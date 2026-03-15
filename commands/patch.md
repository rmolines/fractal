---
description: "Fast patch flow: implements in isolated worktree, presents result, user approves or discards. Use for changes where you already know what you want."
argument-hint: "description of the change"
allowed-tools: AskUserQuestion
---

# /fractal:patch

## Human gates

Every time this skill needs human input (confirmation, choice, correction), use the `AskUserQuestion` tool instead of printing the question as text output. This ensures the agent pauses and waits for the response before continuing.

You are a fast-iteration agent. The user knows what they want — your job is to
implement it in isolation, present the result, and let them decide what to do with it.

No PRD. No plan. No cycles. Just: implement → present → decide.

Input: $ARGUMENTS — description of the change to make. Required.

---

## On entry: detect context and parse arguments

### Detect project context

```bash
REPO_ROOT=""
REPO_NAME=""
if git rev-parse --is-inside-work-tree 2>/dev/null; then
  REPO_ROOT=$(git rev-parse --show-toplevel)
  REPO_NAME=$(grep "^alias:" "$REPO_ROOT/.claude/project.md" 2>/dev/null | sed 's/^alias: //' | head -1)
  [ -z "$REPO_NAME" ] && REPO_NAME=$(basename "$REPO_ROOT")
fi
```

Read `.claude/project.md` for:

```bash
SPEC="$REPO_ROOT/.claude/project.md"
BUILD_CMD=$(grep "^build:" "$SPEC" 2>/dev/null | sed 's/^build: //' | head -1)
TEST_CMD=$(grep "^test:" "$SPEC" 2>/dev/null | sed 's/^test: //' | head -1)
SMOKE_CMD=$(grep "^smoke:" "$SPEC" 2>/dev/null | sed 's/^smoke: //' | head -1)
DEPLOY_CMD=$(grep "^deploy:" "$SPEC" 2>/dev/null | sed 's/^deploy: //' | head -1)
HOT_FILES=$(awk '/^## Hot files/{found=1; next} found && /^- /{print substr($0,3)} found && /^##/{exit}' "$SPEC" 2>/dev/null)
```

### Parse arguments

`$ARGUMENTS` is the description of what to implement. It is **required**.

If empty: ask — "What do you want to implement? Describe the change."

### Generate slug

From the description, derive a slug: lowercase, hyphens only, max 30 chars.

```
"Add dark mode toggle to settings" → "add-dark-mode-toggle-settings"
"Fix pagination bug in user list"  → "fix-pagination-bug-user-list"
```

The worktree branch will be `patch-<slug>`. The worktree path will be
`.claude/worktrees/patch-<slug>` relative to repo root.

---

## Phase 1 — Complexity check

Before starting, assess whether the request fits `/fractal:patch`.

Signs it is **too complex**:
- Requires architectural decisions (new patterns, new abstractions)
- Touches 5+ files with interdependent logic that isn't mechanical
- Has ambiguous product or UX decisions that could go multiple directions
- Needs research or spikes to determine feasibility

If too complex, say:

> "I think this might be too complex for a quick patch — it involves [reason]. Want me
> to continue with `/fractal:patch`, or would `/fractal` be a better starting
> point?"

This is a suggestion, not a blocker. If the user says "continue" or "just do it" — proceed.

---

## Phase 2 — Clarification (0–2 questions, optional)

Default: **zero questions**. Start implementing.

Only ask if there is genuine ambiguity that would lead to significant rework — two
equally valid interpretations that produce different results. Before each question,
state what you are trying to decide and why.

Maximum 2 questions total. Never stack them.

Once clarification is done (or skipped), announce:

> "Implementing in isolated worktree..."

---

## Phase 3 — Implementation (subagent in worktree)

Launch a single subagent with `isolation: "worktree"` and `model: "sonnet"`:

```
Agent(
  description="patch: <slug>",
  model="sonnet",
  isolation="worktree",
  branch="patch-<slug>",
  worktree=".claude/worktrees/patch-<slug>",
  prompt="<implementation prompt below>"
)
```

### Implementation prompt

```
[EXECUTION CONTEXT — do not modify this section]
Repo: <REPO_NAME>
Repo root: <REPO_ROOT>
Current branch: <branch name>
Worktree path: .claude/worktrees/patch-<slug>
Build command: <BUILD_CMD or "not configured">
Test command: <TEST_CMD or "not configured">
Hot files (read before editing): <HOT_FILES or "none listed">

[TASK]
Implement the following change end-to-end:

<$ARGUMENTS>

[INSTRUCTIONS]
1. Read the hot files listed above before making any changes.
2. Implement the change completely — do not leave placeholders or TODOs.
3. After implementation, run build and test:
   <BUILD_CMD>
   <TEST_CMD>
4. Return a structured result in this exact format:

task_id: patch-<slug>
status: success | partial | failed
summary: <1-3 sentences describing what was done>
files_changed:
- <path/to/file>
build_output: <last few lines of build output, or "not configured">
test_output: <last few lines of test output, or "not configured">
errors: <list of errors, or empty>
```

Wait for the subagent to complete before proceeding.

---

## Phase 4 — Present results

Show the result clearly so the user can evaluate:

```
## Result — patch-<slug>

**Summary:** <subagent summary>

**Files changed:**
- <file 1>
- <file 2>

**Build:** passed | failed | not configured
**Tests:** passed | failed | not configured

**Diff:**
<git diff output from the worktree>

**Worktree:** .claude/worktrees/patch-<slug>
```

Fetch the diff:
```bash
git -C "$REPO_ROOT/.claude/worktrees/patch-<slug>" diff HEAD~1..HEAD
# or if the branch has a single commit:
git -C "$REPO_ROOT" diff main...patch-<slug>
```

Then ask:

> "What do you think? You can:
> - **approve** — merge, push, and create a PR
> - **adjust [something]** — I'll make the change and show you again
> - **discard** — clean up and forget it"

---

## Phase 5 — Decision loop

### Adjust

If the user requests an adjustment (any variation of "change X", "ajusta", "actually",
"instead", etc.):

Launch a new subagent in the **same worktree** with the adjustment request:

```
Agent(
  description="patch: <slug> — adjustment",
  model="sonnet",
  isolation="worktree",
  branch="patch-<slug>",
  worktree=".claude/worktrees/patch-<slug>",
  prompt="<adjustment prompt>"
)
```

Adjustment prompt:

```
[EXECUTION CONTEXT]
Repo: <REPO_NAME>
Worktree path: .claude/worktrees/patch-<slug>
Build command: <BUILD_CMD or "not configured">
Test command: <TEST_CMD or "not configured">

[CONTEXT]
The following change was already implemented:
<original $ARGUMENTS>

[ADJUSTMENT REQUESTED]
<user's adjustment request>

[INSTRUCTIONS]
Apply the adjustment to the existing implementation. Run build and test after.
Return a structured result in the same format as before.
```

After the subagent completes, present results again (Phase 4). Loop until the user
approves or discards.

### Discard

If the user says "discard", "descarta", "cancel", "drop", "never mind", or similar:

```bash
git worktree remove --force "$REPO_ROOT/.claude/worktrees/patch-<slug>"
git -C "$REPO_ROOT" branch -D "patch-<slug>"
```

Confirm:

> "Discarded. No changes made."

### Approve

If the user says "approve", "aprova", "ship it", "merge", "looks good", or similar:

Execute the ship-light flow inline:

**Step 1 — Merge worktree branch into current branch**

```bash
git -C "$REPO_ROOT" merge "patch-<slug>" --no-ff -m "feat: <$ARGUMENTS>"
```

If merge conflicts: list the conflicting files and ask for guidance. Do not force-merge.

**Step 2 — Build + test (hard gate)**

```bash
<BUILD_CMD>
<TEST_CMD>
```

If either fails: **stop**. Report the failure in full. Do not push. Do not create a PR.

> "Build/tests failed after merge. No PR created. The worktree branch `patch-<slug>` still
> exists — you can inspect it at `.claude/worktrees/patch-<slug>`."

**Step 3 — Push to remote**

```bash
git -C "$REPO_ROOT" push -u origin <current-branch>
```

**Step 4 — Create PR**

```bash
gh pr create --title "<$ARGUMENTS>" --body "$(cat <<'EOF'
## What was done
<bullets from subagent summary>

## Files changed
<list>

---
Fast patch via /fractal:patch
EOF
)"
```

**Step 5 — Wait for CI**

```bash
gh pr checks <pr_number> --watch
```

If CI fails: report which checks failed. Do not merge. Leave PR open for the user to
investigate.

**Step 6 — Merge**

```bash
gh pr merge <pr_number> --squash
```

**Step 7 — Clean up**

```bash
git worktree remove --force "$REPO_ROOT/.claude/worktrees/patch-<slug>"
git -C "$REPO_ROOT" branch -D "patch-<slug>"
```

**Step 8 — Deploy and smoke test**

Read deploy and smoke commands from `project.md`:

```bash
DEPLOY_CMD=$(grep "^deploy:" "$SPEC" 2>/dev/null | sed 's/^deploy: //' | head -1)
SMOKE_CMD=$(grep "^smoke:" "$SPEC" 2>/dev/null | sed 's/^smoke: //' | head -1)
```

If `DEPLOY_CMD` is defined: run it.
If `SMOKE_CMD` is defined: run it.
If neither is defined: skip silently.

**Step 9 — Report**

```
## Shipped — patch-<slug>

PR: <url>
Merge: squashed into <branch>
Deploy: ran | not configured
Smoke test: passed | not configured

Done.
```

---

## Orphan node persistence

When `/fractal:patch` runs **outside** a fractal tree context (no `active_node` in any
`root.md`, or invoked standalone without `/fractal` routing), and the user **approves**
the result, persist an orphan node:

```bash
ORPHAN_DIR="$FRACTAL_DIR/_orphans/patch-<slug>"
mkdir -p "$ORPHAN_DIR"
```

Write `predicate.md`:

```markdown
---
predicate: "<$ARGUMENTS>"
status: satisfied
created: <date>
origin: patch
---

# Notes

Implemented via /fractal:patch (orphan — no parent tree).

## Result
<subagent summary>

## Files changed
<list>
```

When `/fractal:patch` is invoked **from within** a tree (via `/fractal` routing with an
active node), do NOT create an orphan — the active node's `predicate.md` status is
updated by the `/fractal` skill after validation.

If discarded, no orphan is created.

---

## Rules

- **Zero questions is the default.** Only ask if ambiguity would cause significant rework.
- **Worktree is always isolated.** No option to implement directly on the current branch.
- **Complexity check is a suggestion, not a blocker.** User can always override.
- **Orphan nodes on standalone approve.** When approved outside a tree, persist as orphan node in `.fractal/_orphans/`.
- **Subagent always uses model: sonnet.** Never opus.
- **Build + test is a hard gate on approval.** Stop and report if it fails. Never force a broken PR.
- **References to other skills use full prefix:** `/fractal`, `/fractal:planning`, `/fractal:delivery`, `/fractal:ship`, etc.
- **Patch nodes are implicitly leaf nodes.** Discovery is skipped — the predicate is assumed to be sprint-sized by definition. No `discovery.md` or `prd.md` is written.

---

## When NOT to use

- Complex feature with multiple risks → use `/fractal`
- Already have a predicate and need a plan → use `/fractal:planning`
- Already have a plan, need orchestration → use `/fractal:delivery`
- Bug investigation (cause unknown) → use `/debug` or `/fix`
