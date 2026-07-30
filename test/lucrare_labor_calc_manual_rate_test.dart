import 'package:devizpro_ultra/features/jobs/lucrare_detalii_models.dart';
import 'package:devizpro_ultra/features/jobs/services/lucrare_labor_calc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testează regula centrală din care depinde FIX 2 (iul 2026): câmpul
/// "Tarif orar (opțional)" din dialogurile _onAddLabor/_onEditLabor
/// (lucrare_detalii_page.dart) e citit înapoi prin exact această metodă —
/// `LucrareLaborCalculator.laborRateForRow` — care dă prioritate valorii
/// explicite din `row['hourlyRate']` și cade automat pe tariful din catalogul
/// angajatului/echipei doar când explicit e gol/0.
///
/// Dialogurile propriu-zise nu sunt testate direct (StatefulBuilder în
/// interiorul unei pagini cu multe dependințe Firebase/SharedPreferences),
/// dar logica pe care se bazează prioritatea "manual > automat" e chiar
/// aceasta — vezi și `_onAddLabor`/`_onEditLabor` unde
/// `rate = manualRate > 0 ? manualRate : autoRate`.
void main() {
  LucrareLaborCalculator buildCalc({
    List<LucrareOption> employees = const [],
    List<Map<String, dynamic>> teams = const [],
  }) {
    return LucrareLaborCalculator(
      jobId: 'job-1',
      employeesProvider: () => employees,
      teamsProvider: () => teams,
    );
  }

  group('LucrareLaborCalculator.laborRateForRow — prioritate tarif manual', () {
    test('tarif explicit >0 are prioritate față de catalogul angajatului',
        () {
      final calc = buildCalc(employees: const [
        LucrareOption(id: 'e1', label: 'Ion Popescu', hourlyRate: 40),
      ]);

      final rate = calc.laborRateForRow(const {
        'whoId': 'emp:e1',
        'type': 'person',
        'whoLabel': 'Ion Popescu',
        'hourlyRate': 75, // introdus manual de utilizator în dialog
      });

      expect(rate, 75);
    });

    test('tarif gol/0 cade pe calculul automat din catalogul angajatului',
        () {
      final calc = buildCalc(employees: const [
        LucrareOption(id: 'e1', label: 'Ion Popescu', hourlyRate: 40),
      ]);

      final rateWhenZero = calc.laborRateForRow(const {
        'whoId': 'emp:e1',
        'type': 'person',
        'whoLabel': 'Ion Popescu',
        'hourlyRate': 0,
      });
      final rateWhenMissing = calc.laborRateForRow(const {
        'whoId': 'emp:e1',
        'type': 'person',
        'whoLabel': 'Ion Popescu',
      });

      expect(rateWhenZero, 40);
      expect(rateWhenMissing, 40);
    });

    test('tarif explicit >0 are prioritate și pentru echipă', () {
      final calc = buildCalc(teams: const [
        {
          'id': 't1',
          'name': 'Echipa Nord',
          'hourlyRate': 55,
        },
      ]);

      final manualRate = calc.laborRateForRow(const {
        'whoId': 'team:t1',
        'type': 'team',
        'whoLabel': 'Echipă: Echipa Nord',
        'hourlyRate': 120,
      });
      final autoRate = calc.laborRateForRow(const {
        'whoId': 'team:t1',
        'type': 'team',
        'whoLabel': 'Echipă: Echipa Nord',
        'hourlyRate': 0,
      });

      expect(manualRate, 120);
      expect(autoRate, 55);
    });

    test(
        'simulare exactă a logicii din _onAddLabor/_onEditLabor: '
        'manualRate > 0 ? manualRate : autoRate', () {
      final calc = buildCalc(employees: const [
        LucrareOption(id: 'e1', label: 'Vasile Ionescu', hourlyRate: 30),
      ]);

      double resolvedRate({required double manualRateInput}) {
        final autoRate = calc.laborRateForWhoId(
          'emp:e1',
          type: 'person',
          whoLabel: 'Vasile Ionescu',
        );
        return manualRateInput > 0 ? manualRateInput : autoRate;
      }

      expect(resolvedRate(manualRateInput: 0), 30,
          reason: 'câmp gol/0 în dialog => fallback automat neschimbat');
      expect(resolvedRate(manualRateInput: 99), 99,
          reason: 'utilizatorul a completat un tarif manual => prioritate');
    });
  });
}
