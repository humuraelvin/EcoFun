import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;

import '../../app/app_prefs.dart';
import '../theme/app_colors.dart';
import 'cards.dart';

/// Switches the whole app between the light and dark look, and remembers the choice.
void setDarkMode(bool on) {
  final mode = on ? ThemeMode.dark : ThemeMode.light;
  HapticFeedback.selectionClick();
  AppPrefs.setThemeMode(mode);
  Get.changeThemeMode(mode);
}

/// Profile row: "Dark mode" with a switch. Starts from the phone's look until the member picks one.
class DarkModeRow extends StatelessWidget {
  const DarkModeRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GroupedRow(
      icon: dark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
      iconColor: dark ? const Color(0xFF5E5CE6) : const Color(0xFFFF9F0A),
      title: 'profile.darkMode'.tr(),
      showChevron: false,
      trailing: CupertinoSwitch(value: dark, activeTrackColor: c.brand, onChanged: setDarkMode),
      onTap: () => setDarkMode(!dark),
    );
  }
}
