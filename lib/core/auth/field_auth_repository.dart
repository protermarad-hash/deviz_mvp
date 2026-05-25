import 'field_auth_models.dart';

abstract class FieldAuthRepository {
  String get authSourceLabel;

  Future<List<FieldAuthUser>> listUsers();
  Future<void> saveUser(FieldAuthUser user);

  Future<FieldAuthSession?> loadSession();
  Future<void> saveSession(FieldAuthSession? session);

  Future<FieldAuthUser?> login({
    required String email,
    required String password,
  });

  Future<void> logout();
}
