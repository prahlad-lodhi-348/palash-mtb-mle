import 'dart:typed_data';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Runs the exported IndicTrans2 ONNX graphs (encoder, decoder_step_initial,
/// decoder_step_cached) with greedy decoding. Takes token ids in, returns
/// generated token ids (including the final EOS). Tokenizing is separate.
class OnnxSeq2Seq {
  final String modelDir;
  final int numLayers;
  final int eosId;
  final int decoderStartId;

  OnnxSeq2Seq({
    required this.modelDir,
    this.numLayers = 18,
    this.eosId = 2,
    this.decoderStartId = 2,
  });

  OrtSession? _enc;
  OrtSession? _decInit;
  OrtSession? _decCached;
  Set<String> _cachedInputs = {};

  int get _numPast => numLayers * 4;

  Future<void> load() async {
    if (_enc != null) return;
    final ort = OnnxRuntime();
    _enc = await ort.createSession('$modelDir/encoder.onnx');
    _decInit = await ort.createSession('$modelDir/decoder_step_initial.onnx');
    _decCached = await ort.createSession('$modelDir/decoder_step_cached.onnx');
    // The cached graph may have pruned encoder inputs; only send what it declares.
    _cachedInputs = _decCached!.inputNames.toSet();
  }

  Future<List<int>> generate(
    List<int> inputIds, {
    int maxNewTokens = 60,
    void Function(int step, int tokenId, int elapsedMs)? onStep,
  }) async {
    await load();
    final sw = Stopwatch()..start();
    final len = inputIds.length;

    final idsT = await OrtValue.fromList(Int64List.fromList(inputIds), [1, len]);
    final maskT = await OrtValue.fromList(
        Int64List.fromList(List<int>.filled(len, 1)), [1, len]);

    final encOuts =
        await _enc!.run({'input_ids': idsT, 'attention_mask': maskT});
    final encHidden = encOuts['encoder_hidden_states']!;
    await idsT.dispose();

    final generated = <int>[];
    var lastToken = decoderStartId;
    List<OrtValue>? past;

    try {
      for (var step = 0; step < maxNewTokens; step++) {
        final decIn = await OrtValue.fromList(
            Int64List.fromList([lastToken]), [1, 1]);

        final feed = <String, OrtValue>{
          'decoder_input_ids': decIn,
          'encoder_hidden_states': encHidden,
          'encoder_attention_mask': maskT,
        };
        Map<String, OrtValue> outs;
        if (past == null) {
          outs = await _decInit!.run(feed);
        } else {
          for (var i = 0; i < past.length; i++) {
            feed['past_in_$i'] = past[i];
          }
          feed.removeWhere((k, _) => !_cachedInputs.contains(k));
          outs = await _decCached!.run(feed);
        }
        await decIn.dispose();

        // Greedy: argmax over the vocab logits of this step.
        final logits = await outs['logits']!.asFlattenedList();
        var best = 0;
        var bestV = double.negativeInfinity;
        for (var i = 0; i < logits.length; i++) {
          final v = (logits[i] as num).toDouble();
          if (v > bestV) {
            bestV = v;
            best = i;
          }
        }
        await outs['logits']!.dispose();

        // Initial graph names its cache outputs past_N, cached graph past_out_N.
        final prefix = past == null ? 'past_' : 'past_out_';
        final newPast = <OrtValue>[
          for (var i = 0; i < _numPast; i++) outs['$prefix$i']!
        ];
        if (past != null) {
          for (final p in past) {
            await p.dispose();
          }
        }
        past = newPast;

        generated.add(best);
        lastToken = best;
        onStep?.call(step, best, sw.elapsedMilliseconds);
        if (best == eosId) break;
      }
    } finally {
      if (past != null) {
        for (final p in past) {
          await p.dispose();
        }
      }
      await encHidden.dispose();
      await maskT.dispose();
    }
    return generated;
  }

  Future<void> close() async {
    await _enc?.close();
    await _decInit?.close();
    await _decCached?.close();
    _enc = null;
    _decInit = null;
    _decCached = null;
  }
}
