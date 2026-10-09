import 'package:firebase_auth/firebase_auth.dart';

import '../data/offline_mock_api.dart';
import '../models/travel_models.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String email, String password);

  Future<UserEntity> register(
    String name,
    String email,
    String password,
  );

  Future<void> forgotPassword(String email);
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<UserEntity> login(
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw Exception('auth_err_email_required');
    }

    if (password.isEmpty) {
      throw Exception('auth_err_password_required');
    }

    try {
      final credential =
          await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('auth_err_user_missing');
      }

      return _entity(user);
    } on FirebaseAuthException catch (error) {
      throw Exception(_message(error));
    }
  }

  @override
  Future<UserEntity> register(
    String name,
    String email,
    String password,
  ) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedName.isEmpty) {
      throw Exception('auth_err_name_required');
    }

    if (normalizedEmail.isEmpty) {
      throw Exception('auth_err_email_required');
    }

    if (password.length < 6) {
      throw Exception('auth_err_password_short');
    }

    try {
      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('auth_err_register_failed');
      }

      await user.updateDisplayName(normalizedName);
      await user.reload();

      return _entity(
        _auth.currentUser ?? user,
        fallbackName: normalizedName,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_message(error));
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw Exception('auth_err_email_required');
    }

    if (!_looksLikeEmail(normalizedEmail)) {
      throw Exception('auth_err_email_invalid');
    }

    try {
      await _auth.sendPasswordResetEmail(
        email: normalizedEmail,
      );
    } on FirebaseAuthException catch (error) {
      throw Exception(_message(error));
    }
  }

  bool _looksLikeEmail(String value) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(value);
  }

  UserEntity _entity(
    User user, {
    String? fallbackName,
  }) {
    final displayName = user.displayName?.trim() ?? '';

    return UserEntity(
      id: user.uid,
      name: displayName.isNotEmpty
          ? displayName
          : (fallbackName?.trim().isNotEmpty ?? false)
              ? fallbackName!.trim()
              : (user.email?.split('@').first ?? 'User'),
      email: user.email ?? '',
    );
  }

  /// Translation key for [error] (screens pass it through `tr`); unknown
  /// codes fall back to Firebase's own message, which `tr` shows as is.
  String _message(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'auth_err_email_invalid';

      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'auth_err_wrong_credentials';

      case 'email-already-in-use':
        return 'auth_err_email_in_use';

      case 'weak-password':
        return 'auth_err_weak_password';

      case 'too-many-requests':
        return 'auth_err_too_many';

      case 'network-request-failed':
        return 'auth_err_network';

      case 'operation-not-allowed':
        return 'auth_err_not_enabled';

      case 'missing-email':
        return 'auth_err_email_required';

      default:
        return error.message ?? 'auth_err_generic';
    }
  }
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this.api);

  final MockApi api;

  @override
  Future<UserEntity> login(
    String email,
    String password,
  ) {
    return api.login(email, password);
  }

  @override
  Future<UserEntity> register(
    String name,
    String email,
    String password,
  ) {
    return api.register(
      name,
      email,
      password,
    );
  }

  @override
  Future<void> forgotPassword(String email) {
    return api.forgotPassword(email);
  }
}
