import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ai_config_store.dart';
import '../../core/app_theme_preset.dart';
import 'claude_chat_service.dart';
import '../../core/widgets/help_button.dart';
import '../../core/help_content.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final ClaudeChatService _claude = ClaudeChatService();
  final List<_ChatMsg> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ClaudeMessage> _history = [];

  bool _loading = false;
  bool _showSettings = false;
  bool _configured = false;

  // Setări
  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _modelCtrl = TextEditingController();
  bool _obscureKey = true;
  String? _settingsError;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    await AiConfigStore.load();
    if (!mounted) return;
    setState(() {
      _configured = AiConfigStore.isConfigured;
      _apiKeyCtrl.text = AiConfigStore.apiKey;
      _modelCtrl.text = AiConfigStore.model;
      _showSettings = !_configured;
    });
  }

  Future<void> _saveSettings() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _settingsError = 'Cheia API nu poate fi goală.');
      return;
    }
    await AiConfigStore.saveApiKey(key);
    final model = _modelCtrl.text.trim();
    if (model.isNotEmpty) {
      await AiConfigStore.saveModel(model);
    }
    if (!mounted) return;
    setState(() {
      _configured = true;
      _showSettings = false;
      _settingsError = null;
    });
  }

  Future<void> _clearKey() async {
    await AiConfigStore.clearApiKey();
    if (!mounted) return;
    setState(() {
      _configured = false;
      _showSettings = true;
      _apiKeyCtrl.clear();
      _messages.clear();
      _history.clear();
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    _input.clear();

    setState(() {
      _messages.add(_ChatMsg(role: 'user', text: text));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final reply = await _claude.sendMessage(
        history: List.unmodifiable(_history),
        userMessage: text,
      );
      _history.add(ClaudeMessage(role: 'user', content: text));
      _history.add(ClaudeMessage(role: 'assistant', content: reply));
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(role: 'assistant', text: reply));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMsg(
            role: 'error',
            text: 'Eroare: ${error.toString().replaceAll('Exception: ', '')}',
          ),
        );
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brand = Theme.of(context).extension<AppBrandTheme>();

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: brand == null
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(gradient: brand.shellHeaderGradient),
              ),
        title: const Text('Asistent AI Claude'),
        actions: [
          if (_configured && !_showSettings)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Setări API',
              onPressed: () => setState(() => _showSettings = true),
            ),
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Șterge conversație',
              onPressed: () => setState(() {
                _messages.clear();
                _history.clear();
              }),
            ),
          HelpButton(content: AppHelp.aiAssistant),
        ],
      ),
      body: Column(
        children: [
          if (_showSettings) _buildSettingsPanel(cs) else _buildChatPanel(cs),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel(ColorScheme cs) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: cs.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configurare Asistent AI Claude',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Introdu cheia API Anthropic pentru a activa asistentul.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Info box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Cum obții cheia API',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Mergi la console.anthropic.com\n'
                    '2. Creează un cont sau autentifică-te\n'
                    '3. Navighează la API Keys → Create Key\n'
                    '4. Copiază cheia și lipește-o mai jos',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // API Key field
            Text(
              'Cheie API Anthropic',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              textCapitalization: TextCapitalization.sentences,
              controller: _apiKeyCtrl,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: 'sk-ant-...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Model field
            Text(
              'Model Claude (opțional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              textCapitalization: TextCapitalization.sentences,
              controller: _modelCtrl,
              decoration: const InputDecoration(
                hintText: 'claude-sonnet-4-6',
                border: OutlineInputBorder(),
                helperText:
                    'Lasă gol pentru modelul implicit: claude-sonnet-4-6',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                'claude-opus-4-7',
                'claude-sonnet-4-6',
                'claude-haiku-4-5-20251001',
              ].map((m) {
                return ActionChip(
                  label: Text(m, style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _modelCtrl.text = m),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Error
            if ((_settingsError ?? '').isNotEmpty) ...[
              Text(
                _settingsError!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
            ],

            // Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.check),
                    label: const Text('Salvează și activează'),
                  ),
                ),
                if (_configured) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _showSettings = false),
                    child: const Text('Anulează'),
                  ),
                ],
              ],
            ),
            if (_configured) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _clearKey,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Șterge cheia API',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],

            // Security note
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_outlined,
                      color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cheia API este stocată local pe acest dispozitiv și nu este '
                      'trimisă nicăieri altundeva decât direct la Anthropic. '
                      'Nu o distribui altor persoane.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel(ColorScheme cs) {
    return Expanded(
      child: Column(
        children: [
          // Mesaje
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(cs)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (_loading && i == _messages.length) {
                        return _buildTypingIndicator(cs);
                      }
                      return _buildBubble(_messages[i], cs);
                    },
                  ),
          ),

          // Input
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                  top: BorderSide(color: cs.outlineVariant, width: 0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _input,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    enabled: !_loading,
                    decoration: InputDecoration(
                      hintText: 'Scrie un mesaj...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            BorderSide(color: cs.outlineVariant),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _send,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_outlined,
              size: 56, color: cs.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Asistent AI Claude',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Modelul activ: ${AiConfigStore.model}',
            style:
                TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              'Redactează o ofertă',
              'Calculează TVA',
              'Explică un termen tehnic',
              'Ajutor cu un document',
            ].map((hint) {
              return ActionChip(
                label: Text(hint, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  _input.text = hint;
                  _send();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMsg msg, ColorScheme cs) {
    final isUser = msg.role == 'user';
    final isError = msg.role == 'error';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  isError ? Colors.red.shade100 : cs.primaryContainer,
              child: Icon(
                isError
                    ? Icons.error_outline
                    : Icons.smart_toy_outlined,
                size: 16,
                color: isError ? Colors.red : cs.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copiat în clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? cs.primary
                      : isError
                          ? Colors.red.shade50
                          : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: isError
                      ? Border.all(color: Colors.red.shade200)
                      : null,
                ),
                child: SelectableText(
                  msg.text,
                  style: TextStyle(
                    color: isUser
                        ? cs.onPrimary
                        : isError
                            ? Colors.red.shade800
                            : cs.onSurface,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.smart_toy_outlined,
                size: 16, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 200),
                const SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMsg {
  const _ChatMsg({required this.role, required this.text});
  final String role;
  final String text;
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
