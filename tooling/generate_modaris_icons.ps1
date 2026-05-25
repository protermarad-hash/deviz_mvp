Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$sourceDir = Join-Path $root 'assets\app_icon'
New-Item -ItemType Directory -Force -Path $sourceDir | Out-Null
$sourcePng = Join-Path $sourceDir 'modaris_source.png'
$normalizedPng = Join-Path $sourceDir 'modaris_app_icon_1024.png'

function Save-ResizedPng {
    param(
        [System.Drawing.Image]$Source,
        [int]$Size,
        [string]$Path
    )

    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($Source, 0, 0, $Size, $Size)
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

function New-IcoFromPng {
    param(
        [string]$PngPath,
        [string]$IcoPath
    )

    $pngBytes = [System.IO.File]::ReadAllBytes($PngPath)
    $fs = [System.IO.File]::Open($IcoPath, [System.IO.FileMode]::Create)
    $writer = New-Object System.IO.BinaryWriter($fs)

    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]1)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]32)
    $writer.Write([UInt32]$pngBytes.Length)
    $writer.Write([UInt32]22)
    $writer.Write($pngBytes)

    $writer.Flush()
    $writer.Dispose()
    $fs.Dispose()
}

if (-not (Test-Path $sourcePng)) {
    throw "Missing source icon asset: $sourcePng"
}

$sourceImage = [System.Drawing.Image]::FromFile($sourcePng)
Save-ResizedPng -Source $sourceImage -Size 1024 -Path $normalizedPng

$androidTargets = @{
    'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
    'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
    'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
    'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
    'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
}

$iosTargets = @{
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png' = 20
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png' = 40
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png' = 60
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png' = 29
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png' = 58
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png' = 87
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png' = 40
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png' = 80
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png' = 120
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png' = 120
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png' = 180
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png' = 76
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png' = 152
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png' = 167
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png' = 1024
}

$macTargets = @{
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_16.png' = 16
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_32.png' = 32
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_64.png' = 64
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_128.png' = 128
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_256.png' = 256
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_512.png' = 512
    'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_1024.png' = 1024
}

$webTargets = @{
    'web\favicon.png' = 32
    'web\icons\Icon-192.png' = 192
    'web\icons\Icon-512.png' = 512
    'web\icons\Icon-maskable-192.png' = 192
    'web\icons\Icon-maskable-512.png' = 512
}

foreach ($target in @($androidTargets.GetEnumerator() + $iosTargets.GetEnumerator() + $macTargets.GetEnumerator() + $webTargets.GetEnumerator())) {
    $outputPath = Join-Path $root $target.Key
    Save-ResizedPng -Source $sourceImage -Size $target.Value -Path $outputPath
}

$windowsPng = Join-Path $sourceDir 'modaris_app_icon_256.png'
Save-ResizedPng -Source $sourceImage -Size 256 -Path $windowsPng
New-IcoFromPng -PngPath $windowsPng -IcoPath (Join-Path $root 'windows\runner\resources\app_icon.ico')

$sourceImage.Dispose()
