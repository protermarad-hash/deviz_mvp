import 'dart:async';

/// Excludere mutuală pe cheie, în același isolate, reentrantă pe lanțul de apel
/// (prin Zone): o funcție care deține deja cheia o poate cere din nou fără blocaj.
///
/// Folosită pentru citire-modificare-scriere în SharedPreferences (coada offline,
/// bazele de revizie, conflictele) și pentru îmbinarea cloud ↔ local vs. salvarea
/// locală + coadă (RC 120): fără ea, două operații care se intercalează la un
/// `await` pot rescrie lista cu o versiune veche (de exemplu un element nou din
/// coadă dispare).
///
/// Reentranța este legată de DEȚINEREA CURENTĂ (un jeton unic per achiziție), nu
/// doar de zonă (RC 121): o operație pornită în fundal (`unawaited`) din interiorul
/// unei secțiuni blocate moștenește zona, dar după eliberarea blocării jetonul nu
/// mai este cel curent, deci operația așteaptă blocarea ca oricine altcineva.
class KeyedMutex {
  KeyedMutex._();

  static final Map<String, Future<void>> _tails = {};
  static final Map<String, Object> _currentHolder = {};
  static final Object _heldKey = Object();

  /// Pornește [body] FĂRĂ blocările deținute de apelant (lucru în fundal lansat
  /// dintr-o secțiune blocată): altfel ar fi tratat ca apel imbricat și ar rula
  /// în paralel cu deținătorul. Păstrează restul zonei (tratarea erorilor).
  static Future<T> detached<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_heldKey: const <String, Object>{}});

  static Future<T> run<T>(String key, Future<T> Function() body) async {
    final held = Zone.current[_heldKey] as Map<String, Object>?;
    final token = held?[key];
    if (token != null && identical(_currentHolder[key], token)) return body();
    final previous = _tails[key];
    final done = Completer<void>();
    final tail = done.future;
    _tails[key] = tail;
    final mine = Object();
    try {
      if (previous != null) await previous;
      _currentHolder[key] = mine;
      return await runZoned(body, zoneValues: {
        _heldKey: {...?held, key: mine},
      });
    } finally {
      if (identical(_currentHolder[key], mine)) _currentHolder.remove(key);
      done.complete();
      if (identical(_tails[key], tail)) _tails.remove(key);
    }
  }
}
