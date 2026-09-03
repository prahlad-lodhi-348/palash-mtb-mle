import 'dart:async';

/// Simple STT service interface and a local stub implementation.
abstract class SttService {
  /// Start listening and return recognized text when available.
  Future<String> listenOnce();
}

class StubSttService implements SttService {
  @override
  Future<String> listenOnce() async {
    // Simulate a short recording + recognition delay.
    await Future.delayed(const Duration(seconds: 1));
    // Return a sample Hindi phrase for demo purposes.
    return 'नमस्ते, कैसे हो?';
  }
}
