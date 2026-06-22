import 'package:flutter/material.dart';

import '../../core/lookup_models.dart';

/// Pachet de date pentru lookup-ul lucrărilor: lista de iteme pentru
/// selectoare + maparea lucrare → client.
class JobsLookupBundle {
  const JobsLookupBundle({
    required this.lookupItems,
    required this.jobClientById,
  });

  final List<LookupItem> lookupItems;
  final Map<String, String> jobClientById;
}

/// Preset de culoare pentru o programare (etichetă + valoare ARGB).
class AppointmentColorPreset {
  const AppointmentColorPreset({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  Color get color => Color(value);
}
