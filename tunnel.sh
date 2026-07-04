#!/usr/bin/env bash
#
# Expose one or more local ports to the internet via Cloudflare Tunnels.
# Prints the live URL(s). Press Ctrl+C to stop all tunnels.
#
#   tunnel.sh              # interactive prompt
#   tunnel.sh 8000         # direct: single port
#   tunnel.sh 8000 5173    # direct: multiple ports
#
set -euo pipefail

# ── Resolve ports ───────────────────────────────────────────
if [ $# -gt 0 ]; then
    PORTS=("$@")
else
    echo "Which port(s) should I expose? (space-separated, Enter = 8000)"
    read -r -e input
    if [ -z "$input" ]; then
        PORTS=(8000)
    else
        read -r -a PORTS <<< "$input"
    fi
fi

# ── Install cloudflared if missing ──────────────────────────
if ! command -v cloudflared &>/dev/null; then
    echo "Installing cloudflared…"
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)          CFARCH="amd64" ;;
        arm64|aarch64)   CFARCH="arm64" ;;
        *) echo "Unsupported arch: $ARCH"; exit 1 ;;
    esac

    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$OS" in
        darwin)  CFOS="darwin" ;;
        linux)   CFOS="linux" ;;
        *) echo "Unsupported OS: $OS"; exit 1 ;;
    esac

    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${CFOS}-${CFARCH}"
    if [ "$CFOS" = "darwin" ]; then URL="${URL}.tgz"; fi

    TMP="/tmp/cloudflared-download"
    curl -sL -o "$TMP" "$URL"

    if [ "$CFOS" = "darwin" ]; then
        sudo tar -xzf "$TMP" -C /usr/local/bin/
        sudo chmod +x /usr/local/bin/cloudflared
    else
        sudo install "$TMP" /usr/local/bin/cloudflared
    fi
    rm -f "$TMP"
    echo "cloudflared installed."
fi

# ── Launch tunnels ──────────────────────────────────────────
PIDS=()
URLS=()

cleanup() {
    echo ""
    echo "Stopping ${#PIDS[@]} tunnel(s)…"
    for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
    exit 0
}
trap cleanup INT TERM EXIT

for port in "${PORTS[@]}"; do
    LOG="/tmp/cloudflared-tunnel-${port}.log"
    : > "$LOG"

    cloudflared tunnel --url "http://localhost:${port}" >"$LOG" 2>&1 &
    PIDS+=($!)

    URL=""
    for i in $(seq 1 20); do
        sleep 1
        URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG" 2>/dev/null | head -1 || true)
        [ -n "$URL" ] && break
    done

    if [ -z "$URL" ]; then
        echo "  Failed to tunnel port ${port}. Check ${LOG}"
        continue
    fi

    URLS+=("${port}|${URL}")
done

if [ ${#URLS[@]} -eq 0 ]; then
    echo "No tunnels established. Exiting."
    exit 1
fi

# ── Print results ───────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅  ${#URLS[@]} tunnel(s) live"
echo ""
for entry in "${URLS[@]}"; do
    IFS='|' read -r port url <<< "$entry"
    echo "  :${port}  →  ${url}"
done
echo ""
echo "  Logs:   tail -f /tmp/cloudflared-tunnel-*.log"
echo "  Stop:   Ctrl+C"
echo "════════════════════════════════════════════════════════════"
echo ""

# Keep alive
for pid in "${PIDS[@]}"; do wait "$pid" 2>/dev/null || true; done
