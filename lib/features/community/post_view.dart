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
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';
import 'community_view.dart';

/// A community photo with its comments. Arguments: a [CommunityPost], or a post id (from a notification).
class PostView extends StatefulWidget {
  const PostView({super.key});

  @override
  State<PostView> createState() => _PostViewState();
}

class _PostViewState extends State<PostView> {
  CommunityPost? _post;
  List<PostComment>? _comments;
  String? _error;
  bool _sending = false;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  bool get _isAdmin => SessionController.to.profile?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    if (arg is CommunityPost) _post = arg;
    if (!Get.isRegistered<CommunityController>()) Get.put(CommunityController());
    _load(arg is String ? arg : _post?.id);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load(String? id) async {
    if (id == null) return setState(() => _error = 'community.postGone'.tr());
    try {
      final results = await Future.wait<Object>([
        if (_post == null) CommunityRepository.post(id),
        CommunityRepository.comments(id),
      ]);
      if (!mounted) return;
      setState(() {
        _post ??= results.first as CommunityPost;
        _comments = results.last as List<PostComment>;
        _post!.commentCount = _comments!.length;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final post = _post;
    if (text.isEmpty || post == null || _sending) return;
    setState(() => _sending = true);
    try {
      await CommunityRepository.addComment(post.id, text);
      _input.clear();
      HapticFeedback.lightImpact();
      final list = await CommunityRepository.comments(post.id);
      if (!mounted) return;
      setState(() {
        _comments = list;
        post.commentCount = list.length;
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _commentMenu(PostComment cm) async {
    final mine = cm.userId == currentUid;
    if (!mine && !_isAdmin) return;
    HapticFeedback.selectionClick();
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('community.deleteComment'.tr()),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
      ),
    );
    if (ok != true) return;
    try {
      await CommunityRepository.deleteComment(cm.id);
      setState(() {
        _comments?.remove(cm);
        _post?.commentCount = _comments?.length ?? 0;
      });
    } catch (e) {
      showToast(friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final post = _post;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'community.post'.tr()),
      body: Column(children: [
        Expanded(
          child: post == null
              ? (_error != null ? MessageView.error(_error!) : const CenteredSpinner())
              : GestureDetector(
                  onTap: () => _focus.unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: ListView(
                    controller: _scroll,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      Obx(() {
                        // re-render after a rating made through the controller
                        CommunityController.to.posts.length;
                        return PostCard(post: post, detail: true);
                      }),
                      const SizedBox(height: 18),
                      Text('community.commentsTitle'.tr(), style: AppText.title3.c(c.label)),
                      const SizedBox(height: 10),
                      if (_comments == null)
                        const Padding(padding: EdgeInsets.all(20), child: CupertinoActivityIndicator())
                      else if (_comments!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text('community.noComments'.tr(), textAlign: TextAlign.center, style: AppText.subhead.c(c.secondaryLabel)),
                        )
                      else
                        for (final cm in _comments!) _CommentTile(comment: cm, onLongPress: () => _commentMenu(cm)),
                    ],
                  ),
                ),
        ),
        if (post != null) _composer(c),
      ]),
    );
  }

  Widget _composer(AppColors c) => Container(
        decoration: BoxDecoration(
          color: c.background,
          border: Border(top: BorderSide(color: c.separator, width: 0.5)),
        ),
        padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + MediaQuery.paddingOf(context).bottom),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _input,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body.c(c.label),
                cursorColor: c.brand,
                decoration: InputDecoration(
                  hintText: 'community.commentHint'.tr(),
                  hintStyle: AppText.body.c(c.tertiaryLabel),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _input,
            builder: (_, v, _) {
              final can = v.text.trim().isNotEmpty && !_sending;
              return Pressable(
                onTap: can ? _send : null,
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: can ? c.brand : c.fill, shape: BoxShape.circle),
                  child: _sending
                      ? CupertinoActivityIndicator(color: c.onBrand)
                      : Icon(CupertinoIcons.arrow_up, color: can ? c.onBrand : c.tertiaryLabel, size: 22),
                ),
              );
            },
          ),
        ]),
      );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onLongPress});
  final PostComment comment;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Pressable(
            onTap: () => Get.toNamed(Routes.member, arguments: comment.userId),
            child: Avatar(name: comment.authorName, url: comment.authorAvatar, size: 34),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(comment.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.subhead.semibold.c(c.label)),
                  ),
                  Text(Fmt.ago(comment.createdAt), style: AppText.caption.c(c.tertiaryLabel)),
                ]),
                const SizedBox(height: 3),
                Text(comment.body, style: AppText.callout.c(c.label)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
