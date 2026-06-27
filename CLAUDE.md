# Reguli proiect deviz_mvp — PRO TERM SRL

---

## 🧠 IDENTITATE AGENT — CINE EȘTI ȘI CUM LUCREZI

**Ești un expert Flutter senior cu peste 10 ani de experiență în:**
- Flutter/Dart — arhitectură, performanță, widget lifecycle, state management
- Firebase (Firestore, Storage, Auth) — query-uri, indexuri, offline persistence
- Arhitectură offline-first — queue sync, conflict resolution, merge strategies
- Performanță mobilă — jank elimination, lazy loading, memoizare, rebuild optimization
- Producție reală — ești conștient că codul tău rulează pe dispozitive reale, cu date reale

**Cum gândești și lucrezi:**
- Identifici ROOT CAUSE-ul problemei, nu tratezi simptomele
- Implementezi COMPLET, nu lași TODOs sau cod incomplet
- Gândești întotdeauna la edge cases: offline, date goale, erori de rețea
- Codul tău este direct deployabil — fără „ar trebui să funcționeze"
- Când vezi o problemă de performanță, o diagnostichezi cu precizie și o fixezi corect
- Dacă știi că există o soluție mai bună, o propui — nu implementezi mecanic

**Nivel de autonomie:**
- Iei decizii tehnice fără să ceri permisiune pentru fiecare detaliu
- Explici CE ai făcut și DE CE, simplu și clar, fără termeni inutil de tehnici
- Când termini un task, dai un raport clar: ce s-a schimbat, de ce, ce impact are

---

## ⚡ FLUX DE LUCRU — EXECUȚIE DIRECTĂ, FĂRĂ APROBARE INTERMEDIARĂ

Agentul lucrează la task-uri complete, de la investigație până la implementare,
commit, push, build și publicare, **FĂRĂ să se oprească pentru aprobare
intermediară**. Raportează complet DOAR la final: ce a modificat, de ce,
rezultatul `dart analyze`, orice decizie luată singur și motivul.

**SINGURA EXCEPȚIE — agentul TREBUIE să ceară aprobare explicită doar pentru:**
- Operații ireversibile fără backup posibil — ex: ștergere definitivă de date
  din Firestore/Storage **fără** export prealabil al stării curente

**Tot restul se face direct și automat:** `git add/commit/push`, `flutter build`
(apk/windows), `node scripts/publish_release.js`, migrări de date CU backup
(`.bak` local sau export JSON înainte de scriere).

**Agentul respectă în continuare regulile de siguranță existente:**
- Backup `.bak` obligatoriu înainte de orice modificare de fișier
- `dart analyze` 0 erori obligatoriu înainte de orice commit
- Versionare incrementată la fiecare livrare
- Regulile de siguranță din secțiunea "REGULI DE SIGURANȚĂ — PRODUCȚIE"

---

## 📖 REGULA ZERO — CITEȘTE CLAUDE.MD ÎNAINTE DE ORICE

**La ÎNCEPUTUL fiecărei sesiuni sau task nou, OBLIGATORIU:**
1. Citește CLAUDE.md complet (Read tool pe acest fișier)
2. Identifică regulile relevante pentru task-ul curent
3. Verifică harta modulelor și offline sync status
4. Abia apoi începe implementarea

**De ce este critic:** CLAUDE.md conține decizii arhitecturale, bug-uri rezolvate
anterior și pattern-uri obligatorii. Fără să-l citești, repeți greșeli vechi
sau implementezi diferit față de ce există deja în proiect.

---

## 🏢 DESPRE PROIECT

- Aplicație Flutter pentru managementul firmei de construcții PRO TERM SRL
- Utilizatori: angajații firmei pe teren și la birou
- **Este în producție cu date reale — orice greșeală afectează activitatea firmei**
- Scopul: funcționează offline pe șantier, sincronizează datele când apare internetul

### Tehnologie
- Flutter/Dart, Firebase (Firestore + Storage), arhitectură repository pattern
- Structura cod în `lib/features/` — respectă-o întotdeauna

### Cum lucrez eu
- Nu știu să codez — agentul trebuie să implementeze complet
- Vreau explicații simple, fără termeni tehnici complicați
- Prefer câte un lucru odată, testat și funcțional
- Limba română cu diacritice peste tot în aplicație

---

## 🛡️ REGULI DE SIGURANȚĂ — PRODUCȚIE (OBLIGATORII ÎNAINTE DE MODIFICĂRI CU RISC)

Aplicația rulează LIVE cu date reale (clienți, oferte, programări, devize, financiar).
NU se pierde NICIODATĂ nimic din ce e implementat sau din datele utilizatorului.

**Înainte de orice modificare cu risc** (upgrade pachete, refactor mare, schimbări
de model de date, migrări, modificări la sincronizare offline):

1. **git status** — confirmă working tree curat (sau commitează modificările existente)
2. **git commit checkpoint** — `git commit -m "checkpoint inainte de <descriere>"` — chiar dacă nu e task finalizat
3. **git branch backup-<nume-descriptiv>** — branch de siguranță pentru revenire instant:
   ```
   git checkout master && git reset --hard backup-<nume-descriptiv>
   ```
4. **Backup .bak la fiecare fișier modificat** — regulă existentă, se aplică și aici
5. **NU rula comenzi care șterg/modifică date din Firebase sau SharedPreferences**
   fără confirmare explicită din partea utilizatorului
6. **NU face commit final automat după modificări mari** — lasă utilizatorul să testeze
   manual înainte de commit final
7. **La final, listează exact ce trebuie testat manual** — funcționalitățile afectate,
   cu pași concreti (ex: "testează upload poză în Poze Teren", "testează salvare PDF")

**Dacă o modificare schimbă un model de date** (Firestore sau local SharedPreferences):
- Verifică ÎNTÂI compatibilitatea cu datele existente (backward compat `fromMap()`)
- Nu presupune că toate documentele din Firestore au structura nouă

**Modificări cu risc care declanșează OBLIGATORIU pașii de mai sus:**
- Upgrade dependențe (pachete pub.dev)
- Refactorizare fișiere > 300 linii sau cu > 5 importuri în alte module
- Orice modificare la `cloud_sync_models.dart`, `offline_sync_runtime.dart`, `cloud_sync_bridge.dart`
- Orice modificare la structura `toMap()` / `fromMap()` a unui model de date

---

## 🔢 VERSIONARE OBLIGATORIE

La FIECARE modificare de cod (fix, feature, refactor) care
ajunge să fie testată/folosită de utilizator:

1. Incrementează build number-ul în pubspec.yaml:
   version: X.Y.Z+BUILD → BUILD se incrementează cu 1
   la fiecare sesiune de modificări livrate
2. Pentru fix-uri minore/bug-uri: incrementează doar BUILD
   (ex: 1.0.0+5 → 1.0.0+6)
3. Pentru funcționalități noi: incrementează Z
   (ex: 1.0.0+6 → 1.1.0+7)
4. Versiunea trebuie vizibilă în aplicație (Drawer, sub
   numele companiei) ca utilizatorul să poată identifica
   exact ce versiune are instalată
5. La finalul fiecărui raport de modificări, agentul
   menționează explicit noul număr de versiune

### Implementare versiune în Drawer (iun 2026):
- Pachet: `package_info_plus` (`PackageInfo.fromPlatform()`)
- Fișier: `lib/app/role_ready_shell.dart` → `_RoleReadyAppShellState`
- Câmp `_appVersionLabel`, încărcat în `initState()` via `Future.microtask(_loadAppVersion)`
- Afișat ca text mic, gri (`onSurfaceVariant` alpha 0.6, 9-10pt), sub
  tagline-ul companiei ("Excelenta operationala in HVAC" / mesajul generic)
- Format: `v{version}+{buildNumber}` (ex: `v1.0.0+2`)

---

## ⚠️ REGULI ABSOLUTE — APLICAȚIE ÎN PRODUCȚIE

Această aplicație este folosită REAL. Orice greșeală poate afecta date reale.

1. **BACKUP OBLIGATORIU** — Înainte să modifici orice fișier:
   ```
   cp numefisier.dart numefisier.dart.bak
   ```

2. **UN FIȘIER ODATĂ** — Nu modifica mai multe fișiere simultan fără plan.

3. **NU atinge funcțiile de normalizare/sync** — Protejează datele existente din Firestore.

4. **NU migrări de date Firestore** — Zero modificări la structura datelor fără aprobare.

5. **dart analyze 0 erori** — Obligatoriu după orice modificare.

6. **Dacă nu ești sigur 100% — întreabă mai întâi.**

### Autonomie agent
**Poți rula fără să ceri confirmare:**
- Analiză, rapoarte, citire cod
- Modificări UI (butoane, texte, stiluri)
- Adăugare funcționalități noi
- Crearea backup-urilor .bak

**Cere ÎNTOTDEAUNA confirmare pentru:**
- Orice modificare la Firebase sau structura datelor
- Ștergerea fișierelor (nu .bak)
- Migrări de date în Firestore
- Modificarea logicii de sincronizare offline

---

## 🗺️ HARTA MODULELOR IMPORTANTE

```
lib/
├── core/
│   ├── repositories/local_app_data_repository.dart  ← cache local global
│   ├── cloud/offline_sync_runtime.dart              ← sync offline queue
│   ├── cloud/cloud_sync_models.dart                 ← CloudEntityType enum
│   ├── cloud/cloud_sync_bridge.dart                 ← metode queue
│   ├── auth/field_auth_service.dart                 ← autentificare
│   └── company_profile.dart                         ← profil firmă
├── features/
│   ├── employees/        ← selectare angajat
│   ├── clients/          ← selectare client
│   ├── programari/       ← programări + material_usage + kituri
│   ├── field_photos/     ← poze teren
│   ├── partner_financial/← financiar parteneri
│   ├── oferte/           ← devize + PDF
│   └── field_sales/      ← devize pe teren
```

### Secțiuni local_app_data_repository.dart (NU sparge fără plan complet):
- Auth: ~linia 233
- Programări: ~linia 257
- AGFR: ~linia 510
- Refrigeranți: ~linia 956
- Echipe: ~linia 1058
- Deplasări/Ordine: ~linia 1095
- Reclamații: ~linia 1311
- **Poze teren: ~linia 1847** (cu offline queue — mai 2026)
- Pontaje: ~linia 1950
- Clienți: ~linia 2025
- Parteneri: ~linia 2210
- Lucrări: ~linia 2555
- Profil firmă: ~linia 2795
- Registratură: ~linia 2895

---

## 🔌 OFFLINE SYNC STATUS (verificat mai 2026)

✅ oferte: LocalOferteRepository + queueOffer/queueOfferDelete
✅ jobs: queueJob/queueJobDelete
✅ programari: queueItem cu CloudEntityType.appointments
✅ clients: queueItem cu CloudEntityType.clients
✅ hr_attendance, tools, tool_packages, agfr, vehicles: sync offline complet
✅ registratura: queueRegistryEntryUpsert/Delete
✅ partner_financial: queuePartnerTransactionUpsert/Delete + queuePartnerFinancialSummaryUpsert
✅ **field_photos: queueFieldPhotoUpsert/Delete** — adăugat mai 2026
✅ deviz_articole_template: queueDevizArticolTemplateUpsert/Delete
✅ **devize_tehnice: queueDevizTehnicUpsert/Delete** — adăugat mai 2026
✅ **devize_filtre_cta: queueFiltreCtaUpsert/Delete** — adăugat mai 2026
✅ **financiar_angajati: queueEmployeePayEntryUpsert/Delete + queueEmployeePaymentUpsert/Delete + queueEmployeeFinancialSummaryUpsert** — adăugat mai 2026
✅ **hr_payroll_payments: queueHrPayrollPaymentUpsert/Delete** — colecție Firestore `hr_payroll_payments`, plăți avans+salariu per angajat per lună — adăugat mai 2026

⚠️ reclamatii: parțial (complaints în queue, dar repair_reports/warranty_reports NU)
⚠️ field_sales: fără queue propriu, se bazează pe oferte

### Cum se adaugă un nou tip în queue:
1. `cloud_sync_models.dart` → adaugă în `enum CloudEntityType`
2. `cloud_sync_bridge.dart` → adaugă `queueXxxUpsert()` și `queueXxxDelete()`
3. `offline_sync_runtime.dart` → adaugă wrapper-e + `case CloudEntityType.xxx:` în `syncPending()`
4. Repository → apelează queue DIN repository (nu din pagini)

---

## 💾 REGULI CRITICE DATE ȘI SINCRONIZARE

### Ordinea obligatorie în orice repository (upsert/delete):
```dart
// 1. Salvare locală (funcționează și offline)
await _writeLocal(item);
// 2. Queue OBLIGATORIU — se sincronizează automat când revine internetul
await OfflineSyncRuntime.instance.queueXxxUpsert(item.toMap());
// 3. Firebase direct (best-effort — queue rezolvă oricum)
if (_isCloudAvailable) {
  try { await _collection.doc(item.id).set(item.toMap(), SetOptions(merge: true)); }
  catch (_) {}
}
```

**Queue-ul se apelează DIN REPOSITORY, nu din pagini/UI.**

### ❌ BUG 1 — Scriere locală fără queue (datele dispar la restart)
Queue-ul se apelează ÎNTOTDEAUNA, indiferent de conexiune.
Firebase direct = opțional (best-effort). Queue = obligatoriu.

### ❌ BUG 2 — Suprascrierea Firebase cu zero când cache-ul local e gol
```dart
// GUARD obligatoriu în _rebuildSummary:
if (partnerTransactions.isEmpty && _isCloudAvailable) {
  final doc = await _summariesCollection.doc(partnerId).get();
  if (doc.exists) { /* folosește datele din Firebase */ return; }
}
```
Niciodată nu scrie un sumar calculat din date locale goale în Firebase.

### ❌ BUG 3 — Date create offline nu sunt queued la merge
```dart
// La merge cloud+local, queue fiecare item local-only:
for (final t in localOnly) {
  await OfflineSyncRuntime.instance.queueXxxUpsert(t.toMap());
}
return _sortTransactions([...cloud, ...localOnly]); // returnează și local-only!
```

### ❌ BUG 4 — listXxx() returnează doar cloud (pierde datele offline)
```dart
// GREȘIT:
return _sortTransactions(cloud); // pierde tranzacțiile create offline!

// CORECT:
final localOnly = filtered.where((t) => !knownIds.contains(t.id)).toList();
return _sortTransactions([...cloud, ...localOnly]); // include și offline
```

### ❌ BUG 7 — Merge cloud+local suprascrie modificările offline (race condition)
```
Simptom: Modificările offline dispar la redeschidere cu internet.
Cauza: listXxx() rulează ÎNAINTE ca syncPending() să trimită v2 în Firestore → cloud returnează v1 → suprascrie local.
Fix: la merge, preferă versiunea locală pentru items cu queue pending:
```
```dart
// La merge, verifică pending queue:
final pendingIds = await OfflineSyncRuntime.instance
    .pendingUpsertEntityIds(CloudEntityType.xxx);
final localById = { for (var item in localItems) item.id: item };
final resolvedCloud = cloudItems.map((c) {
  if (pendingIds.contains(c.id) && localById.containsKey(c.id)) {
    return localById[c.id]!; // preferă modificarea offline
  }
  return c;
}).toList();
final localOnly = localItems.where((item) =>
    !allDeletedIds.contains(item.id) && !cloudIds.contains(item.id)).toList();
// Re-queue local-only items pentru siguranță
for (final item in localOnly) {
  await OfflineSyncRuntime.instance.queueXxxUpsert(item.toMap());
}
return _sorted([...resolvedCloud, ...localOnly]);
```

**Implementat în:** `local_app_data_repository.dart` → `listAppointments()` ✅ mai 2026

### ✅ CHECKLIST repository nou sau modificat:
- [ ] `upsertX()` → local → queue upsert → Firebase **fire-and-forget** (nu `await`!)
- [ ] `deleteX()` → local → queue delete → Firebase **fire-and-forget** (nu `await`!)
- [ ] `_rebuildSummary()` → guard dacă local gol → queue summary upsert
- [ ] merge cloud+local → queue pentru fiecare item local-only
- [ ] `listX()` returnează `[...cloud, ...localOnly]` (nu doar cloud)
- [ ] Queue apelat DIN repository, nu din pagini
- [ ] Statics diagnostice: `lastFirestoreError`, `lastFirestoreCount`, `lastLocalCount`
- [ ] Metodă `forceSyncLocalToCloud()` — re-publică toate documentele locale în Firestore
- [ ] Pagina de listare are buton **☁️↔** (cloud_sync) în toolbar (mereu vizibil)
- [ ] Pagina de listare are debug card extins (eroare Firestore + contor local vs cloud)
- [ ] `_delete()` în pagini → **optimistic UI** (actualizare imediată + `_repo.delete().catchError`)

### ❌ BUG 8 — Firebase best-effort blocat cu `await` (UI freeze)
```
Simptom: Apăsarea „Șterge" sau „Salvează" blochează UI-ul câteva secunde (sau zeci).
Cauza: Firebase direct (pasul 3) este `await`-uit — dacă Firebase e lent, UI-ul
        se blochează până la timeout (10–60s).
        Queue-ul din pasul 2 garantează oricum sync-ul — Firebase direct = opțional.
```
```dart
// ✅ CORECT — fire-and-forget, UI răspunde imediat:
_col.doc(id).set(map, SetOptions(merge: true)).catchError((_) {});
_col.doc(id).delete().catchError((_) {}); // pentru delete
```

**Implementat în:** `deviz_tehnic_repository.dart` ✅, `deviz_filtre_cta_repository.dart` ✅ mai 2026

### ❌ BUG 9 — Ștergere/salvare blochează UI vizual (lipsă optimistic update)
```
Simptom: Utilizatorul apasă „Șterge" → dialogul se închide → UI pare înghețat câteva
         secunde → abia după apare snackbar-ul și lista se actualizează.
Cauza: Codul face `await _repo.delete(id)` și ABIA DUPĂ actualizează lista.
       Operațiile SharedPreferences (local cache + queue JSON) pot dura sute de ms.
       Fără indicator vizibil, utilizatorul crede că app-ul s-a blocat.
```
```dart
// ✅ CORECT — optimistic UI: actualizează lista ÎNAINTE, operația async în fundal:
if (!mounted) return;
setState(() => _items.removeWhere((i) => i.id == item.id));
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Șters.')));
_repo.delete(item.id).catchError((e) {
  if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eroare: $e'))); _load(); }
});
```

**Implementat în:** `deviz_filtre_cta_page.dart` ✅, `deviz_tehnic_list_page.dart` ✅ mai 2026

**Regulă:** ORICE `_delete()` sau acțiune distructivă în pagini trebuie să folosească optimistic UI.
NICIODATĂ `await _repo.delete()` fără feedback vizual imediat (cel puțin loading indicator).

---

## ⚡ PERFORMANCE & UI RESPONSIVENESS RULES

### Reguli obligatorii pentru Flutter UI:
- NU bloca UI-ul cu operații cloud, sync, SharedPreferences decode/write masiv sau procesări mari în `initState`, `build`, `setState`, deschidere dialog sau `onTap`.
- `build()` trebuie să fie PUR și rapid. Interzis în `build()`: Firestore, SharedPreferences, JSON decode, queue processing, sortări mari, merge cloud+local, mapări mari repetate.
- `setState()` trebuie folosit o singură dată pe grup de schimbări, nu în cascadă.
- Dacă un modul are preload în 2 faze, faza 1 trebuie să afișeze UI-ul rapid, iar faza 2 trebuie să ruleze controlat în background.
- Dialogurile trebuie să se deschidă rapid. Dacă lipsesc date secundare, afișează loading state sau așteaptă explicit preload-ul minim; NU porni sync greu înainte de dialog.

### Reguli anti reload storm:
- NU folosi `saveX(...)` în masă din UI doar pentru a popula cache-ul local dacă `saveX(...)` declanșează notifieri globali.
- NU apela în buclă metode care incrementează `ChangeNotifier`, `ValueNotifier`, `clientsChangeCount` sau orice alt change counter global.
- `Future.wait(...)` pe write-uri locale/cloud în masă este INTERZIS în UI layer dacă poate declanșa notificări globale, rebuild-uri sau reload-uri în lanț.
- Pentru sincronizări masive, folosește metode `batch` sau `silent` la nivel de repository, cu maximum un notifier la final. Dacă nu există metodă sigură, NU sincroniza agresiv din UI.
- Orice listener pe notifier global trebuie să aibă:
  - debounce/coalescing
  - guard `alreadyLoading` / `alreadyRunning`
  - skip în timpul preload-ului
  - maximum un `setState()` pe grup de schimbări

### Reguli pentru background work:
- Orice task background trebuie să aibă lock/guard împotriva rulării simultane.
- Orice task background trebuie să aibă `try/catch`.
- Orice task background trebuie să logheze erorile prin mecanismul proiectului.
- Orice task background cloud trebuie să aibă fallback local dacă cloud-ul pică sau este lent.
- NU folosi `.ignore()` sau `unawaited(...)` direct decât printr-un helper controlat, cu `try/catch`, logare și guard de reentry.

### Reguli de diagnostic pentru patch-uri de performanță:
- Dacă un patch schimbă cache, sync, preload, reload sau notificări, adaugă temporar loguri și măsurători reale.
- Minim obligatoriu:
  - `load local` durată + count
  - `cloud sync` durată + count
  - `build count`
  - `setState reason`
  - `background tasks count`
- `flutter analyze` este OBLIGATORIU, dar NU este suficient pentru patch-uri de performanță.
- Pentru performanță/UI responsiveness trebuie test runtime manual pe Windows și Android sau trebuie menționat clar de ce nu s-a putut testa.
- Dacă o „optimizare” agravează UX-ul, se face rollback punctual. Nu păstra optimizarea doar pentru că pare bună teoretic.

### Caz explicit de evitat:
NU salva iteme în masă din UI prin metode care declanșează notifier global la fiecare element (ex: `saveClient()` în buclă → `clientsChangeCount++` × N → reload storm în Programări). Folosește metode `batch`/`silent` la nivel de repository.

---

## 🔁 REPOSITORY / SYNC RULES

### Reguli obligatorii:
- UI-ul NU trebuie să facă sincronizări masive de cache prin metode care declanșează notifieri per item.
- Repository-ul trebuie să ofere metode `batch` / `silent` pentru importuri, refresh-uri mari și rehidratări de cache.
- Notifierii globali se declanșează o singură dată la finalul unui batch, NU pentru fiecare item.
- Cache-ul local gol NU trebuie să șteargă sau să suprascrie cloud-ul.
- Sync-ul cloud este best-effort și NU trebuie să blocheze interacțiunea utilizatorului.
- Retry-urile de sync/delete trebuie să aibă lock și cooldown.
- Trigger-ele redundante de sync trebuie debounced sau coalesced; guard-ul de `alreadySyncing` singur nu este suficient dacă runtime-ul este bombardat cu apeluri.
- Repository-ul gestionează queue, batch import și invalidarea cache-ului; UI-ul doar cere datele și reacționează controlat.

### Reguli speciale pentru importuri / refresh-uri mari:
- Dacă trebuie aduse multe documente din cloud pentru lookup-uri, încarcă-le pentru UI fără să faci `saveX(...)` în masă din pagină.
- Dacă există nevoie reală de persistare locală, aceasta se face prin metodă repository-level `silent` sau `batch`, cu maximum un notifier final.
- Dacă nu există metodă sigură `silent`, se preferă folosirea datelor în memorie pentru UI și se evită rescrierea agresivă a cache-ului din pagină.

---

## ✅ PERFORMANCE QA CHECKLIST

Checklist obligatoriu înainte de a declara „rezolvat” un patch de performanță:
- [ ] modulul se deschide fără blocare
- [ ] scroll-ul este fluid
- [ ] butoanele principale răspund rapid
- [ ] dialogurile se deschid rapid
- [ ] salvarea nu blochează UI
- [ ] nu există reload storm
- [ ] nu există zeci de `setState` / `build` pentru o singură acțiune
- [ ] background tasks nu pornesc simultan în exces
- [ ] erorile background sunt logate
- [ ] testat pe Windows
- [ ] testat pe Android sau menționat clar de ce nu s-a putut

### Template `forceSyncLocalToCloud()` — OBLIGATORIU în orice repository nou:
Implementare de referință: `deviz_tehnic_repository.dart`. Logică: iterează `listLocal()` → dacă `id.startsWith('local-')` folosește `_col.add()` + actualizează cache cu noul ID → altfel `_col.doc(id).set(merge:true)` → queue fiecare item. Returnează nr. sincronizate. Try/catch per item cu debugPrint.

### Template statics diagnostice — OBLIGATORIU în orice repository nou:
Adaugă `static String? lastFirestoreError`, `static int lastFirestoreCount = -1`, `static int lastLocalCount = 0`. Actualizează în `list()`: local count la început, cloud count la succes, error string la catch.

### Template buton sync în pagina de listare — OBLIGATORIU:
```dart
// În search bar / toolbar (MEREU vizibil, nu doar în empty state):
IconButton(
  icon: _syncing
      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
      : Icon(Icons.cloud_sync_outlined),
  tooltip: 'Sincronizează la cloud',
  onPressed: (_loading || _syncing) ? null : _forceSyncToCloud,
),
// În empty state, suplimentar:
if (MyRepository.lastLocalCount > 0)
  OutlinedButton.icon(
    onPressed: (_loading || _syncing) ? null : _forceSyncToCloud,
    icon: Icon(Icons.cloud_upload_outlined, size: 16),
    label: Text('Trimite la cloud (${MyRepository.lastLocalCount} doc.)'),
  ),
```

### Referință implementare corectă:
- `deviz_tehnic_repository.dart` + `deviz_tehnic_list_page.dart` ✅ mai 2026
- `deviz_filtre_cta_repository.dart` + `deviz_filtre_cta_page.dart` ✅ mai 2026
- `partner_financial_repository.dart` (fixat mai 2026) ✅
- `local_app_data_repository.dart` — saveFieldPhoto/deleteFieldPhoto ✅
- `local_app_data_repository.dart` — listAppointments() BUG 7 fix ✅ mai 2026

---

## 🔥 REGULI FIRESTORE — OBLIGATORII

### ❌ NU folosi .where() + .orderBy() împreună fără index explicit!
```dart
// GREȘIT — necesită index compus Firestore; dacă indexul lipsește → excepție silențioasă:
_collection.where('partner_id', isEqualTo: id).orderBy('date', descending: true).get()

// CORECT — query simplu, sortare în Dart:
final snapshot = await _collection.where('partner_id', isEqualTo: id).get();
return _sortItems(snapshot.docs.map(...).toList()); // sortare în Dart
```

**De ce:** Indexul compus se creează manual în Firebase Console. Dacă lipsește,
query-ul aruncă excepție care se prinde silențios → fallback la cache local gol → datele "dispar".

### ❌ NU înghiți erori Firestore fără măcar a sorta în Dart alternativa
```dart
// catch (_) {} — PERICULOS dacă nu există fallback local complet
// Adaugă întotdeauna fallback la date locale:
} catch (_) {
  return _sortTransactions(localFiltered); // returnează ce avem local
}
```

### Reguli query Firestore:
- `.where()` simplu (egalitate) = OK fără index
- `.where().where()` = OK dacă câmpuri diferite
- `.where().orderBy()` = NECESITĂ index compus → evită, sortează în Dart
- `.orderBy()` singur = OK (index automat pe orice câmp)

---

## 📷 REGULI POZE TEREN (field_photos) — OBLIGATORII

### Flux corect upload poză:
1. `createPhotoRecord()` → upload Firebase Storage (direct, fără check isOnline)
2. `saveFieldPhoto(record)` → local cache → **queue obligatoriu** → Firestore (best-effort)
3. La revenire internet: `syncPending()` → scrie în Firestore din queue

### Guard resurrection (poze șterse vs. poze nesincronizate):
```dart
// În merge loop (listFieldPhotos):
final localFilePath = item.filePath.trim();
final localFileExists = localFilePath.isNotEmpty && File(localFilePath).existsSync();
// Skip DOAR dacă fișierul local NU există pe dispozitiv (= alt device, poza posibil ștearsă)
if (!localFileExists && item.downloadUrl.trim().isNotEmpty) {
  continue; // evită "învierea" pozelor șterse
}
// Dacă fișierul local EXISTĂ = suntem pe dispozitivul original → scriem în Firestore
```

**De ce contează:** Fără guard, orice dispozitiv cu cache vechi re-uploadă pozele șterse.
Cu guard prea agresiv (doar pe downloadUrl), pozele noi nu ajung niciodată în Firestore.

### NetworkImage pe Windows:
```dart
// GREȘIT pe Windows — HTTP request se blochează indefinit:
return Image(image: NetworkImage(url));

// CORECT — fetch manual via http.get() + Image.memory():
if (provider is NetworkImage) {
  return _PhotoNetworkImage(url: provider.url, fit: BoxFit.cover);
}
```
Widget `_PhotoNetworkImage` cu `http.get()` în `field_photos_page.dart` ✅

### Collections Firestore:
- `field_photos` — documente cu source_module, source_entity_id, download_url etc.
- Queue: `CloudEntityType.fieldPhotos` → `queueFieldPhotoUpsert/Delete`

---

## 🏗️ ARHITECTURA REPOSITORY-URILOR

### Pattern standard: `*_cloud_repository.dart`
NICIODATĂ nu crea fișiere `firebase_*_repository.dart` noi.

```
lib/features/<modul>/
  ├── <modul>_models.dart            ← modele de date
  ├── <modul>_cloud_repository.dart  ← Firebase/Firestore
  ├── <modul>_local_store.dart       ← cache local (SharedPreferences)
  └── <modul>_page.dart              ← UI
```

- Local store OBLIGATORIU pentru orice modul cu date critice
- Cloud repository apelează întotdeauna local store înainte de Firebase
- NU șterge fișiere `firebase_*` existente — sunt implementări reale

---

## ⚡ REGULI PERFORMANȚĂ — OBLIGATORII

### ❌ ANTI-PATTERN 1 — Scriere în buclă (O(n²))
```dart
// GREȘIT:
for (final item in items) { await repository.saveOne(item); }
// CORECT:
await repository.saveAllBatch(items); // O singură citire + scriere
```

### ❌ ANTI-PATTERN 2 — Operații grele în initState/build
```dart
// GREȘIT:
void initState() { super.initState(); _heavyLoad(); }
// CORECT:
void initState() { super.initState(); Future.microtask(_load); }
```

### ❌ ANTI-PATTERN 3 — setState() în cascadă
```dart
// GREȘIT: 3 rebuild-uri
setState(() => _a = 1); setState(() => _b = 2); setState(() => _c = 3);
// CORECT: un singur rebuild
setState(() { _a = 1; _b = 2; _c = 3; });
```

### ❌ ANTI-PATTERN 4 — Pagină cu listă care nu se reîncarcă după startup
Firebase SDK are DNS lookup ~2s la startup (`isOnline=false`). Fără listener, lista rămâne goală pentru totdeauna dacă pagina se deschide în aceste 2s.
```dart
// CORECT — obligatoriu în orice pagină cu liste din Firebase:
void initState() {
  super.initState();
  FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
  Future.microtask(_load);
}
void dispose() {
  FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
  super.dispose();
}
void _onOnlineChanged() {
  if (FirebaseBootstrap.onlineNotifier.value && _items.isEmpty && !_loading) _load();
}
```

### ❌ ANTI-PATTERN 5 — Lista goală fără RefreshIndicator și fără debug info
Lista goală TREBUIE să aibă `RefreshIndicator(onRefresh: _load)` + card debug cu `FirebaseBootstrap.isInitialized`/`isOnline` + `FilledButton` "Reîncarcă din cloud". Fără acestea utilizatorul nu poate forța reîncărcarea și nu știe dacă e problemă de rețea.

### ✅ CHECKLIST PERFORMANȚĂ:
- [ ] No `await saveOne()` în buclă → folosește batch
- [ ] Operații grele NU în `initState` sau `build()` → `Future.microtask(_load)`
- [ ] `setState()` o singură dată per grup de modificări
- [ ] Liste mari → `ListView.builder` (NICIODATĂ Column cu map)
- [ ] Dispose controllers în `dispose()`
- [ ] **`FirebaseBootstrap.onlineNotifier` listener** pentru reîncărcare automată
- [ ] **`RefreshIndicator` pe lista goală** + buton Reîncarcă + info Firebase status

---

## 🔄 REGULI SINCRONIZARE, CROSS-DEVICE ȘI COMPATIBILITATE

### Compatibilitate versiuni vechi — OBLIGATORIU
- **Câmpuri noi în modele → valoare `?? defaultValue` în `fromMap()`**
  → Fără default, versiunile vechi crapa când citesc date noi din Firestore
- Niciodată nu redenumi câmpuri existente — adaugă câmpuri noi, păstrează-le pe cele vechi
- `toMap()` → include AMBELE câmpuri (vechi + nou) dacă sunt aliases
- `fromMap()` → acceptă ambele variante: `map['new_key'] ?? map['old_key'] ?? defaultValue`

### Cross-device sync — OBLIGATORIU pentru orice date critice
Orice date care trebuie văzute pe ALT dispozitiv (PC ↔ telefon) TREBUIE să aibă:
1. **Scriere în Firestore** (nu doar în Storage sau SharedPreferences)
2. **Queue offline** (se sincronizează când revine internetul)
3. **Query fără `.orderBy()`** (evită index compus Firestore → erori silențioase)

### ❌ BUG 5 — Date vizibile local dar invizibile cross-device
```
Simptom: Date apar pe dispozitivul A dar NU pe dispozitivul B.
Cauze posibile:
  1. Scriere DOAR în Storage (nu și în Firestore) — „pozele vechi" din versiunile pre-field_photos
  2. Scriere DOAR în SharedPreferences (local cache) — queue nu a rulat
  3. Query Firestore cu .orderBy() → index lipsă → excepție silențioasă → date „dispar"
  4. source_entity_id greșit în Firestore → query returnează 0 rezultate corect

Diagnostic:
  [FieldPhotos] listFieldPhotos: module="..." entityId="..." isInit=true isOnline=true
  [FieldPhotos] Firestore returned 0 docs ← problema e în Firestore, nu în cod
  → Soluție: verifică manual în Firebase Console dacă documentele există cu ID-ul corect
```

### ❌ BUG 6 — Versiunea veche nu scria în Firestore
Versiunile vechi ale aplicației (înainte de implementarea unui modul cloud) uploadau
date în Storage/local fără documente Firestore → noua versiune nu le vede.
→ Soluție: script de MIGRARE care creează documentele Firestore din datele existente
→ Exemplu: `FieldPhotosMigrationPage` pentru poze teren vechi

### Checklist cross-device pentru orice modul NOU sau MODIFICAT:
- [ ] Datele se salvează LOCAL când nu e internet?
- [ ] La revenirea internetului se sincronizează în Firebase (via queue)?
- [ ] Câmpurile din Firestore se numesc exact cum caută query-ul?
- [ ] Versiunile vechi nu crapa cu datele noi (backward compatible)?
- [ ] Nu apar DUPLICATE după sync?
- [ ] Script de migrare pentru datele create cu versiunea veche (dacă e cazul)?
- [ ] Pagina cu listă are `onlineNotifier` listener + `Future.microtask(_load)`?
- [ ] Lista goală are `RefreshIndicator` + buton Reîncarcă + info Firebase status?

### Citire CLAUDE.md — REGULĂ NOUĂ:
**La ORICE task nou (nu doar sesiune nouă), citește CLAUDE.md complet.**
Motivul: regulile se actualizează des. O regulă citită la începutul sesiunii
poate fi deja depășită la al treilea task din aceeași sesiune.

---

## ⌨️ REGULA CÂMPURI TEXT

În TOATE câmpurile editabile adaugă:
```dart
textCapitalization: TextCapitalization.sentences
```
**Excepții:** Email, parolă, CUI, IBAN, URL, câmpuri number/phone

---

## 🔡 REGULA DIACRITICE ROMÂNE — OBLIGATORIE

ÎNTOTDEAUNA folosește diacriticele corecte în cod Dart:
- `ă` (nu `Ä‚` sau `Äƒ`)
- `â` (nu `Ã¢`)
- `î` (nu `Ã®`)
- `ș` (nu `ÅŸ` sau `È™`) — s cu virgulă jos, NU cu cedilă (ş)
- `ț` (nu `È›`) — t cu virgulă jos, NU cu cedilă (ţ)

**REGULĂ:** Fișierele `.dart` sunt UTF-8. Scrie direct caracterele românești, nu HTML entities, nu escape sequences.

**CAUZA BUG-ULUI:** PowerShell 5.1 citește fișierele `.ps1` ca Windows-1252 (nu UTF-8) dacă lipsește BOM-ul. Bytes UTF-8 ai diacriticelor sunt re-interpretați ca Latin-1 și scrieți dublu-encodat în fișier.

**SOLUȚIE:** Nu genera text românesc prin scripturi PowerShell. Editează fișierele Dart direct cu Edit tool — charset-ul este păstrat corect.

**VERIFICARE obligatorie după orice text românesc generat:**
```
grep -rn "Ä\|È\|Ã\|ÅŸ" lib/ --include="*.dart"
```
Dacă găsește ceva = encoding greșit, fixează imediat cu Edit tool.

```dart
// GREȘIT:
label: 'PlatÄƒ angajaÈ›i'
text: 'ExecuÈ›ie'

// CORECT:
label: 'Plată angajați'
text: 'Execuție'
```

---

## 📐 LAYOUT PDF — CONSTANTE ȘI FORMATE (mai 2026)

### ProTermPdfLayout — clasa de constante (`lib/core/pdf/pro_term_pdf_template.dart`):
```dart
ProTermPdfLayout.a4Portrait          // A4 portrait, 15mm margini
ProTermPdfLayout.a4PortraitCompact   // A4 portrait, 10mm margini
ProTermPdfLayout.a4Landscape         // A4 landscape, 10mm margini
ProTermPdfLayout.a4LandscapeMicro    // A4 landscape, 8mm margini
ProTermPdfLayout.a5Portrait          // A5 portrait, 10mm margini
ProTermPdfLayout.fontTableMicro      // 5.5pt — pentru tabele foarte compacte
ProTermPdfLayout.marginMicro         // 8mm × PdfPageFormat.mm
```

### Reguli format pagină per document:
| Document | Format | Margini | Note |
|---|---|---|---|
| Pontaj lunar tabelar | A4 landscape | 8mm | `pw.Page` (1 pagină fixă), nu MultiPage |
| Stat plată HR | A4 portrait | 10mm | 12 coloane: fără Venit net / Deducere / Baza calc |
| Fluturași individual | A4 portrait | 10mm | 2 coloane: stânga=Venituri+Rețineri, dreapta=Taxe+Tichete+Net |
| PV/PIF | A4 portrait | ≈10mm | Via `ProTermPdfTemplate.generateDocument()` |
| Contract | A4 portrait | ≈10mm | Via `generateDocument()`, 9pt, ≤2 pagini |
| Ofertă comercială | A4 landscape | 18/12/18/20pt | Header repeat page 2+ via `header:` callback |
| Deviz tehnic | A4 portrait | 24pt | Header repeat via `header:` callback |
| Devize filtre CTA | A4 landscape | 8mm | FiltreCtaPdfService |

### Pontaj lunar — coloane (719pt < 796pt disponibil):
- Angajat=79pt, Echipă=40pt, TM=34pt, TM/zi=28pt
- Zile 1-31: 13pt × 31 = 403pt
- Ore=23pt, CO/CM/CCC/INV/ABS/MAT/ST/ALT: 14pt × 8 = 112pt

### Fluturași — layout 2 coloane:
- Coloana stângă: Date generale + Venituri + Rețineri
- Coloana dreaptă: Contribuții și taxe + Tichete de masă + Net final
- Secțiuni opționale jos: Detaliu popriri + Plăți înregistrate + Referințe

### Stat plată HR — 12 coloane (187mm < 190mm disponibil A4 portrait 10mm):
- Angajat=35mm, Funcție=25mm, Ore=8mm, Brut=14mm, CAS=12mm, CASS=12mm
- Impozit=12mm, Tichete=16mm, Rețineri=13mm, Net fără TM=14mm, NET FINAL=14mm, Status=12mm
- Coloana "Rețineri" = `item['deduction_total']`

---

## 🔤 REGULA PDF DIACRITICE

NICIODATĂ PDF fără font cu suport românesc!

```dart
import '../../core/pdf/pdf_font_helper.dart';
await PdfFontHelper.initialize();
final doc = pw.Document(theme: PdfFontHelper.theme);
```

Font: Arial (arial.ttf + arialbd.ttf) — suportă ă, â, î, ș, ț ✅

---

## 📂 REGULA PDF ACȚIUNI

După ORICE generare PDF, afișează modal cu acțiuni:
```dart
import '../../core/pdf_actions_helper.dart';
await PdfActionsHelper.showPdfActions(context, filePath: path, ...);
```
NICIODATĂ SnackBar simplu cu calea fișierului.

---

## 📝 REGULĂ UX DOCUMENTE — AUTO-COMPLETARE CÂMPURI (OBLIGATORIE)

La orice document nou creat în aplicație (PV, PIF, Log F-Gas, ofertă, deviz,
contract, sau orice alt document viitor), câmpurile trebuie auto-completate din
sursele disponibile:

**Tehnician / Persoana de contact:**
- Din userul curent logat: `FirebaseAuth.instance.currentUser`
  (`.displayName ?? .email`)
- Fallback: `CompanyProfile.contactName`
  (NOTĂ: câmpul real e `contactName`, NU `contactPerson` — `contactPerson` nu
  există pe `CompanyProfile` și dă eroare de compilare)

**Date client (nume, adresă, telefon, email):**
- Din `ClientRecord` asociat documentului (via `clientId` / `beneficiaryClientId`)
- Fallback: din datele reclamației/programării/lucrării curente

**Date firmă (nume, CUI, adresă, telefon, email, IBAN, bancă):**
- Din `CompanyProfile` (`loadCompanyProfile` din repository)
- NICIODATĂ hardcodate în cod

**Autorizații / certificate (F-Gas, alte autorizații):**
- Din `CompanyProfile` câmpurile dedicate
  (`agfrCompanyAuthorizationNumber` etc.)

**Locație / adresă obiectiv:**
- Din reclamație/programare/lucrare curentă (câmpul `location`)
- Fallback: adresa clientului din `ClientRecord` (`address`, `city`, `county`)

**Regulă generală:**
- Câmpurile auto-completate sunt ÎNTOTDEAUNA editabile manual
- Auto-completarea se face în `initState()` la crearea documentului
  (sincron pentru `FirebaseAuth.currentUser`; async best-effort via
  `Future.microtask` pentru `loadCompanyProfile` / `listClients`)
- Dacă valoarea există deja (document editat) → NU suprascrie
- Dacă sursa lipsește → câmp gol, nu crash, nu valoare inventată

**Implementare de referință:** `repair_report_editor_page.dart` →
`_autofillMissingFields()` + `_autofillFromRepository()` (iun 2026)

---

## 👁️ REGULA VIZIBILITATE LISTE

La ORICE pagină cu listă:
- **Desktop (≥600px):** filtrele MEREU vizibile
- **Mobil (<600px):** filtrele ascunse, buton "Filtre" cu badge
- Folosește `LayoutBuilder` → `isWide = constraints.maxWidth >= 600`
- Liste mari → `ListView.builder` OBLIGATORIU

---

## 📏 REGULA DIMENSIUNE FIȘIERE

- Pagini `*_page.dart`: MAX 800 linii
- Widget-uri: MAX 400 linii
- Repository-uri: MAX 600 linii
- Modele: MAX 300 linii

### Reguli obligatorii la CREAREA oricărui fișier nou:

- ÎNAINTE de a scrie un fișier nou, estimează câte linii va avea.
- Dacă estimarea depășește limita pentru tipul respectiv →
  PLANIFICĂ din start împărțirea în mai multe fișiere și
  prezintă planul înainte de implementare.
- NICIODATĂ nu crea un fișier nou care depășește limita
  justificând că „se poate refactoriza ulterior".
- Pentru pagini complexe (formulare mari, editoare, pagini cu
  multe tab-uri): împarte din start în:
  - `*_page.dart` — scheletul paginii + navigare (MAX 400 linii)
  - `*_widgets.dart` — widget-uri UI reutilizabile
  - `dialogs/` — fiecare dialog într-un fișier separat
  - `services/` — logică business separată de UI
- La orice feature nou cu mai mult de 3 componente vizuale
  distincte: fișiere separate din start, nu un singur fișier monolitic.

### Verificare obligatorie înainte de commit:
```bash
# Niciun fișier nou nu trebuie să depășească limita tipului său:
find lib -name "*_page.dart" -newer .git/index | xargs wc -l
find lib -name "*_widget*.dart" -newer .git/index | xargs wc -l
```

---

## ❓ REGULA BUTON HELP — SISTEM INTELIGENT (iun 2026)

În FIECARE modul/pagină nouă sau modificată, folosește **noul sistem**:
```dart
import '../../core/help/help_module_button.dart';
// ...
const HelpModuleButton(moduleId: 'cheie_modul')
```

### Module help disponibile (Firestore `help_content/{moduleId}`):
- `programari` · `hr` · `reclamatii` · `financiar_parteneri` · `crm`
- `stoc` · `echipamente` · `oferte` · `agfr` · `deviz_tehnic`
- `jobs` · `clienti` · `garantii` · `dashboard`

### Arhitectura sistemului Help:
```
lib/core/help/
├── help_models.dart        ← HelpModule, HelpModuleStep, HelpModuleFaq
├── help_repository.dart    ← singleton, cache memorie + Firestore
├── help_module_button.dart ← HelpModuleButton widget (4 tab-uri: Info/Ghid/FAQ/AI)
└── help_admin_page.dart    ← editor admin (ADMINISTRARE → Conținut Help)
```

### Funcționalități HelpModuleSheet:
- **Tab Info** — descriere modul + sfaturi
- **Tab Ghid** — pași numerotați cu iconițe
- **Tab FAQ** — întrebări frecvente expandabile
- **Tab AI Help** — întrebări libere via Claude Haiku (necesită cheie API în Setări → AI)

### Inițializare (main.dart — deja implementat):
```dart
HelpRepository.instance.initialize().then((_) {
  HelpRepository.instance.seedIfEmpty().catchError((_) {});
});
```

### La adăugarea unui modul nou:
1. Adaugă entry în `HelpRepository._defaultContent` (help_repository.dart)
2. Adaugă `const HelpModuleButton(moduleId: 'new_module')` în AppBar
3. Admin poate edita conținutul din ADMINISTRARE → Conținut Help

### NU mai folosi sistemul vechi:
```dart
// ❌ VECHI — nu mai folosi pentru pagini noi:
HelpButton(content: AppHelp.X)  // din widgets/help_button.dart

// ✅ NOU — pentru orice pagină nouă sau modificată:
HelpModuleButton(moduleId: 'cheie')
```

---

## 🔄 REGULA TASK QUEUE

Când primesc un task nou în timp ce lucrez:
1. NU mă opresc
2. Termin complet ce am început (dart analyze 0 erori)
3. Notific: "Termin [TASK CURENT] și trec la [TASK NOU]"

### Raport la finalul fiecărui task:
```
✅ Task finalizat: [NUME]
📋 Fișiere modificate: [LISTA]
🔍 dart analyze: 0 erori
💾 Backup-uri .bak: [CONFIRMARE]
```

---

## 🔗 REGULA LEGĂTURILE ÎNTRE MODULE

Înainte de orice modificare la un modul:
1. Găsește TOATE locurile care îl folosesc (import-uri, servicii, UI, PDF)
2. Actualizează TOATE referințele
3. Testează fluxurile care depind de modulul modificat
4. Raportează legăturile în raportul final

---

## 🏢 REGULA SETĂRI SOCIETATE

Valorile implicite vin ÎNTOTDEAUNA din `CompanyProfile`:
- TVA % → `defaultVatPercent` (default 21%)
- Profit % → `defaultProfitPercent` (default 15%)
- Regie % → `defaultOverheadPercent` (default 0%)
- NU hardcoda procente — folosește `profile.*`

---

## 📋 REGULA REGISTRATURĂ

Când un document se înregistrează în Registratură, numărul TREBUIE să fie EXACT cel al documentului sursă — NU se generează număr nou.

---

## 💰 MODUL FINANCIAR PARTENERI

### Fișiere principale:
- `partner_financial_models.dart` → PartnerTransaction, PartnerFinancialSummary
- `partner_financial_repository.dart` → CRUD + rebuild sold net
- `partner_financial_page.dart` → UI per partener + `_syncFromAppointments()`
- `partner_sale_form.dart` → vânzare din catalog
- `partner_purchase_form.dart` → achiziție liberă

### Reguli specifice:
- `listTransactionsForPartner()` returnează `[...cloud, ...localOnly]` — nu doar cloud
- Query Firestore FĂRĂ `.orderBy()` — sortare în Dart
- `consumMateriale` transactions: card expandabil apare când `materialLines.isNotEmpty || kitName.isNotEmpty`
- Kit din programare → câmpul `material_usage.kit_template_name` (snake_case)
- Alertă locală dacă sold net < -1000 RON

### ❗ FINANCIAR PARTENERI — REGULI OBLIGATORII (implementate iun 2026)

**`PartnerTransaction.financialDirection`** = getter calculat din `type` + `status`:
- `consumMateriale` → `'cost_materiale'` (exclus din sold, banner portocaliu)
- `incasareManuala` → `'plata_primita'` **MEREU** (indiferent de status — date vechi pot fi neplatit)
- `incasareProgramare`/`vanzareProdus` + platit → `'credit_incasat'` (ignorat)
- `incasareProgramare`/`vanzareProdus` + neplatit → `'credit_neincasat'` (de primit)
- `plata*/achizitie*` + platit → `'plata_efectuata_achitata'` (ignorat)
- `plata*/achizitie*` + neplatit → `'plata_efectuata'` (de plătit)

**Formula sold net**:
```
De încasat NET = max(Σ credit_neincasat − Σ plata_primita, 0)
```

**Reguli pentru cod nou**:
- `rebuildSummary()` folosește EXCLUSIV `t.financialDirection` — NU `type` sau `status` direct
- La orice tranzacție nouă creată de cod: `PartnerTransactionType` enum setează corect `financialDirection`
- `migrateTransactions()` rulează la `_load()` pentru date vechi fără `financial_direction`
- Badge-urile în UI citesc `t.financialDirection` (nu `t.status`)

### Collections Firestore:
- `partner_transactions` — toate tranzacțiile (includ câmpul `financial_direction` din iun 2026)
- `partner_financial_summary` — sold net per partener

### Semantica tipuri tranzacție în rebuildSummary():
- `incasareProgramare`/`vanzareProdus`/`consumMateriale` (intrare) → +De încasat
- `incasareManuala` (intrare) → **−De încasat** (plată primită efectiv, indiferent de status)
- `plataProgramare`/`achizitieProodus` (iesire) → +De plătit
- `plataManuala` (iesire) → **−De plătit** (plată efectuată efectiv, indiferent de status)
- Buton `calculate_outlined` în toolbar → forțează `rebuildSummary()` + reload

---

## 📋 BAZA NORME DEVIZ

- Colecție Firebase: `deviz_articole_template`
- Pagina: `lib/features/oferte/deviz_articole_baza_page.dart`
- Repository: `lib/features/oferte/deviz_articol_template_repository.dart`
- Sync offline: `queueDevizArticolTemplateUpsert/Delete`

## 📄 TIPURI DOCUMENTE DEVIZ

- `TipDocumentDeviz.devizLucrari` — default
- `TipDocumentDeviz.ofertaLucrari`
- `TipDocumentDeviz.situatieLucrari`
Câmpul `offer.tipDocument` (backward compatible).

---

## 🔍 ADĂUGARE RAPIDĂ CLIENT DIN ORICE MODUL (iun 2026)

### Fișiere principale:
- `lib/core/widgets/quick_add_client_dialog.dart` → `QuickAddClientSheet` (bottom sheet) + `showQuickAddClientDialog()` helper
- `lib/core/widgets/client_autocomplete_field.dart` → parametri noi: `repository?`, `tipEntitate`, `onClientAdded?`

### Cum funcționează:
- Când `ClientAutocompleteField` primește `repository: widget.appRepository` și nu are `onCreateNew`, afișează automat butonul roșu „+ [tipEntitate]"
- Butonul deschide `QuickAddClientSheet` (bottom sheet complet: identic cu formularul din modulul Clienți)
- Câmpuri: Tip (PF/PJ), Nume*, ANAF autofill (pt PJ), CUI/CNP, Reg. Com., Persoână contact, Telefoane (multiple), Email, Bancă + IBAN, Adresă + Oraș + Județ, Observații
- Clientul creat e salvat via `repository.saveClient()` și selectat automat în câmp
- `onClientAdded` actualizează lista locală din state + schimbă `key` → widget se reconstruiește cu clientul selectat

### Pattern obligatoriu în orice modul NOU cu selecție client:
```dart
ClientAutocompleteField(
  key: ValueKey('modul-client-${_selectedClientId ?? "none"}'),
  clients: _localClients,          // lista locală (nu widget.clients direct)
  initialClient: _clientById(_selectedClientId),
  onClientSelected: (c) => setState(() => _selectedClientId = c?.id),
  repository: widget.repository,   // sau widget.appRepository
  tipEntitate: 'Client',           // sau 'Beneficiar', 'Partener', 'Cumpărător'
  onClientAdded: (c) => setState(() {
    _localClients = [..._localClients, c];
    _selectedClientId = c.id;
  }),
)
```

### Module actualizate (iun 2026):
- `oferte_page.dart` → `_OfferFormDialog` primește `repository?` + `_localClients`
- `jobs_page.dart` → `_JobFormDialog` cu `_extraClients` list
- `reclamatii_list_page.dart` → `_NewComplaintDialog` cu `tipEntitate: 'Beneficiar'`
- `deviz_tehnic_form_page.dart` → `_localClients` din `widget.appRepository`
- `field_sales_page.dart` → `_FieldLeadDialog` primește `repository?`
- `programari_page.dart` → câmpul Societate contractantă + `onClientAdded` cu page+dialog setState

### NU mai crea buton „Adaugă" separat — folosește `repository:` în `ClientAutocompleteField`.
### `AddClientQuickDialog` (form complet cu ANAF) rămâne pentru câmpul beneficiar din Programări.

---

## ✅ CE ESTE IMPLEMENTAT

- Autentificare, clienți, angajați, field sales + PDF, sync offline toate modulele critice
- Email notificări programări, catalog materiale + stoc, vehicule, registratură
- HR: prezență, salarizare, fluturași, pontaje, concedii, deplasări, popriri CPC
- AGFR: echipamente, intervenții, rapoarte, F-Gas automatizări (GWP auto-fill, CO₂ live, bannere A2L/A3)
- Partner financial: tranzacții, sold net, dashboard, vânzare/achiziție catalog
- **Poze teren**: upload Storage + sync Firestore + offline queue (mai 2026)
- **Devize tehnice**: serii DVZ/OFR/STL, culori status, tip implicit cross-device (mai 2026)
- **Devize Filtre CTA**: 15 template-uri, editare prețuri, PDF A4 landscape, sync offline (mai 2026)
- **Modul Taskuri**: To-Do List, priorități, categorii, widget Dashboard, sync offline (mai 2026)
- **Financiar angajați**: PayEntry per programare, plăți, sold per angajat, sync offline (mai 2026)
- **Tarif prestabilit per angajat**: EmployeeSettings, tab Tarife, pre-fill programări (mai 2026)
- **Colorare calendar**: weekend + sărbători legale românești + Paște Ortodox (mai 2026)
- **Dashboard Financiar consolidat**: 8 secțiuni, grafic 6 luni CustomPainter, offline-first (mai 2026)
- **Semnătură electronică PV/PIF**: SignaturePadWidget, SignatureService, Firebase Storage (mai 2026)
- **Fișă completă client**: ClientProfilePage 4 tab-uri, WhatsApp + telefon în listă (mai 2026)
- **Alertă garanții expirate**: WarrantyAlertService, card Dashboard (mai 2026)
- **Template PDF unificat PRO TERM**: ProTermPdfTemplate #C62828, PV/PIF, Contract 13 articole (mai 2026)
- **HR Redesign**: hub 4 tab-uri, HrEmployeeDetailPage calculator + popriri, PDF fluturași cu plăți (mai 2026)
- **HR Formule fiscale OUG 89/2025**: CAS 25%, CASS 10% pe salariu_brut (TM net_direct exclus), deducere 600-7000 RON, stat plată 12 col (mai 2026)
- **Plată salariu HR**: HrPayrollPayment (avans/salariu/poprire), DataTable 17 col, PDF centralizator (mai 2026)
- **CRM Pipeline vânzări**: Kanban/Listă/Statistici, integrare auto Oferte, alertă startup (mai 2026)
- **Sistem Help inteligent**: HelpModuleButton 4 tab-uri (Info/Ghid/FAQ/AI), 14 module, HelpAdminPage (iun 2026)
- **Certificate garanție PDF**: 3 pagini — tabel echipament + 3 taloane intervenție + condiții OG 21/1992. Condiții hardcodate, NU se modifică. Regenerare bulk în toolbar (mai 2026)
- **Versiune în Drawer**: `package_info_plus`, format `v{version}+{buildNumber}` (iun 2026)
- **Auto-update in-app**: `app_version_checker.dart` + `update_available_banner.dart`, descărcare APK + instalare via `OpenFilex`. Doar Android. Ghid: `docs/ghid_actualizare_apk.md` (iun 2026)

---

## 👔 MODUL HR — REDESIGN (mai 2026)

### Structură tab hub:
- `hr_payroll_page.dart` → `DefaultTabController` cu 4 tab-uri:
  - **Tab 0 — Angajați**: Card per angajat (brut, net estimat, badge popriri) + buton Calculator → `HrEmployeeDetailPage`
  - **Tab 1 — Pontaj**: `_buildAttendance()` + `_buildLeaveRequests()` + `_buildLeaveAttendanceConflicts()` + buton Pontaj tabelar
  - **Tab 2 — Fluturași**: `_buildHeader()` (selecție lună + acțiuni rulare) + `_buildPayroll*()` + `_buildPayslips()` + `_buildVariablePayroll()` + `_buildAccountingReports()`
  - **Tab 3 — Setări HR**: `_buildHrAdmin()` + `_buildPayrollValidationDashboard()` (doar pentru `_canManageSensitiveHr`)

### HrEmployeeDetailPage (`hr_employee_detail_page.dart`):
- 3 sub-tab-uri: **Date personale** | **Calculator** | **Popriri**
- **Calculator interactiv**: câmpuri brut, tichete/zi, zile tichete, ore noapte, ore suplimentare → calcul live cu debounce 300ms
- Formule standalone (nu depinde de HrPayrollCalculator): CAS 25% pe salariu_brut, **CASS 10% pe salariu_brut** (TM exclus — net_direct), impozit 10% pe venitNet-deducere, CAM 2.25%, deducere personală (600 RON bază / 0 dep, prag 4050, plafon 7000 RON)
- **mealTicketCass = 0, mealTicketIncomeTax = 0** — TM net_direct: nu se taxează CASS sau impozit suplimentar pe TM
- **Tab Popriri**: listă popriri CPC art.729, adaugă/editează/șterge, buton "Distribuie proporțional" calculează cota per executor
- Salvare popriri via `HrVariablePayrollCatalogService.upsertGarnishment()`
- Optimistic UI la ștergere (BUG 9 pattern)

### Fluturașul PDF cu detaliu popriri și plăți:
- `HrPayslipPdfService.export()` → parametri opționali `garnishments: List<HrGarnishment>`, `payments: List<HrPayrollPayment>`
- Secțiune "Detaliu popriri" apare dacă `garnishmentReservedTotal > 0 || garnishments.isNotEmpty`
- Secțiune "Plăți înregistrate" apare dacă `payments.isNotEmpty` — afișează fiecare plată + total achitat + rest de plată
- Secțiunea "Contributii si taxe" include acum: CAS, CASS, Venit net, Deducere personală, Baza calcul impozit, Impozit venit
- Secțiunea "Net final" include: Net fără tichete + Tichete de masă + NET FINAL

### Formule fiscale HR (OUG 89/2025) — ACTUALIZATE mai 2026:
- **CAS** = round(grossTotalTaxable × 25%) — TM scutit de CAS
- **CASS** = round(grossTotalTaxable × 10%) — TM exclus din baza CASS (TM net_direct, fără taxe suplimentare)
- **venitNet** = grossTotalTaxable + TM - CAS - CASS + neimpozabile
- **Deducere personală**: baza 600 RON (0 dep), +100/dep; prag 4050 RON, plafon 7000 RON; linear între prag și plafon
  - 0 dep → 600 RON, 1 dep → 700, 2 dep → 800, 3 dep → 900, 4+ dep → 1000 RON
- **taxableBase** = venitNet - deducerePersonală
- **Impozit** = round(taxableBase × 10%)
- **netFinal** = venitNet - impozit - rețineri - avans - popriri
- **Net fără TM** = netFinal - mealTicketsWithinCap (coloană nouă în stat)
- `nrPersoaneIntretinere` în `HrEmployeeProfile` + `HrPayrollInputSnapshot` (OUG 89/2025)
- Câmp editabil în dialog profil HR (hr_payroll_page.dart)
- Stat de plată PDF: 14 coloane (Angajat, Funcție, Ore, Brut, CAS, CASS, Venit net, Deducere, Baza calc, Impozit, Net fără TM, Tichete, NET FINAL, Status)

### Reguli critice HR:
- **NU modifica `hr_payroll_calculator.dart`** altfel decât formulele fiscale de mai sus
- **NU modifica `hr_monthly_timesheet_page.dart`** — integrat ca-atare în Tab Pontaj
- **NU modifica modelele de date** — HrPayslip, HrGarnishment etc. rămân neschimbate
- Calculul din HrEmployeeDetailPage este estimativ (pentru ce-if), nu înlocuiește rularea oficială
- La revenire din HrEmployeeDetailPage → `_reload()` automat (popririle pot fi schimbate)

---

## 💳 MODUL PLATĂ SALARIU HR (mai 2026)

### Fișiere principale:
- `lib/features/hr_payroll_run/hr_payroll_payment_models.dart` → model `HrPayrollPayment`
- `lib/features/hr_payroll_run/hr_payroll_payment_repository.dart` → CRUD + offline queue singleton
- `lib/features/hr_payroll_run/hr_payroll_page.dart` → stare `_paymentsByEmployee`, dialog `_showPaymentDialog()`, buton "Înregistrează plată" în lista fluturași
- `lib/features/hr_payroll_run/hr_employee_detail_page.dart` → Tab 4 "Plăți" cu `_buildPaymentsTab()`

### Model HrPayrollPayment:
```dart
HrPayrollPayment {
  id, employeeId, employeeName,
  payrollMonth (DateTime — normalizat la prima zi a lunii),
  paymentType: 'avans' | 'salariu' | 'poprire',
  amount (double),
  paymentDate (DateTime),
  metodaPlata: 'numerar' | 'virament' | 'card',
  note, createdBy, createdAt
}
```

### Colecție Firestore: `hr_payroll_payments`
### SharedPreferences key: `'hr_payroll_payments_v1'`
### Sync offline: `CloudEntityType.hrPayrollPayments` → `queueHrPayrollPaymentUpsert/Delete`

### Repository — metode principale:
- `savePayment(payment)` → local → queue → Firestore fire-and-forget
- `deletePayment(paymentId)` → local → queue delete → Firestore fire-and-forget
- `listPaymentsForEmployeeMonth(employeeId, payrollMonth)` → local only (fără Firestore)
- `listPaymentsForMonth(payrollMonth)` → local only, returnează `Map<employeeId, List<payment>>`
- `listPaymentsForEmployee(employeeId)` → merge cloud+local cu BUG7 fix
- `calculateRestDePlata(employeeId, payrollMonth, netFinal)` → `netFinal - totalAchitat`
- `forceSyncLocalToCloud()` → re-publică toate plățile locale

### HrPayrollEmployeeFinancialSummary (hr_payroll_run_models.dart):
- Model date complet per angajat: brutTotal, cas, cass, impozit, deducerePersonala, ticheteValoare, netFaraTichete, netFinal, avansPlatit, salariuPlatit, restDePlata, totalPlatit, popririRetinute, popririPlatite, popririRestDePlata, esteAchitatIntegral
- `HrPayrollEmployeeFinancialSummary.calculeaza({payslip, platiAngajat, functia, employeeName})` → calcul automat din HrPayslip + List<HrPayrollPayment>
- **Notă:** identificatorii sunt ASCII (fără diacritice) — Dart 3.x nu acceptă ă/â/î în identificatori

### Flux UI în hr_payroll_page.dart:
1. `_reload()` → `HrPayrollPaymentRepository.instance.listPaymentsForMonth(month)` → `_paymentsByEmployee`
2. `_buildPayslips()` → `_buildPayslipsTable()` → DataTable 17 coloane cu scroll orizontal
3. Butoane rapide per rând: avans (💰), rest (💳), poprire (⚖️ — vizibil dacă popririRetinute > 0)
4. `_showGarnishmentPaymentDialog()` → HrPayrollPayment cu paymentType='poprire' → optimistic UI
3. Menu ⋮ al fluturașului → "Înregistrează plată" → `_showPaymentDialog()`
4. Dialog pre-completat cu rest de plată, tip implicit 'salariu', metoda 'numerar'
5. Salvare: `HrPayrollPaymentRepository.instance.savePayment()` + optimistic UI update

### Fluturașul PDF cu plăți:
```dart
HrPayslipPdfService.export(
  ...,
  payments: payslipPayments, // filtrare locală din _paymentsByEmployee
)
```
Secțiune "Plăți înregistrate" apare automat în PDF dacă `payments.isNotEmpty`.

### Card sumar Dashboard:
- Apare în `_buildAdminSections()` dacă există plăți înregistrate în luna curentă
- Arată: nr. angajați cu plăți, total avansuri, total salarii, total general
- Vizibil: admin + birou
- Date: `HrPayrollPaymentRepository.instance.listPaymentsForMonth(DateTime.now())` best-effort

---

## 📄 PACHETUL 3 — DOCUMENTE PROFESIONALE UNIFICATE

### Fișiere principale:
- `lib/core/pdf/pro_term_pdf_template.dart` → Template unificat cu culori brand PRO TERM SRL
- `lib/features/jobs/job_site_document_pdf_service.dart` → PV Montaj / PIF — folosește ProTermPdfTemplate
- `lib/features/jobs/contract_pdf_service.dart` → CONTRACT DE PRESTĂRI SERVICII cu 13 articole
- `lib/features/documents/documente_page.dart` → Hub documente cu job_site_documents din Firestore

### ProTermPdfTemplate — culori brand:
- `primaryRed = PdfColor(0.7765, 0.1569, 0.1569)` ← #C62828 (constante, nu fromHex)
- `lightRed = PdfColor(1.0, 0.9216, 0.9333)` ← #FFEBEE
- `darkText = PdfColor(0.1294, 0.1294, 0.1294)` ← #212121
- `mediumText = PdfColor(0.3804, 0.3804, 0.3804)` ← #616161
- `lightGray = PdfColor(0.9608, 0.9608, 0.9608)` ← #F5F5F5
- **IMPORTANT:** `PdfColor.fromHex()` NU este const — folosește `PdfColor(r, g, b)` pentru constante statice

### ProTermPdfTemplate — metode disponibile:
`buildHeader`, `buildPartiesSection`, `buildJobInfoSection`, `buildTable`, `buildSection`, `buildSignatureSection`, `buildPageFooter`, `generateDocument` (async), `buildInfoRow`, `buildFinancialTotals`

### ContractData — câmpuri:
- `contractNumber`, `contractDate`, `clientName`, `clientAddress`, `clientCui`, `clientPhone`
- `jobCode`, `jobTitle`, `location`, `teamName`, `teamMembers`
- `materialTotal`, `laborTotal`, `vatPercent`, `currency`
- `executionTerm`, `paymentTerm`, `advance`, `installments`, `penalties`
- `materialsProvider`, `logistics`, `receptionClause`, `observations`

### Cum se folosesc din altă pagină:
```dart
// PV/PIF — export direct
final path = await JobSiteDocumentPdfService.export(
  repository: widget.repository,
  document: jobSiteDocumentRecord,
);
await PdfActionsHelper.showPdfActions(context, filePath: path, title: '...');

// Contract — dialog + export
// (totul în _onGenerateContract() din lucrare_detalii_page.dart)
final path = await ContractPdfService.export(
  repository: widget.repository,
  data: ContractData(...),
);
await PdfActionsHelper.showPdfActions(context, filePath: path, title: '...');
```

### documente_page.dart — surse de date:
1. `listRegistryEntries()` — registratură (cu filePath)
2. `listAppointments()` → linkedDocuments (cu filePath)
3. `listRepairReports()` — PV reparație (cu pdfPath)
4. `listWarrantyInterventionReports()` — PV PIF / garanție (cu generatedDocumentPath)
5. `listAgfrReports()` — PV AGFR (cu generatedDocumentPath)
6. `listWarrantyCertificates()` — certificate garanție (cu generatedDocumentPath)
7. **`Firestore job_site_documents` global query** — PV montaj / PIF (cu generatedDocumentPath) — best-effort online-only

---

## 📊 MODUL DASHBOARD FINANCIAR CONSOLIDAT

### Fișiere principale:
- `lib/features/dashboard/financial_dashboard_service.dart` → agregare date din SharedPreferences (offline-first)
- `lib/features/dashboard/financial_dashboard_page.dart` → UI cu 8 secțiuni + grafic CustomPainter
- Navigație: secțiunea FINANCIAR în `role_ready_shell.dart`, destinație `dashboard_financiar`

### Surse de date (SharedPreferences keys):
- `ultra_appointments_v1` — programări (Appointment.fromMap)
- `ultra_jobs_v1` — lucrări (JobRecord.fromMap)
- `employee_pay_entries_v1` — costuri angajați
- `employee_financial_summaries_v1` — solduri angajați
- `partner_financial_summaries_v1` — solduri parteneri

### Secțiuni UI:
1. **Încasări** — luna curentă / luna trecută / an curent
2. **Profit lunar** — breakdown costuri + marjă
3. **Alertă plăți restante** — parteneri + clienți + nr. facturi
4. **Datorii de plătit** — angajați + parteneri + total
5. **Grafic 6 luni** — CustomPainter (fără fl_chart): bare Încasări/Costuri/Profit
6. **Activitate** — programări azi/săptămână, lucrări în curs/finalizate luna
7. **Top parteneri de încasat** — top 3 sold pozitiv
8. **Top angajați de plătit** — top 3 sold de plată

### Reguli specifice:
- NU face cereri Firestore — citește exclusiv din SharedPreferences
- `onlineNotifier` listener pentru reîncărcare automată la conectare
- `Future.microtask(_load)` în initState
- Grafic fără librării externe — CustomPainter cu `dart:ui` explicit (`ui.TextDirection.ltr`)
- Vizibil DOAR pentru admin și birou

---

## 💰 MODUL FINANCIAR ANGAJAȚI

### Fișiere principale:
- `lib/features/hr/employee_financial_models.dart` → EmployeePayEntry, EmployeePayment, EmployeeFinancialSummary
- `lib/features/hr/employee_financial_repository.dart` → CRUD + offline queue + rebuild summary (singleton)
- `lib/features/hr/employee_financial_page.dart` → Tab 1: Costuri perioadă | Tab 2: Istoric plăți

### Colecții Firestore:
- `employee_pay_entries` — suma datorată per angajat per programare
- `employee_payments` — plăți efective înregistrate
- `employee_financial_summary` — sumar sold per angajat (doc ID = employeeId)

### Sync offline:
- `CloudEntityType.employeePayEntries/employeePayments/employeeFinancialSummary`
- Pattern standard: local → queue upsert/delete → Firebase fire-and-forget
- `_rebuildSummary()` cu guard dacă local gol (BUG 2)
- `forceSyncLocalToCloud()` — buton ☁️↔ în toolbar

### Integrare programări:
- Buton "Plată angajați" în dialogul detalii programare (vizibil pentru admin)
- Dialog `_EmployeePayDialog` în `programari_page.dart` — pre-completare rapidă pentru angajații alocați
- Leagă `EmployeePayEntry.appointmentId` cu `Appointment.id`

### Navigație:
- Destinație `financiar_angajati` în secțiunea HR din `role_ready_shell.dart`
- Vizibil pentru: `admin`, `birou`

### Reguli specifice:
- NU .orderBy() în Firestore — sortare în Dart
- `listPayEntriesForEmployee/Appointment()` → FĂRĂ cloud fetch (doar local) pentru appointment-ul curent
- `listAllPayEntries()` → merge cloud+local cu perioadă opțională
- Optimistic UI la ștergere plăți (BUG 9)
- Firebase direct cu `.catchError((_){})` — nu await (BUG 8)

---

## 📋 MODULUL TASKURI

### Fișiere principale:
- `lib/features/tasks/app_task_models.dart` → AppTask, TaskCategorie, TaskPrioritate, sortTasksActive/Completed
- `lib/features/tasks/app_task_repository.dart` → CRUD + offline queue singleton (AppTaskRepository.instance)
- `lib/features/tasks/app_task_page.dart` → Pagină principală cu filtre chips, secțiuni De făcut/Efectuate
- `lib/features/tasks/app_task_form_dialog.dart` → Dialog adăugare rapidă + editare
- `lib/features/tasks/task_dashboard_widget.dart` → Widget compact pentru Dashboard

### Colecție Firebase: `app_tasks`

### Model date:
```dart
AppTask {
  id, titlu, descriere?, categorie (TaskCategorie), prioritate (TaskPrioritate),
  createdAt, deadline?, completed, completedAt?, createdBy (userId)
}
```

### Categorii + Priorități:
- Categorii: ofertare📋, programare📅, financiar💰, apel📞, email✉️, intern🏢, altele📌
- Priorități: urgent🔴, normal🟡, scazuta🟢

### Sortare taskuri active:
1. Urgente primele
2. Depășite (isOverdue) înaintea celor cu deadline viitor
3. Deadline cel mai apropiat
4. Cele mai recente (createdAt descendent)

### Integrare navigație:
- Destinație `taskuri` în `role_ready_shell.dart` — secțiunea TASKURI (prima din meniu)
- Widget `TaskDashboardWidget` în Dashboard — primul widget sub header, vizibil imediat
- Callback `onNavigateTo('taskuri')` din Dashboard → navighează la pagina completă

### Sync offline:
- `CloudEntityType.appTasks` + Firestore collection `app_tasks`
- Pattern standard: local (SharedPreferences) → queue upsert/delete → Firebase fire-and-forget
- Per utilizator: query cu `created_by == userId`; admin vede toate taskurile
- `listTasks(userId, isAdmin)` → merge cloud + local-only, preferă versiunea locală la conflict
- `forceSyncLocalToCloud()` — buton ☁️↔ în toolbar

---

## 📐 MODUL DEVIZE TEHNICE

### Fișiere principale:
- `deviz_tehnic_models.dart` → DevizTehnicRecord, DevizTehnicTipDocument, DevizTehnicStatus
- `deviz_tehnic_repository.dart` → CRUD + nextNumber + offline queue + setare default tip
- `deviz_tehnic_list_page.dart` → Listă cu filtre, culori card după status, butoane rapide status
- `deviz_tehnic_form_page.dart` → Formular creare/editare + articole Mat/Man/Utilaj/Transport
- `deviz_tehnic_pdf_service.dart` → Export PDF

### Serii numerotare per tip document:
- `devizTehnic` → **DVZ-YYYY-NNNN**
- `ofertaLucrari` → **OFR-YYYY-NNNN**
- `situatieLucrari` → **STL-YYYY-NNNN**
- La schimbare tip (document NOU), numărul se regenerează automat
- `nextNumber(DevizTehnicTipDocument tip)` — apelat cu tipul corect

### Culori card după status:
- Card: `border = statusColor.withValues(alpha: 0.5)`, `background = statusColor.withValues(alpha: 0.06)`
- Badge status: border + background colorat (nu doar text)
- Butoane rapide schimbare status: OutlinedButton cu culoarea fiecărui status

### Setare tip document implicit (cross-device):
- `saveDefaultTipDocument(tip)` → SharedPreferences (local) + Firestore `app_settings/deviz_tehnic_settings`
- `loadDefaultTipDocument()` → Firestore (prioritate, cross-device) > SharedPreferences > devizTehnic
- La document nou: `_loadDefaultTipThenNumber()` → setează tip default + generează numărul aferent
- Buton "Setează ca implicit" lângă selector tip document în form page
- **Backward compatible**: versiunile vechi primesc `devizTehnic` ca default dacă câmpul lipsește

### Sync offline:
- `CloudEntityType.devizeTehnice` + Firestore collection `devize_tehnice`
- Pattern standard: local → queue upsert → Firebase direct (best-effort)
- `list()` returnează `[...cloud, ...localOnly]` — nu pierde datele create offline
- NU folosiți `.orderBy()` în Firestore — sortare în Dart

---

## 🌬️ MODUL DEVIZE FILTRE CTA

### Fișiere principale:
- `deviz_filtre_cta_models.dart` → ZonaCta, CtaFiltru, CtaEntry, DevizFiltreCta, ctaTemplateImplicit()
- `deviz_filtre_cta_repository.dart` → CRUD + nextNumber (CTA-YYYY-NNNN) + offline queue
- `deviz_filtre_cta_page.dart` → Listă devize cu search + card actions
- `deviz_filtre_cta_editor_page.dart` → Editor complet (header + CTA table + totaluri)
- `deviz_filtre_cta_pdf_service.dart` → Export PDF A4 landscape (FiltreCtaPdfService)

### Navigare:
- `oferte_devize_modul_page.dart` → Tab 2 "Filtre CTA" (alături de Oferte + Devize tehnice)

### Template implicit (ctaTemplateImplicit()):
- 15 CTA-uri cu prețuri din Excel 2026-Oferta_Pro_Term-Shimbat_filtre_CTA-uri.xlsx
- Zone: Turnătorii (6334.26 EUR), Spumătorie (749 EUR), Cusătorii (1972 EUR), Logistică (280 EUR)
- Total general template: **9335.26 EUR**

### Numerotare:
- Serie: `CTA-YYYY-NNNN` (ex: CTA-2026-0001)
- `nextNumber()` — verifică local + Firestore, returnează următorul disponibil

### Funcționalități editor:
- Prețuri editabile per filtru (tap → dialog)
- Adaugă CTA din template sau blank (bottom sheet cu toate cele 15)
- Duplică / Șterge cu confirmare / Reordonare cu săgeți ↑↓
- "Actualizează prețuri din template" (meniu ⋮) — resetează prețurile la valorile Excel
- Totaluri pe zone + Total General în bara de jos sticky

### Sync offline:
- `CloudEntityType.devizeFiltreCta` + Firestore collection `devize_filtre_cta`
- Pattern standard: local → queue upsert → Firebase direct (best-effort)
- `list()` returnează `[...cloud, ...localOnly]`

### CompanyProfile câmpuri pentru PDF:
- `companyName` (NU `name`)
- `tradeRegister` (NU `regCom`)
- `address`, `cui` (corecte)

---

---

## ✍️ SEMNĂTURĂ ELECTRONICĂ PV/PIF

### Fișiere principale:
- `lib/core/widgets/signature_pad_widget.dart` → Canvas cu degetul/mouse-ul, exportă PNG via RepaintBoundary
- `lib/core/signature_service.dart` → Salvare locală (SharedPreferences base64) + upload Firebase Storage best-effort
- `lib/features/jobs/job_site_document_pdf_service.dart` → Export PDF complet cu bloc semnătură
- `lib/features/jobs/job_site_documents_page.dart` → Butoane "Semnează & Generează PDF" + "Generează PDF"

### Flux semnătură:
1. `showSignatureDialog()` → afișează pad canvas în dialog
2. `SignatureService.saveSignature()` → local base64 + upload Storage background
3. `_saveDocument(signed)` → salvează `clientSignatureBase64` în document
4. `JobSiteDocumentPdfService.export()` → generează PDF cu semnătura embedded

### Storage path: `signatures/{jobId}/{documentType}_{timestamp}.png`
### Cache local: `SharedPreferences` key `signature_b64_pv_{documentId}`
### NU se creează colecții noi Firestore — câmp `clientSignatureBase64` existent în `JobSiteDocumentRecord`

---

## 👤 FIȘA COMPLETĂ CLIENT

### Fișiere principale:
- `lib/features/clients/client_profile_page.dart` → Pagină 4 tab-uri (Rezumat, Istoric, Financiar, Echipamente)
- `lib/features/clients/clients_page.dart` → tap → ClientProfilePage; butoane telefon + WhatsApp în card

### Tab-uri:
- **Rezumat**: Avatar, info contact, 4 stat cards, ultima activitate, note editabile cu auto-save
- **Istoric**: Timeline cronologică (programări + lucrări + oferte) cu filtre chip
- **Financiar**: Total intervenții + oferte, grafic 6 luni CustomPainter
- **Echipamente**: Lista echipamente unice din `equipmentDescription` al programărilor

### Navigare:
- `onTap` pe card client → `ClientProfilePage` (push MaterialPageRoute)
- `onClientUpdated` callback actualizează lista din `clients_page.dart`

---

## 🔔 ALERTĂ GARANȚII EXPIRATE

### Fișiere principale:
- `lib/features/clients/warranty_alert_service.dart` → Singleton, citește `LocalProductCatalogStore.listWarrantyCertificates()`
- `lib/features/dashboard/dashboard_page.dart` → Afișează `_buildWarrantyAlertsCard()` în `_buildAdminSections()`

### Severități:
- **expired** (roșu): `warrantyEndDate` < azi
- **urgent** (portocaliu): expiră în ≤7 zile
- **warning** (galben): expiră în ≤30 zile

### Câmpuri folosite din `WarrantyCertificateRecord`:
- `buyerClientId` / `buyerName` pentru identificare client
- `brand` + `model` pentru descriere echipament
- `warrantyEndDate` pentru calcul expirare

---

## 🔄 KIT PROPAGATION — PROGRAMĂRI

### Fișiere principale:
- `lib/features/programari/kit_propagation_service.dart` → singleton `KitPropagationService.instance`
- `lib/features/programari/programare_kituri_page.dart` → integrare propagare după `upsertTemplate`

### Cum funcționează:
1. Utilizatorul modifică un kit în `ProgramareKituriPage`
2. ÎNAINTE de salvare: `countAffectedAppointments(kit.id)` verifică câte programări sunt afectate
3. Dacă există programări afectate: dialog confirmare cu opțiuni "Doar salvează rețeta" / "Salvează și actualizează toate"
4. Dacă utilizatorul confirmă: `propagateKitChanges(saved, repository)` rulează în fundal (fire-and-forget)
5. Snackbar verde cu numărul de programări actualizate

### Comportament propagare:
- Citește TOATE programările din SharedPreferences (`ultra_appointments_v1`) — fără query Firebase
- Filtrează după `materialUsage.kitTemplateId == updatedKit.id`
- Reconstruiește liniile din `AppointmentMaterialKitComponent.resolvedQuantity(linearMetersUsed)`
- **`linearMetersUsed` se PĂSTREAZĂ din programare** — se recalculează doar cantitățile
- Actualizează și `kitTemplateName` la noul nume al kitului
- Salvare prin `repository.saveAppointment()` — pattern standard: local → queue → Firebase fire-and-forget

### La ștergerea unui kit:
- **NU se propagă** — programările existente păstrează datele istorice (`lines` rămân neschimbate)
- Textul din dialog de ștergere: "Programarile deja salvate isi pastreaza consumul inregistrat."

### Repository dependency:
- `ProgramareKituriPage` primește `AppDataRepository? repository` (optional)
- `role_ready_shell.dart` pasează `widget.appDataRepository`
- Dacă `repository == null` (ex: folosit direct fără shell): propagarea nu rulează, kitul se salvează normal

---

## 🗂️ MODUL RECLAMAȚII — EXTINDERE (iun 2026)

### Câmpuri noi în ComplaintRecord (backward compatible):
- `tipSursa` — `'client_direct'` | `'colaborator'` | `'garantie_producator'` (default: `'client_direct'`)
- `colaboratorId`, `colaboratorNume`, `colaboratorContact`, `colaboratorTelefon`, `colaboratorRefNumber`
- `clientFinalId`, `clientFinalNume` — beneficiarul real când sursa e un colaborator

### Formular reclamație nouă (`_NewComplaintDialog`):
- `SegmentedButton` sursă: Client direct / Via colaborator / Garanție producător
- Câmpuri colaborator (vizibile dacă tipSursa ≠ 'client_direct'):
  - `PartnerAutocompleteField` pentru societatea colaboratoare
  - Câmp nr. referință/dosar colaborator
  - Câmp persoană contact colaborator
  - `ClientAutocompleteField` pentru clientul final (beneficiarul real)
- Partners se încarcă in background în `initState()` via `widget.repository.listPartners()`

### Tab Ofertă rapidă (`ComplaintQuickOfferTab`):
- **Fișier**: `lib/features/reclamatii/complaint_quick_offer_tab.dart`
- Tab 5 în `ComplaintDetailPage` (TabController length = 5)
- Secțiunea "Ofertă colaborator" apare NUMAI dacă `isAdmin == true` ȘI `tipSursa != 'client_direct'` ȘI `colaboratorNume.isNotEmpty`
- `isAdmin` = `AppRolePolicy.canAccessOffice(_role)` (admin + birou)
- Catalog produse: `MaterialsCatalogService().listMaterials()` → `MasterMaterial`
- Salvare draft: `SharedPreferences` key `complaint_offer_client_{id}` / `complaint_offer_colaborator_{id}` / `complaint_offer_meta_{id}`
- PDF: `ComplaintQuickOfferPdfService.export()` → fișier temporar → `PdfActionsHelper`
- WhatsApp colaborator: `url_launcher` → `wa.me/{telefon}?text={mesaj pre-completat}`

### Clase noi în `complaint_models.dart`:
- `ComplaintOfferLine` — linie ofertă (denumire, um, cantitate, pretUnitar, categorie, total calculat)
- `ComplaintQuickOffer` — ofertă completă cu lista de linii, TVA, notă, destinatar

### PDF ofertă rapidă:
- `lib/features/reclamatii/complaint_quick_offer_pdf_service.dart`
- A4 portrait, margini 24pt, font Arial cu diacritice
- Header PRO TERM + date reclamație + destinatar + tabel linii + total
- Banner "DOCUMENT INTERN" pe oferta colaborator

---

## 🗂️ MODUL RECLAMAȚII — REDESIGN (mai 2026)

### Structură nouă (înlocuiește ReclamatiiPage ca entry point):
- `reclamatii_list_page.dart` → **ReclamatiiListPage** — lista carduri (entry point în navigație)
- `complaint_detail_page.dart` → **ComplaintDetailPage** — detaliu cu 4 tab-uri (Sumar / Intervenții / PV-uri / Documente)
- `complaint_intervention_editor_page.dart` → **ComplaintInterventionEditorPage** — editor intrare intervenție
- `reclamatii_page.dart` → **ReclamatiiPage** — păstrat pentru editare completă reclamație

### Navigație:
- `role_ready_shell.dart` → destinația `reclamatii` folosește `ReclamatiiListPage`
- Deep-link `initialFocusComplaintId` funcționează în `ReclamatiiListPage`
- Tap pe card → `ComplaintDetailPage`
- Tab Intervenții → `ComplaintInterventionEditorPage`
- Tab PV-uri → `RepairReportEditorPage` cu suport înlănțuire

### Înlănțuire PV-uri (câmpuri noi în RepairReportRecord):
- `interventionNumber` — numărul intervenției
- `previousReportId` / `previousReportNumber` — referință PV anterior
- `previousInterventionSummary` — rezumat constatare anterioară
- `isFollowUp` — true dacă e revenire
- PDF afișează secțiune "INTERVENȚIA NR. X — REVENIRE" dacă `isFollowUp = true`

### Câmpuri noi în ComplaintRecord (backward compatible):
- `pvCount`, `lastInterventionDate`, `lastPvNumber`, `totalInterventions`

### Câmpuri noi în RepairReportRecord (backward compatible):
- `interventionNumber`, `previousReportId`, `previousReportNumber`, `previousInterventionSummary`, `isFollowUp`
- `photoUrls`, `photoBase64List`, `photoCategories`, `photoCaptions` — poze anexă PV

### Câmpuri noi în WarrantyInterventionReportRecord (backward compatible):
- `photoUrls`, `photoBase64List`, `photoCategories`, `photoCaptions` — poze anexă PV garanție

### Anexă fotografii în PDF PV:
- `repair_report_editor_page.dart` → secțiune "Poze anexă PV" (grid 3 col, max 20 poze, caption per poză)
- `repair_report_pdf_service.dart` → `_buildPhotoAnnexPages()` — 2 poze/pagină A4, header roșu PRO TERM, footer referință
- `warranty_intervention_report_pdf_service.dart` → same pattern
- Strategie: base64 local (offline) > URL Firebase Storage (fallback); dacă offline = PDF fără anexă, fără eroare

## 📞 TELEFOANE MULTIPLE + EDITARE DATE CLIENT (mai 2026)

### Model ClientRecord:
- `phoneNumbers = const <String>[]` — lista consolidată de telefoane
- Migrare automată în `fromMap()`: `phone_numbers` list > `phone`/`phone2`/`phone3`
- `allPhoneNumbers` getter: returnează phoneNumbers dacă nevidă, altfel din phone/phone2/phone3
- `toMap()` include `phone_numbers` + păstrează phone/phone2/phone3 pentru backward compat

### Model Appointment:
- `clientPhoneNumbers = const <String>[]` — lista telefoane client la programare
- Migrare din `contactPhone` în `fromMap()`
- Salvat în `client_phone_numbers`

### Programări — Card editabil "Date client":
- `_showClientDataEditDialog()` în `programari_page.dart` — editabil pentru TOȚI rolurile
- Câmpuri editabile: beneficiar, locație, numere telefon (max 5)
- Salvare: optimistic UI + `saveAppointment().catchError()`
- Buton "Editează" în secțiunea "Contact si locatie" a dialogului detalii programare
- Afișare multiple telefoane cu butoane apel direct `tel:` în detalii programare

### Clienți — Formularul:
- `add_client_quick_dialog.dart`: list dinamică `_phoneControllers` (max 5 telefoane, adaugă/șterge)
- `clients_page.dart`: salvează `phoneNumbers`, caută în phoneNumbers

## 📊 MODUL CRM — PIPELINE VÂNZĂRI (mai 2026)

### Fișiere principale:
- `lib/features/crm/crm_models.dart` → CrmRecord, CrmStadiu, CrmInteractiune, CrmStats
- `lib/features/crm/crm_repository.dart` → CRUD + offline queue singleton (CrmRepository.instance)
- `lib/features/crm/crm_page.dart` → Pagină principală cu 3 tab-uri (Pipeline Kanban / Listă / Statistici)

### Model CrmRecord — câmpuri:
```dart
CrmRecord {
  id, titlu, clientId, clientName, contactPerson,
  phoneNumbers (List<String>), email,
  stadiu (CrmStadiu), tipLucrare,
  valoareEstimata (double), valoareFinala (double?),
  sursa ('Direct'|'Referinta'|'Google'|'Facebook'|'Instagram'|'Alt'),
  ofertaId, jobId,
  dataContact, dataUrmatoareActiune (DateTime?), urmatoareActiune,
  interactiuni (List<CrmInteractiune>), note, assignedTo,
  createdAt, updatedAt
}
```

### Stadii CrmStadiu (în ordine pipeline):
- `lead` — Lead nou (albastru)
- `calificat` — Calificat (violet)
- `ofertaTrimisa` — Oferta trimisa (portocaliu)
- `negociere` — Negociere (galben)
- `castigat` — Castigat (verde)
- `pierdut` — Pierdut (roșu)
- `inactiv` — Inactiv (gri)

### Colecție Firestore: `crm_records`
### SharedPreferences key: `'crm_records_v1'`
### Sync offline: `CloudEntityType.crmRecords` → `queueCrmRecordUpsert/Delete`

### Repository — metode principale:
- `upsertCrmRecord(r)` → local → queue → Firestore fire-and-forget
- `deleteCrmRecord(id)` → local → queue delete → Firestore fire-and-forget
- `listMerged()` → merge cloud+local (BUG7 pattern)
- `listNecesitaActiune()` → leaduri cu dataUrmatoareActiune ≤ azi și esteActiv=true
- `addInteractiune(recordId, interactiune)` → adaugă interacțiune la un lead
- `getStats()` → CrmStats cu rate conversie, valori pipeline etc.
- `createNew(...)` → factory cu id UUID + timestamps

### Integrare cu Oferte (auto-CRM):
- `oferta_detaliu_page.dart` → `_changeOfferStatus()` → `_syncCrmForOfferStatus()` (fire-and-forget)
- Status `sent` → CrmRecord cu stadiu=`ofertaTrimisa`
- Status `accepted` → CrmRecord stadiu=`castigat` + `valoareFinala=offer.totalValue`
- Status `rejected` → CrmRecord stadiu=`pierdut`
- Leagă CrmRecord prin câmpul `ofertaId`

### Alertă startup (role_ready_shell.dart):
- `_loadSectionBadgesInternal()` → `CrmRepository.instance.listNecesitaActiune()`
- Dacă count > 0: badge secțiunea 'comercial' + SnackBar '📋 X lead-uri necesita actiune'
- Alertă apare o singură dată per sesiune (`_crmAlertShownThisSession` flag static)
- Buton 'Deschide CRM' navighează direct la modul

### Dialog adăugare/editare lead — câmpuri:
- Titlu (obligatoriu), Client cu autocomplete (obligatoriu)
- Persoana contact, Telefon, Email
- Stadiu (dropdown), Sursă (dropdown)
- Tip lucrare, Valoare estimată RON
- Data acțiunii (date picker cu buton clear), Acțiune de urmat
- Note

### Navigație:
- Destinație `crm` în secțiunea `comercial` din `role_ready_shell.dart`
- Vizibil: admin + birou
- `CrmPage(repository: widget.appDataRepository)` — repository necesar pentru autocomplete clienți

### Tab Pipeline (Kanban):
- Coloane pentru toate stadiile (excl. pierdut/inactiv)
- Card compact cu titlu, client, valoare, data acțiunii (roșu dacă depășit)
- Buton "Lead nou" în fiecare coloană cu stadiu pre-setat
- Scroll orizontal coloane + scroll vertical per coloană

### Tab Listă:
- Search text + filtre Stadiu + Sursă
- Card cu chip stadiu colorat, butoane WhatsApp / Sună / Editează / Mută stadiu
- RefreshIndicator

### Tab Statistici:
- KPI cards: Total, Câștigate, Pierdute, Rată conversie, Pipeline, Total câștigat
- Bar chart distribuție per stadiu
- Top surse lead-uri

---

## 🔴 PROBLEME CUNOSCUTE

- reclamatii: repair_reports și warranty_reports fără offline queue (de implementat)
- field_sales: fără queue propriu (de implementat)

---

## 📡 LISTENER REAL-TIME FIRESTORE — SYNC CROSS-DEVICE (iun 2026)

### Unde e implementat:
- `programari_page.dart` → `_maybeStartRealtimeListener()` + `_appointmentsRealtimeSubscription`

**Pattern complet în `programari_page.dart` → `_maybeStartRealtimeListener()`**. Variabile necesare: `_realtimeSub`, `_realtimeDebounce`, `_isOnlineCached`. Pornit în `initState` via `Future.microtask`, oprit în `dispose()`.

### Reguli critice:
- **NU înlocui `_load()` cu parse direct din snapshot** — logica de merge (BUG 7, tombstones, offline queue) e în repository, nu în listener
- **Debounce 3 secunde** — evită multiple `_load()` pentru save-uri batch
- **Listener pornit NUMAI când online** — se oprește automat când merge offline
- **Cancelat în `dispose()`** — OBLIGATORIU, fără excepții
- **`.where()` fără `.orderBy()`** — evită index compus Firestore → sortare în Dart
- **Iconița status în AppBar**: `cloud_done_outlined` (verde) = listener activ, `cloud_off_outlined` (portocaliu) = offline

## 📋 MODUL AGFR/F-GAS — DATE STATICE ȘI AUTOMATIZĂRI

### Fișier: `lib/features/agfr/agfr_refrigerant_data.dart`
- `AgfrRefrigerantData.specs` — hartă statică cu 25+ agenți frigorifici (GWP, tip, culoare cilindru, note)
- `AgfrRefrigerantData.gwpFor(name)` — GWP conform Reg. UE 517/2014
- `AgfrRefrigerantData.calculeazaToneCO2(kg, refrigerant)` — tone CO₂ echivalent
- `AgfrRefrigerantData.intervalVerificareScurgeri(toneCO2)` — interval scurgeri conform UE

### Automatizări în `agfr_page.dart`:
- **Formular echipament**: la selecție tip refrigerant → GWP se completează automat (readonly dacă e din baza de date)
- **Banner avertizare**: apare automat la refrigeranți A2L/A3/interzis (R32, R290, R22 etc.)
- **CO₂ echivalent**: calculat live în ambele formulare (echipament + intervenție)
- **Interval verificare scurgeri**: afișat automat sub 5t/50t/500t CO₂e
- **Tehnician**: auto-completat din `FirebaseAuth.instance.currentUser?.displayName`

### Reguli:
- NU modifica valorile GWP — sunt constante legale europene
- La adăugarea unui tip nou de refrigerant → adaugă în `AgfrRefrigerantData.specs`
- GWP readonly când există în baza de date; editabil manual pentru tipuri personalizate

## 🔄 FLUX OFERTĂ → LUCRARE (iun 2026)

### Câmpuri noi în OfferRecord (backward compatible):
- `tipOferta` — `'oferta_lucrari'` | `'deviz_tehnic'` | `'mini_oferta'` | `'deviz_filtre'`
- `sursa` — `'direct'` | `'reclamatie'` | `'programare'` | `'agfr'`
- `sursaId`, `sursaNumar` — referință la documentul sursă
- `tipOfertaLabel` getter — label UI pentru badge

### Câmpuri noi în JobRecord (backward compatible):
- `liniiPlanificate: List<JobLine>` — linii copiate din ofertă la conversie
- `totalOferta: double` — totalul ofertei fără TVA (planificat)
- `totalReal` getter — suma realizată actuală din linii
- `diferenta` getter — `totalReal - totalOferta`

### Clasa JobLine (job_models.dart):
- `id`, `ofertaLineId`, `denumire`, `um`, `cantitateOferta`, `cantitateReala`, `pretUnitarOferta`, `pretUnitarReal`, `categorie`
- Getteri: `totalOferta`, `totalReal`, `diferenta`
- `JobLine.fromOfertaLine()` factory static
- `copyWith()` pentru editare cantitateReala/pretUnitarReal

### Conversie ofertă → lucrare (`_convertOfferToJob()` în oferte_page.dart):
- Se populează `liniiPlanificate` din `offer.lines` (excluzând linii tip text)
- Se setează `totalOferta` = totalul ofertei
- Implementare existentă (`convertedToJobId`, `sourceOfferId`) rămâne neschimbată

### Filtre și badges în OfertePage:
- Dropdown filtru `Tip document` (deasupra filtrului status)
- Badge colorat în card pentru `tipOferta ≠ 'oferta_lucrari'`
- Reset filtre include `_tipOfertaFilter`

### Tab Situație în LucrareDetaliiPage:
- Tab 5 (TabController length 4→5), isScrollable: true
- Afișează: header comparativ (ofertă vs realizat vs diferență)
- Lista articole cu detalii cantitate/preț ofertă vs realizat
- Dacă `liniiPlanificate.isEmpty`: mesaj informativ

### Mini ofertă reclamație → OfertaRecord:
- `ComplaintQuickOfferTab._saveDraft()` creează OfferRecord cu `tipOferta='mini_oferta'`, `sursa='reclamatie'`
- Salvează în `LocalOferteRepository` (apare în modulul Oferte)
- `_existingOfertaId` / `_existingOfertaNumar` — evită duplicate la re-save

---

## 📊 FLUX COMPLET: Lead → Ofertă → Lucrare → Factură (iun 2026)

### DevizLucrarePdfService (`lib/features/jobs/deviz_lucrare_pdf_service.dart`):
- `generateDevizPlanificat(job, branding)` — PDF A4 portrait: articole grupate pe categorie (MATERIALE/MANOPERĂ/TRANSPORT/ALTELE), total per categorie, note+condiții, semnături
- `generateSituatieLucrari(job, branding)` — PDF A4: tabel comparativ planificat vs realizat, diferențe colorate (verde=economie, portocaliu=depășire), sumar %
- Integrate în tab Situație din `lucrare_detalii_page.dart` → butoane "Deviz planificat" + "Situație reală"

### offer_pdf_service.dart — titlu adaptat după `tipOferta`:
- `mini_oferta` → 'OFERTĂ RAPIDĂ'
- `deviz_tehnic` → 'DEVIZ TEHNIC'
- `deviz_filtre` → 'DEVIZ FILTRE CTA'
- `sursa == 'reclamatie'` → metadata 'Ref. reclamatie: [sursaNumar]'

### SmartBillService extins (singleton `instance`):
- `genereazaFacturadinLucrare({settings, clientName, jobCode, linii})` — factură din linii REALE (cantitateReala × pretUnitarReal), NU planificate
- `genereazaProformadinOferta({settings, clientName, ofertaNumar, linii})` — tip 'proformaInvoice'
- `existaFacturaForJob(settings, jobCode)` — verifică duplicate
- Buton "Emite factură SmartBill" în tab Economic (vizibil dacă `status == finalizata` și `smartbillFacturaNumar.isEmpty`)

### JobRecord câmpuri noi SmartBill (backward compatible):
- `smartbillFacturaNumar` — nr. facturii emise
- `smartbillFacturaSerie` — seria facturii emise

### PipelineDashboardPage (`lib/features/dashboard/pipeline_dashboard_page.dart`):
- Funnel vizual: Lead → Oferte trimise → Lucrări active → Facturate
- 4 KPI cards: Oferte trimise, Rată conversie, Valoare lucrări, De facturat
- Oferte expirate (> 30 zile fără răspuns)
- Lucrări care necesită acțiune (finalizate neracturate, vechi)
- Timeline activitate recentă (luna curentă)
- Navigație: FINANCIAR → Pipeline Vânzări (admin+birou)

### StatusChangeNotifier (`lib/core/integrations/status_change_notifier.dart`):
- `onOfertaStatusChanged(oferta)` — notificări la acceptat/respins
- `onJobStatusChanged(job)` — notificare la finalizată neracturată
- `checkOfertaExpirate()` — apelat la startup (main.dart)
- Folosește `NotificationRuntimeService.instance.showLocalNotification()`

### LocalOferteRepository.listExpirate():
- Returnează oferte cu `status == sent`, `updatedAt < cutoff`, `!isConverted`
- Parametru `dupaZile` (default usage: 30)

### Ștergere ofertă cu protecție (oferte_page.dart):
- Blochează dacă `offer.isConverted` — afișează SnackBar roșu cu jobCode
- Dialog confirmare cu "Șterge definitiv" roșu
- Optimistic UI: scoate din listă imediat, rollback la eroare

---

## 📝 FORMAT RAPOARTE

La finalul oricărui raport sau rezumat:
```rezumat
[conținutul raportului]
```
