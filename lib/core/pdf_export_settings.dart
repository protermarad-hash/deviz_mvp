enum PdfDocumentCategory {
  offers,
  jobs,
  hrPayslips,
  hrStatements,
  hrAccountingReports,
  leaveRequests,
  attendanceReports,
  travelOrders,
  other,
}

enum PdfVisualTemplate {
  classic,
  executive,
  modern,
  minimal,
  bold,
  joyson,
}

extension PdfVisualTemplateX on PdfVisualTemplate {
  String get value {
    switch (this) {
      case PdfVisualTemplate.classic:
        return 'classic';
      case PdfVisualTemplate.executive:
        return 'executive';
      case PdfVisualTemplate.modern:
        return 'modern';
      case PdfVisualTemplate.minimal:
        return 'minimal';
      case PdfVisualTemplate.bold:
        return 'bold';
      case PdfVisualTemplate.joyson:
        return 'joyson';
    }
  }

  String get label {
    switch (this) {
      case PdfVisualTemplate.classic:
        return 'Clasic business';
      case PdfVisualTemplate.executive:
        return 'Executive premium';
      case PdfVisualTemplate.modern:
        return 'Modern editorial';
      case PdfVisualTemplate.minimal:
        return 'Minimal curat';
      case PdfVisualTemplate.bold:
        return 'Bold comercial';
      case PdfVisualTemplate.joyson:
        return 'Joyson industrial';
    }
  }

  String get description {
    switch (this) {
      case PdfVisualTemplate.classic:
        return 'Aspect sobru, potrivit pentru documente standard.';
      case PdfVisualTemplate.executive:
        return 'Contrast elegant si accente premium pentru oferte formale.';
      case PdfVisualTemplate.modern:
        return 'Ierarhie vizuala clara, carduri si ton contemporan.';
      case PdfVisualTemplate.minimal:
        return 'Design aerisit, discret, cu accent pe continut.';
      case PdfVisualTemplate.bold:
        return 'Titluri puternice si zone de evidentiere pentru documente comerciale.';
      case PdfVisualTemplate.joyson:
        return 'Layout operațional industrial, cu blocuri compacte pentru ofertă, beneficiar, materiale și condiții comerciale.';
    }
  }

  static PdfVisualTemplate fromValue(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final value in PdfVisualTemplate.values) {
      if (value.value == normalized) {
        return value;
      }
    }
    return PdfVisualTemplate.classic;
  }
}

class PdfExportSettings {
  const PdfExportSettings({
    this.askEveryTime = false,
    this.visualTemplate = PdfVisualTemplate.classic,
    this.defaultPdfFolder = '',
    this.offersFolder = '',
    this.jobsFolder = '',
    this.hrPayslipsFolder = '',
    this.hrStatementsFolder = '',
    this.hrAccountingReportsFolder = '',
    this.leaveRequestsFolder = '',
    this.attendanceReportsFolder = '',
    this.travelOrdersFolder = '',
  });

  final bool askEveryTime;
  final PdfVisualTemplate visualTemplate;
  final String defaultPdfFolder;
  final String offersFolder;
  final String jobsFolder;
  final String hrPayslipsFolder;
  final String hrStatementsFolder;
  final String hrAccountingReportsFolder;
  final String leaveRequestsFolder;
  final String attendanceReportsFolder;
  final String travelOrdersFolder;

  PdfExportSettings copyWith({
    bool? askEveryTime,
    PdfVisualTemplate? visualTemplate,
    String? defaultPdfFolder,
    String? offersFolder,
    String? jobsFolder,
    String? hrPayslipsFolder,
    String? hrStatementsFolder,
    String? hrAccountingReportsFolder,
    String? leaveRequestsFolder,
    String? attendanceReportsFolder,
    String? travelOrdersFolder,
  }) {
    return PdfExportSettings(
      askEveryTime: askEveryTime ?? this.askEveryTime,
      visualTemplate: visualTemplate ?? this.visualTemplate,
      defaultPdfFolder: defaultPdfFolder ?? this.defaultPdfFolder,
      offersFolder: offersFolder ?? this.offersFolder,
      jobsFolder: jobsFolder ?? this.jobsFolder,
      hrPayslipsFolder: hrPayslipsFolder ?? this.hrPayslipsFolder,
      hrStatementsFolder: hrStatementsFolder ?? this.hrStatementsFolder,
      hrAccountingReportsFolder:
          hrAccountingReportsFolder ?? this.hrAccountingReportsFolder,
      leaveRequestsFolder: leaveRequestsFolder ?? this.leaveRequestsFolder,
      attendanceReportsFolder:
          attendanceReportsFolder ?? this.attendanceReportsFolder,
      travelOrdersFolder: travelOrdersFolder ?? this.travelOrdersFolder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ask_every_time': askEveryTime,
      'visual_template': visualTemplate.value,
      'default_pdf_folder': defaultPdfFolder,
      'offers_folder': offersFolder,
      'jobs_folder': jobsFolder,
      'hr_payslips_folder': hrPayslipsFolder,
      'hr_statements_folder': hrStatementsFolder,
      'hr_accounting_reports_folder': hrAccountingReportsFolder,
      'leave_requests_folder': leaveRequestsFolder,
      'attendance_reports_folder': attendanceReportsFolder,
      'travel_orders_folder': travelOrdersFolder,
    };
  }

  factory PdfExportSettings.fromMap(Map<String, dynamic> map) {
    bool readBool(String key) {
      final raw = map[key];
      if (raw is bool) return raw;
      final normalized = (raw ?? '').toString().trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    String readString(String key) => (map[key] ?? '').toString().trim();

    return PdfExportSettings(
      askEveryTime: readBool('ask_every_time'),
      visualTemplate: PdfVisualTemplateX.fromValue(
        readString('visual_template'),
      ),
      defaultPdfFolder: readString('default_pdf_folder'),
      offersFolder: readString('offers_folder'),
      jobsFolder: readString('jobs_folder'),
      hrPayslipsFolder: readString('hr_payslips_folder'),
      hrStatementsFolder: readString('hr_statements_folder'),
      hrAccountingReportsFolder: readString('hr_accounting_reports_folder'),
      leaveRequestsFolder: readString('leave_requests_folder'),
      attendanceReportsFolder: readString('attendance_reports_folder'),
      travelOrdersFolder: readString('travel_orders_folder'),
    );
  }

  String folderForCategory(PdfDocumentCategory category) {
    switch (category) {
      case PdfDocumentCategory.offers:
        return offersFolder;
      case PdfDocumentCategory.jobs:
        return jobsFolder;
      case PdfDocumentCategory.hrPayslips:
        return hrPayslipsFolder;
      case PdfDocumentCategory.hrStatements:
        return hrStatementsFolder;
      case PdfDocumentCategory.hrAccountingReports:
        return hrAccountingReportsFolder;
      case PdfDocumentCategory.leaveRequests:
        return leaveRequestsFolder;
      case PdfDocumentCategory.attendanceReports:
        return attendanceReportsFolder;
      case PdfDocumentCategory.travelOrders:
        return travelOrdersFolder;
      case PdfDocumentCategory.other:
        return defaultPdfFolder;
    }
  }
}
