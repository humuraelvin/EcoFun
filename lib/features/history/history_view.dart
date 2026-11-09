import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/storage_service.dart';
import '../../data/supa.dart';

/// "My journey": every completed mission, newest first, grouped by month.
class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final _items = <MissionCompletion>[];
  final _scroll = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _more();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await MissionRepository.history();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list);
        _hasMore = list.length >= 30;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    if (_loadingMore || !_hasMore || _items.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final list = await MissionRepository.history(beforeDay: _items.last.day);
      if (mounted) {
        setState(() {
          _items.addAll(list);
          _hasMore = list.length >= 30;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final streak = SessionController.to.home.value?.streak ?? 0;
    final rows = <Widget>[];
    String? month;
    for (final m in _items) {
      final label = Fmt.monthYear(m.day);
      if (label != month) {
        month = label;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(label.toUpperCase(), style: AppText.overline.c(c.secondaryLabel)),
        ));
      }
      rows.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: HistoryRow(item: m)));
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'history.title'.tr()),
      body: _loading
          ? const CenteredSpinner()
          : _error != null
              ? MessageView.error(_error!, onRetry: _load)
              : _items.isEmpty
                  ? MessageView(
                      icon: CupertinoIcons.leaf_arrow_circlepath,
                      title: 'history.emptyTitle'.tr(),
                      message: 'history.emptyBody'.tr(),
                    )
                  : RefreshIndicator.adaptive(
                      onRefresh: _load,
                      child: ListView(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 24),
                        children: [
                          _Summary(count: _items.length, hasMore: _hasMore, streak: streak),
                          ...rows,
                          if (_loadingMore) const Padding(padding: EdgeInsets.all(16), child: CupertinoActivityIndicator()),
                        ],
                      ),
                    ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.hasMore, required this.streak});
  final int count;
  final bool hasMore;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = SessionController.to.home.value?.stats.missions ?? count;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Icon(CupertinoIcons.leaf_arrow_circlepath, color: c.brand, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Text('history.summary'.plural(total), style: AppText.headline.c(c.label)),
        ),
        Icon(CupertinoIcons.flame_fill, size: 18, color: const Color(0xFFFF8A00)),
        const SizedBox(width: 4),
        Text('$streak', style: AppText.headline.c(c.label)),
      ]),
    );
  }
}

class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.item});
  final MissionCompletion item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lang = SessionController.to.language.value;
    return Pressable(
      onTap: () => Get.toNamed(Routes.historyDetail, arguments: item),
      scale: 0.985,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 76, height: 76, child: StoragePhoto(bucket: Bucket.missions, path: item.imagePath, radius: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(item.mission?.icon ?? '🌱', style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.mission?.title(lang) ?? 'mission.title'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headline.c(c.label),
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text(item.story, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.subhead.c(c.secondaryLabel)),
              const SizedBox(height: 5),
              Text(
                '${Fmt.date(item.day)}  ·  +${item.pointsAwarded} ${'common.pts'.tr()}',
                style: AppText.caption.c(c.tertiaryLabel),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
