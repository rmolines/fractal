#!/usr/bin/env bash
set -euo pipefail

# active-predicate.sh — reads the active node's predicate.md content
# Usage: bash scripts/active-predicate.sh [tree-path]
#   No argument: auto-discovers the single tree in .fractal/

if [ -n "${1:-}" ]; then
  TREE="${1%/}"
  # Resolve: if no root.md found, try .fractal/ prefix
  if [ ! -f "$TREE/root.md" ] && [ -f ".fractal/$TREE/root.md" ]; then
    TREE=".fractal/$TREE"
  fi
else
  # Auto-discover single tree
  TREE=""
  for rootmd in .fractal/*/root.md; do
    [ -f "$rootmd" ] || continue
    if [ -z "$TREE" ]; then
      TREE="$(dirname "$rootmd")"
    else
      echo "ERROR: multiple trees in .fractal/ — run /fractal:doctor"
      exit 0
    fi
  done
  if [ -z "$TREE" ]; then
    echo "ERROR: no tree found in .fractal/"
    exit 0
  fi
fi

if [ ! -f "$TREE/root.md" ]; then
  echo "ERROR: no root.md at $TREE"
  exit 0
fi

AN=$(grep "^active_node:" "$TREE/root.md" 2>/dev/null | sed 's/^active_node:[[:space:]]*//' | tr -d "\"'" | head -1)

if [ -z "$AN" ] || [ "$AN" = "." ]; then
  cat "$TREE/root.md"
else
  if [ -f "$TREE/$AN/predicate.md" ]; then
    cat "$TREE/$AN/predicate.md"
  else
    echo "ERROR: no predicate.md at $TREE/$AN"
  fi
fi
