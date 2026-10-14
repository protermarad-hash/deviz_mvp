import 'dart:async';

import 'package:devizpro_ultra/core/auth/field_auth_models.dart';
import 'package:devizpro_ultra/core/auth/field_auth_service.dart';
import 'package:devizpro_ultra/core/auth/field_local_auth_repository.dart';
import 'package:devizpro_ultra/features/auth/field_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Login controlat de test: prima încercare e respinsă imediat, a doua
/// rămâne „în verificare” până la completarea manuală.
class _SlowRepo extends FieldLocalAuthRepository {
  int calls = 0;
  final pending = Completer<FieldAuthUser?>();

  @override
  Future<FieldAuthUser?> login({
    required String email,
    required String password,
  }) {
    calls++;
    return calls == 1 ? Future.value(null) : pending.future;
  }
}

void main() {
  testWidgets(
      'eroarea încercării anterioare dispare când începe o nouă autentificare',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _SlowRepo();
    final service = FieldAuthService(repo);
    await tester.pumpWidget(MaterialApp(home: FieldLoginPage(authService: service)));

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'birou@test.qa');
    await tester.enterText(find.widgetWithText(TextFormField, 'Parolă'), 'gresita-QA');
    await tester.tap(find.text('Login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Email sau parolă invalidă.'), findsOneWidget);

    // A doua încercare (parola corectă) — verificarea durează.
    await tester.enterText(find.widgetWithText(TextFormField, 'Parolă'), 'corecta-QA');
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(service.isLoading, isTrue);
    expect(find.text('Email sau parolă invalidă.'), findsNothing,
        reason: 'mesajul vechi nu trebuie să pară rezultatul noii încercări');

    repo.pending.complete(const FieldAuthUser(
        id: 'u1',
        name: 'Birou',
        email: 'birou@test.qa',
        role: FieldUserRole.office,
        active: true));
    await tester.pumpAndSettle();
    expect(service.isAuthenticated, isTrue);
    expect(find.text('Email sau parolă invalidă.'), findsNothing);
  });
}
