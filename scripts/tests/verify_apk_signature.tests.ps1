# =============================================================
#  Teste pentru scripts\verify_apk_signature.ps1 + garda din build_proterm.ps1
#
#  Fixture-uri generate la rulare, intr-un director temporar sters la final:
#   - APK de baza: un APK debug construit local (implicit
#     build\app\outputs\flutter-apk\app-proterm-debug.apk, din
#     `flutter build apk --debug --flavor proterm`);
#   - doua keystore-uri de TEST (keytool), cu parole aleatoare generate la
#     rulare, niciodata afisate; NU au legatura cu certificatul de productie.
#  Fingerprint-urile asteptate se calculeaza independent (SHA-256 peste
#  certificatul DER exportat), nu din iesirea apksigner.
#
#  Rulare (din radacina proiectului):
#     powershell -ExecutionPolicy Bypass -File scripts\tests\verify_apk_signature.tests.ps1
#  Exit 0 = toate testele PASS; 1 = cel putin un FAIL; 2 = BLOCKED (lipsa APK
#  de baza / keytool / apksigner).
# =============================================================
param(
    [string]$BaseApk = "build\app\outputs\flutter-apk\app-proterm-debug.apk"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $root
$verify = Join-Path $root "scripts\verify_apk_signature.ps1"

function Find-SdkTool([string]$name) {
    $sdkRoot = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA "Android\Sdk")) |
        Where-Object { $_ -and (Test-Path (Join-Path $_ "build-tools")) } | Select-Object -First 1
    if (-not $sdkRoot) { return $null }
    Get-ChildItem (Join-Path $sdkRoot "build-tools") -Directory |
        Sort-Object { try { [version]$_.Name } catch { [version]"0.0" } } -Descending |
        ForEach-Object { Join-Path $_.FullName $name } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}

$apksigner = Find-SdkTool "apksigner.bat"
$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not (Test-Path $BaseApk) -or -not $apksigner -or -not $keytool) {
    Write-Host "BLOCKED: lipseste APK-ul de baza ($BaseApk), apksigner sau keytool." -ForegroundColor Yellow
    exit 2
}

function Invoke-Native([string]$exe, [string[]]$arguments) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $exe @arguments 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return @{ Code = $code; Out = $out }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pv-sign-tests-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null
$results = New-Object System.Collections.Generic.List[object]

try {
    # --- Keystore-uri de TEST + fingerprint calculat independent ---
    function New-TestKey([string]$alias) {
        $ks = Join-Path $tmp "$alias.p12"
        $pw = [guid]::NewGuid().ToString("N")
        $r = Invoke-Native $keytool @("-genkeypair", "-keystore", $ks, "-storetype", "PKCS12",
            "-storepass", $pw, "-keypass", $pw, "-alias", $alias, "-keyalg", "RSA",
            "-keysize", "2048", "-validity", "2", "-dname", "CN=$alias, O=ProVentaris QA TEST")
        if ($r.Code -ne 0) { throw "keytool genkeypair a esuat pentru $alias" }
        $cer = Join-Path $tmp "$alias.cer"
        $r = Invoke-Native $keytool @("-exportcert", "-keystore", $ks, "-storetype", "PKCS12",
            "-storepass", $pw, "-alias", $alias, "-file", $cer)
        if ($r.Code -ne 0) { throw "keytool exportcert a esuat pentru $alias" }
        $der = [System.IO.File]::ReadAllBytes($cer)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fp = -join ($sha.ComputeHash($der) | ForEach-Object { $_.ToString("x2") })
        return @{ Ks = $ks; Pw = $pw; Alias = $alias; Fp = $fp }
    }
    function New-SignedApk([string]$name, [object[]]$keys) {
        $apk = Join-Path $tmp $name
        Copy-Item $BaseApk $apk
        $signArgs = @("sign")
        # Schemele v3/v4 nu accepta mai multi semnatari; doar pentru fixture.
        if ($keys.Count -gt 1) {
            $signArgs += @("--v3-signing-enabled", "false", "--v4-signing-enabled", "false")
        }
        $first = $true
        $index = 0
        foreach ($k in $keys) {
            if (-not $first) { $signArgs += "--next-signer" }
            $index++
            $signArgs += @("--v1-signer-name", "SIGNER$index", "--ks", $k.Ks, "--ks-type", "PKCS12", "--ks-key-alias", $k.Alias,
                "--ks-pass", "pass:$($k.Pw)", "--key-pass", "pass:$($k.Pw)")
            $first = $false
        }
        $signArgs += $apk
        $r = Invoke-Native $apksigner $signArgs
        if ($r.Code -ne 0) { throw "apksigner sign a esuat pentru ${name}: $(($r.Out -split "`n" | Where-Object { $_ -match 'ERROR|Exception' } | Select-Object -First 1))" }
        return $apk
    }

    $keyA = New-TestKey "qa-test-a"
    $keyB = New-TestKey "qa-test-b"
    $apkA = New-SignedApk "signed-a.apk" @($keyA)
    $apkTwo = New-SignedApk "signed-two.apk" @($keyA, $keyB)
    $apkDebug = Join-Path $tmp "debug.apk"; Copy-Item $BaseApk $apkDebug
    $apkGarbage = Join-Path $tmp "garbage.apk"; Set-Content -Path $apkGarbage -Value "nu este un apk"
    $apkTruncated = Join-Path $tmp "truncated.apk"
    $bytes = [System.IO.File]::ReadAllBytes($apkA)
    [System.IO.File]::WriteAllBytes($apkTruncated, $bytes[0..([int]($bytes.Length / 2))])

    # Fingerprint-ul certificatului debug al masinii (pentru cazul „debug
    # declarat ca asteptat”): citit din APK-ul debug, metadata publica.
    $dbg = Invoke-Native $apksigner @("verify", "--print-certs", $apkDebug)
    $debugFp = ([regex]::Match($dbg.Out, 'SHA-256 digest: ([0-9a-f]{64})')).Groups[1].Value

    function Test-Case([string]$name, [int]$expectedExit, [string]$apk, $fp) {
        $a = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $verify, "-ApkPath", $apk)
        if ($null -ne $fp) { $a += @("-ExpectedCertSha256", $fp) }
        $r = Invoke-Native "powershell" $a
        $ok = ($r.Code -eq $expectedExit)
        $results.Add([pscustomobject]@{ Test = $name; Asteptat = $expectedExit; Obtinut = $r.Code; Rezultat = $(if ($ok) { "PASS" } else { "FAIL" }) })
    }

    Test-Case "fingerprint lipsa"                         10 $apkA $null
    Test-Case "fingerprint doar spatii"                  10 $apkA "   "
    Test-Case "fingerprint invalid (text)"                11 $apkA "nu-e-hex"
    Test-Case "fingerprint invalid (63 hex)"              11 $apkA ($keyA.Fp.Substring(1))
    Test-Case "fingerprint corect"                         0 $apkA $keyA.Fp
    Test-Case "fingerprint corect, MAJUSCULE cu ':'"       0 $apkA ((($keyA.Fp.ToUpper()) -split '(..)' | Where-Object { $_ }) -join ':')
    Test-Case "fingerprint gresit (alt certificat)"       15 $apkA $keyB.Fp
    Test-Case "certificat debug, fingerprint productie"   14 $apkDebug $keyA.Fp
    Test-Case "certificat debug declarat ca asteptat"     14 $apkDebug $debugFp
    Test-Case "APK invalid (nu e zip)"                    13 $apkGarbage $keyA.Fp
    Test-Case "APK trunchiat"                             13 $apkTruncated $keyA.Fp
    Test-Case "APK inexistent"                            13 (Join-Path $tmp "lipsa.apk") $keyA.Fp
    Test-Case "doi semnatari"                             16 $apkTwo $keyA.Fp

    # --- Garda din build_proterm.ps1: fara fingerprint confirmat -> BLOCKED
    #     inainte de build (exit 2, fara "[1/6]"). Nu atinge un fisier real.
    $certFile = Join-Path $root "scripts\release_cert_proterm.sha256"
    $buildScript = Join-Path $root "scripts\build_proterm.ps1"
    function Test-BuildGate([string]$name, [string]$content) {
        if ($null -ne $content) { Set-Content -Path $certFile -Value $content -Encoding ASCII }
        try {
            $r = Invoke-Native "powershell" @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $buildScript, "-ApkOnly")
        } finally {
            if ($null -ne $content) { Remove-Item $certFile -Force -ErrorAction SilentlyContinue }
        }
        $ok = ($r.Code -eq 2) -and ($r.Out -match 'BLOCKED') -and ($r.Out -notmatch '\[1/6\]')
        $results.Add([pscustomobject]@{ Test = "build_proterm: $name"; Asteptat = 2; Obtinut = $r.Code; Rezultat = $(if ($ok) { "PASS" } else { "FAIL" }) })
    }
    if (Test-Path $certFile) {
        $results.Add([pscustomobject]@{ Test = "build_proterm: garda fingerprint"; Asteptat = "-"; Obtinut = "-"; Rezultat = "NOT TESTED (exista $certFile real; nu il modific)" })
    } else {
        Test-BuildGate "fisier fingerprint lipsa" $null
        Test-BuildGate "fisier fingerprint invalid" "# comentariu`r`nnu-e-un-sha256"
        Test-BuildGate "fisier fingerprint doar comentarii" "# nimic aici"
    }
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

$results | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
$failed = @($results | Where-Object { $_.Rezultat -eq "FAIL" }).Count
Write-Host "Total: $($results.Count), FAIL: $failed"
if ($failed -gt 0) { exit 1 }
exit 0
