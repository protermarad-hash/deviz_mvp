import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../../core/ai_config_store.dart';
import '../../core/repositories/app_data_repository.dart';
import '../product_catalog/product_catalog_models.dart';
import '../product_catalog/product_catalog_service.dart';
import 'ai_assistant_action_catalog.dart';
import 'ai_assistant_models.dart';
import 'ai_assistant_prompt_service.dart';
import 'ai_assistant_requirement_models.dart';

class AiAssistantService {
  AiAssistantService({
    required AppDataRepository repository,
    http.Client? client,
    ProductCatalogService? productCatalogService,
    AiAssistantPromptService? promptService,
  })  : _repository = repository,
        _client = client ?? http.Client(),
        _productCatalogService =
            productCatalogService ?? ProductCatalogService(),
        _promptService = promptService ?? const AiAssistantPromptService();

  final AppDataRepository _repository;
  final http.Client _client;
  final ProductCatalogService _productCatalogService;
  final AiAssistantPromptService _promptService;

  bool get isConfigured => AiConfigStore.isConfigured;

  Future<AiAssistantRunResult> generateDraft({
    required AiAssistantSessionRecord session,
    required AiAssistantQuickAction action,
    required AiAssistantRuntimeContext runtimeContext,
    String userPrompt = '',
  }) async {
    final userMessage = AiAssistantMessageRecord(
      id: _newId('ai-msg'),
      role: AiAssistantMessageRole.user,
      content: userPrompt.trim().isEmpty
          ? action.defaultPrompt
          : '${action.defaultPrompt}\n\nCerinta suplimentara: ${userPrompt.trim()}',
      createdAt: DateTime.now(),
      metadata: <String, dynamic>{
        'action_id': action.id,
      },
    );
    var workingSession = session.copyWith(
      status: AiAssistantSessionStatus.generating,
      updatedAt: DateTime.now(),
      lastSuggestedAction: action.id,
      messages: <AiAssistantMessageRecord>[...session.messages, userMessage],
    );

    if (!isConfigured) {
      const message =
          'Asistentul AI este pregătit, dar lipsește cheia API Anthropic. '
          'Configurează cheia în modulul AI > Setări.';
      workingSession = _appendAssistantMessage(
        workingSession.copyWith(status: AiAssistantSessionStatus.unavailable),
        message,
        metadata: <String, dynamic>{'reason': 'missing_anthropic_config'},
      );
      return AiAssistantRunResult(
        session: workingSession,
        status: AiAssistantSessionStatus.unavailable,
        unavailableReason: message,
      );
    }

    final tools = AiAssistantActionCatalog.toolsForAction(action);
    final toolTrace = <Map<String, dynamic>>[];
    AiAssistantDraft? toolDraft;

    final systemPrompt = _promptService.buildSystemPrompt(
      action: action,
      runtimeContext: runtimeContext,
    );

    // Construim mesajele Claude: mai întâi istoricul sesiunii, apoi cererea curentă
    List<Map<String, dynamic>> messages = _buildInitialClaudeMessages(
      session: workingSession,
      action: action,
      runtimeContext: runtimeContext,
      userPrompt: userPrompt,
    );

    try {
      for (var iteration = 0; iteration < 4; iteration++) {
        final response = await _postResponse(
          systemPrompt: systemPrompt,
          messages: messages,
          tools: tools,
        );

        final functionCalls = _extractFunctionCalls(response);
        if (functionCalls.isEmpty) {
          final rawOutput = _extractOutputText(response);
          final draft = toolDraft ??
              _draftFromRawOutput(
                action: action,
                rawOutput: rawOutput,
              );
          final assistantText = draft == null
              ? (rawOutput.trim().isEmpty
                  ? 'Nu am putut construi un draft utilizabil din răspunsul modelului.'
                  : rawOutput.trim())
              : '${draft.title}\n\n${draft.content}'.trim();
          final finalStatus = draft == null
              ? AiAssistantSessionStatus.error
              : AiAssistantSessionStatus.ready;
          workingSession = _appendAssistantMessage(
            workingSession.copyWith(
              status: finalStatus,
              updatedAt: DateTime.now(),
            ),
            assistantText,
            metadata: <String, dynamic>{
              'action_id': action.id,
              'has_draft': draft != null,
            },
          );
          return AiAssistantRunResult(
            session: workingSession,
            status: finalStatus,
            draft: draft,
            rawOutput: rawOutput,
            toolTrace: toolTrace,
          );
        }

        // Adăugăm răspunsul asistentului (cu tool_use) în conversație
        final assistantContent = response['content'];
        if (assistantContent is List) {
          messages.add(<String, dynamic>{
            'role': 'assistant',
            'content': assistantContent,
          });
        }

        // Executăm tool calls și construim răspunsurile
        final toolResults = <Map<String, dynamic>>[];
        for (final call in functionCalls) {
          final toolResult = await _executeToolCall(
            toolName: call.name,
            arguments: call.arguments,
            action: action,
            runtimeContext: runtimeContext,
          );
          toolTrace.add(<String, dynamic>{
            'tool_name': call.name,
            'arguments': call.arguments,
            'result': toolResult,
          });
          final draftMap = toolResult['draft'];
          if (draftMap is Map<String, dynamic>) {
            toolDraft = _draftFromMap(action: action, map: draftMap);
          }
          toolResults.add(<String, dynamic>{
            'type': 'tool_result',
            'tool_use_id': call.callId,
            'content': jsonEncode(toolResult),
          });
        }

        // Adăugăm rezultatele tool-urilor ca mesaj user în conversație
        messages.add(<String, dynamic>{
          'role': 'user',
          'content': toolResults,
        });
      }
    } catch (error) {
      final message = 'Asistentul AI nu a putut genera draftul: $error';
      workingSession = _appendAssistantMessage(
        workingSession.copyWith(
          status: AiAssistantSessionStatus.error,
          updatedAt: DateTime.now(),
        ),
        message,
        metadata: <String, dynamic>{'error': error.toString()},
      );
      return AiAssistantRunResult(
        session: workingSession,
        status: AiAssistantSessionStatus.error,
        unavailableReason: message,
        toolTrace: toolTrace,
      );
    }

    const timeoutMessage =
        'Asistentul AI a depășit numărul de iterații permis pentru tool calling. Nu a fost salvată nicio modificare.';
    workingSession = _appendAssistantMessage(
      workingSession.copyWith(
        status: AiAssistantSessionStatus.error,
        updatedAt: DateTime.now(),
      ),
      timeoutMessage,
    );
    return AiAssistantRunResult(
      session: workingSession,
      status: AiAssistantSessionStatus.error,
      unavailableReason: timeoutMessage,
      toolTrace: toolTrace,
    );
  }

  Future<AiRequirementAnalysisResult> analyzeOfferRequirement({
    required AiAssistantRuntimeContext runtimeContext,
    required String requirementText,
    String userNotes = '',
  }) async {
    final normalizedRequirement = requirementText.trim();
    if (normalizedRequirement.isEmpty) {
      return const AiRequirementAnalysisResult(
        originalRequirement: '',
        recognizedItems: <AiRequirementRecognizedItem>[],
        offerPositions: <AiRequirementOfferPositionDraft>[],
        unavailableReason:
            'Introdu textul cerinței clientului înainte de analiză asistată.',
      );
    }

    if (!isConfigured) {
      return AiRequirementAnalysisResult(
        originalRequirement: normalizedRequirement,
        recognizedItems: const <AiRequirementRecognizedItem>[],
        offerPositions: const <AiRequirementOfferPositionDraft>[],
        unavailableReason: _missingAiConfigMessage(),
      );
    }

    final action = AiAssistantActionCatalog.actionById(
      'offer_requirement_to_draft',
    );
    if (action == null) {
      return AiRequirementAnalysisResult(
        originalRequirement: normalizedRequirement,
        recognizedItems: const <AiRequirementRecognizedItem>[],
        offerPositions: const <AiRequirementOfferPositionDraft>[],
        unavailableReason:
            'Fluxul de analiză pentru cerințe nu este disponibil în catalogul AI.',
      );
    }

    final tools = AiAssistantActionCatalog.toolsForAction(action);
    final toolTrace = <Map<String, dynamic>>[];

    var recognizedItems = <AiRequirementRecognizedItem>[];
    var positions = <AiRequirementOfferPositionDraft>[];
    var clarificationQuestions = <String>[];
    var warnings = <String>[];
    var suggestedServices = <String>[];
    var suggestedAccessories = <String>[];
    var draftNotes = '';

    final systemPromptReq = _promptService.buildRequirementSystemPrompt(
      runtimeContext: runtimeContext,
    );
    List<Map<String, dynamic>> messages = <Map<String, dynamic>>[
      <String, dynamic>{
        'role': 'user',
        'content': _promptService.buildRequirementUserPrompt(
          runtimeContext: runtimeContext,
          requirementText: normalizedRequirement,
          userNotes: userNotes,
        ),
      },
    ];

    try {
      for (var iteration = 0; iteration < 6; iteration++) {
        final response = await _postResponse(
          systemPrompt: systemPromptReq,
          messages: messages,
          tools: tools,
        );

        final functionCalls = _extractFunctionCalls(response);
        if (functionCalls.isEmpty) {
          final finalizedPositions = _finalizeRequirementPositions(
            items: recognizedItems,
            positions: positions,
            suggestedServices: suggestedServices,
            suggestedAccessories: suggestedAccessories,
          );
          if (recognizedItems.isEmpty && finalizedPositions.isEmpty) {
            final rawOutput = _extractOutputText(response);
            return AiRequirementAnalysisResult(
              originalRequirement: normalizedRequirement,
              recognizedItems: const <AiRequirementRecognizedItem>[],
              offerPositions: const <AiRequirementOfferPositionDraft>[],
              warnings: warnings,
              unavailableReason: rawOutput.trim().isEmpty
                  ? 'Asistentul AI nu a returnat o analiză structurată utilizabilă.'
                  : rawOutput.trim(),
            );
          }
          return AiRequirementAnalysisResult(
            originalRequirement: normalizedRequirement,
            recognizedItems: recognizedItems,
            offerPositions: finalizedPositions,
            clarificationQuestions: clarificationQuestions,
            warnings: warnings,
            suggestedServices: suggestedServices,
            suggestedAccessories: suggestedAccessories,
            draftNotes: draftNotes,
          );
        }

        // Adăugăm răspunsul asistentului (cu tool_use)
        final assistantContent = response['content'];
        if (assistantContent is List) {
          messages.add(<String, dynamic>{
            'role': 'assistant',
            'content': assistantContent,
          });
        }

        final toolResults = <Map<String, dynamic>>[];
        for (final call in functionCalls) {
          final toolResult = await _executeToolCall(
            toolName: call.name,
            arguments: call.arguments,
            action: action,
            runtimeContext: runtimeContext,
          );
          toolTrace.add(<String, dynamic>{
            'tool_name': call.name,
            'arguments': call.arguments,
            'result': toolResult,
          });

          final nextItems = _parseRequirementItems(toolResult['items']);
          if (nextItems.isNotEmpty) {
            recognizedItems = nextItems;
          }
          final nextPositions = _parseRequirementPositions(
            toolResult['positions'],
          );
          if (nextPositions.isNotEmpty) {
            positions = nextPositions;
          }
          final nextQuestions = _parseStringList(
            toolResult['clarification_questions'],
          );
          if (nextQuestions.isNotEmpty) {
            clarificationQuestions = nextQuestions;
          }
          final nextWarnings = _parseStringList(toolResult['warnings']);
          if (nextWarnings.isNotEmpty) {
            warnings = nextWarnings;
          }
          final nextServices = _parseStringList(
            toolResult['service_suggestions'],
          );
          if (nextServices.isNotEmpty) {
            suggestedServices = nextServices;
          }
          final nextAccessories = _parseStringList(
            toolResult['accessory_suggestions'],
          );
          if (nextAccessories.isNotEmpty) {
            suggestedAccessories = nextAccessories;
          }
          final nextDraftNotes = (toolResult['draft_notes'] ?? '').toString();
          if (nextDraftNotes.trim().isNotEmpty) {
            draftNotes = nextDraftNotes.trim();
          }

          toolResults.add(<String, dynamic>{
            'type': 'tool_result',
            'tool_use_id': call.callId,
            'content': jsonEncode(toolResult),
          });
        }

        messages.add(<String, dynamic>{
          'role': 'user',
          'content': toolResults,
        });
      }
    } catch (error) {
      return AiRequirementAnalysisResult(
        originalRequirement: normalizedRequirement,
        recognizedItems: recognizedItems,
        offerPositions: _finalizeRequirementPositions(
          items: recognizedItems,
          positions: positions,
          suggestedServices: suggestedServices,
          suggestedAccessories: suggestedAccessories,
        ),
        clarificationQuestions: clarificationQuestions,
        warnings: <String>[
          ...warnings,
          'Analiza AI nu a putut fi finalizată complet: $error',
        ],
        suggestedServices: suggestedServices,
        suggestedAccessories: suggestedAccessories,
        draftNotes: draftNotes,
        unavailableReason: recognizedItems.isEmpty && positions.isEmpty
            ? 'Analiza AI nu a putut fi finalizată: $error'
            : '',
      );
    }

    return AiRequirementAnalysisResult(
      originalRequirement: normalizedRequirement,
      recognizedItems: recognizedItems,
      offerPositions: _finalizeRequirementPositions(
        items: recognizedItems,
        positions: positions,
        suggestedServices: suggestedServices,
        suggestedAccessories: suggestedAccessories,
      ),
      clarificationQuestions: clarificationQuestions,
      warnings: <String>[
        ...warnings,
        'Asistentul AI a depășit numărul de iterații permis pentru această analiză.',
      ],
      suggestedServices: suggestedServices,
      suggestedAccessories: suggestedAccessories,
      draftNotes: draftNotes,
      unavailableReason: recognizedItems.isEmpty && positions.isEmpty
          ? 'Analiza AI a depășit numărul de iterații permis.'
          : '',
    );
  }

  // ── Claude Messages API ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _postResponse({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    required List<AiAssistantToolDefinition> tools,
  }) async {
    final body = <String, dynamic>{
      'model': AiConfigStore.model,
      'max_tokens': 4096,
      'system': systemPrompt,
      'messages': messages,
      if (tools.isNotEmpty)
        'tools': tools
            .map((item) => item.toClaudeToolMap())
            .toList(growable: false),
    };

    final response = await _client
        .post(
          Uri.parse(AiConfigStore.anthropicEndpoint),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'x-api-key': AiConfigStore.apiKey,
            'anthropic-version': AiConfigStore.anthropicVersion,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = '';
      try {
        final decoded = jsonDecode(response.body);
        detail = (decoded['error']?['message'] ?? '').toString();
      } catch (e) {
        debugPrint('[AiAssistant] parsare detaliu eroare API eșuată: $e');
      }
      throw Exception(
        'Claude API (${response.statusCode})'
        '${detail.isEmpty ? '' : ': $detail'}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Claude API a returnat un payload invalid.');
    }
    return decoded;
  }

  List<Map<String, dynamic>> _buildInitialClaudeMessages({
    required AiAssistantSessionRecord session,
    required AiAssistantQuickAction action,
    required AiAssistantRuntimeContext runtimeContext,
    required String userPrompt,
  }) {
    final messages = <Map<String, dynamic>>[];

    // Adăugăm istoricul conversației existente (user/assistant)
    for (final item in session.messages.where(
      (message) =>
          message.role == AiAssistantMessageRole.user ||
          message.role == AiAssistantMessageRole.assistant,
    )) {
      messages.add(<String, dynamic>{
        'role':
            item.role == AiAssistantMessageRole.user ? 'user' : 'assistant',
        'content': item.content,
      });
    }

    // Adăugăm cererea curentă
    messages.add(<String, dynamic>{
      'role': 'user',
      'content': _promptService.buildUserPrompt(
        action: action,
        runtimeContext: runtimeContext,
        userPrompt: userPrompt,
      ),
    });

    return messages;
  }

  // ── Parsare răspuns Claude ─────────────────────────────────────────────────

  List<_FunctionCallPayload> _extractFunctionCalls(
      Map<String, dynamic> response) {
    final content = response['content'];
    if (content is! List) return const <_FunctionCallPayload>[];
    final result = <_FunctionCallPayload>[];
    for (final item in content.whereType<Map>()) {
      final row = Map<String, dynamic>.from(item);
      if ((row['type'] ?? '').toString() != 'tool_use') {
        continue;
      }
      final name = (row['name'] ?? '').toString().trim();
      final callId = (row['id'] ?? '').toString().trim();
      if (name.isEmpty || callId.isEmpty) {
        continue;
      }
      Map<String, dynamic> arguments = const <String, dynamic>{};
      final rawInput = row['input'];
      if (rawInput is Map<String, dynamic>) {
        arguments = rawInput;
      } else if (rawInput is Map) {
        arguments = Map<String, dynamic>.from(rawInput);
      }
      result.add(
        _FunctionCallPayload(
          callId: callId,
          name: name,
          arguments: arguments,
        ),
      );
    }
    return result;
  }

  String _extractOutputText(Map<String, dynamic> response) {
    final content = response['content'];
    if (content is! List) return '';
    final buffer = StringBuffer();
    for (final item in content.whereType<Map>()) {
      final row = Map<String, dynamic>.from(item);
      if ((row['type'] ?? '').toString() != 'text') {
        continue;
      }
      final text = (row['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      if (buffer.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write(text);
    }
    return buffer.toString().trim();
  }

  // ── Draft building ─────────────────────────────────────────────────────────

  AiAssistantDraft? _draftFromRawOutput({
    required AiAssistantQuickAction action,
    required String rawOutput,
  }) {
    final normalized = rawOutput.trim();
    if (normalized.isEmpty) return null;
    final parsed = _extractJsonObject(normalized);
    if (parsed != null) {
      return _draftFromMap(action: action, map: parsed);
    }
    return AiAssistantDraft(
      id: _newId('ai-draft'),
      actionId: action.id,
      title: action.label,
      content: normalized,
      createdAt: DateTime.now(),
      status: AiAssistantDraftStatus.suggestion,
      targetKey: action.defaultTargetKey,
      disclaimer: action.delicate
          ? 'Text generat asistat de AI — necesită verificare umană.'
          : 'Text generat asistat de AI.',
    );
  }

  AiAssistantDraft _draftFromMap({
    required AiAssistantQuickAction action,
    required Map<String, dynamic> map,
  }) {
    final targetKey = (map['target_key'] ?? action.defaultTargetKey).toString();
    final reviewRequired =
        map['human_review_required'] == true || action.delicate;
    return AiAssistantDraft(
      id: _newId('ai-draft'),
      actionId: action.id,
      title: (map['title'] ?? action.label).toString().trim().isEmpty
          ? action.label
          : (map['title'] ?? action.label).toString().trim(),
      content: (map['content'] ?? '').toString().trim(),
      createdAt: DateTime.now(),
      status: AiAssistantDraftStatus.suggestion,
      targetKey: targetKey,
      disclaimer: reviewRequired
          ? 'Text generat asistat de AI — necesită verificare umană.'
          : 'Text generat asistat de AI.',
      metadata: map,
    );
  }

  Map<String, dynamic>? _extractJsonObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('[AiAssistant] decodare JSON directă eșuată, încerc extragere acoladă: $e');
    }
    final firstBrace = raw.indexOf('{');
    final lastBrace = raw.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace <= firstBrace) return null;
    final candidate = raw.substring(firstBrace, lastBrace + 1);
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('[AiAssistant] decodare JSON din substring eșuată: $e');
    }
    return null;
  }

  // ── Tool execution (neschimbat) ────────────────────────────────────────────

  Future<Map<String, dynamic>> _executeToolCall({
    required String toolName,
    required Map<String, dynamic> arguments,
    required AiAssistantQuickAction action,
    required AiAssistantRuntimeContext runtimeContext,
  }) async {
    switch (toolName) {
      case AiAssistantActionCatalog.getOfferContextTool:
        return <String, dynamic>{
          'offer': _contextRow(runtimeContext, 'offer'),
        };
      case AiAssistantActionCatalog.getClientContextTool:
        return <String, dynamic>{
          'client': _findClientContext(runtimeContext, arguments),
        };
      case AiAssistantActionCatalog.getJobContextTool:
        return <String, dynamic>{
          'job': _contextRow(runtimeContext, 'job'),
        };
      case AiAssistantActionCatalog.getComplaintContextTool:
        return <String, dynamic>{
          'complaint': _contextRow(runtimeContext, 'complaint'),
        };
      case AiAssistantActionCatalog.getFieldSalesRequestContextTool:
        return <String, dynamic>{
          'field_sales_request':
              _contextRow(runtimeContext, 'field_sales_request'),
          'lead': _contextRow(runtimeContext, 'lead'),
        };
      case AiAssistantActionCatalog.getCompanyProfileContextTool:
        final profile = await _repository.loadCompanyProfile();
        return <String, dynamic>{
          'company_profile': profile.toMap(),
        };
      case AiAssistantActionCatalog.parseCustomerRequirementTool:
        final parsedItems = _parseRequirementItems(arguments['items']);
        return <String, dynamic>{
          'original_requirement':
              (arguments['original_requirement'] ?? '').toString().trim(),
          'items': parsedItems
              .map((item) => _normalizeRequirementItem(item).toMap())
              .toList(growable: false),
          'clarification_questions': _parseStringList(
            arguments['clarification_questions'],
          ),
          'warnings': _parseStringList(arguments['warnings']),
        };
      case AiAssistantActionCatalog.normalizeRequirementItemsTool:
        final normalizedItems = _parseRequirementItems(arguments['items'])
            .map(_normalizeRequirementItem)
            .toList(growable: false);
        return <String, dynamic>{
          'items': normalizedItems
              .map((item) => item.toMap())
              .toList(growable: false),
        };
      case AiAssistantActionCatalog.matchCatalogProductsTool:
        final matchedItems = <AiRequirementRecognizedItem>[];
        for (final item in _parseRequirementItems(arguments['items'])) {
          matchedItems.add(
            item.copyWith(
              catalogMatches: await _catalogMatchesFor(
                _normalizeRequirementItem(item),
                runtimeContext,
              ),
            ),
          );
        }
        return <String, dynamic>{
          'items':
              matchedItems.map((item) => item.toMap()).toList(growable: false),
        };
      case AiAssistantActionCatalog.suggestRequiredServicesTool:
        final serviceItems = _parseRequirementItems(arguments['items']);
        final serviceSuggestions = _parseStringList(
          arguments['service_suggestions'],
        );
        return <String, dynamic>{
          'service_suggestions': serviceSuggestions.isNotEmpty
              ? serviceSuggestions
              : _deriveServiceSuggestions(serviceItems, runtimeContext),
        };
      case AiAssistantActionCatalog.suggestMissingAccessoriesTool:
        final accessoryItems = _parseRequirementItems(arguments['items']);
        final accessorySuggestions = _parseStringList(
          arguments['accessory_suggestions'],
        );
        return <String, dynamic>{
          'accessory_suggestions': accessorySuggestions.isNotEmpty
              ? accessorySuggestions
              : _deriveAccessorySuggestions(accessoryItems),
        };
      case AiAssistantActionCatalog.suggestOfferPositionsFromRequirementTool:
        final proposedPositions = _parseRequirementPositions(
          arguments['positions'],
        );
        if (proposedPositions.isNotEmpty) {
          return <String, dynamic>{
            'positions': proposedPositions
                .map((item) => item.toMap())
                .toList(growable: false),
          };
        }
        final sourceItems = _parseRequirementItems(arguments['items']);
        final fallbackPositions = _fallbackPositionsFromItems(sourceItems);
        return <String, dynamic>{
          'positions': fallbackPositions
              .map((item) => item.toMap())
              .toList(growable: false),
        };
      case AiAssistantActionCatalog.createOfferDraftFromRequirementTool:
        final draftPositions = _parseRequirementPositions(
          arguments['positions'],
        );
        final fallbackDraftPositions = draftPositions.isNotEmpty
            ? draftPositions
            : _fallbackPositionsFromItems(
                _parseRequirementItems(arguments['items']),
              );
        return <String, dynamic>{
          'draft_title': (arguments['draft_title'] ?? '').toString().trim(),
          'draft_notes': (arguments['draft_notes'] ?? '').toString().trim(),
          'positions': fallbackDraftPositions
              .map((item) => item.toMap())
              .toList(growable: false),
          'clarification_questions': _parseStringList(
            arguments['clarification_questions'],
          ),
          'warnings': _parseStringList(arguments['warnings']),
        };
      case AiAssistantActionCatalog.getProductContextTool:
        return <String, dynamic>{
          'products': await _findProductContext(runtimeContext, arguments),
        };
      case AiAssistantActionCatalog.createOfferTextDraftTool:
      case AiAssistantActionCatalog.createReportDraftTool:
      case AiAssistantActionCatalog.createEmailDraftTool:
        return <String, dynamic>{
          'draft': <String, dynamic>{
            'title': (arguments['title'] ?? action.label).toString().trim(),
            'content': (arguments['content'] ?? '').toString().trim(),
            'target_key': (arguments['target_key'] ?? action.defaultTargetKey)
                .toString()
                .trim(),
            'human_review_required': action.delicate ||
                toolName != AiAssistantActionCatalog.createOfferTextDraftTool,
          },
        };
      default:
        return <String, dynamic>{
          'error': 'Tool necunoscut: $toolName',
        };
    }
  }

  // ── Context helpers (neschimbate) ──────────────────────────────────────────

  Map<String, dynamic> _contextRow(
    AiAssistantRuntimeContext runtimeContext,
    String key,
  ) {
    final related = runtimeContext.relatedData[key];
    if (related is Map<String, dynamic>) {
      return related;
    }
    if (related is Map) {
      return Map<String, dynamic>.from(related);
    }
    if (runtimeContext.primaryData['type'] == key) {
      return runtimeContext.primaryData;
    }
    return runtimeContext.primaryData;
  }

  Map<String, dynamic> _findClientContext(
    AiAssistantRuntimeContext runtimeContext,
    Map<String, dynamic> arguments,
  ) {
    final related = runtimeContext.relatedData['client'];
    if (related is Map<String, dynamic>) {
      return related;
    }
    if (related is Map) {
      return Map<String, dynamic>.from(related);
    }
    final clientId = (arguments['client_id'] ?? '').toString().trim();
    final primaryClientId = (runtimeContext.primaryData['client_id'] ??
            runtimeContext.primaryData['beneficiary_client_id'] ??
            runtimeContext.primaryData['clientId'] ??
            '')
        .toString()
        .trim();
    return <String, dynamic>{
      'client_id': clientId.isNotEmpty ? clientId : primaryClientId,
      'client_name': (runtimeContext.primaryData['client_name'] ??
              runtimeContext.primaryData['clientName'] ??
              runtimeContext.primaryData['beneficiary_name'] ??
              runtimeContext.primaryData['beneficiaryName'] ??
              runtimeContext.primaryData['contractor_name'] ??
              '')
          .toString(),
      'contact_name': (runtimeContext.primaryData['contact_name'] ??
              runtimeContext.primaryData['contactName'] ??
              runtimeContext.primaryData['contact_person'] ??
              '')
          .toString(),
      'email': (runtimeContext.primaryData['email'] ?? '').toString(),
      'phone': (runtimeContext.primaryData['phone'] ?? '').toString(),
    };
  }

  Future<List<Map<String, dynamic>>> _findProductContext(
    AiAssistantRuntimeContext runtimeContext,
    Map<String, dynamic> arguments,
  ) async {
    final products = <Map<String, dynamic>>[];
    final relatedProducts = runtimeContext.relatedData['products'];
    if (relatedProducts is List) {
      for (final item in relatedProducts.whereType<Map>()) {
        products.add(Map<String, dynamic>.from(item));
      }
    }
    final includeSelectedProducts =
        arguments['include_selected_products'] == true;
    final productId = (arguments['product_id'] ?? '').toString().trim();
    if (productId.isNotEmpty) {
      final exact = products
          .where((item) =>
              (item['id'] ?? item['product_id'] ?? '').toString() == productId)
          .toList(growable: false);
      if (exact.isNotEmpty) {
        return exact;
      }
      final catalogRows = await _productCatalogService.listProducts();
      for (final row in catalogRows) {
        if (row.id == productId) {
          return <Map<String, dynamic>>[row.toMap()];
        }
      }
    }
    if (includeSelectedProducts && products.isNotEmpty) {
      return products;
    }
    return products.take(6).toList(growable: false);
  }

  String _missingAiConfigMessage() {
    return 'Asistentul AI este pregătit, dar lipsește cheia API Anthropic. '
        'Configurează cheia în modulul AI > Setări.';
  }

  // ── Parsare structuri (neschimbate) ───────────────────────────────────────

  List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<AiRequirementRecognizedItem> _parseRequirementItems(dynamic raw) {
    if (raw is! List) return const <AiRequirementRecognizedItem>[];
    return raw
        .whereType<Map>()
        .map(
          (item) => AiRequirementRecognizedItem.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  List<AiRequirementOfferPositionDraft> _parseRequirementPositions(
    dynamic raw,
  ) {
    if (raw is! List) return const <AiRequirementOfferPositionDraft>[];
    return raw
        .whereType<Map>()
        .map(
          (item) => AiRequirementOfferPositionDraft.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  AiRequirementRecognizedItem _normalizeRequirementItem(
    AiRequirementRecognizedItem item,
  ) {
    final normalizedName = item.normalizedName.trim().isEmpty
        ? item.sourceText.trim()
        : item.normalizedName.trim();
    final normalizedUnit = item.unitOfMeasure.trim().isEmpty
        ? _defaultUnitForCategory(item.category)
        : item.unitOfMeasure.trim().toLowerCase();
    final normalizedQty = item.quantity > 0 ? item.quantity : 1.0;
    final flags = <String>{...item.flags};
    if (item.quantity <= 0) {
      flags.add('cantitate_de_confirmat');
    }
    if (item.category == AiRequirementItemCategory.unknown) {
      flags.add('categorie_neclara');
    }
    return item.copyWith(
      normalizedName: normalizedName,
      unitOfMeasure: normalizedUnit,
      quantity: normalizedQty,
      flags: flags.toList(growable: false),
      confidence: item.confidence <= 0 ? 0.45 : item.confidence,
    );
  }

  String _defaultUnitForCategory(AiRequirementItemCategory category) {
    switch (category) {
      case AiRequirementItemCategory.service:
      case AiRequirementItemCategory.labor:
        return 'serv';
      case AiRequirementItemCategory.material:
      case AiRequirementItemCategory.accessory:
      case AiRequirementItemCategory.equipment:
      case AiRequirementItemCategory.consumable:
      case AiRequirementItemCategory.unknown:
        return 'buc';
    }
  }

  Future<List<ProductCatalogRecord>> _catalogProducts(
    AiAssistantRuntimeContext runtimeContext,
  ) async {
    final relatedProducts = runtimeContext.relatedData['catalog_products'];
    if (relatedProducts is List && relatedProducts.isNotEmpty) {
      return relatedProducts
          .whereType<Map>()
          .map(
            (item) => ProductCatalogRecord.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }
    return _productCatalogService.listProducts();
  }

  Future<List<AiRequirementCatalogMatch>> _catalogMatchesFor(
    AiRequirementRecognizedItem item,
    AiAssistantRuntimeContext runtimeContext,
  ) async {
    if (item.category == AiRequirementItemCategory.service ||
        item.category == AiRequirementItemCategory.labor) {
      return const <AiRequirementCatalogMatch>[];
    }
    final products = await _catalogProducts(runtimeContext);
    final inputText = _normalizeSearchText(
      [
        item.normalizedName,
        item.brand,
        item.model,
        item.technicalSpecs,
      ].join(' '),
    );
    final inputTokens = _tokenize(inputText);
    if (inputTokens.isEmpty) {
      return const <AiRequirementCatalogMatch>[];
    }

    final scored = <MapEntry<ProductCatalogRecord, double>>[];
    for (final product in products.where((row) => row.isActive)) {
      final candidateText = _normalizeSearchText(
        [
          product.name,
          product.category,
          product.brand,
          product.model,
          product.sku,
          product.description,
          product.commercialDescription,
        ].join(' '),
      );
      final candidateTokens = _tokenize(candidateText);
      if (candidateTokens.isEmpty) continue;
      final shared = inputTokens.intersection(candidateTokens).length;
      if (shared == 0) continue;
      var score = shared / inputTokens.length;
      if (candidateText.contains(inputText) ||
          inputText.contains(candidateText)) {
        score += 0.35;
      }
      if (item.brand.trim().isNotEmpty &&
          product.brand.toLowerCase() == item.brand.trim().toLowerCase()) {
        score += 0.15;
      }
      if (item.model.trim().isNotEmpty &&
          product.model.toLowerCase() == item.model.trim().toLowerCase()) {
        score += 0.15;
      }
      scored.add(MapEntry<ProductCatalogRecord, double>(product, score));
    }

    scored.sort((left, right) => right.value.compareTo(left.value));
    return scored.take(3).map((entry) {
      final product = entry.key;
      final score = entry.value.clamp(0.0, 1.0).toDouble();
      return AiRequirementCatalogMatch(
        productId: product.id,
        productLabel: [
          product.name,
          if (product.brand.trim().isNotEmpty) product.brand.trim(),
          if (product.model.trim().isNotEmpty) product.model.trim(),
        ].join(' • '),
        score: score,
        notes: score >= 0.8
            ? 'Potrivire bună cu catalogul.'
            : 'Potrivire orientativă, necesită verificare.',
        isAlternative: scored.isNotEmpty && entry != scored.first,
      );
    }).toList(growable: false);
  }

  String _normalizeSearchText(String raw) {
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  Set<String> _tokenize(String raw) {
    return raw
        .split(RegExp(r'\s+'))
        .map((item) => item.trim())
        .where((item) => item.length >= 2)
        .toSet();
  }

  List<String> _servicePresetLabels(AiAssistantRuntimeContext runtimeContext) {
    final raw = runtimeContext.relatedData['service_presets'];
    if (raw is! List) return const <String>[];
    return raw
        .whereType<Map>()
        .map((item) => (item['label'] ?? '').toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _deriveServiceSuggestions(
    List<AiRequirementRecognizedItem> items,
    AiAssistantRuntimeContext runtimeContext,
  ) {
    final labels = _servicePresetLabels(runtimeContext);
    final suggestions = <String>{};
    final hasEquipment = items.any(
      (item) => item.category == AiRequirementItemCategory.equipment,
    );
    final hasPipeRoute = items.any(
      (item) =>
          item.normalizedName.toLowerCase().contains('traseu') ||
          item.technicalSpecs.toLowerCase().contains('traseu'),
    );
    if (hasEquipment) {
      for (final label in labels) {
        final normalized = label.toLowerCase();
        if (normalized.contains('montaj') || normalized == 'pif') {
          suggestions.add(label);
        }
        if (hasPipeRoute && normalized.contains('traseu')) {
          suggestions.add(label);
        }
      }
    }
    return suggestions.toList(growable: false);
  }

  List<String> _deriveAccessorySuggestions(
    List<AiRequirementRecognizedItem> items,
  ) {
    final suggestions = <String>{};
    final hasEquipment = items.any(
      (item) => item.category == AiRequirementItemCategory.equipment,
    );
    if (hasEquipment) {
      suggestions.add('Verifică necesar accesorii montaj și kit prindere.');
      suggestions.add('Verifică traseu, cablaj și consumabile aferente.');
    }
    return suggestions.toList(growable: false);
  }

  List<AiRequirementOfferPositionDraft> _fallbackPositionsFromItems(
    List<AiRequirementRecognizedItem> items,
  ) {
    return items.map((item) {
      final primaryMatch =
          item.catalogMatches.isEmpty ? null : item.catalogMatches.first;
      return AiRequirementOfferPositionDraft(
        id: item.id.isEmpty ? _newId('ai-pos') : item.id,
        title: primaryMatch?.productLabel.isNotEmpty == true
            ? primaryMatch!.productLabel
            : item.normalizedName,
        description: [
          item.sourceText,
          if (item.technicalSpecs.trim().isNotEmpty) item.technicalSpecs.trim(),
          if (item.notes.trim().isNotEmpty) item.notes.trim(),
        ].join(' | '),
        category: item.category,
        unitOfMeasure: item.unitOfMeasure,
        quantity: item.quantity,
        confidence: item.confidence,
        needsReview: item.needsReview || primaryMatch == null,
        sourceItemIds: <String>[item.id],
        matchedProductId: primaryMatch?.productId ?? '',
        matchedProductLabel: primaryMatch?.productLabel ?? '',
        notes: primaryMatch?.notes ?? item.notes,
        alternativeProductLabels: item.catalogMatches
            .skip(1)
            .map((match) => match.productLabel)
            .toList(growable: false),
      );
    }).toList(growable: false);
  }

  List<AiRequirementOfferPositionDraft> _finalizeRequirementPositions({
    required List<AiRequirementRecognizedItem> items,
    required List<AiRequirementOfferPositionDraft> positions,
    required List<String> suggestedServices,
    required List<String> suggestedAccessories,
  }) {
    final base =
        positions.isNotEmpty ? positions : _fallbackPositionsFromItems(items);
    final merged = <AiRequirementOfferPositionDraft>[...base];

    for (final label in suggestedServices) {
      final exists = merged.any(
        (item) => item.title.toLowerCase() == label.toLowerCase(),
      );
      if (exists) continue;
      merged.add(
        AiRequirementOfferPositionDraft(
          id: _newId('ai-pos'),
          title: label,
          description: 'Serviciu sugerat asistat pe baza cerinței clientului.',
          category: AiRequirementItemCategory.service,
          unitOfMeasure:
              label.toLowerCase().contains('traseu') ? 'ml' : 'serv',
          quantity: 1,
          confidence: 0.55,
          needsReview: true,
          notes:
              'Sugestie AI. Verifică necesitatea, cantitatea și încadrarea.',
        ),
      );
    }

    for (final label in suggestedAccessories) {
      final exists = merged.any(
        (item) => item.title.toLowerCase() == label.toLowerCase(),
      );
      if (exists) continue;
      merged.add(
        AiRequirementOfferPositionDraft(
          id: _newId('ai-pos'),
          title: label,
          description: 'Accesoriu sau necesar complementar de verificat.',
          category: AiRequirementItemCategory.accessory,
          unitOfMeasure: 'buc',
          quantity: 1,
          confidence: 0.4,
          needsReview: true,
          notes: 'Sugestie de verificare, nu confirmare automată.',
        ),
      );
    }

    return [
      for (var index = 0; index < merged.length; index++)
        merged[index].copyWith(
            id: merged[index].id.isEmpty
                ? 'ai-pos-$index'
                : merged[index].id),
    ];
  }

  AiAssistantSessionRecord _appendAssistantMessage(
    AiAssistantSessionRecord session,
    String content, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return session.copyWith(
      messages: <AiAssistantMessageRecord>[
        ...session.messages,
        AiAssistantMessageRecord(
          id: _newId('ai-msg'),
          role: AiAssistantMessageRole.assistant,
          content: content,
          createdAt: DateTime.now(),
          metadata: metadata,
        ),
      ],
      updatedAt: DateTime.now(),
    );
  }

  String _newId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }
}

class _FunctionCallPayload {
  const _FunctionCallPayload({
    required this.callId,
    required this.name,
    required this.arguments,
  });

  final String callId;
  final String name;
  final Map<String, dynamic> arguments;
}
