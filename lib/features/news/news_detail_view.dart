import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;
import 'package:url_launcher/url_launcher.dart';

import '../../app/news_controller.dart';
import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import 'news_widgets.dart';

/// Article reader. A story counts as read when the reader scrolls near the end,
/// when a short story stays on screen for a few seconds, or when the original is opened.
class NewsDetailView extends StatefulWidget {
  const NewsDetailView({super.key});

  @override
  State<NewsDetailView> createState() => _NewsDetailViewState();
}

class _NewsDetailViewState extends State<NewsDetailView> {
  late NewsArticle _article = Get.arguments as NewsArticle;
  final _scroll = ScrollController();
  final _progress = ValueNotifier<double>(0);
  bool _loadingBody = true;
  bool _marked = false;
  Timer? _dwell;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _marked = NewsController.to.readIds.contains(_article.id) &&
        SessionController.to.progress.newsRead &&
        SessionController.to.progress.articleId == _article.id;
    _loadBody();
  }

  Future<void> _loadBody() async {
    try {
      final full = await NewsController.to.full(_article);
      if (mounted) setState(() => _article = full);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingBody = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkShortStory());
      }
    }
  }

  void _checkShortStory() {
    if (!_scroll.hasClients || _marked) return;
    if (_scroll.position.maxScrollExtent < 80) {
      _dwell = Timer(const Duration(seconds: 4), _markRead);
    }
  }

  void _onScroll() {
    final max = _scroll.position.maxScrollExtent;
    final p = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    _progress.value = p;
    if (!_marked && !_loadingBody && p >= 0.85) _markRead();
  }

  Future<void> _markRead() async {
    if (_marked) return;
    _marked = true;
    NewsController.to.markLocallyRead(_article.id);
    final session = SessionController.to;
    final firstToday = !session.progress.newsRead;
    final quizStarted = session.progress.quizDone;
    final ok = await session.markRead(_article);
    if (!mounted) return;
    setState(() {});
    if (ok && firstToday && !quizStarted) {
      HapticFeedback.mediumImpact();
      showToast('news.readUnlocked'.tr(), title: 'news.readTitle'.tr(), icon: CupertinoIcons.book_fill);
    } else if (!ok) {
      _marked = false;
    }
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(_article.url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView).catchError((_) => false) ||
        await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (opened) {
      _markRead();
    } else {
      showToast('news.cannotOpen'.tr(), error: true);
    }
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: c.surface,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _article.imageUrl == null
                    ? SizedBox(height: top + 64)
                    : AspectRatio(aspectRatio: 4 / 3, child: NetPhoto(url: _article.imageUrl)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverList.list(children: [
                  Row(children: [
                    Expanded(child: SourceLine(_article)),
                    Text('news.minRead'.tr(args: ['${_article.readingMinutes}']), style: AppText.caption.c(c.secondaryLabel)),
                  ]),
                  const SizedBox(height: 10),
                  Text(_article.title, style: AppText.title1.c(c.label)),
                  const SizedBox(height: 10),
                  Text(
                    '${languageLabel(_article.language)} · ${Fmt.date(_article.publishedAt)}',
                    style: AppText.footnote.c(c.secondaryLabel),
                  ),
                  const SizedBox(height: 18),
                  Container(height: 0.6, color: c.separator),
                  const SizedBox(height: 18),
                  if (_loadingBody && _article.body.isEmpty)
                    const SkeletonPulse(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SkeletonBox(height: 14), SizedBox(height: 10), SkeletonBox(height: 14),
                        SizedBox(height: 10), SkeletonBox(width: 220, height: 14), SizedBox(height: 24),
                        SkeletonBox(height: 14), SizedBox(height: 10), SkeletonBox(height: 14),
                      ]),
                    )
                  else
                    ..._article.paragraphs.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(p, style: AppText.reading.c(c.label)),
                        )),
                  if (!_loadingBody && !_article.hasBody)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text('news.summaryOnly'.tr(args: [_article.source]), style: AppText.footnote.c(c.secondaryLabel)),
                    ),
                  const SizedBox(height: 6),
                  AppButton(
                    label: 'news.readOn'.tr(args: [_article.source]),
                    icon: CupertinoIcons.arrow_up_right_square,
                    kind: ButtonStyleKind.tinted,
                    onPressed: _openOriginal,
                  ),
                  const SizedBox(height: 14),
                  _QuizCallout(marked: _marked),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 40),
                ]),
              ),
            ],
          ),
          // Floating top bar with back button + reading progress.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(12, top + 6, 12, 8),
                  child: Row(children: [
                    CircleIconButton(
                      icon: CupertinoIcons.chevron_back,
                      onTap: Get.back,
                      background: Colors.black.withValues(alpha: 0.42),
                      foreground: Colors.white,
                    ),
                    const Spacer(),
                    CircleIconButton(
                      icon: CupertinoIcons.arrow_up_right,
                      onTap: _openOriginal,
                      background: Colors.black.withValues(alpha: 0.42),
                      foreground: Colors.white,
                    ),
                  ]),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (_, v, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v,
                  child: Container(height: top > 0 ? 3 : 2.5, color: c.brand),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizCallout extends StatelessWidget {
  const _QuizCallout({required this.marked});
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() {
      final p = SessionController.to.progress;
      if (p.quizDone) return const SizedBox.shrink();
      final ready = p.newsRead || marked;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ready ? c.brandSoft : c.fill, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(ready ? CupertinoIcons.sparkles : CupertinoIcons.arrow_down_circle, color: ready ? c.brand : c.secondaryLabel),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ready ? 'news.quizReady'.tr() : 'news.keepReading'.tr(),
                style: AppText.subhead.c(ready ? c.label : c.secondaryLabel),
              ),
            ),
            if (ready) ...[
              const SizedBox(width: 8),
              AppButton(
                label: 'news.takeQuiz'.tr(),
                expand: false,
                height: 38,
                onPressed: () => Get.toNamed(Routes.quiz),
              ),
            ],
          ],
        ),
      );
    });
  }
}
