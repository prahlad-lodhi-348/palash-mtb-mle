import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'services/indic_tokenizer.dart';

class TokenizerTestPage extends StatefulWidget {
  const TokenizerTestPage({super.key});
  @override
  State<TokenizerTestPage> createState() => _S();
}

class _S extends State<TokenizerTestPage> {
  String log = 'Running...';
  static const dir =
      '/sdcard/Android/data/com.palash.mtbmle/files/tokenizer_assets';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final sb = StringBuffer();
    try {
      final sw = Stopwatch()..start();
      final tok = await IndicTokenizer.load(dir);
      sb.writeln('load: ${sw.elapsedMilliseconds} ms');
      final fx = jsonDecode(await File('$dir/fixtures.json').readAsString())
          as List;
      int ok = 0, okDec = 0;
      for (final f in fx) {
        final exp = (f['input_ids'] as List).cast<int>();
        final got = tok.encode(f['hindi'] as String);
        if (got.toString() == exp.toString()) {
          ok++;
        } else {
          sb.writeln('ENC FAIL: ${f['hindi']}\n exp $exp\n got $got');
        }
        final dec = tok.decode((f['output_ids'] as List).cast<int>());
        if (dec == f['output_text']) {
          okDec++;
        } else {
          sb.writeln('DEC FAIL: ${f['hindi']}\n exp [${f['output_text'].toString().split('').map((c) => c.codeUnitAt(0)).join(',')}]\n exp ${f['output_text']}\n got $dec');
        }
      }
      sb.writeln('encode $ok/${fx.length}, decode $okDec/${fx.length}');
    } catch (e, st) {
      sb.writeln('ERROR: $e\n$st');
    }
    setState(() => log = sb.toString());
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('Tokenizer test')),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(12), child: SelectableText(log)),
      );
}
