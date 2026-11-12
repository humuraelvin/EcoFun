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
import '../../core/utils/image_utils.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/large_title_page.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/toast.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';
import '../scan/waste_widgets.dart';

/// Today's climate mission: photo proof (+ AI waste check when relevant) and a short story.
/// Saved to Supabase: the photo in the private `missions` bucket, the entry in `mission_completions`.
class MissionView extends StatefulWidget {
  const MissionView({super.key});

  @override
  State<MissionView> createState() => _MissionViewState();
}

class _MissionViewState extends State<MissionView> {
  final _story = TextEditingController();
  String? _photoPath;
  Uint8List? _photo;
  WasteScan? _scan;
  bool _scanning = false;
  String? _scanError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _story.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _story.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(Mission m) async {
    final path = await Get.toNamed(Routes.camera, arguments: {'hint': 'mission.cameraHint'.tr()});
    if (path is! String) return;
    setState(() {
      _photoPath = path;
      _photo = null;
      _scan = null;
      _scanError = null;
    });
    final bytes = await ImageUtils.compressForUpload(path);
    if (!mounted) return;
    setState(() => _photo = bytes);
    if (m.needsScan) _runScan(path);
  }

  Future<void> _runScan(String path) async {
    setState(() {
      _scanning = true;
      _scanError = null;
    });
    try {
      final aiBytes = await ImageUtils.compressForAi(path);
      final scan = await ScanRepository.classify(aiBytes, SessionController.to.language.value);
      if (mounted && path == _photoPath) setState(() => _scan = scan);
    } catch (e) {
      if (mounted) setState(() => _scanError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  bool get _canSubmit => _photo != null && _story.text.trim().length >= 3 && !_saving && !_scanning;

  Future<void> _submit(Mission m) async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final done = await MissionRepository.complete(story: _story.text.trim(), jpeg: _photo!, scanId: _scan?.id);
      HapticFeedback.heavyImpact();
      await SessionController.to.refreshHome();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: false,
        builder: (_) => _Celebration(points: done.points, streak: done.streak),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = SessionController.to;
    return Scaffold(
      backgroundColor: c.background,
      appBar: appTopBar(context, title: 'mission.title'.tr()),
      body: Obx(() {
        final home = session.home.value;
        final m = home?.mission;
        if (home == null) return const CenteredSpinner();
        if (m == null) {
          return MessageView(icon: CupertinoIcons.leaf_arrow_circlepath, title: 'mission.none'.tr());
        }
        final p = home.progress;
        if (p.missionDone) {
          return MessageView(
            icon: CupertinoIcons.checkmark_seal_fill,
            title: 'mission.doneTitle'.tr(),
            message: 'mission.doneBody'.tr(),
            actionLabel: 'mission.viewJourney'.tr(),
            onAction: () => Get.offNamed(Routes.history),
          );
        }
        return _form(c, m, session.language.value);
      }),
    );
  }

  Widget _form(AppColors c, Mission m, String lang) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 24),
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(18)),
                child: Text(m.icon, style: const TextStyle(fontSize: 28)),
              ),
              const Spacer(),
              Pill(label: '+${m.points} ${'common.pts'.tr()}', icon: CupertinoIcons.star_fill),
            ]),
            const SizedBox(height: 14),
            Text('mission.today'.tr().toUpperCase(), style: AppText.overline.c(c.brand)),
            const SizedBox(height: 4),
            Text(m.title(lang), style: AppText.title2.c(c.label)),
            const SizedBox(height: 6),
            Text(m.description(lang), style: AppText.callout.c(c.secondaryLabel)),
          ]),
        ),
        const SizedBox(height: 22),
        _StepLabel(n: 1, text: 'mission.photoStep'.tr()),
        const SizedBox(height: 10),
        Pressable(
          onTap: _saving ? null : () => _takePhoto(m),
          scale: 0.98,
          child: AspectRatio(
            aspectRatio: 16 / 11,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                border: _photoPath == null ? Border.all(color: c.separator, width: 1.2) : null,
              ),
              child: _photoPath == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(CupertinoIcons.camera_fill, size: 34, color: c.brand),
                      const SizedBox(height: 10),
                      Text('mission.addPhoto'.tr(), style: AppText.headline.c(c.label)),
                      const SizedBox(height: 2),
                      Text(
                        m.needsScan ? 'mission.addPhotoScan'.tr() : 'mission.addPhotoHint'.tr(),
                        textAlign: TextAlign.center,
                        style: AppText.footnote.c(c.secondaryLabel),
                      ),
                    ])
                  : Stack(fit: StackFit.expand, children: [
                      Image.file(File(_photoPath!), fit: BoxFit.cover, cacheWidth: 900, gaplessPlayback: true),
                      if (_scanning) const ScanningOverlay(),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(99)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(CupertinoIcons.camera_rotate, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text('mission.retake'.tr(), style: AppText.caption.semibold.c(Colors.white)),
                          ]),
                        ),
                      ),
                    ]),
            ),
          ),
        ),
        if (m.needsScan && _photoPath != null) ...[
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _scanning
                ? Row(children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: 10),
                    Text('scan.analysing'.tr(), style: AppText.subhead.c(c.secondaryLabel)),
                  ])
                : _scan != null
                    ? Pressable(
                        onTap: () => Get.toNamed(Routes.scanResult, arguments: {'scan': _scan}),
                        child: Row(children: [
                          Flexible(child: WasteChip(scan: _scan!)),
                          const SizedBox(width: 6),
                          Text('mission.details'.tr(), style: AppText.footnote.c(c.brand)),
                        ]),
                      )
                    : _scanError != null
                        ? Row(children: [
                            Expanded(child: Text(_scanError!, style: AppText.footnote.c(c.secondaryLabel))),
                            TextLink('common.tryAgain'.tr(), onTap: () => _runScan(_photoPath!)),
                          ])
                        : const SizedBox.shrink(),
          ),
        ],
        const SizedBox(height: 22),
        _StepLabel(n: 2, text: 'mission.storyStep'.tr()),
        const SizedBox(height: 10),
        AppTextField(
          controller: _story,
          placeholder: 'mission.storyHint'.tr(),
          maxLines: 6,
          minLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: _saving ? 'mission.saving'.tr() : 'mission.complete'.tr(args: ['${m.points}']),
          icon: CupertinoIcons.checkmark_alt,
          loading: _saving,
          onPressed: _canSubmit ? () => _submit(m) : null,
        ),
        const SizedBox(height: 10),
        Text('mission.privacy'.tr(), textAlign: TextAlign.center, style: AppText.caption.c(c.tertiaryLabel)),
      ],
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
        child: Text('$n', style: AppText.footnote.bold.c(c.onBrand)),
      ),
      const SizedBox(width: 10),
      Text(text, style: AppText.headline.c(c.label)),
    ]);
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({required this.points, required this.streak});
  final int points;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                child: Icon(CupertinoIcons.checkmark_alt, size: 54, color: c.onBrand),
              ),
            ),
            const SizedBox(height: 20),
            Text('mission.celebrateTitle'.tr(), textAlign: TextAlign.center, style: AppText.title1.c(c.label)),
            const SizedBox(height: 8),
            Text('mission.celebrateBody'.tr(), textAlign: TextAlign.center, style: AppText.callout.c(c.secondaryLabel)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Pill(label: '+$points ${'common.pts'.tr()}', icon: CupertinoIcons.star_fill),
              const SizedBox(width: 10),
              Pill(
                label: 'home.streakDays'.plural(streak),
                icon: CupertinoIcons.flame_fill,
                color: const Color(0xFFE07000),
              ),
            ]),
            const SizedBox(height: 26),
            AppButton(label: 'common.done'.tr(), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
