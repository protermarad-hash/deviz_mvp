import 'package:flutter/material.dart';
import 'widgets/help_button.dart';

/// Conținut help centralizat pentru toate modulele aplicației.
/// Fiecare getter returnează un HelpContent gata de afișat.
class AppHelp {
  AppHelp._();

  // ---------------------------------------------------------------------------
  // PROGRAMĂRI
  // ---------------------------------------------------------------------------

  static HelpContent get programari => const HelpContent(
        title: 'Cum se folosește modulul Programări',
        intro:
            'Modulul Programări îți permite să planifici, urmărești și documentezi toate intervențiile, montajele și vizitele la clienți.',
        sections: [
          HelpSection(
            icon: Icons.add_circle_outline,
            title: 'Creare programare nouă',
            steps: [
              'Apasă butonul "Adaugă" (colțul din dreapta jos).',
              'Completează titlul, clientul și data/ora programate.',
              'Selectează echipa sau angajații responsabili.',
              'Adaugă locația și detalii despre intervenție.',
              'Opțional: atașează o rețetă de materiale din catalog.',
              'Salvează — programarea apare în calendar și listă.',
            ],
            note:
                'Poți adăuga programări și direct din calendar prin apăsare lungă pe un interval orar.',
          ),
          HelpSection(
            icon: Icons.edit_calendar_outlined,
            title: 'Actualizare status și finalizare',
            steps: [
              'Apasă pe o programare pentru a o deschide.',
              'Schimbă statusul: Planificată → În curs → Finalizată.',
              'La finalizare completează materialele consumate și costurile.',
              'Adaugă fotografii de pe teren cu butonul "Poze teren".',
              'Înregistrează suma încasată în secțiunea financiară (admin).',
            ],
          ),
          HelpSection(
            icon: Icons.inventory_2_outlined,
            title: 'Materiale consumate și bon de consum',
            steps: [
              'În programare, selectează o rețetă de materiale din catalog.',
              'Completează cantitatea folosită (metri liniari sau cantitate directă).',
              'Materialele sunt calculate automat pe baza rețetei.',
              'Admin: apasă "Bon consum SmartBill" pentru a trimite consumul în SmartBill și a scădea din gestiune.',
            ],
            note:
                'Bonul de consum necesită configurarea gestiunii și seriei în Setări firmă → SmartBill.',
          ),
          HelpSection(
            icon: Icons.filter_list_outlined,
            title: 'Filtrare și vizualizare',
            steps: [
              'Comută între vizualizare Calendar și Listă din bara de sus.',
              'Filtrează după echipă, angajat sau status din panoul lateral.',
              'Folosește chip-ul "Ultimele 14 luni / Tot istoricul" pentru a vedea arhiva.',
              'Raportul de profitabilitate se accesează din butonul grafic (admin).',
              'Raportul de consum materiale se accesează din butonul cutie (admin).',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // RECLAMAȚII
  // ---------------------------------------------------------------------------

  static HelpContent get reclamatii => const HelpContent(
        title: 'Cum se folosește modulul Reclamații',
        intro:
            'Gestionează reclamațiile clienților, intervențiile în garanție și documentele asociate (PV reparație, PV garanție, bon de lucru).',
        sections: [
          HelpSection(
            icon: Icons.add_circle_outline,
            title: 'Înregistrare reclamație nouă',
            steps: [
              'Apasă butonul "Adaugă reclamație" (colțul din dreapta jos).',
              'Selectează clientul și completează descrierea problemei.',
              'Alege tipul: garanție sau post-garanție.',
              'Setează termenul de rezolvare și angajatul responsabil.',
              'Salvează — reclamația primește automat un număr unic.',
            ],
          ),
          HelpSection(
            icon: Icons.assignment_outlined,
            title: 'Gestionare și rezolvare',
            steps: [
              'Deschide reclamația și actualizează statusul pe măsură ce avansează.',
              'Generează PV de reparație din butonul "PV Reparație".',
              'Generează PV de intervenție în garanție din butonul "PV Garanție".',
              'Atașează fotografii sau documente justificative.',
              'La rezolvare marchează reclamația ca "Rezolvată" și adaugă soluția aplicată.',
            ],
          ),
          HelpSection(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Documente generate',
            steps: [
              'PV Reparație — procesul verbal de reparație semnat de client.',
              'PV Intervenție Garanție — document pentru intervenții în perioada de garanție.',
              'Bon de lucru — centralizatorul intervențiilor pentru un client.',
              'Toate documentele pot fi exportate ca PDF și salvate.',
            ],
            note:
                'Documentele preiau automat datele firmei din Setări → Profil firmă.',
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // AGFR
  // ---------------------------------------------------------------------------

  static HelpContent get agfr => const HelpContent(
        title: 'Cum se folosește modulul AGFR',
        intro:
            'Modulul AGFR (Agenți Frigorifici) gestionează evidența echipamentelor, intervențiilor și rapoartelor conform legislației pentru instalațiile frigorifice.',
        sections: [
          HelpSection(
            icon: Icons.devices_outlined,
            title: 'Evidență echipamente',
            steps: [
              'Adaugă fiecare echipament frigorific cu datele tehnice complete.',
              'Înregistrează: tip agent frigorific, capacitate, număr serie, client.',
              'Echipamentele sunt legate de client — le găsești și din fișa clientului.',
              'Fiecare echipament are un jurnal de intervenții asociat.',
            ],
          ),
          HelpSection(
            icon: Icons.build_outlined,
            title: 'Intervenții și rapoarte',
            steps: [
              'Înregistrează fiecare intervenție: data, tipul, cantitatea de agent.',
              'Generează Raport AGFR pentru fiecare intervenție efectuată.',
              'Raportul de cântărire documentează recuperarea/completarea agentului.',
              'Toate rapoartele pot fi exportate PDF cu semnătura tehnicianului.',
            ],
            note:
                'Datele tehnicianului autorizat se configurează în Setări firmă → AGFR.',
          ),
          HelpSection(
            icon: Icons.filter_list_outlined,
            title: 'Filtrare și căutare',
            steps: [
              'Folosește bara de căutare pentru a găsi rapid un echipament sau client.',
              'Filtrează după tipul de agent frigorific sau perioada de intervenție.',
              'Tab-urile din partea de sus comută între Echipamente, Intervenții, Rapoarte și Cântăriri.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // CLIENȚI
  // ---------------------------------------------------------------------------

  static HelpContent get clienti => const HelpContent(
        title: 'Cum se folosește modulul Clienți',
        intro:
            'Gestionează baza de date a clienților firmei — persoane fizice și juridice.',
        sections: [
          HelpSection(
            icon: Icons.person_add_outlined,
            title: 'Adăugare client nou',
            steps: [
              'Apasă "Adaugă client" și completează datele de identificare.',
              'Pentru persoane juridice: CUI, denumire, registrul comerțului.',
              'Folosește butonul ANAF pentru a prelua automat datele fiscale după CUI.',
              'Adaugă adresa, telefonul și email-ul de contact.',
              'Clientul primește automat un cod unic intern.',
            ],
            note: 'Datele clienților se sincronizează automat pe toate dispozitivele.',
          ),
          HelpSection(
            icon: Icons.edit_outlined,
            title: 'Editare și gestionare',
            steps: [
              'Apasă pe un client din listă pentru a-l deschide și edita.',
              'Din fișa clientului poți vedea istoricul programărilor și reclamațiilor.',
              'Clientul poate fi șters doar dacă nu are documente asociate.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // LUCRĂRI (JOBS)
  // ---------------------------------------------------------------------------

  static HelpContent get lucrari => const HelpContent(
        title: 'Cum se folosește modulul Lucrări',
        intro:
            'Modulul Lucrări gestionează proiectele și contractele de execuție ale firmei.',
        sections: [
          HelpSection(
            icon: Icons.add_circle_outline,
            title: 'Creare lucrare nouă',
            steps: [
              'Apasă "Lucrare nouă" și completează titlul și clientul beneficiar.',
              'Adaugă codul de lucrare, descrierea și valoarea contractată.',
              'Setează data de start și termenul de finalizare.',
              'Lucrarea poate fi legată de programări și devize.',
            ],
          ),
          HelpSection(
            icon: Icons.folder_outlined,
            title: 'Documente lucrare',
            steps: [
              'Din fișa lucrării poți accesa toate documentele asociate.',
              'Adaugă contracte, devize, situații de lucrări și alte documente.',
              'Fotografiile de pe teren se pot atașa direct la lucrare.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // DEVIZE / OFERTE
  // ---------------------------------------------------------------------------

  static HelpContent get oferte => const HelpContent(
        title: 'Cum se folosesc Devizele și Ofertele',
        intro:
            'Creează devize și oferte de preț pentru clienți, cu export PDF și sincronizare SmartBill.',
        sections: [
          HelpSection(
            icon: Icons.add_circle_outline,
            title: 'Creare deviz/ofertă',
            steps: [
              'Apasă "Deviz nou" sau "Ofertă nouă" și selectează clientul.',
              'Adaugă linii: materiale, manoperă și alte servicii.',
              'Prețurile se pot prelua din catalogul de produse.',
              'Setează TVA, discount și alte condiții comerciale.',
              'Previzualizează și exportă PDF-ul final.',
            ],
          ),
          HelpSection(
            icon: Icons.sync_outlined,
            title: 'Sincronizare SmartBill',
            steps: [
              'Din deviz/ofertă apasă "Emite în SmartBill" pentru a crea proforma sau factura.',
              'Selectează seria și tipul de document.',
              'Documentul apare automat în SmartBill cu toate liniile.',
              'Statusul plății se actualizează automat din SmartBill.',
            ],
            note: 'Necesită SmartBill configurat în Setări firmă.',
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // REGISTRATURĂ
  // ---------------------------------------------------------------------------

  static HelpContent get registratura => const HelpContent(
        title: 'Cum se folosește Registratura',
        intro:
            'Registratura electronică înregistrează toate documentele emise și primite de firmă, cu număr de înregistrare automat.',
        sections: [
          HelpSection(
            icon: Icons.inbox_outlined,
            title: 'Înregistrare document',
            steps: [
              'Apasă "Înregistrare intrare" sau "Înregistrare ieșire".',
              'Completează: titlul documentului, emitent/destinatar, data.',
              'Documentul primește automat numărul de înregistrare următor.',
              'Atașează fișierul PDF sau scanul documentului fizic.',
            ],
          ),
          HelpSection(
            icon: Icons.search_outlined,
            title: 'Căutare în registru',
            steps: [
              'Folosește bara de căutare pentru a găsi documente după număr sau titlu.',
              'Filtrează după tip (intrare/ieșire), dată sau categorie.',
              'Documentele generate automat (facturi, oferte) apar automat în registru.',
            ],
            note:
                'Numerotarea se configurează în Setări registratură — verifică seria înainte de a începe.',
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // HR DEPLASĂRI
  // ---------------------------------------------------------------------------

  static HelpContent get hrDeplasari => const HelpContent(
        title: 'Cum se folosesc Deplasările HR',
        intro:
            'Gestionează ordinele de deplasare și deconturile de cheltuieli ale angajaților.',
        sections: [
          HelpSection(
            icon: Icons.add_circle_outline,
            title: 'Creare ordin de deplasare',
            steps: [
              'Apasă "Ordin nou" și selectează angajatul.',
              'Completează: destinația, scopul deplasării, data plecării și întoarcerii.',
              'Adaugă mijlocul de transport și diurna aferentă.',
              'Exportă PDF-ul ordinului de deplasare pentru semnare.',
            ],
          ),
          HelpSection(
            icon: Icons.receipt_outlined,
            title: 'Decont cheltuieli',
            steps: [
              'După deplasare, deschide ordinul și adaugă cheltuielile reale.',
              'Înregistrează: cazare, transport, masă și alte cheltuieli.',
              'Sistemul calculează automat totalul de decontat.',
              'Exportă decontul ca PDF pentru aprobare și contabilitate.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // HR PREZENȚĂ
  // ---------------------------------------------------------------------------

  static HelpContent get hrPrezenta => const HelpContent(
        title: 'Cum se folosește Prezența',
        intro:
            'Înregistrează prezența zilnică a angajaților — ore lucrate, ore suplimentare, absențe.',
        sections: [
          HelpSection(
            icon: Icons.today_outlined,
            title: 'Înregistrare prezență',
            steps: [
              'Deschide modulul în ziua curentă — apare ziua de azi precompletată.',
              'Confirmă ora de intrare și ieșire.',
              'Marchează dacă ai lucrat ore suplimentare sau ai fost în deplasare.',
              'Salvează — datele se trimit automat la manager.',
            ],
            note: 'Fiecare angajat vede doar propria prezență. Managerul vede tot.',
          ),
          HelpSection(
            icon: Icons.summarize_outlined,
            title: 'Vizualizare și export',
            steps: [
              'Managerul poate filtra prezența pe angajat, echipă sau perioadă.',
              'Exportă pontajul lunar pentru contabilitate.',
              'Abaterile și orele suplimentare sunt evidențiate automat.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // HR PONTAJ LUNAR
  // ---------------------------------------------------------------------------

  static HelpContent get hrPontajLunar => const HelpContent(
        title: 'Cum se folosește Pontajul Lunar',
        intro:
            'Centralizează și aprobă pontajul lunar al tuturor angajaților.',
        sections: [
          HelpSection(
            icon: Icons.calendar_month_outlined,
            title: 'Completare pontaj',
            steps: [
              'Selectează luna și angajatul din lista de sus.',
              'Completează zilnic: zile lucrate, zile concediu, zile medical.',
              'Sistemul calculează automat totalurile lunare.',
              'La final apasă "Finalizează pontaj" pentru aprobare.',
            ],
          ),
          HelpSection(
            icon: Icons.check_circle_outlined,
            title: 'Aprobare și export',
            steps: [
              'Managerul verifică și aprobă pontajele finalizate.',
              'Exportă situația lunară ca PDF pentru contabilitate.',
              'Datele aprobate sunt blocate și nu mai pot fi modificate.',
            ],
            note: 'Pontajul aprobat este trimis automat la modulul de salarizare.',
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // SCULE
  // ---------------------------------------------------------------------------

  static HelpContent get scule => const HelpContent(
        title: 'Cum se folosește modulul Scule',
        intro:
            'Gestionează inventarul de scule și unelte al firmei.',
        sections: [
          HelpSection(
            icon: Icons.build_outlined,
            title: 'Adăugare sculă',
            steps: [
              'Apasă "Adaugă sculă" și completează: denumire, serie, categorie.',
              'Adaugă valoarea de achiziție și data cumpărării.',
              'Atribuie scula unei echipe sau angajat responsabil.',
              'Fotografiază scula pentru identificare rapidă.',
            ],
          ),
          HelpSection(
            icon: Icons.swap_horiz_outlined,
            title: 'Mișcări și atribuire',
            steps: [
              'Înregistrează atribuirea sculei la un angajat sau echipă.',
              'La returnare marchează scula ca disponibilă.',
              'Urmărește istoricul mișcărilor pentru fiecare sculă.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // VEHICULE
  // ---------------------------------------------------------------------------

  static HelpContent get vehicule => const HelpContent(
        title: 'Cum se folosește modulul Vehicule',
        intro:
            'Gestionează parcul auto al firmei — date tehnice, asigurări, inspecții.',
        sections: [
          HelpSection(
            icon: Icons.directions_car_outlined,
            title: 'Adăugare vehicul',
            steps: [
              'Apasă "Vehicul nou" și completează: numărul de înmatriculare, marca, modelul.',
              'Adaugă datele tehnice: serie șasiu, capacitate motor, an fabricație.',
              'Setează datele expirărilor: ITP, RCA, CASCO, rovignietă.',
              'Atribuie vehiculul unui angajat sau echipă.',
            ],
          ),
          HelpSection(
            icon: Icons.notifications_active_outlined,
            title: 'Alerte expirare',
            steps: [
              'Sistemul afișează automat alertă când un document expiră în 30 de zile.',
              'Actualizează datele după reînnoire din butonul de editare.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // ANGAJAȚI
  // ---------------------------------------------------------------------------

  static HelpContent get angajati => const HelpContent(
        title: 'Cum se folosesc Angajații',
        intro:
            'Catalogul de angajați — date personale, rol, echipă și cost salarial.',
        sections: [
          HelpSection(
            icon: Icons.person_add_outlined,
            title: 'Adăugare angajat',
            steps: [
              'Apasă "Angajat nou" și completează: nume, prenume, rol în firmă.',
              'Selectează echipa din care face parte.',
              'Configurează tipul de salarizare: orar sau lunar.',
              'Adaugă datele de contact și alte informații relevante.',
            ],
            note: 'Rolul angajatului determină ce module poate accesa în aplicație.',
          ),
          HelpSection(
            icon: Icons.group_outlined,
            title: 'Roluri și accesuri',
            steps: [
              'Admin — acces complet la toate modulele și datele financiare.',
              'Manager — acces la rapoarte și gestionare echipă.',
              'Tehnician/Operator — acces la programări proprii și prezență.',
              'Rolurile se configurează din Admin → Roluri și permisiuni.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // ECHIPE
  // ---------------------------------------------------------------------------

  static HelpContent get echipe => const HelpContent(
        title: 'Cum se folosesc Echipele',
        intro:
            'Organizează angajații în echipe de lucru pentru o planificare mai ușoară.',
        sections: [
          HelpSection(
            icon: Icons.group_add_outlined,
            title: 'Creare echipă',
            steps: [
              'Apasă "Echipă nouă" și dă-i un nume sugestiv.',
              'Adaugă membrii echipei din lista de angajați.',
              'Setează o culoare pentru identificare rapidă în calendar.',
              'Echipa poate fi selectată la programări pentru atribuire în bloc.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // PARTENERI
  // ---------------------------------------------------------------------------

  static HelpContent get parteneri => const HelpContent(
        title: 'Cum se folosește modulul Parteneri',
        intro:
            'Gestionează partenerii externi — subcontractori, furnizori de servicii.',
        sections: [
          HelpSection(
            icon: Icons.handshake_outlined,
            title: 'Adăugare partener',
            steps: [
              'Apasă "Partener nou" și completează datele firmei partenere.',
              'Adaugă angajații/tehnicienii partenerului cu datele de contact.',
              'Înregistrează vehiculele partenerului dacă este cazul.',
              'Partenerii pot fi selectați la programări ca echipă externă.',
            ],
          ),
          HelpSection(
            icon: Icons.payments_outlined,
            title: 'Plăți parteneri',
            steps: [
              'Din raportul de parteneri (butonul din Programări) vizualizează sumele de plătit.',
              'Înregistrează plățile efectuate către parteneri.',
              'Urmărește soldul și istoricul colaborării.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // CATALOG PRODUSE
  // ---------------------------------------------------------------------------

  static HelpContent get catalogProduse => const HelpContent(
        title: 'Cum se folosește Catalogul de Produse',
        intro:
            'Catalogul de produse stochează echipamentele și serviciile pe care le vinzi — utilizat la emiterea ofertelor și facturilor.',
        sections: [
          HelpSection(
            icon: Icons.add_box_outlined,
            title: 'Adăugare produs',
            steps: [
              'Apasă "Produs nou" și completează: denumire, categorie, marcă, model.',
              'Adaugă prețul de listă și unitatea de măsură.',
              'Opțional: adaugă prețuri furnizor pentru calculul marjei.',
              'Produsele din catalog sunt disponibile la crearea devizelor.',
            ],
          ),
          HelpSection(
            icon: Icons.card_membership_outlined,
            title: 'Certificate de garanție',
            steps: [
              'Din fișa produsului poți genera certificate de garanție.',
              'Completează seria, data instalării și durata garanției.',
              'Certificatul se exportă ca PDF cu datele firmei și clientului.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // CATALOG MATERIALE
  // ---------------------------------------------------------------------------

  static HelpContent get catalogMateriale => const HelpContent(
        title: 'Cum se folosește Catalogul de Materiale',
        intro:
            'Catalogul de materiale stochează consumabilele și materialele folosite în intervenții — utilizat în rețetele de materiale.',
        sections: [
          HelpSection(
            icon: Icons.add_box_outlined,
            title: 'Adăugare material',
            steps: [
              'Apasă "Material nou" și completează: denumire, unitate de măsură, preț unitar.',
              'Setează stocul curent și cantitatea minimă de alertă.',
              'Categoria poate fi: material, frigorant, consumabil.',
              'Materialele apar automat în rețetele de programări.',
            ],
          ),
          HelpSection(
            icon: Icons.warning_outlined,
            title: 'Alertă stoc minim',
            steps: [
              'Dacă stocul scade sub cantitatea minimă configurată, apare alertă în raportul de consum materiale.',
              'Actualizează stocul după recepție de marfă.',
            ],
            note:
                'Stocul real se poate prelua din SmartBill gestiune — configurează integrarea în Setări firmă.',
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // REȚETE MATERIALE (KITURI)
  // ---------------------------------------------------------------------------

  static HelpContent get reteteKituri => const HelpContent(
        title: 'Cum se folosesc Rețetele de Materiale',
        intro:
            'Rețetele (kiturile) sunt șabloane de materiale predefinite pentru tipuri standard de intervenții — angajatul selectează rețeta și completează cantitatea.',
        sections: [
          HelpSection(
            icon: Icons.playlist_add_outlined,
            title: 'Creare rețetă',
            steps: [
              'Apasă "Rețetă nouă" și dă-i un nume descriptiv (ex: "Instalare split 12000 BTU").',
              'Adaugă componentele: selectează materialul din catalog și cantitatea de bază.',
              'Bifează "Variabil per metru liniar" pentru materiale care depind de distanță.',
              'Setează costul unitar — se preia automat din catalog dacă e configurat.',
              'Activează rețeta pentru a fi disponibilă în programări.',
            ],
          ),
          HelpSection(
            icon: Icons.link_outlined,
            title: 'Legătură cu SmartBill',
            steps: [
              'Pentru fiecare component, completează Codul SmartBill (din gestiunea configurată).',
              'La generarea bonului de consum, codul SmartBill este folosit pentru identificarea corectă a produsului.',
              'Poți prelua lista produselor direct din SmartBill cu butonul "Preia din SmartBill".',
            ],
            note:
                'Dacă denumirile din rețetă diferă de cele din SmartBill, bonul de consum poate fi creat cu eroare. Verifică înainte de trimitere.',
          ),
          HelpSection(
            icon: Icons.smartphone_outlined,
            title: 'Utilizare de către angajați',
            steps: [
              'La o programare, angajatul selectează rețeta potrivită.',
              'Completează metrii liniari sau cantitățile utilizate efectiv.',
              'Materialele se calculează automat și apar în programare.',
              'Administratorul trimite bonul de consum în SmartBill după finalizare.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // DASHBOARD
  // ---------------------------------------------------------------------------

  static HelpContent get dashboard => const HelpContent(
        title: 'Cum se folosește Dashboard-ul',
        intro:
            'Dashboard-ul oferă o privire de ansamblu rapidă asupra activității zilnice și a programărilor relevante.',
        sections: [
          HelpSection(
            icon: Icons.today_outlined,
            title: 'Programări de azi',
            steps: [
              'Secțiunea "Azi" arată toate programările din ziua curentă.',
              'Apasă pe o programare pentru a o deschide direct.',
              'Culoarea indică statusul: albastru=planificat, portocaliu=în curs, verde=finalizat.',
            ],
          ),
          HelpSection(
            icon: Icons.person_outlined,
            title: 'Programările mele',
            steps: [
              'Secțiunea "Ale mele" filtrează programările atribuite contului tău.',
              'Angajații văd doar programările proprii; managerii văd tot.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // SETĂRI FIRMĂ
  // ---------------------------------------------------------------------------

  static HelpContent get setariFirma => const HelpContent(
        title: 'Cum se folosesc Setările Firmei',
        intro:
            'Configurează datele firmei, integrările externe și preferințele aplicației.',
        sections: [
          HelpSection(
            icon: Icons.business_outlined,
            title: 'Date firmă',
            steps: [
              'Completează: denumire, CUI, IBAN, adresă, telefon, email.',
              'Încarcă logo-ul firmei — apare pe toate PDF-urile generate.',
              'Datele firmei sunt folosite automat la generarea documentelor.',
            ],
          ),
          HelpSection(
            icon: Icons.receipt_outlined,
            title: 'Integrare SmartBill',
            steps: [
              'Completează email-ul și token-ul API din contul SmartBill.',
              'Adaugă CIF-ul firmei din SmartBill.',
              'Apasă "Testează conexiunea" pentru a verifica credențialele.',
              'Apasă "Încarcă serii și TVA" pentru a prelua seriile disponibile.',
              'Completează Gestiunea și Seria pentru bon de consum.',
            ],
            note:
                'Token-ul API se generează din SmartBill → Setări → API → Generare token.',
          ),
          HelpSection(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Export PDF',
            steps: [
              'Configurează template-ul vizual pentru PDF-uri (clasic sau modern).',
              'Setează procentele implicite de TVA, profit și regie.',
              'Modificările se aplică la toate PDF-urile generate ulterior.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // DOCUMENTE
  // ---------------------------------------------------------------------------

  static HelpContent get documente => const HelpContent(
        title: 'Cum se folosește modulul Documente',
        intro:
            'Arhiva centralizată a tuturor documentelor generate și atașate în aplicație.',
        sections: [
          HelpSection(
            icon: Icons.folder_open_outlined,
            title: 'Navigare documente',
            steps: [
              'Documentele sunt organizate pe categorii: oferte, devize, facturi, PV-uri etc.',
              'Filtrează după categorie, dată sau client.',
              'Apasă pe un document pentru a-l deschide sau descărca.',
            ],
          ),
          HelpSection(
            icon: Icons.upload_file_outlined,
            title: 'Adăugare documente',
            steps: [
              'Documentele se adaugă automat la generare din celelalte module.',
              'Poți atașa manual documente externe cu butonul "Adaugă document".',
              'Fișierele acceptate: PDF, JPG, PNG, Word.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // AI ASSISTANT
  // ---------------------------------------------------------------------------

  static HelpContent get aiAssistant => const HelpContent(
        title: 'Cum se folosește Asistentul AI',
        intro:
            'Asistentul AI te ajută să redactezi documente, să răspunzi la întrebări despre activitatea firmei sau să obții informații rapide.',
        sections: [
          HelpSection(
            icon: Icons.chat_outlined,
            title: 'Utilizare chat',
            steps: [
              'Scrie întrebarea sau cererea în câmpul de text de jos.',
              'Apasă "Trimite" sau tasta Enter.',
              'Asistentul răspunde pe baza informațiilor disponibile.',
              'Poți cere: redactare email, calcule simple, sugestii de text pentru oferte.',
            ],
            note:
                'Asistentul nu are acces la datele firmei dacă nu îi furnizezi tu informațiile în mesaj.',
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // RAPORT CONSUM MATERIALE
  // ---------------------------------------------------------------------------

  static HelpContent get consumMateriale => const HelpContent(
        title: 'Cum se folosește Raportul de Consum Materiale',
        intro:
            'Analizează materialele consumate de echipe în intervenții — pe perioadă, echipă sau angajat.',
        sections: [
          HelpSection(
            icon: Icons.date_range_outlined,
            title: 'Selectare perioadă',
            steps: [
              'Alege perioada din chips-urile de sus: săptămâna curentă, luna curentă etc.',
              'Sau apasă "Personalizat" pentru a selecta orice interval de date.',
              'Graficul și lista se actualizează automat.',
            ],
          ),
          HelpSection(
            icon: Icons.filter_list_outlined,
            title: 'Filtrare echipă / angajat',
            steps: [
              'Selectează o echipă sau un angajat din rândul de filtre.',
              'Lista arată doar materialele consumate de echipa/angajatul selectat.',
              'Util pentru a vedea cine consumă cel mai mult dintr-un material.',
            ],
          ),
          HelpSection(
            icon: Icons.warning_amber_outlined,
            title: 'Alertă stoc scăzut',
            steps: [
              'Materialele cu stoc sub minimul configurat apar cu alertă roșie.',
              'Banner-ul de sus listează toate materialele cu stoc critic.',
              'Actualizează stocul din Catalog Materiale sau din SmartBill.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // BAZA PROPRIE DE NORME DEVIZ
  // ---------------------------------------------------------------------------

  static HelpContent get devizArticoleBaza => const HelpContent(
        title: 'Cum se folosește Baza proprie de norme',
        intro:
            'Baza de norme stochează articolele folosite în devize cu prețurile lor unitare. Prețurile se completează automat la refolosire.',
        sections: [
          HelpSection(
            icon: Icons.auto_fix_high_outlined,
            title: 'Completare automată prețuri',
            steps: [
              'Când adaugi un articol în deviz, aplicația caută automat în baza de norme.',
              'Dacă articolul există, prețul se completează automat în câmpul corespunzător.',
              'Poți modifica prețul pentru devizul curent fără să afectezi baza salvată.',
              'La salvare, dacă prețul s-a schimbat, aplicația te întreabă dacă vrei să actualizezi baza.',
            ],
            note:
                'Potrivirea se face după denumire exactă (fără majuscule/minuscule).',
          ),
          HelpSection(
            icon: Icons.save_outlined,
            title: 'Salvare automată',
            steps: [
              'Fiecare articol nou adăugat în deviz se salvează automat în baza de norme.',
              'La articole de tip material: se salvează Prețul material.',
              'La articole de tip manoperă standard: se salvează Prețul manoperă.',
              'Numărul de utilizări și data ultimei utilizări se actualizează automat.',
            ],
          ),
          HelpSection(
            icon: Icons.edit_outlined,
            title: 'Editare manuală',
            steps: [
              'Apasă "Editează" pe orice articol pentru a modifica prețurile toate cele 4 componente.',
              'Poți seta Manual: Material, Manoperă, Utilaj, Transport (RON per unitate).',
              'Totalul unitar se calculează automat din suma componentelor.',
              'Modificările se sincronizează automat pe toate dispozitivele.',
            ],
          ),
          HelpSection(
            icon: Icons.delete_outline,
            title: 'Ștergere articol',
            steps: [
              'Apasă "Șterge" pentru a elimina un articol din baza de norme.',
              'Devizele existente nu sunt afectate — articolele rămân în ofertele salvate.',
              'La ștergere, articolul nu mai apare ca sugestie în dialogul de adăugare.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // FINANCIAR PARTENERI — pagina unui singur partener
  // ---------------------------------------------------------------------------

  static HelpContent get partnerFinanciar => const HelpContent(
        title: 'Cum se folosește Financiar Partener',
        intro:
            'Această pagină îți arată toate tranzacțiile financiare cu un partener: ce ai de încasat, ce ai de plătit și soldul net.',
        sections: [
          HelpSection(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Sold NET',
            steps: [
              'Sold pozitiv (verde) = partenerul îți datorează bani.',
              'Sold negativ (roșu) = tu datorezi bani partenerului.',
              'Soldul se calculează automat din toate tranzacțiile.',
            ],
          ),
          HelpSection(
            icon: Icons.add_circle_outline,
            title: 'Adaugă încasare sau plată',
            steps: [
              'Apasă butonul verde "Încasează" pentru a înregistra o sumă primită.',
              'Apasă butonul roșu "Plătește" pentru a înregistra o plată efectuată.',
              'Completează suma, descrierea, data și metoda de plată.',
              'Selectează statusul: Neîncasat, Parțial sau Plătit.',
            ],
          ),
          HelpSection(
            icon: Icons.filter_list_outlined,
            title: 'Filtrare tranzacții',
            steps: [
              'Filtrează după tip: Toate, Programări, Vânzări, Achiziții, Plăți manuale.',
              'Tranzacțiile sunt sortate cronologic descrescător.',
              'Ține apăsat pe o tranzacție pentru a o șterge.',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // FINANCIAR PARTENERI — dashboard global
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // DEVIZE FILTRE CTA
  // ---------------------------------------------------------------------------

  static HelpContent get devizeFiltreCta => const HelpContent(
        title: 'Cum se folosește modulul Devize Filtre CTA',
        intro:
            'Modulul Devize Filtre CTA permite crearea și gestionarea devizelor pentru înlocuirea filtrelor la centralele de tratare a aerului (CTA) din fabrică.',
        sections: [
          HelpSection(
            icon: Icons.add_circle_outline,
            title: 'Creare deviz nou',
            steps: [
              'Apasă butonul "Deviz nou" (dreapta jos).',
              'La creare se completează automat toate CTA-urile din template-ul standard cu prețurile actuale.',
              'Completează titlul devizului, clientul și data emiterii.',
              'Numărul de deviz (CTA-YYYY-NNNN) se generează automat.',
            ],
            note:
                'Devizul vine precompletate cu toate cele 15 CTA-uri din fabrică. Poți șterge sau adăuga CTA-uri după necesitate.',
          ),
          HelpSection(
            icon: Icons.edit_outlined,
            title: 'Editare prețuri',
            steps: [
              'Apasă pe orice rând de preț (caseta albastră) pentru a îl edita.',
              'Introdu noul preț în euro și apasă Salvează.',
              'Prețurile se actualizează instant și totalul se recalculează.',
              'Folosește "Actualizează prețuri din template" (meniu ⋮) pentru a reseta la prețurile standard.',
            ],
          ),
          HelpSection(
            icon: Icons.air_outlined,
            title: 'Gestionare CTA-uri',
            steps: [
              'Apasă "Adaugă CTA" pentru a adăuga un CTA din template sau unul nou.',
              '"Duplică" — creează o copie a CTA-ului selectat.',
              '"Șterge" — elimină CTA-ul (cu confirmare).',
              'Săgețile ↑↓ reordonează CTA-urile în listă.',
            ],
          ),
          HelpSection(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Export PDF',
            steps: [
              'Apasă "PDF" (butonul din josul paginii) sau din meniul ⋮.',
              'Devizul se salvează automat înainte de generarea PDF-ului.',
              'PDF-ul include header-ul firmei, tabelul complet cu filtre și totalurile pe zone.',
              'Poți partaja sau tipări PDF-ul din modalul de acțiuni.',
            ],
          ),
          HelpSection(
            icon: Icons.sync_outlined,
            title: 'Sincronizare offline',
            steps: [
              'Devizele se salvează local imediat, fără a necesita internet.',
              'Când revine conexiunea, datele se sincronizează automat în cloud.',
              'Devizele sunt accesibile de pe orice dispozitiv după sincronizare.',
            ],
          ),
        ],
      );

  static HelpContent get partnerFinanciarDashboard => const HelpContent(
        title: 'Cum se folosește Dashboard Financiar Parteneri',
        intro:
            'Vizualizează situația financiară a tuturor partenerilor: total de încasat, total de plătit și soldul net global.',
        sections: [
          HelpSection(
            icon: Icons.dashboard_outlined,
            title: 'Sumar global',
            steps: [
              'Secțiunea de sus arată totalurile agregate pentru toți partenerii.',
              'Sold NET total pozitiv = partenerii îți datorează în total.',
              'Sold NET total negativ = tu datorezi în total partenerilor.',
            ],
          ),
          HelpSection(
            icon: Icons.people_outline,
            title: 'Lista partenerilor',
            steps: [
              'Lista este sortată după sold: cei cu sold mare sus.',
              'Apasă pe un partener pentru a vedea tranzacțiile detaliate.',
              'Filtrează: Toți / De încasat (sold pozitiv) / De plătit (sold negativ).',
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // TASKURI
  // ---------------------------------------------------------------------------

  static HelpContent get taskuri => const HelpContent(
        title: 'Cum se folosește modulul Taskuri',
        intro:
            'Modulul Taskuri îți permite să urmărești sarcinile zilnice ale firmei: oferte de trimis, apeluri, programări, sarcini interne și alte activități.',
        sections: [
          HelpSection(
            icon: Icons.add_circle_outline,
            title: 'Adăugare task rapid',
            steps: [
              'Apasă butonul "+" (dreapta jos) sau "Adaugă" din toolbar.',
              'Introdu titlul taskului — scurt și clar (ex: "Ofertă client Ionescu").',
              'Alege categoria: Ofertare, Programare, Financiar, Apel, Email, Intern, Altele.',
              'Setează prioritatea: 🔴 Urgent, 🟡 Normal, 🟢 Scăzută.',
              'Opțional: adaugă un deadline și o descriere.',
              'Apasă "Salvează rapid" pentru a adăuga imediat.',
            ],
          ),
          HelpSection(
            icon: Icons.check_circle_outline,
            title: 'Bifarea și gestionarea taskurilor',
            steps: [
              'Apasă "✓ Bifează" pe un task pentru a-l marca ca finalizat.',
              'Taskul bifast se mută automat în secțiunea "Efectuate" (jos).',
              'Poți dezactiva un task bifast apăsând din nou pe el.',
              'Secțiunea "Efectuate" este colapsabilă — apasă pe ea pentru a vedea istoricul.',
            ],
          ),
          HelpSection(
            icon: Icons.filter_list_outlined,
            title: 'Filtrare și sortare',
            steps: [
              'Filtrele rapide (chips) îți permit să vezi: Toate, Urgente, Azi, pe categorie.',
              'Taskurile "De făcut" sunt sortate: Urgente → Deadline apropiat → Cele mai recente.',
              'Taskurile depășite apar cu roșu și eticheta "Depășit cu X zile".',
            ],
          ),
          HelpSection(
            icon: Icons.cloud_sync_outlined,
            title: 'Sincronizare',
            steps: [
              'Taskurile se salvează local imediat — funcționează și fără internet.',
              'Când revine conexiunea, se sincronizează automat cu cloud-ul.',
              'Apasă "☁️↔" din toolbar pentru a forța sincronizarea manuală.',
              'Fiecare utilizator vede propriile taskuri; admin-ul vede toate.',
            ],
          ),
        ],
      );
}
