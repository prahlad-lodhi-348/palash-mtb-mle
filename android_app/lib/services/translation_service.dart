import 'package:flutter/services.dart' show rootBundle;

/// Translation service interface and offline dictionary implementation.
abstract class TranslationService {
  Future<TranslationResult> translateHindiToSanthali(String hindi);
}

class TranslationResult {
  final String translated; // Ol Chiki script — for display
  final String transliteration; // Devanagari approximation — for Hindi TTS to speak
  final double confidence;
  final List<String> unknownWords;
  final bool isFullPhraseMatch;
  final String source; // 'dict' or 'onnx' — which engine produced this

  TranslationResult(
    this.translated,
    this.confidence, {
    this.transliteration = '',
    this.unknownWords = const [],
    this.isFullPhraseMatch = false,
    this.source = 'dict',
  });

  bool get isFullyTranslated => unknownWords.isEmpty;
  bool get hasSpeakableAudio => transliteration.isNotEmpty;
}

class StubTranslationService implements TranslationService {
  static final Map<String, String> _dict = {}; // hindi -> ol chiki
  static final Map<String, String> _translit = {}; // hindi -> devanagari transliteration
  static final Map<String, double> _conf = {};
  static bool _loaded = false;

  static const String _dictionaryAsset =
      'assets/dictionaries/hindi_santhali_500.csv'; // TODO: rename once dictionary is actually expanded

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final csv = await rootBundle.loadString(_dictionaryAsset);
      final lines = csv.split(RegExp(r'\r?\n'));
      // Expected header: hindi,transliteration,santhali_ol_chiki,confidence
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length < 3) continue; // need at least hindi, translit, ol chiki

        final hindi = parts[0].trim();
        final translit = parts[1].trim();
        final santhali = parts[2].trim();
        double conf = santhali.isNotEmpty ? 1.0 : 0.0;
        if (parts.length > 3) {
          try {
            conf = double.parse(parts[3].trim());
          } catch (_) {}
        }

        _dict[hindi] = santhali;
        _translit[hindi] = translit;
        _conf[hindi] = conf;
      }
    } catch (e) {
      // ignore errors; leave maps empty
    }
    _loaded = true;
  }

  @override
  Future<TranslationResult> translateHindiToSanthali(String hindi) async {
    await _ensureLoaded();

    final trimmedInput = hindi.trim();

    // 1) Try exact full-phrase match first.
    final directMatch = _dict[trimmedInput];
    if (directMatch != null && directMatch.isNotEmpty) {
      return TranslationResult(
        directMatch,
        _conf[trimmedInput] ?? 1.0,
        transliteration: _translit[trimmedInput] ?? '',
        isFullPhraseMatch: true,
      );
    }

    // 2) Fall back to word-by-word lookup.
    final tokens = trimmedInput
        .split(RegExp(r'[\s,।?]+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return TranslationResult('', 0.0);
    }

    final translatedTokens = <String>[];
    final translitTokens = <String>[];
    final unknownWords = <String>[];
    double totalConf = 0.0;

    for (final t in tokens) {
      final san = _dict[t];
      if (san != null && san.isNotEmpty) {
        translatedTokens.add(san);
        translitTokens.add(_translit[t] ?? '');
        totalConf += (_conf[t] ?? 1.0);
      } else {
        unknownWords.add(t);
      }
    }

    final out = translatedTokens.join(' ');
    final translitOut = translitTokens.where((t) => t.isNotEmpty).join(' ');
    final conf = (totalConf / tokens.length).clamp(0.0, 1.0);

    return TranslationResult(
      out,
      conf,
      transliteration: translitOut,
      unknownWords: unknownWords,
    );
  }
}