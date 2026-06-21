import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_translations.dart';

/// Singleton that manages the app's current language.
/// All screens call `LocaleProvider.tr('key')` to get translated strings.
class LocaleProvider extends ChangeNotifier {
  // Singleton
  static final LocaleProvider instance = LocaleProvider._();
  LocaleProvider._();

  String _locale = 'en';

  /// Current language code (e.g., 'en', 'hi', 'gu')
  String get locale => _locale;

  /// Get the native name of the current language
  String get currentLanguageName =>
      AppTranslations.supportedLanguages[_locale] ?? 'English';

  /// Load saved language from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString('appLocale') ?? 'en';
  }

  /// Change the app language and persist
  Future<void> setLocale(String code) async {
    if (_locale == code) return;
    _locale = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLocale', code);
    notifyListeners();
  }

  /// Translate a key using the current locale
  static String tr(String key) {
    return AppTranslations.get(key, instance._locale);
  }
}
