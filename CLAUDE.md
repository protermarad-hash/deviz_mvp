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
Simptom: Modificările făcute offline dispar când app se redeschide cu internet.
Cauza: listXxx() rulează ÎNAINTE ca syncPending() să trimită modificările în Firestore.
  1. Utilizator modifică programare offline → local cache = v2, queue = {v2}
  2. App se redeschide cu internet
  3. listAppointments() → cloud returnează v1 (queue nu s-a sincronizat încă)
  4. Merge folosește v1 din cloud → local cache suprascris cu v1 → modificare pierdută!
  5. syncPending() eventual trimite v2 în Firestore, dar local a fost deja suprascris

Fix: preferă versiunea locală pentru items cu queue pending:
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
// ❌ GREȘIT — blochează UI:
try {
  await _col.doc(id).set(map, SetOptions(merge: true));
} catch (_) {}

// ✅ CORECT — fire-and-forget, UI răspunde imediat:
_col.doc(id).set(map, SetOptions(merge: true)).catchError((_) {});

// ✅ Același pattern pentru delete:
_col.doc(id).delete().catchError((_) {});
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
// ❌ GREȘIT — UI blocat vizual în așteptarea operației async:
await _repo.delete(item.id);
setState(() => _items.removeWhere((i) => i.id == item.id));
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Șters.')));

// ✅ CORECT — optimistic UI: actualizează lista ÎNAINTE, operația async în fundal:
// Asigură-te că ești mounted după orice await (ex: dialog)
if (!mounted) return;

// 1. Actualizare imediată — UI răspunde instantaneu
setState(() => _items.removeWhere((i) => i.id == item.id));
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Șters.')));

// 2. Operația efectivă în fundal — nu blochează UI
_repo.delete(item.id).catchError((e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Eroare la ștergere: \$e')),
    );
    _load(); // restaurează starea corectă la eroare
  }
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

### Caz explicit de evitat — Programări mai 2026:
- BUG real: preload-ul secundar salva clienții în masă prin `saveClient(...)`.
- Fiecare `saveClient(...)` declanșa `clientsChangeCount`.
- Listenerul din Programări făcea reload repetat.
- Rezultat: reload storm, multe `setState`, multe `build`, blocaj UI pe Windows și Android.
- Regula permanentă: UI-ul NU are voie să facă import/sync agresiv per item prin metode care notifică global la fiecare element.

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
```dart
// ── Sync forțat: publică toate documentele locale în Firestore ───────────
Future<int> forceSyncLocalToCloud() async {
  if (!_isCloudAvailable) return 0;
  final locals = await listLocal();
  if (locals.isEmpty) return 0;
  int synced = 0;
  for (final r in locals) {
    try {
      if (r.id.startsWith('local-') || r.id.isEmpty) {
        final map = r.toMap()..remove('id');
        final ref = await _col.add(map);
        final updated = MyRecord.fromMap({...r.toMap(), 'id': ref.id});
        await _updateLocalCache(updated);
        await OfflineSyncRuntime.instance.queueXxxUpsert(updated.toMap());
      } else {
        final map = r.toMap()..remove('id');
        await _col.doc(r.id).set(map, SetOptions(merge: true));
        await OfflineSyncRuntime.instance.queueXxxUpsert(r.toMap());
      }
      synced++;
    } catch (e) {
      debugPrint('[Modul] ❌ forceSyncLocalToCloud error for ${r.id}: $e');
    }
  }
  return synced;
}
```

### Template statics diagnostice — OBLIGATORIU în orice repository nou:
```dart
static String? lastFirestoreError;
static int lastFirestoreCount = -1;
static int lastLocalCount = 0;
// În list():
lastLocalCount = localItems.length;
lastFirestoreCount = -1; lastFirestoreError = null;
// ... on success:
lastFirestoreCount = cloudItems.length; lastFirestoreError = null;
// ... on catch:
lastFirestoreCount = -1; lastFirestoreError = e.toString();
```

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
```dart
// GREȘIT — dacă Firebase nu e ready la deschidere, lista rămâne goală pentru totdeauna:
void initState() {
  super.initState();
  _load(); // apelat direct, fără microtask
  // fără listener onlineNotifier → nu se reîncarcă niciodată automat
}

// CORECT — pagini cu liste care citesc din Firebase:
void initState() {
  super.initState();
  FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
  Future.microtask(_load); // nu blochează initState
}

void dispose() {
  FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
  super.dispose();
}

void _onOnlineChanged() {
  // Reîncarcă NUMAI dacă lista e goală (nu suprascrie date deja încărcate)
  if (FirebaseBootstrap.onlineNotifier.value && _items.isEmpty && !_loading) {
    _load();
  }
}
```

**De ce contează:** Firebase SDK are un DNS lookup de ~2s la startup (`isOnline=false`).
Dacă pagina se deschide în aceste 2 secunde, citește DOAR cache local (gol dacă e prima instalare
sau alt dispozitiv). Fără listener, datele rămân invizibile până la repornire sau refresh manual.
Același bug apare după upgrade de versiune: cache local gol + Firebase nu a terminat init = lista goală.

### ❌ ANTI-PATTERN 5 — Lista goală fără RefreshIndicator și fără debug info
```dart
// GREȘIT — utilizatorul nu poate reîncărca manual și nu vede ce se întâmplă:
child: items.isEmpty
    ? Center(child: Text('Nicio înregistrare.'))
    : ListView.builder(...)

// CORECT — lista goală cu RefreshIndicator + info debug + buton Reîncarcă:
child: items.isEmpty
    ? RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          Center(child: Column(children: [
            Text('Nicio înregistrare.'),
            // Info debug vizibil (ajutor la depanare cross-device):
            Card(child: Text('Firebase: init=${FirebaseBootstrap.isInitialized} '
                             'online=${FirebaseBootstrap.isOnline}')),
            FilledButton.icon(
              onPressed: _load,
              icon: Icon(Icons.refresh),
              label: Text('Reîncarcă din cloud'),
            ),
          ])),
        ]),
      )
    : RefreshIndicator(onRefresh: _load, child: ListView.builder(...))
```

**De ce contează:** Fără RefreshIndicator pe lista goală, utilizatorul nu poate forța
reîncărcarea. Fără info debug, nu știe dacă problema e de rețea sau de date.

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

### Cum verifici că sync-ul funcționează cross-device:
1. Dispozitiv A: creează/modifică o înregistrare
2. Verifică în Firebase Console că documentul există în colecția corectă
3. Verifică că câmpurile sunt exact cum le caută query-ul (ex: `source_entity_id`)
4. Dispozitiv B: deschide modulul, apasă Reîncarcă
5. Dacă B nu vede datele → bug în query sau în scriere

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

---

## ❓ REGULA BUTON HELP

În FIECARE modul/pagină nouă sau modificată:
```dart
HelpButton(content: AppHelp.<cheieModul>)
```
Conținut în `lib/core/help_content.dart` — română cu diacritice.

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
- Sold net = intrări - ieșiri (calculat automat în `_rebuildSummary`)
- Alertă locală dacă sold net < -1000 RON

### Collections Firestore:
- `partner_transactions` — toate tranzacțiile
- `partner_financial_summary` — sold net per partener

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

## ✅ CE ESTE IMPLEMENTAT

- Autentificare utilizatori + nume real din Firestore în AppBar
- Modul clienți (CRUD + Firebase)
- Modul angajați
- Modul field sales / devize pe teren + PDF
- Generare PDF devize (cu PdfFontHelper)
- Sync offline cu queue pentru toate modulele critice
- Email server settings + notificări programări (cu filtru câmpuri relevante)
- Catalog materiale + stoc
- HR: prezență, salarizare, fluturași, pontaje, concedii, deplasări
- AGFR: echipamente, intervenții, rapoarte, cântărire
- Vehicule + registratură
- Partner financial: tranzacții, sold net, dashboard, vânzare catalog, achiziție
- **Poze teren: upload Storage + sync Firestore + offline queue** (mai 2026)
- Baza proprie norme deviz
- **Devize tehnice: sync cross-device, serii DVZ/OFR/STL, culori status, tip implicit** (mai 2026)
- **Devize Filtre CTA: 15 CTA-uri template, editare prețuri, PDF A4 landscape, sync offline** (mai 2026)
- **Modul Taskuri: To-Do List cu filtre, priorități, categorii, widget Dashboard, sync offline** (mai 2026)

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

### Checklist repository implementat:
- ✅ `saveTask()` → local → queue upsert → Firebase fire-and-forget
- ✅ `deleteTask()` → local → queue delete → Firebase fire-and-forget
- ✅ `completeTask()` / `uncompleteTask()` → wrapper peste saveTask
- ✅ merge cloud+local cu preferință pentru modificările pending
- ✅ Statics diagnostice: `lastFirestoreError`, `lastFirestoreCount`, `lastLocalCount`
- ✅ `forceSyncLocalToCloud()` cu in-place replacement + deduplicare

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

## 🔴 PROBLEME CUNOSCUTE

- reclamatii: repair_reports și warranty_reports fără offline queue (de implementat)
- field_sales: fără queue propriu (de implementat)

## 🚀 CE VREAU SĂ IMPLEMENTEZ ÎN VIITOR

-

---

## 📝 FORMAT RAPOARTE

La finalul oricărui raport sau rezumat:
```rezumat
[conținutul raportului]
```
