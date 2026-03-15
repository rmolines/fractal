---
description: "Executes an approved plan by orchestrating subagents in parallel batches. Use after /fractal:planning produces an approved plan.md."
argument-hint: "path to the fractal node directory (e.g. .fractal/node-slug)"
allowed-tools: AskUserQuestion
user-invocable: false
---

# /fractal:delivery

## Human gates

Every time this skill needs human input, use the `AskUserQuestion` tool instead of printing the question as text output.

Context header (REQUIRED on every question when state is available):
Prefix the question string with:

📍 <breadcrumb> | <state>
🎯 <active_predicate (max 80 chars)>

<actual question>

Variables come from the pre-loaded State section. If state is not yet loaded (e.g., early steps of /fractal:propose before tree detection), omit the header.

IMPORTANT: The header must be plain text. No markdown formatting (no **, ##, *, etc.) in the question string. Emojis are fine as visual anchors.

You are the orchestrator (Opus thread) executing an approved plan.
Subagents do the implementation. You coordinate, validate, and unblock.

Input: $ARGUMENTS

---

## Core principle

The plan is the contract — execute it faithfully.

Don't improvise deliverables not in the plan. Don't skip validations. Don't re-derive
the execution order — read it from the Execution DAG. Subagents never spawn other
subagents. All orchestration flows from this thread.

---

## On entry: locate and validate the plan

$ARGUMENTS is the path to the active fractal node directory.

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
NODE_DIR="${REPO_ROOT}/${ARGUMENTS}"
PLAN="${NODE_DIR}/plan.md"
PREDICATE="${NODE_DIR}/predicate.md"
PRD="${NODE_DIR}/prd.md"
```

If $ARGUMENTS is empty: read `.fractal/root.md` → get `active_node`.
If plan.md not found: "No plan.md found. Run /fractal:planning first."

Read in parallel:
1. `plan.md` — especially `## Execution DAG`
2. `predicate.md` — the verifiable condition for this node (the product reference)
3. `prd.md` — acceptance criteria (leaf nodes only; provides concrete validation targets)
4. `.claude/project.md` — build/test commands, hot files

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
- <slug>: "<predicate>" → files: <comma-separated from results.md files_changed>
- <slug>: "<predicate>" → files: <comma-separated from results.md files_changed>

Pending siblings: <slugs of sibling nodes with status: pending>
Active: <current node path>
```

If no satisfied nodes exist: omit the "Satisfied nodes" section entirely.
If the tree has only the current node: show only Root and Active.

Use this context when:
- Writing deliverable prompts (include relevant prior work as context for the subagent)
- Assessing scope (avoid re-implementing what a satisfied node already delivered)
- Identifying dependencies on prior deliveries (files that were created by earlier nodes)

**Critical:** Read project.md in the same parallel batch as plan.md/predicate.md.
The build/test commands come from project.md — without it, baseline check will fail
with wrong commands.

### Load standards

After reading project.md, check for a standards file in the target repo:

```bash
STANDARDS="$REPO_ROOT/.claude/standards.md"
if [ -f "$STANDARDS" ]; then
  STD_BUILD=$(grep "^build:" "$STANDARDS" | sed 's/^build: //')
  STD_TEST=$(grep "^test:" "$STANDARDS" | sed 's/^test: //')
  STD_LINT=$(grep "^lint:" "$STANDARDS" | sed 's/^lint: //')
  STD_TYPECHECK=$(grep "^type-check:" "$STANDARDS" | sed 's/^type-check: //')
  STD_FORMAT=$(grep "^format:" "$STANDARDS" | sed 's/^format: //')
  STD_COAUTHOR=$(grep "^co-author:" "$STANDARDS" | sed 's/^co-author: //')
  STD_BRANCH_PREFIX=$(grep "^branch-prefix:" "$STANDARDS" | sed 's/^branch-prefix: //')
  STD_MAX_LINES=$(grep "^max-lines-per-file:" "$STANDARDS" | awk '{print $2}')
  STD_HOT_PREFLIGHT=$(grep "^hot-file-preflight:" "$STANDARDS" | awk '{print $2}')
fi
# Override project.md values with standards.md values (if present)
BUILD_CMD=${STD_BUILD:-$BUILD_CMD}
TEST_CMD=${STD_TEST:-$TEST_CMD}
BRANCH_PREFIX=${STD_BRANCH_PREFIX:-$BRANCH_PREFIX}
```

Report what was loaded:
- If standards.md exists: `Standards: loaded from .claude/standards.md (N fields)` — count non-empty STD_* variables
- If not: `Standards: not found, using project.md defaults`

### Parse the Execution DAG

Read the `## Execution DAG` section from plan.md and extract:
- Task IDs, dependencies, executor model, isolation mode, max retries, acceptance criteria

```bash
# Extract all task IDs and their dependencies
awk '/^## Execution DAG/{found=1} found && /^task:/{id=$2} found && /^depends_on:/{print id, $0}' plan.md
```

Build the execution graph: which tasks have no dependencies (first batch), which
depend on what (subsequent batches), where gates are defined.

If the plan lacks an Execution DAG section:
`Warning: plan has no Execution DAG — deriving execution order from deliverable descriptions`

### Check for review.md (amendment mode)

```bash
ls "${NODE_DIR}/review.md" 2>/dev/null
```

If `review.md` exists AND `decision: back-to-delivery`:

**Amendment mode activated.** Read the review findings and adapt execution:

1. Read the Action Items from review.md — these define what needs to be re-done
2. Read the Success Criteria Status — identify which criteria are FAIL or PARTIAL
3. Map action items back to deliverables in plan.md
4. Build a **reduced DAG** containing only:
   - Deliverables that map to failed action items
   - Deliverables that depend on those (transitively)
5. Skip all deliverables already marked as passing

Report to the user:
```
Amendment mode — review.md found (back-to-delivery)

Action items from review:
- <item 1>
- <item 2>

Deliverables to re-execute: D2, D4
Skipping (already passing): D1, D3

Proceed?
```

Wait for confirmation before executing.

If `review.md` exists but `decision` is NOT `back-to-delivery`: ignore it — wrong routing.
If no `review.md`: proceed normally (existing behavior, no changes).

### Validate before starting

Check for:
- Deliverables with self-contained prompts (if missing: `Warning: plan without subagent prompts — adapting`)
- Circular dependencies (stop and report)
- Deliverables without acceptance criteria (warn)
- Gate points in DAG (note: gates are opt-in — only pause where the plan explicitly sets gate: true)

If critical inconsistencies found: report to the user before starting.

---

## Branch setup

Before running any deliverable, ensure commits go to an isolated feature branch.

### Read branch config

```bash
BRANCH_PREFIX=$(grep "^branch-prefix:" .claude/project.md 2>/dev/null | sed 's/^branch-prefix: //' | head -1)
MAIN_BRANCH=$(grep "^main-branch:" .claude/project.md 2>/dev/null | sed 's/^main-branch: //' | head -1)
BRANCH_PREFIX=${BRANCH_PREFIX:-feat/}
MAIN_BRANCH=${MAIN_BRANCH:-main}
```

### Create or checkout feature branch

```bash
NODE_SLUG=$(basename "$NODE_DIR")
FEATURE_BRANCH="${BRANCH_PREFIX}${NODE_SLUG}"

git fetch origin

if git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH"; then
  # Branch exists (re-entry after /clear) — checkout
  git checkout "$FEATURE_BRANCH"
else
  # Create from origin/<main-branch>
  git checkout -b "$FEATURE_BRANCH" "origin/$MAIN_BRANCH"
fi
```

Report:
```
Branch: <feature branch name>
Base: origin/<main branch>
Status: created | checked out (existing)
```

All subsequent integration commits go to this branch. Do not push — push is handled by `/fractal:ship`.

---

## Baseline check (hard gate)

Before launching any subagent:

```bash
# Build
<build command from project.md>

# Tests
<test command from project.md>
```

If build or tests fail: **stop**. Report the failure. Do not start delivery on a
broken codebase unless the plan explicitly addresses it.

### Additional standards gates

After build and test pass, run standards-defined quality gates if set:

```bash
# Lint gate
if [ -n "$STD_LINT" ]; then
  $STD_LINT
  # If lint fails: stop and report. Do not continue.
fi

# Type-check gate
if [ -n "$STD_TYPECHECK" ]; then
  $STD_TYPECHECK
  # If type-check fails: stop and report. Do not continue.
fi
```

If `STD_LINT` or `STD_TYPECHECK` is not set (standards.md absent or field missing), skip these gates silently.

---

## Execution

### Launch by batch

> **Amendment mode:** if active, only launch deliverables in the reduced DAG.
> The enriched prompt for each re-executed deliverable must include the review's action items
> relevant to that deliverable in the `[EXECUTION CONTEXT]` block:
> ```
> [REVIEW FINDINGS — amendment mode]
> This deliverable is being re-executed because the previous attempt had issues.
> Action items from review:
> - <relevant action items for this deliverable>
> Previous issues:
> - <relevant criteria that were FAIL/PARTIAL>
> ```

For each batch of parallel deliverables:

1. **Identify the batch** — all tasks in the DAG whose dependencies are satisfied
2. **Enrich each prompt** with runtime context (see below)
3. **Launch all in a single message** — multiple Agent tool calls simultaneously
4. **Wait for all to complete** before processing results

```
Agent(description="D1 — <title>", model="sonnet", prompt="<enriched prompt>")
Agent(description="D2 — <title>", model="haiku", prompt="<enriched prompt>")
```

Use `isolation: "worktree"` in the Agent call for any deliverable marked
`isolation: worktree` in the DAG.

### Enrich prompts

Before sending the plan's prompt to a subagent, prepend runtime context:

```
[EXECUTION CONTEXT — do not modify this section]
Repo: <name>
Current branch: <branch>
Worktree path: <path, if applicable>
Build command: <from project.md, overridden by standards.md if present>
Test command: <from project.md, overridden by standards.md if present>
Hot files (read before editing): <list from project.md>
PRD acceptance criteria: <acceptance criteria from prd.md, or "No PRD — validate against predicate.md">
Project context (prior deliveries): <satisfied nodes summary from project context, or "First node — no prior deliveries">

[DELIVERABLE PROMPT]
<original prompt from the plan>
```

**Standards: hot-file preflight**

If `STD_HOT_PREFLIGHT` is `true`, extend the `[EXECUTION CONTEXT]` block with an explicit instruction for the subagent:

```
Hot files — MANDATORY preflight:
Read each of the following files BEFORE making any edits:
- <hot file 1 from project.md>
- <hot file 2 from project.md>
These files contain shared interfaces, tokens, or conventions that your edits must respect.
```

If `STD_HOT_PREFLIGHT` is not `true` (or standards.md is absent), the hot files line in the context block remains informational only (no mandatory instruction added).

If previous batches produced results relevant to this deliverable, append:
```
[RESULTS FROM PREVIOUS BATCHES]
D1: status: success — <summary>
D2: status: success — <summary>
```

The subagent receives no session context. Everything it needs is in the prompt.

### Process results

When a subagent returns, parse its structured result:

```
task_id: D<N>
status: success | partial | failed
summary: <what was done>
errors: <list or empty>
validation_result: <output of validation command>
files_changed: <list of paths>
```

Track each deliverable's result in memory as it completes. You will need all results to write results.md after the final batch.

**If `status: success`** — mark as complete, proceed.

**If `status: partial`** — check if retry would help. If `retries < max_retries`,
retry with the error context appended. Otherwise, proceed with a warning.

**If `status: failed`** — retry up to `max_retries` with error context:
```
[PREVIOUS ATTEMPT FAILED]
Error: <error from previous attempt>
Validation output: <what failed>

Please fix the issue and try again. The original prompt follows.

[DELIVERABLE PROMPT]
<original prompt>
```

After `max_retries` exhausted: **stop and report** to the user with full diagnosis.
Do not attempt to fix it yourself. Do not continue to the next batch.

**If the subagent returns narrative instead of structured result:** extract what you
can (status, files changed) and proceed, but note the deviation.

### Human gates (opt-in)

Gates only trigger at points where the Execution DAG explicitly sets `gate: true`.
No implicit gates — not even after Batch 1. If the plan didn't flag a gate, delivery
continues autonomously.

When a gate triggers:

```
## Gate — Batch 1 complete

Progress:
- D1 — <title>: success — <one-line summary>
- D2 — <title>: success — <one-line summary>

Next batch: D3, D4 (parallel)

Confirm to proceed, or adjust the plan.
```

Wait for explicit approval before continuing. If the user requests changes, adapt
the remaining plan accordingly.

---

## Integration

### Build and test

After all deliverables complete:

```bash
<build command>
<test command>
<smoke test, if defined in project.md>
```

Report: X/Y tests passing, any remaining failures.

### Worktree merge (if applicable)

If deliverables ran in worktree isolation:

1. Check for merge conflicts with the base branch
2. If no conflicts: merge cleanly
3. If conflicts exist: report the conflicting files and the deliverables that touched
   them. Attempt resolution preserving each deliverable's intent. Run build + tests
   after resolution.
4. If resolution is ambiguous: ask the user before proceeding

### Browser smoke test (UI deliverables)

After worktree merge and before committing, if the deliverable has a `human_test` that
references a URL or UI element, use Chrome automation tools to do a quick sanity check:

```
mcp__claude-in-chrome__navigate → target URL
mcp__claude-in-chrome__get_screenshot → visual check
```

If the browser check reveals broken UI (missing elements, layout errors, blank page):
treat it as a failed deliverable and retry. This catches critical regressions before
committing. Detailed per-test browser validation happens later in the
"Auto-validate test checklist" section after all deliverables complete.

### Integration commit

After each deliverable is integrated (worktree merge complete) and build + tests pass,
commit the changes immediately:

1. **Stage only the files listed in `files_changed`** from the subagent's structured result.
   Never use `git add -A` or `git add .` — stage file by file:
   ```bash
   git add <file1> <file2> ...   # files from files_changed only
   ```

2. **Commit with the canonical message format:**
   ```
   feat(<node-slug>): D<N> — <title>

   Co-Authored-By: <executor model> <noreply@anthropic.com>
   ```
   Where `<node-slug>` is `basename $NODE_DIR`, `<N>` is the deliverable number, and `<title>`
   is the deliverable title from the plan. Use the executor model declared in the DAG
   (e.g. `claude-sonnet-4-5`, `claude-haiku-4-5`).

   **Standards commit format validation:**
   - If `STD_FORMAT` is `conventional`: validate the commit message matches the conventional commits pattern (`^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\(.+\))?: .+`). If it does not match, rewrite the message to conform before committing.
   - If `STD_COAUTHOR` is set: append an additional `Co-Authored-By: $STD_COAUTHOR` trailer to every commit (in addition to the executor model trailer already present).

3. **If the commit fails due to a pre-commit hook:** fix the reported issue, re-stage
   the same files, and retry the commit. Do not skip hooks (`--no-verify`).

4. **In amendment mode:** follow the same pattern — one commit per re-executed
   deliverable, using the same message format.

Do not push. Push is handled by `/fractal:ship`.

### Standards: max-lines check

After each integration commit, if `STD_MAX_LINES` is set, check all files in `files_changed` from the subagent's structured result:

```bash
if [ -n "$STD_MAX_LINES" ]; then
  for f in <files_changed>; do
    LINE_COUNT=$(wc -l < "$f")
    if [ "$LINE_COUNT" -gt "$STD_MAX_LINES" ]; then
      echo "Warning: $f has $LINE_COUNT lines (limit: $STD_MAX_LINES)"
    fi
  done
fi
```

Append any warnings to the deliverable's result output. This is a non-blocking warning — do not stop delivery. The warning will be visible in results.md and the final report.

### Generate test-checklist.md

After persisting results.md, generate `test-checklist.md` in the node directory using Schema 9 format.

For each deliverable in the Execution DAG that has a `human_test:` field (and it's not "No manual test needed"):

1. Create a test entry (T1, T2, ...) with:
   - `title:` derived from the deliverable title
   - `validates:` copied from the `predicate:` field in the DAG
   - `from:` the deliverable ID (D1, D2, etc.)
   - `steps:` break down the `human_test:` text into numbered steps
   - `expected:` extract the expected observation from the human_test text
   - `result: [ ]` (unchecked — human fills this in)
   - `notes:` (empty — human fills this in)

2. Add the header:
   ```
   # Test Checklist
   _Node: <node-path>_
   _Generated: <YYYY-MM-DD>_

   ## How to use
   1. Run each test below
   2. Mark [x] for pass, [ ] for fail
   3. Add notes for any failures
   4. Run /fractal:review when done
   ```

3. Save to: `${NODE_DIR}/test-checklist.md`

If no deliverables have human tests: write a test-checklist.md with only the header and a note: "All deliverables validated automatically. No manual tests needed."

---

### Auto-validate test checklist

After generating test-checklist.md, attempt to automatically execute as many tests as possible. This reduces the human review burden and surfaces failures early.

#### 1. Classify each test

For each entry T1, T2, ... in test-checklist.md, inspect its `steps:` field and classify:

| Type | Classification criteria |
|---|---|
| `browser` | Steps mention URLs (http/https), "open", "navigate", "page", "screen", "click", "form", or UI element names |
| `cli` | Steps mention running commands, checking files, verifying output, reading logs |
| `manual` | Steps require human judgment: "verify the design feels right", "check accessibility", "confirm the copy reads well" |

#### 2. Execute browser tests

For each `browser` test, use Chrome automation tools:

```
mcp__claude-in-chrome__navigate → extract the target URL from the steps field
mcp__claude-in-chrome__get_page_text → extract page content
mcp__claude-in-chrome__find → locate elements expected by the test
```

Compare what is found against the test's `expected:` field. The test passes if the expected element or content is present; fails otherwise.

If Chrome automation tools are unavailable or raise an error, treat the test as `manual` (skip gracefully — do not block delivery).

#### 3. Execute CLI tests

For each `cli` test, run the command described in `steps:` using Bash with a **30-second timeout**:

```bash
timeout 30 <command from steps>
```

Compare the output against `expected:`. The test passes if output matches; fails if it does not or if the command times out.

#### 4. Skip manual tests

Leave `manual` tests with `result: [ ]` unchanged. They require human judgment and cannot be automated.

#### 5. Update test-checklist.md in place

After attempting auto-validation, rewrite only the `result:` and `notes:` fields for each test. Never modify `steps:` or `expected:`.

- **Test passed:** `result: [x]` + `notes: Auto-validated by delivery`
- **Test failed:** `result: [ ]` + `notes: Auto-validation failed: <reason>`
- **Test skipped (manual or tool unavailable):** `result: [ ]` + `notes: Requires human validation`

#### 6. Report auto-validation summary

After updating test-checklist.md, print:

```
## Auto-validation results
- T1: PASS (browser) — <what was verified>
- T2: PASS (cli) — <what was verified>
- T3: SKIPPED (manual) — requires human validation
- T4: FAIL (cli) — expected "200 OK", got "connection refused"

Auto-validated: N/M tests
Remaining for human: K tests
```

Track these numbers — `N` (passed), `M` (total), `K` (remaining for human) — for the final report.

#### Important rules

- Auto-validation is **best-effort**. A failed auto-validation does NOT block delivery.
- Auto-validated results (pass or fail) still appear in the review checklist. The human can override any result.
- CLI tests must have a 30-second timeout — do not let a hanging command stall delivery.
- Never modify `steps:` or `expected:` fields.

---

### Persist results

After all batches complete and before generating the final report, write `results.md` to the node directory:

```bash
${NODE_DIR}/results.md
```

Use Schema 5 format (see `templates/schemas.md`). For each deliverable, write one block with the fields: `task`, `status`, `summary`, `files_changed`, `errors`, `validation_result`. Blocks are separated by blank lines.

Include ALL deliverables — even skipped ones in amendment mode. For deliverables that were skipped, write:

```
task: D<N>
status: skipped
summary: Previously passing
files_changed:
errors:
validation_result:
```

Then generate `test-checklist.md` (see "Generate test-checklist.md" section above).

---

## Standards auto-update

After persisting results.md and test-checklist.md, check if the delivery introduced new standard-bearing files.

```bash
STANDARDS_SCRIPT="$REPO_ROOT/scripts/generate-standards.sh"

# Detect changed files matching standard-bearing patterns
CHANGED_STANDARDS=$(git diff origin/$MAIN_BRANCH...HEAD --name-only 2>/dev/null | grep -E \
  '(\.eslintrc|eslint\.config|\.stylelintrc|\.prettierrc|biome\.json|\
\.github/workflows/|\.github/actions/|Makefile|jest\.config|vitest\.config|\
pytest\.ini|\.mocharc|\.nvmrc|\.tool-versions|package\.json|pyproject\.toml|\
husky|lint-staged|commitlint|lefthook|\.editorconfig|tsconfig|jsconfig)' \
  | head -1)

if [ -n "$CHANGED_STANDARDS" ] && [ -f "$STANDARDS_SCRIPT" ]; then
  echo "Standards-bearing files detected — regenerating .claude/standards.md"
  bash "$STANDARDS_SCRIPT"
  # Commit updated standards.md if it changed
  if ! git diff --quiet "$REPO_ROOT/.claude/standards.md" 2>/dev/null; then
    git add "$REPO_ROOT/.claude/standards.md"
    git commit -m "chore: update standards.md after delivery

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
    echo "Standards: updated and committed."
  else
    echo "Standards: regenerated, no changes detected."
  fi
else
  # No new patterns or script not found — skip silently
  true
fi
```

---

## Final report

```
## Delivery complete — <feature name>

Deliverables:
- D1 — <title>: success
- D2 — <title>: success
- D3 — <title>: success

Build: passed
Tests: X/Y passed

Test checklist: <N> tests saved to <node-dir>/test-checklist.md
Auto-validated: <X>/<N> tests passed, <K> remaining for human

Next step: /fractal:review <path to node directory>
```

If there are unresolved failures:
```
Deliverables with issues:
- D3 — <title>: failed after 2 attempts
  Root cause: <diagnosis>
  Suggested next step: <action>
```

If amendment mode was active, the final report should note:
```
## Delivery complete (amendment) — <feature name>

Re-executed deliverables:
- D2 — <title>: success
- D4 — <title>: success

Skipped (from previous delivery):
- D1 — <title>: previously passing
- D3 — <title>: previously passing

Build: passed
Tests: X/Y passed

Next step: /fractal:review <path to node directory>
```

In amendment mode, skipped deliverables must also be written to results.md with `status: skipped` and `summary: Previously passing`. This ensures results.md is always a complete record of all deliverables regardless of amendment mode.

After successful amendment delivery, **delete review.md** to clear the amendment flag:
```bash
rm "${NODE_DIR}/review.md"
```
This prevents the next `/fractal:review` from seeing stale findings.

---

## Rules

| Rule | Detail |
|---|---|
| Plan is the contract | Execute faithfully. Don't add deliverables not in the plan. |
| Parse the DAG | Read execution order from `## Execution DAG`, don't re-derive it. |
| Baseline must pass | Never start on a broken codebase. |
| Gates are opt-in | Only pause at explicit `gate: true` in the DAG. No implicit gates, not even after D1. |
| 2 retries max per deliverable | After 2 failures: stop and report. Don't fix indefinitely. |
| Subagents don't spawn subagents | All orchestration from this thread. |
| Sonnet by default | Never use opus in a subagent without explicit justification in the plan. |
| Structured results | Expect and parse the result schema. Proceed on narrative but note it. |
| Worktree for parallel writes | If two deliverables run in the same batch and modify files, use worktree isolation. |
| Commit per deliverable | Stage only files_changed — never git add -A. Commit immediately after integration. |
| Feature branch isolation | Create feat/<node-slug> before execution. Never commit to main branch during delivery. |

---

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| Re-deriving execution order from descriptions | Parse the Execution DAG section |
| Launching all sequentially when parallelism is possible | If no shared files: launch in parallel |
| Continuing after 2 failures | Stop and report with full diagnosis |
| Subagent spawning subagent | Not possible — all launches from this thread |
| Ignoring structured result format | Parse task_id, status, errors — don't read as narrative |
| Skipping baseline check | Always verify build + tests before starting |
| Enriching prompt with session context | Only use runtime context block — no session state |
| Leaving changes uncommitted after integration | Commit per deliverable using files_changed from structured result |
| Committing directly to main/master | Create feature branch on entry — all commits go to feat/<node-slug> |

---

## When NOT to use

- No plan.md exists → run `/fractal:planning` first
- Plan not approved by human → get approval first
- Code already implemented and reviewed → run `/fractal:ship`
- Quick fix that doesn't need orchestration → do it directly
