#!/usr/bin/env bash
set -euo pipefail

# list-insertion-points.sh — list valid insertion positions for a new predicate node
# Usage: bash scripts/list-insertion-points.sh [tree-path]
#   No argument: auto-discovers tree in .fractal/
#
# Output: one block per valid insertion point, blocks separated by blank line.
# Fields: path, predicate, depth, children, status
# Valid positions: nodes with status pending or candidate (never satisfied or pruned).
# The tree root is always included as a valid insertion point.
# Sorted: root first, then shallowest depth first, then alphabetically.

# ── Auto-discovery (same pattern as fractal-state.sh) ────────────────────────

if [ $# -lt 1 ]; then
  if [ ! -d ".fractal" ]; then
    echo "Error: .fractal directory not found" >&2
    exit 1
  fi
  if [ -f ".fractal/root.md" ]; then
    TREE_PATH=".fractal"
  else
    FOUND=()
    for d in .fractal/*/; do
      [ -f "${d}root.md" ] && FOUND+=("${d%/}")
    done
    if [ "${#FOUND[@]}" -eq 1 ]; then
      TREE_PATH="${FOUND[0]}"
    elif [ "${#FOUND[@]}" -eq 0 ]; then
      echo "Error: no fractal tree found in .fractal/" >&2
      exit 1
    else
      echo "multiple_trees: true"
      for t in "${FOUND[@]}"; do
        echo "tree: $(basename "$t")"
      done
      exit 2
    fi
  fi
else
  TREE_PATH="${1%/}"
  if [ ! -d "$TREE_PATH" ]; then
    if [ -d ".fractal/$TREE_PATH" ]; then
      TREE_PATH=".fractal/$TREE_PATH"
    else
      echo "Error: tree path does not exist: $TREE_PATH (also tried .fractal/$TREE_PATH)" >&2
      exit 1
    fi
  fi
fi

ROOT_MD="$TREE_PATH/root.md"
if [ ! -f "$ROOT_MD" ]; then
  echo "Error: no root.md found in $TREE_PATH" >&2
  exit 1
fi

# ── Helper: extract frontmatter field (same as fractal-state.sh) ─────────────

get_field() {
  local file="$1"
  local field="$2"
  awk '
    /^---/ { if (fm==0) { fm=1; next } else { exit } }
    fm==1 && /^'"$field"':/ {
      sub(/^'"$field"':[[:space:]]*/, "")
      gsub(/^"/, ""); gsub(/"$/, "")
      gsub(/^'"'"'/, ""); gsub(/'"'"'$/, "")
      print
      exit
    }
  ' "$file"
}

# ── Helper: count direct child nodes with predicate.md ───────────────────────

count_children() {
  local dir="$1"
  local count=0
  for child in "$dir"/*/; do
    [ -d "$child" ] && [ -f "${child}predicate.md" ] && count=$((count + 1))
  done
  echo "$count"
}

# ── Collect valid insertion points ───────────────────────────────────────────
# Each entry: "<depth> <rel_path>"
# We'll collect into arrays, then sort and output.

declare -a ENTRIES=()

# Root node — always valid (read status from root.md)
ROOT_PREDICATE="$(get_field "$ROOT_MD" predicate)"
ROOT_STATUS="$(get_field "$ROOT_MD" status)"
ROOT_CHILDREN="$(count_children "$TREE_PATH")"
# Root is always included; record with special marker for sort (depth 0)
ENTRIES+=("0|.|${ROOT_PREDICATE}|${ROOT_CHILDREN}|${ROOT_STATUS:-pending}")

# Traverse all subdirectories recursively
while IFS= read -r -d '' pred_file; do
  node_dir="$(dirname "$pred_file")"
  # Compute relative path from TREE_PATH
  rel_path="${node_dir#$TREE_PATH/}"

  # Skip root itself (already handled above)
  [ "$rel_path" = "$TREE_PATH" ] && continue
  [ "$node_dir" = "$TREE_PATH" ] && continue

  status="$(get_field "$pred_file" status)"

  # Skip satisfied and pruned
  case "$status" in
    satisfied|pruned) continue ;;
  esac

  # Compute depth: number of path segments
  depth="$(echo "$rel_path" | awk -F'/' '{print NF}')"

  predicate="$(get_field "$pred_file" predicate)"
  children="$(count_children "$node_dir")"

  ENTRIES+=("${depth}|${rel_path}|${predicate}|${children}|${status:-pending}")
done < <(find "$TREE_PATH" -mindepth 2 -name "predicate.md" -print0 2>/dev/null | sort -z)

# ── Sort: root first (depth 0), then by depth asc, then alphabetically ───────

# Separate root entry from the rest
ROOT_ENTRY=""
declare -a REST_ENTRIES=()

for entry in "${ENTRIES[@]}"; do
  rel="${entry#*|}"
  rel="${rel%%|*}"
  if [ "$rel" = "." ]; then
    ROOT_ENTRY="$entry"
  else
    REST_ENTRIES+=("$entry")
  fi
done

# Sort REST_ENTRIES by depth then path (field 1 = depth, field 2 = path)
declare -a SORTED_REST=()
if [ "${#REST_ENTRIES[@]}" -gt 0 ]; then
  while IFS= read -r line; do
    SORTED_REST+=("$line")
  done < <(printf '%s\n' "${REST_ENTRIES[@]}" | sort -t'|' -k1,1n -k2,2)
fi

# ── Output ───────────────────────────────────────────────────────────────────

output_entry() {
  local entry="$1"
  IFS='|' read -r depth rel_path predicate children status <<< "$entry"
  echo "path: $rel_path"
  echo "predicate: $predicate"
  echo "depth: $depth"
  echo "children: $children"
  echo "status: $status"
}

PRINTED=false

if [ -n "$ROOT_ENTRY" ]; then
  output_entry "$ROOT_ENTRY"
  PRINTED=true
fi

for entry in "${SORTED_REST[@]}"; do
  if [ "$PRINTED" = true ]; then
    echo ""
  fi
  output_entry "$entry"
  PRINTED=true
done
