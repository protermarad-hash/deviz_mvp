import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'asociere_logistica_repository.dart';
import 'asociere_operational_common.dart';
import 'cost_asociere_repository.dart';
import 'decont_lunar_asociere_repository.dart';
import 'pontaj_asociere_repository.dart';
import 'pontaj_asociere_models.dart';
import 'decont_lunar_asociere_models.dart';
import 'venit_asociere_repository.dart';

class AsociereCsvExportService {
  const AsociereCsvExportService._();

  static Future<String> exportRegistru(String projectId) async {
    final costs =
        await CostAsociereRepository.instance.listByProject(projectId);
    final income =
        await VenitAsociereRepository.instance.listByProject(projectId);
    final rows = <List<Object?>>[
      [
        'tip',
        'data',
        'categorie',
        'descriere',
        'valoare_proiect',
        'moneda',
        'platitor_emitent',
        'status',
        'document'
      ],
      ...costs.map((item) => [
            'cost',
            item.data.toIso8601String(),
            item.categorie.value,
            item.descriere,
            item.valoareProiect,
            item.moneda,
            item.platitor.value,
            item.status.value,
            (item.documentRef ?? '').isEmpty ? 'nu' : 'da'
          ]),
      ...income.map((item) => [
            'venit',
            item.dataFactura?.toIso8601String() ?? '',
            item.etapa.name,
            item.numarFactura,
            item.valoareFaraTva * item.curs,
            item.moneda,
            item.emitent.value,
            item.status.value,
            (item.documentRef ?? '').isEmpty ? 'nu' : 'da'
          ]),
    ];
    return _writeAndShare('registru_asociere_$projectId.csv', rows);
  }

  static Future<String> exportPontaje(String projectId) async {
    final values =
        await PontajAsociereRepository.instance.listByProject(projectId);
    return _writeAndShare('pontaje_asociere_$projectId.csv', [
      [
        'data',
        'persoana',
        'angajator',
        'calificare',
        'ore',
        'activitate',
        'tarif_snapshot',
        'cost',
        'confirmare_interna',
        'confirmare_externa'
      ],
      ...values.map((item) => [
            item.data.toIso8601String(),
            item.persoanaNameSnapshot,
            item.angajator.value,
            item.calificare,
            item.ore,
            item.activitate,
            item.tarifSnapshot,
            item.costCalculat,
            item.confirmareInterna,
            item.confirmareExternaInregistrata
          ]),
    ]);
  }

  static Future<String> exportDeplasari(String projectId) async {
    final values =
        await DeplasareAsociereRepository.instance.listByProject(projectId);
    return _writeAndShare('deplasari_asociere_$projectId.csv', [
      [
        'plecare',
        'revenire',
        'punct_plecare',
        'destinatie',
        'metoda',
        'km_estimati',
        'km_reali',
        'tarif_km_snapshot',
        'cost_estimat',
        'cost_real',
        'platitor',
        'document'
      ],
      ...values.map((item) => [
            item.dataPlecare.toIso8601String(),
            item.dataRevenire.toIso8601String(),
            item.punctPlecare,
            item.destinatie,
            item.metodaCalcul.name,
            item.kilometriEstimati,
            item.kilometriReali,
            item.tarifKmSnapshot,
            item.costEstimat,
            item.calculeazaTransport(),
            item.platitor.value,
            item.documentRef.isEmpty ? 'nu' : 'da'
          ]),
    ]);
  }

  static Future<String> exportDecont(String projectId) async {
    final values =
        await DecontLunarAsociereRepository.instance.listByProject(projectId);
    return _writeAndShare('deconturi_asociere_$projectId.csv', [
      [
        'an',
        'luna',
        'venit_eligibil',
        'cost_pro_term',
        'cost_partener',
        'rezultat',
        'rambursare_costuri',
        'distribuire',
        'rezerva',
        'obligatie_neta',
        'status',
        'formula_revision',
        'intrari'
      ],
      ...values.map((item) => [
            item.an,
            item.luna,
            item.veniturIncasatTotal,
            item.costRecunoscutProTerm,
            item.costRecunoscutPartener,
            item.rezultat,
            item.rambursareCosturi,
            item.distribuireProfitImediata,
            item.sumaRezervaRetinuta,
            item.sumaDeAchitatAcum,
            item.status.value,
            item.formulaRevision,
            item.inputIds.length
          ]),
    ]);
  }

  static Future<String> _writeAndShare(
      String fileName, List<List<Object?>> rows) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    final content = rows.map((row) => row.map(_cell).join(',')).join('\r\n');
    await file.writeAsString('\ufeff$content');
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
        subject: fileName);
    return file.path;
  }

  static String _cell(Object? raw) {
    final value = '${raw ?? ''}'.replaceAll('"', '""');
    return '"$value"';
  }
}
