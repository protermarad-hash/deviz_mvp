// FAZA A-E/1-13 — teste pentru eliminarea completa a firebase_storage din
// SupplierInvoiceRepository (crash nativ Windows confirmat — vezi raportul
// FAZA A-E). Persistarea XML-ului sursa s-a mutat server-side, in
// parseSupplierInvoiceXml (functions_invoice_import/).
//
// Mediul de test NU are Firebase initializat (ca si
// supplier_invoice_import_repair_test.dart) — SupplierInvoiceRepository
// foloseste FirebaseAuth/FirebaseFirestore.instance direct. Asta e
// EXACT ce ne permite sa demonstram structural ca `persistNewInvoice` nu
// mai atinge deloc firebase_storage: daca ar mai fi existat vreun apel
// Storage inainte de verificarea de autentificare, ar fi aparut o alta
// eroare (legata de Storage), nu strict cea de autentificare.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:devizpro_ultra/features/jobs/invoice_import/supplier_invoice_repository.dart';

void main() {
  group('SupplierInvoiceRepository — fara firebase_storage', () {
    // NOTA (ca si in supplier_invoice_import_repair_test.dart): mediul de
    // test nu are Firebase.initializeApp() apelat, iar constructorul
    // SupplierInvoiceRepository() acceseaza FirebaseFirestore.instance
    // direct in initializer (comportament PRE-EXISTENT, neschimbat de
    // aceasta faza) — deci simpla construire arunca deja "no Firebase
    // App". Important pentru aceasta regresie: eroarea e despre
    // `cloud_firestore`, NICIODATA despre `firebase_storage` — inainte de
    // aceasta faza, constructorul initializa SI `FirebaseStorage.instance`
    // (camp `_storage`, eliminat acum complet).
    test(
        'SupplierInvoiceRepository() fara Firebase initializat -> eroare '
        'despre cloud_firestore, NU despre firebase_storage (campul '
        '_storage a fost eliminat complet din constructor)', () {
      Object? caught;
      try {
        SupplierInvoiceRepository();
      } catch (error) {
        caught = error;
      }
      expect(caught, isNotNull);
      final message = caught.toString();
      expect(message.contains('firebase_storage'), false);
      expect(message.contains('Storage'), false);
    });

    test(
        'STRUCTURAL: supplier_invoice_repository.dart nu (mai) contine '
        'niciun import/apel firebase_storage sau putData — regresie '
        'directa impotriva reintroducerii accidentale a upload-ului client',
        () {
      final source = File(
        'lib/features/jobs/invoice_import/supplier_invoice_repository.dart',
      ).readAsStringSync();

      // Verificam liniile de COD (import/apeluri), nu prezenta cuvantului
      // in comentarii explicative (care mentioneaza "firebase_storage" ca
      // sa documenteze DE CE a fost eliminat).
      expect(source.contains("import 'package:firebase_storage"), false,
          reason: 'nu ar trebui sa mai existe niciun import firebase_storage');
      expect(source.contains('putData('), false,
          reason: 'nu ar trebui sa mai existe niciun apel putData (upload client)');
      expect(source.contains('FirebaseStorage'), false,
          reason: 'nu ar trebui sa mai existe nicio referinta la clasa FirebaseStorage');
    });
  });
}
