import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'help_models.dart';

class HelpRepository {
  HelpRepository._();
  static final instance = HelpRepository._();

  final Map<String, HelpModule> _cache = {};
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('help_content');

  Future<void> initialize() async {
    try {
      final snapshot = await _col.get();
      for (final doc in snapshot.docs) {
        _cache[doc.id] = HelpModule.fromMap({...doc.data(), 'module_id': doc.id});
      }
      debugPrint('[Help] Încărcat ${_cache.length} module din Firestore');
    } catch (e) {
      debugPrint('[Help] Firestore indisponibil, fallback la conținut implicit: $e');
      _loadDefaultContent();
    }
  }

  HelpModule? getForModule(String moduleId) =>
      _cache[moduleId] ?? _defaultContent.where((m) => m.moduleId == moduleId).firstOrNull;

  Future<void> updateContent(HelpModule content) async {
    _cache[content.moduleId] = content;
    await _col.doc(content.moduleId).set(content.toMap());
  }

  Future<void> seedIfEmpty() async {
    try {
      final snapshot = await _col.limit(1).get();
      if (snapshot.docs.isEmpty) {
        for (final m in _defaultContent) {
          await _col.doc(m.moduleId).set(m.toMap());
        }
        debugPrint('[Help] Seed Firestore: ${_defaultContent.length} module');
      }
    } catch (e) {
      debugPrint('[Help] Seed eșuat (offline): $e');
    }
  }

  void _loadDefaultContent() {
    for (final m in _defaultContent) {
      _cache[m.moduleId] = m;
    }
  }

  static final List<HelpModule> _defaultContent = [
    HelpModule(
      moduleId: 'programari',
      titlu: 'Modul Programări',
      descriere: 'Gestionează toate programările de service, montaj și igienizare. '
          'Vizualizează în calendar, adaugă echipe și urmărești statusul.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Adaugă programare', descriere: 'Apasă butonul + din colțul dreapta-jos sau apăsare lungă în calendar.', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Completează datele', descriere: 'Titlu, client, dată/oră, echipă, locație și detalii intervenție.', icon: 'edit'),
        HelpModuleStep(nr: 3, titlu: 'Salvează', descriere: 'Apasă Salvează — apare imediat în calendar și listă.', icon: 'save'),
        HelpModuleStep(nr: 4, titlu: 'Actualizează status', descriere: 'La finalizare schimbă statusul în Finalizată.', icon: 'check_circle'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Cum schimb echipa?', raspuns: 'Deschide programarea → tab Execuție → modifică câmpul Echipă.'),
        HelpModuleFaq(intrebare: 'Cum adaug materiale?', raspuns: 'Tab Execuție → secțiunea Materiale → selectează kitul sau adaugă manual.'),
        HelpModuleFaq(intrebare: 'Cum trimit confirmare clientului?', raspuns: 'Apasă butonul WhatsApp de lângă numărul de telefon.'),
      ],
      sfaturi: [
        'Swipe stânga/dreapta în calendar pentru navigare între săptămâni',
        'Programările cu border galben au materiale atașate',
        'Stocul se scade automat la salvarea materialelor',
      ],
      versiune: '1.1',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'hr',
      titlu: 'HR & Salarizare',
      descriere: 'Gestionează angajații, calculează salarii conform OUG 89/2025 și generează fluturași PDF.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Adaugă angajat', descriere: 'Tab Angajați → + → completează datele personale și contractul.', icon: 'person_add'),
        HelpModuleStep(nr: 2, titlu: 'Completează pontajul', descriere: 'Tab Pontaj → selectează luna → marchează orele zilnice.', icon: 'calendar_month'),
        HelpModuleStep(nr: 3, titlu: 'Verifică calculul', descriere: 'Angajat → tab Calculator → valorile se completează automat.', icon: 'calculate'),
        HelpModuleStep(nr: 4, titlu: 'Generează fluturașul', descriere: 'Buton Generează fluturașul → PDF gata pentru semnare.', icon: 'picture_as_pdf'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'De ce salariul diferă față de contabilă?', raspuns: 'Verifică: brut corect, nr. dependenți, nr. zile tichete și că TM e introdus ca valoare netă.'),
        HelpModuleFaq(intrebare: 'Cum adaug o poprire?', raspuns: 'Angajat → tab Popriri → + Adaugă executor → completează datoria și procentul.'),
        HelpModuleFaq(intrebare: 'Cum înregistrez un avans?', raspuns: 'Tab Fluturași → angajat → buton 💰 Avans → sumă și dată.'),
      ],
      sfaturi: [
        'Tichetele de masă se introduc ca valoare netă (ce primește angajatul)',
        'CASS se calculează NUMAI pe salariu brut (TM exclus)',
        'Deducere personală: 600 RON bază, prag 4050 RON, plafon 7000 RON',
      ],
      versiune: '1.1',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'reclamatii',
      titlu: 'Reclamații',
      descriere: 'Gestionează reclamațiile clienților, emite procese verbale și urmărești intervențiile.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Adaugă reclamație', descriere: 'Buton + → completează clientul, echipamentul și descrierea problemei.', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Adaugă intervenție', descriere: 'Tab Intervenții → + → documentează constatările tehnice.', icon: 'build'),
        HelpModuleStep(nr: 3, titlu: 'Emite PV', descriere: 'Tab PV-uri → + PV Nou → completează și generează PDF.', icon: 'description'),
        HelpModuleStep(nr: 4, titlu: 'Atașează poze', descriere: 'Tab PV → secțiunea Poze → Fă poza sau Alege din galerie.', icon: 'photo_camera'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Pot emite mai multe PV-uri?', raspuns: 'Da. Fiecare intervenție poate avea propriul PV, înlănțuite automat.'),
        HelpModuleFaq(intrebare: 'Pozele nu se încarcă?', raspuns: 'Deconectează-te și reconectează-te pentru a reîmprospăta sesiunea.'),
      ],
      sfaturi: [
        'PV-ul include automat pozele atașate ca Anexă Foto',
        'La revenire, PV-ul nou referențiază automat PV-ul anterior',
      ],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'financiar_parteneri',
      titlu: 'Financiar Parteneri',
      descriere: 'Urmărești încasările și plățile cu partenerii executanți. De încasat = sume neîncasate minus plăți primite.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Înregistrează încasare', descriere: 'Buton verde Încasează → suma primită de la partener → Salvează.', icon: 'arrow_downward'),
        HelpModuleStep(nr: 2, titlu: 'Înregistrează plată', descriere: 'Buton roșu Plătește → suma plătită partenerului → Salvează.', icon: 'arrow_upward'),
        HelpModuleStep(nr: 3, titlu: 'Recalculează soldul', descriere: 'Apasă ↻ din toolbar pentru a forța recalculul.', icon: 'refresh'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'De ce soldul nu e actualizat?', raspuns: 'Apasă ↻ (recalculează) din toolbar.'),
        HelpModuleFaq(intrebare: 'Ce e bannerul portocaliu?', raspuns: 'Costul materialelor/kiturilor — informativ, nu inclus în sold.'),
      ],
      sfaturi: ['Înregistrează plățile cu butonul Încasează pentru sold corect'],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'crm',
      titlu: 'CRM — Pipeline Vânzări',
      descriere: 'Urmărești lead-urile de la primul contact până la lucrarea finalizată.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Adaugă lead', descriere: 'Buton + → completează clientul, tipul lucrării și valoarea estimată.', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Avansează în pipeline', descriere: 'Modifică stadiul: Lead → Calificat → Ofertă → Câștigat.', icon: 'trending_up'),
        HelpModuleStep(nr: 3, titlu: 'Trimite ofertă', descriere: 'Lead → Generează ofertă → oferta se creează automat în Oferte.', icon: 'send'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Cum văd rata de conversie?', raspuns: 'Tab Statistici → Rată conversie = % lead-uri câștigate.'),
        HelpModuleFaq(intrebare: 'Cum setez reminder?', raspuns: 'Editează lead → câmpul Data acțiunii → primești alertă la deschidere app.'),
      ],
      sfaturi: [
        'Lead-urile cu acțiune depășită apar cu text roșu',
        'Integrare automată cu Oferte la trimitere/acceptare ofertă',
      ],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'stoc',
      titlu: 'Stoc Materiale',
      descriere: 'Gestionează stocul de materiale și urmărești consumul automat din programări.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Adaugă produs', descriere: 'Buton + → denumire, cod, cantitate inițială, prag minim.', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Înregistrează intrare', descriere: 'Tap pe produs → buton + Intrare → cantitate și furnizor.', icon: 'add_circle'),
        HelpModuleStep(nr: 3, titlu: 'Urmărește stocul critic', descriere: 'Tab Stoc critic → produsele sub pragul minim.', icon: 'warning'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Stocul se scade automat?', raspuns: 'Da, la salvarea materialelor pe o programare stocul scade automat.'),
        HelpModuleFaq(intrebare: 'Cum generez lista de comandă?', raspuns: 'Tab Comandă → produse sub prag → Generează listă PDF.'),
      ],
      sfaturi: ['Setează praguri realiste pentru alerte la timp'],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'echipamente',
      titlu: 'Echipamente Instalate',
      descriere: 'Evidența echipamentelor HVAC instalate la clienți, cu garanție și referințe de service.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Adaugă echipament', descriere: 'Buton + → client, marcă, model, serie, agent frigorific.', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Asociere garanție', descriere: 'Echipament → buton Certificat garanție pentru a genera documentul.', icon: 'verified_outlined'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Cum văd echipamentele cu garanție expirată?', raspuns: 'Tab Garanție expirată — sau cardul de alertă din Dashboard.'),
      ],
      sfaturi: ['Asocierea cu programările și reclamațiile se face automat prin echipamentul selectat'],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'oferte',
      titlu: 'Oferte Comerciale',
      descriere: 'Creează, trimite și urmărești ofertele comerciale. Integrare cu CRM și Lucrări.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Ofertă nouă', descriere: 'Buton + → completează client, titlu, articole.', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Generează PDF', descriere: 'Buton PDF → alege șablonul → salvează sau trimite pe email.', icon: 'picture_as_pdf'),
        HelpModuleStep(nr: 3, titlu: 'Schimbă statusul', descriere: 'Trimis → Acceptat/Respins. La Acceptat se poate converti în Lucrare.', icon: 'send'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Cum convertesc oferta în lucrare?', raspuns: 'Ofertă acceptată → buton Convertește în Lucrare din meniu ⋮.'),
      ],
      sfaturi: ['GWP și CO₂ echivalent se calculează automat pentru ofertele AGFR/F-Gas'],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'agfr',
      titlu: 'AGFR / F-Gas',
      descriere: 'Registrul F-Gas conform Reg. UE 517/2014. Înregistrează echipamentele, intervențiile și rapoartele de etanșeitate.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Adaugă echipament', descriere: 'Tab Echipamente → + → client, tip, marcă, agent frigorific (GWP se completează automat).', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Înregistrează intervenție', descriere: 'Tab Intervenții → + → selectează echipamentul, completează cantitățile.', icon: 'build'),
        HelpModuleStep(nr: 3, titlu: 'Generează raport', descriere: 'Tab Rapoarte → + → completează datele și generează PDF.', icon: 'description'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'GWP nu se completează automat?', raspuns: 'Selectează un agent din lista predefinită (nu "Altul") pentru auto-fill GWP.'),
        HelpModuleFaq(intrebare: 'Cât de des trebuie verificate scurgerile?', raspuns: 'Sub 5t CO₂e: nu se aplică | 5-50t: anual | 50-500t: la 6 luni | >500t: la 3 luni (Reg. UE 517/2014).'),
      ],
      sfaturi: [
        'GWP se completează automat la selecția agentului din lista predefinită',
        'CO₂ echivalent și intervalul de verificare se calculează live',
        'Agentul care introduce intervenția se completează automat din cont',
      ],
      versiune: '1.1',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'deviz_tehnic',
      titlu: 'Devize Tehnice',
      descriere: 'Creează devize tehnice, oferte de lucrări și situații de lucrări cu calcul automat.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Deviz nou', descriere: 'Buton + → alege tipul (DVZ/OFR/STL) → completează titlul și obiectivul.', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Adaugă articole', descriere: 'Secțiunea Articole → + → denumire, cantitate, prețuri Mat/Man/Utilaj/Transport.', icon: 'list'),
        HelpModuleStep(nr: 3, titlu: 'Exportă PDF', descriere: 'Buton PDF → document gata pentru client.', icon: 'picture_as_pdf'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Cum schimb tipul documentului?', raspuns: 'Selector din header formular — numărul se regenerează automat pentru seria corectă (DVZ/OFR/STL).'),
      ],
      sfaturi: ['Totalurile se calculează live la fiecare modificare de preț sau cantitate'],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'jobs',
      titlu: 'Lucrări',
      descriere: 'Gestionează lucrările în execuție sau finalizate. Urmărești documentele, echipele alocate și PV-urile de recepție.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Lucrare nouă', descriere: 'Buton + → completează titlul, clientul și locația.', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Alocă echipa', descriere: 'Tab Execuție → selectează echipa și membrii.', icon: 'group'),
        HelpModuleStep(nr: 3, titlu: 'Generează documente', descriere: 'Meniu ⋮ → Contract PDF sau PV Montaj/PIF.', icon: 'description'),
        HelpModuleStep(nr: 4, titlu: 'Finalizează', descriere: 'Schimbă statusul în Finalizat după recepție.', icon: 'check_circle'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Cum generez contractul?', raspuns: 'Lucrare → meniu ⋮ → Generează contract → completează termenii → PDF gata.'),
        HelpModuleFaq(intrebare: 'Cum adaug PV cu semnătură?', raspuns: 'Tab Documente → + PV → completează → buton Semnează & Generează PDF.'),
      ],
      sfaturi: [
        'PV-ul poate include semnătura electronică a clientului direct pe ecran',
        'Lucrările pot fi legate de oferte acceptate',
      ],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'clienti',
      titlu: 'Clienți',
      descriere: 'Gestionează baza de clienți. Vizualizezi istoricul complet, financiarul și echipamentele fiecărui client.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Client nou', descriere: 'Buton + → completează numele, adresa și telefoanele.', icon: 'person_add'),
        HelpModuleStep(nr: 2, titlu: 'Fișa completă', descriere: 'Tap pe client → 4 tab-uri: Rezumat, Istoric, Financiar, Echipamente.', icon: 'info'),
        HelpModuleStep(nr: 3, titlu: 'Contact rapid', descriere: 'Tap pe telefon → apel direct | Tap pe WhatsApp → deschide chat.', icon: 'phone'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Cum adaug mai multe telefoane?', raspuns: 'Editează clientul → buton + de lângă câmpul telefon → max 5 numere.'),
        HelpModuleFaq(intrebare: 'Cum văd istoricul clientului?', raspuns: 'Tap pe client → tab Istoric → cronologie programări, lucrări și oferte.'),
      ],
      sfaturi: [
        'Tab Financiar arată totalul intervențiilor și graficul pe 6 luni',
        'Tab Echipamente listează toate unitățile HVAC instalate',
      ],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'garantii',
      titlu: 'Certificate Garanție',
      descriere: 'Emite și gestionează certificatele de garanție pentru echipamentele instalate.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Certificat nou', descriere: 'Buton + → client, echipament (marcă/model/serie), dată instalare.', icon: 'add'),
        HelpModuleStep(nr: 2, titlu: 'Generează PDF', descriere: 'Certificat → buton PDF → 3 pagini cu taloane de intervenție.', icon: 'picture_as_pdf'),
        HelpModuleStep(nr: 3, titlu: 'Regenerare bulk', descriere: 'Buton 🖨 din toolbar → regenerează PDF pentru toate certificatele din listă.', icon: 'print'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'Cum văd garanțiile care expiră curând?', raspuns: 'Dashboard → cardul Alerte Garanții — roșu=expirat, portocaliu=7 zile, galben=30 zile.'),
        HelpModuleFaq(intrebare: 'Cum modific perioada de garanție?', raspuns: 'Editează certificatul → câmpul Durată garanție (luni).'),
      ],
      sfaturi: [
        'PDF-ul include 3 taloane de intervenție completabile manual',
        'Condiții de garanție complete conform OG 21/1992 pe pagina 3',
      ],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
    HelpModule(
      moduleId: 'dashboard',
      titlu: 'Dashboard Financiar',
      descriere: 'Vedere consolidată a situației financiare: încasări, costuri, profit, datorii și grafic evoluție 6 luni.',
      pasi: [
        HelpModuleStep(nr: 1, titlu: 'Vizualizare', descriere: 'Secțiunea FINANCIAR → Dashboard — se încarcă automat din date locale.', icon: 'dashboard'),
        HelpModuleStep(nr: 2, titlu: 'Actualizare date', descriere: 'Buton Reîncarcă sau pull-to-refresh pentru date proaspete.', icon: 'refresh'),
      ],
      faq: [
        HelpModuleFaq(intrebare: 'De ce valorile sunt 0?', raspuns: 'Datele se iau din cache local. Sincronizează mai întâi modulele individuale (Programări, Lucrări etc.).'),
        HelpModuleFaq(intrebare: 'Cine poate vedea dashboard-ul financiar?', raspuns: 'Numai rolurile admin și birou au acces la secțiunea financiară.'),
      ],
      sfaturi: [
        'Graficul de 6 luni arată automat luna curentă și cele 5 anterioare',
        'Datele sunt offline-first — funcționează și fără internet',
      ],
      versiune: '1.0',
      updatedAt: DateTime(2026, 6, 3),
    ),
  ];
}
