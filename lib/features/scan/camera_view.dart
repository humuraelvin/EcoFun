import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/pressable.dart';

/// Full-screen in-app camera. Pops with the captured (or picked) file path.
/// Arguments (optional): `{'hint': String}`.
class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _ctrl;
  List<CameraDescription> _cameras = const [];
  int _camIndex = 0;
  FlashMode _flash = FlashMode.off;
  bool _capturing = false;
  bool _flashOverlay = false;
  bool _denied = false;
  String? _error;

  String get _hint => ((Get.arguments as Map?)?['hint'] as String?) ?? 'camera.hint'.tr();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _ctrl;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (ctrl != null) {
        _ctrl = null;
        if (mounted) setState(() {});
        ctrl.dispose();
      }
    } else if (state == AppLifecycleState.resumed && _ctrl == null) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
        final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
        _camIndex = back == -1 ? 0 : back;
      }
      if (_cameras.isEmpty) {
        setState(() => _error = 'camera.none'.tr());
        return;
      }
      final ctrl = CameraController(
        _cameras[_camIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      await ctrl.setFlashMode(_flash).catchError((_) {});
      await ctrl.lockCaptureOrientation(DeviceOrientation.portraitUp).catchError((_) {});
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _denied = false;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      if (e.code.startsWith('CameraAccess')) {
        setState(() => _denied = true);
      } else {
        setState(() => _error = 'camera.failed'.tr());
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'camera.failed'.tr());
    }
  }

  Future<void> _capture() async {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized || _capturing) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _capturing = true;
      _flashOverlay = true;
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _flashOverlay = false);
    });
    try {
      final file = await ctrl.takePicture();
      Get.back(result: file.path);
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
    if (file != null) Get.back(result: file.path);
  }

  Future<void> _toggleFlash() async {
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await _ctrl?.setFlashMode(next);
      HapticFeedback.selectionClick();
      setState(() => _flash = next);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    HapticFeedback.selectionClick();
    final old = _ctrl;
    setState(() {
      _ctrl = null;
      _camIndex = (_camIndex + 1) % _cameras.length;
    });
    await old?.dispose();
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _preview(),
            if (_ctrl != null) IgnorePointer(child: CustomPaint(painter: _FramePainter())),
            AnimatedOpacity(
              opacity: _flashOverlay ? 0.85 : 0,
              duration: const Duration(milliseconds: 90),
              child: const IgnorePointer(child: ColoredBox(color: Colors.white)),
            ),
            Positioned(
              top: pad.top + 8,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  CircleIconButton(
                    icon: CupertinoIcons.xmark,
                    onTap: Get.back,
                    background: Colors.black.withValues(alpha: 0.45),
                    foreground: Colors.white,
                    size: 40,
                  ),
                  const Spacer(),
                  if (_ctrl != null && _cameras[_camIndex].lensDirection == CameraLensDirection.back)
                    CircleIconButton(
                      icon: _flash == FlashMode.off ? CupertinoIcons.bolt_slash_fill : CupertinoIcons.bolt_fill,
                      onTap: _toggleFlash,
                      background: _flash == FlashMode.off ? Colors.black.withValues(alpha: 0.45) : const Color(0xFFFFD60A),
                      foreground: _flash == FlashMode.off ? Colors.white : Colors.black,
                      size: 40,
                    ),
                ],
              ),
            ),
            if (_ctrl != null)
              Positioned(
                left: 24,
                right: 24,
                top: pad.top + 72,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(99)),
                    child: Text(_hint, textAlign: TextAlign.center, style: AppText.subhead.semibold.c(Colors.white)),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: pad.bottom + 26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleIconButton(
                    icon: CupertinoIcons.photo_on_rectangle,
                    onTap: _pickFromGallery,
                    background: Colors.white.withValues(alpha: 0.18),
                    foreground: Colors.white,
                    size: 52,
                  ),
                  _Shutter(onTap: _ctrl == null ? null : _capture, busy: _capturing),
                  _cameras.length > 1
                      ? CircleIconButton(
                          icon: CupertinoIcons.arrow_2_circlepath,
                          onTap: _switchCamera,
                          background: Colors.white.withValues(alpha: 0.18),
                          foreground: Colors.white,
                          size: 52,
                        )
                      : const SizedBox(width: 52),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    if (_denied) return _PermissionNeeded(onRetry: _start, onGallery: _pickFromGallery);
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center, style: AppText.callout.c(Colors.white70)));
    }
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 14));
    }
    return LayoutBuilder(builder: (context, box) {
      // Fill the screen (crop) like the iOS Camera app.
      final previewRatio = 1 / ctrl.value.aspectRatio; // portrait width / height
      final screenRatio = box.maxWidth / box.maxHeight;
      final scale = previewRatio < screenRatio ? screenRatio / previewRatio : previewRatio / screenRatio;
      return ClipRect(
        child: Transform.scale(
          scale: scale,
          child: Center(child: AspectRatio(aspectRatio: previewRatio, child: RepaintBoundary(child: CameraPreview(ctrl)))),
        ),
      );
    });
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onTap, required this.busy});
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.9,
        haptic: false,
        child: Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(shape: BoxShape.circle, color: busy ? Colors.white54 : Colors.white),
            child: busy ? const CupertinoActivityIndicator() : null,
          ),
        ),
      );
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width * 0.74;
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.46), width: side, height: side);
    const len = 34.0;
    const r = 22.0;
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      // top-left
      ..moveTo(rect.left, rect.top + len)
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(Offset(rect.left + r, rect.top), radius: const Radius.circular(r))
      ..lineTo(rect.left + len, rect.top)
      // top-right
      ..moveTo(rect.right - len, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + r), radius: const Radius.circular(r))
      ..lineTo(rect.right, rect.top + len)
      // bottom-right
      ..moveTo(rect.right, rect.bottom - len)
      ..lineTo(rect.right, rect.bottom - r)
      ..arcToPoint(Offset(rect.right - r, rect.bottom), radius: const Radius.circular(r))
      ..lineTo(rect.right - len, rect.bottom)
      // bottom-left
      ..moveTo(rect.left + len, rect.bottom)
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - r), radius: const Radius.circular(r))
      ..lineTo(rect.left, rect.bottom - len);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PermissionNeeded extends StatelessWidget {
  const _PermissionNeeded({required this.onRetry, required this.onGallery});
  final VoidCallback onRetry;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.camera_fill, color: Colors.white, size: 46),
              const SizedBox(height: 16),
              Text('camera.permissionTitle'.tr(), textAlign: TextAlign.center, style: AppText.title3.c(Colors.white)),
              const SizedBox(height: 8),
              Text('camera.permissionBody'.tr(), textAlign: TextAlign.center, style: AppText.callout.c(Colors.white70)),
              const SizedBox(height: 22),
              AppButton(
                label: 'camera.openSettings'.tr(),
                onPressed: () async {
                  await openAppSettings();
                },
                expand: false,
              ),
              const SizedBox(height: 8),
              TextLink('camera.useGallery'.tr(), onTap: onGallery, color: Colors.white),
              TextLink('common.tryAgain'.tr(), onTap: onRetry, color: Colors.white70),
            ],
          ),
        ),
      );
}
