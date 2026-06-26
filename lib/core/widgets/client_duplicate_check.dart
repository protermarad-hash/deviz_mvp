import 'package:flutter/material.dart';

import '../../features/clients/client_models.dart';

/// Acțiunea aleasă de utilizator în dialogul de duplicat.
enum ClientDuplicateAction { goToExisting, saveAnyway }

/// Rezultatul detecției unui posibil client duplicat.
class ClientDuplicateMatch {
  const ClientDuplicateMatch({
    required this.existing,
    required this.matchedField,
  });

  /// Clientul existent care se potrivește.
  final ClientRecord existing;

  /// Câmpul care a declanșat potrivirea (ex: "Telefon", "Email", "Nume").
  final String matchedField;
}

/// Normalizează un număr de telefon pentru comparare:
/// elimină spațiile, cratimele, parantezele și transformă +40 → 0.
String _normalizePhone(String raw) {
  var v = raw.replaceAll(RegExp(r'[\s\-()./]'), '');
  if (v.startsWith('+40')) {
    v = '0${v.substring(3)}';
  } else if (v.startsWith('0040')) {
    v = '0${v.substring(4)}';
  }
  return v;
}

String _normalizeName(String raw) => raw.trim().toLowerCase();

/// Caută un posibil client duplicat în lista [existing] pe baza datelor
/// clientului nou. Logica este OR (orice câmp care se potrivește).
/// Verificarea câmpului de nume folosește "conține / este conținut"
/// (nu distanță Levenshtein, pentru a evita fals pozitive).
///
/// Returnează prima potrivire găsită (cea mai relevantă) sau null.
ClientDuplicateMatch? findClientDuplicate({
  required List<ClientRecord> existing,
  required String name,
  List<String> phones = const <String>[],
  String email = '',
  String externalCode = '',
}) {
  final newPhones = phones
      .map(_normalizePhone)
      .where((p) => p.length >= 6)
      .toSet();
  final newEmail = email.trim().toLowerCase();
  final newExternal = externalCode.trim();
  final newName = _normalizeName(name);

  for (final c in existing) {
    // 1. Telefon (normalizat)
    if (newPhones.isNotEmpty) {
      final existingPhones = c.allPhoneNumbers
          .map(_normalizePhone)
          .where((p) => p.length >= 6)
          .toSet();
      if (existingPhones.any(newPhones.contains)) {
        return ClientDuplicateMatch(existing: c, matchedField: 'Telefon');
      }
    }

    // 2. Email (case-insensitive)
    if (newEmail.isNotEmpty && c.email.trim().toLowerCase() == newEmail) {
      return ClientDuplicateMatch(existing: c, matchedField: 'Email');
    }

    // 3. Cod client extern (dacă e completat)
    if (newExternal.isNotEmpty &&
        c.externalClientCode.trim().isNotEmpty &&
        c.externalClientCode.trim() == newExternal) {
      return ClientDuplicateMatch(
        existing: c,
        matchedField: 'Cod client extern',
      );
    }

    // 4. Nume similar (conține sau este conținut)
    if (newName.isNotEmpty) {
      final existingName = _normalizeName(c.name);
      if (existingName.isNotEmpty &&
          (existingName.contains(newName) || newName.contains(existingName))) {
        return ClientDuplicateMatch(existing: c, matchedField: 'Nume');
      }
    }
  }
  return null;
}

/// Afișează dialogul de avertizare pentru un posibil duplicat.
/// Returnează acțiunea aleasă sau null dacă utilizatorul a închis dialogul.
Future<ClientDuplicateAction?> showClientDuplicateDialog(
  BuildContext context,
  ClientDuplicateMatch match,
) {
  final c = match.existing;
  final contact = <String>[
    if (c.allPhoneNumbers.isNotEmpty) c.allPhoneNumbers.first,
    if (c.email.trim().isNotEmpty) c.email.trim(),
  ].join(' · ');

  return showDialog<ClientDuplicateAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('⚠️ Posibil duplicat detectat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Am găsit un client similar:'),
          const SizedBox(height: 12),
          Text(
            c.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (contact.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(contact),
          ],
          const SizedBox(height: 12),
          Text(
            'Potrivire după: ${match.matchedField}',
            style: const TextStyle(color: Color(0xFFC62828)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vrei să mergi la clientul existent sau să salvezi oricum?',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(ClientDuplicateAction.goToExisting),
          child: const Text('Mergi la clientul existent'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(ClientDuplicateAction.saveAnyway),
          child: const Text('Salvează oricum'),
        ),
      ],
    ),
  );
}
