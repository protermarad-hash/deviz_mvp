---
description: Rulează build_runner pentru generarea codului (dacă proiectul are pachete care necesită asta)
allowed-tools: Bash(dart *), Bash(flutter *), Bash(grep *)
---

Verifică în `pubspec.yaml` dacă există dependențe care necesită code
generation (`build_runner`, `json_serializable`, `freezed`, etc.). Dacă
nu există, spune explicit că proiectul nu folosește build_runner și nu
rula nimic. Dacă există, rulează
`dart run build_runner build --delete-conflicting-outputs` și raportează
fișierele generate/modificate.
