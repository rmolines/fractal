#!/usr/bin/env bash
# animate-tree.sh — generate a standalone animated HTML visualization of a fractal tree
# Usage:
#   bash scripts/animate-tree.sh [fractal-dir] [output-html]
#
# Arguments:
#   $1  path to .fractal/ root directory (optional — auto-discovers from repo root)
#   $2  output HTML file path (optional — defaults to /tmp/fractal-animation.html)
#
# Output:
#   Writes a single standalone HTML file and prints its path to stdout.

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

get_conclusion_oneliner() {
  local node_dir="$1"
  local conclusion_file="$node_dir/conclusion.md"
  [ -f "$conclusion_file" ] || return 0
  awk '
    /^## What was achieved/ { found=1; next }
    found && /^[[:space:]]*$/ { next }
    found { print; exit }
  ' "$conclusion_file"
}

escape_js() {
  # Escape for embedding in a JS double-quoted string
  local s="$1"
  s="${s//\\/\\\\}"   # backslash
  s="${s//\"/\\\"}"   # double-quote
  s="${s//$'\n'/\\n}" # newline
  s="${s//$'\r'/}"    # carriage return
  printf '%s' "$s"
}

# ── argument resolution ───────────────────────────────────────────────────────

FRACTAL_DIR="${1:-}"
OUTPUT_FILE="${2:-/tmp/fractal-animation.html}"

if [ -z "$FRACTAL_DIR" ]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  if [ -d "$REPO_ROOT/.fractal" ]; then
    FRACTAL_DIR="$REPO_ROOT/.fractal"
  else
    echo "Error: no .fractal/ directory found in repo root $REPO_ROOT" >&2
    exit 1
  fi
fi

FRACTAL_DIR="${FRACTAL_DIR%/}"

# Auto-discover single tree if FRACTAL_DIR doesn't have root.md directly
if [ ! -f "$FRACTAL_DIR/root.md" ]; then
  TREE_DIR=""
  TREE_COUNT=0
  for d in "$FRACTAL_DIR"/*/; do
    if [ -f "${d}root.md" ]; then
      TREE_DIR="${d%/}"
      TREE_COUNT=$((TREE_COUNT + 1))
    fi
  done
  if [ "$TREE_COUNT" -eq 1 ] && [ -n "$TREE_DIR" ]; then
    FRACTAL_DIR="$TREE_DIR"
  elif [ "$TREE_COUNT" -eq 0 ]; then
    echo "Error: no root.md found in $FRACTAL_DIR" >&2
    exit 1
  fi
fi

if [ ! -f "$FRACTAL_DIR/root.md" ]; then
  echo "Error: no root.md found at $FRACTAL_DIR/root.md" >&2
  exit 1
fi

# ── read root ─────────────────────────────────────────────────────────────────

ROOT_PREDICATE=$(get_field "$FRACTAL_DIR/root.md" predicate)
ROOT_STATUS=$(get_field "$FRACTAL_DIR/root.md" status)
ROOT_CREATED=$(get_field "$FRACTAL_DIR/root.md" created)
ACTIVE_NODE=$(get_field "$FRACTAL_DIR/root.md" active_node)
[ -z "$ROOT_STATUS" ]  && ROOT_STATUS="pending"
[ -z "$ROOT_CREATED" ] && ROOT_CREATED="2000-01-01"
[ -z "$ACTIVE_NODE" ]  && ACTIVE_NODE=""

# ── collect all nodes ─────────────────────────────────────────────────────────

# Build a JS array of node objects as a shell variable
NODES_JSON=""

collect_nodes() {
  local dir="$1"
  local depth="$2"
  local parent_slug="$3"

  local children=()
  if [ -d "$dir" ]; then
    while IFS= read -r -d '' child_dir; do
      if [ -f "$child_dir/predicate.md" ]; then
        children+=("$child_dir")
      fi
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  fi

  for child_dir in "${children[@]+"${children[@]}"}"; do
    local slug predicate status created conclusion is_active active_basename
    slug="$(basename "$child_dir")"
    predicate="$(get_field "$child_dir/predicate.md" predicate)"
    status="$(get_field "$child_dir/predicate.md" status)"
    created="$(get_field "$child_dir/predicate.md" created)"
    conclusion="$(get_conclusion_oneliner "$child_dir")"
    [ -z "$status" ]    && status="pending"
    [ -z "$created" ]   && created="2000-01-01"
    [ -z "$predicate" ] && predicate="(no predicate)"

    is_active="false"
    active_basename="$(basename "${ACTIVE_NODE:-}" 2>/dev/null || echo "")"
    if [ -n "$active_basename" ] && [ "$slug" = "$active_basename" ]; then
      is_active="true"
    fi

    if [ -n "$NODES_JSON" ]; then
      NODES_JSON="${NODES_JSON},"
    fi
    NODES_JSON="${NODES_JSON}
    {\"slug\":\"$(escape_js "$slug")\",\"predicate\":\"$(escape_js "$predicate")\",\"status\":\"$(escape_js "$status")\",\"created\":\"$(escape_js "$created")\",\"depth\":${depth},\"parent\":\"$(escape_js "$parent_slug")\",\"conclusion\":\"$(escape_js "$conclusion")\",\"isActive\":${is_active}}"

    collect_nodes "$child_dir" $((depth + 1)) "$slug"
  done
}

collect_nodes "$FRACTAL_DIR" 1 "root"

# ── build JS data block ───────────────────────────────────────────────────────

JS_DATA="const TREE_DATA = {
  root: {
    slug: \"root\",
    predicate: \"$(escape_js "$ROOT_PREDICATE")\",
    status: \"$(escape_js "$ROOT_STATUS")\",
    created: \"$(escape_js "$ROOT_CREATED")\",
    active_node: \"$(escape_js "$ACTIVE_NODE")\"
  },
  nodes: [${NODES_JSON}
  ]
};"

# ── write HTML ─────────────────────────────────────────────────────────────────
# Use a quoted heredoc ('HTMLEOF') so no shell expansion happens inside it.
# Inject the JS data block before the heredoc via printf.

{
printf '%s\n' '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>fractal — predicate tree animated</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: '"'"'Inter'"'"', sans-serif;
    background: #0d1117;
    color: #f0f6fc;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    overflow-x: hidden;
  }
  #header {
    padding: 32px 24px 16px;
    text-align: center;
    flex-shrink: 0;
  }
  #header h1 {
    font-size: 36px;
    font-weight: 600;
    color: #f0f6fc;
    letter-spacing: -0.5px;
  }
  #header .root-pred {
    font-size: 14px;
    color: #8b949e;
    margin-top: 8px;
    max-width: 640px;
    margin-left: auto;
    margin-right: auto;
    line-height: 1.5;
  }
  #header .subtitle {
    font-size: 11px;
    color: #6e7681;
    margin-top: 6px;
    text-transform: uppercase;
    letter-spacing: 1px;
  }
  #canvas-container {
    flex: 1;
    position: relative;
    overflow: hidden;
    min-height: 400px;
  }
  #svg-layer {
    position: absolute;
    top: 0; left: 0;
    width: 100%; height: 100%;
    pointer-events: none;
    overflow: visible;
  }
  #nodes-layer {
    position: absolute;
    top: 0; left: 0;
    width: 100%; height: 100%;
  }
  .node-card {
    position: absolute;
    width: 200px;
    border-radius: 8px;
    border: 1.5px solid;
    padding: 10px 12px;
    font-size: 12px;
    line-height: 1.4;
    opacity: 0;
    transform: scale(0.3);
    transition: opacity 0.6s ease-out, transform 0.6s ease-out;
    cursor: default;
  }
  .node-card.visible {
    opacity: 1;
    transform: scale(1);
  }
  .node-card.status-satisfied { border-color: #1a7f37; background: #0d2818; }
  .node-card.status-pending   { border-color: #1f6feb; background: #0c1d2e; }
  .node-card.status-pruned    { border-color: #b91c1c; background: #2d0a0a; }
  .node-card.status-root      { border-color: #6e40c9; background: #1a0f2e; }
  .node-card.is-active { animation: pulse-border 2s ease-in-out infinite; }
  .node-card.status-satisfied.is-active { animation-name: pulse-border-green; }
  .node-card.status-pending.is-active   { animation-name: pulse-border-blue; }
  .node-card.status-root.is-active      { animation-name: pulse-border-purple; }
  @keyframes pulse-border-green {
    0%,100% { box-shadow: 0 0 0 0 rgba(26,127,55,0); border-color: #1a7f37; }
    50%     { box-shadow: 0 0 0 4px rgba(26,127,55,0.4); border-color: #2ea043; }
  }
  @keyframes pulse-border-blue {
    0%,100% { box-shadow: 0 0 0 0 rgba(31,111,235,0); border-color: #1f6feb; }
    50%     { box-shadow: 0 0 0 4px rgba(31,111,235,0.4); border-color: #388bfd; }
  }
  @keyframes pulse-border-purple {
    0%,100% { box-shadow: 0 0 0 0 rgba(110,64,201,0); border-color: #6e40c9; }
    50%     { box-shadow: 0 0 0 4px rgba(110,64,201,0.4); border-color: #8957e5; }
  }
  @keyframes pulse-border {
    0%,100% { box-shadow: 0 0 0 0 rgba(240,246,252,0); }
    50%     { box-shadow: 0 0 0 4px rgba(240,246,252,0.3); }
  }
  .node-slug {
    font-weight: 600;
    font-size: 12px;
    color: #f0f6fc;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .node-icon { float: right; font-size: 13px; margin-left: 4px; }
  .node-icon.satisfied { color: #3fb950; }
  .node-icon.pending   { color: #58a6ff; }
  .node-icon.pruned    { color: #f85149; }
  .node-icon.root      { color: #bc8cff; }
  .node-predicate {
    font-size: 11px;
    color: #8b949e;
    margin-top: 5px;
    line-height: 1.4;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .node-date { font-size: 10px; color: #6e7681; margin-top: 5px; }
  .node-conclusion {
    font-size: 10px; color: #6e7681; margin-top: 4px;
    font-style: italic; white-space: nowrap;
    overflow: hidden; text-overflow: ellipsis;
  }
  .edge-line {
    stroke: #30363d;
    stroke-width: 1.5;
    fill: none;
    transition: stroke-dashoffset 0.5s ease-out;
  }
  #controls {
    background: #161b22;
    border-top: 1px solid #30363d;
    padding: 12px 24px;
    display: flex;
    align-items: center;
    gap: 16px;
    flex-shrink: 0;
    flex-wrap: wrap;
  }
  .ctrl-btn {
    background: #21262d;
    border: 1px solid #30363d;
    border-radius: 6px;
    color: #f0f6fc;
    font-family: '"'"'Inter'"'"', sans-serif;
    font-size: 14px;
    padding: 6px 14px;
    cursor: pointer;
    transition: background 0.15s;
  }
  .ctrl-btn:hover { background: #30363d; }
  #progress-text { font-size: 12px; color: #8b949e; flex: 1; text-align: center; }
  .speed-group { display: flex; gap: 4px; align-items: center; }
  .speed-group label { font-size: 11px; color: #6e7681; margin-right: 4px; }
  .speed-btn {
    background: #21262d; border: 1px solid #30363d; border-radius: 4px;
    color: #8b949e; font-family: '"'"'Inter'"'"', sans-serif; font-size: 11px;
    padding: 3px 8px; cursor: pointer; transition: background 0.15s, color 0.15s;
  }
  .speed-btn.active { background: #1f6feb; border-color: #1f6feb; color: #fff; }
  .speed-btn:hover:not(.active) { background: #30363d; color: #f0f6fc; }
  #legend { display: flex; gap: 14px; align-items: center; }
  .legend-item { display: flex; align-items: center; gap: 5px; font-size: 11px; color: #8b949e; }
  .legend-dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; }
  .legend-dot.satisfied { background: #1a7f37; }
  .legend-dot.pending   { background: #1f6feb; }
  .legend-dot.pruned    { background: #b91c1c; }
</style>
</head>
<body>
<div id="header">
  <h1>fractal</h1>
  <div class="root-pred" id="root-pred-text"></div>
  <div class="subtitle">predicate tree — animated</div>
</div>
<div id="canvas-container">
  <svg id="svg-layer"></svg>
  <div id="nodes-layer"></div>
</div>
<div id="controls">
  <button class="ctrl-btn" id="btn-play">&#9654;</button>
  <button class="ctrl-btn" id="btn-restart">&#8635;</button>
  <span id="progress-text">Node 0 of 0</span>
  <div id="legend">
    <div class="legend-item"><span class="legend-dot satisfied"></span> satisfied</div>
    <div class="legend-item"><span class="legend-dot pending"></span> pending</div>
    <div class="legend-item"><span class="legend-dot pruned"></span> pruned</div>
  </div>
  <div class="speed-group">
    <label>Speed</label>
    <button class="speed-btn" data-speed="0.5">Slow</button>
    <button class="speed-btn active" data-speed="1">Normal</button>
    <button class="speed-btn" data-speed="2">Fast</button>
  </div>
</div>
<script>'

# Inject the shell-generated JS data
printf '%s\n' "$JS_DATA"

# Continue with the rest of the JS (quoted heredoc — no shell expansion)
cat << 'JSEOF'

// ── layout constants ─────────────────────────────────────────────────────────
const CARD_W = 200;
const CARD_H = 92;
const LEVEL_GAP = 180;
const PADDING_TOP = 24;
const PADDING_SIDES = 32;
const NODE_GAP = 16;

// ── build full node list ──────────────────────────────────────────────────────
const allNodes = [
  {
    slug: "root",
    predicate: TREE_DATA.root.predicate,
    status: "root",
    created: TREE_DATA.root.created || "2000-01-01",
    depth: 0,
    parent: null,
    conclusion: "",
    isActive: false
  },
  ...TREE_DATA.nodes
];

// Sort chronologically for animation order (root always first)
const animOrder = [...allNodes].sort((a, b) => {
  if (a.slug === "root") return -1;
  if (b.slug === "root") return 1;
  return a.created.localeCompare(b.created);
});

// Group by depth
const byDepth = {};
allNodes.forEach(n => {
  if (!byDepth[n.depth]) byDepth[n.depth] = [];
  byDepth[n.depth].push(n);
});
const maxDepth = Math.max(...Object.keys(byDepth).map(Number));

// ── layout computation ────────────────────────────────────────────────────────
let positions = {};

function computeLayout() {
  const container = document.getElementById('canvas-container');
  const W = container.offsetWidth || 900;
  const result = {};

  // Build children map: { slug → [child_slug, ...] }
  const childrenMap = {};
  allNodes.forEach(n => { childrenMap[n.slug] = []; });
  allNodes.forEach(n => {
    if (n.parent && childrenMap[n.parent]) {
      childrenMap[n.parent].push(n.slug);
    }
  });

  // Bottom-up: compute subtree width for each node
  const widthCache = {};
  function subtreeWidth(slug) {
    if (widthCache[slug] !== undefined) return widthCache[slug];
    const kids = childrenMap[slug] || [];
    if (kids.length === 0) {
      widthCache[slug] = CARD_W;
      return CARD_W;
    }
    const totalKids = kids.reduce((sum, k) => sum + subtreeWidth(k), 0);
    const w = Math.max(CARD_W, totalKids + NODE_GAP * (kids.length - 1));
    widthCache[slug] = w;
    return w;
  }
  allNodes.forEach(n => subtreeWidth(n.slug));

  // Top-down: assign X positions, centering each node over its subtree block
  const depthMap = {};
  allNodes.forEach(n => { depthMap[n.slug] = n.depth; });

  function assignX(slug, blockLeft) {
    const w = widthCache[slug];
    const x = blockLeft + (w - CARD_W) / 2;
    const depth = depthMap[slug];
    const y = PADDING_TOP + depth * LEVEL_GAP;
    result[slug] = { x, y, cx: x + CARD_W / 2, cy: y + CARD_H / 2 };
    const kids = childrenMap[slug] || [];
    let offset = 0;
    kids.forEach(kid => {
      assignX(kid, blockLeft + offset);
      offset += widthCache[kid] + NODE_GAP;
    });
  }

  const rootW = subtreeWidth('root');
  const startX = Math.max(PADDING_SIDES, (W - rootW) / 2);
  assignX('root', startX);

  return result;
}

// ── DOM helpers ───────────────────────────────────────────────────────────────
function statusIcon(s) {
  return { satisfied: '&#10003;', pruned: '&#10007;', root: '&#9673;' }[s] || '&#9675;';
}
function iconClass(s) {
  return { satisfied: 'satisfied', pruned: 'pruned', root: 'root' }[s] || 'pending';
}

const nodesLayer = document.getElementById('nodes-layer');
const svgLayer   = document.getElementById('svg-layer');
const cardEls = {};
const edgeEls = {};

// Build card DOM elements
allNodes.forEach(node => {
  const card = document.createElement('div');
  card.className = 'node-card status-' + node.status + (node.isActive ? ' is-active' : '');
  card.dataset.slug = node.slug;
  card.style.width = CARD_W + 'px';

  const pred = node.predicate.length > 60 ? node.predicate.slice(0, 60) + '\u2026' : node.predicate;
  const concl = node.conclusion
    ? '<div class="node-conclusion">\u201c' + node.conclusion.slice(0, 55) +
      (node.conclusion.length > 55 ? '\u2026' : '') + '\u201d</div>'
    : '';

  card.innerHTML =
    '<div class="node-slug"><span class="node-icon ' + iconClass(node.status) + '">' +
    statusIcon(node.status) + '</span>' + node.slug + '</div>' +
    '<div class="node-predicate">' + pred + '</div>' +
    '<div class="node-date">' + node.created + '</div>' + concl;

  nodesLayer.appendChild(card);
  cardEls[node.slug] = card;
});

// Build SVG edge paths (one per non-root node)
allNodes.forEach(node => {
  if (!node.parent) return;
  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  path.classList.add('edge-line');
  path.dataset.child = node.slug;
  svgLayer.appendChild(path);
  edgeEls[node.slug] = path;
});

// ── apply layout ──────────────────────────────────────────────────────────────
function applyLayout() {
  positions = computeLayout();

  const container = document.getElementById('canvas-container');
  const W = container.offsetWidth || 900;
  const totalH = PADDING_TOP + maxDepth * LEVEL_GAP + CARD_H + 60;
  container.style.minHeight = totalH + 'px';
  svgLayer.setAttribute('viewBox', '0 0 ' + W + ' ' + totalH);

  allNodes.forEach(node => {
    const pos = positions[node.slug];
    if (!pos) return;
    const card = cardEls[node.slug];
    card.style.left = pos.x + 'px';
    card.style.top  = pos.y + 'px';
    card.style.transformOrigin = (pos.cx - pos.x) + 'px ' + (pos.cy - pos.y) + 'px';
  });

  allNodes.forEach(node => {
    if (!node.parent) return;
    const cp = positions[node.slug];
    const pp = positions[node.parent];
    if (!cp || !pp) return;

    const x1 = pp.cx, y1 = pp.y + CARD_H;
    const x2 = cp.cx, y2 = cp.y;
    const my = (y1 + y2) / 2;
    const d  = 'M ' + x1 + ' ' + y1 + ' C ' + x1 + ' ' + my + ', ' + x2 + ' ' + my + ', ' + x2 + ' ' + y2;

    const line = edgeEls[node.slug];
    if (!line) return;
    line.setAttribute('d', d);
    let len = 200;
    try { len = line.getTotalLength(); } catch(e) {}
    line.style.strokeDasharray = len;
    line.style.strokeDashoffset = line.classList.contains('visible') ? 0 : len;
  });
}

// ── animation engine ──────────────────────────────────────────────────────────
let currentStep = 0;
let isPlaying   = false;
let speedMult   = 1;
let animTimer   = null;

const STEP_MS = 500;
const LOOP_MS = 2000;

function resetAll() {
  clearTimeout(animTimer);
  allNodes.forEach(n => {
    const card = cardEls[n.slug];
    if (!card) return;
    card.style.transition = 'none';
    card.classList.remove('visible');
    card.style.opacity = '0';
    card.style.transform = 'scale(0.3)';
  });
  Object.values(edgeEls).forEach(line => {
    if (!line) return;
    line.style.transition = 'none';
    line.classList.remove('visible');
    let len = 200;
    try { len = line.getTotalLength(); } catch(e) {}
    line.style.strokeDashoffset = len;
  });
  void nodesLayer.offsetHeight; // reflow
  allNodes.forEach(n => {
    const card = cardEls[n.slug];
    if (card) card.style.transition = '';
  });
  Object.values(edgeEls).forEach(line => {
    if (line) line.style.transition = '';
  });
  currentStep = 0;
  updateProgress();
}

function showNode(node) {
  const card = cardEls[node.slug];
  if (card) {
    card.classList.add('visible');
  }
  const line = edgeEls[node.slug];
  if (line) {
    let len = 200;
    try { len = line.getTotalLength(); } catch(e) {}
    line.style.strokeDashoffset = '0';
  }
}

function updateProgress() {
  document.getElementById('progress-text').textContent =
    'Node ' + currentStep + ' of ' + animOrder.length;
}

function stepForward() {
  if (currentStep >= animOrder.length) {
    animTimer = setTimeout(() => {
      resetAll();
      if (isPlaying) scheduleNext();
    }, LOOP_MS / speedMult);
    return;
  }
  showNode(animOrder[currentStep]);
  currentStep++;
  updateProgress();
  if (isPlaying) scheduleNext();
}

function scheduleNext() {
  clearTimeout(animTimer);
  const delay = currentStep >= animOrder.length
    ? LOOP_MS / speedMult
    : STEP_MS / speedMult;
  animTimer = setTimeout(stepForward, delay);
}

function play() {
  if (isPlaying) return;
  isPlaying = true;
  document.getElementById('btn-play').innerHTML = '&#9646;&#9646;';
  scheduleNext();
}

function pause() {
  if (!isPlaying) return;
  isPlaying = false;
  clearTimeout(animTimer);
  document.getElementById('btn-play').innerHTML = '&#9654;';
}

function restart() {
  pause();
  resetAll();
  setTimeout(() => play(), 80);
}

// ── controls ──────────────────────────────────────────────────────────────────
document.getElementById('btn-play').addEventListener('click', () => {
  if (isPlaying) pause(); else play();
});
document.getElementById('btn-restart').addEventListener('click', restart);

document.querySelectorAll('.speed-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.speed-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    speedMult = parseFloat(btn.dataset.speed);
  });
});

// ── init ──────────────────────────────────────────────────────────────────────
window.addEventListener('load', () => {
  applyLayout();
  updateProgress();
  setTimeout(() => play(), 500);
});
window.addEventListener('resize', applyLayout);

JSEOF

printf '%s\n' '</script>
</body>
</html>'

} > "$OUTPUT_FILE"

echo "$OUTPUT_FILE"
