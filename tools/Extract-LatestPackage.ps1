<#
.SYNOPSIS
Extracts the latest ApexTune package in the repo into /source so GitHub becomes editable source, not zip-only storage.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$SourceDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'source'),
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ApexPackageVersion {
    param([string]$Name)
    if ($Name -match 'v(?<major>\d+)\.(?<minor>\d+)') {
        return [version]("$($Matches.major).$($Matches.minor)")
    }
    return [version]'0.0'
}

function Write-Step {
    param([string]$Message)
    Write-Host "[ApexTune] $Message"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$packages = Get-ChildItem -LiteralPath $RepoRoot -Filter 'ApexTune-v*.zip' -File -ErrorAction SilentlyContinue |
    Sort-Object @{ Expression = { Get-ApexPackageVersion $_.Name } }, LastWriteTime -Descending

if (-not $packages) {
    throw 'No ApexTune-v*.zip package found in repository root.'
}

$package = $packages[0]
Write-Step "Selected package: $($package.Name)"

try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($package.FullName)
    $entryCount = $zip.Entries.Count
    $zip.Dispose()
}
catch {
    throw "ZIP validation failed before extraction: $($_.Exception.Message)"
}

if ($entryCount -lt 10) {
    throw "ZIP validation failed: only $entryCount entries found."
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('apextune_extract_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null

try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($package.FullName, $temp)

    $required = @(
        'ApexTune.CommandCenter.ps1',
        'ApexTune.Desktop.ps1',
        'ApexTune-Updater.ps1',
        'web/index.html',
        'web/app.js',
        'web/styles.css',
        'data/tweaks.json',
        'data/games.json'
    )

    foreach ($rel in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $temp $rel))) {
            throw "Package is missing required file: $rel"
        }
    }

    if ($Clean -and (Test-Path -LiteralPath $SourceDir)) {
        Remove-Item -LiteralPath $SourceDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $SourceDir -Force | Out-Null

    Copy-Item -LiteralPath (Join-Path $temp '*') -Destination $SourceDir -Recurse -Force

    $summary = [ordered]@{
        package = $package.Name
        packageSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $package.FullName).Hash.ToLowerInvariant()
        extractedAt = (Get-Date).ToString('o')
        entryCount = $entryCount
        sourceDir = $SourceDir
    }

    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $SourceDir '.source-package.json') -Encoding UTF8
    "# ApexTune extracted source`n`nGenerated from ``$($package.Name)``. Edit these files instead of editing ZIP-only builds." | Set-Content -LiteralPath (Join-Path $SourceDir 'README.md') -Encoding UTF8

    Write-Step "Extracted $entryCount entries to $SourceDir"
    Write-Step "SHA256: $($summary.packageSha256)"
}
finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
