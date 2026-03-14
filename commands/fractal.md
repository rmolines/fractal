---
description: "Recursive predicate primitive for human+agent collaboration. Replaces rigid planning hierarchies with a single fractal operation. Use when starting a new project, resuming work, or any time the user needs to plan and execute toward an objective."
argument-hint: "objective, or empty to resume"
---

# /fractal

You operate the recursive predicate primitive. Read `~/git/fractal/LAW.md` first — it is
the complete specification. This skill is the operational wrapper.

Input: $ARGUMENTS — an objective in natural language, or empty to resume.

---

## On entry

```bash
# Detect project context
REPO_ROOT=""
if git rev-parse --is-inside-work-tree 2>/dev/null; then
  REPO_ROOT=$(git rev-parse --show-toplevel)
fi

# Find the tree
FRACTAL_DIR="${REPO_ROOT:-.}/.fractal"
```

### Route

- **No `.fractal/` dir + no arguments** → ask the user what they want to accomplish
- **No `.fractal/` dir + arguments** → extract objective from arguments, start extraction flow
- **`.fractal/` exists** → read tree from filesystem, find active node, run the primitive

---

## Phase 0: Extract the objective (pre-condition)

This is NOT part of the primitive — it's the pre-condition. Invest maximum energy here.

1. Read what the user said. Understand what they actually want, not just what they asked for.
2. Push back. Challenge assumptions. Ask Socratic questions — one at a time.
3. Anticipate the "cair na real" — when will the user discover they wanted something else?
4. Converge on a falsifiable predicate in the **useful zone of abstraction**:
   - Too abstract ("facilitate urban mobility") → won't discriminate, useless as predicate
   - Useful ("app showing bike lanes in real time for cyclists in SP") → rejects irrelevant steps, survives implementation changes
   - Too concrete ("PWA with Mapbox GL + CET API layer") → rigid plan disguised as objective
   - Test: if the entire tech stack changed, would this predicate still make sense?
5. When the user confirms → create the root directory and `predicate.md` → save to disk

---

## Filesystem structure

The tree IS the filesystem. Each directory is a predicate node. Artifacts from the
execution cycle live inside the node.

```
.fractal/
  root.md                    # active node pointer + history of root changes
  dados-ciclofaixas/         # predicate node (child of root)
    predicate.md             # falsifiable condition, status, created date, notes
    plan.md                  # from /launchpad:planning
    results.md               # from /launchpad:delivery
    review.md                # from /launchpad:review
    endpoint-geojson/        # nested predicate (grandchild)
      predicate.md
      plan.md
      results.md
      review.md
  mapa-renderiza/            # predicate node (child of root)
    predicate.md
```

### root.md

```markdown
---
predicate: "the root falsifiable condition"
status: pending
active_node: dados-ciclofaixas/endpoint-geojson
created: 2026-03-14
---

# Root history

Previous roots are recorded here when the objective mutates.
```

### predicate.md (inside each node directory)

```markdown
---
predicate: "the falsifiable condition for this node"
status: pending | satisfied | pruned
created: 2026-03-14
---

# Notes

Context from execution: what was tried, what was learned, why decisions were made.
```

### Conventions

- Directory name = slug of the predicate (kebab-case, short)
- Depth = nesting of directories
- Status is in `predicate.md` frontmatter
- `active_node` in `root.md` is a relative path to the active node's directory
- Cycle artifacts (`plan.md`, `results.md`, `review.md`) follow the same format as Launchpad
- `ls` shows the tree. `cat` shows the state. No parser needed.

---

## The primitive

Read `~/git/fractal/LAW.md` for the full specification. Here is the operational flow:

### 1. Find the active node

Read `.fractal/root.md` → get `active_node` path → read that node's `predicate.md`.
Present it:

```
Projeto: "<root predicate>"
Nó ativo: "<active predicate>"
Caminho: <path from root>
Pai: "<parent predicate>" (or "raiz" if top-level)
Filhos satisfeitos: N/M
```

### 2. Evaluate the predicate

Assess the active predicate against three checks, in order:

**Check 1: Is it unachievable?**
If you recognize the predicate cannot be satisfied given current constraints → propose
pruning to the user. If confirmed: set `status: pruned` in `predicate.md`, update
`active_node` in `root.md` to parent directory, re-evaluate parent.

**Check 2: Can a try satisfy it?**
The predicate is trivial enough to implement directly in one shot. Criteria:
- Clear what needs to be done
- Few files involved
- No architectural decisions needed
- No research needed

If yes → propose to the user: "Este predicado é simples o suficiente pra um try. Concordo?"
If confirmed → invoke `/launchpad:try` with the predicate as the task description.
After try completes → ask user to validate the predicate was satisfied.

**Check 3: Can a full cycle satisfy it?**
The predicate is complex but self-contained — one cycle of planning → delivery → review → ship
can handle it. Criteria:
- Scope is clear
- Can be planned into deliverables
- Testable/verifiable result

If yes → propose to the user: "Este predicado precisa de um ciclo completo. Concordo?"
If confirmed → invoke `/launchpad:planning` with the predicate, then follow with
delivery → review → ship. Artifacts are saved inside the node directory.
After cycle completes → ask user to validate the predicate was satisfied.

**Check 4: None of the above → subdivide**
The predicate is too large or uncertain. Propose a sub-predicate:

> Choose the sub-predicate that, once satisfied, most reduces uncertainty about how to
> satisfy the parent. Not the easiest. Not the most important. The one that most
> clarifies the path.

Present to the user:
```
O predicado "<parent>" é grande demais pra um ciclo.

Proponho este sub-predicado: "<child predicate>"

Motivo: <why this child most reduces uncertainty>

Aceita?
```

If accepted → create child directory with `predicate.md`, update `active_node` in
`root.md` to the new child path.
If rejected → propose a different sub-predicate.

### 3. Handle validation results

After execution (try or cycle):

**User confirms predicate satisfied:**
- Set `status: satisfied` in node's `predicate.md`
- Update `active_node` in `root.md` to parent directory
- Re-evaluate parent: maybe it's now satisfiable, maybe it needs another child

**User says not satisfied:**
- Keep node as active, status remains `pending`
- Re-run the primitive (will re-evaluate and try again or subdivide further)

### 4. Objective mutation

If the user decides the root objective has changed:
- Record current root in the history section of `root.md`
- Update the root predicate and `active_node`
- Old child directories persist as history
- Recursion restarts from the new root

---

## Resuming

When called with no arguments and `.fractal/` exists:

1. Read `root.md`
2. Show current state:
   ```
   Projeto: <root predicate>
   Nó ativo: <active predicate>
   Caminho: <path>
   Profundidade: N
   Predicados satisfeitos: X/Y total
   ```
3. Run the primitive on the active node

---

## Rules

- **One question at a time.** Never stack questions.
- **Push back.** Challenge scope, assumptions, predicate quality.
- **The filesystem is truth.** Always read before acting, always save after acting.
- **HITL always.** Validate every proposed predicate. Validate every result.
- **Subagents use model: sonnet.** Never opus in a subagent.
- **Discovery is the primitive.** Every evaluation of a predicate IS discovery. Don't invoke `/launchpad:discovery` separately — this skill replaces it.
