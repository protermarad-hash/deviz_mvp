import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

FirebaseOptions? resolveFirebaseOptions() {
  try {
    return DefaultFirebaseOptions.currentPlatform;
  } catch (_) {
    return null;
  }
}
