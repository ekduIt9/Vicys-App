import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Domain-facing notification state returned after requesting permission.
enum NotificationPermissionState { granted, provisional, denied }

/// Registers this device for Firebase Cloud Messaging.
abstract interface class NotificationService {
  /// Requests notification permission and stores the current FCM token.
  ///
  /// This may display an operating-system permission dialog and perform network
  /// I/O. It never logs or exposes the token to UI code.
  Future<NotificationPermissionState> registerCurrentDevice();

  /// Emits notification payloads received while the application is foregrounded.
  Stream<Map<String, dynamic>> get foregroundMessages;

  /// Removes the current device token during logout.
  Future<void> unregisterCurrentDevice();

  /// Releases token and foreground-message subscriptions.
  Future<void> dispose();
}

class FirebaseNotificationService implements NotificationService {
  FirebaseNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StreamController<Map<String, dynamic>> _foregroundController =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<String>? _tokenSubscription;
  String? _registeredToken;

  @override
  Stream<Map<String, dynamic>> get foregroundMessages =>
      _foregroundController.stream;

  /// Requests OS permission and persists the token under the signed-in profile.
  ///
  /// Firestore rules restrict writes to the owning user. Token refreshes replace
  /// the previous device document. If no user is signed in, permission can be
  /// granted but registration is deferred until this method is called again.
  @override
  Future<NotificationPermissionState> registerCurrentDevice() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );
    final state = _mapAuthorizationStatus(settings.authorizationStatus);
    if (state == NotificationPermissionState.denied) return state;

    _messageSubscription ??=
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _tokenSubscription ??= _messaging.onTokenRefresh.listen(_persistToken);
    final token = await _messaging.getToken();
    if (token != null) await _persistToken(token);
    return state;
  }

  /// Deletes only this device's registration and leaves other devices intact.
  ///
  /// Network failures surface to the caller so logout can retry cleanup.
  @override
  Future<void> unregisterCurrentDevice() async {
    final token = _registeredToken;
    final user = _auth.currentUser;
    if (token != null && user != null) {
      await _deviceDocument(user.uid, token).delete();
    }
    _registeredToken = null;
    await _messaging.deleteToken();
  }

  /// Cancels all listeners and closes the broadcast stream.
  @override
  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _foregroundController.close();
  }

  /// Stores a token without using it as a document path or logging it.
  ///
  /// Firestore performs network I/O and maintains its own offline retry queue.
  Future<void> _persistToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_registeredToken != null && _registeredToken != token) {
      await _deviceDocument(user.uid, _registeredToken!).delete();
    }
    await _deviceDocument(user.uid, token).set({
      'token': token,
      'platform': 'mobile',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _registeredToken = token;
  }

  /// Converts foreground Firebase messages into SDK-independent payloads.
  void _handleForegroundMessage(RemoteMessage message) {
    _foregroundController.add({
      ...message.data,
      if (message.notification?.title case final title?) 'title': title,
      if (message.notification?.body case final body?) 'body': body,
    });
  }

  /// Returns a private device document whose ID is a deterministic token hash.
  DocumentReference<Map<String, dynamic>> _deviceDocument(
    String userId,
    String token,
  ) {
    final safeId = sha256.convert(utf8.encode(token)).toString();
    return _firestore
        .collection('profiles')
        .doc(userId)
        .collection('devices')
        .doc(safeId);
  }

  NotificationPermissionState _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) =>
      switch (status) {
        AuthorizationStatus.authorized =>
          NotificationPermissionState.granted,
        AuthorizationStatus.provisional =>
          NotificationPermissionState.provisional,
        _ => NotificationPermissionState.denied,
      };
}
