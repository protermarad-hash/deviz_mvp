# =============================================================
#  Build separat ProVentaris - client Costel Costea
#  Proiect Firebase: proventaris-costel-costea (date izolate)
#
#  Comuta temporar google-services.json pe varianta Costel,
#  compileaza APK + Windows cu --dart-define=CLIENT=costel,
#  apoi RESTAUREAZA google-services.json original PRO TERM.
#
#  Rulare (din radacina proiectului):
#     powershell -ExecutionPolicy Bypass -File scripts\build_costel.ps1
# =============================================================
$ErrorActionPreference = "Stop"

# Radacina proiectului = parintele folderului scripts
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$gsMain   = "android\app\google-services.json"
$gsCostel = "android\app\google-services-costel.json"
$gsBackup = "android\app\google-services.bak.json"

if (-not (Test-Path $gsCostel)) {
    Write-Host "EROARE: lipseste $gsCostel" -ForegroundColor Red
    exit 1
}

try {
    # 1. Backup google-services.json original
    Copy-Item $gsMain $gsBackup -Force
    Write-Host "[1/8] Backup google-services.json -> google-services.bak.json"

    # 2. Swap pe varianta Costel
    Copy-Item $gsCostel $gsMain -Force
    Write-Host "[2/8] google-services.json comutat pe proiectul Costel"

    # 3. Build APK Android
    Write-Host "[3/8] flutter build apk (CLIENT=costel)..."
    flutter build apk --release --dart-define=CLIENT=costel

    # 4. Build Windows
    Write-Host "[4/8] flutter build windows (CLIENT=costel)..."
    flutter build windows --release --dart-define=CLIENT=costel

    # 5. ZIP build Windows
    Write-Host "[5/8] Arhivare build Windows..."
    Compress-Archive -Path "build\windows\x64\runner\Release\*" `
        -DestinationPath "build\proventaris-windows-costel.zip" -Force
}
finally {
    # 6. Restaurare google-services.json original (garantat, chiar si la eroare)
    if (Test-Path $gsBackup) {
        Copy-Item $gsBackup $gsMain -Force
        Write-Host "[6/8] google-services.json PRO TERM restaurat"
    }
}

# 7. Copiere APK cu nume clar
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" `
    "build\proventaris-costel.apk" -Force
Write-Host "[7/8] APK copiat -> build\proventaris-costel.apk"

# 8. Raport final
Write-Host ""
Write-Host "BUILD COSTEL FINALIZAT!" -ForegroundColor Green
Write-Host "APK:     build\proventaris-costel.apk"
Write-Host "Windows: build\proventaris-windows-costel.zip"
