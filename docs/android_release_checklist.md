# ProVentaris — Android Release Checklist

Checklist complet pentru build release Android si publicare Google Play.

---

## 1. Generare keystore (PRIMA OARA — o singura data)

```bash
keytool -genkey -v \
  -keystore android/proventaris-release.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias proventaris
```

Vei fi intrebat pentru:
- First and last name: PRO TERM SRL
- Organization: PRO TERM
- City/Locality: Arad
- State/Province: Arad
- Country Code: RO

**Salveaza keystore-ul si parola intr-un loc sigur (1Password, bitwarden etc.).**
**NICIODATĂ nu il pune in git!**

---

## 2. Creeaza android/key.properties

Copiaza template-ul si completeaza:

```bash
cp android/key.properties.template android/key.properties
```

Editeaza `android/key.properties`:
```
storePassword=PAROLA_TA_KEYSTORE
keyPassword=PAROLA_TA_CHEIE
keyAlias=proventaris
storeFile=../proventaris-release.jks
```

Verifica ca `android/key.properties` este in `.gitignore`:
```bash
cat .gitignore | grep key.properties
```

---

## 3. Configureaza Firebase pentru noul package name

**OBLIGATORIU** daca schimbi applicationId:

1. Mergi la Firebase Console: https://console.firebase.google.com
2. Selecteaza proiectul ProVentaris/PRO TERM
3. Project Settings → General → Your apps
4. Apasa "+ Add app" → Android
5. Completeaza:
   - Android package name: `ro.proterm.proventaris`
   - App nickname: ProVentaris
   - Debug signing certificate SHA-1: (optional pentru development)
6. Descarca `google-services.json`
7. Inlocuieste `android/app/google-services.json` cu fisierul nou descarcat

---

## 4. Update versiune inainte de fiecare release

In `pubspec.yaml`:
```yaml
version: 1.0.0+1
         ^^^^^  ^ 
         |      |
         |      versionCode (numar intreg, creste cu 1 la fiecare build Play Store)
         versionName (versiunea vizibila utilizatorilor)
```

**Regula versionCode:** Play Store nu accepta acelasi versionCode de doua ori.
Creste intotdeauna versionCode cu cel putin 1 fata de versiunea precedenta.

Exemple:
- `1.0.0+1` → prima versiune
- `1.0.1+2` → hotfix
- `1.1.0+3` → release cu functionalitati noi
- `2.0.0+10` → versiune majora (poti sari numere)

---

## 5. Genereaza iconite launcher

```bash
flutter pub run flutter_launcher_icons
```

Verifica ca iconita apare in:
- `android/app/src/main/res/mipmap-hdpi/launcher_icon.png`
- `android/app/src/main/res/mipmap-xhdpi/launcher_icon.png`
- `android/app/src/main/res/mipmap-xxhdpi/launcher_icon.png`
- `android/app/src/main/res/mipmap-xxxhdpi/launcher_icon.png`

---

## 6. Build APK release (distributie directa)

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Fisierul generat: `build/app/outputs/flutter-apk/app-release.apk`

**Trimite APK-ul direct pe telefon via:**
- USB + adb: `adb install build/app/outputs/flutter-apk/app-release.apk`
- Email / WhatsApp / Drive (pentru angajati)
- Firebase App Distribution (recomandat pentru testing intern)

---

## 7. Build AAB release (Google Play)

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

Fisierul generat: `build/app/outputs/bundle/release/app-release.aab`

---

## 8. Upload in Google Play Console

1. Mergi la https://play.google.com/console
2. Selecteaza aplicatia ProVentaris (sau creeaza una noua)
3. Release → Testing → Internal testing (pentru prima oara)
4. Create new release → Upload `.aab` file
5. Completeaza release notes (romana + engleza)
6. Review and rollout to internal testing

**Procesul complet prima data:**
- Internal testing → 1-2 zile review
- Closed testing (angajati) → aprobare manuala utilizatori
- Open testing → fara restrictii
- Production → review complet Google (3-7 zile prima oara)

---

## 9. Dupa fiecare release nou

- [ ] Creste `versionCode` in `pubspec.yaml` (minim +1)
- [ ] Actualizeaza `versionName` daca e versiune noua
- [ ] `flutter clean && flutter pub get`
- [ ] `flutter analyze` → 0 erori
- [ ] `flutter build appbundle --release`
- [ ] Upload AAB nou in Play Console
- [ ] Completeaza release notes

---

## 10. Securitate checklist

- [ ] `android/key.properties` NU este in git (`git status` sa nu il afiseze)
- [ ] `android/proventaris-release.jks` NU este in git
- [ ] `*.keystore`, `*.jks` sunt in `.gitignore`
- [ ] Nu exista parole hardcodate in cod Dart
- [ ] API key Anthropic este in SharedPreferences (introdus de utilizator), nu in cod
- [ ] Firebase API keys in `firebase_options.dart` sunt restricte prin package name

---

## Comenzi utile

```bash
# Verifica ca nu ai fisiere sensibile staged:
git status

# Verifica .gitignore functioneaza:
git check-ignore -v android/key.properties

# SHA-1 debug key (pentru Firebase Console optional):
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# SHA-1 release key:
keytool -list -v -keystore android/proventaris-release.jks -alias proventaris

# Verifica applicationId in APK:
aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep package
```
