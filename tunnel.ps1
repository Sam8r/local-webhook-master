#Requires -Version 5.1
<#
.SYNOPSIS
  Expose one or more local ports to the internet via Cloudflare Tunnels.
.DESCRIPTION
  tunnel.ps1                 # interactive prompt
  tunnel.ps1 8000            # single port
  tunnel.ps1 8000 5173 8080  # multiple ports
#>

param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [int[]]$Ports
)

$ErrorActionPreference = "Stop"

# ── Resolve ports ───────────────────────────────────────────
if (-not $Ports -or $Ports.Count -eq 0) {
    $raw = Read-Host "Which port(s) should I expose? (space-separated, Enter = 8000)"
    if ([string]::IsNullOrWhiteSpace($raw)) {
        $Ports = @(8000)
    } else {
        $Ports = $raw.Trim() -split '\s+' | ForEach-Object { [int]$_ }
    }
}

# ── Install cloudflared if missing ──────────────────────────
$cfExe = "cloudflared"
if (Get-Command cloudflared -ErrorAction SilentlyContinue) {
    # already on PATH
} elseif (Test-Path "$env:USERPROFILE\.local-webhook-master\cloudflared.exe") {
    $cfExe = "$env:USERPROFILE\.local-webhook-master\cloudflared.exe"
} else {
    Write-Host "Installing cloudflared…" -ForegroundColor Yellow

    # Try winget first
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        & winget install --id cloudflare.cloudflared --accept-source-agreements --accept-package-agreements 2>$null
    }

    # Fallback: direct download
    if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
        $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
        $dlUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$arch.exe"
        $dlPath = "$env:USERPROFILE\.local-webhook-master\cloudflared.exe"

        New-Item -ItemType Directory -Force -Path (Split-Path $dlPath) | Out-Null
        Invoke-WebRequest -Uri $dlUrl -OutFile $dlPath -UseBasicParsing
        $cfExe = $dlPath
    }

    Write-Host "cloudflared installed." -ForegroundColor Green
}

# ── Launch tunnels ──────────────────────────────────────────
$jobs = @()
$results = @()

# Ctrl+C handler
$null = Register-EngineEvent PowerShell.Exiting -Action {
    foreach ($j in $script:jobs) {
        if ($j.Process -and -not $j.Process.HasExited) {
            $j.Process.Kill()
        }
    }
}

foreach ($port in $Ports) {
    $logFile = [System.IO.Path]::GetTempFileName()

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $cfExe
    $psi.Arguments = "tunnel --url http://localhost:$port"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    $logBuilder = New-Object System.Text.StringBuilder

    $errHandler = {
        if ($EventArgs.Data) {
            [void]$Event.MessageData.AppendLine($EventArgs.Data)
            if ($EventArgs.Data -match 'https://[a-z0-9-]+\.trycloudflare\.com') {
                $script:urlFound = $Matches[0]
            }
        }
    }

    $script:urlFound = $null
    Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action $errHandler -MessageData $logBuilder | Out-Null
    Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $errHandler -MessageData $logBuilder | Out-Null

    $proc.Start() | Out-Null
    $proc.BeginErrorRead()
    $proc.BeginOutputRead()

    $jobs += [PSCustomObject]@{ Process = $proc; Port = $port; Log = $logFile; LogBuilder = $logBuilder }

    # Wait for URL
    $url = $null
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Seconds 1
        $content = $logBuilder.ToString()
        if ($content -match 'https://[a-z0-9-]+\.trycloudflare\.com') {
            $url = $Matches[0]
            break
        }
    }

    if ($url) {
        $results += [PSCustomObject]@{ Port = $port; Url = $url }
    } else {
        Write-Host "  Failed to tunnel port $port." -ForegroundColor Red
    }

    # Save log
    $logBuilder.ToString() | Out-File -FilePath $logFile -Encoding UTF8
}

if ($results.Count -eq 0) {
    Write-Host "No tunnels established. Exiting." -ForegroundColor Red
    exit 1
}

# ── Print results ───────────────────────────────────────────
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✅  $($results.Count) tunnel(s) live" -ForegroundColor Green
Write-Host ""
foreach ($r in $results) {
    Write-Host "  :$($r.Port)  →  $($r.Url)"
}
Write-Host ""
Write-Host "  Stop:   Ctrl+C" -ForegroundColor DarkGray
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Keep alive until Ctrl+C
try {
    while ($true) {
        Start-Sleep -Seconds 1
        # Check if any process exited
        foreach ($j in $jobs) {
            if ($j.Process.HasExited) {
                Write-Host "Tunnel for port $($j.Port) exited." -ForegroundColor Yellow
            }
        }
    }
} finally {
    foreach ($j in $jobs) {
        if ($j.Process -and -not $j.Process.HasExited) {
            $j.Process.Kill()
        }
    }
    Write-Host "All tunnels stopped." -ForegroundColor Yellow
}
