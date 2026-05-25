import 'package:pdf/widgets.dart' as pw;

class PvPifPdfCommon {
  const PvPifPdfCommon._();

  static const String functionalChecksText =
      'Pornire/oprire, raspuns comenzi, functionare stabila, absenta alarmelor active.';

  static const String fieldParametersText =
      'Parametri electrici, temperaturi, presiuni/debite, etanseitate, zgomot/vibratii, observatii HSE (dupa caz).';

  static const String partsTraceabilityText =
      'Se consemneaza conform procedurilor interne de service/garantie si registrului logistic.';

  static const String legalObservationsText =
      'Documentul are caracter tehnic-operational. Drepturile si obligatiile partilor se interpreteaza conform contractelor aplicabile, certificatelor de garantie si cadrului legal in vigoare.';

  static const String fieldPhotoAnnexText =
      'Se recomanda atasarea fotografiilor de teren pentru identificare aparat, stari initiale/finale, piese inlocuite si situatii relevante.';

  static String complianceStatus(bool condition) {
    return condition ? 'COMPLETAT' : 'INCOMPLET';
  }

  static pw.Widget checkLine({
    required String label,
    required bool completed,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(label)),
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              complianceStatus(completed),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
