// STUB versionat, in git — NU contine date Firebase reale.
//
// Fisierul REAL, cu credentialele proiectului Firebase izolat pentru
// clientul Costel Costea, exista NUMAI local, pe masina dezvoltatorului
// care construieste acel build — NICIODATA in git.
//
// De ce exista acest stub: `firebase_options_loader.dart` trebuie sa
// importe neconditionat aceasta clasa (Dart nu suporta import conditionat
// pe existenta unui fisier sau pe valoarea unui --dart-define). Fara acest
// stub, orice checkout curat (inclusiv CI) esueaza la `flutter analyze`/
// `flutter build`, desi build-ul normal (client implicit "proterm") NU are
// niciodata nevoie de aceasta clasa la runtime — `isCostelBuild` e `false`
// in afara lui `--dart-define=CLIENT=costel`, folosit STRICT de
// scripts/build_costel.ps1, niciodata in CI.
//
// SETUP pentru dezvoltatorul care construieste local clientul Costel:
//   1. Inlocuieste local continutul acestui fisier cu valorile reale
//      (proiect Firebase `proventaris-costel-costea`).
//   2. Ruleaza O SINGURA DATA, din radacina proiectului:
//        git update-index --skip-worktree lib/firebase_options_costel.dart
//      Asta spune git sa ignore definitiv modificarile locale ale acestui
//      fisier (nu va mai aparea in `git status`/nu va mai fi inclus de
//      `git add -A`/`git commit -a`) — echivalentul robust al vechiului
//      .gitignore, dar care nu mai sparge checkout-urile curate/CI.
//   3. (Doar daca vrei sa revii la stub-ul versionat):
//        git update-index --no-skip-worktree lib/firebase_options_costel.dart
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart';

/// STUB — arunca mereu. Inlocuit local (vezi instructiunile de mai sus)
/// doar pe masina care construieste build-ul Costel.
class FirebaseOptionsCostel {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'firebase_options_costel.dart este un STUB versionat (fara date '
      'reale). Pentru build-ul clientului Costel Costea, inlocuieste local '
      'acest fisier cu valorile reale si ruleaza: '
      'git update-index --skip-worktree lib/firebase_options_costel.dart '
      '— vezi comentariul din capul fisierului.',
    );
  }
}
