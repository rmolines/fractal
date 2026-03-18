#!/usr/bin/env bash
set -e

INSTALL_DIR="${INSTALL_DIR:-${HOME}/git/fractal}"
MARKETPLACE="${HOME}/.claude/marketplace.json"

# Check prerequisites
if [ ! -d "${HOME}/.claude" ]; then
  echo "Error: ~/.claude/ not found. Install Claude Code first: https://claude.ai/code"
  exit 1
fi

echo "Installing Fractal Loop to $INSTALL_DIR..."

# Clone or pull
if [ -d "$INSTALL_DIR" ]; then
  echo "Updating existing install at $INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --quiet
else
  echo "Cloning to $INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone --quiet https://github.com/rmolines/fractal "$INSTALL_DIR"
fi

# Resolve path for marketplace (replace $HOME with ~)
PLUGIN_PATH="${INSTALL_DIR/#$HOME/\~}"

# Set up marketplace.json
mkdir -p "$(dirname "$MARKETPLACE")"

if [ ! -f "$MARKETPLACE" ]; then
  echo "{\"plugins\":[{\"path\":\"$PLUGIN_PATH\"}]}" > "$MARKETPLACE"
  echo "Created $MARKETPLACE"
elif grep -q "fractal" "$MARKETPLACE" 2>/dev/null; then
  echo "Already registered in $MARKETPLACE"
else
  # Add to existing plugins array
  if command -v python3 &>/dev/null; then
    python3 -c "
import json
with open('$MARKETPLACE') as f:
    data = json.load(f)
data.setdefault('plugins', []).append({'path': '$PLUGIN_PATH'})
with open('$MARKETPLACE', 'w') as f:
    json.dump(data, f)
"
  else
    echo "Error: python3 required to update marketplace.json. Add manually:"
    echo "  {\"path\":\"$PLUGIN_PATH\"} to $MARKETPLACE"
    exit 1
  fi
  echo "Added to $MARKETPLACE"
fi

echo ""
echo "Done. Start a new Claude Code session and run /fractal:run in any repo."
