import 'package:flutter/widgets.dart';

import 'app_config.dart';
import 'app_mode.dart';
import 'auth_models.dart';
import 'repositories/app_data_repository.dart';
import 'repositories/local_app_data_repository.dart';

class AppSessionController extends ChangeNotifier {
  AppSessionController({
    required AppDataRepository repository,
  }) : _repository = repository;

  final AppDataRepository _repository;
  AppUser? _currentUser;
  bool _initialized = false;

  AppMode get mode => AppConfig.mode;
  bool get isCloudEnabled => mode == AppMode.hybridCloud;
  bool get isInitialized => _initialized;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  static AppSessionController localOnly() {
    return AppSessionController(
      repository: LocalAppDataRepository(),
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final savedUser = await _repository.loadCurrentUser();
    _currentUser = savedUser;

    if (_currentUser == null && !isCloudEnabled) {
      _currentUser = AppUser.localDemo(role: UserRole.admin);
      await _repository.saveCurrentUser(_currentUser);
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> signInLocalDemo({
    String displayName = 'Utilizator local',
    UserRole role = UserRole.admin,
  }) async {
    _currentUser = AppUser.localDemo(role: role).copyWith(
      displayName: displayName,
    );
    await _repository.saveCurrentUser(_currentUser);
    notifyListeners();
  }

  Future<void> signOut() async {
    if (!isCloudEnabled) {
      _currentUser = AppUser.localDemo(role: UserRole.admin);
      await _repository.saveCurrentUser(_currentUser);
      notifyListeners();
      return;
    }

    _currentUser = null;
    await _repository.saveCurrentUser(null);
    notifyListeners();
  }
}

class AppSessionScope extends InheritedNotifier<AppSessionController> {
  const AppSessionScope({
    super.key,
    required AppSessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSessionScope>();
    assert(scope != null, 'AppSessionScope not found in widget tree.');
    return scope!.notifier!;
  }
}
