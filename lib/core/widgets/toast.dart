import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Compact floating banner, similar to iOS system notifications.
void showToast(String message, {String? title, bool error = false, IconData? icon}) {
  final ctx = Get.context;
  if (ctx == null) return;
  final c = AppColors.of(ctx);
  if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
  error ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
  Get.showSnackbar(GetSnackBar(
    snackPosition: SnackPosition.TOP,
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    borderRadius: 18,
    backgroundColor: c.surfaceRaised,
    boxShadows: const [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 8))],
    duration: const Duration(milliseconds: 2800),
    animationDuration: const Duration(milliseconds: 320),
    forwardAnimationCurve: Curves.easeOutCubic,
    isDismissible: true,
    dismissDirection: DismissDirection.up,
    icon: Icon(
      icon ?? (error ? CupertinoIcons.exclamationmark_circle_fill : CupertinoIcons.checkmark_circle_fill),
      color: error ? c.danger : c.brand,
      size: 26,
    ),
    shouldIconPulse: false,
    titleText: title == null ? null : Text(title, style: AppText.headline.c(c.label)),
    messageText: Text(message, style: AppText.subhead.c(title == null ? c.label : c.secondaryLabel)),
  ));
}
