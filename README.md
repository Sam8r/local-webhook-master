# local-webhook-master

Expose any local port to the internet in one command. Get an instant HTTPS URL for webhooks, API testing, and sharing work-in-progress — no account, no config, no nginx.

Powered by [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) (free, no signup required).

Works on **macOS**, **Linux**, and **Windows**.

## Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/Sam8r/local-webhook-master/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/Sam8r/local-webhook-master/main/install.ps1 | iex
```

Open a **new terminal** after install, then:

```bash
tunnel 8000
```

### Manual (no install)

```bash
git clone https://github.com/Sam8r/local-webhook-master.git
cd local-webhook-master

# macOS / Linux
chmod +x tunnel.sh && ./tunnel.sh

# Windows
powershell -ExecutionPolicy Bypass -File tunnel.ps1
```

## Usage

```bash
tunnel                  # prompts for port(s), Enter = 8000
tunnel 8000             # single port
tunnel 8000 5173 8080   # multiple ports — each gets its own URL
```

```
Which port(s) should I expose? (space-separated, Enter = 8000)
> 8000 5173

════════════════════════════════════════════════════════════
  ✅  2 tunnel(s) live

  :8000  →  https://random-words-here.trycloudflare.com
  :5173  →  https://different-words-there.trycloudflare.com

  Stop:   Ctrl+C
════════════════════════════════════════════════════════════
```

`Ctrl+C` stops all tunnels.

## How it works

1. Checks for `cloudflared` — installs it automatically if missing
2. Spawns a Cloudflare quick tunnel per port
3. Waits for each URL, prints them
4. `Ctrl+C` cleanly kills everything

No Cloudflare account, domain, or config file needed. URLs are random and temporary — they change on each run.

## Requirements

- macOS, Linux, or Windows
- A local server running on the port(s) you want to expose

## License

MIT
