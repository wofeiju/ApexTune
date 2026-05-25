<#
.SYNOPSIS
Validates ApexTune repository source, JSON catalogs, and stable package before release.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$RequireSource,
    [switch]$NoReportFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$results = New-Object System.Collections.Generic.List[object]

function Add-CheckResult {
    param([string]$Name,[string]$Status,[string]$Detail)
    $results.Add([pscustomobject]@{ check=$Name; status=$Status; detail=$Detail })
}

function Test-ApexPowerShellSyntax {
    param([string]$Path)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        Add-CheckResult "PowerShell syntax: $Path" 'FAIL' (($errors | Select-Object -First 5 | ForEach-Object Message) -join '; ')
    } else {
        Add-CheckResult "PowerShell syntax: $Path" 'PASS' 'No parser errors.'
    }
}

function Test-ApexJsonSyntax {
    param([string]$Path)
    try {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
        Add-CheckResult "JSON syntax: $Path" 'PASS' 'Valid JSON.'
    } catch {
        Add-CheckResult "JSON syntax: $Path" 'FAIL' $_.Exception.Message
    }
}

function Test-ApexZipPackage {
    param([string]$Path)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
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
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $entries = @($zip.Entries | ForEach-Object FullName)
        $missing = @($required | Where-Object { $_ -notin $entries })
        $entryCount = $entries.Count
        $zip.Dispose()
        if ($missing.Count -gt 0) {
            Add-CheckResult "ZIP package: $Path" 'FAIL' "Missing required entries: $($missing -join ', ')"
        } elseif ($entryCount -lt 10) {
            Add-CheckResult "ZIP package: $Path" 'WARN' "Only $entryCount entries found."
        } else {
            Add-CheckResult "ZIP package: $Path" 'PASS' "Valid ZIP with $entryCount entries."
        }
    } catch {
        Add-CheckResult "ZIP package: $Path" 'FAIL' $_.Exception.Message
    }
}

$sourceDir = Join-Path $RepoRoot 'source'
if (Test-Path -LiteralPath $sourceDir) {
    Add-CheckResult 'source directory' 'PASS' 'source/ exists.'
} elseif ($RequireSource) {
    Add-CheckResult 'source directory' 'FAIL' 'source/ is required for release validation. Run tools/Extract-LatestPackage.ps1 -Clean first.'
} else {
    Add-CheckResult 'source directory' 'WARN' 'source/ is not present yet. Extraction is required before source-first edits.'
}

Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter '*.ps1' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\.git\\' } |
    ForEach-Object { Test-ApexPowerShellSyntax $_.FullName }

Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\.git\\' } |
    ForEach-Object { Test-ApexJsonSyntax $_.FullName }

$packages = @(Get-ChildItem -LiteralPath $RepoRoot -File -Filter 'ApexTune-v*.zip' -ErrorAction SilentlyContinue)
if ($packages.Count -eq 0) {
    Add-CheckResult 'stable package' 'WARN' 'No ApexTune-v*.zip package found in repo root.'
} else {
    $latest = $packages | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Test-ApexZipPackage $latest.FullName
    if ($packages.Count -gt 1) {
        Add-CheckResult 'package cleanup' 'WARN' "Found $($packages.Count) packages. Keep only the latest stable package."
    } else {
        Add-CheckResult 'package cleanup' 'PASS' 'Only one stable package found.'
    }
}

$failures = @($results | Where-Object status -eq 'FAIL')
$warnings = @($results | Where-Object status -eq 'WARN')
$summary = [pscustomobject]@{
    checkedAt = (Get-Date).ToString('o')
    total = $results.Count
    failures = $failures.Count
    warnings = $warnings.Count
    results = $results
}

$summary | ConvertTo-Json -Depth 8 | Tee-Object -Variable json | Out-Null
if (-not $NoReportFile) {
    $json | Set-Content -LiteralPath (Join-Path $RepoRoot 'repo-validation.json') -Encoding UTF8
}
$results | Format-Table -AutoSize
if ($failures.Count -gt 0) { throw "ApexTune repository validation failed with $($failures.Count) failure(s)." }
