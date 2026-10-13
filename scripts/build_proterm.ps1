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
# =============================================================
param(
    [switch]$ApkOnly,  # doar APK Android (sare build-ul Windows)
    # SHA-256 al certificatului de productie (metadata publica, din
    # `apksigner verify --print-certs` pe un APK de productie confirmat).
    # Daca e setat, APK-ul nou trebuie sa aiba exact acest certificat.
    [string]$ExpectedCertSha256 = $env:PROVENTARIS_RELEASE_CERT_SHA256
)
$ErrorActionPreference = "Stop"

# Radacina proiectului = parintele folderului scripts
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# Garda semnare (fail-closed, docs/BUILD_AND_RELEASE_POLICY.md §7): fara
# configuratia de semnare de productie nu se construieste un APK release.
# Se verifica DOAR existenta fisierului — continutul nu se citeste/afiseaza.
if (-not (Test-Path "android\key.properties")) {
    Write-Host "EROARE: android\key.properties lipseste - semnarea de productie nu este disponibila." -ForegroundColor Red
    Write-Host "Build oprit (fail-closed): un APK release semnat debug NU este distribuibil." -ForegroundColor Red
    exit 1
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

# Foldere dedicate (structura fixa build\releases\{client}\{platforma}\)
$relApkDir = "build\releases\proterm\android"
$relWinDir = "build\releases\proterm\windows"
New-Item -ItemType Directory -Force -Path $relApkDir | Out-Null
New-Item -ItemType Directory -Force -Path $relWinDir | Out-Null
$relApk = Join-Path $relApkDir "app-proterm-v$version-build$buildNumber.apk"
$relZip = Join-Path $relWinDir "proventaris-windows-v$version-build$buildNumber.zip"

# 1. Build APK Android (flavor proterm)
Write-Host "[1/6] flutter build apk --flavor proterm (BUILD_TAG=$buildTag)..."
flutter build apk --release --flavor proterm --dart-define=BUILD_TAG=$buildTag
if ($LASTEXITCODE -ne 0) {
    Write-Host "EROARE: 'flutter build apk --flavor proterm' a esuat (exit code $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "Build oprit - NU se copiaza niciun artefact in build\releases\proterm\." -ForegroundColor Red
    exit 1
}

# 1b. Verificare semnatura APK (fail-closed). Se citesc doar metadate publice
#     ale certificatului (subiect + SHA-256), extrase din APK-ul construit.
$apkBuilt = "build\app\outputs\flutter-apk\app-proterm-release.apk"
$sdkRoot = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA "Android\Sdk")) |
    Where-Object { $_ -and (Test-Path (Join-Path $_ "build-tools")) } | Select-Object -First 1
$apksigner = $null
if ($sdkRoot) {
    $apksigner = Get-ChildItem (Join-Path $sdkRoot "build-tools") -Directory |
        Sort-Object { try { [version]$_.Name } catch { [version]"0.0" } } -Descending |
        ForEach-Object { Join-Path $_.FullName "apksigner.bat" } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $apksigner) {
    Write-Host "EROARE: apksigner nu a fost gasit (Android SDK build-tools) - semnatura nu poate fi verificata." -ForegroundColor Red
    exit 1
}
# PowerShell 5.1: cu ErrorActionPreference=Stop, stderr-ul unui exe nativ
# redirectat (2>&1) devine eroare fatala; avertismentele apksigner nu trebuie
# sa opreasca scriptul - decide doar exit code-ul.
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$certOutput = & $apksigner verify --print-certs $apkBuilt 2>&1 | Out-String
$apksignerExit = $LASTEXITCODE
$ErrorActionPreference = $prevPref
if ($apksignerExit -ne 0) {
    Write-Host "EROARE: apksigner verify a esuat pentru $apkBuilt." -ForegroundColor Red
    exit 1
}
$certSubject = ([regex]::Match($certOutput, 'Signer #1 certificate DN: (.+)')).Groups[1].Value.Trim()
$certSha256 = ([regex]::Match($certOutput, 'Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)')).Groups[1].Value.Trim().ToLower()
Write-Host "      Semnatura APK: $certSubject"
Write-Host "      SHA-256 certificat: $certSha256"
if (-not $certSubject -or -not $certSha256) {
    Write-Host "EROARE: nu am putut citi certificatul de semnare din APK." -ForegroundColor Red
    exit 1
}
if ($certSubject -match 'CN=Android Debug') {
    Write-Host "EROARE: APK-ul release este semnat cu certificatul DEBUG - TEST ONLY, NOT DISTRIBUTABLE." -ForegroundColor Red
    Write-Host "Build oprit - NU se copiaza niciun artefact in build\releases\proterm\." -ForegroundColor Red
    exit 1
}
if ($ExpectedCertSha256) {
    if ($certSha256 -ne $ExpectedCertSha256.Replace(':', '').Trim().ToLower()) {
        Write-Host "EROARE: certificatul APK nu corespunde certificatului de productie asteptat." -ForegroundColor Red
        Write-Host "Build oprit - NU se copiaza niciun artefact in build\releases\proterm\." -ForegroundColor Red
        exit 1
    }
    Write-Host "      Certificat confirmat = certificatul de productie asteptat." -ForegroundColor Green
} else {
    Write-Host "ATENTIE: PROVENTARIS_RELEASE_CERT_SHA256 nu e setat - compara MANUAL SHA-256 certificat de mai sus cu certificatul de productie documentat inainte de distributie." -ForegroundColor Yellow
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
    Write-Host "[4/6] Arhivare build Windows -> $relZip ..."
    Compress-Archive -Path "build\windows\x64\runner\Release\*" `
        -DestinationPath $relZip -Force
} else {
    Write-Host "[2-4/6] -ApkOnly: build Windows sarit."
}

# 4. Copiere APK din output-ul implicit Flutter in folderul dedicat.
#    Cu flavors, Flutter genereaza app-proterm-release.apk.
$apkSrc = "build\app\outputs\flutter-apk\app-proterm-release.apk"
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
Write-Host "      Artefacte finale (sursa unica) in build\releases\proterm\ :"
Write-Host "      $relApk"
Write-Host "      $relZip"

Write-Host ""
Write-Host "BUILD PRO TERM FINALIZAT! (v$version+$buildNumber - $buildTag)" -ForegroundColor Green
Write-Host "APK:     $relApk"
Write-Host "Windows: $relZip"
