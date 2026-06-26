// ─────────────────────────────────────────────────────────────────────────────
// Textele juridice fixe ale contractului de prestări servicii mentenanță.
// Separate de serviciul PDF pentru a păstra fișierul de generare sub 600 linii.
// NU modifica formularea fără acordul utilizatorului — sunt clauze contractuale.
// ─────────────────────────────────────────────────────────────────────────────

class ContractClauze {
  const ContractClauze._();

  // ── Secțiunea 2 — Obiectul contractului ─────────────────────────────────────
  static const String obiect =
      'Prestatorul se obligă să efectueze servicii de igienizare și revizie '
      'tehnică periodică pentru echipamentele de climatizare și ventilație ale '
      'Beneficiarului, conform listei din Anexa 1 la prezentul contract, în '
      'condițiile și la termenele stabilite prin prezentul contract.';

  // ── Secțiunea 3 — Durata (fragment fix, fără interpolare) ────────────────────
  static const String durataPrelungire =
      'Contractul se poate prelungi prin acordul scris al ambelor părți, cu cel '
      'puțin 30 de zile înainte de expirare.';

  // ── Secțiunea 4 — Prețul și modalitatea de plată (text fix) ──────────────────
  static const String plata =
      'Plata se va efectua prin transfer bancar, în termen de 30 de zile de la '
      'emiterea facturii, după efectuarea fiecărei intervenții. Facturarea se '
      'face separat pentru fiecare intervenție efectuată.';

  // ── Secțiunea 5 — Obligațiile Prestatorului ─────────────────────────────────
  static const List<String> obligatiiPrestator = [
    'Efectuarea intervențiilor de igienizare și revizie tehnică la termenele '
        'convenite cu Beneficiarul',
    'Utilizarea de personal tehnic calificat și autorizat pentru lucrările cu '
        'agent frigorific (autorizație F-Gas conform Reg. UE 517/2014)',
    'Emiterea unui Proces-Verbal de intervenție după fiecare vizită de '
        'mentenanță, cu consemnarea lucrărilor efectuate',
    'Completarea Registrului F-Gas pentru echipamentele care depășesc pragul '
        'legal de raportare',
    'Anunțarea Beneficiarului cu minimum 48 ore înainte de efectuarea '
        'intervenției planificate',
    'Respectarea normelor de protecția muncii și PSI la obiectivul '
        'Beneficiarului',
  ];

  // ── Secțiunea 6 — Obligațiile Beneficiarului ────────────────────────────────
  static const List<String> obligatiiBeneficiar = [
    'Asigurarea accesului nestânjenit al tehnicienilor la echipamentele care '
        'fac obiectul contractului',
    'Înștiințarea imediată a Prestatorului în cazul apariției unor defecțiuni '
        'sau anomalii de funcționare',
    'Achitarea la termen a facturilor emise de Prestator',
    'Neintervenirea și neautorizarea altor persoane să intervină la '
        'echipamentele contractate fără acordul Prestatorului',
    'Asigurarea condițiilor necesare pentru efectuarea în siguranță a '
        'intervențiilor (acces, iluminat, spațiu de lucru)',
  ];

  // ── Secțiunea 7 — Clauze speciale echipamente vechi (cea mai importantă) ─────
  static const List<String> clauzeSpeciale = [
    '7.1. Prestatorul nu poate garanta funcționarea continuă sau fără '
        'defecțiuni a echipamentelor cu o vechime mai mare de 10 ani de la data '
        'fabricației sau a celor cu uzură avansată a componentelor, indiferent '
        'de calitatea serviciilor de mentenanță prestate.',
    '7.2. Intervențiile de mentenanță prevăzute în prezentul contract '
        '(igienizare și revizie tehnică) nu constituie și nu pot fi interpretate '
        'ca garanție pentru componentele mecanice, electronice sau electrice ale '
        'echipamentelor, inclusiv dar fără a se limita la: compresor, ventilator, '
        'schimbător de căldură, plăci electronice de comandă, supape, robineți de '
        'serviciu.',
    '7.3. Defecțiunile tehnice apărute în termen de 30 de zile calendaristice '
        'după efectuarea unei intervenții de mentenanță, care sunt cauzate de '
        'uzura normală a componentelor, de îmbătrânirea materialelor sau de '
        'defecte latente preexistente intervenției, nu sunt imputabile '
        'Prestatorului și nu pot constitui temei pentru solicitarea de '
        'despăgubiri sau returnarea contravalorii serviciilor prestate.',
    '7.4. La constatarea unor defecțiuni sau riscuri tehnice semnificative în '
        'timpul intervenției de mentenanță, Prestatorul va consemna în scris în '
        'Procesul-Verbal de intervenție starea echipamentului, deficiențele '
        'constatate și recomandările de remediere sau înlocuire. Neluarea în '
        'seamă a acestor recomandări de către Beneficiar exonerează Prestatorul '
        'de orice răspundere pentru defecțiunile ulterioare.',
    '7.5. Beneficiarul declară că a luat cunoștință de starea echipamentelor '
        'contractate și că înțelege limitările tehnice ale serviciilor de '
        'mentenanță pentru echipamentele uzate sau cu vechime avansată.',
  ];

  // ── Secțiunea 8 — Răspundere și forță majoră ────────────────────────────────
  static const List<String> raspundere = [
    '8.1. Răspunderea Prestatorului pentru prejudiciile cauzate din culpa sa '
        'este limitată la valoarea serviciilor prestate în luna în care s-a '
        'produs prejudiciul.',
    '8.2. Prestatorul nu răspunde pentru defecțiunile cauzate de: utilizarea '
        'necorespunzătoare a echipamentelor de către Beneficiar sau terți, '
        'supratensiuni electrice, calamități naturale, inundații, incendii sau '
        'alte cazuri de forță majoră.',
    '8.3. Niciuna dintre părți nu va fi răspunzătoare pentru neexecutarea '
        'obligațiilor contractuale cauzată de forță majoră, notificată în scris '
        'în termen de 5 zile de la producerea evenimentului.',
  ];

  // ── Secțiunea 9 — Confidențialitate și GDPR ─────────────────────────────────
  static const String confidentialitate =
      'Părțile se obligă să păstreze confidențialitatea informațiilor comerciale '
      'și tehnice dobândite în executarea prezentului contract. Datele cu '
      'caracter personal sunt prelucrate în conformitate cu Regulamentul (UE) '
      '2016/679 (GDPR).';

  // ── Secțiunea 10 — Litigii ──────────────────────────────────────────────────
  static const String litigii =
      'Orice litigiu decurgând din sau în legătură cu prezentul contract se va '
      'soluționa pe cale amiabilă. În cazul în care nu se ajunge la o înțelegere '
      'amiabilă în termen de 30 de zile, litigiul va fi supus spre soluționare '
      'instanțelor judecătorești competente de la sediul Prestatorului '
      '(Tribunalul Arad).';

  // ── Secțiunea 11 — Dispoziții finale ────────────────────────────────────────
  static const String dispozitiiFinale =
      'Prezentul contract a fost încheiat în 2 (două) exemplare originale, câte '
      'unul pentru fiecare parte contractantă.\n'
      'Orice modificare a prezentului contract se poate face numai prin act '
      'adițional semnat de ambele părți.\n'
      'Prezentul contract intră în vigoare la data semnării de către ambele '
      'părți.';

  // ── Date implicite Prestator (fallback dacă lipsesc din CompanyProfile) ──────
  static const String prestatorNume = 'SC PRO TERM SRL';
  static const String prestatorCui = 'RO11355602';
  static const String prestatorRc = 'J02/1999/003027';
  static const String prestatorSediu =
      'Aleea Neptun Nr.4, Bl.Y3, Et.7, Ap.31, Arad';
  static const String prestatorTel = '0749025610';
  static const String prestatorEmail = 'proterm.arad@gmail.com';
  static const String prestatorReprezentant = 'Herman Sebastian';
}
