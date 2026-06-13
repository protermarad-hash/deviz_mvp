import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../ai_config_store.dart';
import 'help_models.dart';
import 'help_repository.dart';

/// Buton ajutor cu sistem Firestore + AI Help contextual.
/// Înlocuiește IconButton-urile inline cu showDialog.
/// Nu înlocuiește HelpButton(content: AppHelp.X) existent.
class HelpModuleButton extends StatelessWidget {
  const HelpModuleButton({required this.moduleId, super.key});

  final String moduleId;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.help_outline),
        tooltip: 'Ajutor',
        onPressed: () => _showHelp(context),
      );

  void _showHelp(BuildContext context) {
    final content = HelpRepository.instance.getForModule(moduleId);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HelpModuleSheet(moduleId: moduleId, content: content),
    );
  }
}

class HelpModuleSheet extends StatefulWidget {
  const HelpModuleSheet({required this.moduleId, this.content, super.key});

  final String moduleId;
  final HelpModule? content;

  @override
  State<HelpModuleSheet> createState() => _HelpModuleSheetState();
}

class _HelpModuleSheetState extends State<HelpModuleSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _questionCtrl = TextEditingController();
  String? _aiResponse;
  bool _isLoadingAi = false;

  @override
  void initState() {
    super.initState();
    final hasTabs = widget.content != null;
    _tabController = TabController(length: hasTabs ? 4 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final hasTabs = content != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Icon(Icons.help_outline, color: Color(0xFFC62828)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  content?.titlu ?? 'Ajutor',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              if (content != null)
                Text('v${content.versiune}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFC62828),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFC62828),
            tabs: [
              if (hasTabs) ...[
                const Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Info'),
                const Tab(icon: Icon(Icons.format_list_numbered, size: 18), text: 'Ghid'),
                const Tab(icon: Icon(Icons.quiz_outlined, size: 18), text: 'FAQ'),
              ],
              const Tab(icon: Icon(Icons.smart_toy_outlined, size: 18), text: 'AI Help'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                if (hasTabs) ...[
                  _buildInfoTab(content, scrollCtrl),
                  _buildGuideTab(content, scrollCtrl),
                  _buildFaqTab(content, scrollCtrl),
                ],
                _buildAiTab(scrollCtrl),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildInfoTab(HelpModule c, ScrollController ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(16),
        children: [
          Text(c.descriere, style: const TextStyle(fontSize: 15, height: 1.5)),
          if (c.sfaturi.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('💡 Sfaturi utile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...c.sfaturi.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('• ',
                        style: TextStyle(
                            color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
                    Expanded(child: Text(s)),
                  ]),
                )),
          ],
        ],
      );

  Widget _buildGuideTab(HelpModule c, ScrollController ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(16),
        children: c.pasi
            .map((pas) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFC62828),
                      radius: 16,
                      child: Text('${pas.nr}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(pas.titlu,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(pas.descriere),
                  ),
                ))
            .toList(),
      );

  Widget _buildFaqTab(HelpModule c, ScrollController ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(16),
        children: c.faq
            .map((faq) => ExpansionTile(
                  title: Text(faq.intrebare,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                  iconColor: const Color(0xFFC62828),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(faq.raspuns,
                          style: const TextStyle(height: 1.5)),
                    )
                  ],
                ))
            .toList(),
      );

  Widget _buildAiTab(ScrollController ctrl) => Column(children: [
        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              if (_aiResponse == null && !_isLoadingAi)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Icon(Icons.smart_toy_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Pune orice întrebare despre\n'
                        '${widget.content?.titlu ?? "această funcționalitate"}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (!AiConfigStore.isConfigured) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Text(
                            'AI Help necesită cheia API Claude configurată în Setări → AI.',
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (_isLoadingAi)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Color(0xFFC62828)),
                  ),
                ),
              if (_aiResponse != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.smart_toy_outlined, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text('Răspuns AI',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                              fontSize: 12)),
                    ]),
                    const SizedBox(height: 8),
                    Text(_aiResponse!, style: const TextStyle(height: 1.5)),
                  ]),
                ),
            ],
          ),
        ),
        // Input întrebare
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _questionCtrl,
                decoration: InputDecoration(
                  hintText: 'Pune o întrebare...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _askAi(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'help_send_${widget.moduleId}',
              onPressed: _isLoadingAi ? null : _askAi,
              backgroundColor: const Color(0xFFC62828),
              child: _isLoadingAi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ]),
        ),
      ]);

  Future<void> _askAi() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) return;
    if (!AiConfigStore.isConfigured) {
      setState(() {
        _aiResponse =
            'AI Help necesită cheia API Claude. Configurează din Setări → AI Assistant.';
      });
      return;
    }
    setState(() {
      _isLoadingAi = true;
      _aiResponse = null;
    });
    _questionCtrl.clear();
    try {
      final content = widget.content;
      final moduleCtx = content != null
          ? 'Modulul: ${content.titlu}\nDescriere: ${content.descriere}\n'
              'Pași: ${content.pasi.map((p) => "${p.nr}. ${p.titlu}: ${p.descriere}").join("; ")}'
          : 'Aplicația ProVentaris — ERP pentru firma HVAC PRO TERM SRL Arad.';
      final response = await _callClaudeApi(question, moduleCtx);
      if (mounted) {
        setState(() {
          _aiResponse = response;
          _isLoadingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse = 'Nu am putut genera un răspuns. Verifică conexiunea.';
          _isLoadingAi = false;
        });
      }
    }
  }

  Future<String> _callClaudeApi(String question, String moduleContext) async {
    final response = await http
        .post(
          Uri.parse(AiConfigStore.anthropicEndpoint),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'x-api-key': AiConfigStore.apiKey,
            'anthropic-version': AiConfigStore.anthropicVersion,
          },
          body: jsonEncode(<String, dynamic>{
            'model': 'claude-haiku-4-5-20251001',
            'max_tokens': 500,
            'system': 'Ești asistentul aplicației ProVentaris, sistem ERP pentru firma HVAC PRO TERM SRL din Arad. '
                'Răspunzi NUMAI în română, concis și practic (maxim 150 cuvinte). '
                'Context modul curent: $moduleContext',
            'messages': [
              {'role': 'user', 'content': question}
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return (data['content'] as List?)
              ?.whereType<Map>()
              .firstWhere((e) => e['type'] == 'text',
                  orElse: () => <String, dynamic>{})['text']
              ?.toString() ??
          'Fără răspuns.';
    }
    throw Exception('API error ${response.statusCode}');
  }
}
