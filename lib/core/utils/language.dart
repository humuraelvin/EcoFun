import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/session_controller.dart';
import 'app_lang.dart';

/// Switches the whole app to [code] ('en' or 'rw'): every screen, the news, quizzes, scans,
/// notifications and the emails EcoFun sends (the choice is saved on the member's account).
Future<void> applyLanguage(BuildContext context, String code) async {
  final locale = code == 'rw' ? const Locale('rw', 'RW') : const Locale('en', 'US');
  AppLang.code = code;
  await context.setLocale(locale);
  Get.updateLocale(locale);
  if (Get.isRegistered<SessionController>()) {
    final session = SessionController.to;
    session.language.value = code; // reloads news, syncs the account language
    if (session.home.value != null) session.refreshHome();
  }
}
