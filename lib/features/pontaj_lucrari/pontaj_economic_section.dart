import 'package:flutter/material.dart';

import 'pontaj_zi_lucrare_models.dart';
import 'pontaj_zi_lucrare_repository.dart';

/// Secțiunea "Manoperă din pontaj" pentru tab-ul Economic al fișei de lucrare.
///
/// STRICT INFORMATIVĂ — nu modifică niciun total economic existent
/// (_realTotalCost, profit, marje, PDF-uri). Se afișează DOAR dacă lucrarea
/// are cel puțin un pontaj; lucrările fără pontaje rămân vizual neschimbate.
///
/// Decizie contorizare (iul 2026): pontajele cu sursă "liber" (persoane
/// neînregistrate în cataloage) se contorizează SEPARAT, nu la parteneri —
/// linia "Resurse libere (pontaj)" apare doar dacă există astfel de pontaje.

/// Agregat per persoană (nume + sursă + număr zile + total RON).
class PontajEconomicPersoana {
  const PontajEconomicPersoana({
    required this.nume,
    required this.sursa,
    required this.zile,
    required this.total,
  });

  final String nume;
  final SursaPersoanaPontaj sursa;
  final int zile;
  final double total;
}

/// Agregat economic al pontajelor unei lucrări, defalcat pe sursă.
class PontajEconomicAgregat {
  const PontajEconomicAgregat({
    required this.totalPropriu,
    required this.totalPartener,
    required this.totalLiber,
    required this.perPersoana,
    required this.numarPontaje,
  });

  final double totalPropriu;
  final double totalPartener;
  final double totalLiber;
  final List<PontajEconomicPersoana> perPersoana;
  final int numarPontaje;

  double get totalGeneral => totalPropriu + totalPartener + totalLiber;

  bool get arePontaje => numarPontaje > 0;

  /// Agregă pontajele: totaluri per sursă + defalcare per persoană
  /// (sortată descrescător după total, apoi alfabetic după nume).
  factory PontajEconomicAgregat.dinPontaje(List<PontajZiLucrare> pontaje) {
    var totalPropriu = 0.0;
    var totalPartener = 0.0;
    var totalLiber = 0.0;

    // Cheie per persoană: sursă + nume normalizat (aceeași persoană poate
    // apărea cu majuscule diferite în zile diferite).
    final grupat = <String, List<PontajZiLucrare>>{};
    for (final p in pontaje) {
      switch (p.sursaPersoana) {
        case SursaPersoanaPontaj.propriu:
          totalPropriu += p.costZi;
        case SursaPersoanaPontaj.partener:
          totalPartener += p.costZi;
        case SursaPersoanaPontaj.liber:
          totalLiber += p.costZi;
      }
      final cheie =
          '${p.sursaPersoana.value}|${p.persoanaNume.trim().toLowerCase()}';
      grupat.putIfAbsent(cheie, () => []).add(p);
    }

    final perPersoana = grupat.values.map((lista) {
      final zileUnice =
          lista.map((p) => p.ziCalendaristica).toSet().length;
      return PontajEconomicPersoana(
        nume: lista.first.persoanaNume.trim(),
        sursa: lista.first.sursaPersoana,
        zile: zileUnice,
        total: lista.fold(0.0, (sum, p) => sum + p.costZi),
      );
    }).toList()
      ..sort((a, b) {
        final byTotal = b.total.compareTo(a.total);
        if (byTotal != 0) return byTotal;
        return a.nume.toLowerCase().compareTo(b.nume.toLowerCase());
      });

    return PontajEconomicAgregat(
      totalPropriu: totalPropriu,
      totalPartener: totalPartener,
      totalLiber: totalLiber,
      perPersoana: perPersoana,
      numarPontaje: pontaje.length,
    );
  }
}

/// Condiția de avertisment anti-dublă-contorizare: lucrarea are pontaje noi
/// ȘI manoperă în sistemul vechi (echipă/ore sau lucrători parteneri cu
/// valoare pe workedHours/diurnă/cazare).
bool necesitaAvertismentDublaSursa({
  required bool arePontaje,
  required bool areManoperaVeche,
}) =>
    arePontaje && areManoperaVeche;

/// Widget-ul secțiunii. Își încarcă singur pontajele (repository propriu) —
/// monolitul lucrării face doar wiring (import + un apel).
class PontajEconomicSection extends StatefulWidget {
  const PontajEconomicSection({
    super.key,
    required this.lucrareId,
    required this.areManoperaVeche,
  });

  final String lucrareId;

  /// True dacă lucrarea are manoperă în sistemul vechi (rânduri echipă/ore
  /// sau lucrători parteneri cu total > 0) — calculat de pagina părinte.
  final bool areManoperaVeche;

  @override
  State<PontajEconomicSection> createState() => _PontajEconomicSectionState();
}

class _PontajEconomicSectionState extends State<PontajEconomicSection> {
  final PontajZiLucrareRepository _repo = PontajZiLucrareRepository();

  PontajEconomicAgregat? _agregat;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final pontaje = await _repo.listForLucrare(widget.lucrareId);
      if (!mounted) return;
      setState(() => _agregat = PontajEconomicAgregat.dinPontaje(pontaje));
    } catch (_) {
      // Best-effort: secțiunea e informativă — la eroare rămâne ascunsă.
    }
  }

  String _fmt(double v) => '${v.toStringAsFixed(2)} RON';

  @override
  Widget build(BuildContext context) {
    final agregat = _agregat;
    // În timpul încărcării sau fără pontaje: nimic — lucrările vechi rămân
    // vizual neschimbate.
    if (agregat == null || !agregat.arePontaje) {
      return const SizedBox.shrink();
    }

    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final avertisment = necesitaAvertismentDublaSursa(
      arePontaje: agregat.arePontaje,
      areManoperaVeche: widget.areManoperaVeche,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_note_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Manoperă din pontaj', style: titleStyle),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (avertisment) _buildAvertisment(context),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(context, 'Resurse proprii (pontaj)',
                    _fmt(agregat.totalPropriu)),
                _chip(context, 'Resurse partenere (pontaj)',
                    _fmt(agregat.totalPartener)),
                if (agregat.totalLiber > 0)
                  _chip(context, 'Resurse libere (pontaj)',
                      _fmt(agregat.totalLiber)),
                _chip(context, 'Total manoperă pontaj',
                    _fmt(agregat.totalGeneral)),
                _chip(context, 'Zile pontate', '${agregat.numarPontaje}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Secțiune informativă — nu este inclusă în „Cost real total”.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _expanded
                          ? 'Ascunde defalcarea per persoană'
                          : 'Defalcare per persoană (${agregat.perPersoana.length})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              ...agregat.perPersoana.map(
                (p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text(
                      p.nume.isNotEmpty ? p.nume[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(p.nume),
                  subtitle: Text(
                    '${p.sursa.label} • ${p.zile} ${p.zile == 1 ? 'zi' : 'zile'}',
                  ),
                  trailing: Text(
                    _fmt(p.total),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvertisment(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Atenție: această lucrare are manoperă înregistrată și în '
              'sistemul vechi (echipă/ore) și în pontaj. Verifică să nu '
              'fie dublată.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade900,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}
