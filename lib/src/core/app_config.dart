import 'package:firebase_core/firebase_core.dart';

abstract final class AppConfig {
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const useFirebaseEmulators =
      bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static const firebaseEnabled = bool.fromEnvironment('FIREBASE_ENABLED');
  static const firebaseEmulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  static bool get hasCloudConfiguration =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static bool get shouldInitializeFirebase =>
      firebaseEnabled || useFirebaseEmulators || hasCloudConfiguration;

  /// Builds non-secret Firebase client options from compile-time definitions.
  ///
  /// Prefer generated `firebase_options.dart` for production flavor-specific
  /// builds. Missing required values throw before any network request is made.
  static FirebaseOptions get firebaseOptions {
    if (!hasCloudConfiguration) {
      throw StateError('Firebase is not configured for this build.');
    }
    return FirebaseOptions(
      apiKey: firebaseApiKey,
      appId: firebaseAppId,
      messagingSenderId: firebaseMessagingSenderId,
      projectId: firebaseProjectId,
      storageBucket:
          firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
    );
  }
}
