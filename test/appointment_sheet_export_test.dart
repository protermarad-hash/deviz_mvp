import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/hr/employee_financial_models.dart';
import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/programari/appointment_sheet_pdf_service.dart';

void main() {
  // Programare complet populată — teren + toate câmpurile administrative.
  Appointment fullAppointment() => Appointment.fromMap({
        'id': 'apt-1',
        'client_id': 'cli-1',
        'client_name': 'Client Test SRL',
        'contracting_client_id': 'cli-2',
        'contracting_client_name': 'Contractant SA',
        'title': 'Revizie CTA hala',
        'location': 'Str. Fabricii 10, Arad',
        'scheduled_date': '2026-07-10T00:00:00.000',
        'start_time': '09:00',
        'end_time': '11:30',
        'status': 'finalizata',
        'priority': 'ridicata',
        'type': 'interventie',
        'complaint_visit_type': 'interventie',
        'complaint_visit_outcome': 'rezolvata',
        'complaint_number': 'REC-2026-0007',
        'complaint_id': 'cmp-1',
        'job_id': 'job-1',
        'assigned_user_email': 'tehnician@proterm.ro',
        'vehicle_id': 'veh-1',
        'equipment_description': 'CTA Daikin 2000mc/h',
        'notes': 'Client mulțumit.',
        'intervention_price': 850.0,
        'intervention_price_currency': 'RON',
        // ── administrativ ──
        'admin_collected_amount': 850.0,
        'admin_collected_currency': 'RON',
        'admin_financial_status': 'incasata',
        'admin_due_date': '2026-07-15T00:00:00.000',
        'admin_financial_notes': 'Achitat numerar.',
        'for_partner_id': 'prt-1',
        'for_partner_name': 'Partener Beneficiar SRL',
        'for_partner_invoice_amount': 1000.0,
        'for_partner_invoice_currency': 'RON',
        'for_partner_receive_status': 'neplatit',
        'executing_partner_id': 'prt-2',
        'executing_partner_name': 'Executant SRL',
        'executing_partner_commission': 200.0,
        'executing_partner_commission_currency': 'RON',
        'executing_partner_payment_status': 'neplatit',
        'material_usage': {
          'kit_template_name': 'Kit filtre CTA',
          'linear_meters_used': 5.0,
          'facturabil_partener': true,
          'lines': [
            {
              'id': 'l1',
              'name': 'Filtru G4',
              'unit': 'buc',
              'quantity': 4.0,
              'unit_cost': 25.0,
            },
          ],
        },
      });

  const labels = AppointmentSheetLabels(
    clientName: 'Client Test SRL',
    addressLabel: 'Str. Fabricii 10, Arad',
    clientAddressFromRecord: 'Str. Fabricii 10, Arad, Arad',
    contractingClientName: 'Contractant SA',
    teamLabel: 'Echipa A',
    employeeLabel: 'Ion Popescu',
    vehicleLabel: 'Dacia Dokker AR-01-PRO',
    jobLabel: 'JOB-001 — Revizie CTA',
    statusLabel: 'Finalizata',
    priorityLabel: 'Ridicata',
    contactPerson: 'Maria Ionescu',
    phones: ['0740123456', '0256123456'],
    email: 'contact@client.ro',
  );

  // Câteva câmpuri administrative reprezentative de verificat că NU apar.
  const adminLabelSamples = <String>[
    'Status financiar',
    'Încasare / valoare internă',
    'Observații financiare',
    'Societate contractantă',
    'Partener beneficiar',
    'Partener executant',
    'Comision',
    'Cost materiale estimat',
    'Profit estimat',
    'Facturabil partener',
    'Total datorat',
  ];

  bool contentHasAnyLabel(
    AppointmentSheetContent content,
    List<String> labelsToFind,
  ) {
    final all = <String>[
      ...content.allTerenLabels,
      ...content.allAdminLabels,
      for (final s in content.terenSections) s.title,
      for (final s in content.adminSections) s.title,
    ];
    return labelsToFind.any(all.contains);
  }

  group('Gating pe rol — export fișă programare', () {
    test('(a) Non-admin: zero câmpuri administrative, doar teren', () {
      final content = AppointmentSheetPdfService.buildContent(
        appointment: fullAppointment(),
        labels: labels,
        // Chiar dacă cineva forțează toate opțiunile true, isAdmin=false le ignoră.
        options: const AppointmentSheetExportOptions(
          financiarIntern: true,
          costuriMateriale: true,
          societateContractanta: true,
          partenerBeneficiar: true,
          partenerExecutant: true,
          platiAngajati: true,
        ),
        isAdmin: false,
      );

      expect(content.adminSections, isEmpty,
          reason: 'Non-admin nu trebuie să aibă NICIO secțiune administrativă');
      expect(contentHasAnyLabel(content, adminLabelSamples), isFalse,
          reason: 'Niciun câmp administrativ nu trebuie să apară pentru non-admin');
      // Verifică prezența câmpurilor teren-cheie.
      expect(content.allTerenLabels, contains('Preț intervenție'));
      expect(content.allTerenLabels, contains('Beneficiar'));
      expect(content.allTerenLabels, contains('Status'));
    });

    test('(b) Admin fără nicio bifă: identic cu non-admin (doar teren)', () {
      final adminNoFlags = AppointmentSheetPdfService.buildContent(
        appointment: fullAppointment(),
        labels: labels,
        options: const AppointmentSheetExportOptions(),
        isAdmin: true,
      );
      final nonAdmin = AppointmentSheetPdfService.buildContent(
        appointment: fullAppointment(),
        labels: labels,
        options: const AppointmentSheetExportOptions(),
        isAdmin: false,
      );

      expect(adminNoFlags.adminSections, isEmpty);
      expect(contentHasAnyLabel(adminNoFlags, adminLabelSamples), isFalse);
      // Aceleași etichete teren ca non-admin.
      expect(adminNoFlags.allTerenLabels, equals(nonAdmin.allTerenLabels));
    });

    test('(c) Admin cu bife selective: teren + exact câmpurile bifate', () {
      final content = AppointmentSheetPdfService.buildContent(
        appointment: fullAppointment(),
        labels: labels,
        // Doar Financiar intern bifat (preț e teren, mereu prezent).
        options: const AppointmentSheetExportOptions(financiarIntern: true),
        isAdmin: true,
      );

      // Exact o secțiune administrativă: Financiar intern.
      expect(content.adminSections.length, 1);
      expect(content.adminSections.first.title, 'Financiar intern');
      expect(content.allAdminLabels, contains('Status financiar'));
      expect(content.allAdminLabels, contains('Încasare / valoare internă'));

      // Câmpurile din alte secțiuni administrative NU trebuie să apară.
      expect(content.allAdminLabels, isNot(contains('Comision')));
      expect(content.allAdminLabels, isNot(contains('Societate contractantă')));
      expect(content.allAdminLabels, isNot(contains('Total datorat')));
      // Prețul de intervenție (teren) rămâne prezent.
      expect(content.allTerenLabels, contains('Preț intervenție'));
    });

    test('(d) Admin cu "Plăți angajați" bifat: secțiunea apare cu datele fetch',
        () {
      final payEntries = <EmployeePayEntry>[
        EmployeePayEntry.create(
          employeeId: 'emp-1',
          employeeName: 'Ion Popescu',
          appointmentId: 'apt-1',
          appointmentTitle: 'Revizie CTA hala',
          appointmentDate: '2026-07-10',
          amountDue: 150.0,
          currency: 'RON',
          notes: 'Manoperă',
        ),
      ];

      final content = AppointmentSheetPdfService.buildContent(
        appointment: fullAppointment(),
        labels: labels,
        options: const AppointmentSheetExportOptions(platiAngajati: true),
        isAdmin: true,
        payEntries: payEntries,
      );

      final platiSection = content.adminSections
          .where((s) => s.title == 'Plăți angajați')
          .toList();
      expect(platiSection.length, 1,
          reason: 'Secțiunea Plăți angajați trebuie să apară când e bifată și există date');
      expect(platiSection.first.table, isNotNull);
      expect(platiSection.first.table!.rows.length, 1);
      expect(platiSection.first.table!.rows.first.first, 'Ion Popescu');
      expect(content.allAdminLabels, contains('Total datorat'));

      // Fără date fetch, secțiunea NU apare (chiar dacă e bifată).
      final noData = AppointmentSheetPdfService.buildContent(
        appointment: fullAppointment(),
        labels: labels,
        options: const AppointmentSheetExportOptions(platiAngajati: true),
        isAdmin: true,
        payEntries: const <EmployeePayEntry>[],
      );
      expect(
        noData.adminSections.where((s) => s.title == 'Plăți angajați'),
        isEmpty,
      );
    });
  });
}
