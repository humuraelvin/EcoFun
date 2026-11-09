import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/supa.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';

/// EcoFun is shared as an APK link (no Play Store), so the app checks Supabase for a newer
/// release and offers a one-tap update. Releases below `min_version_code` must update.
abstract final class UpdateChecker {
  static bool _checked = false;

  static Future<void> check({bool force = false}) async {
    if (!Platform.isAndroid || (_checked && !force)) return;
    _checked = true;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      final row = await supa.from('app_releases').select().eq('platform', 'android').maybeSingle();
      if (row == null) return;
      final latest = (row['version_code'] as num).toInt();
      if (latest <= current) return;

      final mustUpdate = current < ((row['min_version_code'] as num?)?.toInt() ?? 0);
      final prefs = await SharedPreferences.getInstance();
      final snoozeKey = 'update_snoozed_$latest';
      final snoozedAt = prefs.getInt(snoozeKey);
      if (!mustUpdate && snoozedAt != null &&
          DateTime.now().millisecondsSinceEpoch - snoozedAt < const Duration(hours: 24).inMilliseconds) {
        return;
      }

      final ctx = Get.context;
      if (ctx == null || !ctx.mounted) return;
      final lang = ctx.locale.languageCode;
      final notes = ((lang == 'rw' ? row['notes_rw'] : row['notes_en']) as String?)?.trim() ?? '';
      final later = await _show(
        ctx,
        versionName: row['version_name'] as String,
        notes: notes,
        url: row['download_url'] as String,
        mustUpdate: mustUpdate,
      );
      if (later == true) await prefs.setInt(snoozeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Offline or not set up yet: try again next launch.
      _checked = false;
    }
  }

  /// Returns true when the member chose "Later".
  static Future<bool?> _show(BuildContext context,
      {required String versionName, required String notes, required String url, required bool mustUpdate}) {
    final c = context.colors;
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: !mustUpdate,
      enableDrag: !mustUpdate,
      isScrollControlled: true,
      builder: (ctx) => PopScope(
        canPop: !mustUpdate,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.arrow_down_circle_fill, color: c.brand, size: 36),
                ),
              ),
              const SizedBox(height: 14),
              Text('update.title'.tr(), textAlign: TextAlign.center, style: AppText.title3.c(c.label)),
              const SizedBox(height: 4),
              Text(
                mustUpdate ? 'update.required'.tr(args: [versionName]) : 'update.body'.tr(args: [versionName]),
                textAlign: TextAlign.center,
                style: AppText.subhead.c(c.secondaryLabel),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('update.whatsNew'.tr(), style: AppText.footnote.semibold.c(c.secondaryLabel)),
                    const SizedBox(height: 4),
                    Text(notes, style: AppText.callout.c(c.label)),
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              AppButton(
                label: 'update.now'.tr(),
                icon: CupertinoIcons.arrow_down_to_line,
                onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              ),
              if (!mustUpdate) ...[
                const SizedBox(height: 6),
                AppButton(label: 'update.later'.tr(), kind: ButtonStyleKind.plain, onPressed: () => Navigator.pop(ctx, true)),
              ],
              const SizedBox(height: 4),
              Text('update.hint'.tr(), textAlign: TextAlign.center, style: AppText.caption.c(c.tertiaryLabel)),
            ]),
          ),
        ),
      ),
    );
  }
}
