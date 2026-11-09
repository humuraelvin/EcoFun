import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: c.brand,
    brightness: brightness,
    primary: c.brand,
    onPrimary: c.onBrand,
    surface: c.surface,
    error: c.danger,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    hoverColor: Colors.transparent,
    dividerColor: c.separator,
    textTheme: base.textTheme.apply(bodyColor: c.label, displayColor: c.label),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.brand,
      selectionColor: c.brand.withValues(alpha: 0.25),
      selectionHandleColor: c.brand,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: c.label,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.label, letterSpacing: -0.2),
      systemOverlayStyle: overlayStyle(brightness),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.tertiaryLabel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand, linearTrackColor: c.fill),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: c.brand,
      barBackgroundColor: c.background,
      scaffoldBackgroundColor: c.background,
      textTheme: CupertinoTextThemeData(
        primaryColor: c.brand,
        navLargeTitleTextStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: c.label),
        navTitleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: c.label),
      ),
    ),
  );
}

SystemUiOverlayStyle overlayStyle(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
