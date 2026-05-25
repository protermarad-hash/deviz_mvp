import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ai_assistant_models.dart';
import 'ai_assistant_service.dart';

typedef AiAssistantInsertDraftCallback = Future<bool> Function(
  String targetKey,
  String content,
);

class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({
    super.key,
    required this.title,
    required this.service,
    required this.runtimeContext,
    required this.actions,
    this.initialActionId,
    this.onInsertDraft,
  });

  final String title;
  final AiAssistantService service;
  final AiAssistantRuntimeContext runtimeContext;
  final List<AiAssistantQuickAction> actions;
  final String? initialActionId;
  final AiAssistantInsertDraftCallback? onInsertDraft;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required AiAssistantService service,
    required AiAssistantRuntimeContext runtimeContext,
    required List<AiAssistantQuickAction> actions,
    String? initialActionId,
    AiAssistantInsertDraftCallback? onInsertDraft,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        child: AiAssistantSheet(
          title: title,
          service: service,
          runtimeContext: runtimeContext,
          actions: actions,
          initialActionId: initialActionId,
          onInsertDraft: onInsertDraft,
        ),
      ),
    );
  }

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  late final TextEditingController _promptController;
  late final ScrollController _historyScrollController;
  late AiAssistantSessionRecord _session;
  late AiAssistantQuickAction _selectedAction;
  AiAssistantDraft? _draft;
  String _selectedTargetKey = '';

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController();
    _historyScrollController = ScrollController();
    _selectedAction = _resolveInitialAction();
    _selectedTargetKey =
        _resolvePreferredTargetKey(_selectedAction.defaultTargetKey);
    _session = AiAssistantSessionRecord(
      id: 'ai-session-${DateTime.now().microsecondsSinceEpoch}',
      module: widget.runtimeContext.contextType,
      entityId: widget.runtimeContext.entityId,
      entityLabel: widget.runtimeContext.entityLabel,
      userId: widget.runtimeContext.userId,
      messages: const <AiAssistantMessageRecord>[],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: AiAssistantSessionStatus.idle,
      metadata: <String, dynamic>{
        'context_label': widget.runtimeContext.contextLabel,
      },
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  AiAssistantQuickAction _resolveInitialAction() {
    if (widget.actions.isEmpty) {
      return AiAssistantQuickAction(
        id: 'ai-action-fallback',
        contextType: widget.runtimeContext.contextType,
        label: 'Asistent AI',
        description: 'Nu există acțiuni AI disponibile pentru acest context.',
        defaultPrompt: '',
        toolNames: const <String>[],
      );
    }
    final initialId = (widget.initialActionId ?? '').trim();
    for (final item in widget.actions) {
      if (item.id == initialId) {
        return item;
      }
    }
    return widget.actions.first;
  }

  List<AiAssistantInsertionTarget> get _insertionTargets =>
      widget.runtimeContext.insertionTargets;

  String _resolvePreferredTargetKey(String preferredKey) {
    final preferred = preferredKey.trim();
    if (preferred.isNotEmpty) {
      for (final target in _insertionTargets) {
        if (target.key == preferred) {
          return preferred;
        }
      }
      if (_insertionTargets.isEmpty) {
        return preferred;
      }
    }
    if (_insertionTargets.isNotEmpty) {
      return _insertionTargets.first.key;
    }
    return '';
  }

  void _scrollHistoryToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_historyScrollController.hasClients) {
        _historyScrollController.animateTo(
          _historyScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _generateDraft() async {
    if (widget.actions.isEmpty ||
        _session.status == AiAssistantSessionStatus.generating) {
      return;
    }
    setState(() {
      _draft = null;
      _session = _session.copyWith(status: AiAssistantSessionStatus.generating);
    });
    final result = await widget.service.generateDraft(
      session: _session,
      action: _selectedAction,
      runtimeContext: widget.runtimeContext,
      userPrompt: _promptController.text,
    );
    if (!mounted) return;
    setState(() {
      _session = result.session;
      _draft = result.draft;
      _selectedTargetKey = _resolvePreferredTargetKey(_draft?.targetKey ?? '');
    });
    _scrollHistoryToEnd();
  }

  Future<void> _regenerateDraft() async {
    setState(() => _draft = null);
    await _generateDraft();
  }

  Future<void> _copyDraft() async {
    final draft = _draft;
    if (draft == null || draft.content.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: draft.content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draftul AI a fost copiat.')),
    );
  }

  Future<void> _insertDraft() async {
    final draft = _draft;
    final callback = widget.onInsertDraft;
    if (draft == null || callback == null) return;
    final targetKey = _selectedTargetKey.trim().isEmpty
        ? draft.targetKey.trim()
        : _selectedTargetKey.trim();
    if (targetKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selectează câmpul în care vrei să fie inserat draftul.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmare inserare draft'),
        content: const Text(
          'Textul generat de AI va fi inserat în câmpul selectat. '
          'Verifică apoi conținutul înainte de salvare sau trimitere.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Inserează'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final saved = await callback(targetKey, draft.content);
    if (!mounted) return;
    if (!saved) return;
    setState(() {
      _draft = draft.copyWith(status: AiAssistantDraftStatus.approved);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draftul a fost inserat cu confirmare.')),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final generating = _session.status == AiAssistantSessionStatus.generating;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.smart_toy_outlined,
                      size: 22, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        widget.runtimeContext.contextLabel,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Warning banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Text generat de AI — necesită verificare umană. '
                      'Nu se trimit documente automat.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Action chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.actions.map((action) {
                  final selected = _selectedAction.id == action.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(action.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          )),
                      selected: selected,
                      avatar: selected
                          ? Icon(Icons.auto_awesome_outlined,
                              size: 14, color: cs.onPrimary)
                          : null,
                      onSelected: (_) {
                        setState(() {
                          _selectedAction = action;
                          _selectedTargetKey = _resolvePreferredTargetKey(
                              action.defaultTargetKey);
                        });
                      },
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              textCapitalization: TextCapitalization.sentences,
              controller: _promptController,
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Instrucțiuni suplimentare (opțional)',
                helperText: _selectedAction.description,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_note_outlined),
              ),
            ),
            if (_insertionTargets.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedTargetKey.trim().isEmpty
                    ? null
                    : _selectedTargetKey,
                decoration: const InputDecoration(
                  labelText: 'Inserează în câmpul',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.input_outlined),
                ),
                items: _insertionTargets
                    .map(
                      (target) => DropdownMenuItem<String>(
                        value: target.key,
                        child: Text(target.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) =>
                    setState(() => _selectedTargetKey = value ?? ''),
              ),
            ],
            const SizedBox(height: 10),
            // Action buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: generating ? null : _generateDraft,
                    icon: generating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_outlined, size: 16),
                    label: Text(generating ? 'Generează...' : 'Generează draft'),
                  ),
                  if (_draft != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: generating ? null : _regenerateDraft,
                      icon: const Icon(Icons.refresh_outlined, size: 16),
                      label: const Text('Regenerează'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _insertDraft,
                      icon: const Icon(Icons.input_outlined, size: 16),
                      label: const Text('Inserează'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _copyDraft,
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Copiază'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildHistory(theme, cs)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDraftPreview(theme, cs)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(ThemeData theme, ColorScheme cs) {
    final all = _session.messages
        .where((m) =>
            m.role == AiAssistantMessageRole.user ||
            m.role == AiAssistantMessageRole.assistant)
        .toList(growable: false);
    final messages =
        all.length > 20 ? all.sublist(all.length - 20) : all;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(Icons.history_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Istoric',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (messages.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${messages.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Expanded(
            child: messages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 28, color: cs.outlineVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Nu există interacțiuni încă.\nApasă „Generează draft" pentru a începe.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _historyScrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final item = messages[index];
                      final isUser =
                          item.role == AiAssistantMessageRole.user;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: isUser
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isUser) ...[
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.smart_toy_outlined,
                                        size: 12,
                                        color: cs.onPrimaryContainer),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? cs.primaryContainer
                                          : cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.only(
                                        topLeft:
                                            const Radius.circular(12),
                                        topRight:
                                            const Radius.circular(12),
                                        bottomLeft: Radius.circular(
                                            isUser ? 12 : 2),
                                        bottomRight: Radius.circular(
                                            isUser ? 2 : 12),
                                      ),
                                    ),
                                    child: Text(
                                      item.content,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.4,
                                        color: isUser
                                            ? cs.onPrimaryContainer
                                            : cs.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isUser) const SizedBox(width: 4),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Padding(
                              padding: EdgeInsets.only(
                                left: isUser ? 0 : 30,
                                right: isUser ? 4 : 0,
                              ),
                              child: Text(
                                _formatTime(item.createdAt),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftPreview(ThemeData theme, ColorScheme cs) {
    final draft = _draft;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: draft != null
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant,
          width: draft != null ? 1.5 : 1.0,
        ),
        boxShadow: draft != null
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(Icons.article_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Draft curent',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (draft != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(draft.status, cs),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      draft.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _statusFgColor(draft.status, cs),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(draft.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Expanded(
            child: draft == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_outlined,
                            size: 32, color: cs.outlineVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Generează un draft pentru\na vedea propunerea AI.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (draft.title.trim().isNotEmpty) ...[
                        Text(
                          draft.title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          draft.content,
                          style:
                              const TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ),
                      if (draft.disclaimer.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 13, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                draft.disclaimer,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(AiAssistantDraftStatus status, ColorScheme cs) {
    switch (status) {
      case AiAssistantDraftStatus.suggestion:
        return cs.primaryContainer;
      case AiAssistantDraftStatus.saved:
        return Colors.blue.shade50;
      case AiAssistantDraftStatus.approved:
        return Colors.green.shade50;
    }
  }

  Color _statusFgColor(AiAssistantDraftStatus status, ColorScheme cs) {
    switch (status) {
      case AiAssistantDraftStatus.suggestion:
        return cs.onPrimaryContainer;
      case AiAssistantDraftStatus.saved:
        return Colors.blue.shade800;
      case AiAssistantDraftStatus.approved:
        return Colors.green.shade800;
    }
  }
}
