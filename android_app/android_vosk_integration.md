Vosk integration guide (Android)
================================

This document explains how to integrate the Vosk offline speech recognition
engine into the Flutter Android app.

High-level steps
- Add a Vosk Flutter plugin (e.g. `vosk_flutter`) to `pubspec.yaml` and run
  `flutter pub get`.
- Download a small Hindi Vosk model (e.g. `vosk-model-small-hi-0.4`) from
  https://alphacephei.com/vosk/models and place it under
  `android_app/assets/models/vosk-model-small-hi-0.4` or on the Android
  filesystem.
- Add Android permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

- If bundling the model as an asset, ensure `flutter_assets` includes the
  model files (they will be packaged into the APK). Large models are better
  loaded from external storage; consider packaging a small model only.
- Implement the `VoskSttService` in Dart using the plugin's API. If no
  Flutter plugin fits your constraints, implement a platform channel to the
  Android native Vosk library (see plugin examples).

Testing
- Run the app on a real Android device or emulator with microphone access.
- Use the `IntegrationDemoPage` and replace `StubSttService` with
  `VoskSttService(modelAssetPath: 'assets/models/vosk-model-small-hi-0.4')`.

Performance notes
- Small Vosk models (tens of MB) run on CPU and can work on low-end
  devices; measure memory usage first.
- For better accuracy, use model-specific language/grammar configuration.

References
- Vosk models: https://alphacephei.com/vosk/models
- Example Flutter plugin: search `vosk_flutter` on pub.dev
