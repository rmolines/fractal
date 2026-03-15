# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

OpenPredicaTree (aka "fractal") — a Claude Code plugin that implements a recursive predicate primitive for human+agent collaboration. Instead of task lists, the agent decomposes goals into falsifiable predicates and works on the riskiest unknown first. One operation, repeated at any scale.

**Version:** 0.4.1 | **Plugin manifest:** `.claude-plugin/plugin.json`

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
  discover(predicate)        → branch | leaf | unachievable
  if unachievable            → prune
  if leaf, patch can satisfy → patch → human validates
  if leaf, cycle needed      → prd → plan → build → review → ship → human validates
  if branch                  → find riskiest child → human validates → recurse
```

### Skill chain (execution order)

1. `/fractal:init` — bootstrap: extract objective, create tree
2. `/fractal:run` — idempotent state machine (main entry point, call repeatedly)
3. `/fractal:patch` — fast path for trivial leaf predicates
4. `/fractal:planning` → `/fractal:delivery` → `/fractal:review` → `/fractal:ship` — sprint cycle for complex predicates
5. `/fractal:doctor` — tree integrity validation

Skills live in `commands/`. The evaluate subagent lives in `agents/evaluate.md`.

### On-disk state (`.fractal/` in target repo)

The filesystem IS the state. No database, no JSON.

- `root.md` — root predicate + `active_node` pointer (always exactly one per tree)
- `predicate.md` — per node: falsifiable condition, status (`pending|satisfied|pruned|candidate`)
- `discovery.md` — per node (after evaluation): node_type (`branch|leaf`), classification
- `prd.md` — leaf nodes only: acceptance criteria, out-of-scope, constraints
- Execution state derived from artifact presence:
  - Only `predicate.md` → not started
  - `discovery.md` exists (branch) → discovered, decompose into children
  - `discovery.md` exists (leaf, no prd) → discovered, write prd
  - `discovery.md` + `prd.md` → specified (run sprint)
  - `plan.md` exists → planned (run delivery)
  - `plan.md` + `results.md` → executed (run review)
  - `plan.md` + `results.md` + `review.md` → reviewed (validate, then ship)
- `learnings.md` — accumulated human corrections (read on every `/fractal:run` entry)

Directory name = kebab-case slug of predicate. Nesting = depth.

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
- `references/statechart.ts` — XState v5 formal statechart (documentation)

## Conventions

- One tree per repo, one active node per tree — enforced by `/fractal:init` and `/fractal:doctor`
- Human validates at two moments: proposal (predicate makes sense) and result (predicate satisfied)
- Every transition persists to disk BEFORE acting (idempotency guarantee)
- Subagents always use `model: "sonnet"`, never opus
- The evaluate subagent (`agents/evaluate.md`) runs discovery — classifies nodes as branch or leaf
- `AskUserQuestion` tool for all human gates (never plain text questions)
