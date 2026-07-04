# local-webhook-master

Expose any local port to the internet in one command. Get an instant HTTPS URL for webhooks, API testing, and sharing work-in-progress — no account, no config, no nginx.

Powered by [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) (free, no signup required).

## Quick start

```bash
git clone https://github.com/Sam8r/local-webhook-master.git
cd local-webhook-master
chmod +x tunnel.sh
./tunnel.sh
```

```
Which port(s) should I expose? (space-separated, Enter = 8000)
> 8000

════════════════════════════════════════════════════════════
  ✅  1 tunnel(s) live

  :8000  →  https://random-words-here.trycloudflare.com

  Logs:   tail -f /tmp/cloudflared-tunnel-*.log
  Stop:   Ctrl+C
════════════════════════════════════════════════════════════
```

`Ctrl+C` stops all tunnels.

## Install (one-liner)

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/Sam8r/local-webhook-master/main/install.sh | bash
```

This clones the repo to `~/.local-webhook-master`, symlinks `tunnel` into `/usr/local/bin`, and installs `cloudflared` on first run.

After install, run from anywhere:

```bash
tunnel 8000
```

## Usage

```bash
tunnel                  # prompts for port(s), Enter = 8000
tunnel 8000             # single port
tunnel 8000 5173 8080   # multiple ports — each gets its own URL
```

## How it works

1. Checks for `cloudflared` — installs it automatically if missing (macOS + Linux, Intel + ARM)
2. Spawns a Cloudflare quick tunnel per port
3. Waits for each URL, prints them
4. `Ctrl+C` cleanly kills everything

No Cloudflare account, domain, or config file needed. URLs are random and temporary — they change on each run.

## Requirements

- macOS or Linux
- A local server running on the port(s) you want to expose

## License

MIT
