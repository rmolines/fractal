---
description: Open the fractal viewer — real-time HTML dashboard with live tree updates
---

Open the fractal viewer for the current project. Prefers the real-time bun server (with WebSocket live-reload) when available, falls back to the static HTML viewer.

First check if `.fractal/` exists. If not, tell the user: "Nenhuma árvore fractal neste projeto. Use /fractal:run para começar."

Then launch the viewer:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd) && SERVER_TS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/server/server.ts 2>/dev/null | tail -1) && if [ -n "$SERVER_TS" ] && command -v bun &>/dev/null; then if lsof -i :3333 &>/dev/null 2>&1; then echo "Server already running on port 3333"; else FRACTAL_REPO="$REPO_ROOT" nohup bun run "$SERVER_TS" >/dev/null 2>&1 & sleep 1 && echo "Server started on port 3333"; fi; open "http://localhost:3333" 2>/dev/null || xdg-open "http://localhost:3333" 2>/dev/null || echo "Open http://localhost:3333 in your browser"; else FRACTAL_PLUGIN=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/view.sh 2>/dev/null | tail -1); [ -n "$FRACTAL_PLUGIN" ] && bash "$FRACTAL_PLUGIN" "$REPO_ROOT" || echo "No viewer available. Install bun for the real-time viewer."; fi
```

If the real-time server started, tell the user: "Viewer real-time rodando em localhost:3333. Mudanças em .fractal/ atualizam o browser automaticamente via WebSocket."

If it fell back to the static viewer, tell the user it opened the static HTML and suggest installing bun for the real-time experience.
