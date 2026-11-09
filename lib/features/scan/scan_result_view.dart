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
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/photos.dart';
import '../../core/widgets/states.dart';
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
                    WasteResultDetails(scan: scan),
                    if (scan.pointsAwarded > 0) ...[
                      const SizedBox(height: 12),
                      Text('scan.earned'.tr(args: ['${scan.pointsAwarded}']), style: AppText.subhead.semibold.c(c.brand)),
                    ],
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
