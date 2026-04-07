#!/usr/bin/env bash
# ssread installer — adds ssread to PATH
set -euo pipefail

SSREAD_DIR="$(cd "$(dirname "$0")" && pwd)"
SSREAD_BIN="$SSREAD_DIR/ssread"

echo "ssread installer"
echo "──────────────────────────────"

# 1. Check dependencies
missing=()
command -v jq &>/dev/null || missing+=("jq")
command -v tmux &>/dev/null || missing+=("tmux")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "⚠ Missing dependencies: ${missing[*]}"
    echo "  brew install ${missing[*]}  (macOS)"
    echo "  apt install ${missing[*]}   (Ubuntu/Debian)"
    echo ""
fi

# 2. Make executable
chmod +x "$SSREAD_BIN"
echo "✓ Made ssread executable"

# 3. Detect shell config
SHELL_NAME="$(basename "$SHELL")"
case "$SHELL_NAME" in
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *)    RC_FILE="$HOME/.profile" ;;
esac

# 4. Add to PATH (skip if already present)
EXPORT_LINE="export PATH=\"$SSREAD_DIR:\$PATH\""
if grep -qF "$SSREAD_DIR" "$RC_FILE" 2>/dev/null; then
    echo "✓ PATH already configured in $RC_FILE"
else
    echo "" >> "$RC_FILE"
    echo "# ssread — Claude session manager" >> "$RC_FILE"
    echo "$EXPORT_LINE" >> "$RC_FILE"
    echo "✓ Added to PATH in $RC_FILE"
fi

echo ""
echo "Done! Run the following to start:"
echo ""
echo "  source $RC_FILE && ssread"
echo ""
echo "ssread will automatically create a tmux session for parallel session management."
echo "Use Ctrl-b 0 to return to the session list from any claude window."
echo ""
