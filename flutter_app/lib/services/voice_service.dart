import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Possible voice commands the user can speak.
enum VoiceCommand {
  none,
  start,    // "start" / "begin" / "go"
  stop,     // "stop" / "pause" / "halt"
  indoor,   // "indoor" / "inside"
  outdoor,  // "outdoor" / "outside"
  openMap,  // "map" / "room"
  question, // anything else → immediate snapshot Q&A
}

class VoiceService {
  static final SpeechToText _speech = SpeechToText();
  static bool _initialized = false;
  static bool _listening = false;

  static bool get isListening => _listening;
  static bool get isAvailable => _initialized;

  /// Call once at startup. Returns true if speech recognition is available.
  static Future<bool> init() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onError: (e) => debugPrint('VoiceService error: ${e.errorMsg}'),
        onStatus: (s) => debugPrint('VoiceService status: $s'),
      );
    } catch (e) {
      debugPrint('VoiceService init failed: $e');
      _initialized = false;
    }
    return _initialized;
  }

  /// Start a listening session.
  /// [onPartial] fires with in-progress words.
  /// [onFinal] fires with the complete recognised utterance (once).
  /// [onDone] fires when the session ends (silence or timeout).
  static Future<void> startListening({
    void Function(String words)? onPartial,
    required void Function(String words) onFinal,
    void Function()? onDone,
  }) async {
    if (!_initialized || _listening) return;
    _listening = true;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _listening = false;
          onFinal(result.recognizedWords);
          onDone?.call();
        } else {
          onPartial?.call(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 8),
      // Short silence pause — snappier response, less waiting
      pauseFor: const Duration(milliseconds: 1200),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        // Dictation mode: fires result as soon as speech ends, no confirmation step
        listenMode: ListenMode.dictation,
      ),
    );
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

    if (_hasWord(lower, ['start', 'begin', 'go', 'activate', 'on'])) {
      return (VoiceCommand.start, null);
    }
    if (_hasWord(lower, ['stop', 'pause', 'halt', 'end', 'off', 'cancel'])) {
      return (VoiceCommand.stop, null);
    }
    if (_hasWord(lower, ['indoor', 'inside', 'interior', 'in door', 'indoors'])) {
      return (VoiceCommand.indoor, null);
    }
    if (_hasWord(lower, ['outdoor', 'outside', 'exterior', 'out door', 'outdoors'])) {
      return (VoiceCommand.outdoor, null);
    }
    if (_hasWord(lower, ['map', 'room map', 'mapping', 'show map', 'open map'])) {
      return (VoiceCommand.openMap, null);
    }
    // Everything else is a question to the AI
    return (VoiceCommand.question, speech.trim());
  }

  static bool _hasWord(String text, List<String> words) =>
      words.any((w) => text.contains(w));
}
