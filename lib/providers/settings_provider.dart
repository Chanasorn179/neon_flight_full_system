import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider() {
    _restore();
  }

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  bool darkMode = false;
  bool notifications = true;
  bool initialized = false;

  Future<void> _restore() async {
    try {
      darkMode = await _prefs.getBool('settings_dark_mode') ?? false;
      notifications = await _prefs.getBool('settings_notifications') ?? true;
    } catch (_) {
      // Keep defaults if local preferences cannot be read.
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  void setDarkMode(bool value) {
    if (darkMode == value) return;
    darkMode = value;
    notifyListeners();
    _prefs.setBool('settings_dark_mode', value);
  }

  void setNotifications(bool value) {
    if (notifications == value) return;
    notifications = value;
    notifyListeners();
    _prefs.setBool('settings_notifications', value);
  }
}
