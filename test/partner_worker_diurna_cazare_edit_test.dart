import 'package:devizpro_ultra/features/jobs/dialogs/partner_worker_dialog.dart';
import 'package:devizpro_ultra/features/jobs/job_models.dart';
import 'package:devizpro_ultra/features/jobs/job_partner_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresie parteneri: editarea unui pontaj partener pe interval
/// (ex. real: Herman Sebastian, 04.08–06.08.2026, 24 h, 3 zile diurnă /
/// 3 nopți cazare) cu diurnă 55→100 și cazare 125→75.
///
/// Înainte de fix, modul editare forța `workDays: 1` și sfârșitul perioadei
/// = start, deci un pontaj de 3 zile ajungea la 1 zi diurnă / 1 noapte
/// cazare (100 + 75 în loc de 300 + 225). Testat cu dialogul REAL.
void main() {
  final partner = JobPartner(id: 'partner-1', jobId: 'job-1', name: 'ACME SRL');

  JobPartnerWorker hermanInterval() => JobPartnerWorker(
        id: 'pw-herman-1',
        jobId: 'job-1',
        partnerId: 'partner-1',
        fullName: 'Herman Sebastian',
        workedHours: 24,
        hoursPerDay: 8,
        hourlyRate: 40,
        workPeriodStart: DateTime(2026, 8, 4),
        workPeriodEnd: DateTime(2026, 8, 6),
        workDays: 3,
        perDiemDays: 3,
        perDiemPerDay: 55,
        lodgingNights: 3,
        lodgingPerNight: 125,
      );

  Future<JobPartnerWorker?> editInDialog(
    WidgetTester tester,
    JobPartnerWorker existing, {
    String? diurna,
    String? cazare,
    String? pickDay,
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<JobPartnerWorker>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showPartnerWorkerDialog(
                context,
                partner: partner,
                masterWorkers: const [],
                jobId: 'job-1',
                onValidationError: (_) {},
                existing: existing,
              );
            },
            child: const Text('deschide'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('deschide'));
    await tester.pumpAndSettle();
    if (pickDay != null) {
      // Butonul de dată al modului editare -> selectorul real de dată.
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pickDay));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
    if (diurna != null) {
      await tester.enterText(
          find.widgetWithText(TextField, 'Diurnă / zi (RON)'), diurna);
    }
    if (cazare != null) {
      await tester.enterText(
          find.widgetWithText(TextField, 'Cazare / noapte (RON)'), cazare);
    }
    await tester.tap(find.text('Salveaza'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.length, 1);
    return result!.single;
  }

  /// Traseul real de salvare: `toMap()` -> JobRecord (`job_partner_workers`,
  /// prefs/Firestore) -> `fromMap()` la recitire.
  JobPartnerWorker saveAndReload(JobPartnerWorker worker) {
    final job = JobRecord.fromMap({
      'id': 'job-1',
      'job_partner_workers': [worker.toMap()],
    });
    final reloaded = JobRecord.fromMap(job.toMap());
    return JobPartnerWorker.fromMap(
        Map<String, dynamic>.from(reloaded.jobPartnerWorkers.single));
  }

  testWidgets('exemplul real: 100/75 persistă, intervalul de 3 zile rămâne',
      (tester) async {
    final edited =
        (await editInDialog(tester, hermanInterval(), diurna: '100', cazare: '75'))!;
    final row = saveAndReload(edited);

    expect(row.id, 'pw-herman-1');
    expect(row.perDiemPerDay, 100);
    expect(row.lodgingPerNight, 75);
    expect(row.workDays, 3);
    expect(row.perDiemDays, 3);
    expect(row.lodgingNights, 3);
    expect(row.workedHours, 24);
    expect(row.workPeriodStart, DateTime(2026, 8, 4));
    expect(row.workPeriodEnd, DateTime(2026, 8, 6));
    expect(row.perDiemCost, 300);
    expect(row.lodgingCost, 225);
    expect(row.perDiemCost + row.lodgingCost, 525);
    expect(row.total, 24 * 40 + 525);
  });

  testWidgets('redeschidere: câmpurile arată 100/75; resalvare fără dublare',
      (tester) async {
    final first = saveAndReload(
        (await editInDialog(tester, hermanInterval(), diurna: '100', cazare: '75'))!);
    // Redeschide formularul și verifică valorile afișate.
    final second = saveAndReload((await editInDialog(tester, first))!);
    expect(
        find.widgetWithText(TextField, 'Diurnă / zi (RON)'), findsNothing,
        reason: 'dialogul s-a închis după salvare');
    expect(second.perDiemPerDay, 100);
    expect(second.lodgingPerNight, 75);
    expect(second.perDiemDays, 3);
    expect(second.lodgingNights, 3);
    expect(second.total, first.total);
    expect(second.total, 24 * 40 + 525);
  });

  testWidgets('valoare zero respectată (nu revine la 55/125)', (tester) async {
    final row = saveAndReload(
        (await editInDialog(tester, hermanInterval(), diurna: '0', cazare: '0'))!);
    expect(row.perDiemPerDay, 0);
    expect(row.lodgingPerNight, 0);
    expect(row.perDiemCost, 0);
    expect(row.lodgingCost, 0);
    expect(row.total, 24 * 40);
  });

  testWidgets('modificarea unui singur câmp (doar diurna)', (tester) async {
    final row = saveAndReload(
        (await editInDialog(tester, hermanInterval(), diurna: '100'))!);
    expect(row.perDiemPerDay, 100);
    expect(row.lodgingPerNight, 125);
    expect(row.perDiemCost, 300);
    expect(row.lodgingCost, 375);
  });

  testWidgets('pontaj pe o singură zi rămâne 1 zi la editare', (tester) async {
    final single = hermanInterval().copyWith(
      workedHours: 8,
      workPeriodEnd: DateTime(2026, 8, 4),
      workDays: 1,
      perDiemDays: 1,
      lodgingNights: 1,
    );
    final row = saveAndReload(
        (await editInDialog(tester, single, diurna: '100', cazare: '75'))!);
    expect(row.workDays, 1);
    expect(row.perDiemDays, 1);
    expect(row.lodgingNights, 1);
    expect(row.workPeriodEnd, DateTime(2026, 8, 4));
    expect(row.perDiemCost + row.lodgingCost, 175);
  });

  testWidgets('afișează perioada completă la editarea unui interval',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPartnerWorkerDialog(
              context,
              partner: partner,
              masterWorkers: const [],
              jobId: 'job-1',
              onValidationError: (_) {},
              existing: hermanInterval(),
            ),
            child: const Text('deschide'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('deschide'));
    await tester.pumpAndSettle();
    expect(find.textContaining('04.08.2026'), findsOneWidget);
    expect(find.textContaining('06.08.2026'), findsOneWidget);
  });

  group('mutarea perioadei la schimbarea datei (fără reducere la 1 zi)', () {
    JobPartnerWorker interval(DateTime start, DateTime end) => JobPartnerWorker(
          id: 'pw-herman-1',
          jobId: 'job-1',
          partnerId: 'partner-1',
          fullName: 'Herman Sebastian',
          workedHours: 24,
          hoursPerDay: 8,
          hourlyRate: 40,
          workPeriodStart: start,
          workPeriodEnd: end,
          workDays: 3,
          perDiemDays: 3,
          perDiemPerDay: 55,
          lodgingNights: 3,
          lodgingPerNight: 125,
        );

    void expectThreeDays(JobPartnerWorker row, DateTime start, DateTime end) {
      expect(row.id, 'pw-herman-1', reason: 'același rând, vecinii neatinși');
      expect(row.workPeriodStart, start);
      expect(row.workPeriodEnd, end);
      expect(row.workDays, 3);
      expect(row.perDiemDays, 3);
      expect(row.lodgingNights, 3);
      expect(row.workedHours, 24);
    }

    testWidgets('04–06.08 mutat la 05.08 devine 05–07.08, 3 zile, 525 RON',
        (tester) async {
      final partnerBefore = partner.toMap();
      final row = saveAndReload((await editInDialog(tester, hermanInterval(),
          diurna: '100', cazare: '75', pickDay: '5'))!);

      expectThreeDays(row, DateTime(2026, 8, 5), DateTime(2026, 8, 7));
      expect(row.perDiemPerDay, 100);
      expect(row.lodgingPerNight, 75);
      expect(row.perDiemCost, 300);
      expect(row.lodgingCost, 225);
      expect(row.perDiemCost + row.lodgingCost, 525);
      expect(row.total, 24 * 40 + 525);
      expect(partner.toMap(), partnerBefore,
          reason: 'datele partenerului nu sunt modificate de dialog');
    });

    testWidgets('mutarea fără schimbare de tarife păstrează tarifele',
        (tester) async {
      final row = saveAndReload(
          (await editInDialog(tester, hermanInterval(), pickDay: '10'))!);

      expectThreeDays(row, DateTime(2026, 8, 10), DateTime(2026, 8, 12));
      expect(row.perDiemPerDay, 55);
      expect(row.lodgingPerNight, 125);
      expect(row.perDiemCost + row.lodgingCost, 3 * 55 + 3 * 125);
    });

    testWidgets('peste sfârșitul lunii: mutat la 31.08 devine 31.08–02.09',
        (tester) async {
      final row = saveAndReload(
          (await editInDialog(tester, hermanInterval(), pickDay: '31'))!);

      expectThreeDays(row, DateTime(2026, 8, 31), DateTime(2026, 9, 2));
    });

    testWidgets('peste sfârșitul anului: 30.12.2026–01.01.2027',
        (tester) async {
      final row = saveAndReload((await editInDialog(
          tester, interval(DateTime(2026, 12, 4), DateTime(2026, 12, 6)),
          pickDay: '30'))!);

      expectThreeDays(row, DateTime(2026, 12, 30), DateTime(2027, 1, 1));
    });

    testWidgets('afișează noua perioadă în dialog după mutare', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPartnerWorkerDialog(
                context,
                partner: partner,
                masterWorkers: const [],
                jobId: 'job-1',
                onValidationError: (_) {},
                existing: hermanInterval(),
              ),
              child: const Text('deschide'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('deschide'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('05.08.2026'), findsOneWidget);
      expect(find.textContaining('07.08.2026'), findsOneWidget);
    });
  });

  group('shiftPartnerWorkPeriod (funcția pură)', () {
    test('păstrează durata calendaristică, inclusiv la trecerea la ora de vară',
        () {
      // 2026-03-29: trecerea la ora de vară în România (zi de 23 h).
      final shifted = shiftPartnerWorkPeriod(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 3),
        newStart: DateTime(2026, 3, 28),
      );
      expect(shifted.start, DateTime(2026, 3, 28));
      expect(shifted.end, DateTime(2026, 3, 30));
    });

    test('un pontaj de o zi rămâne de o zi', () {
      final shifted = shiftPartnerWorkPeriod(
        start: DateTime(2026, 8, 4),
        end: DateTime(2026, 8, 4),
        newStart: DateTime(2026, 8, 9),
      );
      expect(shifted.start, DateTime(2026, 8, 9));
      expect(shifted.end, DateTime(2026, 8, 9));
    });

    test('un sfârșit anterior începutului nu produce o durată negativă', () {
      final shifted = shiftPartnerWorkPeriod(
        start: DateTime(2026, 8, 6),
        end: DateTime(2026, 8, 4),
        newStart: DateTime(2026, 8, 10),
      );
      expect(shifted.start, DateTime(2026, 8, 10));
      expect(shifted.end, DateTime(2026, 8, 10));
    });
  });
}
