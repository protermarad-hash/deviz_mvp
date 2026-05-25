import '../cloud/firebase_bootstrap.dart';
import 'field_auth_repository.dart';
import 'field_firebase_auth_repository.dart';
import 'field_local_auth_repository.dart';

class FieldAuthRepositoryFactory {
  FieldAuthRepositoryFactory._();

  static FieldAuthRepository create() {
    if (!FirebaseBootstrap.isInitialized) {
      return FieldLocalAuthRepository();
    }
    return FieldFirebaseAuthRepository();
  }
}

