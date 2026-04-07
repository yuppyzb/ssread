#!/usr/bin/env bash
# ssread installer — adds ssread to PATH
set -euo pipefail

SSREAD_DIR="$(cd "$(dirname "$0")" && pwd)"
SSREAD_BIN="$SSREAD_DIR/ssread"

echo "ssread installer"
echo "──────────────────────────────"

# 1. Make executable
chmod +x "$SSREAD_BIN"
echo "✓ Made ssread executable"

# 2. Detect shell config
SHELL_NAME="$(basename "$SHELL")"
case "$SHELL_NAME" in
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *)    RC_FILE="$HOME/.profile" ;;
esac

# 3. Add to PATH (skip if already present)
EXPORT_LINE="export PATH=\"$SSREAD_DIR:\$PATH\""
if grep -qF "$SSREAD_DIR" "$RC_FILE" 2>/dev/null; then
    echo "✓ PATH already configured in $RC_FILE"
else
    echo "" >> "$RC_FILE"
    echo "# ssread — Claude session reader" >> "$RC_FILE"
    echo "$EXPORT_LINE" >> "$RC_FILE"
    echo "✓ Added to PATH in $RC_FILE"
fi

echo ""
echo "Done! Run the following to use ssread immediately:"
echo ""
echo "  source $RC_FILE && ssread"
echo ""
