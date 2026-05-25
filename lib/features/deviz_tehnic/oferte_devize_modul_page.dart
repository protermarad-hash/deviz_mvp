import 'package:flutter/material.dart';

import '../../core/repositories/app_data_repository.dart';
import '../../core/widgets/help_button.dart';
import '../../core/help_content.dart';
import '../deviz_filtre_cta/deviz_filtre_cta_page.dart';
import '../oferte/deviz_articole_baza_page.dart';
import '../oferte/oferte_page.dart';
import 'deviz_tehnic_list_page.dart';

/// Pagina wrapper cu 3 tab-uri:
/// - Tab 0 "Oferte" → modulul existent de oferte comerciale
/// - Tab 1 "Devize tehnice" → noul modul cu logică Excel (Mat/Man/Utilaj/Transport)
/// - Tab 2 "Filtre CTA" → devize pentru înlocuire filtre CTA
class OferteDevizeModulPage extends StatefulWidget {
  const OferteDevizeModulPage({
    super.key,
    required this.repository,
    this.currentUserId,
    this.currentUserEmail,
    this.currentUserName,
  });

  final AppDataRepository repository;
  final String? currentUserId;
  final String? currentUserEmail;
  final String? currentUserName;

  @override
  State<OferteDevizeModulPage> createState() => _OferteDevizeModulPageState();
}

class _OferteDevizeModulPageState extends State<OferteDevizeModulPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabIdx = _tabController.index;
    final titles = ['Oferte', 'Devize tehnice', 'Filtre CTA'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tabIdx]),
        actions: [
          if (tabIdx == 0) ...[
            IconButton(
              tooltip: 'Baza proprie de norme',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DevizArticoleBazaPage(),
                ),
              ),
              icon: const Icon(Icons.auto_fix_high_outlined),
            ),
            HelpButton(content: AppHelp.oferte),
          ] else if (tabIdx == 1) ...[
            HelpButton(content: AppHelp.oferte),
          ] else ...[
            HelpButton(content: AppHelp.devizeFiltreCta),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined), text: 'Oferte'),
            Tab(icon: Icon(Icons.calculate_outlined), text: 'Devize tehnice'),
            Tab(icon: Icon(Icons.air_outlined), text: 'Filtre CTA'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // Dezactivăm swipe ca să nu interfere cu scrollul orizontal din liste
        physics: const NeverScrollableScrollPhysics(),
        children: [
          OfertePage(
            repository: widget.repository,
            currentUserId: widget.currentUserId,
            currentUserEmail: widget.currentUserEmail,
            hideAppBar: true,
          ),
          DevizTehnicListPage(
            repository: widget.repository,
            currentUserName: widget.currentUserName ?? '',
            currentUserId: widget.currentUserId ?? '',
            hideAppBar: true,
          ),
          DevizFiltreCtaPage(
            appRepository: widget.repository,
            currentUserName: widget.currentUserName ?? '',
            hideAppBar: true,
          ),
        ],
      ),
    );
  }
}
