import 'dart:convert';
import 'stt_service.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class VoskSttService implements SttService {
  final String modelAssetPath; // e.g. 'assets/models/vosk-model-small-hi-0.22.zip'
  final int sampleRate;

  VoskSttService({required this.modelAssetPath, this.sampleRate = 16000});

  late final VoskFlutterPlugin _vosk;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _vosk = VoskFlutterPlugin.instance();

    final modelPath = await ModelLoader().loadFromAssets(modelAssetPath);
    _model = await _vosk.createModel(modelPath);
    _recognizer = await _vosk.createRecognizer(
      model: _model!,
      sampleRate: sampleRate,
    );
    _speechService = await _vosk.initSpeechService(_recognizer!);
    _initialized = true;
  }

  @override
  Future<String> listenOnce() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw Exception('Microphone permission denied');
    }

    if (!_initialized) {
      await init();
    }

    final completer = _Completer<String>();
    final sub = _speechService!.onResult().listen((resultJson) {
      final text = _extractText(resultJson);
      if (text.isNotEmpty) {
        completer.complete(text);
      }
    });

    await _speechService!.start();
    // Simple fixed-window listen; replace with silence-detection later.
    await Future.delayed(const Duration(seconds: 4));
    await _speechService!.stop();
    await sub.cancel();

    return completer.isCompleted ? completer.value : '';
  }

  String _extractText(String resultJson) {
    try {
      final parsed = jsonDecode(resultJson);
      return (parsed['text'] as String?)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> dispose() async {
    await _speechService?.stop();
    _initialized = false;
  }
}

// Small helper since Dart's Completer can't be read before completion
class _Completer<T> {
  T? _value;
  bool isCompleted = false;
  void complete(T v) {
    if (!isCompleted) {
      _value = v;
      isCompleted = true;
    }
  }
  T get value => _value as T;
}
// import 'stt_service.dart';
// import 'package:permission_handler/permission_handler.dart';

// Future<bool> requestMicPermission() async {
//   final status = await Permission.microphone.request();
//   return status.isGranted;
// }
// /// Vosk STT integration wrapper.
// ///
// /// This file provides a minimal `VoskSttService` class that currently falls
// /// back to `StubSttService`. Replace the `listenOnce` implementation with a
// /// real Vosk plugin call when adding the native model and plugin.
// /// See `android_app/android_vosk_integration.md` for platform setup steps.
// class VoskSttService implements SttService {
//   final String modelAssetPath;

//   VoskSttService({required this.modelAssetPath});

//   /// Initialize model/resources if needed.
//   Future<void> init() async {
//     // TODO: load Vosk model from assets or file system.
//   }

//   @override
//   Future<String> listenOnce() async {
//     // TODO: Replace this stubbed behavior with actual Vosk recognition.
//     // For now, delegate to the stub so the app can run without native setup.
//     return StubSttService().listenOnce();
//   }

//   /// Dispose/cleanup resources if required by the plugin
//   Future<void> dispose() async {
//     // TODO: cleanup
//   }
// }
