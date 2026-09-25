# Invoice Import — Legacy Architecture & Lessons

**Status:** Documentat post-implementare, după validare end-to-end și merge în `master`.
**Checkpoint sursă:** `master @ 460d868` (Merge pull request #1 from `feature/invoice-import-only`)
**Versiune aplicație:** `1.13.0+113`

Acest document descrie modulul "Import materiale din factură" așa cum a fost implementat, testat și mergeuit în ProVentaris Legacy (Flutter/Firebase, PRO TERM SRL). Este scris pentru cititori care nu au fost parte din implementare — fiecare afirmație marchează explicit dacă este **demonstrat** (verificat direct, prin test sau observație), **decizie de design** (aleasă deliberat, cu motivația ei), sau **datorie tehnică** (cunoscută, neremediată).

---

## 1. Scopul modulului

Înainte de acest modul, introducerea materialelor unei facturi de furnizor într-o lucrare se făcea 100% manual — utilizatorul admin deschidea factura pe hârtie/PDF și tasta fiecare poziție (denumire, cantitate, preț) direct în formularul lucrării. Pentru facturi cu zeci de poziții, asta însemna zeci de minute de muncă repetitivă și risc de eroare de transcriere.

Modulul elimină acest pas: importă direct fișierul XML e-Factura (standardul românesc UBL, generat de orice sistem de facturare electronică conform), extrage automat toate liniile, și lasă utilizatorul doar să **selecteze care linii vrea să aloce** lucrării curente și **să editeze cantitatea alocată** per linie (nu neapărat toată cantitatea facturată — vezi secțiunea 8).

## 2. Fluxul final utilizator

```
Lucrare (JobDetailsPage)
  → buton "Import materiale din factură"
  → selectare fișier XML (file picker local)
  → upload către server + parsare (server-side, vezi §3)
  → preview: toate liniile facturii, editabile
  → utilizatorul selectează liniile relevante
  → utilizatorul editează allocatedQty per linie (implicit = cantitatea facturată)
  → confirmare
  → materialele apar în lista lucrării (job materials), cu provenance (§7)
  → persistență completă (Storage + Firestore)
  → reimport ulterior al aceleiași facturi → dedup automat (§12)
```

## 3. Arhitectura finală

### Client Flutter (`lib/features/jobs/invoice_import/`)

Responsabilități:
- **File picker** — selectare XML local (`file_picker`)
- **Preview** — afișare linii parsate, cu UM prietenoasă (§10)
- **Selection** — checkbox per linie
- **Quantity editing** — editare `allocatedQty` per linie selectată, cu validare (§8)
- **Mapping** — construirea obiectelor `JobMaterial` din liniile selectate
- **Job persistence** — `.set(merge: true)` pe documentul lucrării (**demonstrat funcțional și sigur** — vezi §15, nu confunda cu bug-urile de mai jos)
- **Catalog exact match** — potrivire denumire+UM cu catalogul de materiale existent (§11)
- **Post-save allocation metadata** — `markInvoiceAllocated()`, `.update()` simplu pe documentul facturii (**demonstrat funcțional și sigur**)

Fișiere cheie: `supplier_invoice_import_page.dart` (orchestrare UI), `supplier_invoice_repository.dart` (acces Firestore read-only + markAllocated), `supplier_invoice_parser_client.dart` (apel către Cloud Function), `supplier_invoice_catalog_matcher.dart`, `supplier_invoice_job_material_mapper.dart`, `supplier_invoice_unit_labels.dart`, `supplier_invoice_import_repair.dart` (self-heal client-side pentru reconciliere).

### Server — codebase Functions izolat (`functions_invoice_import/`)

**De ce izolat de `functions/` (default):** deploy-ul codebase-ului default legacy era deja blocant/fragil; un codebase separat permite deploy scoped, fără riscul de a atinge `availability`/WhatsApp sau restul funcțiilor legacy. Vezi §19.

Responsabilități:
- Autentificare (`onCall` — Firebase Auth token verificat automat de runtime)
- Autorizare admin (verificare explicită a rolului din Firestore, **nu doar autentificare** — vezi §18)
- Validare XML (structură UBL, dimensiune)
- Hash canonic (§12)
- Parsare (extragere header + linii din UBL)
- Persistență Storage (XML sursă)
- Persistență Firestore (metadata factură + linii)
- Idempotență (§13)
- Self-heal (reconciliere Storage/Firestore parțial eșuate)

Fișiere cheie: `functions_invoice_import/index.js` (entry point `onCall`), `functions_invoice_import/supplier_invoice_parse.js` (logica principală — parsare, hash, persistență, idempotență).

## 4. Endpoint / Cloud Function

```
parseSupplierInvoiceXml
```
Funcție `onCall` (Firebase Functions v2), codebase izolat `invoice-import`. Primește bytes XML (base64) + metadata (uid), returnează header parsat + linii + `invoiceId` canonic + flag-uri de persistență.

## 5. Storage path

```
supplier_invoices/{uid}/{invoiceId}/source.xml
```
`{uid}` = utilizatorul care a inițiat importul. `{invoiceId}` = hash canonic (§12), determinist — reimportul aceleiași facturi de către același sau alt admin produce același `invoiceId`, deci același path.

## 6. Firestore model

```
supplier_invoices/{invoiceId}
supplier_invoices/{invoiceId}/lines/{lineDocId}
```
Documentul `{invoiceId}` conține header-ul facturii (furnizor, dată, `status`, `linkedJobIds` — lista lucrărilor care au alocat linii din această factură, **acumulativă**, niciodată suprascrisă la reimport). Subcolecția `lines` conține câte un document per linie facturată, cu `lineDocId` determinist (ordonat după `lineIndex`, re-citit — nu regenerat — la reimport, pentru consistență, vezi §13).

## 7. Provenance în `JobRecord.materials`

Fiecare material alocat dintr-o factură importată păstrează în documentul lucrării:
- `sourceInvoiceId` — factura sursă
- `sourceInvoiceLineId` — `lineDocId`-ul din Firestore
- `sourceInvoiceSourceLineId` — ID-ul de linie declarat de furnizor în XML (`cbc:ID`), pentru trasabilitate față de documentul original
- `allocatedQty` — cantitatea efectiv alocată acestei lucrări (vezi §8)

Acest lanț de provenance permite: (a) prevenirea alocării duplicate a aceleiași linii în aceeași lucrare, (b) afișarea originii materialului în UI, (c) audit.

## 8. Cantități — **decizie de design**

**Cantitatea facturată ≠ cantitatea alocată.** O factură poate conține 100 bucăți dintr-un material, dar o singură lucrare poate folosi doar 12. Regula de validare aplicată:

```
0 < allocatedQty <= invoiced quantity
```

Alocarea parțială e permisă și este cazul normal de utilizare, nu o excepție.

## 9. Prețuri — **decizie de design**

```
price = unitPriceNoVat
realPrice = unitPriceNoVat
```

Ambele câmpuri din `JobMaterial` sunt setate la prețul unitar fără TVA din factură. **Motivația Legacy:** restul aplicației (calculul devizelor, marjelor) folosește deja convenția `price`/`realPrice` ca preț de cost fără TVA; facturile de la furnizori conțin explicit acest câmp (`cbc:PriceAmount` în UBL), deci nu e nevoie de nicio conversie sau presupunere — valoarea vine direct din sursă, fără interpretare.

## 10. Unități de măsură

Codurile UBL (UNECE Rec 20) sunt convertite la etichete prietenoase pentru UI: `H87` → `buc`, `MTR` → `m`, etc. (`supplier_invoice_unit_labels.dart`, testat exhaustiv).

**Decizie explicită de design, nu omisiune:** **nu există conversie automată** bucată × lungime → metri liniari sau similare. Dacă furnizorul facturează în `H87` (bucată) un produs care conceptual e vândut la metru, sistemul afișează `buc`, punct. Orice conversie dimensională rămâne responsabilitatea utilizatorului la momentul alocării cantității.

## 11. Matching în catalog

**Exact match, normalized name + UM.** Nu există fuzzy matching, nu există AI. Dacă denumirea normalizată (case-insensitive, whitespace normalizat) și unitatea de măsură coincid exact cu un material existent în catalog, se face match; altfel, se creează o intrare nouă. **Niciodată nu se suprascrie prețul unui material existent din catalog** — matching-ul afectează doar alocarea, nu modifică date de catalog.

## 12. Hash / deduplicare

Există **două hash-uri distincte**, cu roluri diferite:

- **Hash client (legacy, "raw bytes")** — SHA-256 calculat direct pe bytes-ul brut al fișierului XML, așa cum a fost citit de pe disc. Folosit istoric pentru un lookup rapid local, **păstrat acum doar ca fallback de diagnostic/legacy pentru fișiere cu BOM**.
- **Hash canonic server** — SHA-256 calculat pe conținutul XML **decodat UTF-8** (după eliminarea explicită a BOM-ului `U+FEFF`, dacă există). Acesta este `invoiceId`-ul autoritar, folosit pentru toate operațiile de persistență/dedup.

**Diferența dintre cele două apare exclusiv la fișiere cu BOM UTF-8** — hash-ul pe bytes brut include BOM-ul, hash-ul canonic nu. Pentru fișiere fără BOM, cele două hash-uri sunt **demonstrat identice** (9 teste dedicate, `test/supplier_invoice_hash_dedup_test.dart`).

**Server-ul este întotdeauna autoritar.** Clientul nu mai ia nicio decizie de dedup pe baza hash-ului local — trimite fișierul la server, primește `invoiceId`-ul canonic înapoi, și îl folosește direct. Hash-ul local e verificat DOAR ca fallback, când există un mismatch BOM cunoscut, pentru compatibilitate cu facturi importate înainte de introducerea hash-ului canonic.

## 13. Idempotență

Persistența server-side (atât Storage cât și Firestore) este proiectată explicit pentru re-execuție sigură:

- **Storage există, Firestore lipsește** (import anterior eșuat parțial) → reimportul recreează metadata Firestore lipsă, fără a re-uploada XML-ul.
- **Firestore există, Storage lipsește** → reimportul reconstruiește fișierul Storage lipsă.
- **Retry complet safe** — reimportul aceleiași facturi de N ori produce exact aceleași `lineDocId`-uri (re-citite din subcolecția existentă, ordonate după `lineIndex`, **niciodată regenerate**), fără duplicate.
- **`linkedJobIds` și `status` sunt păstrate**, niciodată suprascrise la reimport — doar extinse (adăugare, nu înlocuire).

Acestea sunt **demonstrate** prin 8 teste dedicate (`functions_invoice_import/test/supplier_invoice_metadata_persistence.test.js`) plus teste de self-heal pentru Storage (`supplier_invoice_source_persistence.test.js`).

## 14. Cele trei probleme majore descoperite

### BUG #1 — Context greșit de `BuildContext` în dialogul de confirmare

**Simptom:** în anumite secvențe de interacțiune, `Navigator.pop()` din dialogul de confirmare a importului ajungea să închidă ruta paginii lucrării, nu dialogul însuși.

**Cauza:** dialogul folosea `context`-ul paginii părinte în loc de propriul `context` (nested `Navigator`), deci `pop()` naviga pe stack-ul greșit.

**Fix:** dialogul folosește exclusiv propriul `dialogContext`, capturat explicit la deschidere.

**Test de regresie:** `test/supplier_invoice_import_confirm_dialog_test.dart` — verifică explicit că `pop()` nu atinge niciodată ruta paginii, rezultatul final fiind întotdeauna outcome-ul tipizat al dialogului, fără excepție.

### BUG #2 — `firebase_storage` pe Windows: crash nativ de proces

**Context:** `firebase_storage` versiune pinned `12.4.10` (vezi `pubspec.yaml`).

**Simptom:** procesul aplicației (native, Windows) murea complet (nu excepție Dart capturabilă) în timpul upload-ului XML-ului sursă către Storage, mai frecvent sub concurență (upload-uri paralele sau succesive rapide).

**Cauza (confirmată prin inspecție directă a sursei C++ a plugin-ului):** handler-ul `PutDataStreamHandler::OnListenInternal` apelează `EventSink::Success()` dintr-un thread de background al Firebase C++ SDK, nu din thread-ul platformei Flutter. Aceasta este o încălcare a contractului Flutter Engine (`EventSink` trebuie apelat doar din thread-ul platformei) — un defect arhitectural în plugin, nu o eroare de utilizare a API-ului.

**Reproducere:** confirmată printr-un harness minimal izolat, cu upload-uri concurente declanșând crash-ul consistent.

**Fix:** eliminarea completă a upload-ului client către `firebase_storage` — XML-ul sursă este trimis ca bytes către Cloud Function (`onCall`), iar persistența în Storage se face **exclusiv server-side**, prin Admin SDK (imun la acest defect, care există doar în plugin-ul client Windows).

### BUG #3 — `cloud_firestore.runTransaction()` pe Windows: crash nativ de proces

**Context:** `cloud_firestore` versiune pinned `5.6.12`.

**Simptom:** proces mort (același tip de crash ca BUG #2) în timpul persistenței metadatei/liniilor facturii, specific în interiorul unui apel `runTransaction()`.

**Cauza (confirmată prin inspecție directă a sursei C++):** `TransactionStreamHandler::OnListenInternal`, în callback-ul intern al `RunTransaction`, apelează `EventSink::Success()` din același tip de thread de background greșit — **exact aceeași clasă de defect arhitectural ca BUG #2**, în alt plugin.

**Verificare diferențială:** un `.get()` simplu (read, fără transacție) pe aceeași colecție **funcționează corect** — problema este specifică `runTransaction()`, nu Firestore client în general (vezi §15, foarte important să nu se generalizeze).

**Fix:** eliminarea completă a `cloud_firestore.runTransaction()` client-side — persistența metadatei facturii și a liniilor se face **exclusiv server-side**, prin Admin SDK (`db.runTransaction()` pe server, imun la defectul din pluginul client Windows).

## 15. ATENȚIE — nu generaliza defectul

Este o greșeală ușor de făcut să tragi concluzia "toate scrierile Firestore client-side pe Windows sunt nesigure". **Nu este adevărat, demonstrat explicit:**

- `.set(merge: true)` pe documentul lucrării (job persistence, client-side) — **funcționează corect**, folosit activ în producție.
- `.update()` simplu în `markInvoiceAllocated()` (client-side) — **funcționează corect**.

Defectul confirmat este specific și restrâns la: `firebase_storage` upload task (`PutDataStreamHandler`) și `cloud_firestore.runTransaction()` (`TransactionStreamHandler`), ambele pe Windows, la versiunile pinned menționate mai sus. Orice viitoare investigație a unui crash similar **trebuie să identifice explicit API-ul exact folosit** (nu presupune automat aceeași cauză) — vezi Documentul 2, §14.

## 16. Testare manuală reală (validare RC)

Efectuată pe build Windows release, cont admin, date reale:
- Import 1 linie
- Import 5 linii
- 2 cantități modificate manual la alocare
- Import 15 linii dintr-o altă factură
- Import factură complet diferită (furnizor diferit)
- Persistență confirmată după ieșire/reintrare în lucrare (fără restart aplicație)
- Persistență confirmată după **închiderea completă** a aplicației și repornire
- Reimport aceeași factură → dedup confirmat, liniile deja alocate recunoscute și dezactivate automat din selecție

## 17. Teste permanente (suite automate)

- Regresie Navigator/dialog context (`supplier_invoice_import_confirm_dialog_test.dart`)
- Absența oricărui apel client către `firebase_storage` (`supplier_invoice_repository_no_storage_test.dart`, verificare structurală prin sursă)
- Persistență sursă server-side (`functions_invoice_import/test/supplier_invoice_source_persistence.test.js`)
- Persistență metadată server-side (`functions_invoice_import/test/supplier_invoice_metadata_persistence.test.js`)
- Dedup / BOM (`test/supplier_invoice_hash_dedup_test.dart`)
- Reconciliere / self-heal (parte din suitele de persistență de mai sus)
- Validare cantități (`test/supplier_invoice_allocation_validation_test.dart`)
- Mapping alocare → material lucrare (`test/supplier_invoice_job_material_mapper_test.dart`)
- Matching catalog (`test/supplier_invoice_catalog_matcher_test.dart`)
- Unități de măsură (`test/supplier_invoice_unit_labels_test.dart`)

Total confirmat la ultima validare: **389/389 Flutter**, **41/41 backend `functions_invoice_import`**.

## 18. Securitate

- Toate operațiile de import/persistență sunt **strict admin-only** — verificat explicit server-side (nu doar prin `firestore.rules`; funcția `onCall` verifică rolul din Firestore înainte de orice operație).
- **Important:** Admin SDK server-side face bypass la `firestore.rules`/`storage.rules` prin design (rules-urile se aplică doar clienților). De aceea, autorizarea admin **trebuie verificată explicit în codul funcției**, nu se poate presupune că rules-urile o acoperă.
- Dimensiune maximă XML — 5MB (validat atât server-side cât și în `storage.rules`).
- Path-uri Storage controlate exclusiv de server (`{uid}` din contextul de autentificare, nu din input arbitrar al clientului).
- Fără ACL public — fallback deny-by-default pe orice path neenumerat explicit.

## 19. Deployment

Codebase Functions **izolat**: `invoice-import` (director `functions_invoice_import/`), separat de codebase-ul default (`functions/`).

Deploy scoped, **niciodată** `firebase deploy` broad:
```
firebase deploy --only functions:invoice-import
```

**Motivație:** deploy-ul codebase-ului default legacy era deja fragil/blocant la momentul implementării; izolarea permite iterație și deploy pe funcționalitatea nouă fără risc asupra `availability`/WhatsApp/restul funcțiilor existente.

## 20. Lecții CI

- **Clean checkout trebuie să funcționeze fără config local/gitignored** — un fișier de config specific unui alt client (Costel) importat static, dar gitignored, sparge orice checkout curat (CI inclus). Soluție: stub versionat + `git update-index --skip-worktree` pentru developeri.
- **Pin explicit versiunea Flutter în CI** (`3.41.6` în acest caz) — `channel: stable` fără versiune fixă produce drift necontrolat în timp, introducând lint-uri/warning-uri noi care nu au nicio legătură cu schimbările reale dintr-un PR.
- **`--no-fatal-infos`** — politică explicită: ERROR și WARNING rămân fatale pentru CI, INFO devine non-fatal (raportat, dar nu blochează). Motivație: info-uri de stil preexistente nu trebuie să blocheze integrarea unei funcționalități noi.
- **Android CI trebuie să specifice explicit `--flavor proterm`** — fără flavor explicit, Gradle construiește implicit **toate** flavor-urile configurate (inclusiv Costel), eșuând pe config-ul Costel absent din CI (local/privat, per design).

## 21. Checkpoint final

```
master @ 460d868
Merge pull request #1 from protermarad-hash/feature/invoice-import-only
version: 1.13.0+113
```

## 22. Build-uri canonice

Windows + Android (flavor `proterm`), construite exact din checkpoint-ul de mai sus. Locația permanentă a fost creată separat de acest repository — vezi secțiunea **Canonical Release Artifacts** de mai jos.

## 23. Datorii tehnice separate (cunoscute, neremediate)

- **Audit rules repo vs. LIVE byte-for-byte** — `firestore.rules`/`storage.rules` au fost reconciliate manual cu starea Console la un moment dat; nu există un mecanism automat care să confirme continuu că repo-ul rămâne identic cu ce e efectiv deployat.
- **Drift `functions/package.json` vs. `functions/package-lock.json`** — lockfile-ul codebase-ului default conținea (înainte de curățare, pe branch-ul acestei funcționalități) o versiune desincronizată de propriul `package.json` (node 20 vs 22, `express` lipsă din lock) — drift preexistent pe `master`, nelegat de acest modul, nerezolvat încă la nivel de `master`.
- **Lint infos preexistente** — 14 `use_key_in_widget_constructors` în `lib/features/oferte/oferte_dialogs/`, nerezolvate (non-blocante prin politica `--no-fatal-infos`).
- **Audit alte utilizări posibile de `firebase_storage`/`cloud_firestore.runTransaction()` pe Windows** în restul aplicației legacy — bug-urile #2 și #3 au fost confirmate și corectate strict în modulul invoice-import; nu s-a făcut un audit exhaustiv al **restului** codebase-ului pentru alte utilizări ale acelorași API-uri cu risc.

---

## Release/build incident discovered after feature merge

După merge-ul acestei funcționalități, un build Android canonic (`1.13.0+113`) construit corect din
sursă a fost semnat cu certificatul **debug** (nicio configurație de semnare de producție disponibilă
în mediul de build), diferit de certificatul de producție cu care era deja semnată o instalare
anterioară a aplicației pe un device de test — Android a refuzat upgrade-ul, iar aplicația veche a
rămas activă. Cauza nu a avut nicio legătură cu codul sau versiunea din sursă (ambele corecte),
exclusiv cu semnătura APK-ului.

Incidentul complet, politica de build/release introdusă ca urmare, și definiția stărilor de
distribuție (`TEST ONLY` vs. `DISTRIBUTABLE`) sunt documentate integral în
**`BUILD_AND_RELEASE_POLICY.md`** — nu duplicate aici.

---

## Canonical Release Artifacts

**Version:** `1.13.0+113`
**Source:** `master @ 460d868`

**Windows:**
```
C:\Users\Lenovo\develop\releases\ProVentaris\1.13.0+113\windows\
```

**Android (flavor proterm):**
```
C:\Users\Lenovo\develop\releases\ProVentaris\1.13.0+113\android\app-proterm-release.apk
```

### SHA-256

| Fișier | SHA-256 |
|---|---|
| `ProVentaris.exe` | `88f2781ed9af57d44b2bbd40316cdd6112398959683b3795f3065fc7f57d23f8` |
| `data\app.so` | `57d8807c1b89eadb93a7789158fd6be14c4890a9ddc44aa7d8ca49ca18110824` |
| `app-proterm-release.apk` | `59ce9418f0152055747ffc577a7685a4e0b4108fba80d038bbeb893c08d04118` |

Hash-urile de mai sus au fost verificate identice între build-ul sursă (worktree temporar de compilare) și copia permanentă de mai sus.

**Notă:** binarele NU sunt incluse în acest repository Git — locația permanentă de mai sus este externă repository-ului.
