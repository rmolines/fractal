---
description: "Validates fractal tree integrity and optionally fixes inconsistencies."
argument-hint: "--fix to enable cleanup mode"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob
---

# /fractal:doctor

## Human gates

Every time this skill needs human input (confirmation, choice, correction), use the `AskUserQuestion` tool instead of printing the question as text output.

Input: $ARGUMENTS — pass `--fix` to enable interactive cleanup mode.

---

## Mode

- Default: **read-only validation**. Reports issues, changes nothing.
- `--fix`: **interactive cleanup**. Asks for confirmation via AskUserQuestion before each fix.

---

## On entry

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
FRACTAL_DIR="$REPO_ROOT/.fractal"
```

If `.fractal/` does not exist → "Nenhuma árvore encontrada. Execute /fractal:init." STOP.

---

## Checks — execute in order

### Check 1: Single-tree constraint

Count top-level dirs with `root.md` inside `.fractal/`.

- 0 trees → `[FAIL] Nenhuma árvore encontrada.`
- 1 tree → `[PASS] Uma árvore: <name>`
- N > 1 → `[FAIL] Múltiplas árvores: <list>. Constraint: uma por repo.`
  - `--fix`: ask which to keep. Offer to remove others (move to `.fractal/_archive/`).

### Check 2: root.md integrity

Read `.fractal/<tree>/root.md`. Validate frontmatter:

- `predicate` exists and is non-empty
- `status` is a valid value (pending | satisfied | pruned)
- `active_node` exists
- `created` exists

Each missing/invalid field: `[FAIL] root.md: campo '<field>' ausente ou invalido.`
- `--fix` for active_node: reset to `.`
- `--fix` for status: set to `pending`

### Check 3: active_node pointer

If `active_node` != `.`:
- Check that `.fractal/<tree>/<active_node>/` directory exists
- Check that `.fractal/<tree>/<active_node>/predicate.md` exists

If broken: `[FAIL] active_node aponta para diretorio inexistente: <path>`
- `--fix`: reset `active_node` to `.` in root.md

### Check 4: predicate.md files

For every directory inside the tree (recursive), check:

- `predicate.md` exists (dirs without it are orphans)
- Frontmatter has `predicate` (non-empty)
- `status` is valid (pending | satisfied | pruned)
- `created` exists

Orphan dirs: `[WARN] Diretorio orfao (sem predicate.md): <path>`
- `--fix`: ask to remove

Legacy status: `[WARN] Status legado 'candidate' em <path> — considere migrar para 'pending'`
- No auto-fix (manual migration recommended)

Invalid status: `[WARN] Status invalido '<status>' em <path>`
- `--fix`: ask to set to `pending`

### Check 5: Parent-child consistency

For each node:
- If parent status is `satisfied` or `pruned`, no child should be `pending`
  `[WARN] Child pending sob parent <status>: <child_path>`
- `--fix`: ask to set child to `pruned`

### Check 6: Artifact consistency

For nodes with `plan.md` + `results.md` + `review.md` but `status` != `satisfied`:
`[WARN] Artefatos completos mas status pending — pode precisar de validacao: <path>`
- No auto-fix (requires human judgment)

### Check 7: Discovery and PRD consistency

For every node with `discovery.md`:
- Read `response` from frontmatter
- If `response: new_child` or `response: complete` (branch) and `prd.md` exists → `[WARN] prd.md on a branch node is inconsistent: <path>`
  - `--fix`: ask to remove prd.md
- If `response: new_child` or `response: complete` (branch) and `plan.md` exists → `[WARN] Sprint artifacts on a branch node: <path>`
  - `--fix`: ask to remove sprint artifacts (plan.md, results.md, review.md)
- If `response: leaf` and `plan.md` exists but no `prd.md` → `[WARN] Leaf node has plan but no prd.md (pre-update node): <path>`
  - No auto-fix (may be a node created before the PRD model update)
- If `discovery.md` exists but `response` is not `new_child`, `complete`, `leaf`, or `unachievable` → `[WARN] Invalid response in discovery.md: <path>`
- If `discovery.md` exists and has `node_type` field instead of `response` → `[WARN] Legacy discovery.md format (node_type) at <path> — consider migrating to response field`

---

## Output

Print each check result as:
```
[PASS] <description>
[WARN] <description>
[FAIL] <description>
```

Summary at end:
```
Resultado: N passed, M warnings, K failures.
```

If `--fix` was used:
```
Fixes aplicados: N
```

---

## Rules

- Read-only by default. No writes without `--fix`.
- In `--fix` mode, each destructive operation asks for confirmation via AskUserQuestion.
- Never delete `predicate.md` without explicit confirmation.
- Archive (move to `_archive/`), don't delete trees.
- Report what would be fixed even in read-only mode.
