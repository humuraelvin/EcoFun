import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'storage_service.dart';
import 'supa.dart';

Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

abstract final class HomeRepository {
  static const _cacheKey = 'home_cache_v1';

  static Future<HomeData> load() async {
    final json = _map(await rpc<dynamic>('get_home'));
    _save(json);
    return HomeData.fromJson(json);
  }

  static Future<HomeData> markNewsRead(String articleId) async {
    final json = _map(await rpc<dynamic>('mark_news_read', {'p_article_id': articleId}));
    _save(json);
    return HomeData.fromJson(json);
  }

  /// Last known home data so the app opens instantly, even offline.
  static Future<HomeData?> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cacheKey:${supa.auth.currentUser?.id}');
      if (raw == null) return null;
      return HomeData.fromJson(_map(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _save(Map<String, dynamic> json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cacheKey:${supa.auth.currentUser?.id}', jsonEncode(json));
    } catch (_) {}
  }
}

abstract final class NewsRepository {
  static const _cacheKey = 'news_cache_v1';
  static const pageSize = 20;

  static Future<List<NewsArticle>> list({String? language, DateTime? before}) async {
    var q = supa.from('news_articles').select(NewsArticle.listColumns);
    if (language != null) q = q.eq('language', language);
    if (before != null) q = q.lt('published_at', before.toUtc().toIso8601String());
    final rows = await q.order('published_at', ascending: false).limit(pageSize);
    final list = (rows as List).map((e) => NewsArticle.fromJson(_map(e))).toList();
    if (language == null && before == null) _save(list);
    return list;
  }

  static Future<NewsArticle> full(String id) async {
    final row = await supa.from('news_articles').select().eq('id', id).single();
    return NewsArticle.fromJson(row);
  }

  static Future<Set<String>> readIds() async {
    final rows = await supa.from('news_reads').select('article_id').order('read_at', ascending: false).limit(300);
    return (rows as List).map((e) => e['article_id'] as String).toSet();
  }

  static Future<List<NewsArticle>> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List).map((e) => NewsArticle.fromJson(_map(e))).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _save(List<NewsArticle> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(list.take(30).map((a) => a.toJson()).toList()));
    } catch (_) {}
  }
}

/// `get_quiz` returns either a quiz or `{completed: true, score, total}`.
class QuizLoad {
  const QuizLoad({this.quiz, this.completedScore, this.completedTotal});
  final Quiz? quiz;
  final int? completedScore;
  final int? completedTotal;
}

abstract final class QuizRepository {
  static Future<QuizLoad> load(String language) async {
    final json = _map(await rpc<dynamic>('get_quiz', {'p_language': language}));
    if (json['completed'] == true) {
      return QuizLoad(completedScore: (json['score'] as num?)?.toInt(), completedTotal: (json['total'] as num?)?.toInt());
    }
    return QuizLoad(quiz: Quiz.fromJson(json));
  }

  static Future<QuizAnswer> answer(String quizId, int position, int choice) async => QuizAnswer.fromJson(
        _map(await rpc<dynamic>('answer_quiz', {'p_quiz_id': quizId, 'p_position': position, 'p_choice': choice})),
      );

  static Future<QuizResult> finish(String quizId) async =>
      QuizResult.fromJson(_map(await rpc<dynamic>('finish_quiz', {'p_quiz_id': quizId})));
}

abstract final class ScanRepository {
  /// Uploads the photo and asks the AI to classify it (both run in parallel).
  static Future<WasteScan> classify(Uint8List jpeg, String language) async {
    final path = StorageService.instance.newPath();
    final upload = StorageService.instance
        .uploadJpeg(Bucket.scans, jpeg, path: path)
        .then<bool>((_) => true)
        .catchError((_) => false);
    final analysis = rpc<dynamic>('classify_waste', {
      'p_image_base64': base64Encode(jpeg),
      'p_mime': 'image/jpeg',
      'p_image_path': path,
      'p_language': language,
    });
    final results = await Future.wait<dynamic>([analysis, upload]);
    return WasteScan.fromJson(_map(results[0]));
  }

  static Future<List<WasteScan>> mine({int limit = 60}) async {
    final rows = await supa
        .from('waste_scans')
        .select(WasteScan.columns)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((e) => WasteScan.fromJson(_map(e))).toList();
  }
}

class MissionDone {
  const MissionDone(this.points, this.streak);
  final int points;
  final int streak;
}

abstract final class MissionRepository {
  static Future<MissionDone> complete({required String story, required Uint8List jpeg, String? scanId}) async {
    final path = await StorageService.instance.uploadJpeg(Bucket.missions, jpeg);
    final json = _map(await rpc<dynamic>('complete_mission', {
      'p_story': story,
      'p_image_path': path,
      'p_scan_id': scanId,
    }));
    return MissionDone((json['points_awarded'] as num).toInt(), (json['streak'] as num).toInt());
  }

  static Future<List<MissionCompletion>> history({int limit = 30, DateTime? beforeDay}) async {
    var q = supa.from('mission_completions').select(MissionCompletion.select);
    if (beforeDay != null) q = q.lt('day', beforeDay.toIso8601String().substring(0, 10));
    final rows = await q.order('day', ascending: false).limit(limit);
    final list = (rows as List).map((e) => MissionCompletion.fromJson(_map(e))).toList();
    StorageService.instance.preload(Bucket.missions, list.map((m) => m.imagePath));
    return list;
  }
}

abstract final class CommunityRepository {
  static Future<List<CommunityPost>> feed({DateTime? before}) async {
    final json = await rpc<dynamic>('get_feed', {
      'p_limit': 15,
      'p_before': before?.toUtc().toIso8601String(),
    });
    return (json as List).map((e) => CommunityPost.fromJson(_map(e))).toList();
  }

  static Future<List<CommunityPost>> byMember(String uid) async {
    final rows = await supa
        .from('community_posts')
        .select('id,user_id,image_path,caption,rating_count,rating_total,created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(30);
    return (rows as List).map((e) => CommunityPost.fromJson(_map(e))).toList();
  }

  static Future<void> create(Uint8List jpeg, String caption) async {
    final path = await StorageService.instance.uploadJpeg(Bucket.community, jpeg);
    await rpc<dynamic>('create_post', {'p_image_path': path, 'p_caption': caption});
  }

  static Future<(bool alreadyRated, int count, int total)> rate(String postId, int value) async {
    final j = _map(await rpc<dynamic>('rate_post', {'p_post_id': postId, 'p_value': value}));
    return (j['already_rated'] == true, (j['rating_count'] as num).toInt(), (j['rating_total'] as num).toInt());
  }

  static Future<void> delete(String postId) async {
    await supa.from('community_posts').delete().eq('id', postId);
  }

  static Future<List<Profile>> leaderboard() async {
    final rows = await supa
        .from('profiles')
        .select('id,full_name,avatar_url,points')
        .order('points', ascending: false)
        .order('created_at')
        .limit(100);
    return (rows as List).map((e) => Profile.fromJson(_map(e))).toList();
  }

  static Future<Profile?> member(String uid) async {
    final row = await supa.from('profiles').select('id,full_name,avatar_url,points').eq('id', uid).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  static Future<String> grantPoints(String email, int points, String reason) async {
    final j = _map(await rpc<dynamic>('admin_grant_points', {'p_email': email, 'p_points': points, 'p_reason': reason}));
    return (j['member'] as String?) ?? email;
  }
}

abstract final class ProfileRepository {
  static Future<void> rename(String name) async {
    await supa.from('profiles').update({'full_name': name.trim()}).eq('id', currentUid);
  }

  static Future<String> setAvatar(Uint8List jpeg) async {
    final path = await StorageService.instance.uploadJpeg(Bucket.avatars, jpeg);
    final url = StorageService.instance.publicUrl(Bucket.avatars, path);
    await supa.from('profiles').update({'avatar_url': url}).eq('id', currentUid);
    return url;
  }

  static Future<void> deleteAccount() async {
    await StorageService.instance.deleteAllMine();
    await rpc<dynamic>('delete_my_account');
  }
}
