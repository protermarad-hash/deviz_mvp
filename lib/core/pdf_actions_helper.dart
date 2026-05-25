import 'package:flutter/material.dart';
import 'document_file_service.dart';

/// Helper centralizat pentru acțiunile post-generare PDF.
///
/// Afișează un bottom sheet cu butoanele: Deschide, Share, Deschide folderul.
/// Folosit în TOATE modulele care generează documente PDF.
class PdfActionsHelper {
  const PdfActionsHelper._();

  /// Afișează bottom sheet cu acțiuni după salvarea unui PDF.
  ///
  /// [title] — titlul afișat în sheet (ex: "PDF deviz generat")
  /// [filePath] — calea completă a fișierului salvat
  /// [shareSubject] — subiectul mesajului de share (ex: "Deviz DT-2026-001")
  /// [shareText] — textul mesajului de share
  static Future<void> showPdfActions(
    BuildContext context, {
    required String filePath,
    required String title,
    String shareSubject = 'Document PDF',
    String shareText = 'PDF generat din aplicație.',
  }) async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  filePath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final result =
                            await DocumentFileService.openFile(filePath);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message)),
                        );
                        if (result.shouldOfferShare && context.mounted) {
                          await _shareFile(
                            context,
                            filePath: filePath,
                            subject: shareSubject,
                            shareText: shareText,
                          );
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Deschide'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _shareFile(
                          context,
                          filePath: filePath,
                          subject: shareSubject,
                          shareText: shareText,
                        );
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                    if (!DocumentFileService.isMobilePlatform)
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final opened =
                              await DocumentFileService.openFolderForFile(
                            filePath,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                opened
                                    ? 'Folder deschis.'
                                    : 'Nu am putut deschide folderul.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Deschide folderul'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _shareFile(
    BuildContext context, {
    required String filePath,
    required String subject,
    required String shareText,
  }) async {
    try {
      await DocumentFileService.shareFile(
        filePath,
        subject: subject,
        text: shareText,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share deschis pentru PDF.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut trimite PDF-ul: $e')),
      );
    }
  }
}
