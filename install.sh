#!/usr/bin/env bash
set -e

INSTALL_DIR="${HOME}/git/fractal"
MARKETPLACE="${HOME}/.claude/marketplace.json"

echo "Installing Fractal..."

# Clone or pull
if [ -d "$INSTALL_DIR" ]; then
  echo "Updating existing install at $INSTALL_DIR"
  git -C "$INSTALL_DIR" pull --quiet
else
  echo "Cloning to $INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone --quiet https://github.com/rmolines/fractal "$INSTALL_DIR"
fi

# Set up marketplace.json
mkdir -p "$(dirname "$MARKETPLACE")"

if [ ! -f "$MARKETPLACE" ]; then
  echo '{"plugins":[{"path":"~/git/fractal"}]}' > "$MARKETPLACE"
  echo "Created $MARKETPLACE"
elif grep -q "fractal" "$MARKETPLACE" 2>/dev/null; then
  echo "Already registered in $MARKETPLACE"
else
  # Add to existing plugins array
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
with open('$MARKETPLACE') as f:
    data = json.load(f)
data.setdefault('plugins', []).append({'path': '~/git/fractal'})
with open('$MARKETPLACE', 'w') as f:
    json.dump(data, f)
"
  else
    # Fallback: simple sed insert before last ]
    sed -i.bak 's/\]$/,{"path":"~\/git\/fractal"}]/' "$MARKETPLACE"
    rm -f "${MARKETPLACE}.bak"
  fi
  echo "Added to $MARKETPLACE"
fi

echo ""
echo "Done. Start a new Claude Code session and run /fractal."
