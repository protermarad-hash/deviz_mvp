# ProVentaris Legacy RC 120 — controlul concurenței la sincronizare (clienți, oferte, lucrări)

Branch: `fix/sync-revision-conflicts` (din `master` `6d807f0`). **Local, nepublicat, fără PROD.**

## 1. Cauza demonstrată

Teste QA izolate, cu Firebase Emulator, 15.10.2026:

1. A salvează clientul X cu serverul inaccesibil (în jur de 19:49).
2. B salvează o versiune mai nouă (19:50:05).
3. A revine și sincronizează (19:50:12).

**Rezultat: versiunea veche a lui A a înlocuit-o pe cea a lui B.**

Ce produce defectul, identic în 113, 118 și 119:

- `FirebaseClientiRepository` / `FirebaseOferteRepository` / `FirebaseLucrariRepository` scriu **orb** (`set(merge: true)`);
- clienții și ofertele **restampilează** `updated_at` cu ora trimiterii (`DateTime.now()`), deci o editare veche trimisă târziu pare nouă;
- `firestore.rules` nu verifică versiunea (`allow read, write: if isOperational()`).

## 2. Căi de pierdere identificate în audit

| # | Cale | Efect | Stare în 120 |
|---|---|---|---|
| P1 | Scriere oarbă întârziată (coadă sau scriere SDK rămasă în așteptare) | suprascrie versiunea mai nouă a altui dispozitiv | **remediat** pe Android (tranzacție) și pe Windows (verificare cu citire de pe server, neatomică); atomic doar cu reguli (§5) |
| P2 | `_listClientsCloudMerged` înlocuia versiunea locală cu cea din cloud | editarea locală nesincronizată dispare local; o editare ulterioară o poate pierde definitiv | **remediat**: entitățile protejate păstrează versiunea locală |
| P3 | `replaceOffers(cloud)` în 6 pagini | ofertele create sau editate offline erau șterse local | **remediat**: `mergeOffersFromCloud` |
| P4 | Încărcarea „local-only” a clienților (batch orb) | un client șters pe alt dispozitiv era readus la viață | **remediat**: scriere condiționată; conflict `deleted_remotely` |
| P5 | `clearStale` după 10 eșecuri | elementul din coadă era șters silențios | **remediat**: payload păstrat ca conflict `retry_exhausted` |
| P6 | `deleteClient`: ștergere oarbă, fără timeout | blocare pe server inaccesibil; ștergea editări de la distanță | **remediat**: ștergere condiționată, 10 s |
| P7 | Aplicații vechi (113/118/119) care scriu orb | pot suprascrie orice versiune nouă | **NU se poate remedia din client** (§5) |

Alte aplicații: ProVentaris Next folosește alt proiect Firebase (`proterm-proventaris-next-dev`) și nu scrie în `devizpro-ultra-pilot`.

## 3. Modelul de concurență (client)

- **`_rev`** pe document (întreg), incrementat **doar** de o scriere condiționată. `_rev_writer` reține dispozitivul, pentru diagnostic.
- **Baza locală** per entitate: revizia **și** amprenta SHA-256 a conținutului versiunii de server pe care a pornit editarea. Amprenta folosește JSON canonic: chei sortate, `int`/`double` normalizate, `null` tratat ca lipsă, fără câmpuri volatile.
  - Baza se înregistrează **numai** din citiri confirmate de server (nu din cache, nu din scrieri în așteptare).
  - Baza **nu se actualizează** pentru entitățile protejate (modificări nesincronizate sau conflict deschis).
- **Scrierea** (tranzacție pe Android; citire de pe server + decizie + scriere pe Windows):

  | Situație pe server | Decizie |
  |---|---|
  | conținut identic cu cel local | **aplicat** (idempotent; acoperă confirmarea pierdută după commit) |
  | exact la bază (revizie + amprentă) | se scrie, `_rev + 1` |
  | lipsă și nevăzut niciodată | se creează, `_rev = 1` |
  | lipsă, dar văzut anterior | **conflict** `deleted_remotely` (nu se readuce la viață) |
  | altceva | **conflict** `concurrent_edit`: nu se scrie nimic |

- **La conflict**:
  - varianta locală **rămâne** local;
  - perechea local/server se salvează în `SyncConflictStore` (un conflict per entitate);
  - elementul din coadă este **parcat** (nu se mai retrimite orb);
  - nicio ștergere automată.
- **Revizia editorului:** înregistrările locale poartă `syncRev` (`_rev` al versiunii de server din care provin). Dacă baza a avansat între timp la versiunea **altui** dispozitiv (`ownWrite = false`), scrierea devine conflict, nu suprascriere.
- **Deja aplicat:** un element din coadă al cărui conținut este deja baza (scrierea imediată reușise) nu mai este trimis și nu produce conflict fals. Baza nu avansează.
- **Blocări:**
  - `KeyedMutex` pentru coadă, baze și conflicte;
  - `runEntitySyncLocked` între îmbinarea din cloud și perechea „salvare locală + coadă” (oferte, lucrări);
  - blocarea existentă pentru clienți.
- **Prima îmbinare după actualizare:** înregistrările doar-locale neprotejate se păstrează local, cu conflict `unknown_on_upgrade`. Nu se încarcă automat.
- **Ordinea nu se stabilește după `updated_at`.** Câmpul păstrează ora editării, doar informativ.

## 4. Compatibilitate

| Situație | Comportament în 120 |
|---|---|
| Documente existente fără `_rev` | tratate ca revizia 0; prima scriere 120 pe baza citită → `_rev = 1` (test PASS) |
| Elemente vechi din coadă (119), fără bază | conflict dacă serverul diferă; aplicat dacă e identic; creat dacă lipsește (conservator, fără pierderi) |
| Aplicație veche care scrie după 120 | **detectată** prin amprentă: 120 NU o suprascrie, conflict (test PASS, unitar și pe Windows) |
| 120 scrie, apoi o aplicație veche scrie orb | aplicația veche **suprascrie** versiunea 120 (P7). Inevitabil fără reguli de server |
| Aplicație veche, document încă fără `_rev`, cu regulile M3 | scrierea veche e **respinsă** (R4); 120 o poate migra cu `_rev = 1` |
| Dispozitive 113 Debug | 120 oficial e refuzat de Android (certificat diferit); doar după procedura de migrare per dispozitiv (ca Fold7) |

## 5. Gate: protecția completă cere modificări server-side și blochează clienții vechi

Protecția nu poate fi garantată numai din client:

1. **Aplicațiile vechi** (P7) scriu orb. Doar regulile Firestore le pot respinge, iar aceleași reguli **blochează toate scrierile** lor pe clienți, oferte și lucrări.
   - Nu pot fi obligate să se actualizeze: `forceUpdate` nu e implementat.
   - Elementele lor respinse se șterg din coadă după 10 eșecuri (P5 există în versiunile vechi).
2. **Pe Windows**, tranzacțiile pluginului opresc aplicația. Verificarea fără tranzacție nu e atomică. Regulile M3 închid fereastra pentru actualizări (S5 PASS), dar **nu și pentru ștergeri** (§8).

**Conform gate-ului, nu se face nicio schimbare PROD.**

Fișiere pregătite, nepublicate:

- `tooling/rules_tests/rc120/firestore.rc120.proposed.rules`. Este identic cu `firestore.rules` plus revizia; testul R1 blochează deriva.
- `firebase.rules-rc120-test.json`, doar pentru emulator.

## 6. Inventar M0 (numai din surse locale sigure; INCOMPLET prin construcție)

Aplicația **nu raportează nicăieri versiunea**:

- nu există `app_version` în documente;
- token-urile de notificare au doar platforma, emailul și `lastSeenAt`;
- `forceUpdate` nu e implementat.

PROD nu a fost citit. Prin urmare, **lista de mai jos nu este o listă completă de dispozitive**.

| Ce se știe | Sursă | Versiune | Observații |
|---|---|---|---|
| Linia distribuită Android | manifeste 114–119, `RELEASE_PLAN_118.md` | **1.12.1+112**, cert oficial `c14588c2…` | numărul de telefoane: **necunoscut** |
| Telefoane care au instalat 113 de la zero | `RELEASE_PLAN_118.md` | 113, cert Debug `23b2a37e…` | Fold7 (`RFCY70F57JM`) e migrat la 118; altele: **necunoscute** |
| Windows | `RELEASE_PLAN_118.md` (folderul `ProVentaris_113_vechi`) | 113 (zip, fără auto-update) | numărul de instalări: **necunoscut** |
| 114–119 | manifeste | — | **nedistribuite** (RC local, superseded) |
| Proiectul Costel | `firebase_options_costel.dart` local, `build_costel.ps1` | același cod, proiect **`proventaris-costel-costea`** | flotă separată: M0–M3 separat |
| Web | `firebase_options.dart` are config web; `firebase.json` nu are hosting | — | nicio implementare web cunoscută; de confirmat |

Pentru un inventar real, cu decizia proprietarului:

- **M0-a (citire PROD):** utilizatorii activi din Firebase Auth (ultima autentificare) și token-urile de notificare (platformă, `lastSeenAt`).
- **M0-b (raport):** `tooling/sync_monitor/legacy_writes_report.mjs` raportează documentele nemigrate și modificările fără revizie. Rulează doar în citire.
- **M0-c (confirmare manuală):** fiecare utilizator confirmă versiunea afișată în aplicație (`v1.x+N` în meniu).
- **Opțional, după aprobare:** un heartbeat de versiune per dispozitiv (`device_heartbeats/{id}`: uid, platformă, build, `last_seen`). Cere o regulă nouă: colecțiile neenumerate sunt blocate (deny by default). Nu este implementat.

## 7. Căi de scriere (audit complet)

| Cale | Ocolește regulile? | `clients`/`offers`/`jobs` | Stare |
|---|---|---|---|
| Aplicația 120: `Firebase*Repository` → `RevisionWriter` | nu | singura cale (grep complet pe `lib/`) | condiționat |
| Aplicațiile 112/113/118/119 | nu | `set(merge)` orb | blocate doar de M3 |
| Cloud Functions `functions/` (Admin SDK) | **da** | nu scriu (doar notificări, email, users, configurări) | ok |
| `functions_invoice_import` (Admin SDK) | **da** | nu scrie (`supplier_invoices`, `lines`) | ok |
| `scripts/publish_release*.js` (REST + OAuth) | **da** | doar `app_config/version_info` | ok |
| Consola Firebase, `gcloud firestore import`, scripturi cu cont de serviciu | **da** | pot scrie orice | procedură: interzis pe aceste colecții în timpul M1–M3; un import/restore readuce versiuni vechi (vezi rollback) |
| Proiectul Costel | separat | aceeași problemă, în alt proiect | plan separat |

Monitorizare: `updateTime > _rev_at` semnalează **orice** scriere fără revizie, inclusiv pe căile care ocolesc regulile.

## 8. Ștergeri: risc rămas și propunere (decizie)

Regulile nu pot condiționa ștergerea de revizie. Ștergerea nu are `request.resource`, deci regula nu poate afla baza clientului.

- **Android:** tranzacția este atomică, deci o ștergere învechită e refuzată de server și reîncercată.
- **Windows:** citirea, decizia și ștergerea sunt separate. O editare B scrisă exact în fereastră se pierde. Este demonstrat în R9 (emulator) și în testul unitar „RISC CUNOSCUT”.

**Propunere (neimplementată; cere decizie, pentru că schimbă semantica datelor):** ștergere în doi pași (tombstone).

1. Actualizare condiționată `{_deleted: true, _rev: n+1}`. E atomică prin reguli.
2. Ștergerea propriu-zisă.

Regulile M3 ar trebui completate astfel:

- `allow delete: if resource.data._deleted == true`;
- `allow update: if resource.data.get('_deleted', false) == false && revOnUpdate()`.

Cititorii 120 ar trata `_deleted` ca șters. Până la M3, aplicațiile vechi ar vedea pentru scurt timp documentul marcat.

Costul: cele 3 depozite, îmbinările locale și testele. Frecvența ștergerilor pe Windows este mică, dar nenulă.

## 9. Rezolvarea conflictelor: mecanism minim (proiect; arhiva este implementată)

Deja implementat:

- conflictele deschise sunt persistente, cu ambele variante;
- elementul din coadă e parcat;
- varianta locală rămâne afișată;
- un conflict înlocuit sau rezolvat se mută într-o **arhivă doar-adăugare** (`sync_conflicts_archive_v1`), cu motiv și dată;
- tipuri de conflict: `concurrent_edit`, `deleted_remotely`, `delete_vs_remote_edit`, `retry_exhausted`, `unknown_on_upgrade` (prima rulare 120);
- payload-urile de server cu `Timestamp`/`GeoPoint` se serializează sigur. Era un defect latent: salvarea conflictului eșua.

Ecranul propus (cam 250 de linii UI și 100 de logică), fără nicio ștergere de variantă:

1. **Indicator:** în meniul de sincronizare, „Conflicte (N)”, vizibil și pe ecranul entității („Există o versiune diferită pe server”).
2. **Lista:** tip, nume, motiv (editare simultană / șters pe alt dispozitiv / ștergere vs. editare / reîncercări epuizate) și data.
3. **Detaliul:** doar câmpurile diferite, „Varianta mea” vs. „Varianta de pe server”, plus revizia de bază și cea curentă.
4. **Acțiuni:**
   - **Păstrez varianta mea:** recitește serverul și scrie condiționat, cu baza = revizia curentă. Dacă serverul s-a schimbat din nou, apare conflict nou (nimic suprascris orb).
   - **Păstrez varianta serverului:** local primește varianta serverului; varianta mea merge în arhivă.
   - **Păstrez ambele** (oferte, clienți): varianta mea devine entitate nouă (id nou, `_rev = 1`).
   - **Șters pe alt dispozitiv:** „Recreez”, ca entitate nouă, sau „Accept ștergerea”, cu varianta mea arhivată.
   - **Ștergere vs. editare:** „Șterg oricum” (ștergere condiționată pe revizia curentă) sau „Păstrez”.
   - **Reîncercări epuizate:** „Retrimite”, prin coadă, condiționat.
5. **Audit:** în arhivă se rețin cine, ce dispozitiv și ce alegere.
6. **Opțional, după aprobare M3:** copie a conflictelor pe server (`sync_conflicts`), ca să fie vizibile pentru administrator și să supraviețuiască dezinstalării. Cere o regulă nouă.

Arhiva e locală pe dispozitiv: **o dezinstalare o șterge**. Copia pe server elimină acest risc.

## 10. Distribuire etapizată fără dispozitive vechi care pot suprascrie: analiză

**Constatare:** nu există o cale în care, în același timp, aplicațiile vechi nu mai pot suprascrie și nicio editare de pe un dispozitiv vechi nu se pierde. Cauzele:

- aplicațiile vechi nu își trimit versiunea;
- nu au actualizare forțată;
- nu pot fi deosebite de server (nu există App Check, iar cererea nu poartă versiunea).

Variante:

- **Înainte de M3:** pot suprascrie (P7).
- **După M3:** sunt blocate, iar editările lor nesincronizate se pierd **pe acel dispozitiv** după 10 eșecuri. Se pierd doar acolo, nu și pe server.

**Calea fără pierderi:** fiecare dispozitiv vechi este **actualizat in-place la 120 înainte de M3**.

- Actualizarea păstrează baza locală și coada.
- 120 tratează elementele vechi din coadă conservator: conflict dacă serverul diferă (S3 și testele de coadă veche: PASS).
- Fereastra P7 se reduce astfel la durata M1. Ea dispare la M3.

**Variantă intermediară (M3-a, decizie):** regulile permit scrierea veche doar pe documente încă fără `_rev`:

```
allow update: if revOnUpdate() || (!('_rev' in resource.data) && !('_rev' in request.resource.data))
```

- Documentele atinse de 120 sunt protejate imediat.
- Aplicațiile vechi continuă să lucreze pe documentele neatinse.
- O editare 120 nesincronizată pe un astfel de document e protejată de amprentă: devine conflict, nu se pierde.
- Testat pe emulator: R11 PASS.

## 11. Plan M1–M3 (de executat DOAR cu aprobare separată, per etapă)

### M1: distribuire 120 (fără schimbări de reguli)

**Preflight:**

- PR #27 și RC 120 revizuite și merge-uite cu aprobare.
- Build oficial semnat: gate `verify_apk_signature.ps1` (cert `c14588c2…`).
- Zip Windows cu SHA-256.
- QA izolat S1–S6 PASS pe exact binarul distribuit.
- Inventar M0 acceptat de proprietar.
- Coadă goală pe fiecare dispozitiv înainte de actualizare (sincronizare manuală, verificată în aplicație).

**Backup:**

- export Firestore gestionat (`gcloud firestore export`) **înainte** de M1. Este o acțiune PROD, cu aprobare;
- backup local per dispozitiv Android (kitul Fold7 / pilot) și copie a profilului Windows (`%APPDATA%` al aplicației).

**Etape:**

1. Pilot: un telefon 112, un Windows, Fold7 (după procedura sa). 48 de ore.
2. Restul telefoanelor 112, prin `version_info`, doar cu aprobare.
3. Telefoanele 113 Debug, per dispozitiv, prin procedura de migrare.
4. Windows: zip manual.

**Monitorizare:**

- `legacy_writes_report.mjs`, în citire, zilnic, cu aprobare de citire PROD;
- conflicte deschise pe dispozitive (meniu, după UI);
- elemente de coadă nesincronizate de peste 24 de ore.

**Criterii de oprire:**

- orice raport de pierdere de date;
- crash la pornire;
- un element de coadă blocat de peste 24 de ore;
- conflicte în rafală (peste 5 pe zi pe dispozitiv fără editări simultane reale);
- `permission-denied` pe 120 înainte de M3.

**Rollback:** Android nu permite downgrade fără dezinstalare. Rollback-ul înseamnă:

- oprirea distribuției (`version_info` înapoi);
- corecție înainte (121);
- restaurare din backupul local doar cu decizie explicită.

Windows: se revine la folderul vechi redenumit; profilul e același.

### M2: verificare „nicio scriere veche”

**Criteriu de trecere:**

- raportul arată **0 scrieri fără revizie** pe `clients`/`offers`/`jobs` timp de cel puțin 7 zile consecutive;
- toate dispozitivele din M0 au confirmat 120.

Opțional, migrarea explicită `_rev = 0` nu e necesară: regula tratează lipsa ca 0 (R4).

**Oprire:** orice scriere fără revizie. Se identifică dispozitivul, se actualizează, iar perioada se repornește.

### M3: publicarea regulilor (PROD)

**Preflight:**

- se obține conținutul **live** al regulilor (Consola, de către proprietar) și se face `diff` cu `firestore.rules`. Orice diferență oprește etapa până la reconciliere;
- se regenerează propunerea din live și se rulează testele R1–R10 pe emulator;
- se rulează `firebase deploy --only firestore:rules --dry-run`, dacă e disponibil;
- se face export Firestore proaspăt;
- se aplică întâi pe proiectul cel mai mic (decizie: Costel sau principal).

**Publicare:** doar `firestore:rules` (nu functions, nu storage). Se păstrează o copie a regulilor anterioare.

**Monitorizare 24–72 de ore:**

- `permission-denied` raportate de 120 (nu ar trebui, în afara curselor);
- conflicte;
- raportul de scrieri vechi.

**Criterii de oprire și rollback imediat:** orice scriere 120 legitimă respinsă sau orice blocare a utilizatorilor. Rollback-ul înseamnă republicarea regulilor anterioare, în minute; 120 funcționează cu ambele seturi.

**Notă:** restaurarea unui export Firestore ocolește regulile și readuce versiuni vechi. Se face doar la dezastru. După restaurare, clienții 120 detectează diferențele ca conflicte, deci fără suprascriere oarbă.

## 12. Defecte găsite în timpul RC 120 (remediate)

| Defect | Dovadă | Remediere |
|---|---|---|
| `runTransaction` pe Windows oprește aplicația (excepție C++ 0xE06D7363) | 4/4 rulări QA | `a0f3bb3`: citire de pe server + decizie + scriere |
| Cursă: îmbinarea din fundal suprascria local editarea imediat anterioară | QA Windows S1, prima rulare | `384e6fe`: coada înaintea cloud-ului; blocare RMW clienți |
| Scrierea Windows respinsă de reguli devenea conflict abia la reîncercările cozii | analiză + S5 | `e7c3f8b`: o reevaluare imediată |
| Salvarea conflictului eșua dacă varianta de server conținea `Timestamp` | test unitar nou | `7e63e15`: serializare JSON sigură |
| Conflictul nou pe aceeași entitate înlocuia variantele vechi; `resolve` le ștergea | analiză | `7e63e15`: arhivă doar-adăugare |
| Review #1: o ștergere locală în așteptare era anulată de îmbinare (copia din cache revenea), apoi reîncărcată pe server | test (pică pe codul vechi) | `94f0d0b` |
| Review #2: baza avansa din fundal cât timp un editor era deschis → scrierea editorului ștergea editarea altui dispozitiv | test | `94f0d0b`: `syncRev` (`_rev`) în modele + `ownWrite` în bază |
| Review #3: îmbinarea oferte/lucrări se putea intercala între salvarea locală și coadă → editarea locală suprascrisă | test (pică pe codul vechi) | `94f0d0b`: blocare comună per entitate |
| Review #4: conflict fals la reluarea unui element deja aplicat (după o editare B) | test | `94f0d0b`: „deja aplicat”, fără avansarea bazei |
| Review #5: ștergerea compara amprente pe chei diferite → conflict permanent la clienții scriși de versiuni vechi | test | `94f0d0b` |
| Review #6: curățarea cozii la pornire elimina elementele epuizate fără să le păstreze | test | `94f0d0b` |
| Review #7: coada / bazele / conflictele: citire-modificare-scriere fără blocare → element nou din coadă pierdut | test (pică pe codul vechi) | `94f0d0b`: `KeyedMutex` |
| Review #9: prima rulare 120 (fără baze) reîncărca înregistrări șterse în altă parte | test | `f8f97bc`: păstrare locală + conflict `unknown_on_upgrade` |
| Re-review #1: reluarea „aplicat” pierdea `ownWrite` → conflict fals la următoarea salvare pe același dispozitiv | test (pică pe codul vechi) | `ownWrite` din `_rev_writer` |
| Re-review #2: editorii principali (client, ofertă, lucrare) construiau înregistrarea fără `syncRev` | analiză | editorii transmit `syncRev` |
| Re-review #5: `_recordBases` calcula entitățile protejate în afara blocării | analiză | sub `runEntitySyncLocked`; salvarea/ștergerea clienților sub aceeași blocare |
| Re-review #8: păstrarea elementelor epuizate putea eșua, iar curățarea le ștergea oricum | analiză | curățarea doar după păstrare reușită |

### Riscuri rămase (acceptate până la decizie)

- **Windows, înainte de M3:** o scriere care expiră după citire (`timeout`) nu e anulată de SDK și poate ajunge mai târziu, necondiționat (review #8). Cu regulile M3 este respinsă (vezi S5).
- **`set(merge: true)`:** o cheie ștearsă local dintr-o hartă imbricată rămâne pe server. Efect: conflict fals ulterior, nu pierdere.
- **Lucrări:** îmbinarea păstrează local orice lucrare doar-locală. O lucrare ștearsă în altă parte rămâne local și, dacă e editată, devine creare nouă (comportament anterior, neschimbat).
- **Editori care construiesc înregistrarea de la zero** (fără `copyWith`) pierd `syncRev`. Pentru ei rămâne protecția prin bază (ca înainte de review #2).
- **Ștergeri pe Windows** (§8) și **aplicații vechi** (§10): decizii D2/D3.
- **Conflictele nu au încă interfață:** `retry_exhausted`, `unknown_on_upgrade` și conflictele de ștergere păstrează datele, dar entitatea rămâne protejată și invizibilă pentru utilizator până la rezolvare. Ecranul §9 este **condiție obligatorie înainte de distribuire (M1)**, nu opțională.
- `complaint_quick_offer_tab` salvează oferta doar local (fără coadă). Comportament anterior, în afara căii condiționate.

## 13. Teste

### Unitare și analiză (cod `f8f97bc`)

- `flutter test`: **557/557 PASS**.
- `flutter analyze`: 0 erori, 0 avertismente. Cele 16 `info` sunt preexistente, în fișiere neatinse.
- `test/revision_sync_conflicts_test.dart`: **43 de teste**. Acoperă:
  - A offline / B online / A sincronizează;
  - editări simultane, reîncercare, confirmare pierdută, repornire, dublu-clic;
  - cozi vechi, ștergeri, aplicații vechi;
  - fereastra Windows cu și fără regulile M3;
  - arhiva conflictelor, `Timestamp` în conflicte;
  - constatările de review #1–#7 și #9, plus re-review #1.
  - #1, #3, #7 și re-review #1 **pică pe codul vechi** (verificat prin înlocuire temporară).

### Reguli propuse (emulator, proiect `demo-`): **17/17 PASS**

| Test | Ce verifică |
|---|---|
| R1 | propunerea = regulile live + doar revizia (fără derivă) |
| R2–R4 (×3 colecții) | creare `_rev = 1`; scrierea veche respinsă; migrarea documentelor fără `_rev` |
| R5 | citire → scriere B → scriere A învechită: **respinsă** |
| R6 | 40 de runde × 3 colecții, scrieri simultane: **exact un câștigător**, perdantul `permission-denied` |
| R7 | creare simultană a aceluiași id: exact una |
| R8 | retrimiterea după confirmare pierdută: respinsă (nu dublează) |
| R9 | **RISC:** ștergerea învechită trece (§8) |
| R10 | utilizator inactiv respins; alte colecții neschimbate |
| R11 | varianta M3-a: scrierea veche doar pe documente fără `_rev` |

### Windows izolat (binar Release de test cu codul `f8f97bc`, Firestore Emulator, profil QA separat)

- Exe `89c5a8b4…`, rulare `pvl-qa-common/runs/rc120_20261015_235456`: **S1–S6 PASS**.
- Monitorul `legacy_writes_report.mjs` a fost testat pe emulator: PASS.

| Scenariu | Rezultat |
|---|---|
| S1: A offline, B (120) online, A sincronizează | **PASS**: server = B (rev 2); conflict cu A păstrat; persistă după repornire |
| S2: idem, B = aplicație veche (scriere oarbă) | **PASS**: detectat prin amprentă |
| S3: regresia #26 (profil 113 → 120, offline, repornire, sincronizare) | **PASS**: 1 client + 1 ofertă în cloud, 0 conflicte |
| S4: reguli M3 pe emulator | **PASS**: 120 creează `_rev = 1` (`_rev_at` = `Timestamp` server); scrierea veche HTTP 403; scrierea 120 HTTP 200 |
| S5: cursa citire→scriere pe Windows, cu reguli M3 | **PASS**: A respins de reguli, conflict în ~1 s, B păstrat, A păstrat local |
| S6: aceeași cursă fără reguli | **riscul confirmat**: A suprascrie B (motivul pentru M3) |

**Note de investigație:**

- Două rulări intermediare au avut FAIL la C5_CREATE (S2/S5).
  - Cauza: aplicația decide „online” printr-un DNS `firestore.googleapis.com` cu 2 s, neașteptat la pornire. Când DNS-ul e lent, salvarea merge doar în coadă (fără pierdere) și se sincronizează ulterior.
  - Harness-ul verifică acum explicit starea online.
  - Una dintre rulări a coincis și cu testele de reguli pornite în paralel, care opreau porturile emulatorului.
- O rulare S4 mai veche: harness-ul aștepta doar 2 s.


## 14. Decizii care necesită autorizare

| # | Decizie | Opțiuni / recomandare |
|---|---|---|
| D1 | Citire PROD pentru inventarul M0 (Auth, token-uri, raportul de scrieri vechi) | doar citire; recomandat înainte de M1 |
| D2 | Ștergeri pe Windows: acceptăm riscul (§8) sau implementăm tombstone înainte de M3 | recomandare: tombstone înainte de M3, dacă ștergerile pe Windows sunt uzuale |
| D3 | Regulile M3 complete sau varianta M3-a (§10) | M3-a ca pas intermediar, dacă M0 nu poate garanta actualizarea tuturor dispozitivelor |
| D4 | Ecranul de rezolvare a conflictelor (§9) | **obligatoriu înainte de M1**: fără el, conflictele sunt fundături (date păstrate, dar invizibile) |
| D5 | Heartbeat de versiune și copie server a conflictelor (reguli noi, aditive) | opțional; reduce incertitudinea M0/M2 |
| D6 | Ordinea proiectelor la M3 (Costel `proventaris-costel-costea` vs. principal `devizpro-ultra-pilot`) | întâi cel cu mai puține dispozitive |
| D7 | Export Firestore înainte de M1 și înainte de M3 | obligatoriu în plan |
| D8 | Merge PR #27 și PR RC 120, distribuire, `version_info` | nu sunt făcute; fiecare cere aprobare |

