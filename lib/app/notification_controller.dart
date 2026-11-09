import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/widgets/toast.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../data/supa.dart';
import 'session_controller.dart';

/// Notifications for the signed-in member: the list, the unread badge, and live updates
/// (Supabase Realtime) that show a banner the moment something happens.
class NotificationController extends GetxController {
  static NotificationController get to => Get.find();

  final items = <AppNotification>[].obs;
  final unread = 0.obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = true.obs;
  final error = RxnString();

  RealtimeChannel? _channel;
  String? _uid;

  /// Called after sign-in / app start.
  Future<void> start() async {
    final uid = supa.auth.currentUser?.id;
    if (uid == null) return;
    if (_uid != uid) {
      await stop();
      _uid = uid;
      _channel = supa
          .channel('notifications:$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
            callback: _onInsert,
          )
          .subscribe();
    }
    await refreshList();
  }

  Future<void> stop() async {
    final ch = _channel;
    _channel = null;
    _uid = null;
    items.clear();
    unread.value = 0;
    if (ch != null) await supa.removeChannel(ch);
  }

  void _onInsert(PostgresChangePayload payload) {
    final n = AppNotification.fromJson(payload.newRecord);
    unread.value++;
    HapticFeedback.mediumImpact();
    final text = NotificationText.of(n, SessionController.to.language.value);
    showToast(text.body.isEmpty ? text.title : text.body, title: text.title, icon: text.icon);
    // Pull the full row (actor name, post photo) shortly after.
    Future<void>.delayed(const Duration(milliseconds: 400), refreshList);
    if (n.kind == 'rating' || n.kind == 'points_granted' || n.kind == 'points_removed') {
      SessionController.to.refreshHome();
    }
  }

  Future<void> refreshList() async {
    if (supa.auth.currentUser == null) return;
    loading.value = items.isEmpty;
    try {
      final page = await NotificationRepository.list();
      items.assignAll(page.items);
      unread.value = page.unread;
      hasMore.value = page.items.length >= 40;
      error.value = null;
    } catch (e) {
      error.value = friendlyError(e);
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore.value || items.isEmpty) return;
    loadingMore.value = true;
    try {
      final page = await NotificationRepository.list(before: items.last.createdAt);
      items.addAll(page.items);
      hasMore.value = page.items.length >= 40;
    } catch (_) {
    } finally {
      loadingMore.value = false;
    }
  }

  Future<void> markAllRead() async {
    if (unread.value == 0 && items.every((n) => n.read)) return;
    for (final n in items) {
      n.read = true;
    }
    items.refresh();
    unread.value = 0;
    try {
      unread.value = await NotificationRepository.markRead();
    } catch (_) {}
  }

  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    n.read = true;
    items.refresh();
    if (unread.value > 0) unread.value--;
    try {
      unread.value = await NotificationRepository.markRead([n.id]);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    final before = items.toList();
    items.clear();
    unread.value = 0;
    try {
      await NotificationRepository.clear();
    } catch (e) {
      items.assignAll(before);
      showToast(friendlyError(e), error: true);
    }
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}

/// Localised wording for each notification kind (English and Kinyarwanda).
class NotificationText {
  const NotificationText(this.title, this.body, this.icon, this.color);
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  static NotificationText of(AppNotification n, String lang) {
    final d = n.data;
    final actor = n.actorName ?? (d['name'] as String?) ?? 'notif.someone'.tr();
    String s(String k) => (d[k] ?? '').toString();
    switch (n.kind) {
      case 'rating':
        return NotificationText('notif.ratingTitle'.tr(args: [actor, s('stars')]), 'notif.ratingBody'.tr(args: [s('stars')]),
            CupertinoIcons.star_fill, const Color(0xFFE6A700));
      case 'comment':
        return NotificationText('notif.commentTitle'.tr(args: [actor]), s('snippet'), CupertinoIcons.chat_bubble_fill,
            const Color(0xFF0A84FF));
      case 'announcement':
        final title = lang == 'rw' && s('title_rw').isNotEmpty ? s('title_rw') : s('title_en');
        final body = lang == 'rw' && s('body_rw').isNotEmpty ? s('body_rw') : s('body_en');
        return NotificationText(title.isEmpty ? 'notif.announcement'.tr() : title, body, CupertinoIcons.speaker_2_fill,
            const Color(0xFF8E5CF7));
      case 'points_granted':
        return NotificationText('notif.pointsGranted'.tr(args: [s('points')]), s('reason'), CupertinoIcons.gift_fill,
            const Color(0xFF0C9F5C));
      case 'points_removed':
        return NotificationText('notif.pointsRemoved'.tr(args: [s('points')]), s('reason'), CupertinoIcons.minus_circle_fill,
            const Color(0xFFFF3B30));
      case 'post_removed':
        return NotificationText('notif.postRemoved'.tr(), s('reason').isEmpty ? 'notif.postRemovedBody'.tr() : s('reason'),
            CupertinoIcons.eye_slash_fill, const Color(0xFFFF3B30));
      case 'welcome':
        return NotificationText('notif.welcomeTitle'.tr(), 'notif.welcomeBody'.tr(), CupertinoIcons.leaf_arrow_circlepath,
            const Color(0xFF0C9F5C));
      case 'new_user':
        return NotificationText('notif.newUser'.tr(args: [actor]), s('email'), CupertinoIcons.person_badge_plus_fill,
            const Color(0xFF0C9F5C));
      case 'user_left':
        return NotificationText('notif.userLeft'.tr(args: [s('name').isEmpty ? actor : s('name')]), s('email'),
            CupertinoIcons.person_badge_minus_fill, const Color(0xFFFF9500));
      case 'new_post':
        return NotificationText('notif.newPost'.tr(args: [actor]), s('caption'), CupertinoIcons.photo_fill,
            const Color(0xFF0A84FF));
      default:
        return NotificationText('notif.generic'.tr(), '', CupertinoIcons.bell_fill, const Color(0xFF8E8E93));
    }
  }
}
