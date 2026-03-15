# Plan: <name>
_Predicate: .fractal/<node>/predicate.md_
_Generated on: <date>_

## Requirements
_Copied from predicate — the contract this plan must fulfill._

- **R1:** <requirement text>
- **R2:** <requirement text>

## Problem
<Problem description — extracted directly from the predicate. One paragraph that describes what
is being solved and for whom. Used by the executor to verify alignment during execution.>

---

## Deliverables

### D1 — <short active title>

**Executor:** sonnet
**Isolation:** worktree
**Depends on:** none
**Requirements:** R1, R2
**Files touched:**
- `~/git/<repo>/src/path/to/file.ts`
- `~/git/<repo>/src/path/to/other.ts`

**Prompt for subagent:**

> You are implementing: <clear one-sentence objective>.
>
> **Context:**
> - Repo: `<repo>` at `~/git/<repo>/`
> - Stack: <relevant stack, version>
> - <Design decision already made — do not re-discuss. E.g. "we use Repository pattern, not ActiveRecord">
> - <Relevant technical constraint. E.g. "the external API returns arrays, never objects">
>
> **What to do:**
> 1. Create `~/git/<repo>/src/path/to/file.ts` with <what it should contain>
> 2. Edit `~/git/<repo>/src/path/to/other.ts`: add <exactly what>
> 3. <Additional concrete step if needed>
>
> **What NOT to do:**
> - Do not implement <feature Y> — that's D2
> - Do not modify `~/git/<repo>/src/path/to/config.ts` — out of scope for this deliverable
>
> **Validation:** run `<build/test command>` at repo root and confirm <expected result>.
>
> **Result format:** when done, output a result block:
> ```
> ## Result
> task_id: D1
> status: success | partial | failed
> summary: <1-2 sentences, what was done>
> errors: <list or empty>
> validation_result: <output of validation command>
> files_changed:
> - <paths>
> ```

**Acceptance:** `<command>` → <what must pass/return>
**Human test:** <plain language — what the user should do and what they should observe, no CLI commands>

---

### D2 — <short active title>

**Executor:** sonnet
**Isolation:** worktree
**Depends on:** D1
**Requirements:** R1
**Files touched:**
- `~/git/<repo>/src/path/to/file2.ts`

**Prompt for subagent:**

> You are implementing: <clear one-sentence objective>.
>
> **Context:**
> - D1 already created <what D1 did — minimum needed to understand the starting point>
> - <Relevant design decision>
>
> **What to do:**
> 1. <Concrete step with exact path>
> 2. <Concrete step with exact path>
>
> **What NOT to do:**
> - Do not alter what D1 created in <file> — only extend
>
> **Validation:** run `<command>` and confirm <expected result>.
>
> **Result format:** when done, output a result block:
> ```
> ## Result
> task_id: D2
> status: success | partial | failed
> summary: <1-2 sentences, what was done>
> errors: <list or empty>
> validation_result: <output of validation command>
> files_changed:
> - <paths>
> ```

**Acceptance:** `<command>` → <what must pass/return>
**Human test:** <plain language — what the user should do and what they should observe, no CLI commands>

---

### D3 — <short active title>

**Executor:** haiku
**Isolation:** none
**Depends on:** none
**Requirements:** R2
**Files touched:**
- `~/git/<repo>/README.md`
- `~/git/<repo>/.env.example`

**Prompt for subagent:**

> You are updating documentation to reflect <what changed>.
>
> **What to do:**
> 1. Update `~/git/<repo>/README.md` section "Getting Started": add step about <new requirement>
> 2. Add to `~/git/<repo>/.env.example`: `<NEW_VAR>=<example>`
>
> **What NOT to do:**
> - Do not rewrite existing sections — only add what's missing
>
> **Validation:** confirm `grep "<NEW_VAR>" ~/git/<repo>/.env.example` returns the added line.
>
> **Result format:** when done, output a result block:
> ```
> ## Result
> task_id: D3
> status: success | partial | failed
> summary: <1-2 sentences, what was done>
> errors: <list or empty>
> validation_result: <output of validation command>
> files_changed:
> - <paths>
> ```

**Acceptance:** `grep "<NEW_VAR>" ~/git/<repo>/.env.example` → line present

---

## Dependency graph

```
D3 (independent)

D1 ──→ D2 ──→ D4
              │
              ↓
             D5
```

_D3 can run in parallel with any batch. D1 must complete before D2. D2 and D4 are sequential because they touch the same files._

---

## Batches

**Batch 1 (parallel):** D1, D3
**Gate:** human review — confirm D1 (walking skeleton) is working before continuing
> Verify: <observable behavior that indicates D1 is correct>

**Batch 2 (parallel):** D2, D4
_(no gate — deliverables don't touch critical infrastructure)_

**Batch 3 (sequential):** D5 depends on D2 and D4

---

## Execution DAG

<!-- DAG format: one task per block, fields are key: value -->

task: D1
title: <short active title>
depends_on:
executor: sonnet
isolation: worktree
batch: 1
files: src/path/to/file.ts, src/path/to/other.ts
requirements: R1, R2
max_retries: 2
acceptance: <build/test command> exits 0
human_test: <plain language description of what the user should do and observe>

task: D2
title: <short active title>
depends_on: D1
executor: sonnet
isolation: worktree
batch: 2
files: src/path/to/file2.ts
requirements: R1
max_retries: 2
acceptance: <build/test command> exits 0
human_test: <plain language description of what the user should do and observe>

task: D3
title: <short active title>
depends_on:
executor: haiku
isolation: none
batch: 1
files: README.md, .env.example
requirements: R2
max_retries: 2
acceptance: grep "<NEW_VAR>" .env.example returns the line
human_test: No manual test needed — covered by automated validation

task: D4
title: <short active title>
depends_on: D2
executor: sonnet
isolation: worktree
batch: 2
files: src/path/to/file3.ts
requirements:
max_retries: 2
acceptance: <command> exits 0
human_test: <plain language description of what the user should do and observe>

task: D5
title: <short active title>
depends_on: D2, D4
executor: sonnet
isolation: worktree
batch: 3
files: tests/integration/file.test.ts
requirements:
max_retries: 2
acceptance: <command> exits 0
human_test: <plain language description of what the user should do and observe>

---

## Infrastructure

- [ ] New secrets: <none / which and where to configure>
- [ ] CI/CD: <no changes / what changes and where>
- [ ] New dependencies: <none / which — package manager + version>
- [ ] Setup script: <none / what it does and when to run>
- [ ] Data migration: <none / what migrates and how to rollback>

---

## Rollback

If something goes wrong after execution:

```bash
# Revert worktree for D1
git worktree remove .claude/worktrees/<name>-d1
git branch -D worktree-<name>-d1

# Revert added dependency (if D3 ran)
npm uninstall <lib-name>
git checkout -- package-lock.json

# Revert migration (if applicable)
<migration rollback command>
```

If deliverables were merged to main: create a revert branch and open a PR.
