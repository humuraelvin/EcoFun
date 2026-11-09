import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../data/storage_service.dart';
import '../core/widgets/toast.dart';
import '../data/supa.dart';
import 'app_prefs.dart';
import 'news_controller.dart';
import 'notification_controller.dart';
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
    ever(language, AuthRepository.syncLanguage);
    _authSub = supa.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        home.value = null;
        StorageService.instance.clear();
        if (Get.isRegistered<NotificationController>()) NotificationController.to.stop();
        if (Get.currentRoute != Routes.login) Get.offAllNamed(Routes.login);
      }
    });
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }

  bool get isAdmin => profile?.isAdmin ?? AppPrefs.isAdmin;

  Future<void> start() async {
    home.value ??= await HomeRepository.cached();
    if (Get.isRegistered<NewsController>()) NewsController.to.loadReads();
    if (Get.isRegistered<NotificationController>()) unawaited(NotificationController.to.start());
    unawaited(AuthRepository.syncLanguage(language.value));
    await refreshHome();
  }

  /// After sign-in: load the member's data, then open the member app or the admin portal.
  Future<void> enterApp() async {
    home.value = null;
    await start();
    Get.offAllNamed(isAdmin ? Routes.admin : Routes.shell);
  }

  Future<void> refreshHome() async {
    if (supa.auth.currentUser == null) return;
    loading.value = true;
    try {
      final h = await HomeRepository.load();
      home.value = h;
      error.value = null;
      if (Get.isRegistered<NotificationController>()) NotificationController.to.unread.value = h.unreadNotifications;
      if (AppPrefs.isAdmin != h.profile.isAdmin) {
        await AppPrefs.setAdmin(h.profile.isAdmin);
        // Role changed since the app opened: switch between the member app and the admin portal.
        if (h.profile.isAdmin && Get.currentRoute == Routes.shell) Get.offAllNamed(Routes.admin);
        if (!h.profile.isAdmin && Get.currentRoute.startsWith(Routes.admin)) Get.offAllNamed(Routes.shell);
      }
    } catch (e) {
      error.value = friendlyError(e);
      if (isSuspendedError(e)) await _suspended();
    } finally {
      loading.value = false;
    }
  }

  bool _signingOutSuspended = false;

  /// The account was suspended by an admin: explain, then sign out.
  Future<void> _suspended() async {
    if (_signingOutSuspended) return;
    _signingOutSuspended = true;
    try {
      await AuthRepository.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      showToast('errors.suspendedBody'.tr(), title: 'errors.suspended'.tr(), error: true);
    } finally {
      _signingOutSuspended = false;
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
    home.value = h.copyWith(
      profile: Profile(
        id: h.profile.id,
        fullName: h.profile.fullName,
        avatarUrl: h.profile.avatarUrl,
        points: points,
        isAdmin: h.profile.isAdmin,
      ),
    );
  }

  Future<void> signOut() async {
    await AppPrefs.setAdmin(false);
    await AuthRepository.signOut();
  }
}
