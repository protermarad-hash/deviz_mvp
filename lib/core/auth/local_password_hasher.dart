import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash pentru parolele conturilor LOCALE (autentificarea offline de rezervă).
///
/// Format stocat: `pbkdf2_sha256$<iterații>$<salt base64>$<cheie base64>`
/// - PBKDF2-HMAC-SHA256 (RFC 8018), salt aleator de 16 octeți
///   (`Random.secure`), cheie derivată de 32 de octeți;
/// - iterațiile sunt salvate în valoare, deci pot fi crescute ulterior fără
///   a invalida hash-urile existente (vezi [needsRehash]).
///
/// Formatul vechi (`base64(utf8(parolă))`, reversibil — NU este un hash) este
/// acceptat DOAR la verificare, pentru migrarea transparentă la primul login
/// reușit; nu mai este produs niciodată.
class LocalPasswordHasher {
  LocalPasswordHasher({this.iterations = defaultIterations, Random? random})
      : _random = random ?? Random.secure();

  static const String scheme = 'pbkdf2_sha256';
  static const int defaultIterations = 120000;
  static const int saltLength = 16;
  static const int keyLength = 32;

  /// Limite de siguranță la citirea unui hash stocat (valoare coruptă sau
  /// manipulată nu trebuie să blocheze aplicația în calcule uriașe).
  static const int minAcceptedIterations = 1000;
  static const int maxAcceptedIterations = 10000000;

  final int iterations;
  final Random _random;

  /// Hash nou pentru [password]. Parola goală nu este acceptată.
  String hash(String password) {
    if (password.isEmpty) {
      throw ArgumentError('Parola nu poate fi goală.');
    }
    final salt = Uint8List(saltLength);
    for (var i = 0; i < saltLength; i++) {
      salt[i] = _random.nextInt(256);
    }
    final key = pbkdf2(utf8.encode(password), salt, iterations, keyLength);
    return '$scheme\$$iterations\$${base64Encode(salt)}\$${base64Encode(key)}';
  }

  /// Verifică [password] față de o valoare în format [scheme]. Parola goală,
  /// valoarea goală sau un format necunoscut/corupt → `false`.
  bool verify(String password, String stored) {
    if (password.isEmpty || stored.isEmpty) return false;
    final parsed = _parse(stored);
    if (parsed == null) return false;
    final derived =
        pbkdf2(utf8.encode(password), parsed.salt, parsed.iterations,
            parsed.key.length);
    return constantTimeEquals(derived, parsed.key);
  }

  /// Ca [hash], dar derivarea (costisitoare) rulează într-un isolate separat,
  /// ca firul UI să nu înghețe (~2 s pentru 120 000 iterații pe emulator).
  /// Sarea e generată în isolate-ul curent (`Random.secure`).
  Future<String> hashAsync(String password) async {
    if (password.isEmpty) {
      throw ArgumentError('Parola nu poate fi goală.');
    }
    final salt = Uint8List(saltLength);
    for (var i = 0; i < saltLength; i++) {
      salt[i] = _random.nextInt(256);
    }
    final pw = utf8.encode(password);
    final iters = iterations;
    final key = await Isolate.run(() => pbkdf2(pw, salt, iters, keyLength));
    return '$scheme\$$iters\$${base64Encode(salt)}\$${base64Encode(key)}';
  }

  /// Ca [verify], cu derivarea într-un isolate separat.
  Future<bool> verifyAsync(String password, String stored) async {
    if (password.isEmpty || stored.isEmpty) return false;
    final parsed = _parse(stored);
    if (parsed == null) return false;
    final pw = utf8.encode(password);
    final salt = parsed.salt;
    final iters = parsed.iterations;
    final len = parsed.key.length;
    final derived = await Isolate.run(() => pbkdf2(pw, salt, iters, len));
    return constantTimeEquals(derived, parsed.key);
  }

  /// `true` pentru o valoare în formatul vechi (base64 reversibil).
  static bool isLegacy(String stored) =>
      stored.isNotEmpty && !stored.startsWith('$scheme\$');

  /// Verificare în formatul vechi — folosită EXCLUSIV pentru migrare.
  static bool verifyLegacy(String password, String stored) {
    if (password.isEmpty || stored.isEmpty || !isLegacy(stored)) return false;
    return constantTimeEquals(
      utf8.encode(base64Encode(utf8.encode(password))),
      utf8.encode(stored),
    );
  }

  /// `true` dacă valoarea trebuie re-hash-uită (format vechi sau mai puține
  /// iterații decât parametrul curent).
  bool needsRehash(String stored) {
    if (isLegacy(stored)) return true;
    final parsed = _parse(stored);
    return parsed == null || parsed.iterations < iterations;
  }

  static ({int iterations, Uint8List salt, Uint8List key})? _parse(
      String stored) {
    final parts = stored.split('\$');
    if (parts.length != 4 || parts[0] != scheme) return null;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null ||
        iterations < minAcceptedIterations ||
        iterations > maxAcceptedIterations) {
      return null;
    }
    try {
      final salt = base64Decode(parts[2]);
      final key = base64Decode(parts[3]);
      if (salt.length < 8 || key.length < 16) return null;
      return (iterations: iterations, salt: salt, key: key);
    } on FormatException {
      return null;
    }
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018, secțiunea 5.2).
  static Uint8List pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int length,
  ) {
    final hmac = Hmac(sha256, password);
    final out = Uint8List(length);
    var offset = 0;
    var block = 1;
    while (offset < length) {
      final input = Uint8List(salt.length + 4)
        ..setAll(0, salt)
        ..[salt.length] = (block >> 24) & 0xff
        ..[salt.length + 1] = (block >> 16) & 0xff
        ..[salt.length + 2] = (block >> 8) & 0xff
        ..[salt.length + 3] = block & 0xff;
      var u = hmac.convert(input).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final take = min(t.length, length - offset);
      out.setRange(offset, offset + take, t);
      offset += take;
      block++;
    }
    return out;
  }

  /// Comparație în timp constant (nu se oprește la primul octet diferit).
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
