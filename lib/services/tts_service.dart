import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService instance = TtsService._();
  TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  static const Map<String, String> _langToLocale = {
    'English': 'en-US',
    '한국어': 'ko-KR',
    '中文': 'zh-CN',
    '日本語': 'ja-JP',
    'Español': 'es-ES',
    'Français': 'fr-FR',
    'Deutsch': 'de-DE',
  };

  Future<void> _init() async {
    if (_initialized) return;
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  Future<void> speak(String text, {String language = 'English'}) async {
    try {
      await _init();
      final locale = _langToLocale[language] ?? 'en-US';
      await _tts.setLanguage(locale);
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
