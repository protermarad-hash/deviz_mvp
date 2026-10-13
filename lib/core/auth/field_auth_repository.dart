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

  /// `true` dacă utilizatorul trebuie să-și schimbe parola locală înainte de
  /// a continua (ex. contul de dezvoltare cu parola implicită).
  Future<bool> mustChangePassword(String userId);

  /// Schimbă parola LOCALĂ; întoarce `null` la succes sau mesajul de eroare.
  Future<String?> changeLocalPassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  });
}
