import 'package:shared_preferences/shared_preferences.dart';

import '../constants/preferences_keys.dart';

class TermModePreferences {
  static bool _termIncludesDownPayment = false;
  static bool _loaded = false;

  static bool get cachedValue => _termIncludesDownPayment;

  static Future<bool> getTermIncludesDownPayment() async {
    if (!_loaded) {
      await _load();
    }
    return _termIncludesDownPayment;
  }

  static Future<void> setTermIncludesDownPayment(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PreferencesKeys.termIncludesDownPayment, value);
    _termIncludesDownPayment = value;
    _loaded = true;
  }

  static Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _termIncludesDownPayment =
        prefs.getBool(PreferencesKeys.termIncludesDownPayment) ?? false;
    _loaded = true;
  }
}
