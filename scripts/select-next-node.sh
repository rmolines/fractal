#!/usr/bin/env bash
set -euo pipefail

# select-next-node.sh — traverse fractal tree and return highest-priority pending node
# Usage: bash scripts/select-next-node.sh [tree-path]
#   No argument: auto-discovers the single tree in .fractal/
#
# Priority: leaf-like pending nodes (no pending children) > deepest first > alphabetical

if [ $# -lt 1 ]; then
  if [ ! -d ".fractal" ]; then
    echo "error: .fractal directory not found" >&2
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
      echo "error: no tree found in .fractal/" >&2
      exit 1
    else
      echo "Error: multiple trees found in .fractal/ — run /fractal:doctor" >&2
      exit 1
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

# Select deepest node (alphabetical tiebreak) from a list of relative paths
select_deepest() {
  local best="" best_depth=-1
  for node_rel in "$@"; do
    local depth="${node_rel//[^\/]/}"
    depth=$(( ${#depth} + 1 ))
    if [ "$depth" -gt "$best_depth" ] || { [ "$depth" -eq "$best_depth" ] && [[ "$node_rel" < "$best" ]]; }; then
      best_depth="$depth"
      best="$node_rel"
    fi
  done
  echo "$best"
}

# ── Collect all pending nodes ─────────────────────────────────────────────────

PENDING_NODES=()

while IFS= read -r pred_file; do
  rel_dir="${pred_file#$TREE_PATH/}"
  rel_dir="$(dirname "$rel_dir")"

  case "$rel_dir" in
    _orphans|_orphans/*) continue ;;
  esac

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

LEAF_PENDING_NODES=()

for node_rel in "${PENDING_NODES[@]}"; do
  node_dir="$TREE_PATH/$node_rel"
  has_pending_child=false

  while IFS= read -r child_pred; do
    child_rel_dir="${child_pred#$TREE_PATH/}"
    child_rel_dir="$(dirname "$child_rel_dir")"

    if [ "$child_rel_dir" = "$node_rel" ]; then
      continue
    fi

    if [ "$(get_field "$child_pred" status)" = "pending" ]; then
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

if [ "$LEAF_PENDING_COUNT" -gt 0 ]; then
  SELECTED_NODE="$(select_deepest "${LEAF_PENDING_NODES[@]}")"
else
  SELECTED_NODE="$(select_deepest "${PENDING_NODES[@]}")"
fi

# ── Read selected predicate text ──────────────────────────────────────────────

SELECTED_PREDICATE="$(get_field "$TREE_PATH/$SELECTED_NODE/predicate.md" predicate)"

# ── Output ────────────────────────────────────────────────────────────────────

echo "selected_node: $SELECTED_NODE"
echo "selected_predicate: $SELECTED_PREDICATE"
echo "pending_count: $PENDING_COUNT"
echo "leaf_pending_count: $LEAF_PENDING_COUNT"
