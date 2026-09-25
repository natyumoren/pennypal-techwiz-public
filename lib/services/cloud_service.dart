import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';

/// Optional Firebase backend (Authentication + Cloud Firestore).
///
/// PennyPal is offline-first: everything works against the local SQLite
/// database. When Firebase options are supplied at build time the app also
/// signs the student in to Firebase Auth and mirrors their records to
/// Firestore under `students/{localUserId}/{table}/{recordId}`.
class CloudService {
  CloudService._();
  static final instance = CloudService._();

  bool _ready = false;
  bool get isAvailable => _ready;

  Future<void> init() async {
    if (!AppConfig.cloudConfigured || _ready) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseSenderId,
          projectId: AppConfig.firebaseProjectId,
          authDomain: AppConfig.firebaseAuthDomain == ''
              ? null
              : AppConfig.firebaseAuthDomain,
          storageBucket: AppConfig.firebaseStorageBucket == ''
              ? null
              : AppConfig.firebaseStorageBucket,
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Firebase not initialised, running offline only: $e');
    }
  }

  /// Signs in to Firebase with the same credentials used locally, creating
  /// the Firebase account on first use. Failures are non-fatal.
  Future<void> signIn(String email, String password) async {
    if (!_ready) return;
    final auth = FirebaseAuth.instance;
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        try {
          await auth.createUserWithEmailAndPassword(
              email: email, password: password);
        } catch (e) {
          debugPrint('Firebase sign-up failed: $e');
        }
      } else {
        debugPrint('Firebase sign-in failed: ${e.code}');
      }
    } catch (e) {
      debugPrint('Firebase sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    if (_ready) await FirebaseAuth.instance.signOut();
  }

  bool get isSignedIn => _ready && FirebaseAuth.instance.currentUser != null;

  DocumentReference<Map<String, dynamic>> _doc(
      String? userId, String table, String recordId) {
    final db = FirebaseFirestore.instance;
    // Shared tables (content/settings) live at the top level.
    return userId == null
        ? db.collection(table).doc(recordId)
        : db.collection('students').doc(userId).collection(table).doc(recordId);
  }

  /// Upserts are idempotent (fixed document id), so retrying a queue entry
  /// never creates duplicates.
  Future<void> upsert(String? userId, String table, String recordId,
      Map<String, Object?> data) async {
    final clean = Map<String, Object?>.from(data)..remove('PasswordHash');
    await _doc(userId, table, recordId).set({
      ...clean,
      'ownerUid': FirebaseAuth.instance.currentUser?.uid,
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String? userId, String table, String recordId) =>
      _doc(userId, table, recordId).delete();
}
