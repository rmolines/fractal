#!/usr/bin/env bash
set -euo pipefail

# select-next-node.sh — traverse fractal tree and return highest-priority pending node
# Usage: bash scripts/select-next-node.sh [tree-path]
#   No argument: auto-discovers the single tree in .fractal/
#
# Priority: leaf-like pending nodes (no pending children) > deepest first > alphabetical

if [ $# -lt 1 ]; then
  # Auto-discover single tree in .fractal/
  if [ ! -d ".fractal" ]; then
    echo "error: .fractal directory not found" >&2
    exit 1
  fi
  # First: check if .fractal/root.md exists → tree root is .fractal itself
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
      echo "error: no tree found in .fractal/" >&2
      exit 1
    else
      echo "Error: multiple trees found in .fractal/ — run /fractal:doctor" >&2
      exit 1
    fi
  fi
else
  TREE_PATH="${1%/}"  # strip trailing slash

  # Resolve: if not a directory, try .fractal/ prefix
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

# Helper: extract a frontmatter field from a file
# Usage: get_field <file> <field>
get_field() {
  local file="$1"
  local field="$2"
  # Extract value between --- markers, find the field, strip quotes
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

# ── Collect all pending nodes ─────────────────────────────────────────────────

# Arrays to hold relative paths of pending nodes
PENDING_NODES=()

# Find all predicate.md files, skip _orphans/
while IFS= read -r pred_file; do
  # Get relative path from tree root
  rel_dir="${pred_file#$TREE_PATH/}"
  rel_dir="$(dirname "$rel_dir")"

  # Skip _orphans directory
  case "$rel_dir" in
    _orphans|_orphans/*) continue ;;
  esac

  # Skip the root itself (root.md, not predicate.md)
  # predicate.md files are only in subdirectories
  status="$(get_field "$pred_file" status)"

  if [ "$status" = "pending" ]; then
    PENDING_NODES+=("$rel_dir")
  fi
done < <(find "$TREE_PATH" -name "predicate.md" -not -path "*/_orphans/*" | sort)

PENDING_COUNT="${#PENDING_NODES[@]}"

if [ "$PENDING_COUNT" -eq 0 ]; then
  echo "selected_node: none"
  echo "selected_predicate: none"
  echo "pending_count: 0"
  echo "leaf_pending_count: 0"
  exit 0
fi

# ── Identify leaf-like pending nodes ─────────────────────────────────────────
# A leaf-like pending node has NO pending children

LEAF_PENDING_NODES=()

for node_rel in "${PENDING_NODES[@]}"; do
  node_dir="$TREE_PATH/$node_rel"
  has_pending_child=false

  # Check direct and nested children for any pending predicate.md
  while IFS= read -r child_pred; do
    child_rel_dir="${child_pred#$TREE_PATH/}"
    child_rel_dir="$(dirname "$child_rel_dir")"

    # Must be a child (not the node itself)
    if [ "$child_rel_dir" = "$node_rel" ]; then
      continue
    fi

    child_status="$(get_field "$child_pred" status)"
    if [ "$child_status" = "pending" ]; then
      has_pending_child=true
      break
    fi
  done < <(find "$node_dir" -name "predicate.md" -not -path "*/_orphans/*" | sort)

  if [ "$has_pending_child" = false ]; then
    LEAF_PENDING_NODES+=("$node_rel")
  fi
done

LEAF_PENDING_COUNT="${#LEAF_PENDING_NODES[@]}"

# ── Select deepest leaf-like pending node (alphabetical tiebreak) ─────────────

SELECTED_NODE=""
SELECTED_DEPTH=-1

for node_rel in "${LEAF_PENDING_NODES[@]}"; do
  # Depth = number of path segments
  depth="$(echo "$node_rel" | awk -F'/' '{print NF}')"

  if [ "$depth" -gt "$SELECTED_DEPTH" ]; then
    SELECTED_DEPTH="$depth"
    SELECTED_NODE="$node_rel"
  elif [ "$depth" -eq "$SELECTED_DEPTH" ]; then
    # Alphabetical tiebreak: pick the earlier one
    if [[ "$node_rel" < "$SELECTED_NODE" ]]; then
      SELECTED_NODE="$node_rel"
    fi
  fi
done

# If no leaf-like nodes found (shouldn't happen since we have pending nodes),
# fall back to deepest pending node
if [ -z "$SELECTED_NODE" ]; then
  for node_rel in "${PENDING_NODES[@]}"; do
    depth="$(echo "$node_rel" | awk -F'/' '{print NF}')"
    if [ "$depth" -gt "$SELECTED_DEPTH" ]; then
      SELECTED_DEPTH="$depth"
      SELECTED_NODE="$node_rel"
    elif [ "$depth" -eq "$SELECTED_DEPTH" ]; then
      if [[ "$node_rel" < "$SELECTED_NODE" ]]; then
        SELECTED_NODE="$node_rel"
      fi
    fi
  done
fi

# ── Read selected predicate text ──────────────────────────────────────────────

SELECTED_PREDICATE=""
if [ -n "$SELECTED_NODE" ]; then
  sel_pred_file="$TREE_PATH/$SELECTED_NODE/predicate.md"
  if [ -f "$sel_pred_file" ]; then
    SELECTED_PREDICATE="$(get_field "$sel_pred_file" predicate)"
  fi
fi

# ── Output ────────────────────────────────────────────────────────────────────

echo "selected_node: $SELECTED_NODE"
echo "selected_predicate: $SELECTED_PREDICATE"
echo "pending_count: $PENDING_COUNT"
echo "leaf_pending_count: $LEAF_PENDING_COUNT"
