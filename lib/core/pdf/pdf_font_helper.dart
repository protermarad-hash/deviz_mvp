import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Helper centralizat pentru fonturi PDF cu suport complet UTF-8 / diacritice românești.
/// Folosiți ÎNTOTDEAUNA acest helper în orice serviciu PDF nou sau modificat.
class PdfFontHelper {
  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _italic;
  static bool _initialized = false;

  static pw.Font get regular {
    assert(_initialized, 'PdfFontHelper.initialize() trebuie apelat înainte de folosire');
    return _regular!;
  }

  static pw.Font get bold {
    assert(_initialized, 'PdfFontHelper.initialize() trebuie apelat înainte de folosire');
    return _bold!;
  }

  static pw.Font get italic {
    assert(_initialized, 'PdfFontHelper.initialize() trebuie apelat înainte de folosire');
    return _italic!;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    final regularData = await rootBundle.load('assets/fonts/arial.ttf');
    final boldData = await rootBundle.load('assets/fonts/arialbd.ttf');
    _regular = pw.Font.ttf(regularData);
    _bold = pw.Font.ttf(boldData);
    _italic = pw.Font.ttf(regularData); // Arial italic fallback
    _initialized = true;
  }

  static pw.ThemeData get theme => pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: italic,
        boldItalic: bold,
      );
}
