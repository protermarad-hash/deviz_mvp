import 'dart:io';

import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'pdf_export_settings.dart';
import 'repositories/app_data_repository.dart';

class PdfSaveCanceledException implements Exception {
  const PdfSaveCanceledException();

  @override
  String toString() => 'PdfSaveCanceledException';
}

class PdfSaveService {
  const PdfSaveService._();

  static const MethodChannel _androidDownloadsChannel = MethodChannel(
    'devizpro/pdf_exports',
  );

  static Future<String> savePdf({
    required AppDataRepository repository,
    required Uint8List bytes,
    required String fileName,
    required PdfDocumentCategory category,
    String outputDirectory = '',
    bool forceSaveAs = false,
  }) async {
    final customOutput = outputDirectory.trim();
    if (customOutput.isNotEmpty) {
      return _writeToDirectory(bytes, fileName, customOutput);
    }

    if (forceSaveAs) {
      final saveAsPath = await _trySaveAs(fileName);
      if (saveAsPath != null && saveAsPath.trim().isNotEmpty) {
        return _writeToPath(bytes, saveAsPath);
      }
      throw const PdfSaveCanceledException();
    }

    final profile = await repository.loadCompanyProfile();
    final settings = profile.pdfExportSettings;

    if (settings.askEveryTime) {
      final saveAsPath = await _trySaveAs(fileName);
      if (saveAsPath != null && saveAsPath.trim().isNotEmpty) {
        return _writeToPath(bytes, saveAsPath);
      }

      final pickedFolder = await _tryPickDirectory();
      if (pickedFolder != null && pickedFolder.trim().isNotEmpty) {
        return _writeToDirectory(bytes, fileName, pickedFolder);
      }
    }

    final configuredFolder = settings.folderForCategory(category).trim().isEmpty
        ? settings.defaultPdfFolder.trim()
        : settings.folderForCategory(category).trim();
    if (configuredFolder.isNotEmpty) {
      return _writeToDirectory(bytes, fileName, configuredFolder);
    }

    final fallbackDirectory = await _resolveFallbackDirectory(category);
    return _writeToDirectory(bytes, fileName, fallbackDirectory.path);
  }

  static Future<String?> _trySaveAs(String fileName) async {
    try {
      return await FilePicker.saveFile(
        dialogTitle: 'Salveaza PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _tryPickDirectory() async {
    try {
      return await FilePicker.getDirectoryPath(
        dialogTitle: 'Alege folder pentru PDF',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> _writeToDirectory(
    Uint8List bytes,
    String fileName,
    String directoryPath,
  ) async {
    if (Platform.isAndroid && _isPublicDownloadsPath(directoryPath)) {
      final savedPath = await _writeToAndroidDownloads(
        bytes: bytes,
        fileName: fileName,
        directoryPath: directoryPath,
      );
      if (savedPath.trim().isNotEmpty) {
        return savedPath;
      }
    }
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final filePath = '${directory.path}${Platform.pathSeparator}$fileName';
    return _writeToPath(bytes, filePath);
  }

  static Future<String> _writeToPath(Uint8List bytes, String filePath) async {
    var normalizedPath = filePath.trim();
    if (!normalizedPath.toLowerCase().endsWith('.pdf')) {
      normalizedPath = '$normalizedPath.pdf';
    }
    final file = File(normalizedPath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<Directory> _resolveFallbackDirectory(
    PdfDocumentCategory category,
  ) async {
    if (Platform.isAndroid) {
      return Directory(_androidDownloadsPath(category));
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.trim().isNotEmpty) {
        final windowsPath =
            '$userProfile\\Downloads\\DevizPro\\${_windowsFolderSuffix(category)}';
        final directory = Directory(windowsPath);
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        return directory;
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${docs.path}${Platform.pathSeparator}${_documentsFolderSuffix(category)}',
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static bool _isPublicDownloadsPath(String directoryPath) {
    final normalized = directoryPath.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/download') ||
        normalized.endsWith('/downloads');
  }

  static String _androidDownloadsPath(PdfDocumentCategory category) {
    return '/storage/emulated/0/Download/DevizPro/${_androidFolderSuffix(category)}';
  }

  static String _androidFolderSuffix(PdfDocumentCategory category) {
    switch (category) {
      case PdfDocumentCategory.offers:
        return 'Oferte';
      case PdfDocumentCategory.jobs:
        return 'Lucrari';
      case PdfDocumentCategory.hrPayslips:
        return 'HR/Payslips';
      case PdfDocumentCategory.hrStatements:
        return 'HR/Payroll';
      case PdfDocumentCategory.hrAccountingReports:
        return 'HR/Payroll';
      case PdfDocumentCategory.leaveRequests:
        return 'HR/CereriConcediu';
      case PdfDocumentCategory.attendanceReports:
        return 'HR/RapoartePontaj';
      case PdfDocumentCategory.travelOrders:
        return 'HR/OrdineDeplasare';
      case PdfDocumentCategory.other:
        return 'PDF';
    }
  }

  static Future<String> _writeToAndroidDownloads({
    required Uint8List bytes,
    required String fileName,
    required String directoryPath,
  }) async {
    final normalizedPath = directoryPath.replaceAll('\\', '/');
    final marker = '/download/';
    final lowerPath = normalizedPath.toLowerCase();
    final markerIndex = lowerPath.indexOf(marker);
    final relativeDirectory = markerIndex >= 0
        ? normalizedPath.substring(markerIndex + marker.length)
        : normalizedPath.split('/').last;
    try {
      final savedPath = await _androidDownloadsChannel.invokeMethod<String>(
        'savePdfToDownloads',
        <String, dynamic>{
          'bytes': bytes,
          'fileName': fileName,
          'relativeDirectory': relativeDirectory,
        },
      );
      return (savedPath ?? '').trim();
    } on PlatformException {
      return '';
    } on MissingPluginException {
      return '';
    }
  }

  static String _windowsFolderSuffix(PdfDocumentCategory category) {
    switch (category) {
      case PdfDocumentCategory.offers:
        return 'Oferte';
      case PdfDocumentCategory.jobs:
        return 'Lucrari';
      case PdfDocumentCategory.hrPayslips:
        return 'HR\\Payslips';
      case PdfDocumentCategory.hrStatements:
        return 'HR\\Payroll';
      case PdfDocumentCategory.hrAccountingReports:
        return 'HR\\Payroll';
      case PdfDocumentCategory.leaveRequests:
        return 'HR\\CereriConcediu';
      case PdfDocumentCategory.attendanceReports:
        return 'HR\\RapoartePontaj';
      case PdfDocumentCategory.travelOrders:
        return 'HR\\OrdineDeplasare';
      case PdfDocumentCategory.other:
        return 'PDF';
    }
  }

  static String _documentsFolderSuffix(PdfDocumentCategory category) {
    switch (category) {
      case PdfDocumentCategory.offers:
        return 'oferte_pdf';
      case PdfDocumentCategory.jobs:
        return 'jobs_pdf';
      case PdfDocumentCategory.hrPayslips:
        return 'hr_payslips_pdf';
      case PdfDocumentCategory.hrStatements:
        return 'hr_payroll_pdf';
      case PdfDocumentCategory.hrAccountingReports:
        return 'hr_payroll_pdf';
      case PdfDocumentCategory.leaveRequests:
        return 'hr_leave_pdf';
      case PdfDocumentCategory.attendanceReports:
        return 'hr_attendance_pdf';
      case PdfDocumentCategory.travelOrders:
        return 'travel_orders_pdf';
      case PdfDocumentCategory.other:
        return 'pdf_exports';
    }
  }
}
