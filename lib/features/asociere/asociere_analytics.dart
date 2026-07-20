import 'cost_asociere_models.dart';
import 'asociere_operational_common.dart';
import 'decont_lunar_asociere_models.dart';
import 'deplasare_asociere_models.dart';
import 'lucrare_asociere_models.dart';
import 'pontaj_asociere_models.dart';
import 'venit_asociere_models.dart';

enum AsociereAlertSeverity { info, warning, critical }

class AsociereAlert {
  const AsociereAlert({
    required this.code,
    required this.severity,
    required this.explanation,
    required this.action,
    required this.route,
  });
  final String code;
  final AsociereAlertSeverity severity;
  final String explanation;
  final String action;
  final String route;
}

class AsociereAnalytics {
  const AsociereAnalytics({
    required this.project,
    this.pontaje = const [],
    this.costuri = const [],
    this.venituri = const [],
    this.deplasari = const [],
    this.deconturi = const [],
    this.pendingOperations = 0,
    this.syncError,
  });

  final LucrareAsociereRecord project;
  final List<PontajAsociereRecord> pontaje;
  final List<CostAsociereRecord> costuri;
  final List<VenitAsociereRecord> venituri;
  final List<DeplasareAsociereRecord> deplasari;
  final List<DecontLunarAsociereRecord> deconturi;
  final int pendingOperations;
  final String? syncError;

  double get venitFacturat => venituri
      .where((item) => item.etapa != VenitAsociereEtapa.estimat)
      .fold(0, (sum, item) => sum + item.valoareFaraTva * item.curs);
  double get venitIncasat => venituri
      .where((item) => item.esteIncasat && item.eligibil)
      .fold(0, (sum, item) => sum + item.valoareProiect);
  double get costAprobat => costuri
      .where((item) => item.esteAprobat && item.eligibil)
      .fold(0, (sum, item) => sum + item.valoareProiect);
  double get costInAsteptare => costuri
      .where((item) => !item.esteAprobat)
      .fold(0, (sum, item) => sum + item.valoareProiect);
  double get rezultat => venitIncasat - costAprobat;
  double get ore => pontaje.fold(0, (sum, item) => sum + item.ore);
  double get kilometri =>
      deplasari.fold(0, (sum, item) => sum + item.kilometriReali);
  double get logistic => deplasari.fold(0, (sum, item) => sum + item.costReal);
  int get deconturiDeConfirmat =>
      deconturi.where((item) => item.status == DecontLunarStatus.draft).length;

  List<AsociereAlert> get alerts {
    final values = <AsociereAlert>[];
    void add(String code, AsociereAlertSeverity severity, String text,
        String action, String route) {
      values.add(AsociereAlert(
        code: code,
        severity: severity,
        explanation: text,
        action: action,
        route: route,
      ));
    }

    final missingDocs = costuri
        .where((item) => (item.documentRef ?? '').isEmpty && !item.esteAprobat)
        .length;
    if (missingDocs > 0) {
      add(
          'cost_document',
          AsociereAlertSeverity.warning,
          '$missingDocs costuri fără document.',
          'Deschide costurile',
          'costuri');
    }
    final unconfirmed =
        pontaje.where((item) => !item.esteConfirmatIntegral).length;
    if (unconfirmed > 0) {
      add(
          'pontaj_confirmare',
          AsociereAlertSeverity.warning,
          '$unconfirmed pontaje neconfirmate.',
          'Deschide pontajele',
          'pontaje');
    }
    final overdue = venituri
        .where((item) =>
            item.etapa == VenitAsociereEtapa.facturat &&
            item.scadenta != null &&
            item.scadenta!.isBefore(DateTime.now()))
        .length;
    if (overdue > 0) {
      add(
          'factura_restanta',
          AsociereAlertSeverity.critical,
          '$overdue venituri facturate sunt restante.',
          'Deschide veniturile',
          'venituri');
    }
    if (project.esteIntarziata) {
      add(
          'termen',
          AsociereAlertSeverity.critical,
          'Termenul proiectului este depășit.',
          'Verifică proiectul',
          'rezumat');
    }
    if ((project.cotaProTerm + project.cotaPartener - 100).abs() > 0.001) {
      add(
          'cote',
          AsociereAlertSeverity.critical,
          'Cotele contractuale nu însumează 100%.',
          'Corectează configurarea',
          'configurare');
    }
    if (pendingOperations > 0) {
      add(
          'offline_pending',
          AsociereAlertSeverity.warning,
          '$pendingOperations operații așteaptă sincronizarea.',
          'Reîncearcă sincronizarea',
          'activitate');
    }
    if ((syncError ?? '').isNotEmpty) {
      add('sync_error', AsociereAlertSeverity.critical,
          'Ultima sincronizare a eșuat.', 'Vezi detaliile', 'activitate');
    }
    return values;
  }

  Map<String, double> get costuriPeCategorie {
    final result = <String, double>{};
    for (final item in costuri.where((cost) => cost.esteAprobat)) {
      result.update(
          item.categorie.label, (value) => value + item.valoareProiect,
          ifAbsent: () => item.valoareProiect);
    }
    final settlements = [...deconturi]..sort((a, b) =>
        a.an == b.an ? a.luna.compareTo(b.luna) : a.an.compareTo(b.an));
    double cumulative = 0;
    for (final item in settlements) {
      cumulative += item.rezultat;
      result['${item.luna}/${item.an} rezultat cumulat'] = cumulative;
    }
    return result;
  }

  Map<String, double> get estimatVersusRealizat {
    final result = <String, double>{};
    for (final category in AsociereCostCategorie.values) {
      final draft = costuri
          .where((item) =>
              item.categorie == category &&
              item.status == AsociereOperationalStatus.draft)
          .fold<double>(0, (sum, item) => sum + item.valoareProiect);
      final approved = costuri
          .where((item) => item.categorie == category && item.esteAprobat)
          .fold<double>(0, (sum, item) => sum + item.valoareProiect);
      if (draft > 0) result['${category.label} estimat'] = draft;
      if (approved > 0) result['${category.label} realizat'] = approved;
    }
    return result;
  }

  Map<String, double> get evolutieLunara {
    final result = <String, double>{};
    for (final item in venituri) {
      final invoiceDate = item.dataFactura;
      if (invoiceDate != null) {
        final key = '${invoiceDate.month}/${invoiceDate.year} facturat';
        result.update(key, (value) => value + item.valoareFaraTva * item.curs,
            ifAbsent: () => item.valoareFaraTva * item.curs);
      }
      final paidDate = item.dataIncasarii;
      if (paidDate != null) {
        final key = '${paidDate.month}/${paidDate.year} încasat';
        result.update(key, (value) => value + item.valoareProiect,
            ifAbsent: () => item.valoareProiect);
      }
    }
    for (final item in costuri.where((cost) => cost.esteAprobat)) {
      final date = item.aprobatLa ?? item.data;
      final key = '${date.month}/${date.year} cost';
      result.update(key, (value) => value + item.valoareProiect,
          ifAbsent: () => item.valoareProiect);
    }
    return result;
  }

  Map<String, double> get orePeAsociat => {
        'PRO TERM': pontaje
            .where((item) => item.angajator.name == 'proTerm')
            .fold<double>(0, (sum, item) => sum + item.ore),
        'Partener': pontaje
            .where((item) => item.angajator.name == 'partener')
            .fold<double>(0, (sum, item) => sum + item.ore),
      };

  Map<String, double> get costuriPeAsociat {
    final result = <String, double>{};
    for (final item in costuri.where((cost) => cost.esteAprobat)) {
      result.update(item.platitor.label, (value) => value + item.valoareProiect,
          ifAbsent: () => item.valoareProiect);
    }
    return result;
  }
}
