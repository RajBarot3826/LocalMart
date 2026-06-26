import 'package:shared_preferences/shared_preferences.dart';

class ViewManager {
  static late SharedPreferences _prefs;
  static bool _initialized = false;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  static int getViews(String type, String id, int baseViews) {
    if (!_initialized) return baseViews;
    return baseViews + (_prefs.getInt('views_${type}_$id') ?? 0);
  }

  static Future<void> incrementView(String type, String id) async {
    if (!_initialized) await init();
    int current = _prefs.getInt('views_${type}_$id') ?? 0;
    await _prefs.setInt('views_${type}_$id', current + 1);
  }
}
