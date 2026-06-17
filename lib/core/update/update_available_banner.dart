import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_version_checker.dart';

/// Banner non-blocant afișat sub AppBar când există o versiune nouă a
/// aplicației publicată în Firestore (`app_config/version_info`).
///
/// Angajatul poate ignora notificarea ("X") și continuă cu versiunea
/// instalată — `forceUpdate` NU e implementat încă (vezi AppVersionInfo).
///
/// Suportă Android (instalare directă APK) și Windows (descărcare installer
/// .exe + instrucțiuni pentru utilizator să lanseze manual după ce
/// închide aplicația curentă).
class UpdateAvailableBanner extends StatefulWidget {
  const UpdateAvailableBanner({super.key});

  @override
  State<UpdateAvailableBanner> createState() => _UpdateAvailableBannerState();
}

class _UpdateAvailableBannerState extends State<UpdateAvailableBanner> {
  AppUpdateCheckResult? _result;
  bool _dismissed = false;
  bool _downloading = false;
  double _downloadProgress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_check);
  }

  Future<void> _check() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isWindows) return;
    final result = await AppVersionChecker.instance.checkForUpdate();
    if (!mounted || result == null || !result.needsUpdate) return;
    setState(() => _result = result);
  }

  // ─── Android ───────────────────────────────────────────────────────────────

  Future<bool> _ensureInstallPermission() async {
    try {
      final status = await Permission.requestInstallPackages.status;
      if (status.isGranted) return true;
      final result = await Permission.requestInstallPackages.request();
      return result.isGranted;
    } catch (e) {
      // best-effort — pe unele device-uri verificarea poate eșua;
      // încercăm instalarea oricum, OS-ul va cere permisiunea la nevoie.
      debugPrint('[UpdateBanner] verificare permisiune instalare eșuată: $e');
      return true;
    }
  }

  Future<void> _downloadAndInstallAndroid() async {
    final info = _result?.info;
    if (info == null || info.apkUrl.isEmpty) return;

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _error = null;
    });

    try {
      await _ensureInstallPermission();

      final uri = Uri.parse(info.apkUrl);
      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        throw Exception('Descărcare eșuată (HTTP ${response.statusCode})');
      }

      final total = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}proterm_update_${info.latestBuildNumber}.apk',
      );
      final sink = file.openWrite();
      var received = 0;
      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _downloadProgress = received / total);
        }
      }).asFuture<void>();
      await sink.close();

      if (!mounted) return;
      setState(() => _downloading = false);

      final openResult = await OpenFilex.open(file.path);
      if (openResult.type != ResultType.done && mounted) {
        setState(() {
          _error = 'Nu am putut porni instalarea: ${openResult.message}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'Descărcare eșuată: $e';
      });
    }
  }

  // ─── Windows ───────────────────────────────────────────────────────────────

  Future<void> _downloadAndInstallWindows() async {
    final info = _result?.info;
    if (info == null || info.windowsExeUrl.isEmpty) return;

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _error = null;
    });

    try {
      final uri = Uri.parse(info.windowsExeUrl);
      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);
      if (response.statusCode != 200) {
        throw Exception('Descărcare eșuată (HTTP ${response.statusCode})');
      }

      final total = response.contentLength ?? 0;

      // Preferă folderul Downloads ca să fie ușor de găsit de utilizator.
      Directory dir;
      try {
        dir = (await getDownloadsDirectory()) ?? await getTemporaryDirectory();
      } catch (_) {
        dir = await getTemporaryDirectory();
      }

      final fileName = 'proterm_update_${info.latestBuildNumber}.exe';
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      final sink = file.openWrite();
      var received = 0;
      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _downloadProgress = received / total);
        }
      }).asFuture<void>();
      await sink.close();

      if (!mounted) return;
      setState(() => _downloading = false);

      // Afișează dialog cu instrucțiuni și buton pentru a deschide folderul.
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _WindowsUpdateDialog(
          filePath: file.path,
          folderPath: dir.path,
          version: info.latestVersion,
        ),
      );

      if (mounted) setState(() => _dismissed = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'Descărcare eșuată: $e';
      });
    }
  }

  // ─── Router platformă ──────────────────────────────────────────────────────

  Future<void> _downloadAndInstall() async {
    if (!kIsWeb && Platform.isWindows) {
      await _downloadAndInstallWindows();
    } else {
      await _downloadAndInstallAndroid();
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result == null || _dismissed) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.system_update_outlined,
                    color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Versiune nouă disponibilă (v${result.info.latestVersion}) — Actualizează acum',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!_downloading) ...[
                  TextButton(
                    onPressed: _downloadAndInstall,
                    child: const Text('Actualizează'),
                  ),
                  IconButton(
                    tooltip: 'Ascunde',
                    icon: Icon(Icons.close, color: scheme.onPrimaryContainer),
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ],
              ],
            ),
            if (result.info.releaseNotes.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 32, right: 8),
                child: Text(
                  result.info.releaseNotes.trim(),
                  style: TextStyle(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (_downloading)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 32, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Se descarcă actualizarea... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 32, right: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Dialog Windows ──────────────────────────────────────────────────────────

class _WindowsUpdateDialog extends StatelessWidget {
  const _WindowsUpdateDialog({
    required this.filePath,
    required this.folderPath,
    required this.version,
  });

  final String filePath;
  final String folderPath;
  final String version;

  Future<void> _openFolder() async {
    try {
      // Deschide folderul în Explorer cu fișierul selectat.
      await Process.start('explorer.exe', ['/select,', filePath]);
    } catch (_) {
      try {
        // Fallback: deschide folderul fără selecție.
        await Process.start('explorer.exe', [folderPath]);
      } catch (e) {
        debugPrint('[UpdateBanner] nu am putut deschide folderul: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.download_done_outlined, size: 36),
      title: Text('Versiunea v$version descărcată'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fișierul de instalare a fost salvat. '
            'Pentru a actualiza aplicația:',
          ),
          const SizedBox(height: 12),
          _Step(number: '1', text: 'Închide complet aplicația PRO TERM'),
          const SizedBox(height: 6),
          _Step(
            number: '2',
            text: 'Rulează fișierul de mai jos (dublu-click)',
          ),
          const SizedBox(height: 6),
          _Step(number: '3', text: 'Urmează pașii instalatorului'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              filePath,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Am înțeles'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            await _openFolder();
          },
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('Deschide folderul'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
