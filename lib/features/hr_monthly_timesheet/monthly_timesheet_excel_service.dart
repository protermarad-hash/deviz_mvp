import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/company_profile.dart';
import '../../core/pdf_export_settings.dart';
import '../../core/repositories/app_data_repository.dart';
import 'monthly_timesheet_models.dart';

class MonthlyTimesheetExcelSaveCanceledException implements Exception {
  const MonthlyTimesheetExcelSaveCanceledException();

  @override
  String toString() => 'MonthlyTimesheetExcelSaveCanceledException';
}

class MonthlyTimesheetExcelService {
  const MonthlyTimesheetExcelService._();

  static Future<String> export({
    required AppDataRepository repository,
    required MonthlyTimesheetRecord record,
    String outputDirectory = '',
    bool saveAs = false,
  }) async {
    final companyProfile = await repository.loadCompanyProfile();
    final bytes = _buildWorkbookBytes(
      companyProfile: companyProfile,
      record: record,
      generatedAt: DateTime.now(),
    );
    final fileName =
        'pontaj_lunar_${record.year}_${record.month.toString().padLeft(2, '0')}.xml';
    return _saveExcelFile(
      repository: repository,
      bytes: bytes,
      fileName: fileName,
      outputDirectory: outputDirectory,
      forceSaveAs: saveAs,
    );
  }

  static Uint8List _buildWorkbookBytes({
    required CompanyProfile companyProfile,
    required MonthlyTimesheetRecord record,
    required DateTime generatedAt,
  }) {
    final columns = <_ExcelColumn>[
      const _ExcelColumn(width: 180),
      const _ExcelColumn(width: 110),
      const _ExcelColumn(width: 84),
      const _ExcelColumn(width: 72),
      for (var day = 1; day <= record.daysInMonth; day++)
        const _ExcelColumn(width: 34),
      const _ExcelColumn(width: 58),
      for (final _ in MonthlyTimesheetCodeOption.defaults)
        const _ExcelColumn(width: 48),
    ];
    final totalColumnIndex = 4 + record.daysInMonth;
    final lastColumnIndex =
        totalColumnIndex + MonthlyTimesheetCodeOption.defaults.length;

    final rows = <String>[];
    rows.add(
      _xmlRow(
        cells: <String>[
          _mergeCell(
            value: companyProfile.companyName.trim().isEmpty
                ? 'Companie'
                : companyProfile.companyName.trim(),
            styleId: 'title',
            mergeAcross: lastColumnIndex,
          ),
        ],
      ),
    );
    rows.add(
      _xmlRow(
        cells: <String>[
          _mergeCell(
            value: 'Pontaj lunar tabelar',
            styleId: 'subtitle',
            mergeAcross: lastColumnIndex,
          ),
        ],
      ),
    );
    rows.add(
      _xmlRow(
        cells: <String>[
          _cell('Luna', styleId: 'metaLabel'),
          _cell(
            record.month.toString().padLeft(2, '0'),
            styleId: 'metaValue',
          ),
          _cell('An', styleId: 'metaLabel'),
          _cell(record.year.toString(), styleId: 'metaValue'),
          _cell('Data generarii', styleId: 'metaLabel'),
          _cell(_dateLabel(generatedAt), styleId: 'metaValue'),
        ],
      ),
    );
    rows.add(
      _xmlRow(
        cells: <String>[
          _cell('Angajati', styleId: 'metaLabel'),
          _cell(record.rows.length.toString(), styleId: 'metaValue'),
          _cell('Ore totale', styleId: 'metaLabel'),
          _cell(
            record.totalWorkedHours.toStringAsFixed(0),
            styleId: 'metaValue',
          ),
        ],
      ),
    );
    rows.add(_xmlRow(
        cells: <String>[for (var i = 0; i <= lastColumnIndex; i++) _cell('')]));

    rows.add(
      _xmlRow(
        cells: <String>[
          _cell('Angajat', styleId: 'header'),
          _cell('Echipa', styleId: 'header'),
          _cell('TM buget (RON)', styleId: 'headerCode'),
          _cell('TM RON/zi', styleId: 'headerCode'),
          for (var day = 1; day <= record.daysInMonth; day++)
            _cell(
              day.toString(),
              styleId: _isWeekend(record.year, record.month, day)
                  ? 'headerWeekend'
                  : 'header',
            ),
          _cell('Ore', styleId: 'headerTotal'),
          for (final option in MonthlyTimesheetCodeOption.defaults)
            _cell(option.code, styleId: 'headerCode'),
        ],
      ),
    );
    rows.add(
      _xmlRow(
        cells: <String>[
          _cell('', styleId: 'header'),
          _cell('', styleId: 'header'),
          _cell('', styleId: 'headerCode'),
          _cell('', styleId: 'headerCode'),
          for (var day = 1; day <= record.daysInMonth; day++)
            _cell(
              _weekdayLabel(record.year, record.month, day),
              styleId: _isWeekend(record.year, record.month, day)
                  ? 'headerWeekend'
                  : 'header',
            ),
          _cell('', styleId: 'headerTotal'),
          for (final _ in MonthlyTimesheetCodeOption.defaults)
            _cell('', styleId: 'headerCode'),
        ],
      ),
    );

    for (final row in record.rows) {
      final eligibleDays = _eligibleDays(record, row);
      final perDay = (row.mealTicketBudgetRon > 0 && eligibleDays > 0)
          ? row.mealTicketBudgetRon / eligibleDays
          : 0.0;
      rows.add(
        _xmlRow(
          cells: <String>[
            _cell(row.employeeName, styleId: 'employee'),
            _cell(row.teamName, styleId: 'team'),
            _cell(row.mealTicketBudgetRon.toStringAsFixed(2),
                styleId: 'codeValue'),
            _cell(perDay.toStringAsFixed(2), styleId: 'codeValue'),
            for (var day = 1; day <= record.daysInMonth; day++)
              _cell(
                row.dayValues['$day'] ?? '',
                styleId: _bodyStyleId(
                  year: record.year,
                  month: record.month,
                  day: day,
                  value: row.dayValues['$day'] ?? '',
                ),
              ),
            _cell(
              row.totalWorkedHours.toStringAsFixed(0),
              styleId: 'totalValue',
            ),
            for (final option in MonthlyTimesheetCodeOption.defaults)
              _cell(
                row.countCode(option.code).toString(),
                styleId: 'codeValue',
              ),
          ],
        ),
      );
    }

    rows.add(
      _xmlRow(
        cells: <String>[
          _cell('Sumar luna', styleId: 'summaryLabel'),
          _cell('', styleId: 'summaryLabel'),
          _cell(
            record.rows
                .fold<double>(0, (sum, row) => sum + row.mealTicketBudgetRon)
                .toStringAsFixed(2),
            styleId: 'summaryValue',
          ),
          _cell('', styleId: 'summaryValue'),
          for (var day = 1; day <= record.daysInMonth; day++)
            _cell(
              '',
              styleId: _isWeekend(record.year, record.month, day)
                  ? 'summaryWeekend'
                  : 'summaryLabel',
            ),
          _cell(
            record.totalWorkedHours.toStringAsFixed(0),
            styleId: 'summaryValue',
          ),
          for (final option in MonthlyTimesheetCodeOption.defaults)
            _cell(
              record.totalCodeCount(option.code).toString(),
              styleId: 'summaryValue',
            ),
        ],
      ),
    );

    final xml = StringBuffer()
      ..writeln('<?xml version="1.0"?>')
      ..writeln('<?mso-application progid="Excel.Sheet"?>')
      ..writeln(
        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
        'xmlns:o="urn:schemas-microsoft-com:office:office" '
        'xmlns:x="urn:schemas-microsoft-com:office:excel" '
        'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
      )
      ..writeln(
        '<DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">'
        '<Author>${_escapeXml(companyProfile.contactName.trim().isEmpty ? companyProfile.companyName : companyProfile.contactName)}</Author>'
        '<Created>${generatedAt.toUtc().toIso8601String()}</Created>'
        '</DocumentProperties>',
      )
      ..writeln(
        '<ExcelWorkbook xmlns="urn:schemas-microsoft-com:office:excel">'
        '<ProtectStructure>False</ProtectStructure>'
        '<ProtectWindows>False</ProtectWindows>'
        '</ExcelWorkbook>',
      )
      ..writeln(_stylesXml())
      ..writeln(
        '<Worksheet ss:Name="${_escapeXml('Pontaj ${record.month.toString().padLeft(2, '0')}-${record.year}')}">',
      )
      ..writeln('<Table x:FullColumns="1" x:FullRows="1">')
      ..writeln(columns.map((column) => column.toXml()).join())
      ..writeln(rows.join())
      ..writeln('</Table>')
      ..writeln(
        '<WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">'
        '<FreezePanes/>'
        '<FrozenNoSplit/>'
        '<SplitHorizontal>6</SplitHorizontal>'
        '<TopRowBottomPane>6</TopRowBottomPane>'
        '<ActivePane>2</ActivePane>'
        '<Panes>'
        '<Pane><Number>3</Number></Pane>'
        '<Pane><Number>2</Number><ActiveRow>6</ActiveRow></Pane>'
        '</Panes>'
        '<ProtectObjects>False</ProtectObjects>'
        '<ProtectScenarios>False</ProtectScenarios>'
        '</WorksheetOptions>',
      )
      ..writeln('</Worksheet>')
      ..writeln('</Workbook>');
    return Uint8List.fromList(utf8.encode(xml.toString()));
  }

  static Future<String> _saveExcelFile({
    required AppDataRepository repository,
    required Uint8List bytes,
    required String fileName,
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
      throw const MonthlyTimesheetExcelSaveCanceledException();
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

    final configuredFolder = settings
            .folderForCategory(PdfDocumentCategory.attendanceReports)
            .trim()
            .isEmpty
        ? settings.defaultPdfFolder.trim()
        : settings
            .folderForCategory(PdfDocumentCategory.attendanceReports)
            .trim();
    if (configuredFolder.isNotEmpty) {
      return _writeToDirectory(bytes, fileName, configuredFolder);
    }

    final fallbackDirectory = await _resolveFallbackDirectory();
    return _writeToDirectory(bytes, fileName, fallbackDirectory.path);
  }

  static Future<String?> _trySaveAs(String fileName) async {
    try {
      return await FilePicker.platform.saveFile(
        dialogTitle: 'Salveaza Excel',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['xml'],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _tryPickDirectory() async {
    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Alege folder pentru Excel',
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
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final filePath = '${directory.path}${Platform.pathSeparator}$fileName';
    return _writeToPath(bytes, filePath);
  }

  static Future<String> _writeToPath(Uint8List bytes, String filePath) async {
    var normalizedPath = filePath.trim();
    if (!normalizedPath.toLowerCase().endsWith('.xml')) {
      normalizedPath = '$normalizedPath.xml';
    }
    final file = File(normalizedPath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<Directory> _resolveFallbackDirectory() async {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.trim().isNotEmpty) {
        final windowsPath =
            '$userProfile\\Downloads\\DevizPro\\HR\\RapoartePontaj';
        final directory = Directory(windowsPath);
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        return directory;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${docs.path}${Platform.pathSeparator}hr_attendance_excel',
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  static String _bodyStyleId({
    required int year,
    required int month,
    required int day,
    required String value,
  }) {
    final normalized = value.trim().toUpperCase();
    final isWeekend = _isWeekend(year, month, day);
    if (normalized == 'CCC') {
      return 'bodyCcc';
    }
    if (normalized.isEmpty) {
      return isWeekend ? 'bodyWeekendEmpty' : 'bodyEmpty';
    }
    return isWeekend ? 'bodyWeekend' : 'body';
  }

  static bool _isWeekend(int year, int month, int day) {
    final date = DateTime(year, month, day);
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  static int _eligibleDays(
    MonthlyTimesheetRecord record,
    MonthlyTimesheetEmployeeRow row,
  ) {
    var count = 0;
    for (var day = 1; day <= record.daysInMonth; day++) {
      if (_isWeekend(record.year, record.month, day)) {
        continue;
      }
      final value = row.dayValues['$day'] ?? '';
      if (MonthlyTimesheetValueParser.hoursFromValue(value) > 0) {
        count++;
      }
    }
    return count;
  }

  static String _weekdayLabel(int year, int month, int day) {
    final date = DateTime(year, month, day);
    switch (date.weekday) {
      case DateTime.monday:
        return 'L';
      case DateTime.tuesday:
        return 'Ma';
      case DateTime.wednesday:
        return 'Mi';
      case DateTime.thursday:
        return 'J';
      case DateTime.friday:
        return 'V';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'D';
      default:
        return '-';
    }
  }

  static String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  static String _stylesXml() {
    return '''
<Styles>
  <Style ss:ID="Default" ss:Name="Normal">
    <Alignment ss:Vertical="Center"/>
    <Borders>
      <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#BFBFBF"/>
      <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#BFBFBF"/>
      <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#BFBFBF"/>
      <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#BFBFBF"/>
    </Borders>
    <Font ss:FontName="Calibri" ss:Size="10"/>
  </Style>
  <Style ss:ID="title">
    <Font ss:FontName="Calibri" ss:Size="16" ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#D9EAF7" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="subtitle">
    <Font ss:FontName="Calibri" ss:Size="13" ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#EAF2F8" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="metaLabel">
    <Font ss:Bold="1"/>
    <Interior ss:Color="#F2F2F2" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="metaValue">
    <Alignment ss:Horizontal="Center"/>
  </Style>
  <Style ss:ID="header">
    <Font ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#D9D9D9" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="headerWeekend">
    <Font ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#FCE4D6" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="headerTotal">
    <Font ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#DDEBF7" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="headerCode">
    <Font ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#E2F0D9" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="employee">
    <Font ss:Bold="1"/>
  </Style>
  <Style ss:ID="team">
    <Alignment ss:Horizontal="Left"/>
  </Style>
  <Style ss:ID="body">
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
  </Style>
  <Style ss:ID="bodyWeekend">
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#FFF2CC" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="bodyEmpty">
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#F8F8F8" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="bodyWeekendEmpty">
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#FCE4D6" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="bodyCcc">
    <Font ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#E4DFEC" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="totalValue">
    <Font ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#DDEBF7" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="codeValue">
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#F3F9EE" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="summaryLabel">
    <Font ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#D9EAD3" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="summaryWeekend">
    <Font ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#FCE4D6" ss:Pattern="Solid"/>
  </Style>
  <Style ss:ID="summaryValue">
    <Font ss:Bold="1"/>
    <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
    <Interior ss:Color="#C6E0B4" ss:Pattern="Solid"/>
  </Style>
</Styles>''';
  }

  static String _xmlRow({required List<String> cells}) {
    return '<Row>${cells.join()}</Row>';
  }

  static String _cell(
    String value, {
    String? styleId,
    int? mergeAcross,
  }) {
    final style = styleId == null ? '' : ' ss:StyleID="$styleId"';
    final merge = mergeAcross == null ? '' : ' ss:MergeAcross="$mergeAcross"';
    return '<Cell$style$merge><Data ss:Type="String">${_escapeXml(value)}</Data></Cell>';
  }

  static String _mergeCell({
    required String value,
    required String styleId,
    required int mergeAcross,
  }) {
    return _cell(value, styleId: styleId, mergeAcross: mergeAcross);
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

class _ExcelColumn {
  const _ExcelColumn({required this.width});

  final double width;

  String toXml() => '<Column ss:AutoFitWidth="0" ss:Width="$width"/>';
}
