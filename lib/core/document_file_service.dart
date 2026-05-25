import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum DocumentOpenStatus {
  opened,
  fileMissing,
  noAppFound,
  unsupported,
  failed,
}

class DocumentOpenResult {
  const DocumentOpenResult(
    this.status,
    this.message, {
    this.resolvedPath = '',
  });

  final DocumentOpenStatus status;
  final String message;
  final String resolvedPath;

  bool get opened => status == DocumentOpenStatus.opened;

  bool get shouldOfferShare =>
      status == DocumentOpenStatus.noAppFound ||
      status == DocumentOpenStatus.unsupported;
}

class DocumentFileService {
  const DocumentFileService._();

  static final Map<String, String> _resolvedPathCache = <String, String>{};

  static bool get isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get supportsFolderOpen =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static Future<DocumentOpenResult> openFile(
    String path, {
    String fallbackFileName = '',
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return const DocumentOpenResult(
        DocumentOpenStatus.fileMissing,
        'Fisierul nu a fost gasit.',
      );
    }

    final resolvedPath = await resolveExistingPath(
      normalizedPath,
      fallbackFileName: fallbackFileName,
    );
    if (resolvedPath == null) {
      return const DocumentOpenResult(
        DocumentOpenStatus.fileMissing,
        'Fisierul nu a fost gasit.',
      );
    }

    try {
      final result = await OpenFilex.open(resolvedPath);
      switch (result.type) {
        case ResultType.done:
          return DocumentOpenResult(
            DocumentOpenStatus.opened,
            'Document deschis.',
            resolvedPath: resolvedPath,
          );
        case ResultType.noAppToOpen:
          return DocumentOpenResult(
            DocumentOpenStatus.noAppFound,
            'Nu exista o aplicatie disponibila pentru deschidere.',
            resolvedPath: resolvedPath,
          );
        case ResultType.fileNotFound:
          return const DocumentOpenResult(
            DocumentOpenStatus.fileMissing,
            'Fisierul nu a fost gasit.',
          );
        case ResultType.permissionDenied:
          return DocumentOpenResult(
            DocumentOpenStatus.failed,
            'Permisiunea pentru deschiderea fisierului a fost refuzata.',
            resolvedPath: resolvedPath,
          );
        case ResultType.error:
          return DocumentOpenResult(
            DocumentOpenStatus.failed,
            result.message.trim().isEmpty
                ? 'Nu am putut deschide documentul.'
                : result.message,
            resolvedPath: resolvedPath,
          );
      }
    } catch (_) {
      return const DocumentOpenResult(
        DocumentOpenStatus.failed,
        'Nu am putut deschide documentul.',
      );
    }
  }

  static Future<void> shareFile(
    String path, {
    String subject = '',
    String text = '',
    String fallbackFileName = '',
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw const FileSystemException('Fisierul nu a fost gasit.');
    }
    final resolvedPath = await resolveExistingPath(
      normalizedPath,
      fallbackFileName: fallbackFileName,
    );
    if (resolvedPath == null) {
      throw FileSystemException('Fisierul nu a fost gasit.', normalizedPath);
    }
    await Share.shareXFiles(
      [XFile(resolvedPath)],
      subject: subject.trim().isEmpty ? null : subject.trim(),
      text: text.trim().isEmpty ? null : text.trim(),
    );
  }

  static Future<bool> openFolderForFile(
    String filePath, {
    String fallbackFileName = '',
  }) async {
    if (!supportsFolderOpen) {
      return false;
    }
    final resolvedPath = await resolveExistingPath(
      filePath,
      fallbackFileName: fallbackFileName,
    );
    if (resolvedPath == null) {
      return false;
    }
    final folderPath = File(resolvedPath).parent.path;
    final directory = Directory(folderPath);
    if (!directory.existsSync()) {
      return false;
    }
    if (Platform.isWindows) {
      await Process.run('explorer', [folderPath]);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [folderPath]);
      return true;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [folderPath]);
      return true;
    }
    return false;
  }

  static Future<String?> resolveExistingPath(
    String path, {
    String fallbackFileName = '',
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    final directFile = File(normalizedPath);
    if (directFile.existsSync()) {
      _resolvedPathCache[_cacheKey(normalizedPath)] = directFile.path;
      return directFile.path;
    }

    final cached = _resolvedPathCache[_cacheKey(normalizedPath)];
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }

    final targetFileName = _resolveFileName(
      normalizedPath,
      fallbackFileName: fallbackFileName,
    );
    if (targetFileName.isEmpty) {
      return null;
    }

    final rootDirectories = await _candidateSearchDirectories();
    for (final root in rootDirectories) {
      final found = await _findFileByName(
        root,
        targetFileName.toLowerCase(),
      );
      if (found != null) {
        _resolvedPathCache[_cacheKey(normalizedPath)] = found;
        return found;
      }
    }
    return null;
  }

  static String _cacheKey(String path) =>
      path.trim().replaceAll('\\', '/').toLowerCase();

  static String _resolveFileName(
    String path, {
    String fallbackFileName = '',
  }) {
    final explicitName = fallbackFileName.trim();
    if (explicitName.isNotEmpty) {
      return explicitName;
    }
    final normalized = path.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return '';
    }
    final segments = normalized.split('/');
    return segments.isEmpty ? normalized : segments.last.trim();
  }

  static Future<List<Directory>> _candidateSearchDirectories() async {
    final directories = <String>{};

    try {
      final appDocs = await getApplicationDocumentsDirectory();
      directories.add(appDocs.path);
      directories.add('${appDocs.path}${Platform.pathSeparator}PDF');
      directories.add('${appDocs.path}${Platform.pathSeparator}jobs_pdf');
    } catch (_) {}

    if (Platform.isWindows) {
      final userProfile = (Platform.environment['USERPROFILE'] ?? '').trim();
      if (userProfile.isNotEmpty) {
        directories.add('$userProfile\\Downloads\\DevizPro');
        directories.add('$userProfile\\Documents\\DevizPro');
        directories.add('$userProfile\\Downloads');
      }
    }

    if (Platform.isAndroid) {
      directories.add('/storage/emulated/0/Download/DevizPro');
      directories.add('/storage/emulated/0/Download');
      directories.add('/storage/emulated/0/Documents/DevizPro');
    }

    return directories
        .map((path) => Directory(path))
        .where((directory) => directory.existsSync())
        .toList(growable: false);
  }

  static Future<String?> _findFileByName(
    Directory root,
    String targetLowerCaseFileName,
  ) async {
    try {
      await for (final entity
          in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final name = entity.uri.pathSegments.isEmpty
            ? entity.path
            : entity.uri.pathSegments.last;
        if (name.toLowerCase() == targetLowerCaseFileName) {
          return entity.path;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
