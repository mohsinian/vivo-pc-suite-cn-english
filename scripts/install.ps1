# Vivo PC Suite 7.0.6 (CN) - English patch installer
# Run as Administrator:  right-click -> Run with PowerShell (as admin)
# Or:  powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# Expects the release files in the SAME folder as this script:
#   app.asar       (translated main archive, ~365 MB)
#   app_vc.asar    (translated vivoControl archive, ~48 MB)
#
# What it does:
#   1. finds the vivo PC Suite install folder (Windows records, then defaults)
#   2. closes running vivo processes
#   3. backs up originals next to themselves with a .old extension (first run only)
#   4. installs the two translated .asar files (hash-checked copy)
#   5. switches the Phone Mirroring window (vivoScreen.exe) to English
#   6. sets %APPDATA%\pcsuite\config.ini to 1033 / en_US
#   7. restarts vivo PC Suite
#
# Restore: re-run with -Restore  (puts the .old backups back)

param([switch]$Restore)
$ErrorActionPreference = 'Stop'

function Find-InstallRoot {
    # 1) Windows uninstall records
    $keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
              'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')
    foreach ($k in $keys) {
        $item = Get-ItemProperty $k -ErrorAction SilentlyContinue |
            Where-Object { $_.UninstallString -match 'pcsuite\\uninst\.exe' } |
            Select-Object -First 1
        if ($item) {
            $root = Split-Path ($item.UninstallString -replace '"', '')
            if (Test-Path (Join-Path $root 'resources\app.asar')) { return $root }
        }
    }
    # 2) well-known folders
    foreach ($c in @("${env:ProgramFiles(x86)}\pcsuite", 'C:\Program Files (x86)\pcsuite', "$env:ProgramFiles\vivo\pcsuite")) {
        if (Test-Path (Join-Path $c 'resources\app.asar')) { return $c }
    }
    return $null
}

function Backup-File($path) {
    $bak = "$path.old"
    if ((Test-Path $path) -and -not (Test-Path $bak)) {
        Copy-Item $path $bak
        Write-Host "  backup: $bak"
    }
}

function Close-Vivo {
    foreach ($p in @('pcsuite.exe','pcsuite_.exe','vivoScreen.exe','pc_toast.exe')) {
        Get-Process -Name $p -ErrorAction SilentlyContinue | ForEach-Object {
            $_.CloseMainWindow() | Out-Null
        }
    }
    Start-Sleep -Seconds 2
    foreach ($p in @('pcsuite.exe','pcsuite_.exe','vivoScreen.exe','pc_toast.exe')) {
        Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    Start-Sleep -Seconds 1
}

# admin check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Please run this script as Administrator (right-click -> Run as administrator).' }

$root = Find-InstallRoot
if (-not $root) { throw 'Could not find the vivo PC Suite install folder.' }
Write-Host "Install folder: $root"

$asar   = Join-Path $root 'resources\app.asar'
$vcAsar = Join-Path $root 'vivoControl\resources\app.asar'
$screen = Join-Path $root 'vivoScreen\vivoScreen.exe'
$here   = $PSScriptRoot
$newMain = Join-Path $here 'app.asar'
$newVc   = Join-Path $here 'app_vc.asar'
$config  = Join-Path $env:APPDATA 'pcsuite\config.ini'

if ($Restore) {
    Close-Vivo
    foreach ($pair in @(@($asar), @($vcAsar), @($screen))) {
        $bak = "$pair.old"
        if (Test-Path $bak) {
            Copy-Item $bak $pair -Force
            Write-Host "restored: $pair"
        } else {
            Write-Host "no backup for: $pair"
        }
    }
    if (Test-Path "$config.old") {
        Copy-Item "$config.old" $config -Force
        Write-Host "restored: $config"
    }
    Start-Process (Join-Path $root 'pcsuite.exe')
    Write-Host 'RESTORE COMPLETE'
    exit 0
}

# release assets present?
foreach ($f in @($newMain, $newVc)) {
    if (-not (Test-Path $f)) { throw "Missing release file: $f (keep it next to install.ps1)" }
}

Close-Vivo

# backups
Backup-File $asar
Backup-File $vcAsar
Backup-File $screen
if (Test-Path $config) { Backup-File $config }

# install translated asars (hash-verified copy)
foreach ($pair in @(@($newMain,$asar), @($newVc,$vcAsar))) {
    $from, $to = $pair
    Copy-Item $from $to -Force
    $h1 = (Get-FileHash $from -Algorithm SHA256).Hash
    $h2 = (Get-FileHash $to   -Algorithm SHA256).Hash
    if ($h1 -ne $h2) { throw "hash mismatch after copy: $to" }
    Write-Host "installed: $to"
}

# vivoScreen.exe locale flip (single 'zh-CN' occurrence next to LanguageManager marker)
$data = [System.IO.File]::ReadAllBytes($screen)
$s    = [System.Text.Encoding]::ASCII.GetString($data)
$old  = "zh-CN" + [char]0 + [char]0 + [char]0 + "en-US"
$new  = "en-US" + [char]0 + [char]0 + [char]0 + "en-US"
if ($s.Contains($new)) {
    Write-Host 'vivoScreen.exe: already English'
} elseif (($s.Split($old).Count - 1) -eq 1) {
    $idx = $s.IndexOf($old)
    $marker = [System.Text.Encoding]::ASCII.GetBytes('LanguageManager')
    $window = $s.Substring([Math]::Max(0, $idx - 120), [Math]::Min(120, $idx))
    if (-not $window.Contains('LanguageManager')) { throw 'vivoScreen.exe: LanguageManager marker missing, aborting' }
    [Array]::Copy([System.Text.Encoding]::ASCII.GetBytes($new), 0, $data, $idx, $new.Length)
    [System.IO.File]::WriteAllBytes($screen, $data)
    Write-Host 'vivoScreen.exe: switched to en-US'
} else {
    Write-Warning 'vivoScreen.exe: unexpected build (zh-CN count <> 1) - left untouched'
}

# config.ini language
if (Test-Path $config) {
    $txt = Get-Content $config -Raw -Encoding UTF8
    $txt = $txt -replace 'LanguageID=2052', 'LanguageID=1033' -replace 'LanguageTag=zh_CN', 'LanguageTag=en_US'
    Set-Content $config $txt -Encoding UTF8 -NoNewline
    Write-Host 'config.ini: set to 1033 / en_US'
}

Write-Host 'PATCH COMPLETE - starting vivo PC Suite...'
Start-Process (Join-Path $root 'pcsuite.exe')
