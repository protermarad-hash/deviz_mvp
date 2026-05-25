import 'package:flutter/material.dart';

import '../core/app_theme_preset.dart';
import '../core/company_profile.dart';

class DevizThemeController extends ChangeNotifier {
  DevizThemeController();

  CompanyProfile _profile = const CompanyProfile();

  CompanyProfile get profile => _profile;
  AppThemePreset get preset => _profile.appThemePreset;
  ThemeData get theme => buildAppTheme(preset);

  Future<void> initialize(Future<CompanyProfile> Function() loader) async {
    final loaded = await loader();
    _profile = loaded;
    notifyListeners();
  }

  void applyCompanyProfile(CompanyProfile profile) {
    _profile = profile;
    notifyListeners();
  }
}

class DevizThemeScope extends InheritedNotifier<DevizThemeController> {
  const DevizThemeScope({
    super.key,
    required DevizThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static DevizThemeController of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'DevizThemeScope not found in widget tree.');
    return scope!;
  }

  static DevizThemeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DevizThemeScope>()
        ?.notifier;
  }
}
