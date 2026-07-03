# =============================================================
#  Build separat ProVentaris - client Costel Costea
#  Proiect Firebase: proventaris-costel-costea (date izolate)
#
#  Foloseste Gradle product flavor "costel" (applicationId
#  ro.proterm.proventaris.costel) + --dart-define=CLIENT=costel.
#  NU mai atinge google-services.json de la root: flavor-ul costel
#  isi ia automat android/app/src/costel/google-services.json.
#
#  Rulare (din radacina proiectului):
#     powershell -ExecutionPolicy Bypass -File scripts\build_costel.ps1
# =============================================================
$ErrorActionPreference = "Stop"

# Radacina proiectului = parintele folderului scripts
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# 1. Build APK Android (flavor costel + Firebase costel pe partea Dart)
Write-Host "[1/4] flutter build apk --flavor costel (CLIENT=costel)..."
flutter build apk --release --flavor costel --dart-define=CLIENT=costel

# 2. Build Windows (Windows nu are flavors Android; doar dart-define)
Write-Host "[2/4] flutter build windows (CLIENT=costel)..."
flutter build windows --release --dart-define=CLIENT=costel

# 3. ZIP build Windows
Write-Host "[3/4] Arhivare build Windows..."
Compress-Archive -Path "build\windows\x64\runner\Release\*" `
    -DestinationPath "build\proventaris-windows-costel.zip" -Force

# 4. Copiere APK cu nume clar
#    Cu flavors, Flutter genereaza app-costel-release.apk
$apkSrc = "build\app\outputs\flutter-apk\app-costel-release.apk"
if (-not (Test-Path $apkSrc)) {
    Write-Host "EROARE: nu gasesc $apkSrc" -ForegroundColor Red
    exit 1
}
Copy-Item $apkSrc "build\proventaris-costel.apk" -Force
Write-Host "[4/4] APK copiat -> build\proventaris-costel.apk"

Write-Host ""
Write-Host "BUILD COSTEL FINALIZAT!" -ForegroundColor Green
Write-Host "APK:     build\proventaris-costel.apk"
Write-Host "Windows: build\proventaris-windows-costel.zip"
