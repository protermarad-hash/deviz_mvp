import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/asociere/ui/asociere_chart_card.dart';
import 'package:flutter/material.dart';

void main() {
  test('modulul Asociere nu depinde de JobRecord sau lucrareId', () {
    final directory = Directory('lib/features/asociere');
    final source = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(source, isNot(contains('JobRecord')));
    expect(source, isNot(contains('lucrareId')));
    expect(source, isNot(contains("'lucrare_id'")));
  });

  test('Lucrări are cinci taburi și nu importă Asociere', () {
    final source =
        File('lib/features/jobs/lucrare_detalii_page.dart').readAsStringSync();
    expect(
      RegExp(r'DefaultTabController\(\s*length:\s*5').hasMatch(source),
      isTrue,
    );
    expect(source, isNot(contains("asociere/ui")));
    expect(source, isNot(contains("text: 'Asociere'")));
  });

  test('navigația principală expune destinația Asocieri', () {
    final source = File('lib/app/role_ready_shell.dart').readAsStringSync();
    expect(source, contains("id: 'asocieri'"));
    expect(source, contains('AsociereModulePage'));
  });

  testWidgets('graficul are stare goală fără valori fictive', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AsociereChartCard(title: 'Grafic', series: []))));
    expect(
        find.text('Nu există date pentru perioada selectată.'), findsOneWidget);
  });

  test('exporturile MVP sunt prezente', () {
    final source =
        File('lib/features/asociere/asociere_csv_export_service.dart')
            .readAsStringSync();
    for (final name in [
      'exportRegistru',
      'exportDecont',
      'exportPontaje',
      'exportDeplasari'
    ]) {
      expect(source, contains(name));
    }
  });
}
