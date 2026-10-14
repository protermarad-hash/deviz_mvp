# Android Backup: risc acceptat temporar și propunere de remediere

Stare: **decizie aprobată**, politica actuală se păstrează temporar (release 1.13.0+118). Acest document descrie riscul acceptat și remedierea propusă pentru o versiune ulterioară. Nimic de aici nu este implementat încă.

## Situația actuală

- `AndroidManifest.xml` nu setează `android:allowBackup`, `android:fullBackupContent` sau `android:dataExtractionRules`. Valorile implicite ale Android se aplică: backup automat în contul Google al utilizatorului (cloud) și transfer între dispozitive (device-to-device), ambele activate.
- Toate datele aplicației sunt în `shared_prefs/FlutterSharedPreferences.xml`, un singur fișier:
  - utilizatori locali (`field_auth_users_v1`, cu hash PBKDF2 după 1.13.0, sau format vechi reversibil până la primul login);
  - sesiunea locală (`field_auth_session_v1`) și marcajul de schimbare obligatorie a parolei;
  - coada offline (`cloud_sync_queue_v1`);
  - toate datele de lucru: lucrări, pontaje, angajați, echipe, plăți.
- Firestore ține propriul cache și scrierile în așteptare în `databases/firestore.*`.
- Firebase Auth ține utilizatorul cloud persistent în `shared_prefs/com.google.firebase.auth.api.Store.*`.

## Riscul acceptat

| Risc | Impact | Probabilitate |
|---|---|---|
| Sesiunea locală restaurată pe alt dispozitiv (transfer sau restore) | utilizatorul e autentificat pe noul dispozitiv fără parolă | medie: se întâmplă la orice restore |
| Conturi locale încă în formatul vechi (base64 reversibil) ajung în backup | parola e recuperabilă din backup | mică: doar conturile fără login după actualizare; backup-ul Google e criptat cu credențialele contului |
| Hash-urile PBKDF2 ajung în backup | atac offline pe hash (120 000 iterații) | mică |
| Datele de lucru ajung în backup-ul Google al angajatului | date de business în contul personal Google | depinde de politica firmei |

Beneficiul păstrat temporar: după restore, coada offline și datele nesincronizate se recuperează, deci operațiunile nu se pierd.

## De ce nu s-a remediat acum

Opțiunile simple nu sunt sigure:

1. **`allowBackup="false"`**: elimină riscul, dar și recuperarea datelor nesincronizate la schimbarea telefonului.
2. **Excluderea întregului `FlutterSharedPreferences.xml`**: același efect, plus pierderea utilizatorilor locali. După restore nu mai există administrator: build-urile release nu creează cont implicit, deci rezultatul e blocare.
3. **Ștergerea sesiunii la detectarea unui restore**, fără separarea fișierelor: sesiunea pare „restaurată” și la o actualizare normală. Utilizatorii cloud care lucrează offline ar fi deconectați și n-ar mai putea intra fără rețea.

## Propunere (versiune ulterioară)

Obiectiv: nicio sesiune nu se restaurează pe alt dispozitiv. Utilizatorii locali, coada offline și datele de lucru rămân recuperabile.

1. **Sesiune într-un fișier separat.** `field_auth_session_v1` și marcajul de schimbare a parolei se mută în `SharedPreferencesAsync` cu fișier propriu (`fileName: 'proventaris_auth_session'`; shared_preferences_android ≥ 2.4 permite fișier separat). Migrare o singură dată: citire din fișierul vechi, scriere în cel nou, apoi ștergere din cel vechi.
2. **Reguli de backup** (`res/xml/data_extraction_rules.xml` pentru API 31+, `res/xml/backup_rules.xml` pentru API ≤ 30), referite din manifest. Excluse din cloud-backup și din transfer: fișierul de sesiune, `com.google.firebase.auth.api.Store.*` (sesiunea cloud) și `databases/firestore.*` (cache-ul se reface din server). Incluse: `FlutterSharedPreferences.xml` (utilizatori locali, coadă, date).
   - Coada offline duplică scrierile Firestore în așteptare doar pentru tipurile din coadă: lucrări, echipe și altele, dar **nu** angajații. Înainte de a exclude `databases/firestore.*`, angajații trebuie adăugați în coadă, altfel o modificare de angajat nesincronizată s-ar pierde la restore.
3. **Fără ștergere „ghicită” a sesiunii.** Separarea fișierelor e suficientă: la restore, fișierul de sesiune nu există, deci utilizatorul trebuie să se autentifice. La o actualizare normală, fișierul există și nimic nu se schimbă.
4. **Teste:**
   - unitare: migrarea sesiunii (cu și fără sesiune veche) și idempotența ei;
   - pe dispozitiv, cu `adb shell bmgr backupnow` și `bmgr restore`: după restore, utilizatorii locali și coada există, sesiunea nu;
   - upgrade fără dezinstalare: sesiunea rămâne activă.

## Criterii de acceptare

- [ ] Restore pe dispozitiv nou: ecran de login. Login local cu parola existentă funcționează. Coada se sincronizează după login.
- [ ] Upgrade de la 1.13.0+118: fără deconectare, fără pierdere de date.
- [ ] Angajații modificați offline nu se pierd la restore (coadă pentru angajați).
- [ ] Niciun fișier cu sesiune (locală sau cloud) în backup-ul cloud sau în transfer.
