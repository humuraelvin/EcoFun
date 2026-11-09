import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/states.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/storage_service.dart';

/// Public profile: name, points and shared photos. Emails are never exposed.
class MemberView extends StatefulWidget {
  const MemberView({super.key});

  @override
  State<MemberView> createState() => _MemberViewState();
}

class _MemberViewState extends State<MemberView> {
  final String uid = Get.arguments as String;
  late final Future<(Profile?, List<CommunityPost>)> _future = _load();

  Future<(Profile?, List<CommunityPost>)> _load() async {
    final r = await Future.wait([CommunityRepository.member(uid), CommunityRepository.byMember(uid)]);
    return (r[0] as Profile?, r[1] as List<CommunityPost>);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context),
      body: FutureBuilder<(Profile?, List<CommunityPost>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return MessageView.error('errors.generic'.tr());
          if (!snap.hasData) return const CenteredSpinner();
          final (profile, posts) = snap.data!;
          if (profile == null) {
            return MessageView(icon: CupertinoIcons.person_crop_circle_badge_xmark, title: 'community.memberGone'.tr());
          }
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Column(children: [
                const SizedBox(height: 8),
                Avatar(name: profile.fullName, url: profile.avatarUrl, size: 92),
                const SizedBox(height: 14),
                Text(profile.fullName, textAlign: TextAlign.center, style: AppText.title2.c(c.label)),
                const SizedBox(height: 4),
                Text(
                  '${Fmt.points(profile.points)} ${'common.points'.tr()}  ·  ${'community.posts'.plural(posts.length)}',
                  style: AppText.subhead.c(c.secondaryLabel),
                ),
                const SizedBox(height: 20),
              ]),
            ),
            if (posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageView(icon: CupertinoIcons.photo, title: 'community.noPostsYet'.tr()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 30),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (_, i) => NetPhoto(url: StorageService.instance.publicUrl(Bucket.community, posts[i].imagePath)),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
