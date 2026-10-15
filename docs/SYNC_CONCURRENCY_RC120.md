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
- **Ordinea nu se stabilește după `updated_at`.** Câmpul păstrează ora editării, doar informativ.

## 4. Compatibilitate

| Situație | Comportament în 120 |
|---|---|
| Documente existente fără `_rev` | tratate ca revizia 0; prima scriere 120 pe baza citită → `_rev = 1` (test PASS) |
| Elemente vechi din coadă (119), fără bază | conflict dacă serverul diferă; aplicat dacă e identic; creat dacă lipsește (conservator, fără pierderi) |
| Aplicație veche care scrie după 120 | **detectată** prin amprentă: 120 NU o suprascrie, conflict (test PASS, unitar și pe Windows) |
| 120 scrie, apoi o aplicație veche scrie orb | aplicația veche **suprascrie** versiunea 120 (P7). Inevitabil fără reguli de server |
| Dispozitive 113 Debug (Fold7) | neschimbat față de 119: 120 se instalează doar oficial (după migrare) |

## 5. Gate: protecția completă cere modificări server-side și blochează clienții vechi

Protecția nu poate fi garantată numai din client:

1. **Aplicațiile vechi** (P7) scriu orb. Doar regulile Firestore le pot respinge.
   - Test pe emulator (S4), reguli `firestore.rev-enforced.rules`: scrierea veche → **HTTP 403**; scrierea 120 cu `_rev + 1` → **HTTP 200**.
   - Efect: aceleași reguli **blochează toate scrierile** clienților 113/118/119, pentru clienți, oferte și lucrări.
   - Clienții vechi nu au actualizare forțată: `forceUpdate` nu e implementat, deci nu pot fi obligați să se actualizeze.
   - Elementele lor respinse ar fi șterse după 10 eșecuri (P5 există în versiunile vechi).
2. **Pe Windows**, tranzacțiile pluginului actual opresc aplicația. Verificarea fără tranzacție nu este atomică; regulile de mai sus o fac atomică.

**Conform gate-ului, implementarea se oprește înaintea oricărei schimbări PROD.**

### Planul de migrare propus (fiecare etapă cere aprobare separată)

| Etapă | Acțiune | Risc | Rollback |
|---|---|---|---|
| M0 | Inventarul dispozitivelor și versiunilor (Android și Windows) care scriu în PROD | — | — |
| M1 | Distribuire 120 pe toate dispozitivele cu certificat compatibil (pilot → toate). Dispozitivele 113 Debug: procedura de migrare | P7 rămâne până la M3 (aplicațiile vechi pot suprascrie) | reinstalare 119/118 nu e posibilă fără dezinstalare (date locale); rollback = corecție înainte (121) |
| M2 | Verificare: niciun dispozitiv sub 120 nu mai scrie. Toate documentele active primesc `_rev` la prima editare 120; opțional o migrare care setează `_rev = 0` explicit | — | — |
| M3 | **PROD (aprobare separată):** publicarea regulilor cu revizie obligatorie pentru `clients`/`offers`/`jobs` | orice client vechi rămas este **blocat** la scriere | republicarea regulilor anterioare (copie păstrată); 120 funcționează cu ambele seturi de reguli |
| M4 | Opțional, după M3: Windows pe tranzacții când pluginul le suportă stabil | — | rămâne pe verificarea cu citire de pe server |

Alternativă fără blocarea clienților vechi: rămânem la M1 (protecție în 120, P7 acceptat temporar) până la M3.

## 6. Defecte găsite pe Windows în timpul RC 120 (remediate)

| Defect | Dovadă | Remediere |
|---|---|---|
| `runTransaction` pe Windows oprește aplicația (excepție C++ 0xE06D7363 în KERNELBASE; pluginul trimite evenimente din firul tranzacției) | 4/4 rulări QA | `a0f3bb3`: pe Windows, citire de pe server (`Source.server`) + decizie + scriere; neatomic (fereastră de ordinul sutelor de ms), atomic doar cu regulile M3 |
| Cursă: îmbinarea cloud din fundal suprascria local editarea făcută imediat înainte (`queueClient` nu era așteptat) | QA Windows S1, prima rulare | `384e6fe`: coada **înaintea** cloud-ului; blocare citire-modificare-scriere pentru clienți; recitire locală sub blocare |

## 7. Teste

Unitare: suita completă **535/535 PASS**, plus `flutter analyze` fără erori și fără avertismente (16 `info` preexistente, în fișiere neatinse de branch). Dintre ele, 21 teste noi în `test/revision_sync_conflicts_test.dart` acoperă:

- A offline / B online / A sincronizează;
- editări simultane;
- confirmare pierdută după commit (idempotență);
- reîncercare, repornire, dublu-clic, elemente vechi din coadă, ștergere vs. editare;
- scriere oarbă a aplicației vechi;
- epuizarea reîncercărilor.

QA Windows izolat: binar Release de test, Firestore Emulator, profil QA separat, fără PROD.

Binar de test `qa-test-only-120d` (cod aplicație = `37ce3ed`). Rulări în `pvl-qa-common/runs`: `rc120_20261015_223916` (S1, S2) și `rc120_20261015_225009` (S3, S4).

| Scenariu | Rezultat |
|---|---|
| S1: A editează offline, B (120) salvează online, A sincronizează | **PASS**: server = B (rev 2); conflict `concurrent_edit` cu varianta A păstrată; elementul parcat; local = A; persistă după repornire |
| S2: idem, B = aplicație veche 119 (scriere oarbă, fără `_rev`) | **PASS**: scrierea veche detectată prin amprentă; B păstrat pe server, A păstrat în conflict și local |
| S3: regresie #26 (profil 113 → 120, client + ofertă offline, repornire, sincronizare) | **PASS**: salvare locală imediată; coada supraviețuiește repornirii; cloud 1 client + 1 ofertă; sincronizarea a doua idempotentă; 0 conflicte |
| S4: reguli **emulator** cu revizie obligatorie | **PASS**: 120 creează cu `_rev = 1`; scrierea veche → HTTP 403; scrierea 120 cu `_rev + 1` → HTTP 200 |

Notă: o rulare S4 anterioară a raportat FAIL. Cauza a fost harness-ul de test: aștepta fix 2 s confirmarea serverului, iar emulatorul abia pornit compila regulile. Nu a fost o scriere fără `_rev` (respingerea din jurnalul emulatorului era scrierea veche, intenționată). Harness-ul așteaptă acum până la 20 s.

## 8. Ce rămâne de decis

- interfața de rezolvare a conflictelor (conflictele sunt păstrate și vizibile în jurnal, dar nu există încă un ecran);
- momentul M3 (reguli PROD) și tratamentul clienților vechi rămași;
- aplicarea aceluiași model la celelalte colecții (programări, echipe etc.) — în afara acestui RC.
