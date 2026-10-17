import 'dart:async';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'stt_service.dart';

Future<bool> requestMicPermission() async {
  final status = await Permission.microphone.request();
  return status.isGranted;
}

class VoskSttService implements SttService {
  final String modelAssetPath;
  final int sampleRate;

  VoskSttService({required this.modelAssetPath, this.sampleRate = 16000});

  // Static on purpose: the native plugin allows only ONE SpeechService per
  // process, and every page rebuild creates a new VoskSttService object.
  static SpeechService? _speechService;
  static Future<void>? _initFuture;
  static bool _busy = false;

  Future<void> init() {
    return _initFuture ??= _doInit().catchError((Object e) {
      _initFuture = null; // allow a retry after a failure
      throw e;
    });
  }

  Future<void> _doInit() async {
    final vosk = VoskFlutterPlugin.instance();
    final modelPath = await ModelLoader().loadFromAssets(modelAssetPath);
    final model = await vosk.createModel(modelPath);
    final recognizer =
        await vosk.createRecognizer(model: model, sampleRate: sampleRate);
    _speechService = await vosk.initSpeechService(recognizer);
  }

  @override
  Future<String> listenOnce() async {
    if (_busy) return '';
    _busy = true;
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) throw Exception('Microphone permission denied');
      await init();

      final service = _speechService!;
      final completer = Completer<String>();
      final sub = service.onResult().listen((json) {
        final text = _extractText(json);
        if (text.isNotEmpty && !completer.isCompleted) completer.complete(text);
      });

      await service.start();
      await Future.delayed(const Duration(seconds: 4));
      await service.stop();
      await Future.delayed(const Duration(milliseconds: 300));
      await sub.cancel();

      return completer.isCompleted ? await completer.future : '';
    } finally {
      _busy = false;
    }
  }

  String _extractText(String resultJson) {
    try {
      final parsed = jsonDecode(resultJson);
      return (parsed['text'] as String?)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> dispose() async {} // shared for the whole process lifetime
}
