import 'package:flutter/services.dart' show rootBundle;

/// Simple translation service interface and a small offline dictionary stub.
abstract class TranslationService {
  /// Translate Hindi text to Santhali (Ol Chiki) or return best-effort string.
  Future<TranslationResult> translateHindiToSanthali(String hindi);
}

class TranslationResult {
  final String translated;
  final double confidence; // 0.0 - 1.0

  TranslationResult(this.translated, this.confidence);
}

class StubTranslationService implements TranslationService {
  // Maps loaded from asset CSV
  static final Map<String, String> _dict = {};
  static final Map<String, double> _conf = {};
  static bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final csv = await rootBundle.loadString('assets/dictionaries/hindi_santhali_500.csv');
      final lines = csv.split(RegExp(r'\r?\n'));
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.isEmpty) continue;
        final hindi = parts[0].trim();
        final santhali = parts.length > 1 ? parts[1].trim() : '';
        double conf = 0.0;
        if (parts.length > 2) {
          try {
            conf = double.parse(parts[2].trim());
          } catch (_) {
            conf = santhali.isNotEmpty ? 1.0 : 0.0;
          }
        } else {
          conf = santhali.isNotEmpty ? 1.0 : 0.0;
        }
        _dict[hindi] = santhali;
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
    final tokens = hindi.split(RegExp(r'[\s,।?]+'));
    final translatedTokens = <String>[];
    double totalConf = 0.0;
    for (final t in tokens) {
      final san = _dict[t];
      if (san != null && san.isNotEmpty) {
        translatedTokens.add(san);
        totalConf += (_conf[t] ?? 1.0);
      } else {
        translatedTokens.add(t);
      }
    }
    final out = translatedTokens.join(' ');
    final conf = tokens.isEmpty ? 0.0 : (totalConf / tokens.length).clamp(0.0, 1.0);
    return TranslationResult(out, conf);
  }
}
