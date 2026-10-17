import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'indic_tokenizer.dart';
import 'onnx_seq2seq.dart';
import 'translation_service.dart';

/// Dictionary-first, ONNX-fallback translator.
/// Fast path: StubTranslationService (verified dictionary).
/// Fallback: on-device IndicTrans2 ONNX when the dictionary has gaps.
/// ONNX output has NO verified transliteration, so TTS stays silent for it
/// (native speaker verification is still pending — see project notes).
class HybridTranslationService implements TranslationService {
  final StubTranslationService _dict = StubTranslationService();
  IndicTokenizer? _tok;
  OnnxSeq2Seq? _onnx;
  bool _selfCheckDone = false;

  static const _selfCheckCases = [
    ('बैठ जाओ', [8, 29925, 12387, 8344, 2]),
    (
      'आज हम पानी के बारे में पढ़ेंगे',
      [8, 29925, 772, 293, 1550, 12, 445, 19, 7944, 3692, 2]
    ),
  ];

  Future<void> _ensureOnnxReady() async {
    if (_tok != null && _onnx != null) return;
    final base = await getExternalStorageDirectory();
    final root = base!.path;
    _tok = await IndicTokenizer.load('$root/tokenizer_assets');
    _onnx = OnnxSeq2Seq(modelDir: '$root/onnx_int8');
    await _onnx!.load();

    if (!_selfCheckDone) {
      _selfCheckDone = true;
      for (final c in _selfCheckCases) {
        final got = _tok!.encode(c.$1);
        final ok = listEquals(got, c.$2);
        debugPrint(ok
            ? 'tokenizer self-check OK: ${c.$1}'
            : 'tokenizer self-check MISMATCH for "${c.$1}"\n'
                '  expected: ${c.$2}\n  got:      $got\n'
                '  -> ONNX fallback output is UNRELIABLE until fixed.');
      }
    }
  }

  @override
  Future<TranslationResult> translateHindiToSanthali(String hindi) async {
    final dictResult = await _dict.translateHindiToSanthali(hindi);
    if (dictResult.isFullyTranslated) return dictResult;

    try {
      await _ensureOnnxReady();
      final inputIds = _tok!.encode(hindi);
      final outputIds = await _onnx!.generate(inputIds);
      final translated = _tok!.decode(outputIds);

      if (translated.isEmpty) return dictResult;

      return TranslationResult(
        translated,
        0.3,
        transliteration: '',
        unknownWords: const [],
        isFullPhraseMatch: false,
        source: 'onnx',
      );
    } catch (e, st) {
      debugPrint('ONNX fallback failed: $e\n$st');
      return dictResult;
    }
  }
}
