<#
.SYNOPSIS
    Builds the bClock Windows installer (setup.exe).

.DESCRIPTION
    Runs the Flutter release build, then compiles installer\bclock.iss with
    Inno Setup 6, stamping the version from pubspec.yaml. Output:
    build\installer\bClock_Setup_<version>.exe

    CI runs this same script, so a local build matches the CI artifact.

.PARAMETER SkipBuild
    Reuse the existing release build instead of running
    `flutter build windows --release` first.

.EXAMPLE
    .\installer\build.ps1

.EXAMPLE
    .\installer\build.ps1 -SkipBuild
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    # Version from pubspec.yaml; the build number after '+' is dropped.
    $match = Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)'
    if (-not $match) { throw 'No version found in pubspec.yaml.' }
    $version = $match.Matches[0].Groups[1].Value
    Write-Host "bClock $version"

    if (-not $SkipBuild) {
        flutter build windows --release
        if ($LASTEXITCODE) { throw "flutter build failed ($LASTEXITCODE)." }
    }
    $exe = 'build\windows\x64\runner\Release\bclock.exe'
    if (-not (Test-Path $exe)) {
        throw "No release build at $exe. Run without -SkipBuild."
    }

    # PATH first, then the per-user (winget) and all-users (installer,
    # choco) locations.
    $iscc = (Get-Command iscc -ErrorAction SilentlyContinue).Source
    if (-not $iscc) {
        $iscc = @(
            "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $iscc) {
        throw 'Inno Setup 6 not found. Install it: winget install --id JRSoftware.InnoSetup -e --source winget'
    }

    & $iscc /Q "/DAppVersion=$version" installer\bclock.iss
    if ($LASTEXITCODE) { throw "Inno Setup failed ($LASTEXITCODE)." }

    $setup = Resolve-Path "build\installer\bClock_Setup_$version.exe"
    $mb = [math]::Round((Get-Item $setup).Length / 1MB, 1)
    Write-Host "Installer: $setup ($mb MB)"
}
finally {
    Pop-Location
}
