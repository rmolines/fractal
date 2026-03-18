# Schemas

Machine-readable formats used across the fractal plugin skills.

---

## Schema 1: Structured Result (subagent → orchestrator)

Every subagent spawned by `/fractal:delivery` must return its result in this format. The orchestrator parses it to decide next steps: proceed to next batch, retry the task, or escalate to the human.

### Format

```
## Result

task_id: D1
status: success
summary: Implemented the JWT middleware and wired it into the Express router. All protected routes now reject unauthenticated requests.
errors:
validation_result: PASS — 42 tests passed, 0 failed (npm test)

files_changed:
- src/middleware/auth.ts
- src/routes/index.ts
- tests/middleware/auth.test.ts
```

### Field rules

| Field | Type | Rules |
|---|---|---|
| `task_id` | string | Must match a deliverable ID in plan.md (e.g. `D1`, `D2`, `M1`) |
| `status` | enum | `success` / `partial` / `failed` |
| `summary` | string | 1–2 sentences. What was done, not what was attempted. Past tense. |
| `errors` | list or empty | One error per line, prefixed with `- `. Empty if status is `success`. |
| `validation_result` | string | Verbatim output or summary of the validation command defined in the plan. Include pass/fail verdict. |
| `files_changed` | list | One path per line, prefixed with `- `. Paths relative to repo root. |

### Status semantics

- **success** — validation passed, task is complete. Orchestrator proceeds.
- **partial** — core logic done but validation did not fully pass (e.g. 1 flaky test). Orchestrator may retry or escalate.
- **failed** — task could not be completed or validation failed. Orchestrator retries up to `max_retries`, then escalates to human.

### Parsing (grep/awk)

```bash
STATUS=$(grep "^status:" result.md | awk '{print $2}')
TASK_ID=$(grep "^task_id:" result.md | awk '{print $2}')
FILES=$(awk '/^files_changed:/{found=1; next} found && /^- /{print substr($0,3)} found && /^$/{exit}' result.md)
```

---

## Schema 2: Execution DAG in plan.md

The `## Execution DAG` section is a machine-readable declaration of all deliverables, their dependencies, and execution parameters. It coexists with the human-readable `## Batches` and ASCII graph sections — it does not replace them.

`/fractal:delivery` reads this section to build the execution graph, determine batch order, and configure each subagent.

### Format

Add this section to `plan.md` after `## Batches`:

```markdown
## Execution DAG

<!-- DAG format: one task per block, fields are key: value -->

task: D1
title: Set up JWT auth middleware
depends_on:
executor: haiku
isolation: none
batch: 1
files: src/middleware/auth.ts, src/routes/index.ts
max_retries: 2
acceptance: npm test -- --testPathPattern=auth passes with 0 failures

task: D2
title: Add protected routes
depends_on: D1
executor: sonnet
isolation: worktree
batch: 2
files: src/routes/protected.ts, tests/routes/protected.test.ts
max_retries: 1
acceptance: npm run build exits 0 and bundle size < 500kB

task: M1
title: Verify integration and regressions
depends_on: D1, D2
executor: sonnet
isolation: worktree
batch: 3
files: tests/integration/auth.test.ts
max_retries: 2
acceptance: npm test exits 0, no regressions vs baseline
```

### Field rules

| Field | Type | Rules |
|---|---|---|
| `task` | string | Unique deliverable ID. Must match IDs used in the Batches section. |
| `title` | string | Short human-readable title for the deliverable. |
| `depends_on` | string or empty | Comma-separated list of task IDs that must have `status: success` before this task runs. Leave empty for no dependencies. |
| `executor` | enum | `haiku` (mechanical, well-scoped) / `sonnet` (reasoning required, integrations) |
| `isolation` | enum | `worktree` (changes need isolation from main branch) / `none` (safe to work in current branch) |
| `batch` | int | Which batch this task belongs to. Tasks in the same batch run in parallel. |
| `files` | string | Comma-separated list of key files touched. Brief — for human overview, not exhaustive. |
| `max_retries` | int | How many times orchestrator retries on `failed` before escalating. Typical range: 1–3. |
| `acceptance` | string | The exact command or assertion used to validate completion. Must be runnable. |

### Isolation guidance

Use `worktree` when:
- The task touches shared infrastructure (router, DB schema, auth layer)
- Parallel tasks in the same batch could conflict on the same files
- You want a clean rollback if the task fails

Use `none` when:
- Task is additive only (new file, new test, new migration)
- Task is sequential and no parallel task touches overlapping files

### Parsing (grep/awk)

```bash
# Extract all task IDs
TASKS=$(awk '/^## Execution DAG/{found=1} found && /^task:/{print $2}' plan.md)

# Extract fields for a specific task (e.g. D1)
get_field() {
  local task_id=$1 field=$2
  awk -v tid="$task_id" -v f="$field" '
    /^task:/ { current = $2 }
    current == tid && $0 ~ "^" f ":" { sub(/^[^:]+: ?/, ""); print; exit }
  ' plan.md
}

EXECUTOR=$(get_field D1 executor)
DEPENDS=$(get_field D1 depends_on)
TITLE=$(get_field D1 title)
BATCH=$(get_field D1 batch)
FILES=$(get_field D1 files)
ACCEPTANCE=$(get_field D1 acceptance)
```

---

## Schema 3: Discovery Output (discovery.md)

The evaluator writes this file after each evaluation of a predicate node. `/fractal:run` reads it to route the node. Saved to the active node directory.

**Ephemeral on branch parents:** when ASCEND returns to a parent node, the parent's `discovery.md` is deleted to force re-evaluation. Child nodes retain their `discovery.md`.

### Format

```markdown
---
response: new_child | complete | leaf | unachievable
confidence: high | medium | low
reasoning: "analysis considering existing children"
child_predicate: "proposed child predicate"
child_type: risk | acquisition | scope
prd_seed: "one-sentence scope for the PRD"
leaf_type: patch | cycle | action
incerteza: high | medium | low
impacto: high | medium | low
retorno: high | medium | low
created: YYYY-MM-DD
---

# Discovery notes

What was found, what informed the decision. For re-evaluations: what changed since last visit.
```

### Field rules

| Field | Type | Rules |
|---|---|---|
| `response` | enum | `new_child` (propose 1 child) / `complete` (no more children needed) / `leaf` (directly satisfiable) / `unachievable` (cannot be satisfied) |
| `confidence` | enum | `high` / `medium` / `low` (best guess, may need human override) |
| `reasoning` | string | Thorough analysis. Most valuable part — considers existing children and their conclusions. |
| `child_predicate` | string | `new_child` only. One verifiable predicate for the proposed child. |
| `child_type` | enum | `new_child` only. `risk` (validate feasibility) / `acquisition` (learn from real world) / `scope` (execute known work). |
| `prd_seed` | string | `leaf` only. One sentence scoping the PRD. For `action` leaves: what evidence the human should bring back. |
| `leaf_type` | enum | `leaf` only. `patch` (trivial, 1-3 files) / `cycle` (full sprint) / `action` (human acts in real world, reports evidence). |
| `incerteza` | enum | max(executabilidade, coerência, verificabilidade). See LAW.md anchors. |
| `impacto` | enum | How much satisfying this moves the parent toward satisfied. |
| `retorno` | enum | Value gained relative to effort required. |
| `created` | date | YYYY-MM-DD |

### Response semantics

- **new_child** — the predicate needs decomposition. One child is proposed. The evaluator is called again after the child is resolved (or in dry run, after the child is mapped). Risk/acquisition children are proposed before scope children.
- **complete** — all necessary children exist (or the predicate needs no children and is already a satisfiable branch). No more decomposition needed.
- **leaf** — the predicate is directly satisfiable without children. `prd_seed` and `leaf_type` specify how.
- **unachievable** — the predicate cannot be satisfied given current constraints. `/fractal:run` will propose pruning.
- **confidence: low** — `/fractal:run` should present with extra emphasis on human validation.

### Parsing

```bash
RESPONSE=$(grep "^response:" discovery.md | awk '{print $2}')
CONFIDENCE=$(grep "^confidence:" discovery.md | awk '{print $2}')
CHILD_PREDICATE=$(grep "^child_predicate:" discovery.md | sed 's/^child_predicate: //' | tr -d '"')
PRD_SEED=$(grep "^prd_seed:" discovery.md | sed 's/^prd_seed: //' | tr -d '"')
LEAF_TYPE=$(grep "^leaf_type:" discovery.md | awk '{print $2}')
```

---

## Schema 4: Review Findings (review.md)

`/fractal:review` writes this file after every evaluation. Downstream skills (`/fractal:planning`, `/fractal:delivery`) read it on entry to detect amendment mode.

### Format

```markdown
# Review Findings
_Node: <node-path>_
_Date: <date>_
_Diff analyzed: <git ref range>_

## Decision
decision: approved | back-to-delivery | back-to-planning | back-to-fractal
reason: <1-2 sentence justification>

## Predicate Status
| Criterion | Status | Note |
|-----------|--------|------|
| Predicate: "<predicate text>" | PASS / PARTIAL / FAIL | <evidence or gap> |

## Action Items
Items that the next phase must address. Each item is self-contained — the receiving skill should be able to act on it without session context.
- <specific, actionable item with file paths where relevant>

## Evaluator Summary
<Key findings from the evaluator subagent — condensed for downstream consumption>
```

### Field rules
| Field | Rules |
|---|---|
| `decision` | One of: `approved`, `back-to-delivery`, `back-to-planning`, `back-to-fractal` |
| `reason` | Must explain *why* this decision, not just restate the criteria status |
| Action Items | Each item must be actionable without session context. Include file paths. |

### Parsing
```bash
DECISION=$(grep "^decision:" review.md | awk '{print $2}')
```

---

## Schema 5: Delivery Results (results.md)

`/fractal:delivery` writes this file after all batches complete. It persists the per-deliverable results that would otherwise be lost when the chat session ends. Saved to the active node directory.

### Format

```markdown
task: D1
status: success
summary: Implemented JWT middleware and wired into Express router
files_changed: src/middleware/auth.ts, src/routes/index.ts
validation_result: 42 tests passed, 0 failed

task: D2
status: partial
summary: Template updated but missing tags field
files_changed: templates/prd-template.md
errors: tags field not included in frontmatter
validation_result: head -10 shows 5/6 fields
```

### Field rules

| Field | Type | Rules |
|---|---|---|
| `task` | string | Matches a deliverable ID in the Execution DAG (e.g. `D1`, `D2`, `M1`) |
| `status` | enum | `success` / `partial` / `failed` / `skipped` |
| `summary` | string | Past tense, 1–2 sentences. What was done (or not done). |
| `files_changed` | string or empty | Comma-separated paths. Empty if no files were touched. |
| `errors` | string or empty | Description of what went wrong. Only when status != `success`. Leave empty otherwise. |
| `validation_result` | string | Output of the acceptance command or summary of what was verified. |

### Status semantics

- **success** — validation passed, task is complete.
- **partial** — core logic done but validation did not fully pass. May be retried or escalated to human.
- **failed** — task could not be completed or validation failed after max_retries.
- **skipped** — task was not run (e.g. because a dependency failed).

### Parsing (grep/awk)

```bash
# Extract all task IDs and their status
awk '/^task:/ {task=$2} /^status:/ {print task, $2}' results.md

# Extract fields for a specific task (e.g. D1)
get_result_field() {
  local task_id=$1 field=$2
  awk -v tid="$task_id" -v f="$field" '
    /^task:/ { current = $2 }
    current == tid && $0 ~ "^" f ":" { sub(/^[^:]+: ?/, ""); print; exit }
  ' results.md
}

STATUS=$(get_result_field D1 status)
SUMMARY=$(get_result_field D1 summary)
ERRORS=$(get_result_field D1 errors)
```

---

## Schema 6: PRD (prd.md)

The specify step writes this file for leaf nodes after discovery classifies them. `/fractal:planning` reads it as the primary requirement source — acceptance criteria map directly to functional requirements and deliverables. Saved to the active node directory.

### Format

```markdown
---
predicate: "the verifiable condition from predicate.md"
verification: objective | subjective
created: YYYY-MM-DD
---

## Acceptance Criteria

- AC1: <verifiable criterion that maps to a deliverable>
- AC2: <verifiable criterion that maps to a deliverable>
- AC3: <verifiable criterion>

## Out of Scope

- <explicitly excluded item>
- <explicitly excluded item>

## Constraints

- <technical constraint>
- <design constraint>
```

### Field rules

| Field | Type | Rules |
|---|---|---|
| `predicate` | string | Copied exactly from the node's `predicate.md`. Must match. |
| `verification` | enum | `objective` (agent can self-assess via tests/metrics) / `subjective` (requires human judgment). Optional — omit for standard fractal trees. Populated from evaluator output in objection trees. |
| `created` | date | YYYY-MM-DD |
| Acceptance Criteria | list | Each criterion is verifiable — you can unambiguously say "yes" or "no". Each maps to at least one deliverable in the eventual plan. |
| Out of Scope | list | Items explicitly excluded. `/fractal:review` checks for violations. |
| Constraints | list | Technical or design constraints that deliverables must respect. |

### Semantics

- `prd.md` only exists on **leaf** nodes. Branch nodes never have one.
- Acceptance criteria are the primary input for `/fractal:planning`'s FR extraction.
- Out of Scope items are hard gates in `/fractal:review` — any violation → back to planning.
- The human validates `prd.md` before sprint begins. Rejection → re-specify.

### Parsing

```bash
PREDICATE=$(grep "^predicate:" prd.md | sed 's/^predicate: //' | tr -d '"')
# Acceptance criteria (list items under ## Acceptance Criteria)
AC=$(awk '/^## Acceptance Criteria/{found=1; next} found && /^- /{print} found && /^##/{exit}' prd.md)
```

---

## Schema 9: Test Checklist (test-checklist.md)

`/fractal:delivery` writes this file after all batches complete. It persists what the human needs to manually validate. The human marks pass/fail. `/fractal:review` reads it as input for evaluation.

### Format

```markdown
# Test Checklist
_Node: <node-path>_
_Generated: <YYYY-MM-DD>_

## How to use
1. Run each test below
2. Mark [x] for pass, [ ] for fail
3. Add notes for any failures
4. Run /fractal:review when done

test: T1
title: <human-readable test name>
validates: <which aspect of the predicate this tests>
from: D<N>
steps:
- <step 1 in plain language>
- <step 2 in plain language>
expected: <what you should see>
result: [ ]
notes:

test: T2
...
```

### Field rules

| Field | Type | Rules |
|---|---|---|
| `test` | string | Unique test ID (T1, T2, ...) |
| `title` | string | Human-readable name — what is being tested, not how |
| `validates` | string | Which aspect of the predicate this test covers |
| `from` | string | Which deliverable generated this test (D1, D2, etc.) |
| `steps` | list | Plain language steps — no CLI commands unless unavoidable |
| `expected` | string | Observable outcome in plain language |
| `result` | checkbox | `[ ]` unchecked by default, `[x]` when human confirms pass |
| `notes` | string | Human writes failure details here. Empty if pass. |

### Parsing (grep/awk)

```bash
# Extract all test IDs and results
awk '/^test:/ {id=$2} /^result:/ {print id, $0}' test-checklist.md

# Count pass/fail
PASS=$(grep -c '^result: \[x\]' test-checklist.md)
FAIL=$(grep -c '^result: \[ \]' test-checklist.md)
```
