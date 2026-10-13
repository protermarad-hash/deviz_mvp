# =============================================================
#  Verificare semnatura APK pentru distributie (fail-closed)
#  docs/BUILD_AND_RELEASE_POLICY.md §7, §8, §10 (SIGNING GATE)
#
#  Foloseste DOAR metadate publice ale certificatului, extrase din APK cu
#  `apksigner verify --print-certs` (subiect + SHA-256). Nu citeste
#  keystore-ul, parole sau chei private.
#
#  Rulare:
#     powershell -ExecutionPolicy Bypass -File scripts\verify_apk_signature.ps1 `
#         -ApkPath <apk> -ExpectedCertSha256 <64 hex>
#
#  Coduri de iesire (0 = APK acceptat pentru distributie):
#     10 fingerprint asteptat lipsa        11 fingerprint asteptat invalid
#     12 apksigner indisponibil            13 APK lipsa / semnatura invalida
#     14 certificat Android Debug          15 certificat diferit de cel asteptat
#     16 numar de semnatari diferit de 1
# =============================================================
param(
    [string]$ApkPath,
    [string]$ExpectedCertSha256,
    [string]$ApkSigner
)
$ErrorActionPreference = "Stop"

function Fail([int]$code, [string]$message) {
    Write-Host "RESPINS (cod $code): $message" -ForegroundColor Red
    exit $code
}

# 1. Fingerprint-ul asteptat: obligatoriu si bine format (64 hex, ':' permis).
if ([string]::IsNullOrWhiteSpace($ExpectedCertSha256)) {
    Fail 10 "fingerprint-ul SHA-256 asteptat al certificatului de productie lipseste."
}
$expected = ($ExpectedCertSha256 -replace '[:\s]', '').ToLower()
if ($expected -notmatch '^[0-9a-f]{64}$') {
    Fail 11 "fingerprint-ul asteptat nu este un SHA-256 valid (64 caractere hex)."
}

# 2. apksigner din Android SDK build-tools (cea mai noua versiune).
if (-not $ApkSigner) {
    $sdkRoot = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA "Android\Sdk")) |
        Where-Object { $_ -and (Test-Path (Join-Path $_ "build-tools")) } | Select-Object -First 1
    if ($sdkRoot) {
        $ApkSigner = Get-ChildItem (Join-Path $sdkRoot "build-tools") -Directory |
            Sort-Object { try { [version]$_.Name } catch { [version]"0.0" } } -Descending |
            ForEach-Object { Join-Path $_.FullName "apksigner.bat" } |
            Where-Object { Test-Path $_ } | Select-Object -First 1
    }
}
if (-not $ApkSigner -or -not (Test-Path $ApkSigner)) {
    Fail 12 "apksigner nu a fost gasit (Android SDK build-tools)."
}

# 3. Semnatura APK valida.
if (-not $ApkPath -or -not (Test-Path $ApkPath)) {
    Fail 13 "APK-ul nu exista: $ApkPath"
}
# PowerShell 5.1: cu ErrorActionPreference=Stop, stderr-ul redirectat al unui
# exe nativ devine eroare fatala; decide doar exit code-ul apksigner.
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$certOutput = & $ApkSigner verify --print-certs $ApkPath 2>&1 | Out-String
$apksignerExit = $LASTEXITCODE
$ErrorActionPreference = $prevPref
if ($apksignerExit -ne 0) {
    Fail 13 "semnatura APK invalida sau APK corupt (apksigner exit $apksignerExit)."
}

# 4. Exact un semnatar, cu subiect si SHA-256 lizibile.
$subjects = [regex]::Matches($certOutput, 'Signer #\d+ certificate DN: (.+)')
$digests = [regex]::Matches($certOutput, 'Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]{64})')
if ($subjects.Count -ne 1 -or $digests.Count -ne 1) {
    Fail 16 "APK-ul trebuie sa aiba exact un semnatar (gasit: $($digests.Count))."
}
$subject = $subjects[0].Groups[1].Value.Trim()
$actual = $digests[0].Groups[1].Value.ToLower()
Write-Host "Certificat APK: $subject"
Write-Host "SHA-256 certificat APK: $actual"

# 5. Verificare separata: certificatul Android Debug nu e niciodata acceptat,
#    indiferent de fingerprint-ul asteptat.
if ($subject -match 'CN=Android Debug') {
    Fail 14 "APK semnat cu certificatul Android Debug - TEST ONLY, NOT DISTRIBUTABLE."
}

# 6. Certificatul trebuie sa fie exact cel de productie asteptat.
if ($actual -ne $expected) {
    Fail 15 "certificatul APK NU corespunde certificatului de productie asteptat."
}

Write-Host "ACCEPTAT: semnatura valida, certificat de productie confirmat." -ForegroundColor Green
exit 0
