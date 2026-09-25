# ProVentaris Build & Release Policy

**Status:** Politică obligatorie, introdusă după incidentul de semnare din 1.13.0+113 (vezi §12).
**Se aplică:** oricărui build viitor destinat unui checkpoint canonic/RC/distribuție.

---

## A. PRINCIPII OBLIGATORII

Niciun build nu este considerat **canonic**, **release candidate** sau **distribuibil** doar pentru că
comanda de build a reușit (exit code 0). Un build valid trebuie să aibă verificate explicit, și
raportate, toate cele de mai jos:

1. Repository absolut (path complet, nu relativ)
2. Branch
3. HEAD (commit SHA exact)
4. `versionName`/`buildNumber` (citite din artefact, nu presupuse din `pubspec.yaml`)
5. Platformă (Windows / Android / alta)
6. Flavor (dacă platforma are flavors)
7. Package / `applicationId`
8. Signing identity (subiect certificat + fingerprint)
9. SHA-256 al artefactului final
10. Path absolut final (locație permanentă, nu worktree temporar)
11. Distribution status (§11)

Un raport de build care omite oricare din cele 11 puncte de mai sus este **incomplet** și nu poate
susține o decizie de distribuție.

---

## 2. REGULA PATH-URILOR

**INTERZIS** în orice raport de build path-uri relative de tipul:
```
build\app\...
build\windows\...
```
ca unic identificator al artefactului.

**OBLIGATORIU:** path absolut complet, de exemplu:
```
C:\Users\Lenovo\develop\releases\ProVentaris\1.13.0+113\android\app-proterm-release.apk
```

Dacă build-ul a fost efectuat într-un worktree temporar (practică standard în acest proiect pentru
a proteja fișierele locale sensibile de operații git riscante), raportul trebuie să marcheze explicit:

```
TEMPORARY BUILD PATH — DO NOT INSTALL FROM HERE
```

Artefactul trebuie copiat ulterior într-un director permanent (§4) înainte de a fi considerat
utilizabil pentru testare sau distribuție.

---

## 4. STRUCTURA PERMANENTĂ RELEASE

Standard obligatoriu:

```
C:\Users\Lenovo\develop\releases\ProVentaris\<version>\
  windows\
  android\
  BUILD_MANIFEST.txt
```

Exemplu concret (checkpoint curent):
```
C:\Users\Lenovo\develop\releases\ProVentaris\1.13.0+113\
```

`<version>` corespunde exact valorii din `pubspec.yaml` la momentul build-ului (`X.Y.Z+BUILD`).

---

## 5. WINDOWS POLICY

Comandă canonică:
```
flutter build windows --release
```

Validări obligatorii:
- branch/HEAD sursă confirmate înainte de build
- versiune confirmată (`pubspec.yaml`)
- `ProVentaris.exe` există în artefactul rezultat
- `data\app.so` există (codul Dart AOT compilat)
- **întregul folder `Release\` este păstrat** — nu doar `.exe`-ul
- SHA-256 calculat pentru `ProVentaris.exe`
- SHA-256 calculat pentru `data\app.so`
- zero markeri de debug/instrumentare temporară dacă artefactul e RC (verificabil prin scanare text în binar)
- path absolut permanent (§4), nu path temporar

**IMPORTANT:** Windows nu are un concept de "signing gate" echivalent cu Android în acest proiect
(nu există semnare de cod Authenticode configurată) — validarea de mai sus e singura barieră de
calitate pentru artefactul Windows.

---

## 6. ANDROID POLICY

Pentru clientul standard PRO TERM, comanda **trebuie** să fie explicit:
```
flutter build apk --release --flavor proterm
```

**INTERZIS:**
```
flutter build apk --release
```
fără `--flavor` explicit — proiectul are multiple product flavors (`proterm`, `costel`); fără
flavor explicit, Gradle încearcă implicit să construiască toate flavor-urile configurate, eșuând
pe configurația Costel (locală, privată, indisponibilă în medii curate).

Validări obligatorii, **extrase direct din conținutul binar al APK-ului** (nu presupuse din
`pubspec.yaml` sau din numele fișierului):

- `applicationId`/package (`aapt dump badging`)
- `versionName`
- `versionCode`
- flavor = `proterm` (dedus din `applicationId` = `ro.proterm.proventaris`, nu `ro.proterm.proventaris.costel`)
- signing certificate (§7)
- SHA-256 al APK-ului

---

## 7. SIGNING GATE — CRITIC

**"release build" ≠ "distributable build".**

Un APK compilat cu `flutter build apk --release` este semnat automat cu certificatul **debug**
(`CN=Android Debug`, auto-generat, efemer, specific mediului/mașinii de build) **dacă și numai dacă**
nu există o configurație de semnare de producție validă (`key.properties` + keystore real) prezentă
la momentul build-ului. `--release` descrie doar tipul de build (optimizări, fără debugging), **nu**
garantează semnarea cu o cheie de producție.

Dacă un APK este semnat cu:
```
CN=Android Debug
```
statusul obligatoriu al artefactului este:
```
TEST ONLY — NOT DISTRIBUTABLE
```

**Un astfel de APK NU poate fi folosit ca update peste o aplicație deja instalată cu certificatul
de producție** — Android refuză instalarea/upgrade-ul când semnăturile nu coincid, fără un mesaj
clar întotdeauna vizibil utilizatorului (vezi incidentul §12).

Un APK Android poate primi statusul:
```
DISTRIBUTABLE = YES
```
**NUMAI** dacă, toate simultan:
- este semnat cu certificatul de producție PRO TERM (subiect confirmat, nu presupus)
- fingerprint-ul (SHA-256 al certificatului) corespunde certificatului de producție cunoscut/documentat
- `package`/`applicationId` este cel corect (`ro.proterm.proventaris`)
- `versionCode` este strict mai mare decât versiunea deja instalată pe device-ul țintă

---

## 8. KEYSTORE POLICY

Keystore-ul de producție:
- **NU** se commite în git, niciodată, sub nicio formă
- **NU** se copiază în documentație (nici path-ul complet cu conținut, nici valorile)
- **NU** se loghează (nici parțial, nici mascat)
- parolele asociate **NU** se afișează, în niciun raport, log sau document
- `key.properties` (fișierul local care conține referința către keystore + parole) **NU** se
  commite dacă are conținut sensibil — rămâne exclusiv local, per mașină de build
- dacă semnarea de producție **nu este disponibilă** la momentul build-ului, artefactul rezultat
  **trebuie marcat explicit `TEST ONLY`** (§7) — build-ul nu trebuie să eșueze silențios spre o
  semnare debug fără avertisment

**Mecanismul existent în acest proiect** (fără expunere de valori):
- `android/app/build.gradle.kts` citește `key.properties` din rădăcina proiectului, dacă există,
  și configurează `signingConfigs.create("release")` din acel fișier; dacă `key.properties` nu
  există, `buildTypes.release.signingConfig` cade automat pe `signingConfigs.getByName("debug")`.
- `key.properties` este exclus explicit din git (`.gitignore`: `key.properties`, `android/key.properties`).
- `scripts/build_proterm.ps1` documentează în comentariile proprii pasul de generare a keystore-ului
  de producție (`keytool -genkey ...`) și presupune existența locală a `android/key.properties` cu
  valorile reale — scriptul însuși nu conține și nu expune nicio credențială.

Documentul de față **nu conține** și nu va conține niciodată path-uri, parole, alias-uri sau
conținut de certificat privat — doar mecanismul descris mai sus, la nivel structural.

---

## 9. BUILD MANIFEST

Format obligatoriu pentru `BUILD_MANIFEST.txt`, plasat la rădăcina fiecărui director de versiune
(`releases\ProVentaris\<version>\BUILD_MANIFEST.txt`):

```
Product: ProVentaris
Version: 1.13.0+113
Repository: C:\Users\Lenovo\develop\deviz_mvp
Branch: master
HEAD: 460d868
Build date: YYYY-MM-DD HH:MM

Windows:
Build type: release
Path: C:\Users\Lenovo\develop\releases\ProVentaris\1.13.0+113\windows\
SHA-256 ProVentaris.exe: <hash>
SHA-256 app.so: <hash>
Distribution status: DISTRIBUTABLE / TEST ONLY

Android:
Flavor: proterm
Package: ro.proterm.proventaris
VersionName: 1.13.0
VersionCode: 113
Signing subject: <CN extras din certificat>
Signing SHA-256 fingerprint: <hash certificat>
APK SHA-256: <hash>
Path: C:\Users\Lenovo\develop\releases\ProVentaris\1.13.0+113\android\app-proterm-release.apk
Distribution status: DISTRIBUTABLE / TEST ONLY

Published: NO
ForceUpdate: NO
AppConfig changed: NO
```

`BUILD_MANIFEST.txt` este creat/actualizat pentru fiecare versiune, la fiecare build canonic nou.
Nu conține niciodată parole, alias-uri de keystore, sau conținut de certificat dincolo de subiect
și fingerprint (ambele sunt metadate publice ale artefactului, extrase din APK-ul deja construit,
nu din keystore-ul privat).

---

## 10. RELEASE GATES

Un artefact **nu poate fi declarat CANONIC** până când toate porțile de mai jos sunt confirmate,
în ordine:

**SOURCE GATE**
- branch corect confirmat
- HEAD corect confirmat (SHA exact, verificat, nu presupus)
- working tree controlat (fără modificări necunoscute/nedocumentate)

**VERSION GATE**
- versiune confirmată **din metadata artefactului** (APK/exe), nu doar din `pubspec.yaml` sursă

**FLAVOR GATE**
- Android: `proterm` explicit, confirmat din `applicationId` extras din APK

**SIGNING GATE**
- pentru distribuție Android: certificat de producție confirmat (§7); orice altă semnătură →
  `TEST ONLY`

**HASH GATE**
- SHA-256 calculat **după** copierea în directorul permanent
- hash sursă (worktree temporar) == hash copie (locație permanentă) — verificat explicit, nu presupus

**SMOKE GATE**
- smoke test manual relevant efectuat și confirmat (nu doar "build-ul a reușit")

**PUBLISH GATE**
- publicarea/distribuția efectivă către utilizatori are loc **doar** după aprobare explicită,
  separată de aprobarea de build

---

## 11. DISTRIBUTION STATES

Stările de mai jos **nu sunt echivalente** și nu trebuie folosite interschimbabil în comunicare:

| Stare | Descriere |
|---|---|
| **BUILD GENERATED** | Comanda de build a reușit (exit code 0). Nimic altceva verificat. |
| **RC LOCAL** | Validările tehnice (analyze, test, metadata artefact) au trecut. Nepublicat, nedistribuit. |
| **TEST ONLY** | Semnare debug (sau altă condiție care împiedică un update real peste o instalare de producție existentă). Utilizabil doar pentru testare pe device fără aplicația de producție deja instalată, sau după dezinstalare manuală explicită. |
| **DISTRIBUTABLE** | Semnare de producție confirmată + metadata corectă + smoke test validat. Poate fi trimis unui utilizator/device pentru instalare/update real. |
| **PUBLISHED** | Artefactul a fost efectiv distribuit (canal oficial, store, sau transmis explicit utilizatorilor finali). |

---

## 12. INCIDENTUL 1.13.0+113

**Fapt confirmat, fără date sensibile:**

Un build Android canonic nou (`1.13.0+113`, `master @ 460d868`) a fost construit corect din sursă
(confirmat prin metadata extrasă direct din APK: `versionName=1.13.0`, `versionCode=113`). La
instalarea manuală pe un device de test care avea deja aplicația instalată cu o versiune anterioară
(`1.12.1+112`, semnată cu certificatul de producție PRO TERM), interfața a continuat să afișeze
versiunea veche (`v1.12.1+112`) după "instalare".

**Cauza reală:** APK-ul nou fusese semnat automat cu certificatul **debug** (nicio configurație de
semnare de producție disponibilă în mediul de build folosit), complet diferit de certificatul de
producție cu care era semnată aplicația deja instalată. Android a refuzat instalarea peste
aplicația existentă din cauza semnăturilor diferite; aplicația veche a rămas activă neschimbată,
iar UI-ul (care citește versiunea dinamic din sistemul de operare, nu dintr-o valoare hardcodată)
a raportat corect ce era de fapt instalat.

**Confirmare tehnică:** cauza **nu a fost** o problemă de versiune în cod sau în build — versiunea
din sursă și din APK erau corecte. Cauza a fost exclusiv un mismatch de semnătură (`signing gate`,
§7, nefiind verificat înainte de a considera artefactul "gata de instalat").

**Lecție:** verificarea explicită a semnăturii (§7, §10) este **obligatorie** înainte de a comunica
unui utilizator ce artefact să instaleze — un build "reușit" nu spune nimic despre distribuibilitate.

---

## 13. CI POLICY (baseline actual Legacy)

- Flutter pin explicit: `3.41.6` (`subosito/flutter-action@v2`, `flutter-version: '3.41.6'`)
- `flutter analyze --no-fatal-infos` — ERROR și WARNING rămân fatale pentru CI; INFO e raportat,
  dar nu blochează build-ul
- Android CI (smoke build, nu release):
  ```
  flutter build apk --debug --flavor proterm
  ```
- Costel **nu** este construit în CI standard — flavor-ul `costel` rămâne exclusiv build local,
  privat, prin `scripts/build_costel.ps1`
- Clean checkout CI **nu** necesită și nu are acces la nicio configurație locală Costel (stub
  versionat pentru `firebase_options_costel.dart`, gestionat prin `git update-index --skip-worktree`
  pe mașinile locale care construiesc Costel)

CI validează doar corectitudinea codului (analyze/test) și un build debug de fum pentru flavorul
standard — **CI nu produce artefacte de distribuție** (nu semnează cu certificat de producție, nu
rulează `--release`). Producerea unui artefact `DISTRIBUTABLE` rămâne un proces manual, separat,
guvernat de această politică.

---

## Referințe

- Lecțiile arhitecturale complete ale modulului invoice-import: `INVOICE_IMPORT_LEGACY_ARCHITECTURE_AND_LESSONS.md`
- Ghidul de implementare pentru ProVentaris Next: `PROVENTARIS_NEXT_INVOICE_IMPORT_GUIDELINES.md`
