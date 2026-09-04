import 'dart:async';
import 'vosk_stt_service.dart';

abstract class SttService {
  Future<String> listenOnce();
}

class StubSttService implements SttService {
  @override
  Future<String> listenOnce() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'नमस्ते, कैसे हो?';
  }
}

SttService createSttService() => VoskSttService(
  modelAssetPath: 'assets/models/vosk-model-small-hi-0.22.zip',
);