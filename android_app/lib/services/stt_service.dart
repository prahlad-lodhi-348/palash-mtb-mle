import 'dart:async';

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

SttService createSttService() => StubSttService();
