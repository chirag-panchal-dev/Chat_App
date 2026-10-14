import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/failure.dart';
import '../domain/account_deletion_repository.dart';

class CallableAccountDeletionRepository implements AccountDeletionRepository {
  CallableAccountDeletionRepository(this._functions, this._auth, this._db);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  @override
  Future<void> submitFeedback(DeletionReason reason, String? details) async {
    try {
      await _db.collection('deletionFeedback').add({
        'reason': reason.name,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Feedback must never block account deletion.
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      // Force a fresh ID token so `auth_time` reflects a just-completed
      // re-authentication.
      await _auth.currentUser?.getIdToken(true);
      await _functions.httpsCallable('deleteUserAccount').call<void>();
    } catch (e) {
      throw Failure.from(e);
    }
  }
}
