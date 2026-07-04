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

# Build tag vizibil pe ecran (kBuildTag din lib/core/build_info.dart), cu
# momentul build-ului. Regula permanenta: orice build e identificabil vizual.
$buildTag = "rel-" + (Get-Date -Format "yyyyMMdd-HHmm")
Write-Host "Build tag: $buildTag"

# Foldere dedicate (structura fixa build\releases\{client}\{platforma}\)
$relApkDir = "build\releases\costel\android"
$relWinDir = "build\releases\costel\windows"
New-Item -ItemType Directory -Force -Path $relApkDir | Out-Null
New-Item -ItemType Directory -Force -Path $relWinDir | Out-Null
$relApk = Join-Path $relApkDir "proventaris-costel-v$version-build$buildNumber.apk"
$relZip = Join-Path $relWinDir "proventaris-windows-costel-v$version-build$buildNumber.zip"

# 1. Build APK Android (flavor costel + Firebase costel pe partea Dart)
Write-Host "[1/6] flutter build apk --flavor costel (CLIENT=costel, BUILD_TAG=$buildTag)..."
flutter build apk --release --flavor costel --dart-define=CLIENT=costel --dart-define=BUILD_TAG=$buildTag

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

Write-Host "[3/6] flutter build windows (CLIENT=costel, BUILD_TAG=$buildTag)..."
flutter build windows --release --dart-define=CLIENT=costel --dart-define=BUILD_TAG=$buildTag

# 3. ZIP build Windows DIRECT in folderul dedicat (nume versionat)
Write-Host "[4/6] Arhivare build Windows -> $relZip ..."
Compress-Archive -Path "build\windows\x64\runner\Release\*" `
    -DestinationPath $relZip -Force

# 4. Copiere APK din output-ul implicit Flutter in folderul dedicat.
#    Cu flavors, Flutter genereaza app-costel-release.apk.
$apkSrc = "build\app\outputs\flutter-apk\app-costel-release.apk"
if (-not (Test-Path $apkSrc)) {
    Write-Host "EROARE: nu gasesc $apkSrc" -ForegroundColor Red
    exit 1
}
Copy-Item $apkSrc $relApk -Force
Write-Host "[5/6] APK copiat -> $relApk"

# 5. Curatare output implicit Flutter (conventie: NICIUN artefact livrabil nu
#    ramane in build\app\outputs\... - sursa unica de adevar e build\releases\).
Remove-Item $apkSrc -Force -ErrorAction SilentlyContinue
Write-Host "[6/6] Sters output implicit Flutter: $apkSrc"
Write-Host "      Artefacte finale (sursa unica) in build\releases\costel\ :"
Write-Host "      $relApk"
Write-Host "      $relZip"

Write-Host ""
Write-Host "BUILD COSTEL FINALIZAT! (v$version+$buildNumber - $buildTag)" -ForegroundColor Green
Write-Host "APK:     $relApk"
Write-Host "Windows: $relZip"
