#!/usr/bin/env bash
#
# Install local-webhook-master globally.
# Clones to ~/.local-webhook-master and symlinks `tunnel` into /usr/local/bin.
#
#   curl -fsSL https://raw.githubusercontent.com/Sam8r/local-webhook-master/main/install.sh | bash
#
set -euo pipefail

REPO="https://github.com/Sam8r/local-webhook-master.git"
DEST="$HOME/.local-webhook-master"
BIN="/usr/local/bin/tunnel"

echo "Installing local-webhook-master…"

if [ -d "$DEST" ]; then
    echo "  Updating existing clone…"
    git -C "$DEST" pull --quiet
else
    git clone --quiet "$REPO" "$DEST"
fi

chmod +x "$DEST/tunnel.sh"

sudo ln -sf "$DEST/tunnel.sh" "$BIN"

echo "  Installed: $(which tunnel)"
echo "  Run it:    tunnel 8000"
echo "  Done."
