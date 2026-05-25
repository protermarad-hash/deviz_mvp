import '../../core/company_profile.dart';
import '../../core/repositories/app_data_repository.dart';

/// Service pentru acces centralizat la setările firmei.
/// Întotdeauna returnează un profil valid cu fallback-uri — nu crează niciodată null.
class CompanySettingsService {
  const CompanySettingsService(this._repository);

  final AppDataRepository _repository;

  /// Încarcă profilul firmei. Returnează întotdeauna un obiect complet.
  /// Dacă baza de date e goală, câmpurile sunt string-uri goale (nu null).
  Future<CompanyProfile> getSettings() {
    return _repository.loadCompanyProfile();
  }

  /// Salvează profilul complet al firmei.
  Future<void> updateSettings(CompanyProfile profile) {
    return _repository.saveCompanyProfile(profile);
  }

  /// True dacă datele esențiale sunt completate (Nume firmă + CUI).
  Future<bool> isConfigured() async {
    final profile = await _repository.loadCompanyProfile();
    return profile.isConfigured;
  }

  /// Actualizează parțial profilul — modifică doar câmpurile furnizate.
  Future<CompanyProfile> patchSettings({
    String? companyName,
    String? phone,
    String? email,
    String? contactEmail,
    String? website,
    String? cui,
    String? tradeRegister,
    String? bank,
    String? iban,
    String? contactName,
    String? address,
    String? city,
    String? county,
    String? currency,
    String? language,
    String? logoBase64,
    double? defaultVatPercent,
  }) async {
    final current = await _repository.loadCompanyProfile();
    final updated = current.copyWith(
      companyName: companyName,
      phone: phone,
      email: email,
      contactEmail: contactEmail,
      website: website,
      cui: cui,
      tradeRegister: tradeRegister,
      bank: bank,
      iban: iban,
      contactName: contactName,
      address: address,
      city: city,
      county: county,
      currency: currency,
      language: language,
      logoBase64: logoBase64,
      defaultVatPercent: defaultVatPercent,
    );
    await _repository.saveCompanyProfile(updated);
    return updated;
  }
}
