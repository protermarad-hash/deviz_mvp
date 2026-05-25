import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/ai_config_store.dart';

class ClaudeMessage {
  const ClaudeMessage({required this.role, required this.content});
  final String role;
  final String content;

  Map<String, dynamic> toMap() => {'role': role, 'content': content};
}

class ClaudeChatService {
  ClaudeChatService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const int _maxTokens = 2048;
  static const String _systemPrompt =
      'Ești un asistent AI pentru firma PRO TERM SRL, specializat în HVAC, '
      'construcții, devize și managementul firmei. Răspunzi în română, '
      'profesionist și concis. Poți ajuta cu redactarea documentelor, '
      'calcule, sfaturi tehnice, explicații legislative și orice întrebare '
      'legată de activitatea firmei.';

  Future<String> sendMessage({
    required List<ClaudeMessage> history,
    required String userMessage,
    String? customSystem,
  }) async {
    if (!AiConfigStore.isConfigured) {
      throw Exception('API key Anthropic lipsă. Configurează cheia în setări.');
    }

    final messages = [
      ...history.map((m) => m.toMap()),
      {'role': 'user', 'content': userMessage.trim()},
    ];

    final body = jsonEncode({
      'model': AiConfigStore.model,
      'max_tokens': _maxTokens,
      'system': customSystem ?? _systemPrompt,
      'messages': messages,
    });

    final response = await _client.post(
      Uri.parse(AiConfigStore.anthropicEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AiConfigStore.apiKey,
        'anthropic-version': AiConfigStore.anthropicVersion,
      },
      body: body,
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = '';
      try {
        final decoded = jsonDecode(response.body);
        detail = (decoded['error']?['message'] ?? '').toString();
      } catch (_) {}
      throw Exception(
        'Eroare API Claude (${response.statusCode})'
        '${detail.isEmpty ? '' : ': $detail'}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'] as List?;
    if (content == null || content.isEmpty) {
      throw Exception('Răspuns gol de la Claude.');
    }
    final text = (content.first as Map)['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw Exception('Claude nu a returnat text.');
    }
    return text;
  }
}
