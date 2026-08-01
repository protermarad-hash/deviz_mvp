import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/jobs/job_models.dart';

void main() {
  group('JobLine — preț ofertat vs preț achiziție real', () {
    test('fromOfertaLine: pretUnitarReal pornește egal cu pretUnitarOferta',
        () {
      final linie = JobLine.fromOfertaLine(
        id: 'l1',
        ofertaLineId: 'o1',
        denumire: 'Filtru CTA',
        um: 'ML',
        cantitate: 10,
        pretUnitar: 50,
        categorie: 'material',
      );
      expect(linie.pretUnitarReal, linie.pretUnitarOferta);
      expect(linie.totalReal, linie.totalOferta);
      expect(linie.diferenta, 0);
    });

    test('fără preț real completat, totalReal cade pe prețul ofertat', () {
      final linie = JobLine.fromOfertaLine(
        id: 'l2',
        ofertaLineId: 'o2',
        denumire: 'Țeavă cupru',
        um: 'ML',
        cantitate: 20,
        pretUnitar: 30,
        categorie: 'material',
      ).copyWith(cantitateReala: 15);

      expect(linie.pretUnitarReal, 30);
      expect(linie.totalReal, 15 * 30);
      expect(linie.diferenta, (15 * 30) - (20 * 30));
    });

    test('preț real completat, mai mare decât ofertat → depășire (+)', () {
      final linie = JobLine.fromOfertaLine(
        id: 'l3',
        ofertaLineId: 'o3',
        denumire: 'Racord',
        um: 'buc',
        cantitate: 10,
        pretUnitar: 20,
        categorie: 'material',
      ).copyWith(cantitateReala: 10, pretUnitarReal: 25);

      expect(linie.totalOferta, 200);
      expect(linie.totalReal, 250);
      expect(linie.diferenta, 50);
      expect(linie.diferenta > 0, isTrue); // depășire
    });

    test('preț real completat, mai mic decât ofertat → economie (-)', () {
      final linie = JobLine.fromOfertaLine(
        id: 'l4',
        ofertaLineId: 'o4',
        denumire: 'Izolație',
        um: 'ML',
        cantitate: 10,
        pretUnitar: 20,
        categorie: 'material',
      ).copyWith(cantitateReala: 10, pretUnitarReal: 15);

      expect(linie.totalOferta, 200);
      expect(linie.totalReal, 150);
      expect(linie.diferenta, -50);
      expect(linie.diferenta < 0, isTrue); // economie
    });

    test('copyWith fără pretUnitarReal păstrează valoarea existentă', () {
      final linie = JobLine.fromOfertaLine(
        id: 'l5',
        ofertaLineId: 'o5',
        denumire: 'Robinet',
        um: 'buc',
        cantitate: 5,
        pretUnitar: 40,
        categorie: 'material',
      ).copyWith(pretUnitarReal: 45);

      final updated = linie.copyWith(cantitateReala: 5);
      expect(updated.pretUnitarReal, 45); // backward-compat: nu se resetează
      expect(updated.totalReal, 5 * 45);
    });
  });
}
