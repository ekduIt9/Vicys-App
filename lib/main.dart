import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'src/core/app_config.dart';
import 'src/services/firebase_backend.dart';
import 'src/vicys_app.dart';

/// Handles data notifications while the app process is backgrounded.
///
/// Firebase invokes this on a background isolate. Keep it top-level and avoid
/// UI or local-database access until Firebase initialization has completed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options:
        AppConfig.hasCloudConfiguration ? AppConfig.firebaseOptions : null,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.shouldInitializeFirebase) {
    await Firebase.initializeApp(
      options:
          AppConfig.hasCloudConfiguration ? AppConfig.firebaseOptions : null,
    );
    if (AppConfig.useFirebaseEmulators) {
      await FirebaseBackend.connectToEmulators(
        host: AppConfig.firebaseEmulatorHost,
      );
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const VicysApp());
}
