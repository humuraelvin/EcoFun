import 'package:flutter/material.dart';

/// iOS Dynamic Type scale. No font family is set, so iPhones render San Francisco
/// and Android renders Roboto — the native system font on each platform.
abstract final class AppText {
  static const largeTitle = TextStyle(fontSize: 32, height: 1.18, fontWeight: FontWeight.w800, letterSpacing: -0.6);
  static const title1 = TextStyle(fontSize: 27, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const title2 = TextStyle(fontSize: 22, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.35);
  static const title3 = TextStyle(fontSize: 19, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: -0.25);
  static const headline = TextStyle(fontSize: 16.5, height: 1.32, fontWeight: FontWeight.w600, letterSpacing: -0.2);
  static const body = TextStyle(fontSize: 16.5, height: 1.42, fontWeight: FontWeight.w400, letterSpacing: -0.15);
  static const reading = TextStyle(fontSize: 17.5, height: 1.62, fontWeight: FontWeight.w400, letterSpacing: -0.1);
  static const callout = TextStyle(fontSize: 15.5, height: 1.35, fontWeight: FontWeight.w400, letterSpacing: -0.1);
  static const subhead = TextStyle(fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w400, letterSpacing: -0.08);
  static const footnote = TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w400, letterSpacing: -0.04);
  static const caption = TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w500, letterSpacing: 0);
  static const overline = TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 0.6);
  static const wordmark = TextStyle(fontFamily: 'ClimateCrisis', fontSize: 30, height: 1, letterSpacing: 0.3);
}

extension TextStyleX on TextStyle {
  TextStyle c(Color color) => copyWith(color: color);
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
}
