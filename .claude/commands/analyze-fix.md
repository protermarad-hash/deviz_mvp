---
description: Rulează dart analyze, aplică dart fix automat, apoi re-verifică
allowed-tools: Bash(dart *)
---

Rulează `dart analyze` pe tot proiectul. Dacă găsești erori/warning-uri
care pot fi rezolvate automat, rulează `dart fix --apply` și re-verifică
cu `dart analyze`. Raportează concis: câte probleme au fost la început,
câte au rămas, și lista exactă a celor rămase (fișier:linie).

Nu modifica logica de business pentru a "rezolva" un warning — dacă un
fix automat ar schimba comportament (nu doar stil), semnalează-l separat
în loc să-l aplici orbește.
