import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../core/theme/app_theme.dart';
import '../core/utils/app_lang.dart';
import '../core/utils/update_checker.dart';
import '../core/widgets/system_bars.dart';
import '../data/supa.dart';
import 'app_prefs.dart';
import 'news_controller.dart';
import 'notification_controller.dart';
import 'routes.dart';
import 'rw_localizations.dart';
import 'session_controller.dart';

class EcoFunApp extends StatelessWidget {
  const EcoFunApp({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = supa.auth.currentSession != null;
    final session = Get.isRegistered<SessionController>()
        ? SessionController.to
        : Get.put(SessionController(), permanent: true);
    final lang = context.locale.languageCode == 'rw' ? 'rw' : 'en';
    AppLang.code = lang; // every model getter and server call reads the language from here
    if (session.language.value != lang) {
      // Never mutate reactive state during build; apply right after this frame.
      if (!Get.isRegistered<NewsController>()) {
        session.language.value = lang;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => session.language.value = lang);
      }
    }

    return GetMaterialApp(
      title: 'EcoFun',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: [
        ...context.localizationDelegates,
        RwMaterialLocalizations.delegate,
        RwCupertinoLocalizations.delegate,
      ],
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 380),
      popGesture: true,
      getPages: Routes.pages,
      initialRoute: !AppPrefs.onboarded
          ? Routes.welcome
          : !signedIn
              ? Routes.login
              : AppPrefs.isAdmin
                  ? Routes.admin
                  : Routes.shell,
      onInit: () {
        Get.put(NewsController(), permanent: true);
        Get.put(NotificationController(), permanent: true);
        if (signedIn) session.start();
        // A moment after launch, offer a newer APK if one was published.
        Future<void>.delayed(const Duration(seconds: 2), UpdateChecker.check);
      },
      builder: (context, child) {
        final brightness = MediaQuery.platformBrightnessOf(context);
        // Keep text readable but stop extreme font scales from breaking layouts.
        final mq = MediaQuery.of(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle(brightness),
          child: MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25)),
            child: SystemBarGuard(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
