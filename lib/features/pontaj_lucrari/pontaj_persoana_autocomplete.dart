import 'package:flutter/material.dart';

import '../master/master_local_store.dart';
import '../partners/partner_models.dart';
import 'pontaj_zi_lucrare_models.dart';

/// Opțiune de persoană pentru autosearch — angajat propriu sau muncitor
/// partener (catalog read-only).
class PersoanaPontajOption {
  const PersoanaPontajOption({
    required this.nume,
    required this.sursa,
    this.refId,
    this.partenerNume,
    this.tarifPrefill,
    this.diurnaPrefill = 0,
    this.cazarePrefill = 0,
  });

  final String nume;
  final SursaPersoanaPontaj sursa;
  final String? refId;
  final String? partenerNume;
  final double? tarifPrefill;
  final double diurnaPrefill;
  final double cazarePrefill;
}

/// Construiește lista de opțiuni din cataloage: angajați proprii activi +
/// muncitori parteneri activi (STRICT read-only — nu se scrie nimic înapoi).
List<PersoanaPontajOption> buildPersoanaOptions({
  required List<MasterEmployee> employees,
  required List<PartnerWorkerRecord> partnerWorkers,
  required Map<String, String> partnerNamesById,
}) {
  final options = <PersoanaPontajOption>[
    ...employees.where((e) => e.active && e.name.trim().isNotEmpty).map(
          (e) => PersoanaPontajOption(
            nume: e.name.trim(),
            sursa: SursaPersoanaPontaj.propriu,
            refId: e.id,
            tarifPrefill: e.tarifZilnic,
            diurnaPrefill: e.dailyAllowance,
            cazarePrefill: e.defaultLodgingCost,
          ),
        ),
    ...partnerWorkers
        .where((w) => w.active && w.fullName.trim().isNotEmpty)
        .map(
          (w) => PersoanaPontajOption(
            nume: w.fullName.trim(),
            sursa: SursaPersoanaPontaj.partener,
            refId: w.id,
            partenerNume: partnerNamesById[w.partnerId]?.trim(),
          ),
        ),
  ];
  options.sort((a, b) => a.nume.toLowerCase().compareTo(b.nume.toLowerCase()));
  return options;
}

/// Câmp autosearch persoană — caută SIMULTAN în angajați proprii și
/// muncitori parteneri, cu indicarea vizuală a sursei. Permite și nume liber.
class PersoanaPontajAutocomplete extends StatelessWidget {
  const PersoanaPontajAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.onSelected,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<PersoanaPontajOption> options;
  final ValueChanged<PersoanaPontajOption> onSelected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RawAutocomplete<PersoanaPontajOption>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (o) => o.nume,
      optionsBuilder: (TextEditingValue value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return options;
        return options.where((o) => o.nume.toLowerCase().contains(query));
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, textController, fieldFocusNode,
          onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: fieldFocusNode,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Persoană (caută sau scrie liber)',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: onChanged,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onOptionSelected, filteredOptions) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: filteredOptions.length,
                itemBuilder: (context, index) {
                  final option = filteredOptions.elementAt(index);
                  final isPartener =
                      option.sursa == SursaPersoanaPontaj.partener;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isPartener
                          ? Icons.handshake_outlined
                          : Icons.badge_outlined,
                      size: 18,
                    ),
                    title: Text(option.nume),
                    subtitle: Text(
                      isPartener
                          ? 'Partener${(option.partenerNume ?? '').isNotEmpty ? ' · ${option.partenerNume}' : ''}'
                          : 'Angajat propriu',
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () => onOptionSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
