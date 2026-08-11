import '../data/mock_api.dart';
import '../models/entities.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String email, String password);
  Future<UserEntity> register(String name, String email, String password);
  Future<void> forgotPassword(String email);
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this.api);
  final MockApi api;
  @override Future<UserEntity> login(String email, String password) => api.login(email, password);
  @override Future<UserEntity> register(String name, String email, String password) => api.register(name, email, password);
  @override Future<void> forgotPassword(String email) => api.forgotPassword(email);
}
