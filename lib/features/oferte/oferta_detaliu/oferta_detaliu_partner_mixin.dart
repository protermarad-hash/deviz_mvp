import 'package:flutter/material.dart';

import '../../../core/widgets/anaf_company_autofill_section.dart';
import '../../partners/partner_models.dart';
import '../offer_models.dart';
import '../offer_partner_models.dart';
import '../oferta_detaliu_page.dart' show OfertaDetaliuPage;

/// Secțiunea parteneri (personal + autovehicule) și calculele de totaluri
/// aferente, pentru [OfertaDetaliuPage].
mixin OffertaDetaliuPartnerMixin on State<OfertaDetaliuPage> {
  OfferRecord get offer;

  /// Furnizate de [_OfertaDetaliuPageState].
  bool get saving;
  bool get isFrozen;
  void showFrozenMessage();
  Future<void> persistOffer(OfferRecord next, {bool keepPdfPath});

  List<PartnerRecord> _masterPartners = const <PartnerRecord>[];
  List<PartnerWorkerRecord> _masterPartnerWorkers =
      const <PartnerWorkerRecord>[];
  List<PartnerVehicleRecord> _masterPartnerVehicles =
      const <PartnerVehicleRecord>[];


  Future<void> loadPartnerCatalog() async {
    final results = await Future.wait([
      widget.repository.listPartners(),
      widget.repository.listPartnerWorkers(),
      widget.repository.listPartnerVehicles(),
    ]);
    if (!mounted) return;
    setState(() {
      _masterPartners = results[0] as List<PartnerRecord>;
      _masterPartnerWorkers = results[1] as List<PartnerWorkerRecord>;
      _masterPartnerVehicles = results[2] as List<PartnerVehicleRecord>;
    });
  }


  List<OfferPartnerWorker> _partnerWorkersFor(String partnerId) {
    return offer.partnerWorkers
        .where((item) => item.partnerId == partnerId)
        .toList(growable: false);
  }

  List<OfferPartnerVehicle> _partnerVehiclesFor(String partnerId) {
    return offer.partnerVehicles
        .where((item) => item.partnerId == partnerId)
        .toList(growable: false);
  }

  PartnerRecord? _masterPartnerById(String partnerId) {
    for (final partner in _masterPartners) {
      if (partner.id == partnerId) return partner;
    }
    return null;
  }

  List<PartnerWorkerRecord> _masterWorkersForOfferPartner(
      OfferPartner partner) {
    final masterPartnerId = partner.masterPartnerId.trim();
    if (masterPartnerId.isEmpty) return const <PartnerWorkerRecord>[];
    return _masterPartnerWorkers
        .where((item) => item.partnerId == masterPartnerId)
        .toList(growable: false);
  }

  List<PartnerVehicleRecord> _masterVehiclesForOfferPartner(
    OfferPartner partner,
  ) {
    final masterPartnerId = partner.masterPartnerId.trim();
    if (masterPartnerId.isEmpty) return const <PartnerVehicleRecord>[];
    return _masterPartnerVehicles
        .where((item) => item.partnerId == masterPartnerId)
        .toList(growable: false);
  }

  double _partnerWorkersTotalFor(String partnerId) {
    return _partnerWorkersFor(partnerId)
        .fold<double>(0, (sum, item) => sum + item.total);
  }

  double _partnerVehiclesTotalFor(String partnerId) {
    return _partnerVehiclesFor(partnerId)
        .fold<double>(0, (sum, item) => sum + item.total);
  }

  double _partnerTotalFor(String partnerId) {
    return _partnerWorkersTotalFor(partnerId) +
        _partnerVehiclesTotalFor(partnerId);
  }

  double get partnerWorkersTotal =>
      offer.partnerWorkers.fold<double>(0, (sum, item) => sum + item.total);

  double get partnerVehiclesTotal =>
      offer.partnerVehicles.fold<double>(0, (sum, item) => sum + item.total);

  double get partnersTotal => partnerWorkersTotal + partnerVehiclesTotal;

  String _currencyLabel(Iterable<String> values) {
    final normalized = values
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) return 'RON';
    if (normalized.length == 1) return normalized.first;
    return 'monede mixte';
  }

  String get partnerWorkersCurrency =>
      _currencyLabel(offer.partnerWorkers.map((item) => item.currency));

  String get partnerVehiclesCurrency =>
      _currencyLabel(offer.partnerVehicles.map((item) => item.currency));

  String get partnersCurrency => _currencyLabel([
        ...offer.partnerWorkers.map((item) => item.currency),
        ...offer.partnerVehicles.map((item) => item.currency),
      ]);

  Future<OfferPartner?> _showPartnerDialog({OfferPartner? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final cuiCtrl = TextEditingController(text: existing?.cui ?? '');
    final regCtrl =
        TextEditingController(text: existing?.tradeRegisterNumber ?? '');
    final contactCtrl =
        TextEditingController(text: existing?.contactPerson ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? '');
    final countyCtrl = TextEditingController(text: existing?.county ?? '');
    final ibanCtrl = TextEditingController(text: existing?.iban ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String? selectedMasterPartnerId =
        existing?.masterPartnerId.trim().isNotEmpty == true
            ? existing!.masterPartnerId.trim()
            : null;
    try {
      return await showDialog<OfferPartner>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
                existing == null ? 'Adaugă partener' : 'Editează partener'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_masterPartners.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: selectedMasterPartnerId != null &&
                                _masterPartners.any(
                                  (item) => item.id == selectedMasterPartnerId,
                                )
                            ? selectedMasterPartnerId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Partener salvat',
                          helperText:
                              'Optional: preia datele din registrul de parteneri',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Introducere manuală'),
                          ),
                          ..._masterPartners.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedMasterPartnerId = value;
                            final selected = value == null
                                ? null
                                : _masterPartnerById(value);
                            if (selected == null) return;
                            nameCtrl.text = selected.name;
                            cuiCtrl.text = selected.cui;
                            regCtrl.text = selected.tradeRegisterNumber;
                            contactCtrl.text = selected.contactPerson;
                            phoneCtrl.text = selected.phone;
                            emailCtrl.text = selected.email;
                            addressCtrl.text = selected.address;
                            cityCtrl.text = selected.city;
                            countyCtrl.text = selected.county;
                            ibanCtrl.text = selected.iban;
                            notesCtrl.text = selected.notes;
                          });
                        },
                      ),
                    if (selectedMasterPartnerId == null)
                      AnafCompanyAutofillSection(
                        cuiController: cuiCtrl,
                        nameController: nameCtrl,
                        tradeRegisterController: regCtrl,
                        phoneController: phoneCtrl,
                        ibanController: ibanCtrl,
                        addressController: addressCtrl,
                        cityController: cityCtrl,
                        countyController: countyCtrl,
                      ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Partener / companie'),
                    ),
                    if (selectedMasterPartnerId != null)
                      TextField(
                        controller: cuiCtrl,
                        decoration: const InputDecoration(labelText: 'CUI'),
                      ),
                    TextField(
                      controller: regCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nr. Reg. Com.',
                      ),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: contactCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Persoană contact'),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Telefon'),
                    ),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Adresa'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: cityCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Localitate'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: countyCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Județ'),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: ibanCtrl,
                      decoration: const InputDecoration(labelText: 'IBAN'),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: notesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Observații'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Renunță'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Completează numele partenerului.'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    OfferPartner(
                      id: existing?.id ??
                          'offer-partner-${DateTime.now().microsecondsSinceEpoch}',
                      name: name,
                      masterPartnerId: selectedMasterPartnerId ?? '',
                      cui: cuiCtrl.text.trim(),
                      tradeRegisterNumber: regCtrl.text.trim(),
                      contactPerson: contactCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      city: cityCtrl.text.trim(),
                      county: countyCtrl.text.trim(),
                      iban: ibanCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                    ),
                  );
                },
                child: const Text('Salvează'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameCtrl.dispose();
      cuiCtrl.dispose();
      regCtrl.dispose();
      contactCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      addressCtrl.dispose();
      cityCtrl.dispose();
      countyCtrl.dispose();
      ibanCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  Future<OfferPartnerWorker?> _showPartnerWorkerDialog({
    required OfferPartner partner,
    OfferPartnerWorker? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final roleCtrl = TextEditingController(text: existing?.role ?? '');
    final hoursCtrl =
        TextEditingController(text: (existing?.hours ?? 0).toString());
    final rateCtrl =
        TextEditingController(text: (existing?.hourlyRate ?? 0).toString());
    final currencyCtrl =
        TextEditingController(text: existing?.currency ?? 'RON');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final masterWorkers = _masterWorkersForOfferPartner(partner);
    String? selectedMasterWorkerId =
        existing?.masterWorkerId.trim().isNotEmpty == true
            ? existing!.masterWorkerId.trim()
            : null;
    try {
      return await showDialog<OfferPartnerWorker>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text(
                    existing == null
                        ? 'Adaugă personal partener'
                        : 'Editează personal partener',
                  ),
                  content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              partner.name,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          if (masterWorkers.isNotEmpty)
                            DropdownButtonFormField<String?>(
                              initialValue: selectedMasterWorkerId != null &&
                                      masterWorkers.any(
                                        (item) =>
                                            item.id == selectedMasterWorkerId,
                                      )
                                  ? selectedMasterWorkerId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Personal salvat',
                                helperText:
                                    'Optional: precompleteaza din registrul partenerului',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Introducere manuală'),
                                ),
                                ...masterWorkers.map(
                                  (item) => DropdownMenuItem<String?>(
                                    value: item.id,
                                    child: Text(item.fullName),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedMasterWorkerId = value;
                                  final selected = value == null
                                      ? null
                                      : masterWorkers.firstWhere(
                                          (item) => item.id == value,
                                        );
                                  if (selected == null) return;
                                  nameCtrl.text = selected.fullName;
                                  roleCtrl.text = selected.role;
                                  rateCtrl.text =
                                      selected.hourlyRate.toStringAsFixed(2);
                                  currencyCtrl.text = selected.currency;
                                  notesCtrl.text = selected.notes;
                                });
                              },
                            ),
                          TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Nume complet'),
                          ),
                          TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: roleCtrl,
                            decoration: const InputDecoration(labelText: 'Rol'),
                          ),
                          TextField(
                            controller: hoursCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Ore estimate'),
                          ),
                          TextField(
                            controller: rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Tarif negociat / ora'),
                          ),
                          TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: currencyCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Moneda'),
                          ),
                          TextField(
                            textCapitalization: TextCapitalization.sentences,
                            controller: notesCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Observații'),
                            minLines: 2,
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Renunță'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final fullName = nameCtrl.text.trim();
                        if (fullName.isEmpty) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Completează numele persoanei.')),
                          );
                          return;
                        }
                        Navigator.of(context).pop(
                          OfferPartnerWorker(
                            id: existing?.id ??
                                'offer-partner-worker-${DateTime.now().microsecondsSinceEpoch}',
                            partnerId: partner.id,
                            fullName: fullName,
                            masterWorkerId: selectedMasterWorkerId ?? '',
                            role: roleCtrl.text.trim(),
                            hours: double.tryParse(
                                  hoursCtrl.text.replaceAll(',', '.').trim(),
                                ) ??
                                0,
                            hourlyRate: double.tryParse(
                                  rateCtrl.text.replaceAll(',', '.').trim(),
                                ) ??
                                0,
                            currency: currencyCtrl.text.trim().isEmpty
                                ? 'RON'
                                : currencyCtrl.text.trim().toUpperCase(),
                            notes: notesCtrl.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Salvează'),
                    ),
                  ],
                )),
      );
    } finally {
      nameCtrl.dispose();
      roleCtrl.dispose();
      hoursCtrl.dispose();
      rateCtrl.dispose();
      currencyCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  Future<OfferPartnerVehicle?> _showPartnerVehicleDialog({
    required OfferPartner partner,
    OfferPartnerVehicle? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.vehicleName ?? '');
    final registrationCtrl =
        TextEditingController(text: existing?.registrationNumber ?? '');
    final kmCtrl = TextEditingController(text: (existing?.km ?? 0).toString());
    final consumptionCtrl = TextEditingController(
      text: (existing?.fuelConsumptionPer100Km ?? 0).toString(),
    );
    final priceCtrl = TextEditingController(
      text: (existing?.fuelPricePerLiter ?? 0).toString(),
    );
    final currencyCtrl =
        TextEditingController(text: existing?.currency ?? 'RON');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final masterVehicles = _masterVehiclesForOfferPartner(partner);
    String? selectedMasterVehicleId =
        existing?.masterVehicleId.trim().isNotEmpty == true
            ? existing!.masterVehicleId.trim()
            : null;
    try {
      return await showDialog<OfferPartnerVehicle>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              existing == null
                  ? 'Adaugă autovehicul partener'
                  : 'Editează autovehicul partener',
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        partner.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    if (masterVehicles.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: selectedMasterVehicleId != null &&
                                masterVehicles.any(
                                  (item) => item.id == selectedMasterVehicleId,
                                )
                            ? selectedMasterVehicleId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Autovehicul salvat',
                          helperText:
                              'Optional: precompletează din registrul partenerului',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Introducere manuală'),
                          ),
                          ...masterVehicles.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(item.vehicleName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedMasterVehicleId = value;
                            final selected = value == null
                                ? null
                                : masterVehicles.firstWhere(
                                    (item) => item.id == value,
                                  );
                            if (selected == null) return;
                            nameCtrl.text = selected.vehicleName;
                            registrationCtrl.text = selected.registrationNumber;
                            consumptionCtrl.text = selected
                                .fuelConsumptionPer100Km
                                .toStringAsFixed(2);
                            priceCtrl.text =
                                selected.fuelPricePerLiter.toStringAsFixed(2);
                            currencyCtrl.text = selected.currency;
                            notesCtrl.text = selected.notes;
                          });
                        },
                      ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Denumire vehicul'),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: registrationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nr. înmatriculare',
                      ),
                    ),
                    TextField(
                      controller: kmCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Km estimați',
                      ),
                    ),
                    TextField(
                      controller: consumptionCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Consum L / 100 km',
                      ),
                    ),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Preț combustibil',
                      ),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: currencyCtrl,
                      decoration: const InputDecoration(labelText: 'Monedă'),
                    ),
                    TextField(
                      textCapitalization: TextCapitalization.sentences,
                      controller: notesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Observații'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Renunță'),
              ),
              FilledButton(
                onPressed: () {
                  final vehicleName = nameCtrl.text.trim();
                  if (vehicleName.isEmpty) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Completează denumirea vehiculului.'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop(
                    OfferPartnerVehicle(
                      id: existing?.id ??
                          'offer-partner-vehicle-${DateTime.now().microsecondsSinceEpoch}',
                      partnerId: partner.id,
                      vehicleName: vehicleName,
                      masterVehicleId: selectedMasterVehicleId ?? '',
                      registrationNumber: registrationCtrl.text.trim(),
                      km: double.tryParse(
                            kmCtrl.text.replaceAll(',', '.').trim(),
                          ) ??
                          0,
                      fuelConsumptionPer100Km: double.tryParse(
                            consumptionCtrl.text.replaceAll(',', '.').trim(),
                          ) ??
                          0,
                      fuelPricePerLiter: double.tryParse(
                            priceCtrl.text.replaceAll(',', '.').trim(),
                          ) ??
                          0,
                      currency: currencyCtrl.text.trim().isEmpty
                          ? 'RON'
                          : currencyCtrl.text.trim().toUpperCase(),
                      notes: notesCtrl.text.trim(),
                    ),
                  );
                },
                child: const Text('Salvează'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameCtrl.dispose();
      registrationCtrl.dispose();
      kmCtrl.dispose();
      consumptionCtrl.dispose();
      priceCtrl.dispose();
      currencyCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  Future<void> addPartner() async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final created = await _showPartnerDialog();
    if (created == null) return;
    await persistOffer(
      offer.copyWith(partners: [...offer.partners, created]),
    );
  }

  Future<void> _editPartner(OfferPartner partner) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final updated = await _showPartnerDialog(existing: partner);
    if (updated == null) return;
    await persistOffer(
      offer.copyWith(
        partners: offer.partners
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _deletePartner(OfferPartner partner) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge partener'),
        content: Text(
          'Partenerul "${partner.name}" va fi sters impreuna cu personalul si autovehiculele asociate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await persistOffer(
      offer.copyWith(
        partners: offer.partners
            .where((item) => item.id != partner.id)
            .toList(growable: false),
        partnerWorkers: offer.partnerWorkers
            .where((item) => item.partnerId != partner.id)
            .toList(growable: false),
        partnerVehicles: offer.partnerVehicles
            .where((item) => item.partnerId != partner.id)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _addPartnerWorker(OfferPartner partner) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final created = await _showPartnerWorkerDialog(partner: partner);
    if (created == null) return;
    await persistOffer(
      offer.copyWith(
        partnerWorkers: [...offer.partnerWorkers, created],
      ),
    );
  }

  Future<void> _editPartnerWorker(
    OfferPartner partner,
    OfferPartnerWorker worker,
  ) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final updated = await _showPartnerWorkerDialog(
      partner: partner,
      existing: worker,
    );
    if (updated == null) return;
    await persistOffer(
      offer.copyWith(
        partnerWorkers: offer.partnerWorkers
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _deletePartnerWorker(OfferPartnerWorker worker) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    await persistOffer(
      offer.copyWith(
        partnerWorkers: offer.partnerWorkers
            .where((item) => item.id != worker.id)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _addPartnerVehicle(OfferPartner partner) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final created = await _showPartnerVehicleDialog(partner: partner);
    if (created == null) return;
    await persistOffer(
      offer.copyWith(
        partnerVehicles: [...offer.partnerVehicles, created],
      ),
    );
  }

  Future<void> _editPartnerVehicle(
    OfferPartner partner,
    OfferPartnerVehicle vehicle,
  ) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    final updated = await _showPartnerVehicleDialog(
      partner: partner,
      existing: vehicle,
    );
    if (updated == null) return;
    await persistOffer(
      offer.copyWith(
        partnerVehicles: offer.partnerVehicles
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _deletePartnerVehicle(OfferPartnerVehicle vehicle) async {
    if (isFrozen) {
      showFrozenMessage();
      return;
    }
    await persistOffer(
      offer.copyWith(
        partnerVehicles: offer.partnerVehicles
            .where((item) => item.id != vehicle.id)
            .toList(growable: false),
      ),
    );
  }

  Widget buildPartnerSection() {
    if (offer.partners.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Nu exista resurse partener adaugate.'),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: offer.partners.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final partner = offer.partners[index];
        final workers = _partnerWorkersFor(partner.id);
        final vehicles = _partnerVehiclesFor(partner.id);
        final workerCurrency =
            _currencyLabel(workers.map((item) => item.currency));
        final vehicleCurrency =
            _currencyLabel(vehicles.map((item) => item.currency));
        final totalCurrency = _currencyLabel([
          ...workers.map((item) => item.currency),
          ...vehicles.map((item) => item.currency),
        ]);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (partner.contactPerson.isNotEmpty)
                                Chip(
                                    label: Text(
                                        'Contact: ${partner.contactPerson}')),
                              if (partner.phone.isNotEmpty)
                                Chip(label: Text('Telefon: ${partner.phone}')),
                              if (partner.email.isNotEmpty)
                                Chip(label: Text('Email: ${partner.email}')),
                              Chip(
                                label: Text(
                                  'Total personal: ${_partnerWorkersTotalFor(partner.id).toStringAsFixed(2)} $workerCurrency',
                                ),
                              ),
                              Chip(
                                label: Text(
                                  'Total autovehicule: ${_partnerVehiclesTotalFor(partner.id).toStringAsFixed(2)} $vehicleCurrency',
                                ),
                              ),
                              Chip(
                                label: Text(
                                  'Total partener: ${_partnerTotalFor(partner.id).toStringAsFixed(2)} $totalCurrency',
                                ),
                              ),
                            ],
                          ),
                          if (partner.notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Observatii: ${partner.notes}'),
                          ],
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Editeaza partener',
                          onPressed: (saving || isFrozen)
                              ? null
                              : () => _editPartner(partner),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Șterge partener',
                          onPressed: (saving || isFrozen)
                              ? null
                              : () => _deletePartner(partner),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Personal partener',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: (saving || isFrozen)
                          ? null
                          : () => _addPartnerWorker(partner),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Adauga personal'),
                    ),
                  ],
                ),
                if (workers.isEmpty)
                  const Text('Nu exista personal partener adaugat.')
                else
                  ...workers.map((worker) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(worker.fullName),
                        subtitle: Text(
                          [
                            if (worker.role.isNotEmpty) 'Rol: ${worker.role}',
                            'Ore: ${worker.hours.toStringAsFixed(2)}',
                            'Tarif: ${worker.hourlyRate.toStringAsFixed(2)} ${worker.currency}',
                            'Total: ${worker.total.toStringAsFixed(2)} ${worker.currency}',
                            if (worker.notes.isNotEmpty)
                              'Observatii: ${worker.notes}',
                          ].join(' • '),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Editeaza',
                              onPressed: (saving || isFrozen)
                                  ? null
                                  : () => _editPartnerWorker(partner, worker),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Șterge',
                              onPressed: (saving || isFrozen)
                                  ? null
                                  : () => _deletePartnerWorker(worker),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      )),
                const Divider(height: 20),
                Row(
                  children: [
                    Text(
                      'Autovehicule partener',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: (saving || isFrozen)
                          ? null
                          : () => _addPartnerVehicle(partner),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Adauga autovehicul'),
                    ),
                  ],
                ),
                if (vehicles.isEmpty)
                  const Text('Nu exista autovehicule partener adaugate.')
                else
                  ...vehicles.map((vehicle) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(vehicle.vehicleName),
                        subtitle: Text(
                          [
                            if (vehicle.registrationNumber.isNotEmpty)
                              'Nr: ${vehicle.registrationNumber}',
                            'Km: ${vehicle.km.toStringAsFixed(2)}',
                            'Consum: ${vehicle.fuelConsumptionPer100Km.toStringAsFixed(2)} L/100 km',
                            'Pret combustibil: ${vehicle.fuelPricePerLiter.toStringAsFixed(2)} ${vehicle.currency}',
                            'Total: ${vehicle.total.toStringAsFixed(2)} ${vehicle.currency}',
                            if (vehicle.notes.isNotEmpty)
                              'Observatii: ${vehicle.notes}',
                          ].join(' • '),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Editeaza',
                              onPressed: (saving || isFrozen)
                                  ? null
                                  : () => _editPartnerVehicle(partner, vehicle),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Șterge',
                              onPressed: (saving || isFrozen)
                                  ? null
                                  : () => _deletePartnerVehicle(vehicle),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

}
