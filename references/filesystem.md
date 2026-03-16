# Filesystem structure

The tree IS the filesystem. Each repo has at most **one tree** under `.fractal/`.
The tree is a named subdirectory containing `root.md`. Each subdirectory within the
tree is a predicate node. Artifacts from the execution cycle live inside the node.

**Single-tree constraint:** `/fractal:init` enforces one tree per repo. If a sub-predicate
falls outside the scope of the root predicate, either redefine the root (objective mutation)
or discard the sub-predicate. `/fractal:doctor` validates this constraint.

```
.fractal/
  ciclofaixas/                 # the single tree for this repo
    root.md                    # root predicate + active node pointer
    dados-cet/                 # leaf node (child of root)
      predicate.md             # verifiable condition, status, notes
      session.lock             # optional: active session claim (auto-managed)
      discovery.md             # from evaluator: response type + reasoning
      prd.md                   # from specify step: acceptance criteria (leaf only)
      plan.md                  # from /fractal:planning
      results.md               # from /fractal:delivery
      review.md                # from /fractal:review
      conclusion.md            # from satisfaction: what was achieved
      endpoint-geojson/        # nested predicate (grandchild)
        predicate.md
        discovery.md
        prd.md
        plan.md
        results.md
        review.md
        conclusion.md          # from satisfaction: what was achieved
    mapa-renderiza/            # branch node (child of root)
      predicate.md
      discovery.md             # branch (has children) — no prd.md
      regiao-filtro/           # child of branch
        predicate.md
```

### root.md (inside each tree directory)

```markdown
---
predicate: "the root verifiable condition"
status: pending
active_node: .
created: 2026-03-14
---

# Root history

Previous roots are recorded here when the objective mutates.
```

**`active_node`** is a session-scoped pointer. `active_node: .` means no session focus — the next `/fractal:run` invocation will traverse the tree, identify the highest-priority pending node, and present it to the human for validation. A relative path (e.g. `dados-cet/endpoint-geojson`) indicates an active session is working on that node.

### predicate.md (inside each node directory)

```markdown
---
predicate: "the verifiable condition for this node"
status: pending | satisfied | pruned
created: 2026-03-14
---

# Notes

Context from execution: what was tried, what was learned, why decisions were made.
```

### session.lock (inside node directories, auto-managed)

```markdown
---
pid: 42567
session_id: abc123
created: 2026-03-15T14:30:00
node: dados-cet
---
```

Session locks prevent parallel sessions from working on the same branch.
Created by `/fractal:run` when a session focuses on a node, removed on ASCEND.

- **Active lock:** PID is alive (`kill -0 $pid` succeeds) → branch is claimed
- **Stale lock:** PID is dead → ignored by `select-next-node.sh`, cleaned up opportunistically
- `select-next-node.sh` excludes the locked node, its ancestors, and its descendants from selection
- Managed by `scripts/session-lock.sh` (create, remove, list, cleanup, check)

### discovery.md (inside each node directory, written by evaluator)

```markdown
---
response: new_child | complete | leaf | unachievable
confidence: high | medium | low
reasoning: "analysis considering existing children"
child_predicate: "proposed child predicate"      # new_child only
child_type: risk | acquisition | scope            # new_child only
prd_seed: "one-sentence PRD scope"                # leaf only
leaf_type: patch | cycle | action                 # leaf only
incerteza: high | medium | low
impacto: high | medium | low
retorno: high | medium | low
created: 2026-03-15
---

# Discovery notes

Context from the evaluator's investigation.
```

**Ephemeral on branch parents:** when ASCEND returns to a parent node, the parent's
`discovery.md` is deleted to force re-evaluation on the next visit. Child nodes retain
their `discovery.md` — it preserves `leaf_type`, `reasoning`, and other classification data.

**`response: new_child`** — the predicate needs decomposition. One child is proposed per evaluation.
Re-called after the child is resolved to check if more children are needed.

**`response: complete`** — all necessary children exist, or none are needed (leaf-like but already has children).

**`response: leaf`** — the predicate is directly satisfiable. `prd_seed` and `leaf_type` specify how.
Leaf nodes get `prd.md` → `plan.md` → `results.md` → `review.md`.

**`response: unachievable`** — the predicate cannot be satisfied. `/fractal:run` will propose pruning.

### prd.md (inside leaf node directories, written by specify step)

```markdown
---
predicate: "the verifiable condition from predicate.md"
created: 2026-03-15
---

## Acceptance Criteria

- Criterion 1: <verifiable, maps to a deliverable>
- Criterion 2: <verifiable, maps to a deliverable>

## Out of Scope

- <explicitly excluded item>

## Constraints

- <technical or design constraint>
```

`prd.md` exists only on leaf nodes. It translates the predicate's verifiable condition
into concrete acceptance criteria that `/fractal:planning` uses to extract functional
requirements and build deliverables. The human validates `prd.md` before sprint begins.

### conclusion.md (inside node directories, written at satisfaction)

````markdown
---
predicate: "the verifiable condition from predicate.md"
satisfied_date: 2026-03-16
satisfied_by: ship | human | synthesis
---

## What was achieved
1-3 sentences oriented toward the parent predicate. Not "what code was written" but "what changed in the world that makes this true."

## Key decisions
Decisions made during execution that constrain future work on sibling or parent predicates.

## Deferred
Items explicitly out of scope that may need future predicates.
````

`satisfied_by` indicates who wrote the conclusion:
- **ship** — automated, written by `/fractal:ship` for technical leaves (patch/cycle)
- **human** — captured from human evidence report for action leaves
- **synthesis** — drafted by agent from children's conclusions, validated by human, for branches

`conclusion.md` is the primary input for tree summaries and progressive disclosure. It answers "what does this node mean for the project?" without requiring the reader to open sprint artifacts.

### Deriving execution state from artifacts

The execution state of a node is NEVER stored explicitly — it's derived from which
artifacts exist in the directory:

| Artifacts present | Execution state | What to do |
|---|---|---|
| Only `predicate.md` | Not started | Run evaluator (discovery) |
| `predicate.md` + `discovery.md` (response: new_child) | Evaluated (new_child) | Create proposed child, recurse |
| `predicate.md` + `discovery.md` (response: leaf) | Evaluated (leaf) | Write prd.md (specify) or present action |
| `predicate.md` + `discovery.md` (response: complete) | Evaluated (complete) | Select next pending child, or validate branch satisfaction |
| `predicate.md` + `discovery.md` (response: unachievable) | Evaluated (unachievable) | Propose pruning to human |
| `predicate.md` + `discovery.md` + `prd.md` | Specified | Run sprint: planning → delivery → review → ship |
| `predicate.md` + child dirs | Subdivided | Check children's status |
| `plan.md` exists | Planned | Run delivery |
| `plan.md` + `results.md` | Executed | Run review |
| `plan.md` + `results.md` + `review.md` | Reviewed | HITL validate, then ship or redo |
| `status: satisfied` + `conclusion.md` | Satisfied (with context) | Conclusion available for parent re-evaluation and tree summary |
| `status: satisfied` in frontmatter (no conclusion.md) | Satisfied (legacy) | Move to parent — conclusion unavailable |
| `status: pruned` in frontmatter | Pruned | Move to parent |

A node may be `status: satisfied` without `conclusion.md` for legacy nodes. New satisfaction flows always write conclusions.

This means a new session can always determine exactly where execution stopped by
reading the filesystem. Zero stale state.

### Notes discipline

Before any checkpoint (user validation, `/clear`, end of session), update the `# Notes`
section of the active node's `predicate.md` with:
- What was attempted and the outcome
- Key decisions made and why
- What the next session needs to know to continue

A new session reads `predicate.md` and has full context. If notes are empty, context is lost.

### Conventions

- Directory name = slug of the predicate (kebab-case, short)
- Depth = nesting of directories
- Status is in `predicate.md` frontmatter, execution state is derived from artifacts
- `active_node` in `root.md` is a session pointer — `"."` means no focus (next /fractal:run discovers), a relative path means an active session is working on that node
- Cycle artifacts (`plan.md`, `results.md`, `review.md`) follow schemas in `templates/schemas.md`
- Discovery artifact (`discovery.md`) follows Schema 3 in `templates/schemas.md`
- PRD artifact (`prd.md`) follows Schema 6 in `templates/schemas.md`
- `ls` shows the tree. `cat` shows the state. No parser needed.
- `session.lock` files are transient — they should NOT be committed to git
