import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme_preset.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class DocumentTemplate {
  DocumentTemplate({
    required this.templateId,
    required this.name,
    required this.category,
    required this.icon,
    required this.hasSubject,
    String? subject,
    String? body,
  })  : subject = subject ?? '',
        body = body ?? '';

  final String templateId;
  final String name;
  final String category;
  final IconData icon;
  final bool hasSubject;
  String subject;
  String body;

  Map<String, dynamic> toMap() => {
        'templateId': templateId,
        'subject': subject,
        'body': body,
      };

  factory DocumentTemplate.fromMap(
    Map<String, dynamic> map,
    DocumentTemplate def,
  ) =>
      DocumentTemplate(
        templateId: def.templateId,
        name: def.name,
        category: def.category,
        icon: def.icon,
        hasSubject: def.hasSubject,
        subject: (map['subject'] as String?)?.isNotEmpty == true
            ? map['subject'] as String
            : def.subject,
        body: (map['body'] as String?)?.isNotEmpty == true
            ? map['body'] as String
            : def.body,
      );
}

// ── Definiții șabloane implicite ──────────────────────────────────────────────

final List<DocumentTemplate> _kTemplateDefaults = [
  DocumentTemplate(
    templateId: 'email_oferta',
    name: 'Email ofertă',
    category: 'Email',
    icon: Icons.request_quote_outlined,
    hasSubject: true,
    subject: 'Ofertă comercială - {numar_oferta}',
    body: 'Stimate {client_nume},\n\n'
        'Vă transmitem alăturat oferta noastră comercială nr. {numar_oferta} '
        'din data de {data_oferta}.\n\n'
        'Valoarea totală a ofertei este de {valoare_totala} {moneda}.\n\n'
        'Vă stăm la dispoziție pentru orice informații suplimentare.\n\n'
        'Cu stimă,\n{firma_nume}\n{firma_telefon}\n{firma_email}',
  ),
  DocumentTemplate(
    templateId: 'email_programare',
    name: 'Email programare',
    category: 'Email',
    icon: Icons.calendar_month_outlined,
    hasSubject: true,
    subject: 'Confirmare programare - {data_programare}',
    body: 'Stimate {client_nume},\n\n'
        'Confirmăm programarea tehnician pentru data de {data_programare}, '
        'ora {ora_programare}, la adresa: {adresa_programare}.\n\n'
        'Tehnicianul alocat: {tehnician_nume}.\n\n'
        'Vă rugăm să ne contactați dacă doriți să modificați programarea.\n\n'
        'Cu stimă,\n{firma_nume}\n{firma_telefon}',
  ),
  DocumentTemplate(
    templateId: 'email_reclamatie',
    name: 'Email reclamație',
    category: 'Email',
    icon: Icons.report_problem_outlined,
    hasSubject: true,
    subject: 'Confirmare înregistrare reclamație - {numar_reclamatie}',
    body: 'Stimate {client_nume},\n\n'
        'Am înregistrat reclamația dumneavoastră cu numărul {numar_reclamatie} '
        'din data de {data_reclamatie}.\n\n'
        'Vom analiza solicitarea și vă vom contacta în cel mai scurt timp.\n\n'
        'Cu stimă,\n{firma_nume}\n{firma_telefon}\n{firma_email}',
  ),
  DocumentTemplate(
    templateId: 'email_certificat_garantie',
    name: 'Email certificat garanție',
    category: 'Email',
    icon: Icons.verified_user_outlined,
    hasSubject: true,
    subject: 'Certificat de garanție - {numar_certificat}',
    body: 'Stimate {client_nume},\n\n'
        'Vă transmitem certificatul de garanție nr. {numar_certificat} '
        'pentru produsele/serviciile achiziționate.\n\n'
        'Perioada de garanție: {perioada_garantie} luni.\n\n'
        'Cu stimă,\n{firma_nume}',
  ),
  DocumentTemplate(
    templateId: 'semn_email',
    name: 'Semnătură email',
    category: 'Email',
    icon: Icons.draw_outlined,
    hasSubject: false,
    body: '{firma_nume}\n'
        'Tel: {firma_telefon} | Email: {firma_email}\n'
        'Web: {firma_website}\n'
        'Adresă: {firma_adresa}',
  ),
  DocumentTemplate(
    templateId: 'antet_document',
    name: 'Antet document',
    category: 'Document',
    icon: Icons.article_outlined,
    hasSubject: false,
    body: '{firma_nume}\n'
        'CUI: {firma_cui} | Reg. Com.: {firma_reg_com}\n'
        'Sediu: {firma_adresa}, {firma_oras}, {firma_judet}\n'
        'Tel: {firma_telefon} | Email: {firma_email}\n'
        'Bancă: {firma_banca} | IBAN: {firma_iban}',
  ),
  DocumentTemplate(
    templateId: 'subsol_document',
    name: 'Subsol document',
    category: 'Document',
    icon: Icons.horizontal_rule_outlined,
    hasSubject: false,
    body: 'Document generat de {firma_nume} | {firma_website} | '
        'Tel: {firma_telefon}',
  ),
  DocumentTemplate(
    templateId: 'pv_interventie',
    name: 'Constatări PV intervenție',
    category: 'Document',
    icon: Icons.fact_check_outlined,
    hasSubject: false,
    body: 'S-a efectuat intervenția tehnică la adresa clientului.\n'
        'S-au constatat următoarele: {constatari}\n'
        'S-au efectuat lucrările: {lucrari_efectuate}\n'
        'Echipamente utilizate: {echipamente}\n'
        'Observații: {observatii}',
  ),
  DocumentTemplate(
    templateId: 'certificat_garantie_text',
    name: 'Text certificat garanție',
    category: 'Document',
    icon: Icons.workspace_premium_outlined,
    hasSubject: false,
    body: 'Produsele/serviciile furnizate beneficiază de o garanție de '
        '{perioada_garantie} luni de la data livrării/punerii în funcțiune.\n\n'
        'Garanția acoperă defectele de fabricație și de instalare. '
        'Nu sunt acoperite defecțiunile cauzate de utilizarea incorectă sau '
        'de intervenții neautorizate.',
  ),
];

// ── Repository local ──────────────────────────────────────────────────────────

class _TemplateStore {
  static const _key = 'app_document_templates_v1';

  Future<List<DocumentTemplate>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return List.from(_kTemplateDefaults);
    try {
      final list = jsonDecode(raw) as List;
      final saved = {
        for (final item in list.whereType<Map>())
          (item['templateId'] as String? ?? ''): Map<String, dynamic>.from(item)
      };
      return _kTemplateDefaults.map((def) {
        final data = saved[def.templateId];
        return data != null ? DocumentTemplate.fromMap(data, def) : def;
      }).toList();
    } catch (_) {
      return List.from(_kTemplateDefaults);
    }
  }

  Future<void> save(List<DocumentTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(templates.map((t) => t.toMap()).toList()),
    );
  }
}

// ── Pagina ────────────────────────────────────────────────────────────────────

class TemplateSettingsPage extends StatefulWidget {
  const TemplateSettingsPage({super.key});

  @override
  State<TemplateSettingsPage> createState() => _TemplateSettingsPageState();
}

class _TemplateSettingsPageState extends State<TemplateSettingsPage> {
  final _store = _TemplateStore();
  List<DocumentTemplate> _templates = [];
  bool _loading = true;
  String _filterCategory = 'Toate';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final templates = await _store.load();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  List<String> get _categories {
    final cats = {'Toate', ..._templates.map((t) => t.category)};
    return cats.toList();
  }

  List<DocumentTemplate> get _filtered => _filterCategory == 'Toate'
      ? _templates
      : _templates.where((t) => t.category == _filterCategory).toList();

  Future<void> _editTemplate(DocumentTemplate template) async {
    final subjectCtrl =
        TextEditingController(text: template.subject);
    final bodyCtrl = TextEditingController(text: template.body);
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => _TemplateEditorDialog(
          template: template,
          subjectController: subjectCtrl,
          bodyController: bodyCtrl,
        ),
      );
      if (saved != true || !mounted) return;
      setState(() {
        template.subject = subjectCtrl.text;
        template.body = bodyCtrl.text;
      });
      await _store.save(_templates);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Șablon „${template.name}" salvat.')),
      );
    } finally {
      subjectCtrl.dispose();
      bodyCtrl.dispose();
    }
  }

  Future<void> _resetTemplate(DocumentTemplate template) async {
    final def = _kTemplateDefaults.firstWhere(
      (d) => d.templateId == template.templateId,
    );
    setState(() {
      template.subject = def.subject;
      template.body = def.body;
    });
    await _store.save(_templates);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('„${template.name}" resetat la implicit.')),
    );
  }

  Widget _buildHeroHeader(ColorScheme cs) {
    final brand = Theme.of(context).extension<AppBrandTheme>();
    final emailCount = _templates.where((t) => t.category == 'Email').length;
    final docCount = _templates.length - emailCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: brand?.shellHeaderGradient ??
            LinearGradient(
              colors: [cs.secondaryContainer, cs.tertiaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brand?.shellGlow ?? cs.secondary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -16,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.onSecondaryContainer.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: cs.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.description_outlined,
                        size: 26, color: cs.secondary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Șabloane documente',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: cs.onSecondaryContainer,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Variabilele în {acolade} sunt înlocuite automat',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                cs.onSecondaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatChip(
                    '$emailCount emailuri',
                    Icons.email_outlined,
                    cs.surface,
                    cs.secondary,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    '$docCount documente',
                    Icons.article_outlined,
                    cs.surface,
                    cs.tertiary,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Șabloane documente'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeroHeader(cs),
                // Filtre categorie
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories
                          .map(
                            (cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(cat),
                                selected: _filterCategory == cat,
                                onSelected: (_) =>
                                    setState(() => _filterCategory = cat),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _TemplateCard(
                      template: _filtered[i],
                      colorScheme: cs,
                      onEdit: () => _editTemplate(_filtered[i]),
                      onReset: () => _resetTemplate(_filtered[i]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Card șablon ───────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.colorScheme,
    required this.onEdit,
    required this.onReset,
  });

  final DocumentTemplate template;
  final ColorScheme colorScheme;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  Color _categoryColor(ColorScheme cs) {
    switch (template.category) {
      case 'Email':
        return cs.primary;
      case 'Document':
        return cs.tertiary;
      default:
        return cs.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = template.body.isEmpty
        ? '(necompletat)'
        : template.body.substring(
            0,
            template.body.length > 80 ? 80 : template.body.length,
          ) +
            (template.body.length > 80 ? '…' : '');

    final cs = colorScheme;
    final catColor = _categoryColor(cs);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [catColor, catColor.withValues(alpha: 0.4)],
                ),
              ),
            ),
            InkWell(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        template.icon,
                        size: 20,
                        color: catColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                template.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  template.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: catColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (template.hasSubject &&
                              template.subject.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Subiect: ${template.subject}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.primary,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            preview,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 18, color: cs.onSurfaceVariant),
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'reset') onReset();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editează')),
                        PopupMenuItem(
                            value: 'reset', child: Text('Resetare implicit')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog editor ─────────────────────────────────────────────────────────────

class _TemplateEditorDialog extends StatelessWidget {
  const _TemplateEditorDialog({
    required this.template,
    required this.subjectController,
    required this.bodyController,
  });

  final DocumentTemplate template;
  final TextEditingController subjectController;
  final TextEditingController bodyController;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(template.name),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Variabile disponibile: {firma_nume}, {firma_telefon}, '
                '{firma_email}, {client_nume}, {data}, {numar_document}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              if (template.hasSubject) ...[
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subiect email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: bodyController,
                decoration: InputDecoration(
                  labelText:
                      template.hasSubject ? 'Conținut email' : 'Conținut',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 12,
                minLines: 6,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}
