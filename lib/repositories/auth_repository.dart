import 'package:firebase_auth/firebase_auth.dart';

import '../data/mock_api.dart';
import '../models/entities.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String email, String password);
  Future<UserEntity> register(String name, String email, String password);
  Future<void> forgotPassword(String email);
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<UserEntity> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception('ไม่พบข้อมูลผู้ใช้');
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
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception('สร้างบัญชีไม่สำเร็จ');
      await user.updateDisplayName(name.trim());
      await user.reload();
      return _entity(_auth.currentUser ?? user, fallbackName: name.trim());
    } on FirebaseAuthException catch (error) {
      throw Exception(_message(error));
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw Exception(_message(error));
    }
  }

  UserEntity _entity(User user, {String? fallbackName}) => UserEntity(
        id: user.uid,
        name: (user.displayName?.trim().isNotEmpty ?? false)
            ? user.displayName!.trim()
            : (fallbackName?.isNotEmpty ?? false)
                ? fallbackName!
                : (user.email?.split('@').first ?? 'User'),
        email: user.email ?? '',
      );

  String _message(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'อีเมลไม่ถูกต้อง';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้งานแล้ว';
      case 'weak-password':
        return 'รหัสผ่านไม่ปลอดภัยเพียงพอ';
      case 'too-many-requests':
        return 'มีการลองเข้าสู่ระบบมากเกินไป กรุณาลองใหม่ภายหลัง';
      case 'network-request-failed':
        return 'ไม่สามารถเชื่อมต่อ Firebase ได้';
      case 'operation-not-allowed':
        return 'ยังไม่ได้เปิด Email/Password ใน Firebase Authentication';
      default:
        return error.message ?? error.code;
    }
  }
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this.api);
  final MockApi api;

  @override
  Future<UserEntity> login(String email, String password) =>
      api.login(email, password);

  @override
  Future<UserEntity> register(String name, String email, String password) =>
      api.register(name, email, password);

  @override
  Future<void> forgotPassword(String email) => api.forgotPassword(email);
}
