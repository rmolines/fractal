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

const STATUS_ICON: Record<string, string> = { satisfied: "&#10003;", pruned: "&#10007;" };
const STATUS_COLOR: Record<string, string> = { satisfied: "#22c55e", pruned: "#ef4444" };

function statusIcon(s: string) { return STATUS_ICON[s] ?? "&#9675;"; }
function statusColor(s: string) { return STATUS_COLOR[s] ?? "#94a3b8"; }

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

function renderNodeHtml(node: NodeInfo, depth: number): string {
  const icon = statusIcon(node.status);
  const color = statusColor(node.status);
  const activeMarker = node.isActive ? ' <span style="color:#f59e0b;font-weight:bold">&#9664;</span>' : "";
  const indent = depth * 20;

  const truncated = node.predicate.length > 100 ? node.predicate.slice(0, 100) + "..." : node.predicate;
  const escapedPredicate = escapeHtml(truncated);
  const escapedFull = escapeHtml(node.predicate);

  let html = `<li style="margin:4px 0;padding-left:${indent}px">`;
  html += `<span style="color:${color};font-size:1.1em;margin-right:6px">${icon}</span>`;
  html += `<span class="slug" style="color:#64748b;font-size:0.85em;margin-right:6px">${node.slug}</span>`;
  html += `<span title="${escapedFull}" style="color:#e2e8f0">${escapedPredicate}</span>`;
  html += activeMarker;
  html += `</li>`;

  if (node.children.length > 0) {
    html += `<ul style="list-style:none;padding:0;margin:0">`;
    for (const child of node.children) {
      html += renderNodeHtml(child, depth + 1);
    }
    html += `</ul>`;
  }

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
  const timestamp = new Date().toLocaleString();

  let treesHtml = "";
  for (const tree of trees) {
    const icon = statusIcon(tree.rootStatus);
    const color = statusColor(tree.rootStatus);
    const escapedPred = escapeHtml(tree.rootPredicate);

    treesHtml += `<div class="tree" style="margin-bottom:32px">`;
    treesHtml += `<h2 style="color:#f1f5f9;margin:0 0 8px 0;font-size:1.1em">`;
    treesHtml += `<span style="color:${color};margin-right:6px">${icon}</span>${tree.name}`;
    treesHtml += `</h2>`;
    treesHtml += `<div style="color:#94a3b8;font-size:0.9em;margin-bottom:12px;padding-left:4px">${escapedPred}</div>`;
    treesHtml += `<ul style="list-style:none;padding:0;margin:0;font-family:monospace">`;
    for (const child of tree.children) {
      treesHtml += renderNodeHtml(child, 0);
    }
    treesHtml += `</ul>`;
    treesHtml += `</div>`;
  }

  if (treesHtml === "") {
    treesHtml = `<p style="color:#64748b">No fractal trees found in .fractal/</p>`;
  }

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Fractal Tree</title>
  <style>
    body { background:#0f172a; color:#e2e8f0; font-family:monospace; margin:0; padding:24px; }
    h1 { color:#f8fafc; font-size:1.4em; margin:0 0 4px 0; }
    .ts { color:#475569; font-size:0.8em; margin-bottom:24px; }
    li:hover { background:rgba(255,255,255,0.03); border-radius:4px; }
    .legend { display:flex; gap:16px; margin-bottom:24px; font-size:0.85em; color:#64748b; }
    .legend span { display:flex; align-items:center; gap:4px; }
  </style>
</head>
<body>
  <h1>Fractal Tree</h1>
  <div class="ts">Last loaded: ${timestamp}</div>
  <div class="legend">
    <span><span style="color:#22c55e">&#10003;</span> satisfied</span>
    <span><span style="color:#ef4444">&#10007;</span> pruned</span>
    <span><span style="color:#94a3b8">&#9675;</span> pending</span>
    <span><span style="color:#f59e0b">&#9664;</span> active</span>
  </div>
  ${treesHtml}
  <script>
    const ws = new WebSocket('ws://localhost:${PORT}');
    ws.onmessage = () => location.reload();
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
