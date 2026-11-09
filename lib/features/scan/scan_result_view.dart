import 'dart:async';
import 'dart:io';

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
import '../../core/utils/image_utils.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/storage_service.dart';
import '../../data/supa.dart';
import 'waste_widgets.dart';

/// Arguments: `{'path': String}` to analyse a new photo, or `{'scan': WasteScan}` to view a saved one.
class ScanResultView extends StatefulWidget {
  const ScanResultView({super.key});

  @override
  State<ScanResultView> createState() => _ScanResultViewState();
}

class _ScanResultViewState extends State<ScanResultView> {
  late final Map args = (Get.arguments as Map?) ?? const {};
  String? get _path => args['path'] as String?;
  WasteScan? _scan;
  Uint8List? _bytes;
  String? _error;
  int _tip = 0;
  Timer? _tipTimer;
  bool _disposing = false;
  String? _disposalFeedback; // AI feedback when the proof photo was not accepted

  static const _tips = ['scan.tip1', 'scan.tip2', 'scan.tip3', 'scan.tip4'];

  @override
  void initState() {
    super.initState();
    _scan = args['scan'] as WasteScan?;
    if (_scan == null && _path != null) _analyse();
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  Future<void> _analyse() async {
    setState(() => _error = null);
    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _tip = (_tip + 1) % _tips.length);
    });
    try {
      _bytes ??= await ImageUtils.compressForAi(_path!);
      if (mounted) setState(() {});
      final scan = await ScanRepository.classify(_bytes!, SessionController.to.language.value);
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _scan = scan);
      if (scan.pointsAwarded > 0) SessionController.to.refreshHome();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      _tipTimer?.cancel();
    }
  }

  /// Points come from disposing of the item properly: photograph it going into the right bin.
  Future<void> _dispose() async {
    final scan = _scan;
    if (scan == null || _disposing) return;
    final path = await Get.toNamed(Routes.camera, arguments: {'hint': 'scan.disposeHint'.tr()});
    if (path is! String || !mounted) return;
    setState(() {
      _disposing = true;
      _disposalFeedback = null;
    });
    try {
      final bytes = await ImageUtils.compressForAi(path);
      final r = await ScanRepository.confirmDisposal(scan.id, bytes, SessionController.to.language.value);
      if (!mounted) return;
      if (r.disposed) {
        HapticFeedback.heavyImpact();
        setState(() => _scan = scan.markDisposed(points: r.points, feedback: r.feedback));
        if (r.points > 0) {
          showToast('scan.disposedToast'.tr(args: ['${r.points}']), icon: CupertinoIcons.checkmark_seal_fill);
          SessionController.to.refreshHome();
        }
      } else {
        HapticFeedback.heavyImpact();
        setState(() => _disposalFeedback = r.feedback.isEmpty ? 'scan.disposeRejected'.tr() : r.feedback);
      }
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _disposing = false);
    }
  }

  Widget _disposalCard(AppColors c, WasteScan scan) {
    if (scan.disposed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.bioSoft, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Icon(CupertinoIcons.checkmark_seal_fill, color: c.bio, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                scan.disposalPoints > 0 ? 'scan.disposedTitle'.tr(args: ['${scan.disposalPoints}']) : 'scan.disposedNoPoints'.tr(),
                style: AppText.headline.c(c.label),
              ),
              if (scan.disposalFeedback.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(scan.disposalFeedback, style: AppText.footnote.c(c.secondaryLabel)),
              ],
            ]),
          ),
        ]),
      );
    }
    if (!scan.canDispose) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(CupertinoIcons.trash_fill, color: c.brand, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text('scan.disposeTitle'.tr(), style: AppText.headline.c(c.label))),
          Pill(label: '+3 ${'common.pts'.tr()}', icon: CupertinoIcons.star_fill, color: c.gold),
        ]),
        const SizedBox(height: 6),
        Text('scan.disposeBody'.tr(), style: AppText.subhead.c(c.secondaryLabel)),
        if (_disposalFeedback != null) ...[
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(CupertinoIcons.info_circle_fill, size: 17, color: c.danger),
            const SizedBox(width: 6),
            Expanded(child: Text(_disposalFeedback!, style: AppText.subhead.c(c.danger))),
          ]),
        ],
        const SizedBox(height: 12),
        AppButton(
          label: _disposing ? 'scan.disposeChecking'.tr() : 'scan.disposeCta'.tr(),
          icon: CupertinoIcons.camera_fill,
          loading: _disposing,
          onPressed: _dispose,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scan = _scan;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: scan == null ? 'scan.analysing'.tr() : 'scan.result'.tr()),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 3.4,
              child: Stack(fit: StackFit.expand, children: [
                if (_path != null)
                  Image.file(File(_path!), fit: BoxFit.cover, cacheWidth: 900, gaplessPlayback: true)
                else
                  StoragePhoto(bucket: Bucket.scans, path: scan?.imagePath),
                if (scan == null && _error == null) const ScanningOverlay(),
                if (scan != null)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(99)),
                      child: Text(Fmt.ago(scan.createdAt), style: AppText.caption.c(Colors.white)),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a), child: child),
            ),
            child: scan != null
                ? Column(key: const ValueKey('done'), children: [
                    _disposalCard(c, scan),
                    const SizedBox(height: 14),
                    WasteResultDetails(scan: scan),
                    const SizedBox(height: 18),
                    if (_path != null) ...[
                      AppButton(
                        label: 'scan.scanAnother'.tr(),
                        icon: CupertinoIcons.camera_fill,
                        onPressed: () async {
                          final path = await Get.toNamed(Routes.camera);
                          if (path is String) Get.offNamed(Routes.scanResult, arguments: {'path': path}, preventDuplicates: false);
                        },
                      ),
                      const SizedBox(height: 8),
                      AppButton(label: 'common.done'.tr(), kind: ButtonStyleKind.plain, onPressed: Get.back),
                    ],
                  ])
                : _error != null
                    ? MessageView.error(_error!, onRetry: _analyse)
                    : Column(key: const ValueKey('wait'), children: [
                        const CupertinoActivityIndicator(radius: 13),
                        const SizedBox(height: 14),
                        Text('scan.analysingBody'.tr(), textAlign: TextAlign.center, style: AppText.headline.c(c.label)),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _tips[_tip].tr(),
                            key: ValueKey(_tip),
                            textAlign: TextAlign.center,
                            style: AppText.subhead.c(c.secondaryLabel),
                          ),
                        ),
                      ]),
          ),
        ],
      ),
    );
  }
}
