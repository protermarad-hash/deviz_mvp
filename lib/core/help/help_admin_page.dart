import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'help_models.dart';
import 'help_repository.dart';

/// Pagină admin pentru editarea conținutului Help din Firestore.
/// Vizibilă NUMAI pentru rolul admin.
class HelpAdminPage extends StatefulWidget {
  const HelpAdminPage({super.key});

  @override
  State<HelpAdminPage> createState() => _HelpAdminPageState();
}

class _HelpAdminPageState extends State<HelpAdminPage> {
  final _fmt = DateFormat('dd.MM.yyyy HH:mm');
  bool _saving = false;

  List<HelpModule> get _modules {
    final repo = HelpRepository.instance;
    final known = [
      'programari', 'hr', 'reclamatii', 'financiar_parteneri',
      'crm', 'stoc', 'echipamente', 'oferte', 'agfr', 'deviz_tehnic',
    ];
    return known
        .map((id) => repo.getForModule(id))
        .whereType<HelpModule>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionează conținut Help'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reîncarcă din Firestore',
            onPressed: () => HelpRepository.instance.initialize().then((_) {
              if (mounted) setState(() {});
            }),
          ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _modules.length,
              itemBuilder: (_, i) {
                final m = _modules[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.help_outline, color: Color(0xFFC62828)),
                    title: Text(m.titlu,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'v${m.versiune} · Actualizat: ${_fmt.format(m.updatedAt)}\n'
                      '${m.pasi.length} pași · ${m.faq.length} FAQ · ${m.sfaturi.length} sfaturi',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editModule(m),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editModule(HelpModule module) async {
    final descriereCtrl = TextEditingController(text: module.descriere);
    final sfaturiCtrl = TextEditingController(text: module.sfaturi.join('\n'));

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editează: ${module.titlu}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(children: [
              TextFormField(
                controller: descriereCtrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descriere modul',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sfaturiCtrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Sfaturi (câte un sfat pe linie)',
                  alignLabelWithHint: true,
                ),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Renunță')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvează')),
        ],
      ),
    );

    if (saved != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = HelpModule(
        moduleId: module.moduleId,
        titlu: module.titlu,
        descriere: descriereCtrl.text.trim(),
        pasi: module.pasi,
        faq: module.faq,
        sfaturi: sfaturiCtrl.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        versiune: _bumpVersion(module.versiune),
        updatedAt: DateTime.now(),
      );
      await HelpRepository.instance.updateContent(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conținut Help actualizat în Firestore.')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la salvare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
      descriereCtrl.dispose();
      sfaturiCtrl.dispose();
    }
  }

  String _bumpVersion(String ver) {
    final parts = ver.split('.');
    if (parts.length >= 2) {
      final minor = (int.tryParse(parts.last) ?? 0) + 1;
      return '${parts.first}.$minor';
    }
    return '$ver.1';
  }
}
