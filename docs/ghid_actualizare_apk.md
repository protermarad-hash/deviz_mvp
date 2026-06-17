# Ghid — Publicare versiune nouă pentru auto-update in-app

Acest ghid e pentru TINE (fără agent), de fiecare dată când vrei să trimiți
o versiune nouă a aplicației către angajați, FĂRĂ Google Play Store.

Aplicația verifică automat la pornire documentul Firestore
`app_config/version_info`. Dacă găsește un `latestBuildNumber` mai mare
decât versiunea instalată pe telefon/PC, afișează un banner discret:
„Versiune nouă disponibilă (vX.Y.Z) — Actualizează acum", cu buton de
descărcare. Angajatul poate ignora banner-ul (X) și continuă
cu versiunea veche — nu e obligatoriu (deocamdată).

Sunt suportate două platforme simultan din același document Firestore:
- **Android** — descărcare APK + instalare directă
- **Windows** — descărcare installer .exe + instrucțiuni manuale

---

## Pas 0 — Incrementează versiunea (OBLIGATORIU, vezi CLAUDE.md)

În `pubspec.yaml`:
```yaml
version: 1.1.0+3
         ^^^^^  ^
         |      buildNumber — TREBUIE crescut cu minim 1 față de ce ai
         |      publicat ultima dată (altfel dispozitivele nu detectează update)
         versionName — vizibil pentru utilizator
```

---

## ══════════════════════════════════════════════
## ANDROID — Build și publicare APK
## ══════════════════════════════════════════════

## Pas 1A — Build APK release

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Fișierul generat: `build/app/outputs/flutter-apk/app-release.apk`

(Vezi și `docs/android_release_checklist.md` pentru semnare/keystore.)

---

## Pas 2A — Upload APK în Firebase Storage

1. Mergi la **Firebase Console** → https://console.firebase.google.com
2. Selectează proiectul aplicației (PRO TERM / ProVentaris)
3. Meniu lateral → **Storage**
4. Dacă nu există deja, creează un folder `app_releases/`
5. Click **Upload file** → selectează `app-release.apk` de la Pasul 1A
6. Recomandare: redenumește fișierul cu versiunea, ex:
   `app_releases/android/proterm-1.1.0+3.apk` (evită să rescrii peste
   fișierul vechi — păstrează istoricul versiunilor pentru rollback)
7. După upload, click pe fișier → panoul din dreapta → **Download URL**
   - URL-ul are forma:
     `https://firebasestorage.googleapis.com/v0/b/PROIECT.appspot.com/o/app_releases%2Fandroid%2Fproterm-1.1.0%2B3.apk?alt=media&token=XXXXXXXX`
   - **Conține token de acces** — funcționează direct cu GET simplu.

---

## ══════════════════════════════════════════════
## WINDOWS — Build și publicare installer
## ══════════════════════════════════════════════

## Pas 1W — Build Windows release

```bash
flutter clean
flutter pub get
flutter build windows --release
```

Fișierul generat: `build/windows/x64/runner/Release/` — conține
`deviz_mvp.exe` și folderele cu DLL-uri necesare.

**Opțiunea A — Copiezi folderul Release întreg pe PC-ul destinatar**
(cel mai simplu, fără installer):
- Arhivează tot folderul `Release/` ca ZIP:
  `proterm-1.1.0+3-windows.zip`
- Dezip pe PC-ul destinatar, lansezi `deviz_mvp.exe` direct

**Opțiunea B — Creezi un installer .exe cu Inno Setup (recomandat)**
(utilizatorul primește un singur fișier .exe care instalează totul):
1. Instalează [Inno Setup](https://jrsoftware.org/isinfo.php) (gratuit)
2. Creează un script `.iss` care împachetează `Release/` → un singur
   `proterm-setup-1.1.0+3.exe`
3. Rezultatul: un singur fișier executabil pe care utilizatorul îl lansează

> **Notă importantă:** Pe Windows, aplicația curentă nu poate fi suprascrisă
> în timp ce rulează. Fluxul este:
> 1. Utilizatorul descarcă fișierul (banner în aplicație)
> 2. Aplicatia afișează un dialog cu instrucțiuni clare
> 3. Utilizatorul **închide PRO TERM**
> 4. Rulează fișierul descărcat (ZIP dezip + înlocuire, sau installer .exe)

---

## Pas 2W — Upload în Firebase Storage

1. Firebase Console → Storage
2. Creează folderul `app_releases/windows/` (dacă nu există)
3. Upload fișierul (ZIP sau .exe), redenumit cu versiunea, ex:
   `app_releases/windows/proterm-setup-1.1.0+3.exe`
4. Obține **Download URL** (același procedeu ca la Pasul 2A)

---

## ══════════════════════════════════════════════
## Pas 3 — Actualizează documentul Firestore (AMBELE platforme)
## ══════════════════════════════════════════════

1. Firebase Console → **Firestore Database**
2. Dacă nu există deja, creează colecția **`app_config`**
3. Creează (sau editează) documentul cu ID-ul exact **`version_info`**
4. Completează/actualizează câmpurile:

| Câmp | Tip | Exemplu | Observații |
|---|---|---|---|
| `latestVersion` | string | `"1.1.0"` | doar pentru afișare în banner |
| `latestBuildNumber` | number | `3` | **acesta decide dacă apare update-ul** — trebuie mai mare ca buildNumber-ul instalat |
| `apkUrl` | string | `"https://firebasestorage.../proterm-1.1.0+3.apk?..."` | URL APK Android; lasă gol dacă nu faci release Android |
| `windowsExeUrl` | string | `"https://firebasestorage.../proterm-setup-1.1.0+3.exe?..."` | URL installer Windows; lasă gol dacă nu faci release Windows |
| `releaseNotes` | string | `"Fix dezalocare angajați, auto-update Windows"` | afișat sub mesajul principal, max 2 linii |
| `forceUpdate` | boolean | `false` | **lasă pe `false`** — nu e implementată blocarea încă |

5. Salvează documentul.

**Asta e tot.** La următoarea pornire a aplicației pe telefoanele/PC-urile
angajaților, banner-ul de update va apărea automat — pe Android pentru
`apkUrl`, pe Windows pentru `windowsExeUrl`. Dacă URL-ul platformei lipsește,
banner-ul NU apare pe acea platformă (nu dă eroare).

---

## Fluxul utilizatorului pe Windows (ce vede angajatul)

1. La pornire, apare banner galben sub AppBar:
   „Versiune nouă disponibilă (v1.1.0) — Actualizează acum"
2. Apasă **Actualizează** → bara de progres arată descărcarea
3. La final, apare un dialog cu 3 pași numerotați:
   - Pas 1: Închide complet aplicația PRO TERM
   - Pas 2: Rulează fișierul descărcat (afișat calea completă)
   - Pas 3: Urmează pașii instalatorului
4. Buton **Deschide folderul** → deschide Explorer cu fișierul selectat
5. Utilizatorul închide PRO TERM, dublu-click pe fișierul .exe → instalare

Fișierul se salvează în **Downloads** (dacă există) sau în directorul
temporar al sistemului — calea exactă e afișată în dialog.

---

## Cum testezi că funcționează (fără să aștepți un build nou)

### Test Android:
1. În Firestore, pune temporar `latestBuildNumber` mai mare decât ce ai
   instalat (ex: dacă ai `1.1.0+3`, pune `999`)
2. `apkUrl` = orice URL valid .apk din Storage
3. Redeschide aplicația pe telefon
4. Banner-ul trebuie să apară sub AppBar

### Test Windows:
1. Același procedeu — pune `latestBuildNumber: 999`
2. `windowsExeUrl` = orice URL valid din Storage (poate fi și un fișier
   mai mic pentru test, important să fie accesibil HTTP)
3. Repornește aplicația pe PC
4. Banner-ul apare → „Actualizează" → progres descărcare → dialog cu pași
5. Butonul „Deschide folderul" trebuie să deschidă Explorer

**După test, pune valorile reale înapoi.**

---

## Reguli importante

- **NU șterge fișierele vechi din Storage** imediat — ține minim ultimele
  2-3 versiuni pentru rollback rapid
- **`latestBuildNumber` trebuie să fie un număr întreg** (partea după `+`
  din `pubspec.yaml`)
- Poți face release **doar pe Android** (fără `windowsExeUrl`), **doar pe
  Windows** (fără `apkUrl`), sau **pe ambele** — sistemul tratează separat
  fiecare platformă
- Dacă `apkUrl` sau `windowsExeUrl` e invalid, angajații vor vedea eroare
  roșie în banner — pot ignora (X) și continuă normal; nu blochează aplicația
- `forceUpdate` există ca câmp dar **nu face nimic încă**
