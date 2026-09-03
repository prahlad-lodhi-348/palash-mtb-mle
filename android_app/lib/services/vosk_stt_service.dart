import 'stt_service.dart';

/// Vosk STT integration wrapper.
///
/// This file provides a minimal `VoskSttService` class that currently falls
/// back to `StubSttService`. Replace the `listenOnce` implementation with a
/// real Vosk plugin call when adding the native model and plugin.
/// See `android_app/android_vosk_integration.md` for platform setup steps.
class VoskSttService implements SttService {
  final String modelAssetPath;

  VoskSttService({required this.modelAssetPath});

  /// Initialize model/resources if needed.
  Future<void> init() async {
    // TODO: load Vosk model from assets or file system.
  }

  @override
  Future<String> listenOnce() async {
    // TODO: Replace this stubbed behavior with actual Vosk recognition.
    // For now, delegate to the stub so the app can run without native setup.
    return StubSttService().listenOnce();
  }

  /// Dispose/cleanup resources if required by the plugin
  Future<void> dispose() async {
    // TODO: cleanup
  }
}
