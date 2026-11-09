import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/news_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/states.dart';
import '../shell/shell_view.dart';
import 'news_widgets.dart';

class NewsView extends StatefulWidget {
  const NewsView({super.key});

  @override
  State<NewsView> createState() => _NewsViewState();
}

class _NewsViewState extends State<NewsView> {
  final news = NewsController.to;
  late final ScrollController _scroll = ShellController.to.scrollers[1];

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
    if (_scroll.position.extentAfter < 700) news.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LargeTitlePage(
      title: 'tabs.news'.tr(),
      controller: _scroll,
      onRefresh: news.refreshNews,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('news.subtitle'.tr(), style: AppText.subhead.c(c.secondaryLabel)),
              ],
            ),
          ),
        ),
        Obx(() {
          final list = news.articles.toList();
          if (list.isEmpty) {
            if (news.loading.value) {
              return const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(child: StorySkeleton(count: 5)),
              );
            }
            return SliverFillRemaining(
              hasScrollBody: false,
              child: news.error.value != null
                  ? MessageView.error(news.error.value!, onRetry: news.refreshNews)
                  : MessageView(
                      icon: CupertinoIcons.news,
                      title: 'news.emptyTitle'.tr(),
                      message: 'news.emptyBody'.tr(),
                    ),
            );
          }
          final reads = news.readIds.toSet();
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.builder(
              itemCount: list.length + 1,
              itemBuilder: (context, i) {
                if (i == list.length) {
                  return Obx(() => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: news.loadingMore.value
                            ? const CupertinoActivityIndicator()
                            : news.hasMore.value
                                ? const SizedBox(height: 20)
                                : Text('news.end'.tr(), textAlign: TextAlign.center, style: AppText.footnote.c(c.tertiaryLabel)),
                      ));
                }
                final a = list[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: i == 0
                      ? FeaturedStoryCard(article: a, read: reads.contains(a.id))
                      : StoryRow(article: a, read: reads.contains(a.id)),
                );
              },
            ),
          );
        }),
      ],
    );
  }

}
