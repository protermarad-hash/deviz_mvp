import 'asociere_models.dart';
import 'lucrare_asociere_models.dart';

extension LucrareAsociereCloudProjection on LucrareAsociereRecord {
  Map<String, dynamic> toCloudMap() {
    final map = toMap()
      ..remove('valoare_contractuala')
      ..remove('cota_pro_term')
      ..remove('cota_partener')
      ..remove('cine_factureaza_beneficiarul')
      ..remove('procent_distribuire_intermediara')
      ..remove('procent_rezerva_garantie')
      ..remove('durata_garantie_luni')
      ..remove('prag_aprobare_cost');
    map['assigned_employee_ids'] = <String>{
      managerId.trim(),
      responsabilId.trim(),
    }.where((value) => value.isNotEmpty).toList(growable: false);
    return map;
  }

  LucrareAsociereRecord withContract(AsociereRecord contract) =>
      LucrareAsociereRecord.fromMap(toMap()
        ..addAll(<String, dynamic>{
          'valoare_contractuala': contract.valoareContractuala,
          'moneda': contract.moneda,
          'cota_pro_term': contract.cotaProTerm,
          'cota_partener': contract.cotaPartener,
          'cine_factureaza_beneficiarul':
              contract.cineFactureazaBeneficiarul.value,
          'procent_distribuire_intermediara':
              contract.procentDistribuireIntermediara,
          'procent_rezerva_garantie': contract.procentRezervaGarantie,
          'durata_garantie_luni': contract.durataGarantieLuni,
          'prag_aprobare_cost': contract.pragAprobareRON,
        }));

  LucrareAsociereRecord withoutFinancialData() =>
      LucrareAsociereRecord.fromMap(toCloudMap());
}
