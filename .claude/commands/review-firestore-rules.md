---
description: Auditează regulile de securitate Firestore ale proiectului
allowed-tools: Bash(find *), Bash(cat *), mcp__firebase-mcp__firebase_get_security_rules, mcp__firebase-mcp__firebase_validate_security_rules
---

Caută un fișier `firestore.rules` local (`find . -iname firestore.rules`).

- Dacă există local: citește-l, validează-l cu tool-ul MCP Firebase
  `firebase_validate_security_rules`, și fă un audit orientat pe riscuri
  reale (acces necontrolat la colecții cu date financiare/clienți, lipsă
  verificare `request.auth`, reguli `allow read, write: if true`).
- Dacă NU există local (regulile sunt gestionate doar în Firebase
  Console): folosește tool-ul MCP `firebase_get_security_rules` pentru
  proiectul curent (`devizpro-ultra-pilot`, vezi `firebase.json`) ca să
  le citești direct din cloud, apoi fă același audit.

Raportează găsirile ca listă prioritizată (risc mare → risc mic), cu
citat exact din regulă pentru fiecare. NU modifica regulile fără
aprobare explicită — sunt live, în producție.
