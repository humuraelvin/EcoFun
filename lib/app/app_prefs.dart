import 'package:shared_preferences/shared_preferences.dart';

/// Tiny settings read before the first frame (so admins open straight into the admin portal).
abstract final class AppPrefs {
  static SharedPreferences? _prefs;
  static bool _isAdmin = false;
  static bool _onboarded = false;

  static bool get isAdmin => _isAdmin;

  /// True once the member finished the first-launch onboarding (language choice).
  static bool get onboarded => _onboarded;

  static Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isAdmin = _prefs!.getBool('is_admin') ?? false;
      _onboarded = _prefs!.getBool('onboarded_v1') ?? false;
    } catch (_) {}
  }

  static Future<void> setAdmin(bool value) async {
    _isAdmin = value;
    try {
      await (_prefs ??= await SharedPreferences.getInstance()).setBool('is_admin', value);
    } catch (_) {}
  }

  static Future<void> setOnboarded() async {
    _onboarded = true;
    try {
      await (_prefs ??= await SharedPreferences.getInstance()).setBool('onboarded_v1', true);
    } catch (_) {}
  }
}
