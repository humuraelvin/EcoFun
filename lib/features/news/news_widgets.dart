import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../data/models.dart';

void openArticle(NewsArticle a) => Get.toNamed(Routes.news, arguments: a);

String languageLabel(String code) => code == 'rw' ? 'news.kinyarwanda'.tr() : 'news.english'.tr();

class SourceLine extends StatelessWidget {
  const SourceLine(this.article, {super.key, this.light = false, this.read = false});
  final NewsArticle article;
  final bool light;
  final bool read;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = light ? Colors.white.withValues(alpha: 0.85) : c.secondaryLabel;
    return Row(
      children: [
        Flexible(
          child: Text(
            article.source.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.overline.c(light ? Colors.white : c.brand),
          ),
        ),
        Text('  ·  ${Fmt.ago(article.publishedAt)}', style: AppText.caption.c(color)),
        if (read) ...[
          const SizedBox(width: 6),
          Icon(CupertinoIcons.checkmark_circle_fill, size: 13, color: light ? Colors.white : c.brand),
        ],
      ],
    );
  }
}

/// Large hero card with the title over a gradient.
class FeaturedStoryCard extends StatelessWidget {
  const FeaturedStoryCard({super.key, required this.article, this.badge, this.read = false});
  final NewsArticle article;
  final String? badge;
  final bool read;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => openArticle(article),
      scale: 0.98,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 4 / 3.1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              article.imageUrl == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.brand, Color.lerp(c.brand, Colors.black, 0.45)!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    )
                  : NetPhoto(url: article.imageUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.25, 1],
                    colors: [Color(0x00000000), Color(0xD9000000)],
                  ),
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(99)),
                    child: Text(badge!, style: AppText.caption.semibold.c(Colors.white)),
                  ),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SourceLine(article, light: true, read: read),
                    const SizedBox(height: 6),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title3.bold.c(Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apple News–style row: text on the left, thumbnail on the right.
class StoryRow extends StatelessWidget {
  const StoryRow({super.key, required this.article, this.read = false});
  final NewsArticle article;
  final bool read;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => openArticle(article),
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SourceLine(article, read: read),
                  const SizedBox(height: 6),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headline.c(read ? c.secondaryLabel : c.label),
                  ),
                  const SizedBox(height: 6),
                  Text(languageLabel(article.language), style: AppText.caption.c(c.tertiaryLabel)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 92,
              height: 92,
              child: NetPhoto(url: article.imageUrl, radius: 12, placeholderIcon: CupertinoIcons.leaf_arrow_circlepath),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact vertical card for horizontal carousels.
class StoryTile extends StatelessWidget {
  const StoryTile({super.key, required this.article});
  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => openArticle(article),
      scale: 0.97,
      child: Container(
        width: 220,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 118, width: double.infinity, child: NetPhoto(url: article.imageUrl)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SourceLine(article),
                  const SizedBox(height: 5),
                  Text(article.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.subhead.semibold.c(c.label)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StorySkeleton extends StatelessWidget {
  const StorySkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) => SkeletonPulse(
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(18)),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 90, height: 10),
                            SizedBox(height: 10),
                            SkeletonBox(height: 14),
                            SizedBox(height: 6),
                            SkeletonBox(width: 160, height: 14),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      SkeletonBox(width: 92, height: 92, radius: 12),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
