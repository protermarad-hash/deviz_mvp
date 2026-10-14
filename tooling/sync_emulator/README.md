# Teste de sincronizare pe Firebase Emulator Suite

Rulează fluxurile reale de sincronizare ale aplicației (coada offline, PUSH, PULL, merge, cache) pe un dispozitiv Android dedicat. Datele sunt sintetice și ajung **numai** în Firebase Emulator Suite local. Testele nu ating Firebase PROD.

## Izolare

Izolarea nu se bazează doar pe blocarea DNS. Fiecare strat de mai jos este verificat de script sau de test înainte de orice acces la Firestore. Dacă o verificare eșuează, rularea se oprește.

| Strat | Ce garantează | Verificat de |
|---|---|---|
| Emulator Android dedicat (ex. `Legacy_Sync_Emulator_API35`), niciodată 5592 | fără date reale și fără scrieri PROD în așteptare | script: refuză `emulator-5592` |
| Mod avion, fără rute, doar interfața `lo` | dispozitivul nu are nicio ieșire de rețea | script, înainte de fiecare fază: `airplane=1`, `ip route` gol, o singură interfață IPv4 |
| `-dns-server 127.0.0.1` + `/system/etc/hosts` | `firestore.googleapis.com` → `127.0.0.1`, pe care nu ascultă nimic pe 443; restul numelor nu se rezolvă | test: `google.com` și `identitytoolkit.googleapis.com` nu se rezolvă; TCP spre `8.8.8.8:53` și `142.250.180.10:443` eșuează |
| `adb reverse tcp:5310/5311` | singura cale spre exterior: un tunel adb către emulatoarele Firebase ale gazdei, legate la `127.0.0.1` | script: `adb reverse --list`; test: portul 5310 accesibil doar în fazele online |
| Proiect `demo-proventaris-sync` | proiectele `demo-*` există doar în emulator | test: refuză orice `projectId` care nu începe cu `demo-`; `singleProjectMode` |
| `useFirestoreEmulator` / `useAuthEmulator` înainte de codul aplicației | Firestore și Auth vorbesc doar cu `127.0.0.1` | test: `settings.host` trebuie să fie `127.0.0.1:5310` |

Proiectul demo se aplică fără modificări în codul aplicației. Testul inițializează aplicația Firebase implicită cu opțiunile reale, schimbând doar `projectId`. `FirebaseBootstrap.initializeSafe()` reutilizează apoi aplicația existentă: `firebase_core` compară doar `apiKey`, `databaseURL` și `storageBucket`.

`/system/etc/hosts` este necesar pentru că `FirebaseBootstrap.checkOnline()` decide „online” printr-o rezolvare DNS. Pe un dispozitiv izolat, fără intrarea din `hosts`, sincronizarea nu ar porni niciodată.

## Pregătirea emulatorului Android (o singură dată)

```
avdmanager create avd -n Legacy_Sync_Emulator_API35 -k "system-images;android-35;google_apis;x86_64" -d pixel_6
emulator -avd Legacy_Sync_Emulator_API35 -port 5596 -writable-system -no-snapshot -dns-server 127.0.0.1
adb -s emulator-5596 shell cmd connectivity airplane-mode enable
adb -s emulator-5596 root && adb -s emulator-5596 remount   # prima dată: reboot, apoi din nou root+remount
```

Înainte de a instala orice, verifică: `airplane_mode_on=1` și `ip route` gol.

## Rulare

Din rădăcina repository-ului, cu Java și Firebase CLI instalate:

```
DEVICE=emulator-5596 OUT=<director> bash tooling/sync_emulator/run_sync_scenarios.sh
```

Scriptul pornește emulatoarele (`firebase.sync-test.json`, regulile reale din `firestore.rules`), comută online/offline (tunel adb + intrarea din `hosts`) și rulează fazele. Fiecare fază pornește un proces nou, deci include un restart real. La final, scriptul oprește doar procesele care ascultă pe porturile acestui test.

Utilizatorul de test este creat pe dispozitiv, în emulatorul Auth, cu o parolă generată aleator. Parola nu apare în loguri. Profilul `users/{uid}` (admin, activ) este creat de gazdă cu drepturi de proprietar ale emulatorului, deci scrierile aplicației trec prin regulile reale.

## Faze

| Fază | Rețea | Verifică |
|---|---|---|
| INIT | online | utilizator sintetic în emulatorul Auth |
| PULL | online | angajați, echipe și lucrări (cu pontaj) aduse din cloud în datele locale |
| OFFLINE_EDIT | offline | lucrare nouă cu pontaj angajat și partener salvată de două ori (un singur element în coadă); editare locală a unei lucrări din cloud; angajat nou (scriere în așteptare); echipă nouă (coadă) |
| RESTART_OFFLINE | offline | după restart: coada, datele locale și scrierea în așteptare a angajatului persistă; cache-ul nu suprascrie editarea locală |
| SYNC | online | serverul are între timp o editare de pe „alt dispozitiv”; merge-ul păstrează editarea locală în așteptare; `syncPending` golește coada |
| PULL2 | online | modificările din cloud ajung local; răspunsul serverului e autoritativ (echipa ștearsă dispare); pontajul local este identic cu cel din cloud |
| RETRY | online | eșec real (scriere neautentificată respinsă de reguli) → retry cu backoff → succes; a doua sincronizare nu mai are nimic de făcut |
| KILL / AFTER_KILL | online | aplicația e oprită forțat în timpul sincronizării; după restart, nimic pierdut, fără duplicate în coadă |
| CACHE | offline | cache incomplet: angajații și echipele locale nu se pierd |

Gazda verifică datele din emulator după SYNC și la final, prin `fs.mjs verify-sync`.
