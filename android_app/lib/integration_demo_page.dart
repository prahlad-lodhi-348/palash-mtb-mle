import 'package:flutter/material.dart';
import 'services/stt_service.dart';
import 'services/tts_service.dart';
import 'services/translation_service.dart';

class IntegrationDemoPage extends StatefulWidget {
  const IntegrationDemoPage({super.key});

  @override
  State<IntegrationDemoPage> createState() => _IntegrationDemoPageState();
}

class _IntegrationDemoPageState extends State<IntegrationDemoPage> {
  final SttService _stt = StubSttService();
  final TtsService _tts = StubTtsService();
  final TranslationService _translator = StubTranslationService();

  String _detected = '';
  String _translated = '';
  double _confidence = 0.0;
  bool _busy = false;

  Future<void> _runOnce() async {
    setState(() => _busy = true);
    final h = await _stt.listenOnce();
    final r = await _translator.translateHindiToSanthali(h);
    setState(() {
      _detected = h;
      _translated = r.translated;
      _confidence = r.confidence;
      _busy = false;
    });
    await _tts.speak(_translated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integration Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _runOnce,
              icon: const Icon(Icons.mic),
              label: Text(_busy ? 'Listening...' : 'Simulate Record'),
            ),
            const SizedBox(height: 16),
            Text('Detected (Hindi): $_detected'),
            const SizedBox(height: 8),
            Text('Translated (Santhali ol-chiki): $_translated'),
            const SizedBox(height: 8),
            Text('Confidence: ${(_confidence * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }
}
