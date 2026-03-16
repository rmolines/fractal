#!/usr/bin/env bash
set -euo pipefail

# select-next-node.sh — traverse fractal tree and return highest-priority pending node
# Usage: bash scripts/select-next-node.sh [tree-path]
#   No argument: auto-discovers the single tree in .fractal/
#
# Priority: shallowest pending node first, alphabetical tiebreak.
# Used for session traversal (start of session). ASCEND goes directly to parent.

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

# Select shallowest node (alphabetical tiebreak) from a list of relative paths
select_shallowest() {
  local best="" best_depth=999999
  for node_rel in "$@"; do
    local depth="${node_rel//[^\/]/}"
    depth=$(( ${#depth} + 1 ))
    if [ "$depth" -lt "$best_depth" ] || { [ "$depth" -eq "$best_depth" ] && { [ -z "$best" ] || [[ "$node_rel" < "$best" ]]; }; }; then
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
  echo "locked_count: 0"
  exit 0
fi

# ── Collect active lock branches ──────────────────────────────────────────────

LOCKED_BRANCHES=()

while IFS= read -r lock_file; do
  lock_pid="$(get_field "$lock_file" pid)"
  if [ -z "$lock_pid" ]; then
    continue
  fi
  if ! kill -0 "$lock_pid" 2>/dev/null; then
    # Stale lock — ignore
    continue
  fi
  # Derive relative node path (same logic as predicate.md collection)
  lock_dir="$(dirname "$lock_file")"
  lock_rel="${lock_dir#$TREE_PATH/}"
  LOCKED_BRANCHES+=("$lock_rel")
done < <(find "$TREE_PATH" -name "session.lock" -not -path "*/_orphans/*" | sort)

# ── Branch exclusion filter ───────────────────────────────────────────────────

is_in_locked_branch() {
  local node="$1"
  for locked in "${LOCKED_BRANCHES[@]}"; do
    # Exact match
    [ "$node" = "$locked" ] && return 0
    # Node is descendant of locked
    [[ "$node" == "$locked/"* ]] && return 0
    # Node is ancestor of locked
    [[ "$locked" == "$node/"* ]] && return 0
  done
  return 1
}

LOCKED_COUNT=0

if [ "${#LOCKED_BRANCHES[@]}" -gt 0 ]; then
  FILTERED_NODES=()
  for node_rel in "${PENDING_NODES[@]}"; do
    if is_in_locked_branch "$node_rel"; then
      LOCKED_COUNT=$((LOCKED_COUNT + 1))
    else
      FILTERED_NODES+=("$node_rel")
    fi
  done
  PENDING_NODES=("${FILTERED_NODES[@]+"${FILTERED_NODES[@]}"}")
fi

if [ "${#PENDING_NODES[@]}" -eq 0 ]; then
  echo "selected_node: none"
  echo "selected_predicate: none"
  echo "pending_count: $PENDING_COUNT"
  echo "locked_count: $LOCKED_COUNT"
  echo "reason: all_pending_locked"
  exit 0
fi

# ── Select shallowest pending node ───────────────────────────────────────────

if [ "${#PENDING_NODES[@]}" -gt 0 ]; then
  SELECTED_NODE="$(select_shallowest "${PENDING_NODES[@]}")"
fi

# ── Read selected predicate text ──────────────────────────────────────────────

SELECTED_PREDICATE="$(get_field "$TREE_PATH/$SELECTED_NODE/predicate.md" predicate)"

# ── Output ────────────────────────────────────────────────────────────────────

echo "selected_node: $SELECTED_NODE"
echo "selected_predicate: $SELECTED_PREDICATE"
echo "pending_count: $PENDING_COUNT"
echo "locked_count: $LOCKED_COUNT"
