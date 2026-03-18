# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Fractal — recursive project management for Claude Code. A plugin that decomposes goals into predicates and works on the riskiest unknown first. One operation, repeated at any scale.

**Version:** 0.8.0 | **Plugin manifest:** `.claude-plugin/plugin.json`

## Commands

```bash
# Test the state machine
bash scripts/fractal-state.sh

# View tree state (auto-discovers single tree in .fractal/)
bash scripts/fractal-tree.sh

# Read active predicate
bash scripts/active-predicate.sh
```

No build step. No dependencies. Pure shell scripts + markdown skills.

## Architecture

### The primitive

```
fractal(predicate):
  evaluate(predicate, existing_children)  → new_child | complete | leaf | unachievable
  if unachievable            → prune
  if leaf                    → specify → execute → human validates
  if new_child               → create child → human validates → recurse → re-evaluate parent
  if complete                → validate branch satisfaction or select next pending child
```

### Skill chain (execution order)

1. `/fractal:init` — bootstrap: extract objective, create tree
2. `/fractal:run` — idempotent state machine (main entry point, call repeatedly)
3. `/fractal:patch` — fast path for trivial leaf predicates
4. Sprint agent (`agents/sprint.md`) — runs the full cycle `/fractal:planning` → `/fractal:delivery` → `/fractal:review` → `/fractal:ship` as a single Sonnet subagent with no human gates
5. `/fractal:doctor` — tree integrity validation
6. `/standards:generate` — inspect repo and generate `.claude/standards.md` (called by `/fractal:init` when no standards.md exists)

Skills live in `commands/`. Subagents live in `agents/` (evaluate, sprint, patch-worker).

### On-disk state (`.fractal/` in target repo)

The filesystem IS the state. No database, no JSON.

- `root.md` — root predicate + `active_node` pointer (always exactly one per tree)
- `predicate.md` — per node: verifiable condition, status (`pending|satisfied|pruned`)
- `discovery.md` — per node (after evaluation): evaluator response (`new_child|complete|leaf|unachievable`). Ephemeral on parents — deleted when child ascends.
- `prd.md` — leaf nodes only: acceptance criteria, out-of-scope, constraints
- Execution state derived from artifact presence:
  - Only `predicate.md` → not started
  - `discovery.md` exists (new_child) → create proposed child, recurse
  - `discovery.md` exists (leaf, no prd) → specify, write prd
  - `discovery.md` + `prd.md` → specified (run sprint)
  - `plan.md` exists → planned (run delivery)
  - `plan.md` + `results.md` → executed (run review)
  - `plan.md` + `results.md` + `review.md` → reviewed (validate, then ship)
- `conclusion.md` — per node (after satisfaction): what was achieved, key decisions, deferred items
- `learnings.md` — accumulated human corrections (read on every `/fractal:run` entry)

Directory name = kebab-case slug of predicate. Nesting = depth.

### Tree as context (progressive disclosure)

The tree is the single source of truth for project state. Navigate it in three levels:
1. **Tree shape** — `bash scripts/fractal-tree.sh` (what exists, status of each node)
2. **Conclusions** — read `conclusion.md` from satisfied nodes (what was achieved)
3. **Sprint artifacts** — read `prd.md`, `plan.md`, etc. from specific nodes (implementation details)

When entering a branch, read conclusions of satisfied children before acting. Full protocol: `references/context-protocol.md`.

### Scripts (`scripts/`)

- `fractal-state.sh` — reads tree state from filesystem, outputs key-value pairs (tree, active_node, depth, state, children counts, artifact presence). Core of idempotency.
- `fractal-tree.sh` — ASCII tree renderer for the predicate hierarchy
- `active-predicate.sh` — reads and prints the active predicate text

All scripts auto-discover the single tree in `.fractal/` when called without arguments.

### Key design documents

- `LAW.md` — complete formal specification of the primitive
- `THEORY.md` — theoretical grounding and related work
- `references/filesystem.md` — filesystem schema and conventions
- `references/learnings.md` — protocol for capturing human invalidations
- `templates/schemas.md` — schemas for cycle artifacts (plan, results, review)
- `references/context-protocol.md` — how the agent navigates the tree for progressive context loading
- `references/statechart.ts` — XState v5 formal statechart (documentation)

## Conventions

- One tree per repo, one active node per tree — enforced by `/fractal:init` and `/fractal:doctor`
- **Session locks (`session.lock`) use `$PPID` — the PID of the invoking shell**, not the Claude process. Each `bash scripts/session-lock.sh` call spawns a short-lived shell; that shell's PID is freed immediately after the call returns. If the OS recycles the PID for an unrelated process, `pid_alive` returns `true` and the lock appears active forever. If `select-next-node.sh` reports `reason: all_pending_locked` but no parallel session is running, execute `bash scripts/session-lock.sh cleanup` from the repo root to clear stale locks. Locks are gitignored and invisible to `git status`.
- Human validates at two moments: proposal (predicate makes sense) and result (predicate satisfied)
- Every transition persists to disk BEFORE acting (idempotency guarantee)
- Subagents use `model: "sonnet"` by default. Exception: the evaluate subagent (`agents/evaluate.md`) uses `model: "opus"` — it's the highest-leverage decision point in the system and runs once per node
- The evaluate subagent (`agents/evaluate.md`) runs incremental evaluation — decides next step for each predicate (new_child, complete, leaf, or unachievable)
- `AskUserQuestion` tool for all human gates (never plain text questions)
