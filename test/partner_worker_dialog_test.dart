import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/jobs/dialogs/partner_worker_dialog.dart';
import 'package:devizpro_ultra/features/jobs/dialogs/per_day_hours_editor.dart';
import 'package:devizpro_ultra/features/jobs/job_partner_models.dart';

/// Reproduce fluxul real din `showPartnerWorkerDialog` (Faza 1, paritate
/// pontaj partener): interval continuu -> 1 rând, zile individuale -> N
/// rânduri, editare -> 1 rând actualizat. Testat cu widget-ul REAL, nu o
/// reimplementare a logicii.
void main() {
  final partner = JobPartner(id: 'partner-1', jobId: 'job-1', name: 'ACME SRL');

  testWidgets('interval (implicit, aceeasi zi start=sfarsit) -> 1 rand cu ore/tarif corecte',
      (tester) async {
    // Viteza test standard (800x600) e prea mica pentru grila calendarului
    // din _MultiDayPickerDialog (pre-existent, nemodificat) -> overflow
    // vertical doar in mediul de test. Marim viewport-ul de test peste tot,
    // pentru consistenta intre teste.
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
              );
            },
            child: const Text('deschide'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('deschide'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Nume complet'), 'Ion Popescu');
    await tester.enterText(find.widgetWithText(TextField, 'Ore/zi'), '10');
    await tester.enterText(
        find.widgetWithText(TextField, 'Tarif negociat / ora'), '55');

    await tester.tap(find.text('Salveaza'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.length, 1);
    final row = result!.first;
    expect(row.fullName, 'Ion Popescu');
    expect(row.hoursPerDay, 10);
    expect(row.hourlyRate, 55);
    expect(row.workDays, 1);
    expect(row.workedHours, 10); // 1 zi x 10 ore/zi
    expect(row.workPeriodStart, isNotNull);
    expect(row.workPeriodStart, row.workPeriodEnd);
  });

  testWidgets('zile individuale -> N randuri, unul per zi selectata',
      (tester) async {
    // Viteza test standard (800x600) e prea mica pentru grila calendarului
    // din _MultiDayPickerDialog (pre-existent, nemodificat) -> overflow
    // vertical doar in mediul de test. Marim viewport-ul de test peste tot,
    // pentru consistenta intre teste.
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
              );
            },
            child: const Text('deschide'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('deschide'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Nume complet'), 'Vasile Ionescu');
    await tester.enterText(find.widgetWithText(TextField, 'Ore/zi'), '8');
    await tester.enterText(
        find.widgetWithText(TextField, 'Tarif negociat / ora'), '40');

    // Comută pe "Zile individuale".
    await tester.ensureVisible(find.text('Zile individuale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zile individuale'));
    await tester.pumpAndSettle();

    // Deschide selectorul multi-zi si bifeaza 2 zile din luna curent afisata
    // (zilele 10 si 15 exista in orice luna).
    await tester.ensureVisible(find.text('Selectează zile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selectează zile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmă'));
    await tester.pumpAndSettle();

    expect(find.text('2 zile selectate'), findsOneWidget);

    await tester.tap(find.text('Salveaza'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.length, 2);
    for (final row in result!) {
      expect(row.fullName, 'Vasile Ionescu');
      expect(row.hoursPerDay, 8);
      expect(row.workedHours, 8); // 1 zi x 8 ore/zi per rand
      expect(row.hourlyRate, 40);
      expect(row.workDays, 1);
    }
    // Zilele celor 2 randuri sunt distincte.
    expect(result![0].workPeriodStart, isNot(result![1].workPeriodStart));
  });

  testWidgets(
      'zile individuale -> ore editate individual per zi, fiecare rand isi pastreaza propria ora',
      (tester) async {
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
              );
            },
            child: const Text('deschide'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('deschide'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Nume complet'), 'Mihai Popa');
    await tester.enterText(find.widgetWithText(TextField, 'Ore/zi'), '8');
    await tester.enterText(
        find.widgetWithText(TextField, 'Tarif negociat / ora'), '30');

    await tester.ensureVisible(find.text('Zile individuale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zile individuale'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Selectează zile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selectează zile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10'));
    await tester.tap(find.text('15'));
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmă'));
    await tester.pumpAndSettle();
    expect(find.text('3 zile selectate'), findsOneWidget);

    // "Ore per zi" - editorul per-zi trebuie sa fie vizibil, precompletat
    // cu "Ore/zi" implicit (8) pentru toate cele 3 zile. Scopeaza cautarea
    // STRICT la campurile din PerDayHoursEditor (nu si campul global
    // "Ore/zi implicit", care afiseaza tot '8') - altfel riscam sa editam
    // campul gresit.
    await tester.ensureVisible(find.text('Ore per zi (editabile individual)'));
    await tester.pumpAndSettle();
    final perDayFieldsFinder = find.descendant(
      of: find.byType(PerDayHoursEditor),
      matching: find.byType(TextField),
    );
    expect(perDayFieldsFinder, findsNWidgets(3));

    // Editeaza DOAR primele 2 campuri de ore per-zi (lasa a treia zi la 8).
    await tester.enterText(perDayFieldsFinder.at(0), '2');
    await tester.pumpAndSettle();
    await tester.enterText(perDayFieldsFinder.at(1), '5');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salveaza'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.length, 3);
    final hoursSet = result!.map((r) => r.hoursPerDay).toSet();
    // Cele 3 randuri NU au toate aceeasi ora (era imposibil inainte de
    // Faza 1 - exact gap-ul raportat de utilizator).
    expect(hoursSet.length, greaterThan(1));
    // Fiecare rand: workedHours == hoursPerDay (1 zi per rand).
    for (final row in result!) {
      expect(row.workedHours, row.hoursPerDay);
    }
    // Suma orelor reflecta editarile (2 + 5 + 8 = 15), nu 3 * 8 = 24.
    final totalHours =
        result!.fold<double>(0, (s, r) => s + r.hoursPerDay);
    expect(totalHours, 15);
  });

  testWidgets('diurna si cazare active -> incluse in randul generat',
      (tester) async {
    // Viteza test standard (800x600) e prea mica pentru grila calendarului
    // din _MultiDayPickerDialog (pre-existent, nemodificat) -> overflow
    // vertical doar in mediul de test. Marim viewport-ul de test peste tot,
    // pentru consistenta intre teste.
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
              );
            },
            child: const Text('deschide'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('deschide'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Nume complet'), 'Mihai Stan');
    await tester.enterText(
        find.widgetWithText(TextField, 'Tarif negociat / ora'), '30');

    await tester.ensureVisible(find.text('Include diurnă'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include diurnă'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextField, 'Diurnă / zi (RON)'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Diurnă / zi (RON)'), '50');

    await tester.ensureVisible(find.text('Include cazare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include cazare'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.widgetWithText(TextField, 'Cazare / noapte (RON)'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Cazare / noapte (RON)'), '120');

    await tester.tap(find.text('Salveaza'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    final row = result!.single;
    expect(row.perDiemDays, 1);
    expect(row.perDiemPerDay, 50);
    expect(row.lodgingNights, 1);
    expect(row.lodgingPerNight, 120);
    expect(row.perDiemCost, 50);
    expect(row.lodgingCost, 120);
  });

  testWidgets('editare rand existent -> 1 rand cu id pastrat, fara selector interval',
      (tester) async {
    final existing = JobPartnerWorker(
      id: 'existing-row-1',
      jobId: 'job-1',
      partnerId: 'partner-1',
      fullName: 'Ana Dinu',
      role: 'Sudor',
      workedHours: 8,
      hoursPerDay: 8,
      hourlyRate: 45,
      workPeriodStart: DateTime(2026, 6, 10),
      workPeriodEnd: DateTime(2026, 6, 10),
      workDays: 1,
      currency: 'RON',
    );

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

    // Fara selector Interval/Zile individuale la editare.
    expect(find.text('Interval'), findsNothing);
    expect(find.text('Zile individuale'), findsNothing);

    await tester.enterText(
        find.widgetWithText(TextField, 'Tarif negociat / ora'), '60');

    await tester.tap(find.text('Salveaza'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.length, 1);
    expect(result!.first.id, 'existing-row-1');
    expect(result!.first.hourlyRate, 60);
  });
}
