import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfFontBundle {
  const PdfFontBundle._({
    required this.base,
    required this.bold,
  });

  final pw.Font base;
  final pw.Font bold;

  pw.ThemeData get theme => pw.ThemeData.withFont(base: base, bold: bold);

  static Future<PdfFontBundle> load() {
    return _cached ??= _load();
  }

  static Future<PdfFontBundle>? _cached;

  static Future<PdfFontBundle> _load() async {
    final regular = await rootBundle.load('assets/fonts/arial.ttf');
    final bold = await rootBundle.load('assets/fonts/arialbd.ttf');
    return PdfFontBundle._(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
  }
}
