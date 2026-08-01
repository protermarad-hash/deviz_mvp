import 'dart:io';

/// Mecanism minim de crash-logging pentru diagnostic producție.
///
/// Scrie erorile + stack trace SINCRON, în mod append, într-un fișier text
/// local, ca dovada să existe chiar dacă procesul se închide imediat după
/// crash. NU repară nimic — doar înregistrează.
class CrashLogger {
  const CrashLogger._();

  /// Fișierul de log. Pe Windows: %APPDATA%\com.example\ProVentaris\crash_log.txt
  /// (același folder în care aplicația scrie deja shared_preferences.json).
  static File? _resolveLogFile() {
    try {
      String? baseDir;
      if (Platform.isWindows) {
        baseDir = Platform.environment['APPDATA'];
      } else {
        // Fallback minim pentru alte platforme (nu e ținta principală).
        baseDir = Platform.environment['HOME'];
      }
      if (baseDir == null || baseDir.trim().isEmpty) return null;
      final dir = Directory('$baseDir${Platform.pathSeparator}com.example'
          '${Platform.pathSeparator}ProVentaris');
      // createSync recursiv = sincron, garantat înainte de scriere.
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return File('${dir.path}${Platform.pathSeparator}crash_log.txt');
    } catch (_) {
      return null;
    }
  }

  /// Scrie o intrare de crash SINCRON (append, cu timestamp).
  ///
  /// Folosește `writeAsStringSync` cu `FileMode.append` — scrierea se termină
  /// complet înainte ca funcția să returneze; nu există await care ar putea să
  /// nu apuce să ruleze dacă procesul moare imediat.
  static void log(String source, Object error, StackTrace? stack) {
    try {
      final file = _resolveLogFile();
      if (file == null) return;
      final ts = DateTime.now().toIso8601String();
      final buffer = StringBuffer()
        ..writeln('==================== CRASH ====================')
        ..writeln('Timestamp: $ts')
        ..writeln('Sursa: $source')
        ..writeln('Eroare: $error')
        ..writeln('Stack trace:')
        ..writeln(stack?.toString() ?? '(fără stack trace)')
        ..writeln('===============================================')
        ..writeln();
      file.writeAsStringSync(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Logging-ul de crash nu trebuie să provoace el însuși un crash.
    }
  }
}
