import 'package:firebase_auth/firebase_auth.dart';

import '../data/mock_api.dart';
import '../models/entities.dart';

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
      throw Exception('กรุณากรอกอีเมล');
    }

    if (password.isEmpty) {
      throw Exception('กรุณากรอกรหัสผ่าน');
    }

    try {
      final credential =
          await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
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
      throw Exception('กรุณากรอกชื่อ');
    }

    if (normalizedEmail.isEmpty) {
      throw Exception('กรุณากรอกอีเมล');
    }

    if (password.length < 6) {
      throw Exception('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
    }

    try {
      final credential =
          await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('สร้างบัญชีไม่สำเร็จ');
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
      throw Exception('กรุณากรอกอีเมล');
    }

    if (!_looksLikeEmail(normalizedEmail)) {
      throw Exception('รูปแบบอีเมลไม่ถูกต้อง');
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

  String _message(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';

      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';

      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้งานแล้ว';

      case 'weak-password':
        return 'รหัสผ่านไม่ปลอดภัยเพียงพอ';

      case 'too-many-requests':
        return 'มีการร้องขอมากเกินไป กรุณาลองใหม่ภายหลัง';

      case 'network-request-failed':
        return 'ไม่สามารถเชื่อมต่อ Firebase ได้ กรุณาตรวจสอบอินเทอร์เน็ต';

      case 'operation-not-allowed':
        return 'ยังไม่ได้เปิด Email/Password ใน Firebase Authentication';

      case 'missing-email':
        return 'กรุณากรอกอีเมล';

      default:
        return error.message ?? 'เกิดข้อผิดพลาดในการยืนยันตัวตน';
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
