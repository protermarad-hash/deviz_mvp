# DevizPro Ultra — Starter PC + Android + sincronizare cloud

Acesta este un proiect **Flutter** pregătit pentru **Android** și **Windows**, cu **Supabase** pentru autentificare și sincronizare cloud.

## Ce face deja
- login cu email și parolă
- bază cloud pentru clienți, materiale și oferte
- creare ofertă cu:
  - materiale
  - manoperă generală
  - regie
  - profit
  - TVA
  - monedă RON/EUR
- sincronizare între PC și Android prin Supabase
- export PDF simplu pentru ofertă client

## Ce trebuie să faci, fără cunoștințe de cod

### Varianta cea mai simplă
1. Trimite această arhivă unui programator Flutter.
2. El face doar 4 lucruri:
   - instalează Flutter
   - creează proiectul Supabase
   - completează cheia și URL-ul în `lib/app_config.dart`
   - rulează build-ul pentru Android și Windows

### Dacă vrei să încerci chiar tu
1. Instalezi Flutter de pe documentația oficială.
2. Instalezi Android Studio.
3. Creezi cont Supabase.
4. Creezi un proiect nou în Supabase.
5. În Supabase, rulezi fișierul `supabase/schema.sql`.
6. Deschizi fișierul `lib/app_config.dart` și completezi:
   - `supabaseUrl`
   - `supabaseAnonKey`
7. În terminal, în folderul proiectului, rulezi:
   - `flutter pub get`
   - `flutter run -d windows`
   - sau `flutter run -d android`

## Build final
### Android APK
```bash
flutter build apk --release
```

### Windows EXE
```bash
flutter build windows
```

## Unde găsești fișierele importante
- `lib/main.dart` — aplicația principală
- `lib/app_config.dart` — cheia Supabase
- `supabase/schema.sql` — tabelele și politicile din cloud

## Ce mai trebuie făcut după MVP
- editare și ștergere completă pentru toate entitățile
- încărcare logo firmă
- ofertă PDF complet branduită
- utilaje și scule
- istoric oferte
- număr ofertă incremental pe an
- rapoarte de profitabilitate

## Important
Acest pachet este **proiect sursă pregătit pentru build**, nu APK/EXE compilat direct.
