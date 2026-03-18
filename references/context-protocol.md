# Context Protocol — Tree as Living Memory

The fractal tree is the single source of truth for project state. This protocol describes how an agent navigates the tree for context using progressive disclosure.

## Three levels of detail

**Level 1 — Tree shape (always cheap):**
Run `bash scripts/fractal-tree.sh` to see all nodes, their status, and the active pointer. This answers: "what exists, what's done, what's in progress."

**Level 2 — Conclusions (moderate cost):**
Read `conclusion.md` from satisfied nodes to understand what was achieved. Each conclusion is 5-10 lines oriented toward the parent predicate. This answers: "what do I know about this project?"

**Level 3 — Sprint artifacts (expensive, on demand):**
Read `prd.md`, `plan.md`, `results.md`, `review.md` from specific nodes only when you need implementation details. This answers: "how exactly was this done?"

## When to load what

| Situation | Load |
|---|---|
| Starting a new session | Level 1 (tree shape) |
| Entering a branch node | Level 2 (conclusions of satisfied children) |
| Re-evaluating a branch for satisfaction | Level 2 (all children's conclusions) |
| Understanding a specific implementation | Level 3 (that node's sprint artifacts) |
| Writing a conclusion for a branch | Level 2 (children's conclusions to synthesize) |

## Reading conclusions efficiently

To get project context without loading every file:

```bash
# Find all conclusions in the tree
find .fractal -name "conclusion.md" -type f

# Read just the "What was achieved" from each
for f in $(find .fractal -name "conclusion.md" -type f); do
  echo "--- $(dirname $f | sed 's|.fractal/||') ---"
  sed -n '/## What was achieved/,/## /p' "$f" | head -5
done
```

## For /fractal:init — install in target repos

When `/fractal:init` creates a tree in a new repo, it should also:

1. Add a block to the repo's CLAUDE.md (or create it):

```markdown
## Fractal Loop tree

This repo uses a fractal predicate tree in `.fractal/` for project management.
Run `bash scripts/fractal-tree.sh` to see current state.
For project context, read `conclusion.md` files from satisfied nodes.
See `references/context-protocol.md` in the fractal plugin for the full navigation protocol.
```

2. Optionally create `.claude/rules/fractal-nav.md` in the target repo:

```markdown
---
paths:
  - ".fractal/**"
---
# Fractal Loop tree navigation

When reading files in .fractal/:
- conclusion.md contains what was achieved (oriented toward parent predicate)
- discovery.md contains the evaluator's last response (ephemeral — deleted on re-evaluation)
- predicate.md contains the verifiable condition and status
- Read conclusions of satisfied siblings before proposing new children for a branch
```

This path-scoped rule loads only when the agent touches .fractal/ files, adding zero cost to sessions that don't interact with the tree.

## Design rationale

The tree already follows the four context engineering patterns (Lance Martin, 2025):
- **Write** — filesystem persistence in `.fractal/`
- **Select** — `active_node` + `select-next-node.sh` choose what to work on
- **Compress** — `conclusion.md` summarizes each satisfied node
- **Isolate** — subagents (evaluate, delivery) work in separate context windows

The progressive disclosure aligns with HiAgent (ACL 2025): subgoals as memory chunks, summaries replace detailed trajectories after completion, detail retrieval on demand.
