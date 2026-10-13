# =============================================================
#  Build ProVentaris - client PRO TERM SRL (build implicit)
#  Proiect Firebase: devizpro-ultra-pilot
#
#  Foloseste Gradle product flavor "proterm" (applicationId
#  ro.proterm.proventaris). Pe partea Dart, clientul implicit e
#  proterm (fara --dart-define=CLIENT).
#
#  Respecta CONVENTIILE DE BUILD din CLAUDE.md:
#   - artefactele livrabile stau EXCLUSIV in build\releases\proterm\{platforma}\
#   - nume versionat v{versiune}-build{buildNumber}
#   - output-ul implicit Flutter e curatat dupa copiere
#   - build tag vizibil (kBuildTag) pasat via --dart-define=BUILD_TAG
#
#  Rulare (din radacina proiectului):
#     powershell -ExecutionPolicy Bypass -File scripts\build_proterm.ps1
#     powershell -ExecutionPolicy Bypass -File scripts\build_proterm.ps1 -ApkOnly
#     powershell -ExecutionPolicy Bypass -File scripts\build_proterm.ps1 -TestOnly
#
#  SIGNING GATE (docs/BUILD_AND_RELEASE_POLICY.md §7/§8, fail-closed):
#   - build canonic: fingerprint-ul SHA-256 al certificatului de productie
#     se citeste EXCLUSIV din scripts\release_cert_proterm.sha256 (fisier
#     versionat, modificat doar prin PR revizuit). Lipsa/invalid -> BLOCKED
#     inainte de build. APK-ul e verificat cu scripts\verify_apk_signature.ps1
#     si ajunge in build\releases\ DOAR daca e acceptat.
#   - -TestOnly: APK release semnat debug, permis explicit, livrat DOAR in
#     build\test-only\proterm\android\ cu "TEST-ONLY" in nume. Niciodata in
#     build\releases\. Implica -ApkOnly.
# =============================================================
param(
    [switch]$ApkOnly,  # doar APK Android (sare build-ul Windows)
    [switch]$TestOnly  # artefact TEST ONLY (semnare debug), izolat de distributie
)
$ErrorActionPreference = "Stop"

# Radacina proiectului = parintele folderului scripts
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$certFile = "scripts\release_cert_proterm.sha256"
$expectedCertSha256 = $null
if ($TestOnly) {
    $ApkOnly = $true
    # Opt-in explicit pentru garda Gradle (doar procesul curent).
    $env:PROVENTARIS_ALLOW_DEBUG_SIGNED_RELEASE = "1"
    Write-Host "MOD TEST ONLY: artefactul NU este distribuibil si nu va ajunge in build\releases\." -ForegroundColor Yellow
} else {
    # Fingerprint-ul asteptat: doar din fisierul versionat (sursa revizuita),
    # NU din variabile de mediu/parametri - altfel s-ar putea "confirma" un
    # APK cu propriul lui fingerprint afisat de build.
    if (-not (Test-Path $certFile)) {
        Write-Host "BLOCKED: $certFile lipseste - nu exista certificat de productie confirmat." -ForegroundColor Red
        Write-Host "Vezi docs/BUILD_AND_RELEASE_POLICY.md sectiunea 8 (procedura de confirmare a fingerprint-ului)." -ForegroundColor Red
        exit 2
    }
    $expectedCertSha256 = (Get-Content $certFile |
        Where-Object { $_ -and -not $_.TrimStart().StartsWith('#') } |
        Select-Object -First 1)
    $normalized = if ($expectedCertSha256) { ($expectedCertSha256 -replace '[:\s]', '').ToLower() } else { '' }
    if ($normalized -notmatch '^[0-9a-f]{64}$') {
        Write-Host "BLOCKED: $certFile nu contine un SHA-256 valid (64 caractere hex)." -ForegroundColor Red
        exit 2
    }

    # Configuratia de semnare de productie: se verifica DOAR existenta
    # fisierului - continutul nu se citeste/afiseaza.
    if (-not (Test-Path "android\key.properties")) {
        Write-Host "EROARE: android\key.properties lipseste - semnarea de productie nu este disponibila." -ForegroundColor Red
        Write-Host "Build oprit (fail-closed): un APK release semnat debug NU este distribuibil." -ForegroundColor Red
        exit 1
    }
}

# Verificare preventiva: procese java/dart ramase dintr-un build anterior
# esuat/intrerupt pot cauza conflicte de fisiere in timpul build-ului curent
# (incident: un proces Gradle orfan concurent a facut ca build-ul curent sa
# esueze real, dar scriptul a continuat si a livrat tacut un artefact vechi).
# Doar avertizeaza - NU le opreste automat, ar putea fi procese legitime.
$orphanProcesses = Get-Process -Name java, dart, dart64 -ErrorAction SilentlyContinue
if ($orphanProcesses) {
    Write-Host "ATENTIE: procese java/dart deja ruleaza inainte de a incepe build-ul:" -ForegroundColor Yellow
    foreach ($proc in $orphanProcesses) {
        Write-Host "  PID $($proc.Id): $($proc.ProcessName)" -ForegroundColor Yellow
    }
    Write-Host "Daca provin dintr-un build anterior neterminat, pot cauza esec de build cu erori neclare (fisiere blocate/conflicte cache)." -ForegroundColor Yellow
    Write-Host "Scriptul continua, dar daca build-ul de mai jos esueaza neasteptat, opreste manual aceste procese si reia." -ForegroundColor Yellow
}

# 0. Citeste versiunea din pubspec.yaml (format: version: X.Y.Z+BUILD)
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

# Foldere dedicate. Distributie: build\releases\{client}\{platforma}\ ;
# TEST ONLY: build\test-only\{client}\android\ (niciodata in build\releases\).
# Folderele se creeaza abia DUPA verificarea semnaturii, ca un build respins
# sa nu atinga directorul de distributie.
if ($TestOnly) {
    $outApkDir = "build\test-only\proterm\android"
    $outApk = Join-Path $outApkDir "app-proterm-v$version-build$buildNumber-TEST-ONLY.apk"
} else {
    $outApkDir = "build\releases\proterm\android"
    $outApk = Join-Path $outApkDir "app-proterm-v$version-build$buildNumber.apk"
}
$relWinDir = "build\releases\proterm\windows"
$relZip = Join-Path $relWinDir "proventaris-windows-v$version-build$buildNumber.zip"

# 1. Build APK Android (flavor proterm)
Write-Host "[1/6] flutter build apk --flavor proterm (BUILD_TAG=$buildTag)..."
flutter build apk --release --flavor proterm --dart-define=BUILD_TAG=$buildTag
if ($LASTEXITCODE -ne 0) {
    Write-Host "EROARE: 'flutter build apk --flavor proterm' a esuat (exit code $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "Build oprit - NU se copiaza niciun artefact in build\releases\proterm\." -ForegroundColor Red
    exit 1
}
$apkSrc = "build\app\outputs\flutter-apk\app-proterm-release.apk"
if (-not (Test-Path $apkSrc)) {
    Write-Host "EROARE: nu gasesc $apkSrc" -ForegroundColor Red
    exit 1
}

# 1b. SIGNING GATE (doar build canonic): semnatura valida, nu Android Debug,
#     certificat = fingerprint-ul de productie confirmat. Respins -> APK-ul
#     se sterge si nimic nu ajunge in build\releases\.
if (-not $TestOnly) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\verify_apk_signature.ps1" `
        -ApkPath $apkSrc -ExpectedCertSha256 $expectedCertSha256
    $verifyExit = $LASTEXITCODE
    if ($verifyExit -ne 0) {
        Remove-Item $apkSrc -Force -ErrorAction SilentlyContinue
        Write-Host "Build oprit (signing gate, cod $verifyExit) - APK respins si sters; NU se copiaza nimic in build\releases\proterm\." -ForegroundColor Red
        exit 1
    }
}

if (-not $ApkOnly) {
    # 2. Curatare cache Windows INAINTE de compilare.
    #    ⚠️ OBLIGATORIU: build\windows\ e folder COMUN intre PRO TERM si Costel
    #    (Windows nu are product flavors ca Android), iar Flutter NU invalideaza
    #    cache-ul Dart la schimbarea --dart-define. Fara curatare, un build
    #    Windows reutilizeaza silentios app.so-ul clientului compilat anterior
    #    -> artefact contaminat cu Firebase-ul gresit (incident 2026-07-03).
    Write-Host "[2/6] Curatare cache Windows (build\windows + .dart_tool\flutter_build)..."
    Remove-Item -Recurse -Force "build\windows" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force ".dart_tool\flutter_build" -ErrorAction SilentlyContinue

    Write-Host "[3/6] flutter build windows (BUILD_TAG=$buildTag)..."
    flutter build windows --release --dart-define=BUILD_TAG=$buildTag
    if ($LASTEXITCODE -ne 0) {
        Write-Host "EROARE: 'flutter build windows' a esuat (exit code $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "Build oprit - NU se arhiveaza/copiaza niciun artefact in build\releases\proterm\." -ForegroundColor Red
        exit 1
    }

    # 3. ZIP build Windows DIRECT in folderul dedicat (nume versionat)
    New-Item -ItemType Directory -Force -Path $relWinDir | Out-Null
    Write-Host "[4/6] Arhivare build Windows -> $relZip ..."
    Compress-Archive -Path "build\windows\x64\runner\Release\*" `
        -DestinationPath $relZip -Force
} else {
    Write-Host "[2-4/6] -ApkOnly: build Windows sarit."
}

# 4. Copiere APK din output-ul implicit Flutter in folderul dedicat.
New-Item -ItemType Directory -Force -Path $outApkDir | Out-Null
Copy-Item $apkSrc $outApk -Force
Write-Host "[5/6] APK copiat -> $outApk"

# 5. Curatare output implicit Flutter (conventie: NICIUN artefact livrabil nu
#    ramane in build\app\outputs\...).
Remove-Item $apkSrc -Force -ErrorAction SilentlyContinue
Write-Host "[6/6] Sters output implicit Flutter: $apkSrc"

Write-Host ""
if ($TestOnly) {
    Write-Host "BUILD TEST ONLY FINALIZAT (v$version+$buildNumber - $buildTag) - NOT DISTRIBUTABLE" -ForegroundColor Yellow
    Write-Host "APK TEST ONLY: $outApk"
} else {
    Write-Host "BUILD PRO TERM FINALIZAT! (v$version+$buildNumber - $buildTag)" -ForegroundColor Green
    Write-Host "APK:     $outApk"
    if (-not $ApkOnly) { Write-Host "Windows: $relZip" }
}
