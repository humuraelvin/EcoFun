import 'package:eco_step/core/util/style/colors.dart';
import 'package:eco_step/core/util/style/typography.dart';
import 'package:eco_step/core/util/app_state_manager.dart';
import 'package:eco_step/features/climate_mission/domain/waste_classifier.dart';
import 'package:eco_step/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dart:io';

class ClimateMissionPage extends StatefulWidget {
  const ClimateMissionPage({super.key});

  @override
  ClimateMissionPageState createState() => ClimateMissionPageState();
}

class ClimateMissionPageState extends State<ClimateMissionPage> {
  final TextEditingController _storyController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _hasSelectedPhoto = false;
  bool _isClassifying = false;
  WasteClassification? _classification;
  String? _classificationError;

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.5),
          child: Container(color: colors.gray40, height: 2.5),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
                    buildTodoSection(colors),
                    const SizedBox(height: 30),
                    buildContentSection(colors),
                    const SizedBox(height: 38),
                    buildPhotoSection(colors),
                    const SizedBox(height: 107),
                    buildCompleteButton(colors),
                    const SizedBox(height: 68),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHeader(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: SvgPicture.asset(
              Assets.icons.arrowBack.path,
              width: 12,
              height: 22,
              colorFilter: ColorFilter.mode(colors.gray900, BlendMode.srcIn),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTodoSection(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Todo",
          style: Typo.bodyStrong(context, color: colors.gray900),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.gray30,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            "Using Tumblr",
            style: Typo.bodyStrong(context, color: colors.gray900),
          ),
        ),
      ],
    );
  }

  Widget buildContentSection(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Content", style: Typo.bodyStrong(context, color: colors.gray900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.gray30,
            borderRadius: BorderRadius.circular(5),
          ),
          child: TextField(
            controller: _storyController,
            maxLines: 8,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: "Please describe your story (up to 1,000 characters)",
              hintStyle: Typo.bodyRegular(context, color: colors.gray200),
              border: InputBorder.none,
              counterStyle: Typo.footnoteRegular(
                context,
                color: colors.gray200,
              ),
            ),
            cursorColor: colors.gray900,
            style: Typo.bodyRegular(context, color: colors.gray900),
          ),
        ),
      ],
    );
  }

  Widget buildPhotoSection(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Photo (select 1)",
              style: Typo.bodyStrong(context, color: colors.gray900),
            ),
            const SizedBox(height: 4),
            Text(
              "Upload a photo.",
              style: Typo.footnoteRegular(context, color: colors.gray200),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _takePicture,
          child: Container(
            decoration: _selectedImage != null
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    image: DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: 161,
                      height: 161,
                    ),
                  )
                : SvgPicture.asset(
                    Assets.icons.addPhoto.path,
                    width: 102.13,
                    height: 100,
                  ),
          ),
        ),
        const SizedBox(height: 14),
        if (_isClassifying)
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Classifying image…'),
            ],
          )
        else if (_classification != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _classification!.type == WasteType.biodegradable
                  ? colors.primary.withValues(alpha: 0.12)
                  : colors.negative.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _classification!.displayName,
                  style: Typo.bodyStrong(context, color: colors.gray900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Item: ${_classification!.detectedLabel}',
                  style: Typo.footnoteRegular(context, color: colors.gray700),
                ),
                if (_classification!.reason.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _classification!.reason,
                    style: Typo.footnoteRegular(context, color: colors.gray700),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  'AI image estimate. Check local waste guidance before disposal.',
                  style: Typo.footnoteRegular(context, color: colors.gray700),
                ),
              ],
            ),
          )
        else if (_classificationError != null)
          Text(
            _classificationError!,
            style: Typo.footnoteRegular(context, color: colors.gray700),
          ),
      ],
    );
  }

  Widget buildCompleteButton(ThemeColors colors) {
    final bool canComplete =
        _storyController.text.isNotEmpty && _hasSelectedPhoto;

    return GestureDetector(
      onTap: canComplete ? handleComplete : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: canComplete ? colors.primary : colors.gray30,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          "Completed",
          style: Typo.titleStrong(
            context,
            color: canComplete ? colors.background : colors.gray200,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void handleComplete() {
    final colors = ThemeColors.of(context);

    AppStateManager.completeMission();
    Get.back();
    Get.snackbar(
      'Mission complete!',
      'You completed today’s climate mission.',
      backgroundColor: colors.primary,
      colorText: colors.background,
    );
  }

  Future<void> _takePicture() async {
    final colors = ThemeColors.of(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    if (source == ImageSource.camera) {
      var cameraStatus = await Permission.camera.status;
      if (cameraStatus.isDenied) {
        cameraStatus = await Permission.camera.request();
      }

      if (cameraStatus.isPermanentlyDenied) {
        Get.dialog(
          AlertDialog(
            title: const Text('Camera permission required'),
            content: const Text(
              'Camera access is required to take a photo. Allow access in Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Get.back();
                  openAppSettings();
                },
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        return;
      }

      // Show a message when camera permission is still denied.
      if (!cameraStatus.isGranted) {
        Get.snackbar(
          'Permission required',
          'Camera permission is required.',
          backgroundColor: colors.negative,
          colorText: colors.background,
        );
        return;
      }
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _hasSelectedPhoto = true;
          _classification = null;
          _classificationError = null;
          _isClassifying = true;
        });
        try {
          final result = await WasteClassifier.classifyFile(image.path);
          if (!mounted) return;
          setState(() {
            _classification = result;
            _classificationError = result.type == WasteType.uncertain
                ? 'Could not identify this item confidently. Try a clear photo of one item.'
                : null;
            if (result.type == WasteType.uncertain) _classification = null;
          });
        } catch (_) {
          if (!mounted) return;
          setState(
            () => _classificationError =
                'Could not analyze the photo. Try again.',
          );
        } finally {
          if (mounted) setState(() => _isClassifying = false);
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not take the photo: $e',
        backgroundColor: colors.negative,
        colorText: colors.background,
      );
    }
  }
}
