// FAZA 2 pct. 8 — matching DETERMINIST (nu fuzzy, nu AI) intre o linie de
// factura confirmata si nomenclatorul general de materiale
// (MasterMaterial). Doar potriviri EXACTE (denumire normalizata + UM)
// reutilizeaza un material existent; altfel se aloca un id nou, dar
// materialul NU e scris in catalog aici — scrierea are loc DOAR dupa ce
// salvarea materialelor lucrarii a reusit (vezi FAZA 2 pct. 8.3, wiring
// in lucrare_detalii_page.dart).
//
// Ce s-a verificat inainte de a scrie acest fisier (cerinta explicita:
// "nu presupune"):
//   - MasterMaterial (lib/features/master/master_local_store.dart) are
//     doar {id, name, unit, price, notes, quantityInStock,
//     minQuantityAlert, stockCategory} — NICIUN camp pentru cod furnizor.
//     Deci potrivirea pe SellersItemIdentification (pct. 8 bullet 2) NU
//     este implementabila fara sa extindem catalogul — interzis explicit
//     ("NU extinde catalogul in aceasta faza doar pentru acel camp").
//   - Nu exista nicaieri o legatura materialId <-> linie de factura
//     persistata anterior — bullet 1 ("cauta dupa identificator intern")
//     nu are ce sa gaseasca inca in V1; devine relevant abia dupa ce
//     liniile importate au deja `materialId` (self-consistent la
//     reimporturi ulterioare ale ACELUIASI produs, prin bullet 3).
//   - MaterialsCatalogService.upsertFromOfferMaterial() EXISTA deja si
//     face un match similar, DAR suprascrie automat pretul catalogului la
//     match (shouldUpdate = price>0 && existing.price != price) — exact
//     comportamentul interzis de pct. 8.1 ("NU suprascrie automat pretul
//     unui material existent cu pretul facturii curente"). De aceea NU
//     este reutilizata direct; in loc, acest fisier face doar potrivirea
//     (citire), iar scrierea (doar pentru materiale NOI) foloseste
//     MaterialsCatalogService.upsertMaterial() direct, fara sa atinga
//     pretul unui material existent.

import '../../master/master_local_store.dart';

/// Aceeasi normalizare ca `MaterialsCatalogService._normalize` (privata
/// acolo) — duplicata aici ca utilitar de o linie, ca sa nu modificam
/// acel fisier doar pentru vizibilitate.
String normalizeForCatalogMatch(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class SupplierInvoiceCatalogResolution {
  const SupplierInvoiceCatalogResolution({
    required this.materialId,
    required this.toCreate,
  });

  final String materialId;

  /// Non-null DOAR daca materialul e NOU (nicio potrivire exacta gasita)
  /// si trebuie creat in catalog dupa ce salvarea materialelor lucrarii
  /// reuseste. Null daca s-a reutilizat un material existent (catalogul
  /// NU este atins).
  final MasterMaterial? toCreate;
}

/// Rezolva materialId pentru o linie confirmata, printr-un batch de
/// potriviri deterministe pe un snapshot de catalog deja incarcat (un
/// singur `listMaterials()` pentru tot lotul, nu cate un read per linie).
///
/// Potriviri intra-lot: daca doua linii NOI din ACEEASI factura au
/// denumire+UM identice normalizat, a doua reutilizeaza id-ul alocat
/// primei (nu se creeaza doua materiale noi pentru acelasi produs).
class SupplierInvoiceCatalogMatcher {
  SupplierInvoiceCatalogMatcher(List<MasterMaterial> initialCatalog)
      : _index = {
          for (final m in initialCatalog) _key(m.name, m.unit): m.id,
        };

  final Map<String, String> _index;
  int _seed = 0;

  static String _key(String name, String unit) =>
      '${normalizeForCatalogMatch(name)}|${normalizeForCatalogMatch(unit)}';

  /// [name]/[unit] trebuie sa fie deja valorile FINALE (displayName,
  /// friendlyUnit) care vor ajunge pe materialul din lucrare.
  SupplierInvoiceCatalogResolution resolve({
    required String name,
    required String unit,
    required double price,
  }) {
    final key = _key(name, unit);
    final existingId = _index[key];
    if (existingId != null) {
      return SupplierInvoiceCatalogResolution(
        materialId: existingId,
        toCreate: null,
      );
    }

    _seed += 1;
    final newId = 'mat-inv-${DateTime.now().millisecondsSinceEpoch}-$_seed';
    final newMaterial = MasterMaterial(
      id: newId,
      name: name.trim(),
      unit: unit.trim(),
      price: price,
      notes: '',
    );
    // Inregistrat imediat in indexul local, ca urmatoarele linii din
    // acelasi lot sa gaseasca potrivirea (evita duplicate intra-lot).
    _index[key] = newId;
    return SupplierInvoiceCatalogResolution(
      materialId: newId,
      toCreate: newMaterial,
    );
  }
}
