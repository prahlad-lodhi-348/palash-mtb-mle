/// Simple TTS service interface and a local stub implementation.
abstract class TtsService {
  /// Speak the provided text (returns when speaking completes).
  Future<void> speak(String text);
}

class StubTtsService implements TtsService {
  @override
  Future<void> speak(String text) async {
    // Simulate speaking delay.
    await Future.delayed(const Duration(milliseconds: 500));
    // For the stub we just print to console so logs show audio output.
    // In a real integration, this would call Piper or another TTS engine.
    // ignore: avoid_print
    print('TTS speaking: $text');
  }
}
