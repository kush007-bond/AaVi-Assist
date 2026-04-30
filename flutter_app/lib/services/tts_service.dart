import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static bool _speaking = false;
  static Completer<void>? _speakCompleter;

  static bool get isSpeaking => _speaking;
  static String lastSpoken = '';

  static Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      _speaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _tts.setCancelHandler(() {
      _speaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _tts.setErrorHandler((msg) {
      _speaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _initialized = true;
  }

  /// Speak text. Returns a Future that completes when speech finishes.
  static Future<void> speak(String text) async {
    await init();
    // Cancel any ongoing speech first
    if (_speaking) {
      await _tts.stop();
      _speaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    }
    lastSpoken = text;
    _speaking = true;
    _speakCompleter = Completer<void>();
    await _tts.speak(text);
    // Wait for completion/cancel/error callback
    return _speakCompleter?.future ?? Future.value();
  }

  /// Speak and wait for completion before returning.
  /// Use this before starting the mic to avoid TTS bleeding into recognition.
  static Future<void> speakAndWait(String text) async {
    await speak(text);
  }

  /// Stop TTS immediately.
  static Future<void> stop() async {
    if (_speaking) {
      await _tts.stop();
      _speaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    }
  }
}
