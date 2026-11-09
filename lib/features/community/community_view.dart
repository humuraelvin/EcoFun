import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/storage_service.dart';
import '../../data/supa.dart';
import '../shell/shell_view.dart';

class CommunityController extends GetxController {
  static CommunityController get to => Get.find();

  final tab = 0.obs; // 0 feed, 1 leaderboard
  final posts = <CommunityPost>[].obs;
  final board = Rxn<Leaderboard>();
  final loadingFeed = true.obs;
  final loadingMore = false.obs;
  final hasMore = true.obs;
  final loadingLeaders = true.obs;
  final feedError = RxnString();
  final leadersError = RxnString();

  @override
  void onInit() {
    super.onInit();
    refreshFeed();
    refreshLeaders();
    // Points change all the time: reload the leaderboard whenever it is shown.
    ever<int>(tab, (t) {
      if (t == 1) refreshLeaders();
    });
    if (Get.isRegistered<ShellController>()) {
      ever<int>(ShellController.to.index, (i) {
        if (i == 3 && tab.value == 1) refreshLeaders();
      });
    }
  }

  Future<void> refreshAll() => Future.wait([refreshFeed(), refreshLeaders()]);

  Future<void> refreshFeed() async {
    try {
      final list = await CommunityRepository.feed();
      posts.assignAll(list);
      hasMore.value = list.length >= 15;
      feedError.value = null;
    } catch (e) {
      feedError.value = friendlyError(e);
    } finally {
      loadingFeed.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore.value || posts.isEmpty) return;
    loadingMore.value = true;
    try {
      final more = await CommunityRepository.feed(before: posts.last.createdAt);
      posts.addAll(more);
      hasMore.value = more.length >= 15;
    } catch (_) {
    } finally {
      loadingMore.value = false;
    }
  }

  Future<void> refreshLeaders() async {
    try {
      board.value = await CommunityRepository.leaderboard();
      leadersError.value = null;
    } catch (e) {
      leadersError.value = friendlyError(e);
    } finally {
      loadingLeaders.value = false;
    }
  }

  Future<void> rate(CommunityPost post, int value) async {
    final before = (post.myRating, post.ratingCount, post.ratingTotal);
    post
      ..myRating = value
      ..ratingCount += 1
      ..ratingTotal += value;
    posts.refresh();
    HapticFeedback.mediumImpact();
    try {
      final (already, count, total) = await CommunityRepository.rate(post.id, value);
      post
        ..ratingCount = count
        ..ratingTotal = total;
      if (already) showToast('community.alreadyRated'.tr());
      posts.refresh();
      refreshLeaders();
    } catch (e) {
      post
        ..myRating = before.$1
        ..ratingCount = before.$2
        ..ratingTotal = before.$3;
      posts.refresh();
      showToast(friendlyError(e), error: true);
    }
  }

  Future<void> delete(CommunityPost post) async {
    try {
      await CommunityRepository.delete(post.id);
      posts.remove(post);
      showToast('community.deleted'.tr());
    } catch (e) {
      showToast(friendlyError(e), error: true);
    }
  }
}

class CommunityView extends StatefulWidget {
  const CommunityView({super.key});

  @override
  State<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<CommunityView> {
  final ctrl = Get.isRegistered<CommunityController>() ? CommunityController.to : Get.put(CommunityController());
  late final ScrollController _scroll = ShellController.to.scrollers[3];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (ctrl.tab.value == 0 && _scroll.position.extentAfter < 900) ctrl.loadMore();
  }

  Future<void> _compose() async {
    final posted = await Get.toNamed(Routes.compose);
    if (posted == true) ctrl.refreshFeed();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LargeTitlePage(
      title: 'tabs.community'.tr(),
      controller: _scroll,
      onRefresh: ctrl.refreshAll,
      trailing: Pressable(
        onTap: _compose,
        child: Icon(CupertinoIcons.plus_circle_fill, color: c.brand, size: 30),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Obx(() => CupertinoSlidingSegmentedControl<int>(
                  groupValue: ctrl.tab.value,
                  backgroundColor: c.fill,
                  thumbColor: c.surface,
                  children: {
                    0: _seg('community.feed'.tr()),
                    1: _seg('community.leaderboard'.tr()),
                  },
                  onValueChanged: (v) {
                    HapticFeedback.selectionClick();
                    ctrl.tab.value = v ?? 0;
                  },
                )),
          ),
        ),
        Obx(() => ctrl.tab.value == 0 ? _feed(c) : _leaderboard(c)),
      ],
    );
  }

  Widget _seg(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t, style: AppText.subhead.semibold),
      );

  Widget _feed(AppColors c) {
    final list = ctrl.posts.toList();
    if (list.isEmpty) {
      if (ctrl.loadingFeed.value) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SkeletonPulse(child: Column(children: [
              SkeletonBox(height: 56, radius: 16), SizedBox(height: 10), SkeletonBox(height: 320, radius: 20),
            ])),
          ),
        );
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ctrl.feedError.value != null
            ? MessageView.error(ctrl.feedError.value!, onRetry: ctrl.refreshFeed)
            : MessageView(
                icon: CupertinoIcons.photo_on_rectangle,
                title: 'community.emptyTitle'.tr(),
                message: 'community.emptyBody'.tr(),
                actionLabel: 'community.share'.tr(),
                onAction: _compose,
              ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: list.length + 1,
        itemBuilder: (_, i) {
          if (i == list.length) {
            return Obx(() => Padding(
                  padding: const EdgeInsets.all(16),
                  child: ctrl.loadingMore.value ? const CupertinoActivityIndicator() : const SizedBox.shrink(),
                ));
          }
          return Padding(padding: const EdgeInsets.only(bottom: 14), child: PostCard(post: list[i]));
        },
      ),
    );
  }

  Widget _leaderboard(AppColors c) {
    final board = ctrl.board.value;
    final list = board?.leaders ?? const <LeaderEntry>[];
    if (list.isEmpty) {
      if (ctrl.loadingLeaders.value) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: CupertinoActivityIndicator()));
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ctrl.leadersError.value != null
            ? MessageView.error(ctrl.leadersError.value!, onRetry: ctrl.refreshLeaders)
            : MessageView(icon: CupertinoIcons.rosette, title: 'community.noLeaders'.tr()),
      );
    }
    final me = SessionController.to.profile?.id;
    final myRank = board?.myRank;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.list(children: [
        if (list.length >= 3) _Podium(top: list.take(3).map((e) => e.profile).toList()),
        if (myRank != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'community.yourRank'.tr(args: ['$myRank', '${board?.members ?? list.length}']),
              textAlign: TextAlign.center,
              style: AppText.footnote.c(c.secondaryLabel),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: c.surface,
            child: Column(children: [
              for (var i = list.length >= 3 ? 3 : 0; i < list.length; i++)
                _LeaderRow(rank: list[i].rank, profile: list[i].profile, isMe: list[i].profile.id == me, last: i == list.length - 1),
            ]),
          ),
        ),
      ]),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.detail = false});
  final CommunityPost post;

  /// True on the post page itself (no navigation, no rounded card margin).
  final bool detail;

  Future<void> openPost() async {
    if (detail) return;
    await Get.toNamed(Routes.post, arguments: post);
    if (Get.isRegistered<CommunityController>()) CommunityController.to.posts.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mine = post.userId == supa.auth.currentUser?.id;
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: () => Get.toNamed(Routes.member, arguments: post.userId),
            scale: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(children: [
                Avatar(name: post.authorName, url: post.authorAvatar, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(post.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.headline.c(c.label)),
                    Text(Fmt.ago(post.createdAt), style: AppText.caption.c(c.secondaryLabel)),
                  ]),
                ),
                if (mine)
                  IconButton(
                    icon: Icon(CupertinoIcons.ellipsis, color: c.secondaryLabel),
                    onPressed: () => _ownerMenu(context),
                  ),
              ]),
            ),
          ),
          Pressable(
            onTap: openPost,
            scale: 1,
            child: AspectRatio(
              aspectRatio: 1,
              child: NetPhoto(url: StorageService.instance.publicUrl(Bucket.community, post.imagePath)),
            ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(post.caption, style: AppText.callout.c(c.label)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
            child: Row(children: [
              Icon(CupertinoIcons.star_fill, size: 15, color: c.gold),
              const SizedBox(width: 4),
              Text(
                post.ratingCount == 0
                    ? 'community.noRatings'.tr()
                    : '${post.average.toStringAsFixed(1)}  ·  ${'community.ratings'.plural(post.ratingCount)}',
                style: AppText.footnote.semibold.c(c.secondaryLabel),
              ),
              const SizedBox(width: 12),
              Pressable(
                onTap: openPost,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(CupertinoIcons.chat_bubble_fill, size: 15, color: c.secondaryLabel),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}', style: AppText.footnote.semibold.c(c.secondaryLabel)),
                ]),
              ),
              const Spacer(),
              if (!mine) _StarPicker(post: post),
            ]),
          ),
        ],
      ),
    );
  }

  void _ownerMenu(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              CommunityController.to.delete(post);
            },
            child: Text('community.delete'.tr()),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.post});
  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rated = post.myRating;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Pressable(
            scale: 0.8,
            onTap: rated != null ? null : () => CommunityController.to.rate(post, i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Icon(
                rated != null && i <= rated ? CupertinoIcons.star_fill : CupertinoIcons.star,
                size: 22,
                color: rated != null && i <= rated ? c.gold : c.tertiaryLabel,
              ),
            ),
          ),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top});
  final List<Profile> top;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget spot(Profile p, int rank, double avatar, double lift, Color medal) => Expanded(
          child: Pressable(
            onTap: () => Get.toNamed(Routes.member, arguments: p.id),
            child: Column(children: [
              SizedBox(height: lift),
              Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: medal, width: 3)),
                  child: Avatar(name: p.fullName, url: p.avatarUrl, size: avatar),
                ),
                Positioned(
                  bottom: -10,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: medal, shape: BoxShape.circle),
                    child: Text('$rank', style: AppText.caption.bold.c(Colors.white)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Text(p.firstName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.subhead.semibold.c(c.label)),
              Text('${Fmt.points(p.points)} ${'common.pts'.tr()}', style: AppText.caption.c(c.secondaryLabel)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        spot(top[1], 2, 58, 22, const Color(0xFFA7B0BA)),
        spot(top[0], 1, 74, 0, const Color(0xFFE6A700)),
        spot(top[2], 3, 58, 30, const Color(0xFFC0773A)),
      ]),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.rank, required this.profile, required this.isMe, required this.last});
  final int rank;
  final Profile profile;
  final bool isMe;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => Get.toNamed(Routes.member, arguments: profile.id),
      scale: 1,
      child: Container(
        color: isMe ? c.brandSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(width: 30, child: Text('$rank', style: AppText.headline.c(c.secondaryLabel))),
          Avatar(name: profile.fullName, url: profile.avatarUrl, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '${profile.fullName} (${'community.you'.tr()})' : profile.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.c(c.label),
            ),
          ),
          Text(Fmt.points(profile.points), style: AppText.headline.c(c.brand)),
        ]),
      ),
    );
  }
}

class SharePrompt extends StatelessWidget {
  const SharePrompt({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      AppButton(label: 'community.share'.tr(), icon: CupertinoIcons.camera_fill, onPressed: onTap);
}
