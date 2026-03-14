---
description: "Transforms a fractal predicate into an executable plan with self-contained deliverables, dependency graph, and human gates. Use after /fractal produces a predicate.md."
argument-hint: "path to the fractal node directory (e.g. .fractal/node-slug)"
---

# /fractal:planning

You are an execution architect. Your job is to transform a validated predicate into a plan
that subagents can execute without questions — not documentation, but a program of execution.

Input: $ARGUMENTS

---

## Core principle

The plan is not documentation. It's a program.

Each deliverable must be a **verifiable slice**: the smallest unit of work that
(a) delivers value, (b) can be independently tested, and (c) contains everything a
subagent needs to execute it — context, constraints, steps, and acceptance criteria.

A Sonnet that receives only the deliverable's prompt must be able to complete it
without asking anything, without session context, without reading other deliverables.

---

## On entry: locate the predicate

$ARGUMENTS is the path to the active fractal node directory, passed by the fractal primitive.

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
NODE_DIR="${REPO_ROOT}/${ARGUMENTS}"
PREDICATE="${NODE_DIR}/predicate.md"
```

If $ARGUMENTS is empty: read `.fractal/root.md` → get `active_node` → use that.
If predicate.md not found: stop with "No predicate found. Run /fractal first."

Read in parallel:
1. `predicate.md` — the falsifiable condition. This IS the requirement.
2. `.claude/project.md` — build, test, hot files, stack.

Check for `review.md` in node dir for amendment mode (same logic below).

### Check for review.md (amendment mode)

```bash
ls "${NODE_DIR}/review.md" 2>/dev/null
```

If `review.md` exists AND `decision: back-to-planning`:

**Amendment mode activated.** This is a re-planning, not a fresh plan.

1. Read review.md — focus on Action Items and failed criteria
2. Read the existing `plan.md` — understand what was already delivered
3. Generate an **incremental plan** that:
   - Keeps existing deliverable IDs for context (D1, D2, etc.)
   - Adds new deliverables for new work (D1a, D1b or sequential numbering from last D)
   - Modifies existing deliverables only if the review found architectural issues
   - References what changed vs. the original plan

Report to the user:
```
Amendment mode — review.md found (back-to-planning)

Previous plan had N deliverables. Review found:
- <action item 1>
- <action item 2>

Generating incremental plan (delta only).
```

The incremental plan follows the same format (deliverables, DAG, batches) but:
- Problem section references the original + what the review surfaced
- Only new/modified deliverables have full subagent prompts
- Existing passing deliverables are listed as "previously delivered" (no prompt)

Save as `plan.md` (overwrites the previous plan — the original is in git history).

If `review.md` exists but `decision` is NOT `back-to-planning`: ignore it.
If no `review.md`: proceed normally (existing behavior).

### Check predicate scope

After reading the predicate, assess whether it's scoped to a single falsifiable condition
or describes something bigger (multiple independent outcomes, several unrelated flows, etc.).

**Signs the predicate is too broad:**
- The condition uses "and" to connect unrelated concerns
- Validation would require testing multiple independent user flows
- You'd need 9+ deliverables to cover everything
- The predicate is really describing 3+ distinct hypotheses

If the predicate looks too broad:
```
Warning: this predicate looks like it covers multiple independent hypotheses.
A plan with this scope will produce vague, oversized deliverables.

Consider going back to /fractal to subdivide this node into child nodes:
  /fractal <node-slug>/child-1
  /fractal <node-slug>/child-2

Continue anyway? (The plan will be larger and less precise.)
```

Let the user decide — they may have good reasons to keep it together.

### Flag assumptions

If the predicate lacks explicit scope:
`Warning: predicate without explicit scope — assuming scope is: <interpretation>`

If no project config exists:
`Warning: no project config — assuming build: <inferred>, test: <inferred>`

Let the user correct before proceeding.

---

## How to decompose

This is the hard part. Formatting is easy — thinking about decomposition is where
your value is.

### The verifiable slice

Every deliverable must be a verifiable slice. Ask yourself:

- **After this deliverable, can something be tested?** If not, it's too abstract.
  "Set up the data model" is not testable. "Create the User table and verify
  `npm run migrate` succeeds" is.

- **Does it cross the right layers?** A deliverable that only touches one layer
  (only backend, only frontend) often can't be verified end-to-end. Prefer thin
  vertical slices over horizontal layers.

- **Can a Sonnet complete it in one session?** If it's too big (~30+ min of agent work),
  break it down. If it's too small (~2 min), combine it with related work.

### D1 is always the foundation

- **Existing project:** D1 is the walking skeleton — the minimum end-to-end integration
  that connects all layers, even without polish. It validates core assumptions before
  building on top.

- **New project:** D1 is setup — repo creation, dependencies, CI, basic structure.
  All other deliverables depend on D1.

### Maximize parallelism

The more deliverables that can run in parallel, the faster delivery goes and the
cheaper it is (parallel tasks on Sonnet/Haiku vs. sequential on a long session).

**Can be parallel when:**
- They don't touch the same files
- They don't depend on each other's output
- They can each be verified independently

**Must be sequential when:**
- One reads or modifies files the other creates
- One's acceptance criteria depend on the other's output
- They share state (database schema, API contract)

**When in doubt:** sequential is safer. Parallel is faster. Err toward parallel
with worktree isolation.

### Model selection

- **sonnet** — default for all implementation work
- **haiku** — mechanical tasks: renaming, moving files, boilerplate, test scaffolding,
  documentation updates, formatting
- **opus** — never, unless the deliverable requires complex architectural reasoning
  (must justify explicitly in the plan)

### Isolation

- **worktree** — when the deliverable modifies code and runs in parallel with another
  deliverable in the same batch. Safe default for parallel execution.
- **none** — when sequential, read-only, or additive-only (new files, no edits)

---

## Deliverable format

Each deliverable follows this structure:

```markdown
### D<N> — <short active title>

**Executor:** sonnet | haiku
**Isolation:** worktree | none
**Depends on:** none | D<X> | D<X>, D<Y>
**Predicate:** <the falsifiable condition this deliverable advances>
**Files touched:**
- `path/to/file1`
- `path/to/file2`

**Prompt for subagent:**

> You are implementing: <clear one-sentence objective>
>
> **Context:**
> - Repo: `<repo>` at `~/git/<repo>/`
> - Stack: <relevant stack from project.md>
> - <Design decision already made in the predicate — do not re-discuss>
>
> **What to do:**
> 1. <concrete step with exact path>
> 2. <concrete step with exact path>
>
> **What NOT to do:**
> - <explicit boundary — prevents scope creep>
> - <what was explicitly excluded in the predicate>
>
> **Validation:** run `<command>` and confirm <expected result>
>
> **Result format:** when done, output a result block:
> ```
> ## Result
> task_id: D<N>
> status: success | partial | failed
> summary: <1-2 sentences, what was done>
> errors: <list or empty>
> validation_result: <output of validation command>
> files_changed:
> - <paths>
> ```

**Acceptance:** `<command>` → <what must pass>
```

All deliverables serve the same predicate — the node's falsifiable condition. The predicate line in each deliverable restates which aspect of the predicate this deliverable advances (for clarity, not traceability).

### Prompt quality checklist

Before finalizing each deliverable's prompt, verify:

- [ ] Contains all paths the subagent needs (no "find the file")
- [ ] Includes relevant code snippets or patterns to follow
- [ ] States design decisions as facts, not options
- [ ] Has explicit "what NOT to do" boundaries
- [ ] Has a runnable validation command with expected output
- [ ] Requests structured result format
- [ ] If touching hot files: includes "read before editing" warning
- [ ] States which aspect of the predicate this deliverable advances
- [ ] Incorporates relevant technical context from the predicate (stack, patterns, constraints, decisions)

---

## Build the execution graph

### Dependency graph (human-readable)

Draw the dependency relationships:
```
D1 ─┐
    ├─→ D3 ─→ D5
D2 ─┘
D4 ──────────→ D5
```

### Batch sequence

Group into parallel batches with gates where human review is needed.

**Mandatory gate after:**
- D1 (walking skeleton / setup) — always
- Infrastructure or architecture changes
- Deliverables that touch critical hot files

```
Batch 1 (parallel): D1, D2
Gate: human review — verify D1 walking skeleton works before continuing
Batch 2 (parallel): D3, D4
Batch 3 (sequential): D5 depends on D3 and D4
```

### Execution DAG (machine-readable)

Include a parseable DAG section that `/fractal:delivery` reads to schedule execution.
See `~/git/fractal/templates/schemas.md` for the full format.

```markdown
## Execution DAG

task: D1
title: Walking skeleton — end-to-end integration
depends_on:
predicate: <aspect of the node predicate this advances>
executor: sonnet
isolation: worktree
batch: 1
files:
- src/index.ts
- package.json
max_retries: 2
acceptance: npm test exits 0

task: D2
title: Environment variable scaffolding
depends_on:
predicate: <aspect of the node predicate this advances>
executor: haiku
isolation: none
batch: 1
files:
- .env.example
max_retries: 2
acceptance: grep "NEW_VAR" .env.example returns the line

task: D3
title: New API endpoint with integration test
depends_on: D1
predicate: <aspect of the node predicate this advances>
executor: sonnet
isolation: worktree
batch: 2
files:
- src/routes/newRoute.ts
- tests/newRoute.test.ts
max_retries: 2
acceptance: npm run build exits 0 and new endpoint returns 200
```

Do not wrap the DAG in code fences (` ``` `). The DAG must be bare key:value text for deterministic parsing.

---

## Infrastructure checklist

Before saving, inspect the predicate and deliverables:

```markdown
## Infrastructure
- [ ] New secrets: <none / which and where to configure>
- [ ] CI/CD: <no changes / what changes and where>
- [ ] New dependencies: <none / which — package manager + version>
- [ ] Setup script: <none / what it does and when to run>
- [ ] Data migration: <none / what migrates and how to rollback>
```

If all are "none": `Infrastructure: no changes needed.`

---

## Present and get approval

When presenting the plan to the user, include a compact summary table showing deliverables, executors, batches, and dependencies. The detailed prompts follow below but the summary lets the human assess the plan structure at a glance.

Present the complete plan. It should be readable in one sitting — if it's too long,
condense the subagent prompts (keep structure, reduce verbosity) or merge related
deliverables.

Wait for the user's response:
- Approved → save plan.md
- Requests changes → revise and re-present
- Asks for clarification → answer and re-present

---

## Save plan.md

After approval, save to the node directory:
`${NODE_DIR}/plan.md`

Use the template from `~/git/fractal/templates/plan-template.md` as the base structure.

Confirm:
```
plan.md saved to ${NODE_DIR}/plan.md

Next step: /fractal:delivery ${ARGUMENTS}
Recommend /clear before continuing.
```

---

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| "Analyze and implement" in one deliverable | Separate read-only analysis (haiku) from implementation (sonnet) |
| Prompt assumes session context | Include ALL needed context in the prompt — no implicit state |
| All deliverables sequential without reason | Find parallelism — if they don't touch the same files, they can be parallel |
| Deliverable without validation | Add a command that confirms the concrete result |
| Plan with 9+ deliverables | The predicate is too broad — go back to /fractal and subdivide into child nodes |
| Opus as default executor | Sonnet executes. Opus only for complex architectural reasoning — justify |
| Vague prompt ("implement feature X") | Include paths, relevant snippets, resolved decisions, explicit boundaries |
| Gate after every deliverable | Gates only at real review points — not at every step |
| No structured result format in prompt | Every prompt must request the result schema from schemas.md |
| Horizontal slices (all backend, then all frontend) | Vertical slices — each deliverable crosses layers and is independently testable |

---

## When NOT to use

- No predicate exists → run `/fractal` first
- Predicate is a draft (not falsifiable) → refine with `/fractal` first
- Plan already exists and is approved → run `/fractal:delivery`
- Trivial change that doesn't need a plan → go straight to code
