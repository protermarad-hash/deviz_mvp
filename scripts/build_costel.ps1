# =============================================================
#  Build separat ProVentaris - client Costel Costea
#  Proiect Firebase: proventaris-costel-costea (date izolate)
#
#  Foloseste Gradle product flavor "costel" (applicationId
#  ro.proterm.proventaris.costel) + --dart-define=CLIENT=costel.
#  NU mai atinge google-services.json de la root: flavor-ul costel
#  isi ia automat android/app/src/costel/google-services.json.
#
#  Artefactele includ versiunea din pubspec.yaml pentru trasabilitate
#  (aceeasi conventie ca PRO TERM: v{versiune}-build{buildNumber}).
#  Fiecare build creeaza fisiere NOI, distincte - NU suprascrie
#  build-urile vechi (istoric local pastrat).
#
#  Rulare (din radacina proiectului):
#     powershell -ExecutionPolicy Bypass -File scripts\build_costel.ps1
# =============================================================
$ErrorActionPreference = "Stop"

# Radacina proiectului = parintele folderului scripts
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# 0. Citeste versiunea din pubspec.yaml (format: version: X.Y.Z+BUILD)
#    Aceeasi sursa/convenite ca PRO TERM (publish_release.js foloseste
#    v{version}-build{buildNumber}).
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)') {
    $version     = $Matches[1]
    $buildNumber = $Matches[2]
} else {
    Write-Host "EROARE: nu pot citi 'version: X.Y.Z+BUILD' din pubspec.yaml" -ForegroundColor Red
    exit 1
}
Write-Host "Versiune detectata din pubspec.yaml: v$version+$buildNumber"

# Nume artefacte versionate (distincte per build, nu se suprascriu)
$apkOut = "build\proventaris-costel-v$version-build$buildNumber.apk"
$zipOut = "build\proventaris-windows-costel-v$version-build$buildNumber.zip"

# 1. Build APK Android (flavor costel + Firebase costel pe partea Dart)
Write-Host "[1/6] flutter build apk --flavor costel (CLIENT=costel)..."
flutter build apk --release --flavor costel --dart-define=CLIENT=costel

# 2. Build Windows (Windows nu are flavors Android; doar dart-define)
#
#    ⚠️ OBLIGATORIU: curata cache-ul de build Windows INAINTE de compilare.
#    build\windows\ este folder COMUN intre PRO TERM si Costel (Windows nu
#    are product flavors ca Android), iar Flutter NU invalideaza cache-ul
#    Dart la schimbarea --dart-define. Fara curatare, un build Windows
#    reutilizeaza silentios app.so-ul clientului compilat anterior ->
#    artefact contaminat cu Firebase-ul gresit.
#    INCIDENT 2026-07-03: PRO TERM Windows a iesit cu cod Costel (app.so
#    identic la hash) pentru ca s-a compilat dupa un build Costel fara
#    curatare. Descoperit prin hash-compare chiar inainte de livrare.
#    NU elimina acest pas crezand ca e doar intarziere - previne
#    livrarea catre client a aplicatiei conectate la baza de date gresita.
Write-Host "[2/6] Curatare cache Windows (build\windows + .dart_tool\flutter_build)..."
Remove-Item -Recurse -Force "build\windows" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force ".dart_tool\flutter_build" -ErrorAction SilentlyContinue

Write-Host "[3/6] flutter build windows (CLIENT=costel)..."
flutter build windows --release --dart-define=CLIENT=costel

# 3. ZIP build Windows (nume versionat)
Write-Host "[4/6] Arhivare build Windows -> $zipOut ..."
Compress-Archive -Path "build\windows\x64\runner\Release\*" `
    -DestinationPath $zipOut -Force

# 4. Copiere APK cu nume clar versionat
#    Cu flavors, Flutter genereaza app-costel-release.apk
$apkSrc = "build\app\outputs\flutter-apk\app-costel-release.apk"
if (-not (Test-Path $apkSrc)) {
    Write-Host "EROARE: nu gasesc $apkSrc" -ForegroundColor Red
    exit 1
}
Copy-Item $apkSrc $apkOut -Force
Write-Host "[5/6] APK copiat -> $apkOut"

# 5. Organizare artefacte finale in foldere separate per client.
#    Strat suplimentar de siguranta vizuala: nicio confuzie despre ce
#    fisier apartine carui client, nici macar la o privire rapida pe disc.
#    COPIERE (nu mutare) - artefactele raman si la locatia originala de
#    mai sus, ca sa nu rupem fluxul existent (ex: publish_release_costel.js
#    citeste din build\proventaris-costel-*.apk / *.zip).
#    NU sterge artefacte vechi din build\releases\ - istoric pastrat.
$relApkDir = "build\releases\costel\android"
$relWinDir = "build\releases\costel\windows"
New-Item -ItemType Directory -Force -Path $relApkDir | Out-Null
New-Item -ItemType Directory -Force -Path $relWinDir | Out-Null
$relApk = Join-Path $relApkDir "proventaris-costel-v$version-build$buildNumber.apk"
$relZip = Join-Path $relWinDir "proventaris-windows-costel-v$version-build$buildNumber.zip"
Copy-Item $apkOut $relApk -Force
Copy-Item $zipOut $relZip -Force
Write-Host "[6/6] Artefacte organizate in build\releases\costel\ :"
Write-Host "      $relApk"
Write-Host "      $relZip"

Write-Host ""
Write-Host "BUILD COSTEL FINALIZAT! (v$version+$buildNumber)" -ForegroundColor Green
Write-Host "APK:     $apkOut"
Write-Host "Windows: $zipOut"
Write-Host "Releases: $relApk"
Write-Host "          $relZip"
