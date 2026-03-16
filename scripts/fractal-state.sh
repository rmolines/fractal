#!/usr/bin/env bash
set -euo pipefail

# fractal-state.sh — read fractal tree state from filesystem
# Usage: bash scripts/fractal-state.sh [tree-path]
#   No argument: auto-discovers the single tree in .fractal/

if [ $# -lt 1 ]; then
  # Auto-discover single tree in .fractal/
  if [ ! -d ".fractal" ]; then
    echo "state: error" >&2
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
      echo "state: error" >&2
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

# ── Root fields ──────────────────────────────────────────────────────────────

TREE_NAME="$(basename "$TREE_PATH")"
ROOT_PREDICATE="$(get_field "$ROOT_MD" predicate)"
ROOT_STATUS="$(get_field "$ROOT_MD" status)"
ACTIVE_NODE="$(get_field "$ROOT_MD" active_node)"

# Normalize: empty active_node → "."
if [ -z "$ACTIVE_NODE" ]; then
  ACTIVE_NODE="."
fi

# ── Resolve active node path ─────────────────────────────────────────────────

if [ "$ACTIVE_NODE" = "." ]; then
  ACTIVE_DIR="$TREE_PATH"
  ACTIVE_PRED_MD="$ROOT_MD"
  ACTIVE_PREDICATE="$ROOT_PREDICATE"
  ACTIVE_STATUS="$ROOT_STATUS"
  DEPTH=0
  BREADCRUMB="$TREE_NAME [depth 0]"
  PARENT_PATH="none"
  PARENT_PREDICATE="none"
else
  ACTIVE_DIR="$TREE_PATH/$ACTIVE_NODE"
  ACTIVE_PRED_MD="$ACTIVE_DIR/predicate.md"

  if [ ! -f "$ACTIVE_PRED_MD" ]; then
    echo "tree: $TREE_NAME"
    echo "root_predicate: $ROOT_PREDICATE"
    echo "root_status: $ROOT_STATUS"
    echo "active_node: $ACTIVE_NODE"
    echo "active_predicate: NOT FOUND"
    echo "active_status: NOT FOUND"
    echo "state: broken"
    exit 0
  fi

  ACTIVE_PREDICATE="$(get_field "$ACTIVE_PRED_MD" predicate)"
  ACTIVE_STATUS="$(get_field "$ACTIVE_PRED_MD" status)"

  # Depth = number of path segments in ACTIVE_NODE
  DEPTH="$(echo "$ACTIVE_NODE" | awk -F'/' '{print NF}')"

  # Breadcrumb: tree > seg1 > seg2 ... [depth N]
  BREADCRUMB_PARTS="$TREE_NAME"
  IFS='/' read -ra SEGS <<< "$ACTIVE_NODE"
  for SEG in "${SEGS[@]}"; do
    BREADCRUMB_PARTS="$BREADCRUMB_PARTS > $SEG"
  done
  BREADCRUMB="$BREADCRUMB_PARTS [depth $DEPTH]"

  # Parent resolution
  if [[ "$ACTIVE_NODE" == */* ]]; then
    # Nested: parent is the directory above
    PARENT_REL="$(dirname "$ACTIVE_NODE")"
    PARENT_PATH="$PARENT_REL"
    PARENT_DIR="$TREE_PATH/$PARENT_REL"
    PARENT_PRED_MD="$PARENT_DIR/predicate.md"
    if [ -f "$PARENT_PRED_MD" ]; then
      PARENT_PREDICATE="$(get_field "$PARENT_PRED_MD" predicate)"
    else
      PARENT_PREDICATE="NOT FOUND"
    fi
  else
    # Top-level child: parent is root
    PARENT_PATH="."
    PARENT_PREDICATE="$ROOT_PREDICATE"
  fi
fi

# ── Children of active node ──────────────────────────────────────────────────

CHILDREN_TOTAL=0
CHILDREN_SATISFIED=0
CHILDREN_PENDING=0
CHILDREN_PRUNED=0

if [ -d "$ACTIVE_DIR" ]; then
  for CHILD_DIR in "$ACTIVE_DIR"/*/; do
    [ -d "$CHILD_DIR" ] || continue
    CHILD_PRED="$CHILD_DIR/predicate.md"
    [ -f "$CHILD_PRED" ] || continue
    CHILDREN_TOTAL=$((CHILDREN_TOTAL + 1))
    CHILD_STATUS="$(get_field "$CHILD_PRED" status)"
    case "$CHILD_STATUS" in
      satisfied)  CHILDREN_SATISFIED=$((CHILDREN_SATISFIED + 1)) ;;
      pruned)     CHILDREN_PRUNED=$((CHILDREN_PRUNED + 1)) ;;
      *)          CHILDREN_PENDING=$((CHILDREN_PENDING + 1)) ;;
    esac
  done
fi

# ── Artifact presence ────────────────────────────────────────────────────────

HAS_PLAN=false
HAS_RESULTS=false
HAS_REVIEW=false
HAS_DISCOVERY=false
HAS_PRD=false

[ -f "$ACTIVE_DIR/plan.md" ]      && HAS_PLAN=true
[ -f "$ACTIVE_DIR/results.md" ]   && HAS_RESULTS=true
[ -f "$ACTIVE_DIR/review.md" ]    && HAS_REVIEW=true
[ -f "$ACTIVE_DIR/discovery.md" ] && HAS_DISCOVERY=true
[ -f "$ACTIVE_DIR/prd.md" ]       && HAS_PRD=true

DISCOVERY_RESPONSE=""
if [ "$HAS_DISCOVERY" = true ]; then
  DISCOVERY_RESPONSE="$(get_field "$ACTIVE_DIR/discovery.md" response)"
fi

# ── State derivation ─────────────────────────────────────────────────────────

if [ "$ACTIVE_STATUS" = "satisfied" ]; then
  STATE="satisfied"
elif [ "$ACTIVE_STATUS" = "pruned" ]; then
  STATE="pruned"
elif [ "$HAS_PLAN" = true ] && [ "$HAS_RESULTS" = true ] && [ "$HAS_REVIEW" = true ]; then
  STATE="reviewed"
elif [ "$HAS_PLAN" = true ] && [ "$HAS_RESULTS" = true ]; then
  STATE="executed"
elif [ "$HAS_PLAN" = true ]; then
  STATE="planned"
elif [ "$HAS_DISCOVERY" = true ] && [ "$HAS_PRD" = true ]; then
  STATE="specified"
elif [ "$HAS_DISCOVERY" = true ] && [ "$DISCOVERY_RESPONSE" = "new_child" ]; then
  STATE="evaluated_new_child"
elif [ "$HAS_DISCOVERY" = true ] && [ "$DISCOVERY_RESPONSE" = "complete" ]; then
  STATE="evaluated_complete"
elif [ "$HAS_DISCOVERY" = true ] && [ "$DISCOVERY_RESPONSE" = "leaf" ]; then
  STATE="evaluated_leaf"
elif [ "$HAS_DISCOVERY" = true ] && [ "$DISCOVERY_RESPONSE" = "unachievable" ]; then
  STATE="evaluated_unachievable"
elif [ "$HAS_DISCOVERY" = true ]; then
  STATE="evaluated"
elif [ "$CHILDREN_TOTAL" -gt 0 ]; then
  STATE="subdivided"
else
  STATE="not_started"
fi

# ── Output ───────────────────────────────────────────────────────────────────

echo "tree: $TREE_NAME"
echo "root_predicate: $ROOT_PREDICATE"
echo "root_status: $ROOT_STATUS"
echo "active_node: $ACTIVE_NODE"
echo "active_predicate: $ACTIVE_PREDICATE"
echo "active_status: $ACTIVE_STATUS"
echo "breadcrumb: $BREADCRUMB"
echo "depth: $DEPTH"
echo "state: $STATE"
echo "parent_path: $PARENT_PATH"
echo "parent_predicate: $PARENT_PREDICATE"
echo "children_total: $CHILDREN_TOTAL"
echo "children_satisfied: $CHILDREN_SATISFIED"
echo "children_pending: $CHILDREN_PENDING"
echo "children_pruned: $CHILDREN_PRUNED"
echo "has_plan: $HAS_PLAN"
echo "has_results: $HAS_RESULTS"
echo "has_review: $HAS_REVIEW"
echo "has_discovery: $HAS_DISCOVERY"
echo "has_prd: $HAS_PRD"
echo "discovery_response: $DISCOVERY_RESPONSE"
