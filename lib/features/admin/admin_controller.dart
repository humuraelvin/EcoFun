import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;

import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';

/// State for the admin portal: dashboard, members, posts and announcements.
class AdminController extends GetxController {
  static AdminController get to => Get.find();

  final tab = 0.obs;

  final dashboard = Rxn<AdminDashboard>();
  final dashboardError = RxnString();

  final users = <AdminUser>[].obs;
  final usersLoading = true.obs;
  final usersMore = true.obs;
  final usersError = RxnString();
  final search = ''.obs;
  final filter = 'all'.obs;

  final posts = <CommunityPost>[].obs;
  final postsLoading = true.obs;
  final postsMore = true.obs;
  final postsError = RxnString();

  final announcements = <Announcement>[].obs;
  final announcementsLoading = true.obs;

  Timer? _debounce;
  int _usersRequest = 0;

  @override
  void onInit() {
    super.onInit();
    refreshDashboard();
    refreshUsers();
    refreshPosts();
    refreshAnnouncements();
    debounce<String>(search, (_) => refreshUsers(), time: const Duration(milliseconds: 350));
    ever<String>(filter, (_) => refreshUsers());
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> refreshAll() => Future.wait([refreshDashboard(), refreshUsers(), refreshPosts(), refreshAnnouncements()]);

  Future<void> refreshDashboard() async {
    try {
      dashboard.value = await AdminRepository.dashboard();
      dashboardError.value = null;
    } catch (e) {
      dashboardError.value = friendlyError(e);
    }
  }

  Future<void> refreshUsers() async {
    final req = ++_usersRequest;
    usersLoading.value = users.isEmpty;
    try {
      final list = await AdminRepository.users(search: search.value, filter: filter.value);
      if (req != _usersRequest) return;
      users.assignAll(list);
      usersMore.value = list.length >= 30;
      usersError.value = null;
    } catch (e) {
      if (req == _usersRequest) usersError.value = friendlyError(e);
    } finally {
      if (req == _usersRequest) usersLoading.value = false;
    }
  }

  Future<void> moreUsers() async {
    if (!usersMore.value || usersLoading.value) return;
    usersMore.value = false;
    try {
      final list = await AdminRepository.users(search: search.value, filter: filter.value, offset: users.length);
      users.addAll(list);
      usersMore.value = list.length >= 30;
    } catch (_) {}
  }

  Future<void> refreshPosts() async {
    postsLoading.value = posts.isEmpty;
    try {
      final list = await AdminRepository.posts();
      posts.assignAll(list);
      postsMore.value = list.length >= 20;
      postsError.value = null;
    } catch (e) {
      postsError.value = friendlyError(e);
    } finally {
      postsLoading.value = false;
    }
  }

  Future<void> morePosts() async {
    if (!postsMore.value || posts.isEmpty) return;
    postsMore.value = false;
    try {
      final list = await AdminRepository.posts(before: posts.last.createdAt);
      posts.addAll(list);
      postsMore.value = list.length >= 20;
    } catch (_) {}
  }

  Future<void> deletePost(CommunityPost post, String reason) async {
    try {
      await AdminRepository.deletePost(post, reason);
      posts.remove(post);
      showToast('admin.postDeleted'.tr());
      refreshDashboard();
    } catch (e) {
      showToast(friendlyError(e), error: true);
    }
  }

  Future<void> refreshAnnouncements() async {
    try {
      announcements.assignAll(await AdminRepository.announcements());
    } catch (_) {
    } finally {
      announcementsLoading.value = false;
    }
  }

  /// Keeps lists in step after an action on one member.
  void memberChanged() {
    refreshUsers();
    refreshDashboard();
  }
}
