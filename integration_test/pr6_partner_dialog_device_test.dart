import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/lucrare_diurna_cazare_persist_test.dart' as persist;
import '../test/partner_worker_diurna_cazare_edit_test.dart' as partner;

/// PR #6 — rulează pe dispozitiv/emulator testele reale ale dialogului
/// partener și ale persistenței diurnă/cazare.
///
/// `flutter run -t test/...` folosește `LiveTestWidgetsFlutterBinding`, care
/// pe Android eșuează în aserțiuni de framework (rădăcină semantică 0×0 la
/// cadrul de încălzire, `debugFrameWasSentToEngine` în FrameTiming) fără
/// legătură cu codul testat. Binding-ul `integration_test` este cel suportat
/// pentru dispozitive.
///
/// Harness-ul nu inițializează Firebase (fără `main.dart`, fără
/// `FirebaseBootstrap`); garda de mai jos eșuează dacă vreo aplicație
/// Firebase există totuși în Dart. Rulați doar pe un emulator izolat de rețea.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('gardă izolare: nicio aplicație Firebase inițializată în Dart', () {
    expect(Firebase.apps, isEmpty);
  });

  group('partner_worker_diurna_cazare_edit_test', partner.main);
  group('lucrare_diurna_cazare_persist_test', persist.main);

  test('gardă izolare (final): nicio aplicație Firebase inițializată în Dart',
      () {
    expect(Firebase.apps, isEmpty);
  });
}
