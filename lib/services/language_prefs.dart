import 'package:hive_flutter/hive_flutter.dart';

/// Persists the user's preferred definition and example languages.
class LanguagePrefs {
  static const _boxName = 'prefs';
  static const _defLangKey = 'definitionLanguage';
  static const _exLangKey = 'exampleLanguage';
  static const _uiLangKey = 'uiLanguage';

  static const List<String> supportedUiLanguages = ['English', '한국어'];

  static Future<Box> get _box => Hive.openBox(_boxName);

  static const List<String> supported = [
    'English',
    '한국어',
    '中文',
    '日本語',
    'Español',
    'Français',
    'Deutsch',
  ];

  static Future<String> getDefinitionLanguage() async {
    final box = await _box;
    return box.get(_defLangKey, defaultValue: 'English') as String;
  }

  /// Returns null when the user wants examples in the same language as the word.
  static Future<String?> getExampleLanguage() async {
    final box = await _box;
    return box.get(_exLangKey) as String?;
  }

  static Future<void> setDefinitionLanguage(String lang) async {
    final box = await _box;
    await box.put(_defLangKey, lang);
  }

  /// Pass null to use the same language as the input word.
  static Future<void> setExampleLanguage(String? lang) async {
    final box = await _box;
    if (lang == null) {
      await box.delete(_exLangKey);
    } else {
      await box.put(_exLangKey, lang);
    }
  }

  static Future<String> getUiLanguage() async {
    final box = await _box;
    return box.get(_uiLangKey, defaultValue: 'English') as String;
  }

  static Future<void> setUiLanguage(String lang) async {
    final box = await _box;
    await box.put(_uiLangKey, lang);
  }
}
