import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'tts_service.dart';

/// Possible voice commands the user can speak.
enum VoiceCommand {
  none,
  start,       // "start" / "begin" / "go"
  stop,        // "stop" / "pause" / "halt"
  indoor,      // "indoor" / "inside"
  outdoor,     // "outdoor" / "outside"
  openMap,     // "map" / "room"
  navigate,    // "navigate" / "navigation" / "directions"
  settings,    // "settings" / "options" / "preferences"
  help,        // "help" / "commands" / "what can you do"
  status,      // "status" / "what's running" / "am i running"
  repeat,      // "repeat" / "say again" / "what did you say"
  emergency,   // "emergency" / "help me" / "SOS" / "call"
  question,    // anything else → immediate snapshot Q&A
}

class VoiceService {
  static final SpeechToText _speech = SpeechToText();
  static bool _initialized = false;
  static bool _listening = false;
  static int _consecutiveErrors = 0;
  static const int _maxRetries = 3;

  static bool get isListening => _listening;
  static bool get isAvailable => _initialized;

  /// Call once at startup. Returns true if speech recognition is available.
  static Future<bool> init() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onError: (e) {
          debugPrint('VoiceService error: ${e.errorMsg}');
          _listening = false;
          // Track consecutive errors for retry logic
          if (e.permanent) {
            _consecutiveErrors++;
          }
        },
        onStatus: (s) => debugPrint('VoiceService status: $s'),
      );
    } catch (e) {
      debugPrint('VoiceService init failed: $e');
      _initialized = false;
    }
    return _initialized;
  }

  /// Start a listening session.
  /// Automatically stops TTS first so the mic doesn't pick up the speaker.
  /// [onPartial] fires with in-progress words.
  /// [onFinal] fires with the complete recognised utterance (once).
  /// [onDone] fires when the session ends (silence or timeout).
  static Future<void> startListening({
    void Function(String words)? onPartial,
    required void Function(String words) onFinal,
    void Function()? onDone,
  }) async {
    if (!_initialized || _listening) return;

    // ── Stop TTS before opening the mic ──────────────────────────────────
    if (TtsService.isSpeaking) {
      await TtsService.stop();
      // Brief pause so audio output fully stops before mic opens
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _listening = true;
    _consecutiveErrors = 0;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _listening = false;
            _consecutiveErrors = 0; // successful recognition
            final words = result.recognizedWords.trim();
            if (words.isNotEmpty) {
              onFinal(words);
            }
            onDone?.call();
          } else {
            onPartial?.call(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 12),
        pauseFor: const Duration(milliseconds: 1800),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint('VoiceService listen failed: $e');
      _listening = false;
      _consecutiveErrors++;

      // Auto-retry if under max retries
      if (_consecutiveErrors < _maxRetries) {
        debugPrint('VoiceService: retrying (${_consecutiveErrors}/$_maxRetries)...');
        await Future.delayed(const Duration(milliseconds: 500));
        return startListening(onPartial: onPartial, onFinal: onFinal, onDone: onDone);
      } else {
        debugPrint('VoiceService: max retries reached, giving up');
        onDone?.call();
      }
    }
  }

  /// Stop a listening session early.
  static Future<void> stop() async {
    _listening = false;
    await _speech.stop();
  }

  /// Cancel without result.
  static Future<void> cancel() async {
    _listening = false;
    await _speech.cancel();
  }

  /// Parse recognised words into a [VoiceCommand].
  /// Returns the command and, if it's a question, the full question text.
  static (VoiceCommand, String?) parseCommand(String speech) {
    final lower = speech.toLowerCase().trim();
    if (lower.isEmpty) return (VoiceCommand.none, null);

    // Emergency — highest priority
    if (_hasPhrase(lower, ['help me', 'emergency', 'sos', 'call for help', 'call emergency'])) {
      return (VoiceCommand.emergency, null);
    }

    // Status check
    if (_hasPhrase(lower, ['status', "what's running", 'what is running', 'am i running', 'are you running', 'current status'])) {
      return (VoiceCommand.status, null);
    }

    // Help
    if (_hasPhrase(lower, ['what can you do', 'list commands', 'available commands']) ||
        (lower == 'help' || lower == 'commands')) {
      return (VoiceCommand.help, null);
    }

    // Repeat
    if (_hasWord(lower, ['repeat', 'say again', 'say that again', 'what did you say', 'come again'])) {
      return (VoiceCommand.repeat, null);
    }

    // Navigate
    if (_hasWord(lower, ['navigate', 'navigation', 'directions', 'guide me', 'show directions'])) {
      return (VoiceCommand.navigate, null);
    }

    // Settings
    if (_hasWord(lower, ['settings', 'options', 'preferences', 'configuration', 'configure'])) {
      return (VoiceCommand.settings, null);
    }

    // Start / Stop
    if (_hasWord(lower, ['start', 'begin', 'go', 'activate', 'turn on', 'switch on', 'resume'])) {
      return (VoiceCommand.start, null);
    }
    if (_hasWord(lower, ['stop', 'pause', 'halt', 'end', 'turn off', 'switch off', 'cancel', 'deactivate'])) {
      return (VoiceCommand.stop, null);
    }

    // Mode
    if (_hasWord(lower, ['indoor', 'inside', 'interior', 'in door', 'indoors'])) {
      return (VoiceCommand.indoor, null);
    }
    if (_hasWord(lower, ['outdoor', 'outside', 'exterior', 'out door', 'outdoors'])) {
      return (VoiceCommand.outdoor, null);
    }

    // Map
    if (_hasWord(lower, ['map', 'room map', 'mapping', 'show map', 'open map', 'scan room'])) {
      return (VoiceCommand.openMap, null);
    }

    // Everything else is a question to the AI
    return (VoiceCommand.question, speech.trim());
  }

  /// Returns a help string describing all available voice commands.
  static String get helpText =>
      'You can say: Start, Stop, Indoor, Outdoor, Navigate, Map, Settings, Status, Repeat, or ask any question about what you see.';

  static bool _hasWord(String text, List<String> words) =>
      words.any((w) => text.contains(w));

  static bool _hasPhrase(String text, List<String> phrases) =>
      phrases.any((p) => text.contains(p));
}
