# ============================================================
# Meridian — Fetch Libraries
# Downloads all required Ace3 / LDB / LibDBIcon libs into libs/
# Run once, or whenever you want to update libs.
# Usage: .\scripts\fetch-libs.ps1
# ============================================================

$ErrorActionPreference = "Stop"
$rootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$libsDir = Join-Path $rootDir "libs"

Write-Host "`n=== Meridian — Fetching Libraries ===" -ForegroundColor Cyan

# ============================================================
# SVN externals (same as .pkgmeta)
# ============================================================
$externals = @(
    @{ Dir = "LibStub";              Url = "https://repos.wowace.com/wow/libstub/trunk" },
    @{ Dir = "CallbackHandler-1.0";  Url = "https://repos.wowace.com/wow/callbackhandler/trunk/CallbackHandler-1.0" },
    @{ Dir = "AceAddon-3.0";         Url = "https://repos.wowace.com/wow/ace3/trunk/AceAddon-3.0" },
    @{ Dir = "AceConsole-3.0";       Url = "https://repos.wowace.com/wow/ace3/trunk/AceConsole-3.0" },
    @{ Dir = "AceEvent-3.0";         Url = "https://repos.wowace.com/wow/ace3/trunk/AceEvent-3.0" },
    @{ Dir = "AceDB-3.0";            Url = "https://repos.wowace.com/wow/ace3/trunk/AceDB-3.0" },
    @{ Dir = "AceTimer-3.0";         Url = "https://repos.wowace.com/wow/ace3/trunk/AceTimer-3.0" },
    @{ Dir = "LibDataBroker-1.1";    Url = "https://repos.wowace.com/wow/libdatabroker-1-1/trunk" },
    @{ Dir = "LibDBIcon-1.0";        Url = "https://repos.wowace.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0" }
)

# ============================================================
# Check for SVN
# ============================================================
$hasSvn = $null -ne (Get-Command "svn" -ErrorAction SilentlyContinue)

if (-not $hasSvn) {
    Write-Host "`n[!] 'svn' not found. Installing via winget..." -ForegroundColor Yellow
    $hasWinget = $null -ne (Get-Command "winget" -ErrorAction SilentlyContinue)

    if ($hasWinget) {
        Write-Host "    Installing TortoiseSVN (includes svn CLI)..."
        winget install --id TortoiseSVN.TortoiseSVN --accept-package-agreements --accept-source-agreements --silent 2>$null

        # Add SVN to PATH for this session
        $svnPath = "C:\Program Files\TortoiseSVN\bin"
        if (Test-Path $svnPath) {
            $env:PATH = "$svnPath;$env:PATH"
            $hasSvn = $true
            Write-Host "    [OK] SVN installed and available." -ForegroundColor Green
        }
    }

    if (-not $hasSvn) {
        Write-Host @"

    SVN is required to fetch libs from repos.wowace.com.
    Install one of:
      - TortoiseSVN: https://tortoisesvn.net/downloads.html
        (check 'command line client tools' during install)
      - winget install TortoiseSVN.TortoiseSVN
      - choco install tortoisesvn

    Then re-run this script.
"@ -ForegroundColor Red
        exit 1
    }
}

# ============================================================
# Fetch each lib via svn export
# ============================================================
if (-not (Test-Path $libsDir)) {
    New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
}

$success = 0
$failed = 0

foreach ($ext in $externals) {
    $dest = Join-Path $libsDir $ext.Dir
    Write-Host "`n  Fetching $($ext.Dir)..." -NoNewline

    # Clean existing if present
    if (Test-Path $dest) {
        Remove-Item -Recurse -Force $dest
    }

    try {
        svn export --quiet $ext.Url $dest 2>&1 | Out-Null
        Write-Host " OK" -ForegroundColor Green
        $success++
    } catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkRed
        $failed++
    }
}

# ============================================================
# Summary
# ============================================================
Write-Host "`n=== Done: $success OK, $failed failed ===" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })

if ($failed -eq 0) {
    Write-Host "libs/ is ready. Copy the Meridian folder into your WoW AddOns directory." -ForegroundColor Gray
    Write-Host "  e.g. World of Warcraft\_retail_\Interface\AddOns\Meridian" -ForegroundColor DarkGray
}
