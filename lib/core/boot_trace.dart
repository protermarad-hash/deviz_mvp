import 'dart:io';

/// Jurnal de boot ușor și permanent, pentru diagnosticarea crash-urilor native
/// intermitente pe Windows (ex: excepția C++ 0xe06d7363 pe un thread de fundal
/// al SDK-ului Firebase, corelată cu stări de conectivitate).
///
/// De ce există: astfel de crash-uri mor la nivel NATIV și NU ajung la
/// handlerele Dart (runZonedGuarded / PlatformDispatcher.onError), deci nu pot
/// fi „prinse". Singura cale de a le diagnostica este să scriem sincron, cu
/// flush imediat, fiecare pas de boot ÎNAINTE de execuție: dacă procesul moare,
/// ULTIMA linie din fișier arată exact pasul (și starea rețelei) pe care a murit.
///
/// Fișier: %APPDATA%\com.example\ProVentaris\boot_trace.txt (doar desktop).
/// Overhead neglijabil (câteva scrieri mici per boot), păstrează istoric rulant.
class BootTrace {
  BootTrace._();

  static File? _file;
  static bool _resolved = false;

  /// Peste această dimensiune, jurnalul e trunchiat (păstrăm coada = boot-urile
  /// recente), ca să nu crească nelimitat.
  static const int _maxBytes = 64 * 1024;

  static File? _resolve() {
    if (_resolved) return _file;
    _resolved = true;
    try {
      if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        return null; // pe mobil nu avem acest tip de crash nativ de boot
      }
      final appData = Platform.environment['APPDATA'] ??
          Platform.environment['HOME'];
      if (appData == null || appData.isEmpty) return null;
      final sep = Platform.pathSeparator;
      final dir = Directory('$appData${sep}com.example${sep}ProVentaris');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _file = File('${dir.path}${sep}boot_trace.txt');
      return _file;
    } catch (_) {
      return null;
    }
  }

  /// Marchează începutul unei porniri și trunchiază jurnalul dacă e prea mare.
  static void reset() {
    try {
      final f = _resolve();
      if (f == null) return;
      if (f.existsSync() && f.lengthSync() > _maxBytes) {
        // Păstrează doar ultima jumătate (boot-urile recente).
        final content = f.readAsStringSync();
        f.writeAsStringSync(
          content.substring(content.length ~/ 2),
          flush: true,
        );
      }
      mark('===== BOOT =====');
    } catch (_) {}
  }

  /// Scrie un pas de boot, sincron, cu flush imediat.
  static void mark(String step) {
    try {
      final f = _resolve();
      if (f == null) return;
      final ts = DateTime.now().toIso8601String();
      f.writeAsStringSync('$ts  $step\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}
