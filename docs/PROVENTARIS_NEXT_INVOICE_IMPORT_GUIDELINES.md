# ProVentaris Next — Invoice Import Implementation Guidelines

**Scop:** Ghid de implementare pentru echipa/agentul care construiește import de facturi în ProVentaris Next, bazat pe lecțiile demonstrate în Legacy (vezi `INVOICE_IMPORT_LEGACY_ARCHITECTURE_AND_LESSONS.md`). Acesta **nu este** o copie a arhitecturii Legacy — este o recomandare de implementare, gândită pentru a evita re-investigarea acaceloraşi probleme și pentru a nu repeta aceleași greșeli arhitecturale inițiale.

Fiecare recomandare de mai jos marchează explicit: **[DEMONSTRAT]** (verificat direct în Legacy, fapt) vs. **[RECOMANDARE]** (decizie de design propusă pentru Next, nu obligatorie) vs. **[DATORIE]** (rămâne de investigat/decis în Next).

---

## 1. Principiu general

**[RECOMANDARE]** Pentru orice workflow critic pe Windows care implică Firebase (upload fișiere, tranzacții, orice operație cu stare pe server), preferă **orchestrare server-side** de la început, nu doar ca fix reactiv după un crash descoperit în producție. Motivul nu e doar robustețe — e că defectele native descoperite în Legacy (§3 mai jos) sunt greu de diagnosticat (crash de proces, nu excepție Dart) și costisitoare de reparat după ce arhitectura clientului deja depinde de ele.

## 2. NU copia arhitectura inițială din Legacy

**[DEMONSTRAT — ca eșec, nu ca model]** Prima implementare din Legacy a folosit lanțul: **upload client → tranzacție client → persistență client**. Acest lanț s-a dovedit instabil pe Windows (vezi §3) și a necesitat o refactorizare completă către server-side. Next ar trebui să pornească direct de la arhitectura server-side finală descrisă în documentul Legacy (§3 acolo), nu de la varianta inițială client-heavy.

## 3. API-uri cu risc cunoscut pe Windows

**[DEMONSTRAT, dar STRICT limitat la versiunile testate]**

| API | Plugin | Versiune testată | Comportament confirmat |
|---|---|---|---|
| Upload task (`putData`/stream) | `firebase_storage` | `12.4.10` | Crash nativ de proces — `EventSink::Success()` apelat din thread de background, nu din thread-ul platformei |
| `runTransaction()` | `cloud_firestore` | `5.6.12` | Crash nativ de proces — aceeași clasă de defect, plugin diferit |

**Foarte important:** aceste rezultate sunt valabile **doar pentru versiunile de mai sus**, la momentul testării. Nu presupune automat că versiuni mai noi ale acestor plugin-uri au (sau nu au) același defect — verifică din nou dacă Next fixează o versiune diferită.

## 4. Regulă: "API disponibil" ≠ "API stabil"

**[RECOMANDARE]** Faptul că un API Flutter/Firebase compilează și rulează corect pe alte platforme (Android, iOS, Web) nu garantează stabilitate pe Windows. Plugin-urile Firebase pentru Windows sunt, la data acestei documentații, relativ tinere și au avut cel puțin două defecte arhitecturale confirmate de tip "callback din thread greșit". Orice API nou dintr-un plugin Firebase pe Windows care nu a fost testat explicit sub concurență/volum ar trebui tratat cu suspiciune, nu presupus stabil.

## 5. Server-side ingest operation — formă recomandată

**[RECOMANDARE, bazată pe implementarea demonstrată funcțională în Legacy]** O singură operație server (`onCall` sau echivalent) care face, în ordine:

```
auth (verificare token, automată în onCall)
  → authorization (verificare explicită rol/permisiune, NU presupusă din rules)
  → hash (identitate canonică a documentului sursă)
  → parse (extragere structură din fișierul sursă)
  → persist source (fișierul brut, Storage sau echivalent)
  → persist metadata (document principal)
  → persist lines/items (subcolecție sau echivalent)
  → idempotency check (la fiecare pas de persistență)
  → return canonical result (id-uri, status, flag-uri de persistență)
```

## 6. Identitate canonică a facturii — decide explicit de la început

**[RECOMANDARE]** Legacy a avut inițial un hash client (raw bytes) și abia ulterior a introdus un hash canonic server (UTF-8 decodat, BOM-stripped) ca sursă de adevăr — o divergență descoperită și reparată după implementare, nu proiectată de la început. Next ar trebui să decidă **explicit, din prima iterație**:

- Hash pe bytes brut sau pe conținut semantic (UTF-8 normalizat)?
- Politica BOM — documentată explicit, nu descoperită accidental.
- **Serverul este întotdeauna autoritar** pentru identitatea canonică — clientul nu ia niciodată decizii de dedup pe cont propriu.

## 7. Model de date separat: sursă vs. alocare

**[RECOMANDARE]** Păstrează separate conceptual (și, ideal, la nivel de model de date):
- **Invoice source** — documentul facturii + liniile ei, așa cum a fost parsată (imutabil odată creat, cu excepția câmpurilor de status/linkedJobIds).
- **Invoice allocation** — ce a fost alocat, cui (lucrare), cât (cantitate), cu provenance explicit către linia sursă.

Această separare a funcționat bine în Legacy (§6-7 în documentul Legacy) și a fost cheia pentru idempotență corectă.

## 8. Câmpuri imuabile/sursă vs. derivate la runtime

**[RECOMANDARE]** Marchează explicit (în cod și în schema de date) care câmpuri sunt fixate la parsare (imuabile — denumire, cantitate facturată, preț unitar din sursă) și care sunt derivate/calculate la runtime (cantitate alocată, status alocare). Confuzia dintre cele două a fost o sursă de bug-uri subtile în Legacy dacă nu era gândită explicit.

## 9. ID-uri de linie deterministe

**[DEMONSTRAT, funcțional]** La reimport, liniile existente trebuie **re-citite** (nu regenerate) din subcolecția deja persistată, ordonate consistent (ex. după index original din sursă). Regenerarea ID-urilor la fiecare import ar sparge orice referință externă (provenance în alocări) creată la un import anterior.

## 10. Retry / self-heal — obligatoriu, nu opțional

**[RECOMANDARE]** Orice operație de persistență multi-pas (sursă + metadata + linii, potențial pe sisteme diferite ca Storage + Firestore) trebuie să presupună eșec parțial ca scenariu normal, nu excepțional. Fiecare pas trebuie să verifice existența înainte de a acționa, și reimportul trebuie să repare orice stare parțială fără a crea duplicate. Testat explicit în Legacy pentru combinațiile "Storage există/Firestore lipsește" și invers.

## 11. Etape de ingestie fișier — separate explicit

**[RECOMANDARE, pentru roadmap Next]** Nu construi un singur pipeline monolitic care presupune toate sursele posibile de la început. Tratează separat:

1. **XML** (structurat, parsare directă — cazul acoperit complet de Legacy)
2. **PDF text** (extras text, parsare eurisitică — mai fragil)
3. **OCR** (scanări, cel mai fragil, necesită validare umană mai atentă)
4. **AI matching** (ultimul strat, doar pentru ce nu s-a putut rezolva determinist mai sus)

Fiecare etapă are propriul nivel de încredere și propriile moduri de eșec — nu le amesteca într-o singură cale de cod.

## 12. Matching în catalog — determinist întâi, AI ulterior

**[RECOMANDARE]** Legacy a folosit exclusiv exact match (denumire normalizată + UM), fără AI. Recomandare pentru Next: păstrează exact match ca prim nivel (rapid, predictibil, zero cost), și adaugă AI/fuzzy matching **doar** ca al doilea nivel, pentru cazurile nerezolvate de exact match, cu un scor de încredere explicit și un pas de review uman înainte de a accepta automat o potrivire incertă. Nu suprascrie niciodată date de catalog existente automat pe baza unui match AI.

## 13. Regulă Navigator — `dialogContext`

**[DEMONSTRAT, ca bug real]** Orice dialog care poate face `pop()` trebuie să folosească explicit propriul `context` (capturat la deschiderea dialogului, ex. `dialogContext`), niciodată `context`-ul paginii părinte. Confuzia a cauzat un bug real în Legacy (§14, BUG #1) — navigarea nedorită pe stack-ul greșit. Acoperă cu test de regresie explicit orice dialog nou similar.

## 14. Diagnosticarea defectelor native pe plugin-uri Windows

**[RECOMANDARE, metodologie confirmată eficientă în Legacy]** Dacă apare un crash de proces (nu excepție Dart) pe Windows, implicând un plugin Firebase:

1. Adaugă markeri de instrumentare fin-granulari (înainte/după fiecare apel suspect) pentru a izola exact punctul de crash.
2. Construiește un harness minimal, izolat, care reproduce doar operația suspectă (fără restul aplicației).
3. Inspectează direct sursa C++ a plugin-ului (dacă e disponibilă) pentru apeluri `EventSink`/callback din thread greșit.
4. **Nu presupune că același simptom (crash de proces) = aceeași cauză** — verifică explicit API-ul exact folosit în fiecare caz nou; Legacy a confirmat DOUĂ cauze diferite (dar din aceeași clasă de defect) în DOUĂ plugin-uri diferite.
5. Elimină instrumentarea temporară (markeri) după ce cauza e confirmată și fix-ul e validat — nu o lăsa în build-uri de producție.

## 15. UI responsive — evită layout-uri rigide

**[RECOMANDARE]** Legacy a avut cel puțin două bug-uri de overflow UI (rânduri de filtre, carduri de calendar) cauzate de `Row`/dropdown-uri fără constrângeri flexibile. Pentru orice rând orizontal cu conținut variabil (text, dropdown-uri, etichete), folosește `Wrap`, `Flexible`, `Expanded` sau `isExpanded` (pentru `DropdownButtonFormField`) în loc de un `Row` rigid care presupune că totul încape mereu la lățimea proiectată.

## 16. CI

**[DEMONSTRAT, funcțional în Legacy]**
- **Pin explicit versiunea Flutter** în workflow-ul CI — nu te baza pe `channel: stable` fără versiune fixă.
- **Clean checkout trebuie să funcționeze fără niciun fișier de config local/gitignored** — orice import static către un fișier care nu există pe un checkout curat sparge CI-ul, indiferent cât de rar e folosit acel cod la runtime.
- **Android CI trebuie să specifice explicit flavor-ul standard** dacă există multiple flavors — altfel Gradle construiește implicit toate flavor-urile configurate.

## 17. GitHub Actions — pin pe SHA

**[RECOMANDARE]** Dacă Next are deja o politică de pin pe SHA pentru GitHub Actions (baseline existent), păstreaz-o și pentru orice acțiune nouă adăugată în contextul modulului de import facturi — nu introduce excepții per-modul de la politica generală de securitate CI a proiectului Next.

## 18. Teste necesare (backend + client)

**[RECOMANDARE, bazat pe acoperirea demonstrată eficientă în Legacy]**

Backend:
- Parsare corectă a structurii sursă (header + linii)
- Idempotență completă (creare, reimport, reimport după eșec parțial pe fiecare combinație de sisteme de persistență)
- Preservarea câmpurilor mutabile (status, referințe externe) la reimport
- Propagare corectă a erorilor de tranzacție

Client:
- Regresie Navigator/dialog context
- Absența structurală a oricărui API cunoscut ca riscant (verificare prin sursă, nu doar prin comportament la runtime)
- Validare cantități (limite, cazuri limită)
- Mapping alocare → entitate finală

## 19. "DO NOT RE-INVESTIGATE FROM ZERO"

Tabel de triaj rapid — dacă un simptom similar apare în Next, verifică întâi aici înainte de investigație de la zero:

| Simptom | Verifică întâi |
|---|---|
| Dialogul de confirmare navighează greșit / se închide pagina în loc de dialog | `BuildContext` folosit de `Navigator.pop()` — trebuie să fie `dialogContext`, nu context-ul paginii părinte |
| Procesul Windows moare (nu excepție) în timpul unui upload Storage | Comportamentul thread-ului nativ al plugin-ului `firebase_storage` la versiunea exactă folosită — nu presupune automat că e mediul/hardware-ul |
| Procesul Windows moare (nu excepție) în timpul unei tranzacții Firestore | Izolează specific `runTransaction()` — un `.get()`/`.set()`/`.update()` simplu poate fi complet safe chiar dacă tranzacția nu e |
| Factură duplicată apare la reimport | Verifică politica de hash/BOM — posibilă divergență între hash client și hash server canonic |
| Firestore are documentul dar Storage nu are fișierul (sau invers) | Forțează reconciliere server-side explicită, nu presupune stare coerentă automat |

## 20. Faze de implementare recomandate pentru Next

**[RECOMANDARE]**

**Faza 1** — Model de domeniu + ingestie XML (server-side de la început, conform §2 și §5)

**Faza 2** — Workspace de alocare (preview, selecție, editare cantitate, provenance)

**Faza 3** — Matching catalog (exact match întâi, conform §12)

**Faza 4** — Ingestie PDF (text extraction)

**Faza 5** — OCR (pentru scanări)

**Faza 6** — Matching asistat de AI (ultimul strat, cu review uman pentru încredere scăzută)

---

## 21. Build and signing lessons transferred from Legacy

**[DEMONSTRAT — incident real în Legacy]** După merge-ul funcționalității de invoice-import în
Legacy, un build Android "reușit" (`versionName`/`versionCode` corecte, construit din sursa corectă)
s-a dovedit **nedistribuibil**: era semnat cu certificatul debug efemer, diferit de certificatul de
producție cu care era deja semnată o instalare anterioară pe device — Android a refuzat upgrade-ul,
lăsând aplicația veche activă, fără un mesaj de eroare evident pentru utilizator. Detalii complete:
`BUILD_AND_RELEASE_POLICY.md` (repo Legacy), §7 și §12.

Recomandări directe pentru Next, ca să nu se repete acest incident:

- **Path absolut obligatoriu** în orice raport de build — niciodată un path relativ (`build\...`)
  ca unic identificator al unui artefact. Dacă build-ul e produs într-un worktree temporar,
  raportul trebuie să marcheze explicit `TEMPORARY BUILD PATH — DO NOT INSTALL FROM HERE`.
- **Build manifest structurat** per versiune (branch, HEAD, versiune, platformă, flavor, package,
  signing subject + fingerprint, SHA-256, distribution status) — nu un simplu "build-ul a reușit".
- **Flavor explicit obligatoriu** la orice build Android multi-flavor (`--flavor <nume>`), niciodată
  implicit.
- **Verifică metadata APK-ului direct din binar** (`aapt dump badging` sau echivalent) — nu presupune
  că `versionName`/`versionCode` din artefact corespund cu ce e în sursă, fără verificare explicită.
- **Verifică fingerprint-ul de semnare** (`apksigner verify --print-certs` sau echivalent) înainte de
  a declara orice artefact Android gata pentru instalare pe un device cu o versiune anterioară deja
  instalată.
- **"debug-signed release" ≠ "distributable"** — un build `--release` fără o configurație de semnare
  de producție validă e semnat automat cu certificatul debug; asta nu se vede din numele fișierului
  sau din faptul că build-ul a reușit, trebuie verificat explicit.
- **Niciun artefact nu e canonic direct din worktree-ul temporar** — trebuie copiat într-un director
  permanent, iar hash-ul SHA-256 al copiei trebuie confirmat identic cu sursa, înainte de a fi
  considerat utilizabil.
- **Checklist de release gates** înainte de a declara un artefact distribuibil: sursă (branch/HEAD),
  versiune (din metadata artefactului), flavor, semnare (certificat de producție confirmat), hash
  (sursă == copie permanentă), smoke test manual, aprobare explicită de publicare — separate, în
  această ordine.
- **GitHub Actions rămâne pinned pe SHA** în Next, conform baseline-ului de securitate CI existent —
  politica de build/release de mai sus nu înlocuiește, ci completează, disciplina CI deja stabilită.

---

## Referință

Detaliile complete ale implementării Legacy (arhitectură, bug-uri, teste, checkpoint) sunt documentate în `INVOICE_IMPORT_LEGACY_ARCHITECTURE_AND_LESSONS.md`, din același director. Politica de build/release și incidentul de semnare Android sunt documentate integral în `BUILD_AND_RELEASE_POLICY.md` (repo Legacy).
