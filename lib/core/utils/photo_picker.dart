import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:image_picker/image_picker.dart';

import '../../app/routes.dart';
import '../theme/app_colors.dart';
import '../widgets/cards.dart';

/// Action sheet: in-app camera or photo library. Returns a local file path.
Future<String?> pickPhoto(BuildContext context, {String? hint}) async {
  final c = context.colors;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GroupedSection(children: [
          GroupedRow(
            icon: CupertinoIcons.camera_fill,
            title: 'photo.take'.tr(),
            onTap: () => Navigator.pop(ctx, 'camera'),
            showChevron: false,
          ),
          GroupedRow(
            icon: CupertinoIcons.photo_fill_on_rectangle_fill,
            iconColor: const Color(0xFF0A84FF),
            title: 'photo.library'.tr(),
            onTap: () => Navigator.pop(ctx, 'gallery'),
            showChevron: false,
          ),
          GroupedRow(
            icon: CupertinoIcons.xmark,
            iconColor: c.secondaryLabel,
            title: 'common.cancel'.tr(),
            onTap: () => Navigator.pop(ctx),
            showChevron: false,
          ),
        ]),
      ),
    ),
  );
  if (choice == 'camera') {
    final path = await Get.toNamed(Routes.camera, arguments: hint == null ? null : {'hint': hint});
    return path is String ? path : null;
  }
  if (choice == 'gallery') {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
    return file?.path;
  }
  return null;
}
