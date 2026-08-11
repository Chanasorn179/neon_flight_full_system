import 'package:flutter/foundation.dart';

class SettingsProvider extends ChangeNotifier {
  bool darkMode = false;
  bool notifications = true;

  void setDarkMode(bool value) {
    if (darkMode == value) return;
    darkMode = value;
    notifyListeners();
  }

  void setNotifications(bool value) {
    if (notifications == value) return;
    notifications = value;
    notifyListeners();
  }
}
