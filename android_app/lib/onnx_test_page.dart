import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'services/onnx_seq2seq.dart';

class OnnxTestPage extends StatefulWidget {
  const OnnxTestPage({super.key});
  @override
  State<OnnxTestPage> createState() => _OnnxTestPageState();
}

class _OnnxTestPageState extends State<OnnxTestPage> {
  // (sentence, input_ids from Python tokenizer, expected output ids from Python)
  static final _cases = <(String, List<int>, List<int>)>[
    ('बैठ जाओ', [8, 29925, 12387, 8344, 2], [90538, 67823, 31428, 2]),
    (
      'आज हम पानी के बारे में पढ़ेंगे',
      [8, 29925, 772, 293, 1550, 12, 445, 19, 7944, 3692, 2],
      [98109, 73054, 88706, 91479, 70985, 98883, 67823, 31428, 2]
    ),
  ];

  String _log = 'Tap "Run ONNX test"';
  bool _busy = false;

  void _add(String s) {
    debugPrint(s);
    setState(() => _log += '\n$s');
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _log = '';
    });
    try {
      final base = await getExternalStorageDirectory();
      final dir = '${base!.path}/onnx_int8';
      if (!await File('$dir/encoder.onnx').exists()) {
        _add('Model files not found in $dir (adb push them first)');
        return;
      }
      final gen = OnnxSeq2Seq(modelDir: dir);
      final loadSw = Stopwatch()..start();
      await gen.load();
      _add('Sessions loaded in ${loadSw.elapsedMilliseconds} ms');

      for (final c in _cases) {
        final sw = Stopwatch()..start();
        final ids = await gen.generate(c.$2,
            onStep: (s, t, ms) => debugPrint('  step $s: $t (${ms}ms)'));
        final ok = listEquals(ids, c.$3);
        _add('\n${c.$1}\n got:      $ids\n expected: ${c.$3}\n'
            ' ${ok ? "MATCH" : "DIFF"}  (${sw.elapsedMilliseconds} ms)');
      }
      await gen.close();
    } catch (e, st) {
      _add('ERROR: $e\n$st');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ONNX test'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _busy ? null : _run,
              child: Text(_busy ? 'Running...' : 'Run ONNX test'),
            ),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: SelectableText(_log))),
          ],
        ),
      ),
    );
  }
}
