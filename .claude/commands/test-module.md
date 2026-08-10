---
description: Rulează testele pentru un modul specific din lib/features/
argument-hint: <nume-modul, ex. oferte, programari, reclamatii>
allowed-tools: Bash(flutter test *), Bash(find *), Bash(ls *)
---

Modul țintă: $1

Găsește toate fișierele din `test/` al căror nume conține `$1` (sau care
testează fișiere din `lib/features/$1/`), rulează `flutter test` doar pe
acele fișiere, și raportează rezultatul (câte verzi, câte roșii, cu
detaliu pe cele roșii). Dacă nu găsești niciun test relevant pentru acest
modul, spune explicit asta — nu rula toată suita ca fallback tăcut.
