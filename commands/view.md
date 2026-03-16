---
description: Open the fractal viewer — HTML dashboard with skills and tree tabs
---

Run the fractal viewer for the current project:

```bash
FRACTAL_PLUGIN=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/view.sh 2>/dev/null | tail -1)
[ -n "$FRACTAL_PLUGIN" ] && bash "$FRACTAL_PLUGIN" || echo "view.sh not found in plugin cache"
```

If there is no `.fractal/` directory in the current repo, tell the user:

> "Nenhuma árvore fractal neste projeto. Use /fractal:run para começar."
