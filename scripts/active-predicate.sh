#!/usr/bin/env bash
set -euo pipefail

# active-predicate.sh — reads the active node's predicate.md content
# Usage: bash scripts/active-predicate.sh [tree-path]
#   No argument: auto-discovers tree in .fractal/

if [ -n "${1:-}" ]; then
  TREE="${1%/}"
  # Resolve: if no root.md found, try .fractal/ prefix
  if [ ! -f "$TREE/root.md" ] && [ -f ".fractal/$TREE/root.md" ]; then
    TREE=".fractal/$TREE"
  fi
else
  # Auto-discover tree
  # First: check if .fractal/root.md exists → tree root is .fractal itself
  if [ -f ".fractal/root.md" ]; then
    TREE=".fractal"
  else
    FOUND=()
    for rootmd in .fractal/*/root.md; do
      [ -f "$rootmd" ] || continue
      FOUND+=("$(dirname "$rootmd")")
    done
    if [ "${#FOUND[@]}" -gt 1 ]; then
      echo "multiple_trees: true"
      for t in "${FOUND[@]}"; do
        echo "tree: $(basename "$t")"
      done
      exit 2
    fi
    TREE="${FOUND[0]:-}"
    if [ -z "$TREE" ]; then
      echo "ERROR: no tree found in .fractal/"
      exit 0
    fi
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
