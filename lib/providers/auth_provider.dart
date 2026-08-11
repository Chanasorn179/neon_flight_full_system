import 'package:flutter/foundation.dart';
import '../models/entities.dart';
import '../repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.repository);
  final AuthRepository repository;
  UserEntity? currentUser;
  bool loading = false;
  String? error;
  bool rememberMe = true;

  Future<bool> login(String email, String password) async {
    loading = true; error = null; notifyListeners();
    try { currentUser = await repository.login(email, password); return true; }
    catch (e) { error = e.toString().replaceFirst('Exception: ', ''); return false; }
    finally { loading = false; notifyListeners(); }
  }

  Future<bool> register(String name, String email, String password) async {
    loading = true; error = null; notifyListeners();
    try { currentUser = await repository.register(name, email, password); return true; }
    catch (e) { error = e.toString().replaceFirst('Exception: ', ''); return false; }
    finally { loading = false; notifyListeners(); }
  }

  Future<bool> forgot(String email) async {
    loading = true; error = null; notifyListeners();
    try { await repository.forgotPassword(email); return true; }
    catch (e) { error = e.toString().replaceFirst('Exception: ', ''); return false; }
    finally { loading = false; notifyListeners(); }
  }

  void setRemember(bool value) { rememberMe = value; notifyListeners(); }
  void logout() { currentUser = null; notifyListeners(); }
}
