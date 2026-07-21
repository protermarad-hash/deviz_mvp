enum AsociereStatus {
  activa,
  incheiata,
  reziliata;

  String get value => name;
  String get label => switch (this) {
        activa => 'Activă',
        incheiata => 'Încheiată',
        reziliata => 'Reziliată',
      };

  static AsociereStatus fromValue(String? raw) =>
      switch ((raw ?? '').trim().toLowerCase()) {
        'incheiata' => AsociereStatus.incheiata,
        'reziliata' => AsociereStatus.reziliata,
        _ => AsociereStatus.activa,
      };
}

enum AsociereIncasator {
  proTerm,
  partener;

  String get value => this == partener ? 'partener' : 'pro_term';
  String get label => this == partener ? 'Partener' : 'PRO TERM';

  static AsociereIncasator fromValue(String? raw) =>
      (raw ?? '').trim().toLowerCase() == 'partener' ? partener : proTerm;
}
