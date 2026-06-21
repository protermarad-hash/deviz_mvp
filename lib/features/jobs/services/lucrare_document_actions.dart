import '../../../core/repositories/app_data_repository.dart';
import '../../registratura/registry_models.dart';
import '../../registratura/registry_store.dart';

/// Acțiuni pe documentele unei lucrări legate de registratură (alocare număr +
/// proiecție în registru).
///
/// Extras din `lucrare_detalii_page.dart` (Faza 2). Este partea non-UI a
/// acțiunilor pe documente: primește `repository` + datele lucrării ca
/// parametri și nu folosește `context`/`ScaffoldMessenger`. Orchestratorii de
/// export/share/email rămân în pagină (cuplați la UI).
class LucrareRegistryService {
  LucrareRegistryService({
    required this.repository,
    required this.jobId,
    required this.jobCode,
    required this.clientName,
    required this.documentTypeLabelFromType,
  });

  final AppDataRepository repository;
  final String jobId;
  final String jobCode;
  final String clientName;
  final String Function(String) documentTypeLabelFromType;

  /// Alocă un număr de registratură pentru document (dacă tipul e recunoscut),
  /// salvează proiecția în registru și întoarce rândul actualizat.
  Future<Map<String, dynamic>> registerDocumentForRegistry(
    Map<String, dynamic> rawRow,
  ) async {
    final row = Map<String, dynamic>.from(rawRow);
    final normalizedType = RegistryStore.normalizeDocumentType(
      row['type'] ?? row['tipDocument'],
    );
    if (normalizedType.isEmpty) {
      return row;
    }

    final existingNumber =
        '${row['numarDocument'] ?? row['number'] ?? ''}'.trim();
    final allocatedNumber = await RegistryStore.allocateNumber(
      type: normalizedType,
      existingNumber: existingNumber,
    );

    final updated = <String, dynamic>{
      ...row,
      'type': normalizedType,
      'tipDocument': documentTypeLabelFromType(normalizedType),
      'numarDocument': allocatedNumber,
      'number': allocatedNumber,
      'registryNumber': allocatedNumber,
      'registeredAt': DateTime.now().toIso8601String(),
    };

    await saveRegistryProjectionEntry(
      type: normalizedType,
      number: allocatedNumber,
      title: '${updated['titlu'] ?? updated['title'] ?? ''}'.trim(),
      documentDate:
          '${updated['dataDocument'] ?? updated['date'] ?? ''}'.trim(),
      status: '${updated['status'] ?? ''}'.trim(),
      referenceId: '${updated['id'] ?? ''}'.trim(),
      filePath: '${updated['pdfPath'] ?? updated['filePath'] ?? ''}'.trim(),
    );
    return updated;
  }

  /// Salvează (sau actualizează) intrarea de registru asociată documentului.
  Future<void> saveRegistryProjectionEntry({
    required String type,
    required String number,
    required String title,
    required String documentDate,
    required String status,
    required String referenceId,
    required String filePath,
  }) async {
    final normalizedType = RegistryStore.normalizeDocumentType(type);
    final registeredAt = DateTime.now();
    final parsedDocumentDate = DateTime.tryParse(documentDate);
    final jobReference =
        jobId.trim().isEmpty ? jobCode : jobId.trim();
    final stableId = referenceId.trim().isNotEmpty
        ? referenceId.trim()
        : 'job_${jobCode}_${normalizedType}_${number.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}';
    final entry = RegistryEntry(
      id: stableId,
      registryNumber: number,
      registryType: RegistryType.iesire,
      sequenceNumber: extractRegistrySequence(number),
      year: (parsedDocumentDate ?? registeredAt).year,
      registeredAt: registeredAt,
      documentNumber: number,
      documentDate: parsedDocumentDate,
      documentTitle: title,
      documentCategory: RegistryStore.documentTypeLabelUi(normalizedType),
      issuerName: '',
      recipientName: clientName,
      clientId: '',
      jobId: jobReference,
      offerId: '',
      estimateId: '',
      contractId: '',
      ticketId: '',
      filePath: filePath,
      fileName: '',
      notes: '',
      status: status,
    );
    await repository.saveRegistryEntry(entry);
  }

  /// Extrage ultimul grup de cifre dintr-un număr de document (secvența).
  int extractRegistrySequence(String number) {
    final match = RegExp(r'(\d+)(?!.*\d)').firstMatch(number);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
