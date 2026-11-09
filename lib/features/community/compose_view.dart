import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/photo_picker.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/toast.dart';
import '../../data/repositories.dart';
import '../../data/supa.dart';

class ComposeView extends StatefulWidget {
  const ComposeView({super.key});

  @override
  State<ComposeView> createState() => _ComposeViewState();
}

class _ComposeViewState extends State<ComposeView> {
  final _caption = TextEditingController();
  String? _path;
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final p = await pickPhoto(context, hint: 'community.cameraHint'.tr());
    if (p != null) setState(() => _path = p);
  }

  Future<void> _post() async {
    if (_path == null || _posting) return;
    FocusScope.of(context).unfocus();
    setState(() => _posting = true);
    try {
      final bytes = await ImageUtils.compressForUpload(_path!, side: 1080, quality: 78);
      await CommunityRepository.create(bytes, _caption.text.trim());
      HapticFeedback.heavyImpact();
      showToast('community.posted'.tr());
      Get.back(result: true);
    } catch (e) {
      showToast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: TextButton(
          onPressed: Get.back,
          child: Text('common.cancel'.tr(), style: AppText.body.c(c.brand)),
        ),
        leadingWidth: 90,
        title: Text('community.newPost'.tr()),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Pressable(
            onTap: _posting ? null : _pick,
            scale: 0.98,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(22)),
                child: _path == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(CupertinoIcons.camera_fill, size: 40, color: c.brand),
                        const SizedBox(height: 10),
                        Text('community.addPhoto'.tr(), style: AppText.headline.c(c.label)),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text('community.addPhotoHint'.tr(), textAlign: TextAlign.center, style: AppText.footnote.c(c.secondaryLabel)),
                        ),
                      ])
                    : Image.file(File(_path!), fit: BoxFit.cover, cacheWidth: 1000),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _caption,
            placeholder: 'community.captionHint'.tr(),
            maxLines: 4,
            minLines: 2,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'community.share'.tr(),
            icon: CupertinoIcons.paperplane_fill,
            loading: _posting,
            onPressed: _path == null ? null : _post,
          ),
          const SizedBox(height: 10),
          Text('community.pointsInfo'.tr(), textAlign: TextAlign.center, style: AppText.caption.c(c.tertiaryLabel)),
        ],
      ),
    );
  }
}
