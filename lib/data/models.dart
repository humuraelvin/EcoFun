import 'package:easy_localization/easy_localization.dart';

import '../core/utils/app_lang.dart';

// Plain data classes for everything the app reads from Supabase.

/// Members without a chosen name are stored as "EcoFun member"; show that in the app language.
String memberName(String? stored) =>
    stored == null || stored.isEmpty || stored == 'EcoFun member' ? 'common.member'.tr() : stored;

DateTime _date(dynamic v) => v == null ? DateTime.now() : DateTime.parse(v as String).toLocal();
int _int(dynamic v) => v == null ? 0 : (v as num).toInt();

class Profile {
  const Profile({required this.id, required this.fullName, this.avatarUrl, required this.points, this.isAdmin = false});

  final String id;
  final String fullName;
  final String? avatarUrl;
  final int points;
  final bool isAdmin;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        fullName: memberName(j['full_name'] as String?),
        avatarUrl: j['avatar_url'] as String?,
        points: _int(j['points']),
        isAdmin: j['is_admin'] == true,
      );

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;
}

class Mission {
  const Mission({
    required this.id,
    required this.icon,
    required this.titleEn,
    required this.titleRw,
    required this.descriptionEn,
    required this.descriptionRw,
    required this.points,
    required this.needsScan,
  });

  final int id;
  final String icon;
  final String titleEn;
  final String titleRw;
  final String descriptionEn;
  final String descriptionRw;
  final int points;
  final bool needsScan;

  String title(String lang) => lang == 'rw' ? titleRw : titleEn;
  String description(String lang) => lang == 'rw' ? descriptionRw : descriptionEn;

  factory Mission.fromJson(Map<String, dynamic> j) => Mission(
        id: _int(j['id']),
        icon: (j['icon'] as String?) ?? '🌱',
        titleEn: j['title_en'] as String,
        titleRw: j['title_rw'] as String,
        descriptionEn: j['description_en'] as String,
        descriptionRw: j['description_rw'] as String,
        points: _int(j['points']),
        needsScan: j['needs_scan'] == true,
      );
}

class DayProgress {
  const DayProgress({
    this.articleId,
    this.newsRead = false,
    this.quizDone = false,
    this.quizScore,
    this.quizTotal,
    this.missionDone = false,
  });

  final String? articleId;
  final bool newsRead;
  final bool quizDone;
  final int? quizScore;
  final int? quizTotal;
  final bool missionDone;

  int get stepsDone => (newsRead ? 1 : 0) + (quizDone ? 1 : 0) + (missionDone ? 1 : 0);

  factory DayProgress.fromJson(Map<String, dynamic> j) => DayProgress(
        articleId: j['article_id'] as String?,
        newsRead: j['news_read'] == true,
        quizDone: j['quiz_done'] == true,
        quizScore: j['quiz_score'] == null ? null : _int(j['quiz_score']),
        quizTotal: j['quiz_total'] == null ? null : _int(j['quiz_total']),
        missionDone: j['mission_done'] == true,
      );
}

class WeekDay {
  const WeekDay(this.day, this.done);
  final DateTime day;
  final bool done;
}

class Stats {
  const Stats({this.missions = 0, this.scans = 0, this.quizzes = 0, this.articles = 0});
  final int missions;
  final int scans;
  final int quizzes;
  final int articles;

  factory Stats.fromJson(Map<String, dynamic>? j) => j == null
      ? const Stats()
      : Stats(
          missions: _int(j['missions']),
          scans: _int(j['scans']),
          quizzes: _int(j['quizzes']),
          articles: _int(j['articles']),
        );
}

class HomeData {
  const HomeData({
    required this.today,
    required this.profile,
    required this.streak,
    required this.week,
    required this.progress,
    required this.mission,
    required this.stats,
    this.unreadNotifications = 0,
  });

  final DateTime today;
  final Profile profile;
  final int streak;
  final List<WeekDay> week;
  final DayProgress progress;
  final Mission? mission;
  final Stats stats;
  final int unreadNotifications;

  HomeData copyWith({Profile? profile, int? unreadNotifications}) => HomeData(
        today: today,
        profile: profile ?? this.profile,
        streak: streak,
        week: week,
        progress: progress,
        mission: mission,
        stats: stats,
        unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      );

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        today: DateTime.parse(j['today'] as String),
        profile: Profile.fromJson(Map<String, dynamic>.from(j['profile'] as Map)),
        streak: _int(j['streak']),
        week: ((j['week'] as List?) ?? const [])
            .map((e) => WeekDay(DateTime.parse(e['day'] as String), e['done'] == true))
            .toList(),
        progress: DayProgress.fromJson(Map<String, dynamic>.from((j['progress'] as Map?) ?? const {})),
        mission: j['mission'] == null ? null : Mission.fromJson(Map<String, dynamic>.from(j['mission'] as Map)),
        stats: Stats.fromJson((j['stats'] as Map?)?.cast<String, dynamic>()),
        unreadNotifications: _int(j['unread_notifications']),
      );
}

/// A news story. Every story exists in English and Kinyarwanda (translated on the server);
/// [title], [summary] and [body] always return the member's language ([AppLang.code]).
class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.url,
    required this.originalTitle,
    required this.originalSummary,
    required this.originalBody,
    this.trTitle,
    this.trSummary,
    this.trBody,
    this.imageUrl,
    required this.source,
    required this.language,
    required this.publishedAt,
  });

  final String id;
  final String url;
  final String originalTitle;
  final String originalSummary;
  final String originalBody;
  final String? trTitle;
  final String? trSummary;
  final String? trBody;
  final String? imageUrl;
  final String source;
  final String language; // language the newsroom wrote it in
  final DateTime publishedAt;

  static const listColumns = 'id,url,title,summary,image_url,source,language,published_at,tr_title,tr_summary';

  bool get _native => language == AppLang.code;

  /// True when this story can be shown in the member's language.
  bool get availableInAppLanguage => _native || (trTitle?.isNotEmpty ?? false);

  /// True when the member reads a translation of the newsroom's original.
  bool get isTranslated => !_native;

  String get title => _native ? originalTitle : (trTitle ?? originalTitle);
  String get summary => _native ? originalSummary : (trSummary ?? '');
  String get body => _native ? originalBody : (trBody ?? '');

  bool get hasBody => body.trim().length > summary.trim().length + 40;

  int get readingMinutes {
    final words = (body.isEmpty ? summary : body).split(RegExp(r'\s+')).length;
    return (words / 200).ceil().clamp(1, 60);
  }

  List<String> get paragraphs => (body.isEmpty ? summary : body)
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  factory NewsArticle.fromJson(Map<String, dynamic> j) => NewsArticle(
        id: j['id'] as String,
        url: j['url'] as String,
        originalTitle: j['title'] as String,
        originalSummary: (j['summary'] as String?) ?? '',
        originalBody: (j['body'] as String?) ?? '',
        trTitle: j['tr_title'] as String?,
        trSummary: j['tr_summary'] as String?,
        trBody: j['tr_body'] as String?,
        imageUrl: j['image_url'] as String?,
        source: j['source'] as String,
        language: j['language'] as String,
        publishedAt: _date(j['published_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': originalTitle,
        'summary': originalSummary,
        'body': originalBody,
        'tr_title': trTitle,
        'tr_summary': trSummary,
        'tr_body': trBody,
        'image_url': imageUrl,
        'source': source,
        'language': language,
        'published_at': publishedAt.toUtc().toIso8601String(),
      };

  NewsArticle withFull(NewsArticle full) => NewsArticle(
        id: id,
        url: url,
        originalTitle: originalTitle,
        originalSummary: originalSummary,
        originalBody: full.originalBody,
        trTitle: trTitle ?? full.trTitle,
        trSummary: trSummary ?? full.trSummary,
        trBody: full.trBody,
        imageUrl: imageUrl,
        source: source,
        language: language,
        publishedAt: publishedAt,
      );
}

class QuizAnswer {
  const QuizAnswer({required this.choice, required this.correct, required this.correctIndex, required this.explanation});
  final int choice;
  final bool correct;
  final int correctIndex;
  final String explanation;

  factory QuizAnswer.fromJson(Map<String, dynamic> j) => QuizAnswer(
        choice: _int(j['choice']),
        correct: j['correct'] == true,
        correctIndex: _int(j['correct_index']),
        explanation: (j['explanation'] as String?) ?? '',
      );
}

class QuizQuestion {
  QuizQuestion({required this.position, required this.question, required this.options, this.topic = '', this.answer});
  final int position;
  final String question;
  final List<String> options;
  final String topic;
  QuizAnswer? answer;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        position: _int(j['position']),
        question: j['question'] as String,
        options: (j['options'] as List).map((e) => e.toString()).toList(),
        topic: (j['topic'] as String?) ?? '',
        answer: j['answer'] == null ? null : QuizAnswer.fromJson(Map<String, dynamic>.from(j['answer'] as Map)),
      );
}

class Quiz {
  const Quiz({
    required this.id,
    required this.questions,
    this.countsForPoints = true,
    this.scoredToday = 0,
    this.scoredLimit = 3,
    this.pointsPerCorrect = 2,
  });
  final String id;
  final List<QuizQuestion> questions;
  final bool countsForPoints;
  final int scoredToday;
  final int scoredLimit;
  final int pointsPerCorrect;

  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
        id: j['quiz_id'] as String,
        countsForPoints: j['counts_for_points'] != false,
        scoredToday: _int(j['scored_today']),
        scoredLimit: j['scored_limit'] == null ? 3 : _int(j['scored_limit']),
        pointsPerCorrect: j['points_per_correct'] == null ? 2 : _int(j['points_per_correct']),
        questions: ((j['questions'] as List?) ?? const [])
            .map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class QuizResult {
  const QuizResult({
    required this.score,
    required this.total,
    required this.pointsAwarded,
    required this.alreadyCompleted,
    this.scoredLeft = 0,
  });
  final int score;
  final int total;
  final int pointsAwarded;
  final bool alreadyCompleted;
  final int scoredLeft;

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
        score: _int(j['score']),
        total: _int(j['total']),
        pointsAwarded: _int(j['points_awarded']),
        alreadyCompleted: j['already_completed'] == true,
        scoredLeft: _int(j['scored_left']),
      );
}

enum WasteCategory {
  biodegradable,
  nonBiodegradable,
  uncertain;

  static WasteCategory parse(String? v) => switch (v) {
        'biodegradable' => WasteCategory.biodegradable,
        'non_biodegradable' => WasteCategory.nonBiodegradable,
        _ => WasteCategory.uncertain,
      };
}

class WasteScan {
  const WasteScan({
    required this.id,
    this.imagePath,
    required this.category,
    required String item,
    required String material,
    required this.confidence,
    required String reason,
    required String decomposeTime,
    required String disposal,
    required String tip,
    this.i18n = const {},
    required this.recyclable,
    required this.createdAt,
    this.pointsAwarded = 0,
    this.disposedAt,
    this.disposalPoints = 0,
    String disposalFeedback = '',
  })  : _item = item,
        _material = material,
        _reason = reason,
        _decomposeTime = decomposeTime,
        _disposal = disposal,
        _tip = tip,
        _disposalFeedback = disposalFeedback;

  final String id;
  final String? imagePath;
  final WasteCategory category;
  final String _item;
  final String _material;
  final double confidence;
  final String _reason;
  final String _decomposeTime;
  final String _disposal;
  final String _tip;

  /// Both languages: {"en": {...}, "rw": {...}, "feedback": {"en": "...", "rw": "..."}}.
  final Map<String, dynamic> i18n;

  String _t(String key, String fallback) {
    final v = (i18n[AppLang.code] as Map?)?[key];
    return v is String && v.isNotEmpty ? v : fallback;
  }

  String get item => _t('item', _item);
  String get material => _t('material', _material);
  String get reason => _t('reason', _reason);
  String get decomposeTime => _t('decompose_time', _decomposeTime);
  String get disposal => _t('disposal', _disposal);
  String get tip => _t('tip', _tip);
  final bool recyclable;
  final DateTime createdAt;
  final int pointsAwarded;
  final DateTime? disposedAt;
  final int disposalPoints;
  final String _disposalFeedback;

  String get disposalFeedback {
    final v = (i18n['feedback'] as Map?)?[AppLang.code];
    return v is String && v.isNotEmpty ? v : _disposalFeedback;
  }

  bool get disposed => disposedAt != null;
  bool get canDispose => !disposed && category != WasteCategory.uncertain;

  WasteScan markDisposed({required int points, required String feedback}) => WasteScan(
        id: id,
        imagePath: imagePath,
        category: category,
        item: _item,
        material: _material,
        confidence: confidence,
        reason: _reason,
        decomposeTime: _decomposeTime,
        disposal: _disposal,
        tip: _tip,
        i18n: {...i18n, 'feedback': {AppLang.code: feedback}},
        recyclable: recyclable,
        createdAt: createdAt,
        pointsAwarded: pointsAwarded,
        disposedAt: DateTime.now(),
        disposalPoints: points,
        disposalFeedback: feedback,
      );

  static const columns = 'id,image_path,category,item,material,confidence,reason,decompose_time,disposal,tip,'
      'recyclable,created_at,disposed_at,disposal_points,disposal_feedback,i18n';

  factory WasteScan.fromJson(Map<String, dynamic> j) => WasteScan(
        id: j['id'] as String,
        imagePath: j['image_path'] as String?,
        category: WasteCategory.parse(j['category'] as String?),
        item: (j['item'] as String?) ?? '',
        material: (j['material'] as String?) ?? '',
        confidence: ((j['confidence'] as num?) ?? 0).toDouble(),
        reason: (j['reason'] as String?) ?? '',
        decomposeTime: (j['decompose_time'] as String?) ?? '',
        disposal: (j['disposal'] as String?) ?? '',
        tip: (j['tip'] as String?) ?? '',
        i18n: Map<String, dynamic>.from((j['i18n'] as Map?) ?? const {}),
        recyclable: j['recyclable'] == true,
        createdAt: _date(j['created_at']),
        pointsAwarded: _int(j['points_awarded']),
        disposedAt: j['disposed_at'] == null ? null : _date(j['disposed_at']),
        disposalPoints: _int(j['disposal_points']),
        disposalFeedback: (j['disposal_feedback'] as String?) ?? '',
      );
}

class DisposalResult {
  const DisposalResult({required this.disposed, required this.points, required this.feedback, this.already = false});
  final bool disposed;
  final int points;
  final String feedback;
  final bool already;

  factory DisposalResult.fromJson(Map<String, dynamic> j) => DisposalResult(
        disposed: j['disposed'] == true,
        points: _int(j['points_awarded']),
        feedback: (j['feedback'] as String?) ?? '',
        already: j['already'] == true,
      );
}

class MissionCompletion {
  const MissionCompletion({
    required this.id,
    required this.day,
    required this.story,
    required this.imagePath,
    required this.pointsAwarded,
    required this.createdAt,
    this.mission,
    this.scan,
  });

  final String id;
  final DateTime day;
  final String story;
  final String imagePath;
  final int pointsAwarded;
  final DateTime createdAt;
  final Mission? mission;
  final WasteScan? scan;

  static const select =
      'id,day,story,image_path,points_awarded,created_at,missions(*),waste_scans(${WasteScan.columns})';

  factory MissionCompletion.fromJson(Map<String, dynamic> j) => MissionCompletion(
        id: j['id'] as String,
        day: DateTime.parse(j['day'] as String),
        story: (j['story'] as String?) ?? '',
        imagePath: j['image_path'] as String,
        pointsAwarded: _int(j['points_awarded']),
        createdAt: _date(j['created_at']),
        mission: j['missions'] == null ? null : Mission.fromJson(Map<String, dynamic>.from(j['missions'] as Map)),
        scan: j['waste_scans'] == null ? null : WasteScan.fromJson(Map<String, dynamic>.from(j['waste_scans'] as Map)),
      );
}

class CommunityPost {
  CommunityPost({
    required this.id,
    required this.userId,
    required this.imagePath,
    required this.caption,
    required this.ratingCount,
    required this.ratingTotal,
    required this.createdAt,
    required this.authorName,
    this.authorAvatar,
    this.myRating,
    this.commentCount = 0,
    this.authorEmail,
    this.authorSuspended = false,
  });

  final String id;
  final String userId;
  final String imagePath;
  final String caption;
  int ratingCount;
  int ratingTotal;
  final DateTime createdAt;
  final String authorName;
  final String? authorAvatar;
  int? myRating;
  int commentCount;
  final String? authorEmail;
  final bool authorSuspended;

  double get average => ratingCount == 0 ? 0 : ratingTotal / ratingCount;

  factory CommunityPost.fromJson(Map<String, dynamic> j) => CommunityPost(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        imagePath: j['image_path'] as String,
        caption: (j['caption'] as String?) ?? '',
        ratingCount: _int(j['rating_count']),
        ratingTotal: _int(j['rating_total']),
        createdAt: _date(j['created_at']),
        authorName: memberName(j['author_name'] as String?),
        authorAvatar: j['author_avatar'] as String?,
        myRating: j['my_rating'] == null ? null : _int(j['my_rating']),
        commentCount: _int(j['comment_count']),
        authorEmail: j['author_email'] as String?,
        authorSuspended: j['author_suspended'] == true,
      );
}

class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    required this.authorName,
    this.authorAvatar,
  });

  final String id;
  final String postId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String authorName;
  final String? authorAvatar;

  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
        id: j['id'] as String,
        postId: j['post_id'] as String,
        userId: j['user_id'] as String,
        body: (j['body'] as String?) ?? '',
        createdAt: _date(j['created_at']),
        authorName: memberName(j['author_name'] as String?),
        authorAvatar: j['author_avatar'] as String?,
      );
}

class LeaderEntry {
  const LeaderEntry({required this.profile, required this.rank});
  final Profile profile;
  final int rank;
}

class Leaderboard {
  const Leaderboard({required this.leaders, this.myRank, this.members = 0});
  final List<LeaderEntry> leaders;
  final int? myRank;
  final int members;

  factory Leaderboard.fromJson(Map<String, dynamic> j) => Leaderboard(
        leaders: ((j['leaders'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((e) => LeaderEntry(profile: Profile.fromJson(e), rank: _int(e['rank'])))
            .toList(),
        myRank: j['my_rank'] == null ? null : _int(j['my_rank']),
        members: _int(j['members']),
      );
}

/// One entry on the notifications page. The text is built in the app from [kind] + [data],
/// so it always follows the app language.
class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.data,
    required this.read,
    required this.createdAt,
    this.postId,
    this.postImage,
    this.actorId,
    this.actorName,
    this.actorAvatar,
  });

  final int id;
  final String kind;
  final Map<String, dynamic> data;
  bool read;
  final DateTime createdAt;
  final String? postId;
  final String? postImage;
  final String? actorId;
  final String? actorName;
  final String? actorAvatar;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _int(j['id']),
        kind: (j['kind'] as String?) ?? '',
        data: Map<String, dynamic>.from((j['data'] as Map?) ?? const {}),
        read: j['read'] == true || j['read_at'] != null,
        createdAt: _date(j['created_at']),
        postId: j['post_id'] as String?,
        postImage: j['post_image'] as String?,
        actorId: j['actor_id'] as String?,
        actorName: j['actor_name'] as String?,
        actorAvatar: j['actor_avatar'] as String?,
      );
}

class Announcement {
  const Announcement({
    required this.id,
    required this.titleEn,
    required this.bodyEn,
    required this.titleRw,
    required this.bodyRw,
    required this.recipients,
    required this.emailed,
    required this.createdAt,
  });

  final String id;
  final String titleEn;
  final String bodyEn;
  final String titleRw;
  final String bodyRw;
  final int recipients;
  final bool emailed;
  final DateTime createdAt;

  String title(String lang) => lang == 'rw' && titleRw.isNotEmpty ? titleRw : titleEn;
  String body(String lang) => lang == 'rw' && bodyRw.isNotEmpty ? bodyRw : bodyEn;

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as String,
        titleEn: (j['title_en'] as String?) ?? '',
        bodyEn: (j['body_en'] as String?) ?? '',
        titleRw: (j['title_rw'] as String?) ?? '',
        bodyRw: (j['body_rw'] as String?) ?? '',
        recipients: _int(j['recipients']),
        emailed: j['emailed'] == true,
        createdAt: _date(j['created_at']),
      );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.points,
    required this.createdAt,
    this.avatarUrl,
    this.isAdmin = false,
    this.suspended = false,
    this.lastSeen,
  });

  final String id;
  final String fullName;
  final String email;
  final int points;
  final DateTime createdAt;
  final String? avatarUrl;
  final bool isAdmin;
  final bool suspended;
  final DateTime? lastSeen;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['id'] as String,
        fullName: memberName(j['full_name'] as String?),
        email: (j['email'] as String?) ?? '',
        points: _int(j['points']),
        createdAt: _date(j['created_at']),
        avatarUrl: j['avatar_url'] as String?,
        isAdmin: j['is_admin'] == true,
        suspended: j['suspended'] == true,
        lastSeen: j['last_seen'] == null ? null : _date(j['last_seen']),
      );
}

class PointEvent {
  const PointEvent({required this.amount, required this.reason, required this.note, required this.createdAt});
  final int amount;
  final String reason;
  final String note;
  final DateTime createdAt;

  factory PointEvent.fromJson(Map<String, dynamic> j) => PointEvent(
        amount: _int(j['amount']),
        reason: (j['reason'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        createdAt: _date(j['created_at']),
      );
}

class AdminUserDetail {
  const AdminUserDetail({
    required this.user,
    required this.stats,
    required this.points,
    required this.posts,
    this.suspendedReason,
    this.verifiedAt,
  });

  final AdminUser user;
  final Map<String, int> stats;
  final List<PointEvent> points;
  final List<CommunityPost> posts;
  final String? suspendedReason;
  final DateTime? verifiedAt;

  factory AdminUserDetail.fromJson(Map<String, dynamic> j) {
    final p = Map<String, dynamic>.from(j['profile'] as Map);
    return AdminUserDetail(
      user: AdminUser.fromJson(p),
      stats: Map<String, dynamic>.from((j['stats'] as Map?) ?? const {}).map((k, v) => MapEntry(k, _int(v))),
      points: ((j['points'] as List?) ?? const []).map((e) => PointEvent.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      posts: ((j['posts'] as List?) ?? const []).map((e) => CommunityPost.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      suspendedReason: p['suspended_reason'] as String?,
      verifiedAt: p['verified_at'] == null ? null : _date(p['verified_at']),
    );
  }
}

class AdminDashboard {
  const AdminDashboard({required this.counts, required this.signups, required this.top, required this.recent});
  final Map<String, int> counts;
  final List<(DateTime, int)> signups;
  final List<Profile> top;
  final List<AdminUser> recent;

  int operator [](String key) => counts[key] ?? 0;

  factory AdminDashboard.fromJson(Map<String, dynamic> j) => AdminDashboard(
        counts: {
          for (final e in j.entries)
            if (e.value is num) e.key: (e.value as num).toInt(),
        },
        signups: ((j['signups'] as List?) ?? const [])
            .map((e) => (DateTime.parse(e['day'] as String), _int(e['count'])))
            .toList(),
        top: ((j['top'] as List?) ?? const []).map((e) => Profile.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        recent: ((j['recent'] as List?) ?? const []).map((e) => AdminUser.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}
