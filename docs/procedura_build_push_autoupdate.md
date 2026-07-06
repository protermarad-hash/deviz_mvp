# Procedură OBLIGATORIE — Build, Push, Autoupdate (ProVentaris)

Acest document se citește INTEGRAL înainte de orice acțiune de build, push sau publicare. Nu se sar pași, nu se înlocuiesc comenzile cu variante "echivalente" alese de tine.

## Motivul acestui document

La ultima încercare de build, ai rulat `flutter build apk` generic, ai primit `exit 1` (proiectul are flavors — proterm/costel — și nu există un APK "standard" unic), iar artefactele au rămas în `build/app/outputs/flutter-apk/`, exact folderul interzis explicit de convenția de build din CLAUDE.md. Asta arată că citirea CLAUDE.md nu a fost suficientă ca aplicare — de acum, urmezi pașii de mai jos LITERAL, nu din memorie sau deducție.

## PAS 0 — Obligatoriu, de fiecare dată

1. Rulează `git status` — raportează orice fișier deja modificat/necomis înainte să începi (nu presupune stare curată).
2. Deschide și afișează CONȚINUTUL EXACT, verbatim, al secțiunii „🧱 CONVENȚII DE BUILD ȘI LIVRARE MULTI-CLIENT" din CLAUDE.md — copiază-l în răspunsul tău, nu doar rezuma. Dacă nu găsești această secțiune, OPREȘTE-TE și raportează — nu improviza o procedură proprie.
3. Afișează conținutul EXACT al fișierelor `scripts/build_proterm.ps1`, `scripts/build_costel.ps1`, și al scriptului/scripturilor de publicare (`publish_release.js` / `publish_release_costel.js` sau echivalent găsit în repo). Nu presupune ce fac — arată codul lor real.

## PAS 1 — Versionare (înainte de orice build)

- Verifică versiunea curentă din `pubspec.yaml`.
- Incrementează build number-ul la o valoare NOUĂ, niciodată folosită înainte pe niciun device (verifică ultimul număr confirmat cunoscut înainte de a alege următorul — dacă nu ești sigur, întreabă).
- Motivul: Android poate rula silențios cod vechi dacă versionCode e identic cu unul deja instalat — confirmat empiric pe acest proiect.

## PAS 2 — Build (EXCLUSIV prin scripturile existente)

- Rulează `scripts/build_proterm.ps1` (sau `build_costel.ps1`, după caz) — NU `flutter build apk` direct, NU alte variante generice.
- După rulare, confirmă:
  - Artefactul final se află în `build/releases/{client}/{platformă}/`, cu nume versionat.
  - `build/app/outputs/flutter-apk/` (folderul de output implicit Flutter) NU conține niciun APK rămas — dacă găsești ceva acolo, șterge-l și raportează.
  - Rulează `aapt dump badging` pe artefactul din `build/releases/...` (NU pe altceva) și raportează exact `versionCode`, `versionName`, `package name`.
- Dacă orice pas de mai sus eșuează sau dă o eroare neclară, OPREȘTE-TE — nu continua cu un artefact despre care nu ești sigur ce conține.

## PAS 3 — Verificare cod

- `flutter analyze` — 0 erori, raportează orice warning nou.
- `flutter test` — toate testele trec, raportează numărul exact.
- Dacă schimbarea a atins reguli de rotunjire/monedă, confirmă explicit cu `grep` că nu au rămas apeluri vechi (`roundPriceUpToTen`, `.round()`, `ceil()` neintenționate) în fișierele atinse.

## PAS 4 — Commit + Push (git)

- Commit-uri logice separate pe temă, mesaje clare.
- Push pe `origin/master` DOAR după ce Pașii 2 și 3 sunt confirmați cu succes — nu împinge cod netestat.
- NU include în commit: `.claude/settings.local.json`, `backups_firestore/`, fișiere `.bak*`, backup-uri Firestore JSON.

## PAS 5 — Autoupdate / Publicare — ⚠️ RISC RIDICAT, CERE CONFIRMARE EXPLICITĂ

Publicarea unui autoupdate (prin scriptul de publish) trimite build-ul DIRECT la utilizatorii reali ai aplicației, automat, fără alt pas de aprobare din partea lor. Este o acțiune cu impact imediat în producție, pe conturi reale (PRO TERM și/sau Costel, în funcție de script).

**Înainte de a rula orice script de publicare:**
1. Confirmă explicit, în scris, CE CLIENT este țintit (proterm sau costel) — nu presupune din context.
2. Confirmă că build-ul a trecut integral prin Pașii 1-4 de mai sus, fără nicio eroare.
3. Afișează-mi conținutul exact al comenzii pe care urmează s-o rulezi și AȘTEAPTĂ confirmarea mea explicită înainte de execuție. NU rula scriptul de publicare automat, ca parte a unui flux "fără oprire" — acesta este exact tipul de operație ireversibilă (utilizatorii primesc deja update-ul) care necesită aprobare separată, indiferent de alte instrucțiuni generale de lucru neîntrerupt.
4. După publicare, raportează confirmarea explicită din output (succes/eșec) și, dacă mecanismul o permite, cum poate fi verificată versiunea publicată de pe un device real.

## Reguli generale (se aplică la tot ce faci aici)

- Comunicare exclusiv în limba română, cu diacritice.
- Nu declara „gata"/„confirmat" fără dovadă din execuție reală (comandă rulată, output afișat) — cod citit static nu ajunge.
- Dacă găsești o discrepanță între ce spune acest document și ce găsești real în repo, oprește-te și raportează — nu alege tu ce variantă e „probabil corectă".
