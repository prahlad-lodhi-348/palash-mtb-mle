import 'package:flutter_tts/flutter_tts.dart';

abstract class TtsService {
  Future<void> speak(String text);
  Future<void> speakTranslation(
    String translated, {
    String transliteration = '',
  });
  Future<void> stop();
}

/// Speaks text using the device's built-in Hindi TTS voice.
/// Santali text is converted to a Devanagari pronunciation approximation when
/// a dedicated transliteration is not available.
class HindiTtsService implements TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _flutterTts.awaitSpeakCompletion(true);
    final hindiAvailable = await _flutterTts.isLanguageAvailable('hi-IN');
    if (hindiAvailable != true) {
      throw StateError(
        'Hindi text-to-speech is unavailable. Install or enable a Hindi '
        'speech voice in the device text-to-speech settings.',
      );
    }
    await _flutterTts.setLanguage('hi-IN');
    await _flutterTts.setSpeechRate(0.45); // slower for classroom clarity
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    _initialized = true;
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInitialized();
    final result = await _flutterTts.speak(text);
    if (result != 1) {
      throw StateError('The device could not start text-to-speech playback.');
    }
  }

  @override
  Future<void> speakTranslation(
    String translated, {
    String transliteration = '',
  }) {
    return speak(
      translationSpeechText(
        translated,
        transliteration: transliteration,
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}

String olChikiToDevanagari(String text) {
  const consonants = {
    'ᱛ': 'त',
    'ᱜ': 'ग',
    'ᱝ': 'ङ',
    'ᱞ': 'ल',
    'ᱠ': 'क',
    'ᱡ': 'ज',
    'ᱢ': 'म',
    'ᱣ': 'व',
    'ᱥ': 'स',
    'ᱦ': 'ह',
    'ᱧ': 'ञ',
    'ᱨ': 'र',
    'ᱪ': 'च',
    'ᱫ': 'द',
    'ᱬ': 'ण',
    'ᱭ': 'य',
    'ᱯ': 'प',
    'ᱰ': 'ड',
    'ᱱ': 'न',
    'ᱲ': 'ड़',
    'ᱴ': 'ट',
    'ᱵ': 'ब',
    'ᱶ': 'व',
    'ᱷ': 'ह',
  };
  const independentVowels = {
    'ᱚ': 'ऑ',
    'ᱟ': 'आ',
    'ᱤ': 'इ',
    'ᱩ': 'उ',
    'ᱮ': 'ए',
    'ᱳ': 'ओ',
  };
  const vowelMarks = {
    'ᱚ': 'ॉ',
    'ᱟ': 'ा',
    'ᱤ': 'ि',
    'ᱩ': 'ु',
    'ᱮ': 'े',
    'ᱳ': 'ो',
  };

  final output = StringBuffer();
  var previousWasConsonant = false;
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    final consonant = consonants[character];
    if (consonant != null) {
      if (previousWasConsonant) output.write('्');
      output.write(consonant);
      previousWasConsonant = true;
      continue;
    }

    final vowel = independentVowels[character];
    if (vowel != null) {
      output.write(
        previousWasConsonant ? vowelMarks[character]! : vowel,
      );
      previousWasConsonant = false;
      continue;
    }

    if (character == 'ᱸ') {
      output.write('ं');
      previousWasConsonant = false;
      continue;
    }

    if (character == 'ᱹ' || character == 'ᱺ') {
      continue;
    }

    if (character == 'ᱼ' || character == 'ᱽ' || character == 'ᱻ') {
      continue;
    }

    if (character == '᱾') {
      output.write('।');
      previousWasConsonant = false;
      continue;
    }

    output.write(character);
    previousWasConsonant = false;
  }
  return output.toString();
}

String translationSpeechText(
  String translated, {
  String transliteration = '',
}) {
  return transliteration.trim().isNotEmpty
      ? transliteration
      : olChikiToDevanagari(translated);
}

/// Fallback used when transliteration is missing — does nothing (silent).
class StubTtsService implements TtsService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> speakTranslation(
    String translated, {
    String transliteration = '',
  }) async {}

  @override
  Future<void> stop() async {}
}
