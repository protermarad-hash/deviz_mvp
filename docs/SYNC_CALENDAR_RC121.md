# ProVentaris Legacy RC 121 — protecția calendarului (programări) la concurență

Branch `fix/rc121-calendar-sync`, pornit din RC 120 (`f66c245`). Nepublicat, fără schimbări Firebase.

## 1. Cauza (verificată în codul RC 120)

Programările (`appointments`) nu erau incluse în protecția de revizii din RC 120. Defectele:

- **Salvare:**
  1. local;
  2. coadă;
  3. o scriere imediată `set(merge: true)` **oarbă**, fără timeout, „fire-and-forget”.
  Offline sau pe o conexiune care cade, SDK-ul Firestore păstrează scrierea și o trimite **mai târziu, necondiționat**, peste versiuni mai noi. Reluarea din coadă era tot oarbă.
- **Editare simultană:** câștigă ultima scriere, fără conflict. Se rescrie toată programarea (~80 de câmpuri), deci și câmpurile neatinse (financiar, materiale, echipă).
- **Ștergere:**
  - fără condiție: o ștergere învechită pierde editarea de pe alt dispozitiv;
  - markerul `deleted_appointments` se scria și după ștergeri care nu trebuiau aplicate.

## 2. Ce s-a schimbat (minim, pe infrastructura RC 120)

| Zonă | Schimbare |
|---|---|
| Modelul `Appointment` | `syncRev` (`_rev`) în `toMap`/`fromMap`/`copyWith`. Actualizările automate (kit, echipă, culoare) îl păstrează prin `copyWith`. Editorul îl transmite explicit. |
| `FirebaseProgramariRepository` | `upsert`/`delete` prin `RevisionWriter`, cu cheile scriitorului (`cloudMapFor`/`writerKeysFor`). Markerul `deleted_appointments` se scrie **doar după o ștergere acceptată**. Bazele se înregistrează din citirile de server: listă, ascultător și interogările din `LocalAppDataRepository`. |
| `LocalAppDataRepository` | Salvarea și ștergerea: local + coadă sub `runEntitySyncLocked`. Scrierea imediată oarbă e **eliminată**, înlocuită cu un push condiționat cu timeout, care nu blochează salvarea. Ștergerile sunt condiționate, inclusiv reîncercările. Îmbinarea rulează sub blocare: programările protejate (coadă sau conflict) își păstrează varianta locală, iar o ștergere în așteptare nu readuce copia din cloud. Verificarea anti-resurecție nu mai atinge programările protejate. |
| Ștergere respinsă | Varianta locală a unei ștergeri nu conține date, deci **varianta serverului este rezolvarea**: programarea redevine vizibilă și editabilă, baza vine din varianta serverului, iar conflictul trece în arhivă (`delete_rejected_server_kept`). |
| Generic (RC 120) | `KeyedMutex`: reentranța e legată de deținerea curentă, plus `detached()` pentru lucrul în fundal. Bucla de sincronizare sare elementele înlocuite între timp. Dacă lipsește baza dar editorul a pornit exact din revizia curentă a serverului, se scrie. Seturile locale de ștergeri și neconfirmate sunt sub blocare. Elementele epuizate de programări se păstrează ca conflict. Banda de conflict are eticheta „Programare”. |

Toate cele **7 puncte de salvare** trec prin `LocalAppDataRepository.saveAppointment`:

- `programari_page` ×2;
- `field_sales` ×2;
- `kit_propagation`;
- calendarul pe echipe;
- `teams_page`.

Cele **2 puncte de ștergere** trec prin `deleteAppointment`: `programari_page` și `lucrare_detalii`. Nu mai există nicio scriere directă în `appointments` în afara repository-ului.

## 3. Compatibilitate

- **Documente fără `_rev`** (scrise de 112/113/118/119/120): sunt tratate ca revizia 0. Prima scriere 121 de pe o bază citită produce `_rev = 1`.
- **Aplicații vechi (inclusiv telefoanele de calendar):**
  - scrierea oarbă a unei aplicații vechi **după** o bază 121 este detectată prin amprentă: rezultă conflict, nu suprascriere;
  - o scriere a unei aplicații vechi peste o versiune 121 **nu poate fi oprită din client**. Se închide doar cu regulile M3.
- **Elemente din coadă dinainte de actualizare:** se tratează conservator (conflict dacă serverul diferă). Actualizarea se face **cu coada goală** (verificat de kitul PC-2).

## 4. Regulile M3 pentru `appointments` (plan; NU se publică fără aprobare)

Fișierul propus: `tooling/rules_tests/rc120/firestore.rc120.proposed.rules`. Regula de bază rămâne `firestore.rules` (testul R1 verifică deriva). Se adaugă:

```
match /appointments/{docId} {
  allow read: if isOperational();
  allow create: if isOperational() && revOnCreate();   // _rev == 1
  allow update: if isOperational() && revOnUpdate();   // _rev == curent + 1 (lipsă = 0)
  allow delete: if isOperational();
}
```

Testat pe emulator: R2–R4 și R6 (concurență) pe `appointments`.

**Ordinea:**

1. Toate dispozitivele care scriu programări (PC-uri **și telefoanele de calendar**) ajung pe 121.
2. 7 zile fără scrieri fără revizie, verificat cu `legacy_writes_report.mjs --collections clients,offers,jobs,appointments` (doar citire, cu aprobare).
3. Export Firestore.
4. Publicarea regulilor.

**Efect asupra clienților vechi:** după M3, scrierile de programări ale aplicațiilor 112–120 sunt **respinse**. Telefoanele rămase pe versiuni vechi nu mai pot salva programări.

**Rollback M3:** se republică regulile anterioare (copie păstrată). 121 funcționează cu ambele seturi.

**Rămâne neacoperit și sub M3:** ștergerea nu poate fi condiționată de revizie în reguli. Fereastra Windows dintre citire și ștergere (de ordinul milisecundelor) rămâne. Tombstone-ul e decizie separată.

## 5. Rollback RC 121

- **Windows:** se revine la folderul 120 păstrat. Profilul rămâne.
- **Android:** nu există downgrade fără dezinstalare. Rollback-ul înseamnă oprirea distribuției și o corecție înainte.

Datele scrise de 121 (`_rev`, `_rev_writer`, `_rev_at`) sunt ignorate de versiunile vechi.

## 6. Riscuri rămase

- Aplicațiile vechi pot suprascrie până la M3.
- Windows: o scriere care expiră după citire poate ajunge mai târziu (comportamentul SDK). M3 o respinge.
- Conflictele de editare (`concurrent_edit`) nu au încă ecran de rezolvare. Programarea rămâne la varianta locală pe dispozitivul cu conflict, cu bandă roșie.
- Amprenta acoperă toată programarea, deci două ecrane care editează câmpuri diferite ale aceleiași programări simultan produc conflict. Este direcția sigură.

## 7. Teste

| Verificare | Rezultat |
|---|---|
| `flutter analyze` | PASS: 0 erori, 0 avertismente (16 `info` preexistente) |
| `flutter test` (578) | 577 PASS + 1 test de performanță PDF (pontaj, neatins de RC 121) depășit din cauza încărcării (10,5 s / prag 10 s); rulat izolat: PASS, 4,0 s |
| `test/appointment_revision_sync_test.dart` | 15/15 PASS: creare/editare, editare offline întârziată vs editare nouă, editare simultană, două salvări rapide / confirmare pierdută, timeout, repornire, ștergere vs editare, fără reapariție, document vechi fără `_rev`, actualizare automată pe copie veche, reguli M3 + fereastra Windows, `KeyedMutex` în fundal, bază lipsă |
| Reguli propuse pe emulator | 20/20 PASS, inclusiv `appointments` (R2–R4, R6 concurență) |
| Review independent (9 constatări) | 7 remediate (#1–#4, #6–#8), #5 și #9 documentate |
| Build Android (`assembleProtermDebug`) | PASS |
| Build Windows (binar de test, același cod `lib`) | PASS |
| **QA Windows real (A1–A3 calendar, S1/S7 regresie clienți)** | **BLOCKED**: protecția runner-ului refuză pornirea cât timp aplicația reală (pilotul, `C:\proventaris`) rulează pe PC-1 |
| Android pe dispozitiv / emulator | NOT TESTED: cere build semnat RC 121, după aprobare |

