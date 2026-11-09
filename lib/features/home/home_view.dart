import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/news_controller.dart';
import '../../app/routes.dart';
import '../../app/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../news/news_widgets.dart';
import '../notifications/notifications_view.dart';
import '../shell/shell_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionController.to;
    final news = NewsController.to;

    return LargeTitlePage(
      title: 'tabs.today'.tr(),
      controller: ShellController.to.scrollers[0],
      onRefresh: () => Future.wait([session.refreshHome(), news.refreshNews()]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Obx(() => _StreakBadge(streak: session.home.value?.streak ?? 0)),
        const SizedBox(width: 6),
        const NotificationBell(),
      ]),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(children: [
            Obx(() => _Greeting(home: session.home.value)),
            const SizedBox(height: 14),
            Obx(() {
              final h = session.home.value;
              if (h == null) {
                if (session.error.value != null) {
                  return AppCard(child: MessageView.error(session.error.value!, onRetry: session.refreshHome));
                }
                return const _HomeSkeleton();
              }
              return Column(children: [
                _WeekStrip(week: h.week),
                const SizedBox(height: 12),
                _TodaySteps(home: h),
              ]);
            }),
          ]),
        ),
        SliverToBoxAdapter(
          child: SectionHeader('home.todayStory'.tr(), action: 'common.seeAll'.tr(), onAction: () => ShellController.to.select(1)),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Obx(() {
              final featured = news.featured(session.progress.articleId, session.language.value);
              if (featured == null) {
                if (news.loading.value) return const SkeletonPulse(child: SkeletonBox(height: 260, radius: 22));
                return AppCard(
                  child: MessageView(
                    icon: CupertinoIcons.news,
                    title: 'news.emptyTitle'.tr(),
                    message: news.error.value ?? 'news.emptyBody'.tr(),
                    actionLabel: 'common.tryAgain'.tr(),
                    onAction: news.refreshNews,
                  ),
                );
              }
              final p = session.progress;
              return FeaturedStoryCard(
                article: featured,
                read: p.newsRead && p.articleId == featured.id,
                badge: '${'news.minRead'.tr(args: ['${featured.readingMinutes}'])} · ${languageLabel(featured.language)}',
              );
            }),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16), sliver: SliverToBoxAdapter(child: _ScanPromo())),
        SliverToBoxAdapter(
          child: Obx(() {
            final featuredId = news.featured(session.progress.articleId, session.language.value)?.id;
            final more = news.articles.where((a) => a.id != featuredId).take(8).toList();
            if (more.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('home.moreStories'.tr(), action: 'common.seeAll'.tr(), onAction: () => ShellController.to.select(1)),
                SizedBox(
                  height: 236,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: more.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => StoryTile(article: more[i]),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.home});
  final HomeData? home;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = home?.profile.firstName;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Fmt.longDay(DateTime.now()).toUpperCase(), style: AppText.overline.c(c.secondaryLabel)),
              const SizedBox(height: 3),
              Text(
                name == null ? Fmt.greeting() : '${Fmt.greeting()}, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title3.c(c.label),
              ),
            ],
          ),
        ),
        if (home != null)
          Pressable(
            onTap: () => ShellController.to.select(4),
            child: Row(children: [
              Pill(label: '${Fmt.points(home!.profile.points)} ${'common.pts'.tr()}', icon: CupertinoIcons.leaf_arrow_circlepath),
              const SizedBox(width: 8),
              Avatar(name: home!.profile.fullName, url: home!.profile.avatarUrl, size: 34),
            ]),
          ),
      ],
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = streak > 0;
    return Pressable(
      onTap: () => showToast(
        active ? 'home.streakActive'.plural(streak) : 'home.streakNone'.tr(),
        icon: CupertinoIcons.flame_fill,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFF8A00).withValues(alpha: 0.14) : c.fill,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.flame_fill, size: 17, color: active ? const Color(0xFFFF8A00) : c.tertiaryLabel),
            const SizedBox(width: 4),
            Text('$streak', style: AppText.headline.c(active ? const Color(0xFFE07000) : c.secondaryLabel)),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.week});
  final List<WeekDay> week;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < week.length; i++)
            _DayDot(day: week[i], isToday: i == week.length - 1, colors: c),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.isToday, required this.colors});
  final WeekDay day;
  final bool isToday;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Column(
      children: [
        Text(Fmt.weekdayShort(day.day), style: AppText.caption.c(isToday ? c.brand : c.secondaryLabel)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: day.done ? c.brand : (isToday ? c.brandSoft : c.fill),
            border: isToday && !day.done ? Border.all(color: c.brand, width: 1.6) : null,
          ),
          alignment: Alignment.center,
          child: day.done
              ? Icon(CupertinoIcons.checkmark_alt, size: 18, color: c.onBrand)
              : Text('${day.day.day}', style: AppText.subhead.semibold.c(isToday ? c.brand : c.secondaryLabel)),
        ),
      ],
    );
  }
}

class _TodaySteps extends StatelessWidget {
  const _TodaySteps({required this.home});
  final HomeData home;

  void _openStory() {
    final s = SessionController.to;
    final a = NewsController.to.featured(s.progress.articleId, s.language.value);
    if (a != null) {
      openArticle(a);
    } else {
      ShellController.to.select(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = home.progress;
    final lang = SessionController.to.language.value;
    final done = p.stepsDone;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(
                value: done / 3,
                color: c.brand,
                track: c.fill,
                size: 50,
                stroke: 6,
                child: Text('$done/3', style: AppText.footnote.bold.c(c.label)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('home.stepsTitle'.tr(), style: AppText.headline.c(c.label)),
                    const SizedBox(height: 2),
                    Text(
                      done == 3 ? 'home.allDone'.tr() : 'home.stepsSubtitle'.tr(),
                      style: AppText.footnote.c(c.secondaryLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StepRow(
            index: 1,
            icon: CupertinoIcons.book_fill,
            title: 'home.step1'.tr(),
            subtitle: p.newsRead ? 'home.step1Done'.tr() : 'home.step1Hint'.tr(),
            state: p.newsRead ? _StepState.done : _StepState.ready,
            onTap: _openStory,
          ),
          _StepRow(
            index: 2,
            icon: CupertinoIcons.question_circle_fill,
            title: 'home.step2'.tr(),
            subtitle: p.quizDone
                ? 'home.step2Done'.tr(args: ['${p.quizScore ?? 0}', '${p.quizTotal ?? 10}'])
                : 'home.step2Hint'.tr(),
            state: p.quizDone ? _StepState.done : _StepState.ready,
            onTap: () => Get.toNamed(Routes.quiz),
          ),
          _StepRow(
            index: 3,
            icon: CupertinoIcons.leaf_arrow_circlepath,
            emoji: home.mission?.icon,
            title: home.mission?.title(lang) ?? 'home.step3'.tr(),
            subtitle: p.missionDone
                ? 'home.step3Done'.tr()
                : 'home.step3Hint'.tr(args: ['${home.mission?.points ?? 20}']),
            state: p.missionDone ? _StepState.done : _StepState.ready,
            onTap: () => Get.toNamed(Routes.mission),
            last: true,
          ),
        ],
      ),
    );
  }
}

enum _StepState { locked, ready, done }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onTap,
    this.emoji,
    this.last = false,
  });

  final int index;
  final IconData icon;
  final String? emoji;
  final String title;
  final String subtitle;
  final _StepState state;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final locked = state == _StepState.locked;
    final done = state == _StepState.done;
    return Pressable(
      scale: 0.985,
      onTap: locked
          ? () => showToast(subtitle, icon: CupertinoIcons.lock_fill)
          : done && index == 3   // stories and quizzes can be repeated; the mission is once a day
              ? () => showToast('home.alreadyDone'.tr())
              : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.separator, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: done ? c.brand : (locked ? c.fill : c.brandSoft),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: done
                  ? Icon(CupertinoIcons.checkmark_alt, color: c.onBrand, size: 21)
                  : emoji != null && !locked
                      ? Text(emoji!, style: const TextStyle(fontSize: 20))
                      : Icon(locked ? CupertinoIcons.lock_fill : icon, size: 19, color: locked ? c.tertiaryLabel : c.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headline.c(locked ? c.secondaryLabel : c.label).copyWith(
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: c.tertiaryLabel,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.footnote.c(c.secondaryLabel)),
                ],
              ),
            ),
            if (!locked && !done) Icon(CupertinoIcons.chevron_right, size: 16, color: c.tertiaryLabel),
          ],
        ),
      ),
    );
  }
}

class _ScanPromo extends StatelessWidget {
  const _ScanPromo();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => ShellController.to.select(2),
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF0C9F5C), Color(0xFF087A47)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('home.scanTitle'.tr(), style: AppText.title3.bold.c(Colors.white)),
                  const SizedBox(height: 4),
                  Text('home.scanBody'.tr(), style: AppText.subhead.c(Colors.white.withValues(alpha: 0.88))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(CupertinoIcons.camera_fill, size: 15, color: c.brand),
                      const SizedBox(width: 6),
                      Text('home.scanCta'.tr(), style: AppText.subhead.semibold.c(const Color(0xFF087A47))),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: const Icon(CupertinoIcons.viewfinder, color: Colors.white, size: 38),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonPulse(
        child: Column(children: [
          SkeletonBox(height: 84, radius: 20),
          SizedBox(height: 12),
          SkeletonBox(height: 250, radius: 20),
        ]),
      );
}
