import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../data/models.dart';
import '../../data/storage_service.dart';
import 'admin_controller.dart';
import 'admin_widgets.dart';

/// Every photo members share, newest first, with moderation.
class AdminPostsView extends StatefulWidget {
  const AdminPostsView({super.key});

  @override
  State<AdminPostsView> createState() => _AdminPostsViewState();
}

class _AdminPostsViewState extends State<AdminPostsView> {
  final ctrl = AdminController.to;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 900) ctrl.morePosts();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _remove(CommunityPost post) async {
    final reason = TextEditingController();
    final c = context.colors;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('admin.removePostTitle'.tr(), textAlign: TextAlign.center, style: AppText.headline.c(c.label)),
          const SizedBox(height: 6),
          Text('admin.removePostMessage'.tr(args: [post.authorName]), textAlign: TextAlign.center,
              style: AppText.subhead.c(c.secondaryLabel)),
          const SizedBox(height: 14),
          AppTextField(controller: reason, placeholder: 'admin.reasonOptional'.tr(), maxLength: 200,
              textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 14),
          AppButton(label: 'admin.removePost'.tr(), kind: ButtonStyleKind.danger, onPressed: () => Navigator.pop(ctx, true)),
          const SizedBox(height: 6),
          AppButton(label: 'common.cancel'.tr(), kind: ButtonStyleKind.plain, onPressed: () => Navigator.pop(ctx, false)),
        ]),
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (ok == true) await ctrl.deletePost(post, text);
  }

  @override
  Widget build(BuildContext context) {
    return LargeTitlePage(
      title: 'admin.posts'.tr(),
      controller: _scroll,
      onRefresh: ctrl.refreshPosts,
      slivers: [
        Obx(() {
          final list = ctrl.posts.toList();
          if (list.isEmpty) {
            if (ctrl.postsLoading.value) {
              return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: CupertinoActivityIndicator()));
            }
            return SliverFillRemaining(
              hasScrollBody: false,
              child: ctrl.postsError.value != null
                  ? MessageView.error(ctrl.postsError.value!, onRetry: ctrl.refreshPosts)
                  : MessageView(icon: CupertinoIcons.photo_on_rectangle, title: 'admin.noPosts'.tr()),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _AdminPostCard(post: list[i], onRemove: () => _remove(list[i])),
            ),
          );
        }),
      ],
    );
  }
}

class _AdminPostCard extends StatelessWidget {
  const _AdminPostCard({required this.post, required this.onRemove});
  final CommunityPost post;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Pressable(
          scale: 1,
          onTap: () => Get.toNamed(Routes.adminUser, arguments: post.userId),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(children: [
              Avatar(name: post.authorName, url: post.authorAvatar, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(post.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.headline.c(c.label))),
                    if (post.authorSuspended) ...[const SizedBox(width: 6), StatusPill(label: 'admin.badgeSuspended'.tr(), color: c.danger)],
                  ]),
                  Text('${post.authorEmail ?? ''} · ${Fmt.ago(post.createdAt)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppText.caption.c(c.secondaryLabel)),
                ]),
              ),
              IconButton(onPressed: onRemove, icon: Icon(CupertinoIcons.trash, color: c.danger, size: 21)),
            ]),
          ),
        ),
        Pressable(
          scale: 1,
          onTap: () => Get.toNamed(Routes.post, arguments: post),
          child: AspectRatio(aspectRatio: 1.25, child: NetPhoto(url: StorageService.instance.publicUrl(Bucket.community, post.imagePath))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (post.caption.isNotEmpty) ...[Text(post.caption, style: AppText.callout.c(c.label)), const SizedBox(height: 6)],
            Row(children: [
              Icon(CupertinoIcons.star_fill, size: 14, color: c.gold),
              const SizedBox(width: 4),
              Text(post.ratingCount == 0 ? 'community.noRatings'.tr() : '${post.average.toStringAsFixed(1)} · ${'community.ratings'.plural(post.ratingCount)}',
                  style: AppText.footnote.c(c.secondaryLabel)),
              const SizedBox(width: 12),
              Icon(CupertinoIcons.chat_bubble_fill, size: 14, color: c.secondaryLabel),
              const SizedBox(width: 4),
              Text('${post.commentCount}', style: AppText.footnote.c(c.secondaryLabel)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
