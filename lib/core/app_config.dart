import 'ai_config_store.dart';
import 'app_mode.dart';

class AppConfig {
  const AppConfig._();

  // OpenAI — păstrate pentru backward compatibility (neutilizate activ)
  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  static const String openAiResponsesEndpoint = String.fromEnvironment(
    'OPENAI_RESPONSES_ENDPOINT',
    defaultValue: 'https://api.openai.com/v1/responses',
  );

  static const String openAiModel = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-4.1-mini',
  );

  static const String openAiFileSearchVectorStoreId = String.fromEnvironment(
    'OPENAI_FILE_SEARCH_VECTOR_STORE_ID',
    defaultValue: '',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  // Delegat la AiConfigStore (Anthropic Claude)
  static bool get isAiAssistantConfigured => AiConfigStore.isConfigured;

  static bool get isAiFileSearchPrepared =>
      openAiFileSearchVectorStoreId.trim().isNotEmpty;

  static AppMode get mode =>
      isSupabaseConfigured ? AppMode.hybridCloud : AppMode.localOnly;
}
