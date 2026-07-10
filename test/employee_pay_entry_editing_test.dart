import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/hr/employee_financial_models.dart';
import 'package:devizpro_ultra/features/programari/employee_pay_editing_guard.dart';

void main() {
  group('EmployeePayEntry mapping', () {
    test('keeps appointment_id and amount_due through toMap/fromMap', () {
      final entry = EmployeePayEntry(
        id: 'pay-1',
        employeeId: 'emp-1',
        employeeName: 'Angajat test',
        appointmentId: 'appt-1',
        appointmentTitle: 'Programare test',
        appointmentDate: '2026-07-10',
        jobId: 'job-1',
        jobTitle: 'Lucrare test',
        amountDue: 125.5,
        currency: 'RON',
        notes: 'test',
        createdAt: DateTime(2026, 7, 10, 9),
        createdBy: 'user-1',
      );

      final map = entry.toMap();

      expect(map['appointment_id'], 'appt-1');
      expect(map['amount_due'], 125.5);

      final parsed = EmployeePayEntry.fromMap(map);

      expect(parsed.appointmentId, 'appt-1');
      expect(parsed.amountDue, 125.5);
      expect(parsed.employeeId, 'emp-1');
    });
  });

  group('employee pay edit guard', () {
    test('allows delete only when editing and preload is conclusive', () {
      expect(
        canDeleteMissingEmployeePayEntries(
          isEditingExisting: true,
          payEntriesLoadConclusive: true,
        ),
        isTrue,
      );
    });

    test('blocks delete when preload is inconclusive', () {
      expect(
        canDeleteMissingEmployeePayEntries(
          isEditingExisting: true,
          payEntriesLoadConclusive: false,
        ),
        isFalse,
      );
    });

    test('blocks delete for new appointments', () {
      expect(
        canDeleteMissingEmployeePayEntries(
          isEditingExisting: false,
          payEntriesLoadConclusive: true,
        ),
        isFalse,
      );
    });
  });
}
