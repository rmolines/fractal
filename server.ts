import { startWatcher } from "openserver/watcher";
import { readFileSync, readdirSync, statSync, existsSync } from "fs";
import { join } from "path";
import type { ServerWebSocket } from "bun";

const PORT = 3333;
const FRACTAL_DIR = ".fractal";

// --- Tree reading helpers ---

function parseField(content: string, field: string): string {
  const lines = content.split("\n");
  let inFrontmatter = false;
  let fmCount = 0;
  for (const line of lines) {
    if (line.trim() === "---") {
      fmCount++;
      if (fmCount === 1) { inFrontmatter = true; continue; }
      if (fmCount === 2) break;
    }
    if (!inFrontmatter) continue;
    const prefix = `${field}:`;
    if (line.startsWith(prefix)) {
      return line.slice(prefix.length).trim().replace(/^["']|["']$/g, "");
    }
  }
  return "";
}

interface NodeInfo {
  slug: string;
  path: string;
  predicate: string;
  status: string;
  isActive: boolean;
  children: NodeInfo[];
}

const STATUS_BADGE: Record<string, { bg: string; color: string; dot: string; label: string }> = {
  satisfied: { bg: "#E8F4EC", color: "#2D6A4F", dot: "●", label: "satisfied" },
  pruned:    { bg: "#F5E8E8", color: "#8C4A4A", dot: "×", label: "pruned" },
  pending:   { bg: "#F5F0E8", color: "#8C7B6E", dot: "○", label: "pending" },
  active:    { bg: "#FDF0E8", color: "#C4773B", dot: "▸", label: "active" },
};

function statusBadge(s: string, isActive: boolean): string {
  const key = isActive ? "active" : (s in STATUS_BADGE ? s : "pending");
  const b = STATUS_BADGE[key];
  return `<span class="badge" style="background:${b.bg};color:${b.color}">${b.dot} ${b.label}</span>`;
}

function escapeHtml(s: string) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function readNodeChildren(dirPath: string, activeNode: string, parentRelPath: string): NodeInfo[] {
  const children: NodeInfo[] = [];
  if (!existsSync(dirPath)) return children;

  let entries: string[];
  try {
    entries = readdirSync(dirPath).sort();
  } catch {
    return children;
  }

  for (const entry of entries) {
    const childPath = join(dirPath, entry);
    let stat;
    try {
      stat = statSync(childPath);
    } catch {
      continue;
    }
    if (!stat.isDirectory()) continue;

    const predicatePath = join(childPath, "predicate.md");
    if (!existsSync(predicatePath)) continue;

    let content = "";
    try { content = readFileSync(predicatePath, "utf-8"); } catch { continue; }

    const predicate = parseField(content, "predicate");
    const status = parseField(content, "status") || "pending";
    const relPath = parentRelPath ? `${parentRelPath}/${entry}` : entry;
    const isActive = relPath === activeNode;

    const nodeChildren = readNodeChildren(childPath, activeNode, relPath);

    children.push({ slug: entry, path: relPath, predicate, status, isActive, children: nodeChildren });
  }

  return children;
}

function renderNodeHtml(node: NodeInfo, depth: number, isLast: boolean): string {
  const badge = statusBadge(node.status, node.isActive);
  const truncated = node.predicate.length > 110 ? node.predicate.slice(0, 110) + "…" : node.predicate;
  const escapedPredicate = escapeHtml(truncated);
  const escapedFull = escapeHtml(node.predicate);
  const depthClass = `depth-${Math.min(depth, 6)}`;
  const activeClass = node.isActive ? " node-active" : "";

  let html = `<li class="node ${depthClass}${activeClass}" data-depth="${depth}" data-last="${isLast}">`;
  html += `<div class="node-row">`;
  html += `<span class="node-connector"></span>`;
  html += `<span class="node-slug">${escapeHtml(node.slug)}</span>`;
  html += `<span class="node-predicate" title="${escapedFull}">${escapedPredicate}</span>`;
  html += badge;
  html += `</div>`;

  if (node.children.length > 0) {
    html += `<ul class="node-children">`;
    for (let i = 0; i < node.children.length; i++) {
      html += renderNodeHtml(node.children[i], depth + 1, i === node.children.length - 1);
    }
    html += `</ul>`;
  }

  html += `</li>`;
  return html;
}

interface TreeInfo {
  name: string;
  rootPredicate: string;
  rootStatus: string;
  activeNode: string;
  children: NodeInfo[];
}

function readTrees(): TreeInfo[] {
  const trees: TreeInfo[] = [];
  if (!existsSync(FRACTAL_DIR)) return trees;

  let entries: string[];
  try { entries = readdirSync(FRACTAL_DIR).sort(); } catch { return trees; }

  for (const entry of entries) {
    const treePath = join(FRACTAL_DIR, entry);
    let stat;
    try { stat = statSync(treePath); } catch { continue; }
    if (!stat.isDirectory()) continue;

    const rootPath = join(treePath, "root.md");
    if (!existsSync(rootPath)) continue;

    let content = "";
    try { content = readFileSync(rootPath, "utf-8"); } catch { continue; }

    const rootPredicate = parseField(content, "predicate");
    const rootStatus = parseField(content, "status") || "pending";
    const activeNode = parseField(content, "active_node");

    const children = readNodeChildren(treePath, activeNode, "");

    trees.push({ name: entry, rootPredicate, rootStatus, activeNode, children });
  }

  return trees;
}

function renderPage(): string {
  const trees = readTrees();
  const timestamp = new Date().toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" });
  const dateStr = new Date().toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" });

  let treesHtml = "";
  for (const tree of trees) {
    const rootBadge = statusBadge(tree.rootStatus, false);
    const escapedPred = escapeHtml(tree.rootPredicate);
    const escapedName = escapeHtml(tree.name);

    treesHtml += `<section class="tree">`;
    treesHtml += `<div class="tree-header">`;
    treesHtml += `<div class="tree-title-row">`;
    treesHtml += `<h2 class="tree-name">${escapedName}</h2>`;
    treesHtml += rootBadge;
    treesHtml += `</div>`;
    treesHtml += `<p class="tree-root-pred">${escapedPred}</p>`;
    treesHtml += `</div>`;
    treesHtml += `<ul class="node-list">`;
    for (let i = 0; i < tree.children.length; i++) {
      treesHtml += renderNodeHtml(tree.children[i], 0, i === tree.children.length - 1);
    }
    treesHtml += `</ul>`;
    treesHtml += `</section>`;
  }

  if (treesHtml === "") {
    treesHtml = `<p class="empty">No fractal trees found in .fractal/</p>`;
  }

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Fractal Loop</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display:ital@0;1&family=Inter:wght@300;400;500&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    /* --- Palette --- */
    :root {
      --bg:        #FAF8F5;
      --surface:   #F4F0EB;
      --border:    #E5DDD5;
      --text:      #1A1814;
      --text-muted:#8C7B6E;
      --accent:    #C4773B;
      --accent-bg: #FDF0E8;
      --sat-bg:    #E8F4EC;
      --sat-fg:    #2D6A4F;
      --pru-bg:    #F5E8E8;
      --pru-fg:    #8C4A4A;
      --pend-bg:   #F5F0E8;
      --pend-fg:   #8C7B6E;
    }

    /* --- Reset & base --- */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      background: var(--bg);
      color: var(--text);
      font-family: 'Inter', system-ui, sans-serif;
      font-weight: 400;
      font-size: 14px;
      line-height: 1.6;
      min-height: 100vh;
    }

    /* --- Layout --- */
    .page {
      max-width: 860px;
      margin: 0 auto;
      padding: 56px 48px 80px;
    }

    /* --- Header --- */
    .site-header {
      margin-bottom: 32px;
      padding-bottom: 28px;
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
      gap: 24px;
    }

    .site-title {
      font-family: 'DM Serif Display', Georgia, serif;
      font-size: 42px;
      font-weight: 400;
      letter-spacing: -0.02em;
      line-height: 1;
      color: var(--text);
    }

    .site-subtitle {
      font-size: 11px;
      font-weight: 500;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--text-muted);
      margin-top: 8px;
    }

    .site-meta {
      text-align: right;
      flex-shrink: 0;
    }

    .meta-date {
      font-size: 13px;
      color: var(--text-muted);
      font-weight: 400;
    }

    .meta-time {
      font-family: 'JetBrains Mono', monospace;
      font-size: 11px;
      color: var(--text-muted);
      opacity: 0.7;
      margin-top: 3px;
    }

    /* --- Legend --- */
    .legend {
      display: flex;
      gap: 12px;
      margin-bottom: 36px;
      flex-wrap: wrap;
    }

    /* --- Badge --- */
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-size: 10px;
      font-weight: 500;
      letter-spacing: 0.04em;
      padding: 2px 8px;
      border-radius: 100px;
      white-space: nowrap;
      flex-shrink: 0;
    }

    /* --- Tree section --- */
    .tree {
      margin-bottom: 48px;
      animation: fadeUp 0.4s ease both;
    }

    .tree + .tree {
      padding-top: 40px;
      border-top: 1px solid var(--border);
    }

    .tree-header {
      margin-bottom: 20px;
    }

    .tree-title-row {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 8px;
    }

    .tree-name {
      font-family: 'DM Serif Display', Georgia, serif;
      font-size: 22px;
      font-weight: 400;
      letter-spacing: -0.01em;
      color: var(--text);
    }

    .tree-root-pred {
      font-size: 13px;
      color: var(--text-muted);
      font-style: italic;
      line-height: 1.5;
      max-width: 680px;
    }

    /* --- Node list --- */
    .node-list, .node-children {
      list-style: none;
      padding: 0;
      margin: 0;
    }

    /* --- Individual node --- */
    .node {
      position: relative;
    }

    .node-row {
      display: flex;
      align-items: baseline;
      gap: 10px;
      padding: 5px 8px;
      margin: 0 -8px;
      border-radius: 6px;
      transition: background 0.12s ease;
    }

    .node-row:hover {
      background: rgba(196, 119, 59, 0.05);
    }

    /* --- Connector lines --- */
    .node-children {
      padding-left: 20px;
      position: relative;
    }

    .node-children::before {
      content: '';
      position: absolute;
      left: 8px;
      top: 0;
      bottom: 12px;
      width: 1px;
      background: var(--border);
    }

    .node-children > .node > .node-row > .node-connector {
      position: relative;
      width: 12px;
      flex-shrink: 0;
      align-self: center;
    }

    .node-children > .node > .node-row > .node-connector::before {
      content: '';
      position: absolute;
      left: -12px;
      top: 50%;
      width: 12px;
      height: 1px;
      background: var(--border);
    }

    /* Top-level nodes: no connector */
    .node-list > .node > .node-row > .node-connector {
      display: none;
    }

    /* --- Slug --- */
    .node-slug {
      font-family: 'JetBrains Mono', monospace;
      font-size: 10px;
      font-weight: 500;
      color: var(--text-muted);
      opacity: 0.65;
      white-space: nowrap;
      flex-shrink: 0;
      letter-spacing: 0.01em;
      width: 170px;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    /* --- Predicate text --- */
    .node-predicate {
      color: var(--text);
      font-size: 13.5px;
      line-height: 1.45;
      flex: 1;
      min-width: 0;
    }

    .node-active > .node-row .node-predicate {
      color: var(--accent);
      font-weight: 500;
    }

    /* --- Depth-based muting --- */
    .depth-1 > .node-row .node-predicate { color: #2E2A26; }
    .depth-2 > .node-row .node-predicate { color: #4A443E; }
    .depth-3 > .node-row .node-predicate { color: #5E5650; }
    .depth-4 > .node-row .node-predicate,
    .depth-5 > .node-row .node-predicate,
    .depth-6 > .node-row .node-predicate { color: var(--text-muted); }

    /* --- Empty state --- */
    .empty {
      color: var(--text-muted);
      font-style: italic;
      padding: 32px 0;
    }

    /* --- Animations --- */
    @keyframes fadeUp {
      from { opacity: 0; transform: translateY(6px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    .tree:nth-child(1) { animation-delay: 0ms; }
    .tree:nth-child(2) { animation-delay: 60ms; }
    .tree:nth-child(3) { animation-delay: 120ms; }
    .tree:nth-child(4) { animation-delay: 180ms; }
    .tree:nth-child(5) { animation-delay: 240ms; }

    /* --- Live indicator --- */
    .live-dot {
      display: inline-block;
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: var(--accent);
      margin-right: 4px;
      animation: pulse 2s ease-in-out infinite;
      vertical-align: middle;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.35; }
    }

    /* --- Reload flash --- */
    body.reloading {
      opacity: 0.5;
      transition: opacity 0.15s ease;
    }
  </style>
</head>
<body>
  <div class="page">
    <header class="site-header">
      <div>
        <h1 class="site-title">Fractal Loop</h1>
        <p class="site-subtitle"><span class="live-dot"></span>predicate tree &middot; live</p>
      </div>
      <div class="site-meta">
        <div class="meta-date">${dateStr}</div>
        <div class="meta-time">${timestamp}</div>
      </div>
    </header>

    <div class="legend">
      <span class="badge" style="background:var(--sat-bg);color:var(--sat-fg)">● satisfied</span>
      <span class="badge" style="background:var(--pend-bg);color:var(--pend-fg)">○ pending</span>
      <span class="badge" style="background:var(--pru-bg);color:var(--pru-fg)">× pruned</span>
      <span class="badge" style="background:var(--accent-bg);color:var(--accent)">▸ active</span>
    </div>

    ${treesHtml}
  </div>

  <script>
    const ws = new WebSocket('ws://localhost:${PORT}');
    ws.onmessage = () => { document.body.classList.add('reloading'); setTimeout(() => location.reload(), 150); };
    ws.onclose = () => setTimeout(() => location.reload(), 1000);
  </script>
</body>
</html>`;
}

// --- WebSocket clients ---
const wsClients = new Set<ServerWebSocket<unknown>>();
const broadcast = (msg: string) => { for (const ws of wsClients) ws.send(msg); };

// --- Start watcher ---
startWatcher([FRACTAL_DIR], broadcast);

// --- HTTP server ---
Bun.serve({
  port: PORT,
  fetch(req, server) {
    if (server.upgrade(req)) return undefined;
    const url = new URL(req.url);
    if (url.pathname === "/" || url.pathname === "/tree") {
      return new Response(renderPage(), { headers: { "Content-Type": "text/html; charset=utf-8" } });
    }
    return new Response("Not Found", { status: 404 });
  },
  websocket: {
    open(ws) { wsClients.add(ws); },
    close(ws) { wsClients.delete(ws); },
    message() {},
  },
});

process.stderr.write(`[fractal-server] running on http://localhost:${PORT}\n`);
process.stderr.write(`[fractal-server] watching: ${FRACTAL_DIR}\n`);
