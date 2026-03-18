---
description: "Transforms a fractal predicate into an executable plan with self-contained deliverables, dependency graph, and human gates. Use after /fractal:run produces a predicate.md."
argument-hint: "path to the fractal node directory (e.g. .fractal/node-slug)"
allowed-tools: AskUserQuestion
user-invocable: false
---

# /fractal:planning

## Human gates

Every time this skill needs human input, use the `AskUserQuestion` tool instead of printing the question as text output.

Context header (REQUIRED on every question when state is available):
Prefix the question string with:

📍 <breadcrumb> | <state>
🎯 <active_predicate (max 80 chars)>

<actual question>

Variables come from the pre-loaded State section. If state is not yet loaded (e.g., early steps of /fractal:propose before tree detection), omit the header.

IMPORTANT: The header must be plain text. No markdown formatting (no **, ##, *, etc.) in the question string. Emojis are fine as visual anchors.

You are an execution architect. Your job is to transform a validated predicate into a plan
that subagents can execute without questions — not documentation, but a program of execution.

Input: $ARGUMENTS

---

## Core principle

The plan is not documentation. It's a program.

Each deliverable must be a **falsifiable slice**: the smallest unit of work that
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
If predicate.md not found: stop with "No predicate found. Run /fractal:run first."

Read in parallel:
1. `predicate.md` — the falsifiable condition. This IS the requirement.
2. `.claude/project.md` — build, test, hot files, stack.

### Load standards

After reading project.md, check for a standards file in the target repo:

```bash
STANDARDS="$REPO_ROOT/.claude/standards.md"
if [ -f "$STANDARDS" ]; then
  STD_BRANCH_PREFIX=$(grep "^branch-prefix:" "$STANDARDS" | sed 's/^branch-prefix: //')
  STD_STALENESS=$(grep "^staleness-check:" "$STANDARDS" | awk '{print $2}')
fi
```

Report: `Standards: loaded (branch-prefix: X, staleness-check: Y)` or `Standards: not found`

If `STD_STALENESS` is `true`: before building the plan, check whether existing plan artifacts in the node directory (e.g. `plan.md`) are older than 7 days. If so, warn:
`Warning: plan artifacts are >7 days old — consider re-evaluating before continuing`

If `STD_BRANCH_PREFIX` is set: use it as the default branch prefix in all deliverable prompts, overriding any `branch-prefix` from project.md.

### Load project context

Scan the `.fractal/` tree to understand what has already been built. This provides the agent with awareness of sibling nodes, previous deliveries, and accumulated project state.

```bash
# Find the tree root (parent of the node directory that contains root.md)
TREE_DIR=$(dirname "$NODE_DIR")
while [ ! -f "$TREE_DIR/root.md" ] && [ "$TREE_DIR" != "$REPO_ROOT/.fractal" ]; do
  TREE_DIR=$(dirname "$TREE_DIR")
done

# Read root predicate
ROOT_PRED=$(grep "^predicate:" "$TREE_DIR/root.md" | sed 's/^predicate: //' | tr -d '"')

# Find all satisfied nodes
find "$TREE_DIR" -name "predicate.md" -exec grep -l "status: satisfied" {} \;

# For each satisfied node, extract: predicate text + files from results.md
```

Build this block and keep it in working memory:

```
[PROJECT CONTEXT — auto-loaded from .fractal/]
Tree: <tree-name>
Root: "<root predicate>"

Satisfied nodes:
- <slug>: "<predicate>"
  achieved: <1-2 sentences from conclusion.md "What was achieved">
  capabilities: <new APIs, utilities, patterns, or files now available for reuse>
  files: <comma-separated from results.md files_changed, or conclusion.md if no results.md>
  deferred: <deferred items from conclusion.md, or "none">

Pending siblings: <slugs of sibling nodes with status: pending>
Active: <current node path>
```

**Source priority:** Read `conclusion.md` as the primary source for each satisfied node (always exists). Use `results.md` as complement for file lists. Branch nodes satisfied by synthesis (`satisfied_by: synthesis`) have no `results.md` — only `conclusion.md`.

If no satisfied nodes exist: omit the "Satisfied nodes" section entirely.
If the tree has only the current node: show only Root and Active.

Use this context when:
- Writing deliverable prompts (include relevant prior work as context for the subagent)
- Assessing scope (avoid re-implementing what a satisfied node already delivered)
- Identifying dependencies on prior deliveries (files that were created by earlier nodes)

### Compounding constraint (MANDATORY)

When writing deliverable prompts, you MUST:
- Reference sibling capabilities that the deliverable should USE, not re-implement
- Include relevant code paths/patterns from sibling files in the "Context" section of each prompt
- If a sibling added an API, utility, or pattern that this deliverable could use, the prompt MUST say: "Use <X> from <path> (built by <sibling>)" — not leave it implicit
- If no sibling capabilities are relevant to a deliverable, explicitly note in the prompt: "No sibling dependencies for this deliverable"

The deliverable prompt is where compounding happens or dies. A prompt that doesn't mention what siblings built produces isolated work.

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

If the predicate looks too broad, use `AskUserQuestion` with the context header:

Question string:
"📍 <breadcrumb> | PLANNING\n🎯 <active_predicate>\n\nEste predicado parece cobrir múltiplas hipóteses independentes. Continuar com plano maior ou subdividir?\n\nSubdividir: volte para /fractal:run e crie nós filhos para cada hipótese.\nContinuar: o plano será maior e menos preciso."

Options: "Sim, continuar com plano maior" / "Voltar para /fractal:run e subdividir"

The user may have good reasons to keep it together — honor their choice either way.

### Flag assumptions

If there are assumptions to validate (missing scope, missing project config, or inferred values), use `AskUserQuestion` with the context header:

Question string:
"📍 <breadcrumb> | PLANNING\n🎯 <active_predicate>\n\nAssumptions que precisam de validação:\n<list each assumption on its own line, e.g.:\n- Scope: <interpreted scope>\n- Build: <inferred command>\n- Test: <inferred command>>\n\nEstão corretos?"

Options: "Correto, prosseguir" / "Preciso ajustar"

If the user selects "Preciso ajustar", ask which assumption is wrong and what the correct value is, then update your working context before proceeding.

---

## How to decompose

This is the hard part. Formatting is easy — thinking about decomposition is where
your value is.

### The falsifiable slice

Every deliverable must be a falsifiable slice. Ask yourself:

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
**Human test:** <plain language — what the user should do and what they should observe, no CLI commands>
```

The **Human test** describes what the user should physically do to verify the deliverable works.
Write it as if explaining to someone who knows the product but not the codebase:
- "Open X, do Y, observe Z" — not "run npm test"
- Focus on the observable outcome, not the implementation
- If the deliverable has no user-facing component, write "No manual test needed — covered by automated validation"

All deliverables serve the same predicate — the node's falsifiable condition. The predicate line in each deliverable restates which aspect of the predicate this deliverable advances (for clarity, not traceability).

### Browser validation for UI deliverables

> Se o deliverable envolver alterações de UI/UX no viewer HTML, consulte `references/paper-design-protocol.md` para iterar no design via Paper MCP antes de escrever o prompt do subagente.

When a deliverable produces user-visible UI (web pages, components, screens), the
**Human test** section should describe steps the user can verify via Chrome browser
automation (`mcp__claude-in-chrome__*` tools). Examples:

- "Open http://localhost:3000/settings → verify the toggle appears"
- "Navigate to the dashboard → screenshot shows the chart rendered"
- "Fill the form and submit → success message appears"

During delivery, the orchestrator can use Chrome tools to pre-validate UI deliverables
before marking them as success. This catches visual regressions, broken layouts, and
missing elements that automated tests miss.

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
- [ ] Has a human-readable test that a non-technical person could follow
- [ ] If UI-facing: human_test includes browser-verifiable steps (Chrome automation)

---

## Functional requirements

Before writing deliverables, extract the **functional requirements** from the predicate.
These are the testable conditions that, taken together, satisfy the predicate.

```markdown
## Functional Requirements

FR1: <testable condition extracted from the predicate>
validates: <which part of the predicate this covers>
verified_by: D<N> acceptance | human_test T<N> | browser check

FR2: <testable condition>
validates: <predicate aspect>
verified_by: D<N> acceptance | human_test T<N>
```

Rules:
- Every FR must be falsifiable — you can unambiguously say "yes this works" or "no it doesn't"
- Every FR must map to at least one deliverable's acceptance or human_test
- Every critical aspect of the predicate must be covered by at least one FR
- FRs that require human observation (UX, visual, flow) → `verified_by: human_test`
- FRs that can be automated → `verified_by: D<N> acceptance`

The review skill uses FRs as the primary checklist. If an FR has no `verified_by`,
the review cannot confirm the predicate is satisfied.

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
See `templates/schemas.md` for the full format.

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
human_test: Open the app, perform <core action>, verify <observable result>

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
human_test: No manual test needed — covered by automated validation

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
human_test: Open <screen>, trigger <action>, verify <expected response>
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

After presenting the plan, use `AskUserQuestion` with the context header:

Question string:
"📍 <breadcrumb> | PLANNING\n🎯 <active_predicate>\n\nPlano completo com <N> deliverables em <M> batches. Aprova?"

Options: "Aprovar plano" / "Ajustar" / "Ver detalhes"

Response handling:
- "Aprovar plano" → save plan.md
- "Ajustar" → ask what should change, revise, and re-present (use AskUserQuestion again)
- "Ver detalhes" → present the full subagent prompts, then re-ask for approval

---

## Save plan.md

After approval, save to the node directory:
`${NODE_DIR}/plan.md`

Use the template from `templates/plan-template.md` as the base structure.

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
| Plan with 9+ deliverables | The predicate is too broad — go back to /fractal:run and subdivide into child nodes |
| Opus as default executor | Sonnet executes. Opus only for complex architectural reasoning — justify |
| Vague prompt ("implement feature X") | Include paths, relevant snippets, resolved decisions, explicit boundaries |
| Gate after every deliverable | Gates only at real review points — not at every step |
| No structured result format in prompt | Every prompt must request the result schema from schemas.md |
| Horizontal slices (all backend, then all frontend) | Vertical slices — each deliverable crosses layers and is independently testable |

---

## When NOT to use

- No predicate exists → run `/fractal:run` first
- Predicate is a draft (not falsifiable) → refine with `/fractal:run` first
- Plan already exists and is approved → run `/fractal:delivery`
- Trivial change that doesn't need a plan → go straight to code
