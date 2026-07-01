import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Configures Firebase SDK adapters that are shared by cloud repositories.
abstract final class FirebaseBackend {
  /// Redirects Firebase products to the local Emulator Suite.
  ///
  /// Call exactly once, immediately after `Firebase.initializeApp` and before
  /// any repository request. This changes process-wide SDK endpoints. Android
  /// emulators normally require host `10.0.2.2`; iOS simulators use `127.0.0.1`.
  /// FCM is excluded because Firebase does not provide a Messaging emulator.
  static Future<void> connectToEmulators({required String host}) async {
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }
}
