#!/usr/bin/env bash
# fractal-tree.sh — render ASCII tree of a fractal node tree
# Usage:
#   bash scripts/fractal-tree.sh <tree-path>         # render one tree
#   bash scripts/fractal-tree.sh .fractal             # render all trees in .fractal
#
# Status indicators:
#   ✓  satisfied
#   ✗  pruned
#   ○  pending / not started
#   ◀  active node (from root.md active_node)

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

get_field() {
  local file="$1" field="$2"
  awk '
    /^---/ { if (fm==0) { fm=1; next } else { exit } }
    fm==1 && $0 ~ "^"field":" {
      sub("^"field":[[:space:]]*", "")
      gsub(/^"/, ""); gsub(/"$/, "")
      gsub(/^'"'"'/, ""); gsub(/'"'"'$/, "")
      print; exit
    }
  ' field="$field" "$file"
}

status_icon() {
  case "$1" in
    satisfied) echo "✓" ;;
    pruned)    echo "✗" ;;
    *)         echo "○" ;;
  esac
}

# ── render_tree <dir> <active_node_rel> <prefix> <is_root> ──────────────────
# dir            — absolute path to this node's directory
# active_node_rel— relative path of active node from tree root (or empty/".")
# prefix         — string to prepend to each line (for nested rendering)
# is_root        — "1" if this is the tree root level

render_tree() {
  local dir="$1"
  local active_node_rel="$2"
  local prefix="$3"
  local is_root="${4:-0}"

  # Collect children: dirs that contain predicate.md OR root.md (sub-trees), sorted
  local children=()
  if [ -d "$dir" ]; then
    while IFS= read -r -d '' child_dir; do
      if [ -f "$child_dir/predicate.md" ] || [ -f "$child_dir/root.md" ]; then
        children+=("$child_dir")
      fi
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  fi

  local total="${#children[@]:-0}"
  local i=0

  # Guard against empty array with -u set
  [ "$total" -eq 0 ] && return 0

  for child_dir in "${children[@]}"; do
    i=$((i + 1))
    local child_name
    child_name="$(basename "$child_dir")"

    # Tree connector
    local connector last_child=0
    if [ "$i" -eq "$total" ]; then
      connector="└── "
      last_child=1
    else
      connector="├── "
    fi

    # Status — from predicate.md if exists, else from root.md (sub-tree)
    local status icon
    if [ -f "$child_dir/predicate.md" ]; then
      status="$(get_field "$child_dir/predicate.md" status)"
    elif [ -f "$child_dir/root.md" ]; then
      status="$(get_field "$child_dir/root.md" status)"
    else
      status="pending"
    fi
    icon="$(status_icon "$status")"

    # Active node marker — compare child's relative path to active_node_rel
    # active_node_rel may be a multi-segment path like "progressive-dx/contexto-cross-node"
    # We need to check if this child IS the active node or is an ancestor of it
    local child_rel
    if [ "$is_root" = "1" ]; then
      child_rel="$child_name"
    else
      # We don't use recursive active_node inside sub-trees yet — mark via sub-tree's own root.md
      child_rel=""
    fi

    local active_marker=""
    if [ -n "$active_node_rel" ] && [ "$active_node_rel" != "." ] && [ -n "$child_rel" ]; then
      # Exact match: this child IS the active node
      if [ "$child_rel" = "$active_node_rel" ]; then
        active_marker=" ◀"
      fi
      # First segment match: active node is INSIDE this child (sub-tree case handled below)
    fi

    echo "${prefix}${connector}${child_name} ${icon}${active_marker}"

    # Determine child prefix for recursion
    local child_prefix
    if [ "$last_child" -eq 1 ]; then
      child_prefix="${prefix}    "
    else
      child_prefix="${prefix}│   "
    fi

    # Recurse into children — sub-trees get no active_node propagation (their ◀ is internal)
    render_tree "$child_dir" "" "$child_prefix" "0"
  done
}

# ── render_one_tree <tree_dir> ───────────────────────────────────────────────

render_one_tree() {
  local tree_dir="${1%/}"

  if [ ! -f "$tree_dir/root.md" ]; then
    echo "Error: no root.md in $tree_dir" >&2
    return 1
  fi

  local tree_name root_pred root_status active_node root_icon
  tree_name="$(basename "$tree_dir")"
  root_pred="$(get_field "$tree_dir/root.md" predicate)"
  root_status="$(get_field "$tree_dir/root.md" status)"
  active_node="$(get_field "$tree_dir/root.md" active_node)"
  [ -z "$active_node" ] && active_node="."

  # If active_node is "." the root itself is active
  local root_active_marker=""
  [ "$active_node" = "." ] && root_active_marker=" ◀"

  root_icon="$(status_icon "$root_status")"

  echo "${tree_name} ${root_icon}${root_active_marker}"
  render_tree "$tree_dir" "$active_node" "" "1"
}

# ── main ─────────────────────────────────────────────────────────────────────

ARG="${1:-.fractal}"
ARG="${ARG%/}"

if [ ! -d "$ARG" ]; then
  echo "Error: directory not found: $ARG" >&2
  exit 1
fi

# If the arg itself has a root.md, render it as a single tree
if [ -f "$ARG/root.md" ]; then
  render_one_tree "$ARG"
  exit 0
fi

# Otherwise treat arg as a container of trees — find all dirs with root.md
found=0
while IFS= read -r -d '' tree_dir; do
  if [ -f "$tree_dir/root.md" ]; then
    # Skip sub-trees (dirs whose parent also contains a root.md or predicate.md)
    # Only render top-level trees (direct children of ARG)
    parent="$(dirname "$tree_dir")"
    if [ "$parent" = "$ARG" ]; then
      [ "$found" -gt 0 ] && echo ""
      render_one_tree "$tree_dir"
      found=$((found + 1))
    fi
  fi
done < <(find "$ARG" -name "root.md" -print0 | sort -z | xargs -0 -I{} dirname {} | sort -zu)

# If no sub-trees found, try rendering ARG itself (maybe it's a flat dir)
if [ "$found" -eq 0 ]; then
  echo "No trees found in $ARG" >&2
  exit 1
fi
