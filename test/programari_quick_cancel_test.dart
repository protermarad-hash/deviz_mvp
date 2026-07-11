import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/programari/appointment_models.dart';
import 'package:devizpro_ultra/features/programari/programare_cancel_confirm_dialog.dart';

/// Harness care reproduce exact fluxul din `_quickCancel` +
/// `_quickChangeStatus` din `programari_page.dart`:
///   buton "Anuleaza" -> showDialog(ProgramariCancelConfirmDialog) ->
///   daca se confirma (true) -> status devine 'anulata'.
/// Foloseste dialogul REAL (`ProgramariCancelConfirmDialog`) si tranzitia
/// reala de status prin `Appointment.copyWith(status: 'anulata')`.
class _QuickCancelHarness extends StatefulWidget {
  const _QuickCancelHarness({required this.initial});

  final Appointment initial;

  @override
  State<_QuickCancelHarness> createState() => _QuickCancelHarnessState();
}

class _QuickCancelHarnessState extends State<_QuickCancelHarness> {
  late Appointment _item = widget.initial;

  Future<void> _quickCancel(BuildContext dialogHostContext) async {
    final confirmed = await showDialog<bool>(
      context: dialogHostContext,
      builder: (_) => const ProgramariCancelConfirmDialog(),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _item = _item.copyWith(status: 'anulata'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (innerContext) => Column(
            children: [
              Text('status:${_item.status}'),
              OutlinedButton(
                onPressed: () => _quickCancel(innerContext),
                child: const Text('Anuleaza'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Appointment _buildAppointment() {
  return Appointment.fromMap({
    'id': 'appt-cancel-test',
    'clientName': 'Client test',
    'scheduledDate': '2026-07-13T00:00:00.000',
    'startTime': '08:00',
    'endTime': '10:00',
    'status': 'programata',
  });
}

void main() {
  group('_quickCancel flux anulare rapida', () {
    testWidgets(
        'tap Anuleaza -> confirma "Anuleaza programarea" -> status devine anulata',
        (tester) async {
      await tester.pumpWidget(_QuickCancelHarness(initial: _buildAppointment()));

      // Preconditie: status initial.
      expect(find.text('status:programata'), findsOneWidget);

      // Tap pe butonul "Anuleaza".
      await tester.tap(find.widgetWithText(OutlinedButton, 'Anuleaza'));
      await tester.pumpAndSettle();

      // Dialogul de confirmare a aparut.
      expect(find.text('Sigur anulezi această programare?'), findsOneWidget);

      // Tap pe butonul de confirmare din dialog.
      await tester.tap(
          find.widgetWithText(FilledButton, 'Anulează programarea'));
      await tester.pumpAndSettle();

      // Status-ul a devenit 'anulata'.
      expect(find.text('status:anulata'), findsOneWidget);
    });

    testWidgets('tap Anuleaza -> "Nu" -> status ramane neschimbat',
        (tester) async {
      await tester.pumpWidget(_QuickCancelHarness(initial: _buildAppointment()));

      expect(find.text('status:programata'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Anuleaza'));
      await tester.pumpAndSettle();

      expect(find.text('Sigur anulezi această programare?'), findsOneWidget);

      // Tap pe "Nu" -> anuleaza actiunea.
      await tester.tap(find.widgetWithText(TextButton, 'Nu'));
      await tester.pumpAndSettle();

      // Status-ul a ramas neschimbat.
      expect(find.text('status:programata'), findsOneWidget);
      expect(find.text('status:anulata'), findsNothing);
    });
  });
}
