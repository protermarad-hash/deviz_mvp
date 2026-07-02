import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../../firebase_options_costel.dart';

/// Clientul activ, selectat la compilare cu `--dart-define=CLIENT=costel`.
/// Default: `proterm` → proiectul Firebase principal (devizpro-ultra-pilot).
/// `costel` → proiect Firebase separat (proventaris-costel-costea), date izolate.
const String kActiveClient =
    String.fromEnvironment('CLIENT', defaultValue: 'proterm');

/// Adevărat doar în build-ul dedicat clientului Costel Costea.
bool get isCostelBuild => kActiveClient == 'costel';

FirebaseOptions? resolveFirebaseOptions() {
  try {
    if (isCostelBuild) {
      return FirebaseOptionsCostel.currentPlatform;
    }
    return DefaultFirebaseOptions.currentPlatform;
  } catch (_) {
    return null;
  }
}
