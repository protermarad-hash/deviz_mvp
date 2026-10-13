# Teste pe dispozitiv (integration_test) — DOAR pe emulator izolat

Flavorul `proterm` inițializează **nativ** FirebaseApp de producție
(`devizpro-ultra-pilot`, din `google-services.json`) la pornirea procesului,
înainte de orice cod Dart. Pe un dispozitiv cu internet, procesul de test ar
putea contacta proiectul live. De aceea testele de aici se rulează **numai**
pe un emulator fără rețea.

`flutter test` (fără argumente, ca în CI) rulează doar `test/` — nu și acest
director.

## 1. Emulator dedicat, izolat

Nu folosiți un emulator partajat cu alte sesiuni/aplicații și nici un
dispozitiv cu aplicația de producție instalată.

```
emulator -avd <AVD_dedicat> -port 5590 -read-only -no-snapshot -no-boot-anim -dns-server 127.0.0.1 -no-audio
adb -s emulator-5590 shell cmd connectivity airplane-mode enable
adb -s emulator-5590 shell svc wifi disable
adb -s emulator-5590 shell svc data disable
```

## 2. Verificare izolare (înainte și după rulare)

```
adb -s emulator-5590 shell settings get global airplane_mode_on   # 1
adb -s emulator-5590 shell ip route                               # gol
adb -s emulator-5590 shell ping -c1 -W2 firestore.googleapis.com  # unknown host
adb -s emulator-5590 shell "nc -w 3 8.8.8.8 53 </dev/null"        # Network is unreachable
```

## 3. Rulare

```
flutter test integration_test/pr6_partner_dialog_device_test.dart -d emulator-5590 --flavor proterm
```

Gărzi automate în harness:
- `setUpAll` oprește toată rularea dacă dispozitivul are internet
  (DNS `firestore.googleapis.com` sau TCP `8.8.8.8:53`) — detectează, dar
  nu poate preveni inițializarea nativă; protecția reală e pasul 1.
- `Firebase.apps` trebuie să fie gol în Dart la început și la final.

Notă: `flutter test` pe dispozitiv dezinstalează aplicația după rulare, deci
datele nu persistă între două rulări `flutter test`.
