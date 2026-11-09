import 'dart:async';

import 'package:get/get.dart' hide Trans;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../data/storage_service.dart';
import '../data/supa.dart';
import 'news_controller.dart';
import 'routes.dart';

/// Single source of truth for today's progress, points and streak.
/// Everything is persisted on the server (Supabase), so it survives restarts
/// and resets automatically at midnight Kigali time.
class SessionController extends GetxController {
  static SessionController get to => Get.find();

  final home = Rxn<HomeData>();
  final loading = false.obs;
  final error = RxnString();
  final language = 'en'.obs;

  StreamSubscription<AuthState>? _authSub;
  final _readInFlight = <String>{};

  Profile? get profile => home.value?.profile;
  DayProgress get progress => home.value?.progress ?? const DayProgress();

  @override
  void onInit() {
    super.onInit();
    _authSub = supa.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        home.value = null;
        StorageService.instance.clear();
        if (Get.currentRoute != Routes.login) Get.offAllNamed(Routes.login);
      }
    });
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }

  Future<void> start() async {
    home.value ??= await HomeRepository.cached();
    if (Get.isRegistered<NewsController>()) NewsController.to.loadReads();
    await refreshHome();
  }

  Future<void> refreshHome() async {
    if (supa.auth.currentUser == null) return;
    loading.value = true;
    try {
      home.value = await HomeRepository.load();
      error.value = null;
    } catch (e) {
      error.value = friendlyError(e);
    } finally {
      loading.value = false;
    }
  }

  /// Records that the user read a story today. Unlocks the quiz.
  Future<bool> markRead(NewsArticle article) async {
    final p = progress;
    if (p.newsRead && p.articleId == article.id) return true;
    if (!_readInFlight.add(article.id)) return false;
    try {
      home.value = await HomeRepository.markNewsRead(article.id);
      return true;
    } catch (_) {
      return false;
    } finally {
      _readInFlight.remove(article.id);
    }
  }

  void setPoints(int points) {
    final h = home.value;
    if (h == null) return;
    home.value = HomeData(
      today: h.today,
      profile: Profile(
        id: h.profile.id,
        fullName: h.profile.fullName,
        avatarUrl: h.profile.avatarUrl,
        points: points,
        isAdmin: h.profile.isAdmin,
      ),
      streak: h.streak,
      week: h.week,
      progress: h.progress,
      mission: h.mission,
      stats: h.stats,
    );
  }

  Future<void> signOut() async {
    await AuthRepository.signOut();
  }
}
