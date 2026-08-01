// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/pontaj_lucrari/pontaj_economic_section.dart';
import '../lib/features/pontaj_lucrari/pontaj_zi_lucrare_models.dart';

PontajZiLucrare pontaj({
  String id = 'p1',
  String nume = 'Ion Pop',
  SursaPersoanaPontaj sursa = SursaPersoanaPontaj.propriu,
  DateTime? data,
  double tarif = 300,
  double diurna = 0,
  double cazare = 0,
  bool includeDiurna = false,
  bool includeCazare = false,
}) {
  final now = DateTime(2026, 7, 30);
  return PontajZiLucrare(
    id: id,
    lucrareId: 'lucrare-1',
    data: data ?? DateTime(2026, 7, 15),
    persoanaNume: nume,
    sursaPersoana: sursa,
    tarifZilnicSnapshot: tarif,
    diurnaSnapshot: diurna,
    cazareSnapshot: cazare,
    includeDiurna: includeDiurna,
    includeCazare: includeCazare,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('PontajEconomicAgregat.dinPontaje', () {
    test('lista goală → agregat zero, fără pontaje', () {
      final agregat = PontajEconomicAgregat.dinPontaje(const []);
      expect(agregat.arePontaje, isFalse);
      expect(agregat.totalGeneral, 0);
      expect(agregat.perPersoana, isEmpty);
    });

    test('separă totalurile pe sursă: propriu / partener / liber', () {
      final agregat = PontajEconomicAgregat.dinPontaje([
        pontaj(id: 'a', nume: 'Ion', sursa: SursaPersoanaPontaj.propriu, tarif: 300),
        pontaj(id: 'b', nume: 'Vasile', sursa: SursaPersoanaPontaj.partener, tarif: 250),
        pontaj(id: 'c', nume: 'Gheorghe', sursa: SursaPersoanaPontaj.liber, tarif: 200),
        pontaj(
          id: 'd',
          nume: 'Ion',
          sursa: SursaPersoanaPontaj.propriu,
          data: DateTime(2026, 7, 16),
          tarif: 300,
          diurna: 50,
          includeDiurna: true,
        ),
      ]);

      expect(agregat.totalPropriu, 650); // 300 + (300+50)
      expect(agregat.totalPartener, 250);
      expect(agregat.totalLiber, 200);
      expect(agregat.totalGeneral, 1100);
      expect(agregat.numarPontaje, 4);
      expect(agregat.arePontaje, isTrue);
    });

    test('costZi include diurna și cazarea doar dacă sunt bifate', () {
      final agregat = PontajEconomicAgregat.dinPontaje([
        pontaj(
          id: 'a',
          tarif: 300,
          diurna: 50,
          cazare: 120,
          includeDiurna: true,
          includeCazare: true,
        ),
        pontaj(
          id: 'b',
          data: DateTime(2026, 7, 16),
          tarif: 300,
          diurna: 50,
          cazare: 120,
          includeDiurna: false,
          includeCazare: false,
        ),
      ]);
      expect(agregat.totalPropriu, 470 + 300);
    });

    test('defalcare per persoană: zile unice, total, sortare desc după total',
        () {
      final agregat = PontajEconomicAgregat.dinPontaje([
        pontaj(id: 'a', nume: 'Ion', tarif: 300, data: DateTime(2026, 7, 15)),
        pontaj(id: 'b', nume: 'Ion', tarif: 300, data: DateTime(2026, 7, 16)),
        pontaj(id: 'c', nume: 'Ana', tarif: 400, data: DateTime(2026, 7, 15)),
      ]);

      expect(agregat.perPersoana.length, 2);
      final primul = agregat.perPersoana.first;
      expect(primul.nume, 'Ion'); // 600 > 400
      expect(primul.zile, 2);
      expect(primul.total, 600);
      expect(agregat.perPersoana.last.nume, 'Ana');
      expect(agregat.perPersoana.last.zile, 1);
    });

    test('aceeași persoană cu majuscule diferite se grupează o singură dată',
        () {
      final agregat = PontajEconomicAgregat.dinPontaje([
        pontaj(id: 'a', nume: 'Ion Pop', data: DateTime(2026, 7, 15)),
        pontaj(id: 'b', nume: 'ION POP', data: DateTime(2026, 7, 16)),
      ]);
      expect(agregat.perPersoana.length, 1);
      expect(agregat.perPersoana.first.zile, 2);
    });

    test('aceeași persoană cu surse diferite = intrări separate', () {
      final agregat = PontajEconomicAgregat.dinPontaje([
        pontaj(id: 'a', nume: 'Ion', sursa: SursaPersoanaPontaj.propriu),
        pontaj(
          id: 'b',
          nume: 'Ion',
          sursa: SursaPersoanaPontaj.liber,
          data: DateTime(2026, 7, 16),
        ),
      ]);
      expect(agregat.perPersoana.length, 2);
    });
  });

  group('necesitaAvertismentDublaSursa', () {
    test('pontaje + manoperă veche → avertisment', () {
      expect(
        necesitaAvertismentDublaSursa(
          arePontaje: true,
          areManoperaVeche: true,
        ),
        isTrue,
      );
    });

    test('doar pontaje, fără manoperă veche → fără avertisment', () {
      expect(
        necesitaAvertismentDublaSursa(
          arePontaje: true,
          areManoperaVeche: false,
        ),
        isFalse,
      );
    });

    test('doar manoperă veche, fără pontaje → fără avertisment', () {
      expect(
        necesitaAvertismentDublaSursa(
          arePontaje: false,
          areManoperaVeche: true,
        ),
        isFalse,
      );
    });

    test('fără nimic → fără avertisment', () {
      expect(
        necesitaAvertismentDublaSursa(
          arePontaje: false,
          areManoperaVeche: false,
        ),
        isFalse,
      );
    });
  });
}
