import 'package:flutter/foundation.dart';

import '../models/entities.dart';
import '../repositories/auth_repository.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.repository);

  final AuthRepository repository;

  UserEntity? currentUser;

  bool loading = false;
  String? error;
  bool rememberMe = true;

  Future<bool> login(
    String email,
    String password,
  ) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      currentUser = await repository.login(
        email,
        password,
      );

      final user = currentUser!;

      await FirebaseService.saveUser(
        id: user.id,
        name: user.name,
        email: user.email,
      );

      return true;
    } catch (e) {
      error = _cleanError(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
  ) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      currentUser = await repository.register(
        name,
        email,
        password,
      );

      final user = currentUser!;

      await FirebaseService.saveUser(
        id: user.id,
        name: user.name,
        email: user.email,
      );

      return true;
    } catch (e) {
      error = _cleanError(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> forgot(String email) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await repository.forgotPassword(email);
      return true;
    } catch (e) {
      error = _cleanError(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void setRemember(bool value) {
    rememberMe = value;
    notifyListeners();
  }

  /// Reflects a saved profile name in the signed-in user.
  void updateName(String name) {
    final user = currentUser;
    if (user == null || name.trim().isEmpty) return;
    currentUser = UserEntity(id: user.id, name: name.trim(), email: user.email);
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    error = null;
    notifyListeners();
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();
  }
}
