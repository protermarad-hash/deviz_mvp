import '../../core/repositories/app_data_repository.dart';
import '../jobs/job_site_document_models.dart';
import 'registry_models.dart';

class RegistryService {
  const RegistryService(this.repository);

  final AppDataRepository repository;

  Future<RegistryEntry> registerOffer({
    required String offerId,
    required String documentNumber,
    required String title,
    String clientId = '',
    String recipientName = '',
    DateTime? documentDate,
    String filePath = '',
    String fileName = '',
    String notes = '',
  }) {
    return repository.registerGeneratedDocument(
      registryType: RegistryType.iesire,
      documentCategory: 'Oferta',
      documentTitle: title,
      documentNumber: documentNumber,
      documentDate: documentDate,
      clientId: clientId,
      offerId: offerId,
      recipientName: recipientName,
      filePath: filePath,
      fileName: fileName,
      notes: notes,
    );
  }

  Future<RegistryEntry> registerEstimate({
    required String estimateId,
    required String documentNumber,
    required String title,
    String clientId = '',
    String recipientName = '',
    DateTime? documentDate,
    String filePath = '',
    String fileName = '',
    String notes = '',
  }) {
    return repository.registerGeneratedDocument(
      registryType: RegistryType.iesire,
      documentCategory: 'Deviz',
      documentTitle: title,
      documentNumber: documentNumber,
      documentDate: documentDate,
      clientId: clientId,
      estimateId: estimateId,
      recipientName: recipientName,
      filePath: filePath,
      fileName: fileName,
      notes: notes,
    );
  }

  Future<RegistryEntry> registerContract({
    required String contractId,
    required String documentNumber,
    required String title,
    String clientId = '',
    String recipientName = '',
    DateTime? documentDate,
    String filePath = '',
    String fileName = '',
    String notes = '',
  }) {
    return repository.registerGeneratedDocument(
      registryType: RegistryType.iesire,
      documentCategory: 'Contract',
      documentTitle: title,
      documentNumber: documentNumber,
      documentDate: documentDate,
      clientId: clientId,
      contractId: contractId,
      recipientName: recipientName,
      filePath: filePath,
      fileName: fileName,
      notes: notes,
    );
  }

  Future<RegistryEntry> registerInvoice({
    required String documentNumber,
    required String title,
    String clientId = '',
    String recipientName = '',
    DateTime? documentDate,
    String filePath = '',
    String fileName = '',
    String notes = '',
  }) {
    return repository.registerGeneratedDocument(
      registryType: RegistryType.iesire,
      documentCategory: 'Factura',
      documentTitle: title,
      documentNumber: documentNumber,
      documentDate: documentDate,
      clientId: clientId,
      recipientName: recipientName,
      filePath: filePath,
      fileName: fileName,
      notes: notes,
    );
  }

  Future<RegistryEntry> registerTravelOrder({
    required String documentNumber,
    required String title,
    String jobId = '',
    String recipientName = '',
    DateTime? documentDate,
    String filePath = '',
    String fileName = '',
    String notes = '',
  }) {
    return repository.registerGeneratedDocument(
      registryType: RegistryType.iesire,
      documentCategory: 'Ordin deplasare',
      documentTitle: title,
      documentNumber: documentNumber,
      documentDate: documentDate,
      jobId: jobId,
      recipientName: recipientName,
      filePath: filePath,
      fileName: fileName,
      notes: notes,
    );
  }

  Future<RegistryEntry> registerComplaint({
    required String ticketId,
    required String documentNumber,
    required String title,
    String clientId = '',
    String issuerName = '',
    DateTime? documentDate,
    String filePath = '',
    String fileName = '',
    String notes = '',
  }) {
    return repository.registerGeneratedDocument(
      registryType: RegistryType.intrare,
      documentCategory: 'Reclamatie',
      documentTitle: title,
      documentNumber: documentNumber,
      documentDate: documentDate,
      clientId: clientId,
      ticketId: ticketId,
      issuerName: issuerName,
      filePath: filePath,
      fileName: fileName,
      notes: notes,
    );
  }

  Future<RegistryEntry> registerJobSiteDocument({
    required JobSiteDocumentRecord document,
    String recipientName = '',
    String issuerName = '',
    String filePath = '',
    String fileName = '',
    String notes = '',
  }) {
    return repository.registerGeneratedDocument(
      registryType: RegistryType.iesire,
      documentCategory: document.documentTypeForRegistry,
      documentTitle: document.documentTitle.trim().isEmpty
          ? (document.projectName.trim().isEmpty
              ? document.documentType.label
              : '${document.documentType.label} - ${document.projectName}')
          : document.documentTitle.trim(),
      documentNumber: document.documentNumber,
      documentDate: document.documentDate,
      jobId: document.jobId,
      recipientName: recipientName,
      issuerName: issuerName,
      filePath: filePath,
      fileName: fileName,
      notes: notes,
    );
  }
}
