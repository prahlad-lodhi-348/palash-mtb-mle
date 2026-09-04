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
  final SttService _stt = createSttService();
  final TtsService _tts = StubTtsService();
  final TranslationService _translator = StubTranslationService();

  String _detected = '';
  String _translated = '';
  double _confidence = 0.0;
  bool _busy = false;

  Future<void> _runOnce() async {
    setState(() {
      _busy = true;
      _detected = 'Processing...';
    });

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
      appBar: AppBar(
        title: const Text('Voice Translation Demo'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _runOnce,
              icon: Icon(_busy ? Icons.hourglass_empty : Icons.mic),
              label: Text(
                _busy ? 'Processing...' : 'Simulate Hindi Speech',
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_detected.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎤 Hindi Input',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text(_detected, style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🌿 Santhali (Ol Chiki)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text(
                      _translated.isEmpty ? '...' : _translated,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'NotoSansOlChiki'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _confidence,
                backgroundColor: Colors.grey.shade200,
                color: Colors.teal,
              ),
              const SizedBox(height: 4),
              Text(
                'Confidence: ${(_confidence * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
