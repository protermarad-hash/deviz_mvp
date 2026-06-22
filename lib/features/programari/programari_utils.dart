// Helper-uri pure pentru modulul Programări (fără dependențe de UI/State).

/// Parsează un text numeric tolerant la separatorul zecimal cu virgulă.
/// Returnează 0 dacă textul nu poate fi parsat.
double asDouble(String raw) {
  return double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;
}
