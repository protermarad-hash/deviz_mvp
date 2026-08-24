import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devizpro_ultra/features/jobs/dialogs/per_day_hours_editor.dart';

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

void main() {
  Widget harness({
    required List<DateTime> days,
    required double initialHoursPerDay,
    required void Function(Map<DateTime, double>) onChanged,
    Key? editorKey,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PerDayHoursEditor(
          key: editorKey,
          days: days,
          initialHoursPerDay: initialHoursPerDay,
          formatHours: _fmt,
          onChanged: onChanged,
        ),
      ),
    );
  }

  testWidgets('precompletează fiecare zi cu ora implicită și raportează suma inițială',
      (tester) async {
    Map<DateTime, double>? lastReported;
    final days = [DateTime(2026, 7, 6), DateTime(2026, 7, 8)];
    await tester.pumpWidget(harness(
      days: days,
      initialHoursPerDay: 8,
      onChanged: (v) => lastReported = v,
    ));
    await tester.pumpAndSettle();

    expect(find.text('8'), findsNWidgets(2)); // ambele zile precompletate
    expect(lastReported, isNotNull);
    expect(lastReported![days[0]], 8);
    expect(lastReported![days[1]], 8);
  });

  testWidgets('editarea unei singure zile NU afectează celelalte zile',
      (tester) async {
    Map<DateTime, double>? lastReported;
    final days = [DateTime(2026, 7, 6), DateTime(2026, 7, 8), DateTime(2026, 7, 10)];
    await tester.pumpWidget(harness(
      days: days,
      initialHoursPerDay: 8,
      onChanged: (v) => lastReported = v,
    ));
    await tester.pumpAndSettle();

    // Editează DOAR câmpul de ore al primei zile (06.07.2026).
    final firstField = find.byType(TextField).first;
    await tester.enterText(firstField, '3');
    await tester.pumpAndSettle();

    expect(lastReported![days[0]], 3);
    expect(lastReported![days[1]], 8); // neschimbat
    expect(lastReported![days[2]], 8); // neschimbat
  });

  testWidgets('applyToAll suprascrie ora TUTUROR zilelor', (tester) async {
    Map<DateTime, double>? lastReported;
    final key = GlobalKey<PerDayHoursEditorState>();
    final days = [DateTime(2026, 7, 6), DateTime(2026, 7, 8)];
    await tester.pumpWidget(harness(
      days: days,
      initialHoursPerDay: 8,
      editorKey: key,
      onChanged: (v) => lastReported = v,
    ));
    await tester.pumpAndSettle();

    // Modifică manual o zi, apoi aplică 5 ore la toate.
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.pumpAndSettle();
    expect(lastReported![days[0]], 2);

    key.currentState!.applyToAll(5);
    await tester.pumpAndSettle();

    expect(lastReported![days[0]], 5);
    expect(lastReported![days[1]], 5);
    expect(find.text('5'), findsNWidgets(2));
  });

  testWidgets('currentValues reflectă exact textul curent din câmpuri',
      (tester) async {
    final key = GlobalKey<PerDayHoursEditorState>();
    final days = [DateTime(2026, 7, 6)];
    await tester.pumpWidget(harness(
      days: days,
      initialHoursPerDay: 8,
      editorKey: key,
      onChanged: (_) {},
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '4.5');
    await tester.pumpAndSettle();

    expect(key.currentState!.currentValues[days[0]], 4.5);
  });
}
