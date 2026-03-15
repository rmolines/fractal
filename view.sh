#!/usr/bin/env bash
# view.sh — generates fractal-view.html from .fractal/ and commands/
# Run from repo root: bash view.sh

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")" && pwd))"
FRACTAL_DIR="$REPO_ROOT/.fractal"
COMMANDS_DIR="$REPO_ROOT/commands"
OUTPUT="/tmp/fractal-view.html"

# ── helpers ────────────────────────────────────────────────────────────────

# Read a frontmatter field from a markdown file
# Usage: frontmatter_field <file> <field>
frontmatter_field() {
  local file="$1" field="$2"
  awk -v f="$field" '
    /^---/ { if (in_fm) { exit } else { in_fm=1; next } }
    in_fm && $0 ~ "^"f":" {
      sub("^"f": *", ""); gsub(/^"|"$/, ""); print; exit
    }
  ' "$file" 2>/dev/null
}

# HTML-escape a string (writes to stdout)
html_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  printf '%s' "$s"
}

# ── derive node execution state ─────────────────────────────────────────────
# Args: <node_dir_absolute> <node_relative_path> <active_node>
# Outputs state string to stdout
derive_state() {
  local node_dir="$1"
  local node_rel="$2"
  local active_node="$3"

  local pred_file="$node_dir/predicate.md"
  local status=""
  if [ -f "$pred_file" ]; then
    status="$(frontmatter_field "$pred_file" "status")"
  fi

  local state
  if [ "$status" = "satisfied" ]; then
    state="satisfied"
  elif [ "$status" = "pruned" ]; then
    state="pruned"
  elif [ "$status" = "candidate" ]; then
    state="candidate"
  elif [ -f "$node_dir/discovery.md" ] && [ -f "$node_dir/prd.md" ]; then
    state="specified"
  elif [ -f "$node_dir/discovery.md" ]; then
    local dtype=""
    dtype=$(awk '/^---/{fc++; next} fc==1 && /^node_type:/{print $2; exit}' "$node_dir/discovery.md" 2>/dev/null)
    if [ "$dtype" = "branch" ]; then
      state="discovered · branch"
    else
      state="discovered · leaf"
    fi
  elif [ -f "$node_dir/plan.md" ] && [ -f "$node_dir/results.md" ] && [ -f "$node_dir/review.md" ]; then
    state="reviewed"
  elif [ -f "$node_dir/plan.md" ] && [ -f "$node_dir/results.md" ]; then
    state="executed"
  elif [ -f "$node_dir/plan.md" ]; then
    state="planned"
  else
    state="pending"
  fi

  if [ -n "$active_node" ] && [ "$node_rel" = "$active_node" ]; then
    state="active · $state"
  fi

  printf '%s' "$state"
}

# ── state sort order ──────────────────────────────────────────────────────────
# Returns numeric sort key for a state string
state_sort_key() {
  local state="$1"
  case "$state" in
    "active"*)  printf '0' ;;
    executed)   printf '1' ;;
    reviewed)   printf '2' ;;
    planned)    printf '3' ;;
    "discovered"*)  printf '3' ;;
    specified)  printf '3' ;;
    candidate)  printf '4' ;;
    pending)    printf '5' ;;
    satisfied)  printf '6' ;;
    pruned)     printf '7' ;;
    *)          printf '5' ;;
  esac
}

# ── state group label ─────────────────────────────────────────────────────────
state_group_label() {
  local state="$1"
  case "$state" in
    "active"*)  printf 'active' ;;
    executed)   printf 'executed' ;;
    reviewed)   printf 'reviewed' ;;
    planned)    printf 'planned' ;;
    "discovered"*)  printf 'in progress' ;;
    specified)  printf 'in progress' ;;
    candidate)  printf 'candidate' ;;
    pending)    printf 'pending' ;;
    satisfied)  printf 'done' ;;
    pruned)     printf 'pruned' ;;
    *)          printf 'pending' ;;
  esac
}

# Canonical group key from state
state_group_key() {
  local state="$1"
  case "$state" in
    "active"*)  printf 'active' ;;
    executed)   printf 'inprogress' ;;
    reviewed)   printf 'inprogress' ;;
    planned)    printf 'inprogress' ;;
    candidate)  printf 'candidate' ;;
    pending)    printf 'pending' ;;
    satisfied)  printf 'satisfied' ;;
    pruned)     printf 'pruned' ;;
    *)          printf 'pending' ;;
  esac
}

# ── recursively build tree HTML ──────────────────────────────────────────────
# render_children <parent_dir_absolute> <parent_rel_path> <active_node> <depth>
# outputs HTML to stdout
render_children() {
  local parent_dir="$1"
  local parent_rel="$2"
  local active_node="$3"
  local depth="${4:-0}"

  # Collect all children with metadata into a temp file for sorting
  local tmp_entries
  tmp_entries="$(mktemp)"

  for child in "$parent_dir"/*/; do
    [ -d "$child" ] || continue
    local dir_name
    dir_name="$(basename "$child")"
    local child_rel
    if [ -z "$parent_rel" ]; then
      child_rel="$dir_name"
    else
      child_rel="$parent_rel/$dir_name"
    fi

    local pred_file="$child/predicate.md"
    [ -f "$pred_file" ] || continue

    local pred_text status created state sort_key
    pred_text="$(frontmatter_field "$pred_file" "predicate")"
    status="$(frontmatter_field "$pred_file" "status")"
    created="$(frontmatter_field "$pred_file" "created")"
    state="$(derive_state "$child" "$child_rel" "$active_node")"
    sort_key="$(state_sort_key "$state")"

    # Replace field separator | with safe placeholder in values
    local safe_pred safe_state safe_created safe_status
    safe_pred="${pred_text//|/PIPE}"
    safe_state="${state//|/PIPE}"
    safe_created="${created//|/PIPE}"
    safe_status="${status//|/PIPE}"
    local safe_child="${child//|/PIPE}"
    local safe_rel="${child_rel//|/PIPE}"

    printf '%s\n' "${sort_key}|${dir_name}|${safe_pred}|${safe_status}|${safe_created}|${safe_state}|${safe_child}|${safe_rel}" >> "$tmp_entries"
  done

  # Sort: primary by sort_key, secondary alphabetically by dir_name
  local sorted_tmp
  sorted_tmp="$(mktemp)"
  sort -t'|' -k1,1n -k2,2 "$tmp_entries" > "$sorted_tmp"
  rm -f "$tmp_entries"

  # Now group-render. We'll write each group into separate temp files, then combine.
  # Group order tracks which groups appeared in order.
  local group_order_file
  group_order_file="$(mktemp)"
  local groups_dir
  groups_dir="$(mktemp -d)"

  while IFS='|' read -r sort_key dir_name safe_pred safe_status safe_created safe_state child_dir child_rel; do
    local gkey
    gkey="$(state_group_key "$safe_state")"
    # Track group order
    if [ ! -f "$groups_dir/$gkey.entries" ]; then
      printf '%s\n' "$gkey" >> "$group_order_file"
    fi
    printf '%s\n' "${sort_key}|${dir_name}|${safe_pred}|${safe_status}|${safe_created}|${safe_state}|${child_dir}|${child_rel}" >> "$groups_dir/$gkey.entries"
  done < "$sorted_tmp"
  rm -f "$sorted_tmp"

  local all_html=""

  # Render active node first, standalone, before groups
  if [ -n "$active_node" ] && [ -f "$groups_dir/active.entries" ]; then
    while IFS='|' read -r sort_key dir_name safe_pred safe_status safe_created safe_state child_dir child_rel; do
      local pred_text="$safe_pred"
      local created="$safe_created"
      local pred_esc created_esc
      pred_esc="$(html_escape "$pred_text")"
      created_esc="$(html_escape "$created")"

      all_html+="      <div class=\"active-node-highlight\">"$'\n'
      all_html+="        <div class=\"tree-item-header\">"$'\n'
      all_html+="          <div class=\"tree-dot active\"></div>"$'\n'
      all_html+="          <span class=\"tree-predicate\">${pred_esc}</span>"$'\n'
      all_html+="          <span class=\"tree-state active-state\">active</span>"$'\n'
      if [ -n "$created_esc" ]; then
        all_html+="          <span class=\"tree-date\">${created_esc}</span>"$'\n'
      fi
      all_html+="        </div>"$'\n'
      local children_output_act
      children_output_act="$(render_children "$child_dir" "$child_rel" "$active_node" "$((depth+1))")"
      if [ -n "$children_output_act" ]; then
        all_html+="        <div class=\"tree-level\">"$'\n'
        all_html+="${children_output_act}"
        all_html+="        </div>"$'\n'
      fi
      all_html+="      </div>"$'\n'
    done < "$groups_dir/active.entries"
  fi

  while IFS= read -r gkey; do
    # Skip active group — already rendered above
    [ "$gkey" = "active" ] && continue
    local entries_file="$groups_dir/$gkey.entries"
    [ -f "$entries_file" ] || continue

    local count
    count="$(wc -l < "$entries_file" | tr -d ' ')"

    # Determine group label and CSS class
    local glabel gcss
    case "$gkey" in
      active)     glabel="active"; gcss="group-active" ;;
      inprogress) glabel="in progress"; gcss="group-inprogress" ;;
      candidate)  glabel="candidate"; gcss="group-candidate" ;;
      pending)    glabel="pending"; gcss="group-pending" ;;
      satisfied)  glabel="done"; gcss="group-satisfied" ;;
      pruned)     glabel="pruned"; gcss="group-pruned" ;;
      *)          glabel="$gkey"; gcss="group-pending" ;;
    esac

    # Unique ID for collapse toggle (use depth+parent_rel+gkey hash)
    local gid
    gid="grp-${depth}-$(printf '%s' "${parent_rel}${gkey}" | tr -dc 'a-zA-Z0-9' | head -c 16)-${count}"

    # Collapsible for satisfied/pruned
    local collapsible=0
    if [ "$gkey" = "satisfied" ] || [ "$gkey" = "pruned" ]; then
      collapsible=1
    fi

    # Group header
    if [ $collapsible -eq 1 ]; then
      all_html+="      <div class=\"state-group ${gcss} collapsible\" data-group-id=\"${gid}\">"$'\n'
      all_html+="        <div class=\"state-group-header\" onclick=\"toggleGroup('${gid}')\">"$'\n'
      all_html+="          <span class=\"state-group-label\">${glabel}</span>"$'\n'
      all_html+="          <span class=\"state-group-count\">${count}</span>"$'\n'
      all_html+="          <span class=\"state-group-toggle\" id=\"toggle-${gid}\">▾</span>"$'\n'
      all_html+="        </div>"$'\n'
      all_html+="        <div class=\"state-group-body collapsed\" id=\"body-${gid}\">"$'\n'
    else
      all_html+="      <div class=\"state-group ${gcss}\">"$'\n'
      if [ "$gkey" != "active" ]; then
        all_html+="        <div class=\"state-group-header\">"$'\n'
        all_html+="          <span class=\"state-group-label\">${glabel}</span>"$'\n'
        all_html+="          <span class=\"state-group-count\">${count}</span>"$'\n'
        all_html+="        </div>"$'\n'
      fi
      all_html+="        <div class=\"state-group-body\">"$'\n'
    fi

    # Render items in this group
    while IFS='|' read -r sort_key dir_name safe_pred safe_status safe_created safe_state child_dir child_rel; do
      local pred_text="$safe_pred"
      local status="$safe_status"
      local state="$safe_state"
      local created="$safe_created"

      # Dot class
      local dot_class="tree-dot"
      case "$status" in
        satisfied) dot_class="tree-dot satisfied" ;;
        pruned)    dot_class="tree-dot pruned" ;;
        *)
          case "$state" in
            "active"*) dot_class="tree-dot active" ;;
          esac
          ;;
      esac

      # Predicate text class
      local pred_class="tree-predicate"
      [ "$status" = "pruned" ] && pred_class="tree-predicate pruned"
      [ "$status" = "satisfied" ] && pred_class="tree-predicate satisfied"

      local pred_esc created_esc
      pred_esc="$(html_escape "$pred_text")"
      created_esc="$(html_escape "$created")"

      # State label class
      local state_label_class="tree-state"
      [[ "$state" == "active"* ]] && state_label_class="tree-state active-state"
      local state_label_esc
      state_label_esc="$(html_escape "$state")"

      # Recurse into children first so we know if there are any
      local children_output
      children_output="$(render_children "$child_dir" "$child_rel" "$active_node" "$((depth+1))")"

      # Generate unique node ID for collapsible toggle
      local safe_dir_id
      safe_dir_id="$(printf '%s' "${dir_name}" | tr -dc 'a-zA-Z0-9' | head -c 20)"
      local node_id="node-${depth}-${safe_dir_id}"

      all_html+="          <div class=\"tree-item\">"$'\n'
      if [ -n "$children_output" ]; then
        all_html+="            <div class=\"tree-item-header tree-item-toggle\" onclick=\"toggleNode('${node_id}')\">"$'\n'
        all_html+="              <span class=\"toggle-icon\" id=\"icon-${node_id}\">▾</span>"$'\n'
      else
        all_html+="            <div class=\"tree-item-header\">"$'\n'
      fi
      all_html+="              <div class=\"${dot_class}\"></div>"$'\n'
      all_html+="              <span class=\"${pred_class}\">${pred_esc}</span>"$'\n'
      all_html+="              <span class=\"${state_label_class}\">${state_label_esc}</span>"$'\n'
      if [ -n "$created_esc" ]; then
        all_html+="              <span class=\"tree-date\">${created_esc}</span>"$'\n'
      fi
      all_html+="            </div>"$'\n'

      if [ -n "$children_output" ]; then
        all_html+="            <div class=\"tree-children\" id=\"children-${node_id}\">"$'\n'
        all_html+="              <div class=\"tree-level\">"$'\n'
        all_html+="${children_output}"
        all_html+="              </div>"$'\n'
        all_html+="            </div>"$'\n'
      fi

      all_html+="          </div>"$'\n'
    done < "$entries_file"

    all_html+="        </div>"$'\n'  # state-group-body
    all_html+="      </div>"$'\n'    # state-group
  done < "$group_order_file"

  rm -rf "$groups_dir" "$group_order_file"

  printf '%s' "$all_html"
}

# ── render a single fractal tree ──────────────────────────────────────────────
# render_tree <tree_dir> <tree_name>
# Returns HTML for one tree panel
render_tree() {
  local tree_dir="$1"
  local tree_name="$2"
  local root_file="$tree_dir/root.md"

  local root_predicate="" active_node=""
  if [ -f "$root_file" ]; then
    root_predicate="$(frontmatter_field "$root_file" "predicate")"
    active_node="$(frontmatter_field "$root_file" "active_node")"
  fi

  # Count nodes for this tree
  local total=0 satisfied=0
  while IFS= read -r pred_file; do
    local node_dir
    node_dir="$(dirname "$pred_file")"
    [ "$node_dir" = "$tree_dir" ] && continue
    total=$((total + 1))
    local st
    st="$(frontmatter_field "$pred_file" "status")"
    [ "$st" = "satisfied" ] && satisfied=$((satisfied + 1))
  done < <(find "$tree_dir" -name "predicate.md" | sort)

  local root_meta="$satisfied / $total"
  local root_pred_esc
  root_pred_esc="$(html_escape "$root_predicate")"
  local tree_children
  tree_children="$(render_children "$tree_dir" "" "$active_node")"

  # Progress bar percentage
  local pct=0
  if [ "$total" -gt 0 ]; then
    pct=$(( (satisfied * 100) / total ))
  fi

  printf '<div class="tree-root-line">\n'
  printf '  <div class="tree-root-dot"></div>\n'
  printf '  <div class="tree-root-text">%s</div>\n' "$root_pred_esc"
  printf '  <div class="tree-root-meta">%s</div>\n' "$root_meta"
  printf '</div>\n'
  printf '<div class="progress-bar-wrap">\n'
  printf '  <div class="progress-bar-fill" style="width:%d%%"></div>\n' "$pct"
  printf '</div>\n'
  printf '<div class="tree-level">\n'
  printf '%s' "$tree_children"
  printf '</div>\n'
}

# ── discover all trees ────────────────────────────────────────────────────────
# A tree is either:
#   1. .fractal/root.md → the default tree (name = "main")
#   2. .fractal/<name>/root.md → a named independent tree

TREE_NAMES=()   # display names in order
TREE_DIRS=()    # absolute dirs in order

if [ -d "$FRACTAL_DIR" ]; then
  # Check for root tree
  if [ -f "$FRACTAL_DIR/root.md" ]; then
    TREE_NAMES+=("main")
    TREE_DIRS+=("$FRACTAL_DIR")
  fi

  # Check for sub-trees (skip _orphans — handled separately)
  for subdir in "$FRACTAL_DIR"/*/; do
    [ -d "$subdir" ] || continue
    local_name="$(basename "$subdir")"
    [ "$local_name" = "_orphans" ] && continue
    if [ -f "$subdir/root.md" ]; then
      TREE_NAMES+=("$local_name")
      TREE_DIRS+=("$subdir")
    fi
  done
fi

NUM_TREES=${#TREE_NAMES[@]}

# ── build tree panels HTML ────────────────────────────────────────────────────
TREE_TABS_HTML=""
TREE_PANELS_HTML=""

if [ "$NUM_TREES" -eq 0 ]; then
  # No trees found
  TREE_PANELS_HTML='<div class="empty-state">no trees found in .fractal/</div>'
elif [ "$NUM_TREES" -eq 1 ]; then
  # Single tree — no sub-tabs needed, just render the tree directly
  tree_html="$(render_tree "${TREE_DIRS[0]}" "${TREE_NAMES[0]}")"
  TREE_PANELS_HTML="$tree_html"
else
  # Multiple trees — render sub-tabs within the tree panel
  NL=$'\n'
  for i in "${!TREE_NAMES[@]}"; do
    tname="${TREE_NAMES[$i]}"
    tname_esc="$(html_escape "$tname")"
    tname_id="tree-sub-$(echo "$tname" | tr ' /' '--')"
    if [ "$i" -eq 0 ]; then
      TREE_TABS_HTML="${TREE_TABS_HTML}    <div class=\"tree-tab active\" data-subtree=\"${tname_id}\">${tname_esc}</div>${NL}"
    else
      TREE_TABS_HTML="${TREE_TABS_HTML}    <div class=\"tree-tab\" data-subtree=\"${tname_id}\">${tname_esc}</div>${NL}"
    fi

    tree_html="$(render_tree "${TREE_DIRS[$i]}" "$tname")"

    if [ "$i" -eq 0 ]; then
      TREE_PANELS_HTML="${TREE_PANELS_HTML}<div class=\"tree-sub-panel active\" id=\"${tname_id}\">${NL}${tree_html}${NL}</div>${NL}"
    else
      TREE_PANELS_HTML="${TREE_PANELS_HTML}<div class=\"tree-sub-panel\" id=\"${tname_id}\">${NL}${tree_html}${NL}</div>${NL}"
    fi
  done
fi

# ── build orphans HTML ────────────────────────────────────────────────────────
ORPHANS_DIR="$FRACTAL_DIR/_orphans"
ORPHANS_HTML=""

if [ -d "$ORPHANS_DIR" ]; then
  orphan_count=0
  orphan_rows=""
  for orphan_dir in "$ORPHANS_DIR"/*/; do
    [ -d "$orphan_dir" ] || continue
    local_pred_file="$orphan_dir/predicate.md"
    [ -f "$local_pred_file" ] || continue
    orphan_count=$((orphan_count + 1))
    pred_text="$(frontmatter_field "$local_pred_file" "predicate")"
    origin="$(frontmatter_field "$local_pred_file" "origin")"
    status="$(frontmatter_field "$local_pred_file" "status")"
    pred_esc="$(html_escape "$pred_text")"
    origin_esc="$(html_escape "$origin")"
    status_esc="$(html_escape "$status")"
    orphan_rows="${orphan_rows}      <div class=\"orphan-item\">
        <div class=\"orphan-dot\"></div>
        <span class=\"orphan-predicate\">${pred_esc}</span>
        <span class=\"orphan-meta\">${origin_esc:+${origin_esc} · }${status_esc}</span>
      </div>
"
  done

  if [ "$orphan_count" -gt 0 ]; then
    ORPHANS_HTML="  <div class=\"orphans-section\">
    <div class=\"orphans-label\">orphans · ${orphan_count}</div>
    <div class=\"orphans-list\">
${orphan_rows}    </div>
  </div>"
  fi
fi

# ── build skills HTML ────────────────────────────────────────────────────────
# Cycle order for flow pills
CYCLE_SKILLS="planning delivery review ship"

# Build flow pills HTML
FLOW_HTML=""
first=1
for skill in $CYCLE_SKILLS; do
  if [ $first -eq 0 ]; then
    FLOW_HTML="${FLOW_HTML}
      <span class=\"skill-arrow\">→</span>
"
  fi
  FLOW_HTML="${FLOW_HTML}      <div class=\"skill-pill\">${skill}</div>"
  first=0
done

# Build description list HTML
# We'll build a temp file list, then emit in order: fractal, cycle, rest
TMP_SKILLS_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_SKILLS_DIR"' EXIT

if [ -d "$COMMANDS_DIR" ]; then
  for f in "$COMMANDS_DIR"/*.md; do
    [ -f "$f" ] || continue
    skill_name="$(basename "$f" .md)"
    desc="$(frontmatter_field "$f" "description")"
    if [ -z "$desc" ]; then
      # Fallback: first non-empty content line after frontmatter
      desc="$(awk '
        /^---/ { fc++; next }
        fc < 2 { next }
        /^#/ { next }
        /^[[:space:]]*$/ { next }
        { print; exit }
      ' "$f")"
    fi
    printf '%s' "$desc" > "$TMP_SKILLS_DIR/$skill_name"
  done
fi

# Emit description rows in order
DESC_LIST_HTML=""

emit_skill_row() {
  local skill="$1"
  local desc_file="$TMP_SKILLS_DIR/$skill"
  [ -f "$desc_file" ] || return
  local desc
  desc="$(cat "$desc_file")"
  local name_esc desc_esc
  name_esc="$(html_escape "$skill")"
  desc_esc="$(html_escape "$desc")"
  DESC_LIST_HTML="${DESC_LIST_HTML}      <div class=\"skill-desc-item\">
        <span class=\"skill-desc-name\">${name_esc}</span>
        <span class=\"skill-desc-text\">${desc_esc}</span>
      </div>
"
}

# Emit: fractal first
emit_skill_row "fractal"

# Cycle skills
for skill in $CYCLE_SKILLS; do
  emit_skill_row "$skill"
done

# Remaining skills (not fractal, not cycle)
if [ -d "$COMMANDS_DIR" ]; then
  for f in "$COMMANDS_DIR"/*.md; do
    [ -f "$f" ] || continue
    skill="$(basename "$f" .md)"
    # Skip if already emitted
    skip=0
    [ "$skill" = "fractal" ] && skip=1
    for c in $CYCLE_SKILLS; do
      [ "$skill" = "$c" ] && skip=1
    done
    [ $skip -eq 0 ] && emit_skill_row "$skill"
  done
fi

# ── multi-tree sub-tabs header (only if multiple trees) ───────────────────────
TREE_SUBTABS_BLOCK=""
if [ "$NUM_TREES" -gt 1 ]; then
  TREE_SUBTABS_BLOCK="$(printf '  <div class="tree-subtabs">\n%s  </div>\n' "$TREE_TABS_HTML")"
fi

# ── generate HTML ─────────────────────────────────────────────────────────────

cat > "$OUTPUT" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>openpredicatree</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500&display=swap');

  :root {
    --bg: #ffffff;
    --text: #2a2a2a;
    --text-muted: #888;
    --text-soft: #555;
    --text-faint: #aaa;
    --text-ghost: #bbb;
    --text-whisper: #ccc;
    --text-dim: #ddd;
    --border: #e8e8e8;
    --border-light: #f0f0f0;
    --border-lighter: #f5f5f5;
    --pill-border: #e0e0e0;
    --dot-satisfied: #2a2a2a;
    --dot-pending-border: #ccc;
    --dot-pruned-bg: #eee;
    --dot-pruned-border: #ddd;
    --tree-l1: #e8e8e8;
    --tree-l2: #d0d0d0;
    --tree-l3: #b0b0b0;
    --scrollbar: #e0e0e0;
    --arrow: #ddd;
    --orphan-dot: #d0d0d0;
    --orphan-text: #bbb;
    --orphan-meta: #ccc;
    --orphan-border: #f0f0f0;
    --progress-bg: #f0f0f0;
    --progress-fill: #2a2a2a;
    --group-label-active: #2a2a2a;
    --group-label-inprogress: #666;
    --group-label-pending: #999;
    --group-label-satisfied: #bbb;
    --group-label-pruned: #ccc;
    --group-bg-satisfied: #fafafa;
    --group-bg-pruned: #fafafa;
    --toggle-color: #ccc;
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #161616;
      --text: #e0e0e0;
      --text-muted: #777;
      --text-soft: #bbb;
      --text-faint: #888;
      --text-ghost: #666;
      --text-whisper: #555;
      --text-dim: #444;
      --border: #2a2a2a;
      --border-light: #222;
      --border-lighter: #1e1e1e;
      --pill-border: #333;
      --dot-satisfied: #e0e0e0;
      --dot-pending-border: #555;
      --dot-pruned-bg: #2a2a2a;
      --dot-pruned-border: #333;
      --tree-l1: #2a2a2a;
      --tree-l2: #444;
      --tree-l3: #666;
      --scrollbar: #333;
      --arrow: #444;
      --orphan-dot: #444;
      --orphan-text: #555;
      --orphan-meta: #444;
      --orphan-border: #1e1e1e;
      --progress-bg: #2a2a2a;
      --progress-fill: #e0e0e0;
      --group-label-active: #e0e0e0;
      --group-label-inprogress: #888;
      --group-label-pending: #666;
      --group-label-satisfied: #444;
      --group-label-pruned: #3a3a3a;
      --group-bg-satisfied: #111;
      --group-bg-pruned: #111;
      --toggle-color: #444;
    }
  }

  * { margin: 0; padding: 0; box-sizing: border-box; }

  body {
    font-family: 'Inter', -apple-system, sans-serif;
    background: var(--bg);
    color: var(--text);
    font-weight: 300;
    line-height: 1.6;
    min-height: 100vh;
  }

  .header {
    padding: 48px 48px 0;
    max-width: 800px;
    margin: 0 auto;
  }

  .header h1 {
    font-size: 15px;
    font-weight: 400;
    letter-spacing: 3px;
    text-transform: lowercase;
    color: var(--text-muted);
    margin-bottom: 32px;
  }

  .tabs {
    display: flex;
    gap: 32px;
    border-bottom: 1px solid var(--border);
    padding: 0 48px;
    max-width: 800px;
    margin: 0 auto;
  }

  .tab {
    padding: 12px 0;
    font-size: 13px;
    font-weight: 400;
    letter-spacing: 1px;
    color: var(--text-faint);
    cursor: pointer;
    border-bottom: 1px solid transparent;
    margin-bottom: -1px;
    transition: color 0.4s ease, border-color 0.4s ease;
    text-transform: lowercase;
    user-select: none;
  }

  .tab:hover { color: var(--text-soft); }

  .tab.active {
    color: var(--text);
    border-bottom-color: var(--text);
  }

  .content {
    max-width: 800px;
    margin: 0 auto;
    padding: 40px 48px 80px;
  }

  .panel {
    display: none;
    animation: fadeIn 0.5s ease;
  }

  .panel.active { display: block; }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(8px); }
    to { opacity: 1; transform: translateY(0); }
  }

  /* ── Skills ── */

  .skills-section-label {
    font-size: 11px;
    letter-spacing: 1.5px;
    text-transform: lowercase;
    color: var(--text-ghost);
    margin-bottom: 20px;
  }

  .skills-flow {
    display: flex;
    align-items: center;
    gap: 0;
    margin-bottom: 48px;
  }

  .skill-pill {
    padding: 10px 20px;
    font-size: 13px;
    font-weight: 400;
    color: var(--text-soft);
    border: 1px solid var(--pill-border);
    border-radius: 24px;
    white-space: nowrap;
    transition: border-color 0.3s ease, color 0.3s ease;
  }

  .skill-pill:hover {
    border-color: var(--text);
    color: var(--text);
  }

  .skill-arrow {
    color: var(--arrow);
    font-size: 18px;
    padding: 0 8px;
    font-weight: 300;
    flex-shrink: 0;
  }

  .skill-desc-list {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .skill-desc-item {
    display: flex;
    align-items: baseline;
    padding: 14px 0;
    border-bottom: 1px solid var(--border-lighter);
  }

  .skill-desc-item:last-child { border-bottom: none; }

  .skill-desc-name {
    font-size: 13px;
    font-weight: 400;
    color: var(--text);
    min-width: 80px;
  }

  .skill-desc-text {
    font-size: 12px;
    color: var(--text-faint);
    font-weight: 300;
  }

  .skills-aside {
    margin-top: 32px;
    padding-top: 24px;
    border-top: 1px solid var(--border-light);
  }

  .aside-label {
    font-size: 11px;
    letter-spacing: 1.5px;
    text-transform: lowercase;
    color: var(--text-whisper);
    margin-bottom: 12px;
  }

  .aside-text {
    font-size: 12px;
    color: var(--text-ghost);
    font-weight: 300;
    line-height: 1.7;
  }

  /* ── Tree ── */

  .tree-subtabs {
    display: flex;
    gap: 24px;
    margin-bottom: 32px;
    border-bottom: 1px solid var(--border-light);
    padding-bottom: 0;
  }

  .tree-tab {
    padding: 8px 0;
    font-size: 12px;
    font-weight: 400;
    letter-spacing: 0.5px;
    color: var(--text-ghost);
    cursor: pointer;
    border-bottom: 1px solid transparent;
    margin-bottom: -1px;
    transition: color 0.3s ease, border-color 0.3s ease;
    text-transform: lowercase;
    user-select: none;
  }

  .tree-tab:hover { color: var(--text-soft); }

  .tree-tab.active {
    color: var(--text-soft);
    border-bottom-color: var(--text-soft);
  }

  .tree-sub-panel {
    display: none;
    animation: fadeIn 0.4s ease;
  }

  .tree-sub-panel.active { display: block; }

  .empty-state {
    font-size: 13px;
    color: var(--text-faint);
    font-weight: 300;
    padding: 24px 0;
  }

  .tree-root-line {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 12px;
  }

  .tree-root-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--text);
    flex-shrink: 0;
  }

  .tree-root-text {
    font-size: 15px;
    font-weight: 400;
    color: var(--text);
  }

  .tree-root-meta {
    font-size: 11px;
    color: var(--text-whisper);
    margin-left: auto;
    white-space: nowrap;
  }

  /* ── Progress bar ── */
  .progress-bar-wrap {
    height: 2px;
    background: var(--progress-bg);
    border-radius: 1px;
    margin-bottom: 28px;
    overflow: hidden;
  }

  .progress-bar-fill {
    height: 100%;
    background: var(--progress-fill);
    border-radius: 1px;
    transition: width 0.6s ease;
    min-width: 0;
  }

  .tree-level {
    padding-left: 24px;
    border-left: 1px solid var(--tree-l1);
    margin-left: 3px;
  }

  .tree-level .tree-level {
    border-left-color: var(--tree-l2);
  }

  .tree-level .tree-level .tree-level {
    border-left-color: var(--tree-l3);
  }

  .tree-item {
    padding: 10px 0 10px 20px;
    position: relative;
  }

  .tree-item::before {
    content: '';
    position: absolute;
    left: 0;
    top: 22px;
    width: 12px;
    height: 1px;
    background: inherit;
  }

  .tree-item-header {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .tree-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    border: 1px solid var(--dot-pending-border);
    background: var(--bg);
    flex-shrink: 0;
  }

  .tree-dot.satisfied {
    background: var(--dot-satisfied);
    border-color: var(--dot-satisfied);
  }

  .tree-dot.active {
    border-color: var(--text);
    border-width: 1.5px;
    animation: pulse 3s ease-in-out infinite;
  }

  .tree-dot.pruned {
    background: var(--dot-pruned-bg);
    border-color: var(--dot-pruned-border);
  }

  @keyframes pulse {
    0%, 100% { box-shadow: 0 0 0 3px color-mix(in srgb, var(--text) 8%, transparent); }
    50% { box-shadow: 0 0 0 6px color-mix(in srgb, var(--text) 4%, transparent); }
  }

  .tree-predicate {
    font-size: 13px;
    font-weight: 400;
    color: var(--text);
    flex: 1;
  }

  .tree-predicate.pruned {
    color: var(--text-whisper);
    text-decoration: line-through;
    text-decoration-color: var(--text-dim);
  }

  .tree-predicate.satisfied {
    color: var(--text-ghost);
    font-weight: 300;
  }

  .tree-date {
    font-size: 10px;
    color: var(--text-ghost);
    font-weight: 300;
    white-space: nowrap;
    letter-spacing: 0.2px;
    flex-shrink: 0;
  }

  /* ── State groups ── */

  .state-group {
    margin-bottom: 4px;
  }

  .state-group-header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 0 4px 20px;
    position: relative;
  }

  .state-group.collapsible .state-group-header {
    cursor: pointer;
    user-select: none;
  }

  .state-group.collapsible .state-group-header:hover .state-group-label {
    color: var(--text-faint);
  }

  .state-group-label {
    font-size: 10px;
    letter-spacing: 1px;
    text-transform: lowercase;
    font-weight: 400;
    transition: color 0.2s ease;
  }

  .state-group-count {
    font-size: 10px;
    font-weight: 300;
    color: var(--text-ghost);
  }

  .state-group-toggle {
    font-size: 10px;
    color: var(--toggle-color);
    margin-left: auto;
    transition: transform 0.25s ease, color 0.2s ease;
    display: inline-block;
  }

  .state-group-toggle.open {
    transform: rotate(0deg);
  }

  .state-group-toggle.closed {
    transform: rotate(-90deg);
  }

  .state-group-body {
    overflow: hidden;
    transition: max-height 0.3s ease, opacity 0.3s ease;
    max-height: 9999px;
    opacity: 1;
  }

  .state-group-body.collapsed {
    max-height: 0;
    opacity: 0;
  }

  /* Group-specific label colors */
  .group-active .state-group-label   { color: var(--group-label-active); }
  .group-inprogress .state-group-label { color: var(--group-label-inprogress); }
  .group-candidate .state-group-label { color: var(--group-label-pending); }
  .group-pending .state-group-label  { color: var(--group-label-pending); }
  .group-satisfied .state-group-label { color: var(--group-label-satisfied); }
  .group-pruned .state-group-label   { color: var(--group-label-pruned); }

  /* Satisfied group: subtle background */
  .group-satisfied .state-group-body,
  .group-pruned .state-group-body {
    border-radius: 4px;
  }

  /* Active group: no header shown (handled in bash via conditional) */
  .group-active .state-group-header {
    display: none;
  }

  /* ── Active node highlight ── */
  .active-node-highlight {
    padding: 12px 16px;
    border-left: 2px solid var(--text);
    margin-bottom: 24px;
  }
  .active-node-highlight .tree-predicate {
    font-weight: 500;
    font-size: 14px;
  }

  /* ── State label ── */
  .tree-state {
    font-size: 10px;
    letter-spacing: 0.5px;
    color: var(--text-ghost);
    font-weight: 300;
    white-space: nowrap;
    flex-shrink: 0;
    text-transform: lowercase;
    margin-right: 8px;
  }
  .tree-state.active-state {
    color: var(--text-soft);
  }

  /* ── Orphans ── */

  .orphans-section {
    margin-top: 48px;
    padding-top: 32px;
    border-top: 1px solid var(--border-light);
  }

  .orphans-label {
    font-size: 11px;
    letter-spacing: 1.5px;
    text-transform: lowercase;
    color: var(--orphan-meta);
    margin-bottom: 16px;
  }

  .orphans-list {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .orphan-item {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 0;
    border-bottom: 1px solid var(--orphan-border);
  }

  .orphan-item:last-child { border-bottom: none; }

  .orphan-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--orphan-dot);
    flex-shrink: 0;
  }

  .orphan-predicate {
    font-size: 12px;
    font-weight: 300;
    color: var(--orphan-text);
  }

  .orphan-meta {
    font-size: 10px;
    color: var(--orphan-meta);
    font-weight: 300;
    margin-left: auto;
    white-space: nowrap;
  }

  /* ── Node collapsible ── */
  .tree-item-toggle {
    cursor: pointer;
    user-select: none;
  }
  .tree-item-toggle .toggle-icon {
    font-size: 10px;
    color: var(--text-ghost);
    margin-right: 4px;
    display: inline-block;
    transition: transform 0.2s ease;
  }
  .tree-children {
    overflow: hidden;
    transition: max-height 0.3s ease;
  }
  .tree-children.collapsed {
    max-height: 0 !important;
  }

  /* Breathing */
  .content { animation: breathe 8s ease-in-out infinite; }

  @keyframes breathe {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.97; }
  }

  ::-webkit-scrollbar { width: 4px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: var(--scrollbar); border-radius: 2px; }
</style>
</head>
<body>

<div class="header">
  <h1>openpredicatree</h1>
</div>

<div class="tabs">
  <div class="tab active" data-tab="tree">predicate tree</div>
  <div class="tab" data-tab="skills">skills</div>
</div>

<div class="content">

  <!-- ── Tree ── -->
  <div class="panel active" id="tree">

${TREE_SUBTABS_BLOCK}
${TREE_PANELS_HTML}
${ORPHANS_HTML}
  </div>

  <!-- ── Skills ── -->
  <div class="panel" id="skills">

    <div class="skills-section-label">execution cycle</div>

    <div class="skills-flow">
${FLOW_HTML}
    </div>

    <div class="skill-desc-list">
${DESC_LIST_HTML}
    </div>

    <div class="skills-aside">
      <div class="aside-label">shortcut</div>
      <div class="aside-text">
        <strong style="font-weight:400;color:var(--text-soft)">patch</strong> skips the full cycle — for predicates simple enough to solve in one shot.
      </div>
    </div>

  </div>

</div>

<script>
  // Main tabs
  document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
      tab.classList.add('active');
      document.getElementById(tab.dataset.tab).classList.add('active');
    });
  });

  // Tree sub-tabs (for multiple trees)
  document.querySelectorAll('.tree-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tree-tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tree-sub-panel').forEach(p => p.classList.remove('active'));
      tab.classList.add('active');
      document.getElementById(tab.dataset.subtree).classList.add('active');
    });
  });

  // Toggle group collapse
  function toggleGroup(id) {
    const body = document.getElementById('body-' + id);
    const toggle = document.getElementById('toggle-' + id);
    if (!body) return;
    const isCollapsed = body.classList.contains('collapsed');
    if (isCollapsed) {
      body.classList.remove('collapsed');
      if (toggle) { toggle.textContent = '▾'; toggle.classList.remove('closed'); toggle.classList.add('open'); }
    } else {
      body.classList.add('collapsed');
      if (toggle) { toggle.textContent = '▸'; toggle.classList.remove('open'); toggle.classList.add('closed'); }
    }
  }

  // Initialize toggle icons for collapsed groups
  document.querySelectorAll('.state-group-body.collapsed').forEach(body => {
    const id = body.id.replace('body-', '');
    const toggle = document.getElementById('toggle-' + id);
    if (toggle) { toggle.textContent = '▸'; toggle.classList.add('closed'); }
  });

  // Toggle individual predicate node children
  function toggleNode(id) {
    var body = document.getElementById('children-' + id);
    var icon = document.getElementById('icon-' + id);
    if (!body) return;
    if (body.classList.contains('collapsed')) {
      body.classList.remove('collapsed');
      body.style.maxHeight = body.scrollHeight + 'px';
      if (icon) icon.textContent = '▾';
    } else {
      body.style.maxHeight = '0px';
      body.classList.add('collapsed');
      if (icon) icon.textContent = '▸';
    }
  }

  // Initialize node children max-height for expanded nodes
  document.querySelectorAll('.tree-children:not(.collapsed)').forEach(el => {
    el.style.maxHeight = el.scrollHeight + 'px';
  });
</script>

</body>
</html>
HTMLEOF

echo "Generated: $OUTPUT"
open "$OUTPUT"
