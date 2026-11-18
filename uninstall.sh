#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="me.muriloscolari.darmoshark"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
TARGET_DIR="$DATA_DIR/plasma/plasmoids/$PLASMOID_ID"

if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet -r "$PLASMOID_ID" >/dev/null 2>&1 || true
fi

if [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
    echo "[OK] Widget removido de $TARGET_DIR"
else
    echo "Widget $PLASMOID_ID não estava instalado em $TARGET_DIR"
fi

echo "Se o widget ainda estiver visível no painel, reinicie o shell com:"
echo "  systemctl --user restart plasma-plasmashell.service"
