import 'package:easy_localization/easy_localization.dart';

/// Date formatting that works for both English and Kinyarwanda
/// (intl has no Kinyarwanda data, so month/day names come from translations).
abstract final class Fmt {
  static String _month(int m) => 'months.$m'.tr();
  static String _weekday(int d) => 'weekdays.$d'.tr();
  static String weekdayShort(DateTime d) => 'weekdaysShort.${d.weekday}'.tr();

  /// "Monday, 9 November"
  static String longDay(DateTime d) => '${_weekday(d.weekday)}, ${d.day} ${_month(d.month)}';

  /// "9 November 2026"
  static String date(DateTime d) => '${d.day} ${_month(d.month)} ${d.year}';

  /// "November 2026"
  static String monthYear(DateTime d) => '${_month(d.month)} ${d.year}';

  static String ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'time.now'.tr();
    if (diff.inMinutes < 60) return 'time.minutes'.tr(args: ['${diff.inMinutes}']);
    if (diff.inHours < 24) return 'time.hours'.tr(args: ['${diff.inHours}']);
    if (diff.inDays < 7) return 'time.days'.tr(args: ['${diff.inDays}']);
    return date(t);
  }

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'home.goodMorning'.tr();
    if (h < 18) return 'home.goodAfternoon'.tr();
    return 'home.goodEvening'.tr();
  }

  static String points(int p) => NumberFormat.decimalPattern('en').format(p);
}
