<#
.SYNOPSIS
  Install local-webhook-master globally on Windows.
.DESCRIPTION
  Clones to %USERPROFILE%\.local-webhook-master and symlinks tunnel.ps1
  into a directory on PATH.
.EXAMPLE
  irm https://raw.githubusercontent.com/Sam8r/local-webhook-master/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$Dest = "$env:USERPROFILE\.local-webhook-master"
$BinDir = "$env:USERPROFILE\bin"
$ScriptSrc = "$Dest\tunnel.ps1"
$ScriptDst = "$BinDir\tunnel.ps1"
$BatDst = "$BinDir\tunnel.bat"

Write-Host "Installing local-webhook-master…" -ForegroundColor Cyan

# ── Clone or update ─────────────────────────────────────────
if (Test-Path $Dest) {
    Write-Host "  Updating existing clone…"
    Push-Location $Dest
    git pull --quiet
    Pop-Location
} else {
    git clone --quiet "https://github.com/Sam8r/local-webhook-master.git" $Dest
}

# ── Install dir on PATH ─────────────────────────────────────
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

# Copy script
Copy-Item -Path $ScriptSrc -Destination $ScriptDst -Force

# Create a .bat wrapper so `tunnel` works from cmd too
@"
@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0tunnel.ps1" %*
"@ | Out-File -FilePath $BatDst -Encoding ASCII

# Add to user PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$BinDir;$userPath", "User")
    $env:PATH = "$BinDir;$env:PATH"
    Write-Host "  Added $BinDir to PATH (restart terminal to pick up)."
}

# ── Pre-download cloudflared ────────────────────────────────
$cfPath = "$Dest\cloudflared.exe"
if (-not (Test-Path $cfPath)) {
    Write-Host "  Pre-downloading cloudflared…"
    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
    $dlUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$arch.exe"
    Invoke-WebRequest -Uri $dlUrl -OutFile $cfPath -UseBasicParsing
}

Write-Host ""
Write-Host "  ✅ Installed." -ForegroundColor Green
Write-Host "  Open a NEW terminal, then run:  tunnel 8000" -ForegroundColor Green
