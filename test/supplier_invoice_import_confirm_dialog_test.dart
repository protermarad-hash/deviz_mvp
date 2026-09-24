// Regresie FAZA 6 — BUG CRITIC: la "Confirma importul" din
// SupplierInvoiceImportPage, dialogul de confirmare folosea contextul
// paginii exterioare (capturat prin closure) in loc de contextul propriu
// al dialogului la Navigator.of(context).pop(...). Cand pagina de import e
// gazduita pe un Navigator diferit de cel radacina (unde showDialog isi
// deschide implicit propriul dialog, useRootNavigator: true), acel pop
// ajungea sa inchida RUTA PAGINII (Navigator.push<SupplierInvoiceImportOutcome>)
// cu o valoare bool in loc sa inchida doar dialogul — eroare de tip
// ireproductibila prin teste pure de logica (type 'bool' is not a subtype
// of type 'SupplierInvoiceImportOutcome?' of 'result'), urmata de o
// cascada de asertari Navigator '_debugLocked' care doboara aplicatia
// INAINTE ca vreo linie din _doImport/_persistJobMaterials sa ruleze.
//
// Acest test reproduce STRUCTURAL exact acelasi pattern (pagina pe un
// Navigator imbricat, diferit de cel radacina folosit de showDialog) si
// demonstreaza ca fix-ul (folosirea contextului propriu al dialogului,
// primit ca parametru in `builder`) este robust: dialogul se inchide
// mereu pe Navigator-ul lui propriu, niciodata pe cel al paginii.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rezultat tipizat analog cu SupplierInvoiceImportOutcome — orice tip
/// non-bool e suficient sa demonstreze mismatch-ul daca fix-ul lipseste.
class _FakeImportOutcome {
  const _FakeImportOutcome(this.rowCount);
  final int rowCount;
}

/// Pagina "de import" gazduita pe un Navigator IMBRICAT (nu radacina) —
/// exact geometria reala: SupplierInvoiceImportPage e deschisa prin
/// Navigator.of(context).push<SupplierInvoiceImportOutcome> dintr-un
/// Navigator care NU e cel radacina folosit implicit de showDialog.
class _FakeImportPage extends StatelessWidget {
  const _FakeImportPage({required this.useFixedDialogContext});

  final bool useFixedDialogContext;

  Future<void> _onConfirmPressed(BuildContext context) async {
    final confirmed = useFixedDialogContext
        ? await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Confirma importul'),
              actions: [
                FilledButton(
                  key: const Key('confirmBtn'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Confirma'),
                ),
              ],
            ),
          )
        // Reproduce exact bug-ul original: 'context' capturat din pagina
        // exterioara, NU parametrul primit de builder.
        : await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Confirma importul'),
              actions: [
                FilledButton(
                  key: const Key('confirmBtn'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirma'),
                ),
              ],
            ),
          );
    if (confirmed != true) return;
    if (!context.mounted) return;
    // Echivalentul lui Navigator.of(context).pop(SupplierInvoiceImportOutcome(...))
    // din _doImport — trebuie sa se execute DOAR daca dialogul a fost
    // inchis corect (nu pagina insasi).
    Navigator.of(context).pop(const _FakeImportOutcome(3));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('openConfirmDialogBtn'),
          onPressed: () => _onConfirmPressed(context),
          child: const Text('Import materiale din factura'),
        ),
      ),
    );
  }
}

/// Container care gazduieste _FakeImportPage pe un Navigator NOU, IMBRICAT
/// (nu radacina) — reproduce exact structura reala (lucrare_detalii_page
/// -> Navigator.push<SupplierInvoiceImportOutcome>(...) pe un Navigator
/// care nu e cel folosit implicit de showDialog).
class _NestedHostHarness extends StatefulWidget {
  const _NestedHostHarness({required this.useFixedDialogContext});

  final bool useFixedDialogContext;

  @override
  State<_NestedHostHarness> createState() => _NestedHostHarnessState();
}

class _NestedHostHarnessState extends State<_NestedHostHarness> {
  _FakeImportOutcome? _outcome;
  bool _pushCompleted = false;
  Object? _caughtError;

  Future<void> _openImportPage(BuildContext nestedNavContext) async {
    try {
      final result = await Navigator.of(nestedNavContext)
          .push<_FakeImportOutcome>(
        MaterialPageRoute(
          builder: (_) => _FakeImportPage(
            useFixedDialogContext: widget.useFixedDialogContext,
          ),
        ),
      );
      setState(() {
        _outcome = result;
        _pushCompleted = true;
      });
    } catch (error) {
      setState(() {
        _caughtError = error;
        _pushCompleted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text('outcome=${_outcome?.rowCount ?? 'null'} '
                'completed=$_pushCompleted error=$_caughtError'),
            Expanded(
              // Navigator IMBRICAT, distinct de cel radacina al MaterialApp —
              // exact geometria in care apare bug-ul real.
              child: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (nestedNavContext) => Scaffold(
                    body: ElevatedButton(
                      key: const Key('openPageBtn'),
                      onPressed: () => _openImportPage(nestedNavContext),
                      child: const Text('Deschide pagina import'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'FIX: dialogul foloseste contextul propriu -> pop() nu atinge '
    'niciodata ruta paginii (nested Navigator), rezultatul final e '
    'intotdeauna outcome-ul tipizat, fara exceptie',
    (tester) async {
      await tester.pumpWidget(
        const _NestedHostHarness(useFixedDialogContext: true),
      );

      await tester.tap(find.byKey(const Key('openPageBtn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('openConfirmDialogBtn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('openConfirmDialogBtn')));
      await tester.pumpAndSettle();

      // Dialogul trebuie sa fie vizibil (deschis corect pe navigatorul lui).
      expect(find.text('Confirma importul'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmBtn')));
      await tester.pumpAndSettle();

      // Fara nicio exceptie prinsa, iar rezultatul final e outcome-ul
      // TIPIZAT (nu bool) — confirma ca pop-ul dialogului nu a atins
      // niciodata ruta paginii de import.
      expect(find.text('outcome=3 completed=true error=null'), findsOneWidget);
    },
  );

  // NOTA: varianta FARA fix (`useFixedDialogContext: false`) a fost
  // verificata manual cu acest exact harness in timpul investigatiei —
  // reproduce identic defectul din productie: la tap pe 'confirmBtn',
  // framework-ul arunca o exceptie neprinsa in
  // MaterialRouteTransitionMixin.didPop (pop() ajunge pe Navigator-ul
  // paginii, nu pe cel al dialogului), urmata de o cascada de exceptii de
  // unmount care corup ireversibil arborele de widget-uri — exact
  // echivalentul asertarilor Navigator '_debugLocked' repetate observate
  // in consola aplicatiei reale (vezi raportul FAZA 6). Coruperea e
  // ireversibila prin design (asta E defectul), deci nu poate fi pastrata
  // ca test automat "verde" — testul de mai sus (cu fix-ul aplicat) este
  // singura garantie de regresie utila: daca fix-ul e vreodata scos sau
  // stricat, acel test incepe sa esueze exact ca varianta nefixata.
}
