import 'package:flutter/material.dart';

/// EcoFun colour tokens, modelled on Apple's semantic system colours.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.fill,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.bio,
    required this.bioSoft,
    required this.nonBio,
    required this.nonBioSoft,
    required this.danger,
    required this.warning,
    required this.gold,
    required this.shadow,
  });

  final Color background; // grouped background
  final Color surface; // cards, rows
  final Color surfaceRaised; // sheets, bars
  final Color fill; // inputs, chips, skeletons
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;
  final Color brand;
  final Color brandSoft;
  final Color onBrand;
  final Color bio;
  final Color bioSoft;
  final Color nonBio;
  final Color nonBioSoft;
  final Color danger;
  final Color warning;
  final Color gold;
  final Color shadow;

  static const light = AppColors(
    background: Color(0xFFF2F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    fill: Color(0xFFE9EAE4),
    label: Color(0xFF111412),
    secondaryLabel: Color(0xFF6B706C),
    tertiaryLabel: Color(0xFFA2A6A2),
    separator: Color(0xFFDADCD6),
    brand: Color(0xFF0C9F5C),
    brandSoft: Color(0xFFDDF4E7),
    onBrand: Color(0xFFFFFFFF),
    bio: Color(0xFF16A34A),
    bioSoft: Color(0xFFDCFCE7),
    nonBio: Color(0xFFEA6A12),
    nonBioSoft: Color(0xFFFFEDD5),
    danger: Color(0xFFE5372B),
    warning: Color(0xFFF2A100),
    gold: Color(0xFFE6A700),
    shadow: Color(0x14000000),
  );

  static const dark = AppColors(
    background: Color(0xFF000000),
    surface: Color(0xFF1A1C1B),
    surfaceRaised: Color(0xFF232624),
    fill: Color(0xFF2C2F2D),
    label: Color(0xFFF4F6F3),
    secondaryLabel: Color(0xFFA0A6A1),
    tertiaryLabel: Color(0xFF6A706B),
    separator: Color(0xFF333734),
    brand: Color(0xFF2FD27F),
    brandSoft: Color(0xFF12301F),
    onBrand: Color(0xFF032313),
    bio: Color(0xFF34D364),
    bioSoft: Color(0xFF0F2E19),
    nonBio: Color(0xFFFF9F43),
    nonBioSoft: Color(0xFF3A2410),
    danger: Color(0xFFFF5146),
    warning: Color(0xFFFFC233),
    gold: Color(0xFFFFCC33),
    shadow: Color(0x00000000),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      fill: l(fill, other.fill),
      label: l(label, other.label),
      secondaryLabel: l(secondaryLabel, other.secondaryLabel),
      tertiaryLabel: l(tertiaryLabel, other.tertiaryLabel),
      separator: l(separator, other.separator),
      brand: l(brand, other.brand),
      brandSoft: l(brandSoft, other.brandSoft),
      onBrand: l(onBrand, other.onBrand),
      bio: l(bio, other.bio),
      bioSoft: l(bioSoft, other.bioSoft),
      nonBio: l(nonBio, other.nonBio),
      nonBioSoft: l(nonBioSoft, other.nonBioSoft),
      danger: l(danger, other.danger),
      warning: l(warning, other.warning),
      gold: l(gold, other.gold),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => AppColors.of(this);
}
