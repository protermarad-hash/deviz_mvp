import 'dart:async';

/// Excludere mutuală pe cheie, în același isolate, reentrantă pe lanțul de apel
/// (prin Zone): o funcție care deține deja cheia o poate cere din nou fără blocaj.
///
/// Folosită pentru citire-modificare-scriere în SharedPreferences (coada offline,
/// bazele de revizie, conflictele) și pentru îmbinarea cloud ↔ local vs. salvarea
/// locală + coadă (RC 120): fără ea, două operații care se intercalează la un
/// `await` pot rescrie lista cu o versiune veche (de exemplu un element nou din
/// coadă dispare).
class KeyedMutex {
  KeyedMutex._();

  static final Map<String, Future<void>> _tails = {};
  static final Object _heldKey = Object();

  static Future<T> run<T>(String key, Future<T> Function() body) async {
    final held = Zone.current[_heldKey] as Set<String>?;
    if (held != null && held.contains(key)) return body();
    final previous = _tails[key];
    final done = Completer<void>();
    final tail = done.future;
    _tails[key] = tail;
    try {
      if (previous != null) await previous;
      return await runZoned(body, zoneValues: {
        _heldKey: {...?held, key},
      });
    } finally {
      done.complete();
      if (identical(_tails[key], tail)) _tails.remove(key);
    }
  }
}
