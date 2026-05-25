import 'package:shared_preferences/shared_preferences.dart';

/// Stochează local cheia API Anthropic și modelul Claude ales.
class AiConfigStore {
  AiConfigStore._();

  static const _keyApiKey = 'ai_anthropic_api_key';
  static const _keyModel = 'ai_anthropic_model';

  static const String defaultModel = 'claude-sonnet-4-6';
  static const String anthropicEndpoint =
      'https://api.anthropic.com/v1/messages';
  static const String anthropicVersion = '2023-06-01';

  static String _cachedApiKey = '';
  static String _cachedModel = '';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedApiKey = prefs.getString(_keyApiKey) ?? '';
    _cachedModel = prefs.getString(_keyModel) ?? '';
  }

  static Future<void> saveApiKey(String key) async {
    _cachedApiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, _cachedApiKey);
  }

  static Future<void> saveModel(String model) async {
    _cachedModel = model.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyModel, _cachedModel);
  }

  static Future<void> clearApiKey() async {
    _cachedApiKey = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyApiKey);
  }

  static String get apiKey => _cachedApiKey;
  static String get model =>
      _cachedModel.trim().isEmpty ? defaultModel : _cachedModel.trim();
  static bool get isConfigured => _cachedApiKey.trim().isNotEmpty;
}
