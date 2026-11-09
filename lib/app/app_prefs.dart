import 'package:shared_preferences/shared_preferences.dart';

/// Tiny settings read before the first frame (so admins open straight into the admin portal).
abstract final class AppPrefs {
  static SharedPreferences? _prefs;
  static bool _isAdmin = false;

  static bool get isAdmin => _isAdmin;

  static Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isAdmin = _prefs!.getBool('is_admin') ?? false;
    } catch (_) {}
  }

  static Future<void> setAdmin(bool value) async {
    _isAdmin = value;
    try {
      await (_prefs ??= await SharedPreferences.getInstance()).setBool('is_admin', value);
    } catch (_) {}
  }
}
