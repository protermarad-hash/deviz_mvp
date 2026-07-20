import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/asociere/asociere_access_policy.dart';
import 'package:devizpro_ultra/features/asociere/asociere_analytics.dart';
import 'package:devizpro_ultra/features/asociere/asociere_operational_common.dart';
import 'package:devizpro_ultra/features/asociere/cazare_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/cost_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/deplasare_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/diurna_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/lucrare_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/pontaj_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/tarif_asociere_models.dart';
import 'package:devizpro_ultra/features/asociere/venit_asociere_models.dart';

void main() {
  final now = DateTime(2026, 7, 20, 10);
  LucrareAsociereRecord project({double pt = 50, double partner = 50}) =>
      LucrareAsociereRecord(
        id: 'p1',
        numar: 'AS-1',
        denumire: 'Proiect',
        partnerId: 'partner-1',
        partnerNameSnapshot: 'Partener',
        dataInceput: now,
        cotaProTerm: pt,
        cotaPartener: partner,
        createdAt: now,
        updatedAt: now,
      );

  test('proiectul independent serializează și validează cotele', () {
    final value = project();
    final restored = LucrareAsociereRecord.fromMap(value.toMap());
    expect(restored.id, value.id);
    expect(restored.partnerId, 'partner-1');
    expect(restored.validate(), isEmpty);
    expect(project(pt: 60, partner: 30).validate(), isNotEmpty);
  });

  test('tariful este versionat și are perioadă de valabilitate', () {
    final value = TarifAsociereRecord(
      id: 't1',
      projectId: 'p1',
      calificare: 'instalator',
      tarifOra: 50,
      tarifKm: 2,
      valabilDeLa: now,
      createdAt: now,
      updatedAt: now,
    );
    expect(value.esteValabilLa(now.add(const Duration(days: 1))), isTrue);
    expect(value.toMap()['project_id'], 'p1');
    expect(value.toMap(), isNot(contains('lucrare_id')));
  });

  test('pontajul păstrează snapshot și confirmarea externă cere audit', () {
    final value = PontajAsociereRecord(
      id: 'po1',
      projectId: 'p1',
      persoanaId: 'u1',
      persoanaNameSnapshot: 'Persoană',
      angajator: AsociereAngajator.proTerm,
      calificare: 'instalator',
      data: now,
      ore: 8,
      tarifSnapshot: 50,
      costCalculat: 400,
      confirmareExternaInregistrata: true,
      createdAt: now,
      updatedAt: now,
    );
    expect(value.tarifSnapshot, 50);
    expect(value.validate(), isNotEmpty);
  });

  test('transport tarif/km și combustibil sunt mutual exclusive', () {
    DeplasareAsociereRecord travel(DeplasareCalcul method) =>
        DeplasareAsociereRecord(
          id: method.name,
          projectId: 'p1',
          dataPlecare: now,
          dataRevenire: now,
          punctPlecare: 'A',
          destinatie: 'B',
          metodaCalcul: method,
          kilometriReali: 100,
          tarifKmSnapshot: 2,
          consum: 8,
          pretCombustibil: 7.5,
          taxeDrum: 10,
          createdAt: now,
          updatedAt: now,
        );
    expect(travel(DeplasareCalcul.tarifKm).calculeazaTransport(), 210);
    expect(travel(DeplasareCalcul.combustibil).calculeazaTransport(), 70);
  });

  test('cazarea și diurna folosesc tarife configurabile', () {
    final lodging = CazareAsociereRecord(
      id: 'c1',
      projectId: 'p1',
      furnizor: 'F',
      localitate: 'L',
      checkIn: now,
      checkOut: now.add(const Duration(days: 2)),
      nopti: 2,
      persoane: 3,
      camere: 2,
      tarif: 100,
      createdAt: now,
      updatedAt: now,
    );
    final allowance = DiurnaAsociereRecord(
      id: 'd1',
      projectId: 'p1',
      persoanaId: 'u1',
      persoanaSnapshot: 'P',
      dataInceput: now,
      dataSfarsit: now.add(const Duration(days: 2)),
      zileEligibile: 2.5,
      tarifZi: 60,
      createdAt: now,
      updatedAt: now,
    );
    expect(lodging.calculeazaCost(), 600);
    expect(allowance.calculeazaValoare(), 150);
  });

  test('costul aprobat cere document, actor și timestamp', () {
    final cost = CostAsociereRecord(
      id: 'c1',
      projectId: 'p1',
      sourceType: 'manual',
      sourceId: 's1',
      categorie: AsociereCostCategorie.materiale,
      descriere: 'Material',
      data: now,
      valoareFaraTva: 100,
      valoareProiect: 100,
      platitor: AsociereParte.proTerm,
      status: AsociereOperationalStatus.aprobat,
      createdAt: now,
      updatedAt: now,
    );
    expect(cost.validate(), isNotEmpty);
    expect(cost.idempotencyKey, 'p1:manual:s1');
  });

  test('venitul estimat nu este încasare', () {
    final income = VenitAsociereRecord(
      id: 'v1',
      projectId: 'p1',
      etapa: VenitAsociereEtapa.estimat,
      valoareFaraTva: 5000,
      createdAt: now,
      updatedAt: now,
    );
    expect(income.esteIncasat, isFalse);
    expect(income.validate(), isEmpty);
  });

  test('alertele folosesc date reale și rolurile ascund financiarul', () {
    final data = AsociereAnalytics(project: project());
    expect(data.venitIncasat, 0);
    expect(
        AsociereAccessPolicy.allows(
            'tehnician', AsocierePermission.viewFinancial),
        isFalse);
    expect(
        AsociereAccessPolicy.allows('birou', AsocierePermission.manageProject),
        isTrue);
    expect(
        AsociereAccessPolicy.allows(
            'sef_echipa', AsocierePermission.manageOperations),
        isTrue);
    expect(
        AsociereAccessPolicy.allows(
            'sef_echipa', AsocierePermission.configureRates),
        isFalse);
  });
}
