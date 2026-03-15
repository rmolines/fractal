# Filesystem structure

## Filesystem structure

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
      predicate.md             # falsifiable condition, status, notes
      discovery.md             # from evaluator: node_type, classification
      prd.md                   # from specify step: acceptance criteria (leaf only)
      plan.md                  # from /fractal:planning
      results.md               # from /fractal:delivery
      review.md                # from /fractal:review
      endpoint-geojson/        # nested predicate (grandchild)
        predicate.md
        discovery.md
        prd.md
        plan.md
        results.md
        review.md
    mapa-renderiza/            # branch node (child of root)
      predicate.md
      discovery.md             # node_type: branch — no prd.md
      regiao-filtro/           # child of branch
        predicate.md
```

### root.md (inside each tree directory)

```markdown
---
predicate: "the root falsifiable condition"
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
predicate: "the falsifiable condition for this node"
status: pending | satisfied | pruned | candidate
created: 2026-03-14
---

# Notes

Context from execution: what was tried, what was learned, why decisions were made.
```

**Status `candidate`:** hypothetical sub-predicates generated during subdivision but not
selected as the active child. They persist in the hierarchy for future discovery rounds.
A candidate is NOT human-validated — it's the agent's hypothesis. When the parent is
re-evaluated, existing candidates are read before proposing new sub-predicates.

### discovery.md (inside each node directory, written by evaluator)

```markdown
---
node_type: branch | leaf
confidence: high | medium | low
reasoning: "why this classification"
proposed_children:                    # branch only — YAML list
  - "child predicate 1"
  - "child predicate 2"
prd_seed: "one-sentence PRD scope"   # leaf only
created: 2026-03-15
---

# Discovery notes

Context from the evaluator's investigation: what was found in the repo,
what informed the classification decision.
```

**`node_type: branch`** — the predicate is composite. Satisfied when all children are satisfied.
Branch nodes never have `prd.md`, `plan.md`, `results.md`, or `review.md`.

**`node_type: leaf`** — the predicate is executable. A PRD can be written and a sprint
executed against it. Leaf nodes get `prd.md` → `plan.md` → `results.md` → `review.md`.

### prd.md (inside leaf node directories, written by specify step)

```markdown
---
predicate: "the falsifiable condition from predicate.md"
created: 2026-03-15
---

## Acceptance Criteria

- Criterion 1: <falsifiable, maps to a deliverable>
- Criterion 2: <falsifiable, maps to a deliverable>

## Out of Scope

- <explicitly excluded item>

## Constraints

- <technical or design constraint>
```

`prd.md` exists only on leaf nodes. It translates the predicate's falsifiable condition
into concrete acceptance criteria that `/fractal:planning` uses to extract functional
requirements and build deliverables. The human validates `prd.md` before sprint begins.

### Deriving execution state from artifacts

The execution state of a node is NEVER stored explicitly — it's derived from which
artifacts exist in the directory:

| Artifacts present | Execution state | What to do |
|---|---|---|
| Only `predicate.md` | Not started | Run evaluator (discovery) |
| `predicate.md` + `discovery.md` (node_type: branch) | Discovered (branch) | Decompose — generate/select children |
| `predicate.md` + `discovery.md` (node_type: leaf) | Discovered (leaf) | Write prd.md (specify) |
| `predicate.md` + `discovery.md` + `prd.md` | Specified | Run sprint: planning → delivery → review → ship |
| `predicate.md` + child dirs | Subdivided | Check children's status |
| `plan.md` exists | Planned | Run delivery |
| `plan.md` + `results.md` | Executed | Run review |
| `plan.md` + `results.md` + `review.md` | Reviewed | HITL validate, then ship or redo |
| `status: satisfied` in frontmatter | Satisfied | Move to parent |
| `status: pruned` in frontmatter | Pruned | Move to parent |
| `status: candidate` in frontmatter | Candidate | Skip — hypothetical, not yet human-validated |

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
