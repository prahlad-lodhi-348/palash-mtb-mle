import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'onnx_test_page.dart';
import 'tokenizer_test_page.dart';
import 'services/onnx_translation_service.dart';
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
  final TtsService _tts = HindiTtsService();
  final TranslationService _translator = HybridTranslationService();
  final TextEditingController _typedController = TextEditingController();

  String _detected = '';
  String _translated = '';
  String _transliteration = '';
  double _confidence = 0.0;
  List<String> _unknownWords = [];
  String _source = 'dict';
  bool _busy = false;
  bool _useTyping = false; // toggle between mic and keyboard input

  Future<void> _translateAndSpeak(String hindiText) async {
    setState(() {
      _busy = true;
      _unknownWords = [];
    });

    final r = await _translator.translateHindiToSanthali(hindiText);

    setState(() {
      _detected = hindiText;
      _translated = r.translated;
      _transliteration = r.transliteration;
      _confidence = r.confidence;
      _unknownWords = r.unknownWords;
      _source = r.source;
      _busy = false;
    });

    if (r.isFullyTranslated && r.hasSpeakableAudio) {
      await _tts.speak(r.transliteration);
    }
  }

  Future<void> _runMicOnce() async {
    setState(() {
      _busy = true;
      _detected = 'Listening...';
      _unknownWords = [];
    });
    final h = await _stt.listenOnce();
    await _translateAndSpeak(h);
  }

  void _runTyped() {
    final text = _typedController.text.trim();
    if (text.isEmpty) return;
    _translateAndSpeak(text);
  }

  Future<void> _playTranslation() async {
    try {
      await _tts.speakTranslation(
        _translated,
        transliteration: _transliteration,
      );
    } on StateError catch (error) {
      _showTtsError(error.message);
    } on PlatformException catch (error) {
      _showTtsError(
        error.message ?? 'Check the device text-to-speech settings.',
      );
    }
  }

  Future<void> _playHindi() async {
    try {
      await _tts.speak(_detected);
    } on StateError catch (error) {
      _showTtsError(error.message);
    } on PlatformException catch (error) {
      _showTtsError(
        error.message ?? 'Check the device text-to-speech settings.',
      );
    }
  }

  void _showTtsError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not play translated audio: $message')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Translation Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'ONNX test',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OnnxTestPage())),
          ),
          IconButton(
            icon: const Icon(Icons.rule),
            tooltip: 'Tokenizer test',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TokenizerTestPage())),
          ),
        ],
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mic / keyboard toggle
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('🎤 Mic'),
                    selected: !_useTyping,
                    onSelected: (_) => setState(() => _useTyping = false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('⌨️ Type'),
                    selected: _useTyping,
                    onSelected: (_) => setState(() => _useTyping = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_useTyping) ...[
              ElevatedButton.icon(
                onPressed: _busy ? null : _runMicOnce,
                icon: Icon(_busy ? Icons.hourglass_empty : Icons.mic),
                label: Text(
                  _busy ? 'Listening...' : 'Tap to speak (Hindi)',
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
              const SizedBox(height: 8),
              const Text(
                'Mic saaf awaaz na pakde toh "Type" tab use karein',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ] else ...[
              TextField(
                controller: _typedController,
                decoration: InputDecoration(
                  hintText: 'Hindi mein type karein...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(fontSize: 18),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _runTyped(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _busy ? null : _runTyped,
                icon: const Icon(Icons.translate),
                label: const Text('Translate', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

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
                    Row(
                      children: [
                        const Text('🎤 Hindi Input',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54)),
                        const Spacer(),
                        if (_detected.isNotEmpty && _detected != 'Listening...')
                          IconButton(
                            icon:
                                const Icon(Icons.volume_up, color: Colors.teal),
                            tooltip: 'Hindi sunein',
                            onPressed: _playHindi,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_detected, style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_source == 'onnx' && _translated.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI translation — dictionary mein verify nahi hai. Bharosa thoda kam rakhein.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🌿 Santhali (Ol Chiki)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54)),
                        const Spacer(),
                        if (_translated.isNotEmpty && _unknownWords.isEmpty)
                          IconButton(
                            icon:
                                const Icon(Icons.volume_up, color: Colors.teal),
                            tooltip:
                                'Santali sunein (Hindi voice approximation)',
                            onPressed: _playTranslation,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _translated.isEmpty ? '...' : _translated,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NotoSansOlChiki'),
                    ),
                    if (_transliteration.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '($_transliteration)',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
              if (_unknownWords.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dictionary mein nahi mila: ${_unknownWords.join(", ")}',
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  @override
  void dispose() {
    _typedController.dispose();
    super.dispose();
  }
}
