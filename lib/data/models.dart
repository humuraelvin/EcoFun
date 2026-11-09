// Plain data classes for everything the app reads from Supabase.

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
        fullName: (j['full_name'] as String?) ?? 'EcoStep member',
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
  });

  final DateTime today;
  final Profile profile;
  final int streak;
  final List<WeekDay> week;
  final DayProgress progress;
  final Mission? mission;
  final Stats stats;

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
      );
}

class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.url,
    required this.title,
    required this.summary,
    required this.body,
    this.imageUrl,
    required this.source,
    required this.language,
    required this.publishedAt,
  });

  final String id;
  final String url;
  final String title;
  final String summary;
  final String body;
  final String? imageUrl;
  final String source;
  final String language;
  final DateTime publishedAt;

  static const listColumns = 'id,url,title,summary,image_url,source,language,published_at';

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
        title: j['title'] as String,
        summary: (j['summary'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        imageUrl: j['image_url'] as String?,
        source: j['source'] as String,
        language: j['language'] as String,
        publishedAt: _date(j['published_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'summary': summary,
        'body': body,
        'image_url': imageUrl,
        'source': source,
        'language': language,
        'published_at': publishedAt.toUtc().toIso8601String(),
      };

  NewsArticle withBody(String body) => NewsArticle(
        id: id,
        url: url,
        title: title,
        summary: summary,
        body: body,
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
  QuizQuestion({required this.position, required this.question, required this.options, this.answer});
  final int position;
  final String question;
  final List<String> options;
  QuizAnswer? answer;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        position: _int(j['position']),
        question: j['question'] as String,
        options: (j['options'] as List).map((e) => e.toString()).toList(),
        answer: j['answer'] == null ? null : QuizAnswer.fromJson(Map<String, dynamic>.from(j['answer'] as Map)),
      );
}

class Quiz {
  const Quiz({required this.id, required this.source, required this.questions});
  final String id;
  final String source;
  final List<QuizQuestion> questions;

  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
        id: j['quiz_id'] as String,
        source: (j['source'] as String?) ?? 'bank',
        questions: ((j['questions'] as List?) ?? const [])
            .map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class QuizResult {
  const QuizResult({required this.score, required this.total, required this.pointsAwarded, required this.alreadyCompleted});
  final int score;
  final int total;
  final int pointsAwarded;
  final bool alreadyCompleted;

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
        score: _int(j['score']),
        total: _int(j['total']),
        pointsAwarded: _int(j['points_awarded']),
        alreadyCompleted: j['already_completed'] == true,
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
    required this.item,
    required this.material,
    required this.confidence,
    required this.reason,
    required this.decomposeTime,
    required this.disposal,
    required this.tip,
    required this.recyclable,
    required this.createdAt,
    this.pointsAwarded = 0,
  });

  final String id;
  final String? imagePath;
  final WasteCategory category;
  final String item;
  final String material;
  final double confidence;
  final String reason;
  final String decomposeTime;
  final String disposal;
  final String tip;
  final bool recyclable;
  final DateTime createdAt;
  final int pointsAwarded;

  static const columns =
      'id,image_path,category,item,material,confidence,reason,decompose_time,disposal,tip,recyclable,created_at';

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
        recyclable: j['recyclable'] == true,
        createdAt: _date(j['created_at']),
        pointsAwarded: _int(j['points_awarded']),
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

  double get average => ratingCount == 0 ? 0 : ratingTotal / ratingCount;

  factory CommunityPost.fromJson(Map<String, dynamic> j) => CommunityPost(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        imagePath: j['image_path'] as String,
        caption: (j['caption'] as String?) ?? '',
        ratingCount: _int(j['rating_count']),
        ratingTotal: _int(j['rating_total']),
        createdAt: _date(j['created_at']),
        authorName: (j['author_name'] as String?) ?? 'EcoStep member',
        authorAvatar: j['author_avatar'] as String?,
        myRating: j['my_rating'] == null ? null : _int(j['my_rating']),
      );
}
