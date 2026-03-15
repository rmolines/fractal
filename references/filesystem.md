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
    dados-cet/                 # predicate node (child of root)
      predicate.md             # falsifiable condition, status, notes
      plan.md                  # from /fractal:planning
      results.md               # from /fractal:delivery
      review.md                # from /fractal:review
      endpoint-geojson/        # nested predicate (grandchild)
        predicate.md
        plan.md
        results.md
        review.md
    mapa-renderiza/            # predicate node (child of root)
      predicate.md
```

### root.md (inside each tree directory)

```markdown
---
predicate: "the root falsifiable condition"
status: pending
active_node: dados-cet/endpoint-geojson
created: 2026-03-14
---

# Root history

Previous roots are recorded here when the objective mutates.
```

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

### Deriving execution state from artifacts

The execution state of a node is NEVER stored explicitly — it's derived from which
artifacts exist in the directory:

| Artifacts present | Execution state | What to do |
|---|---|---|
| Only `predicate.md` | Not started | Evaluate: try, cycle, or subdivide |
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
- `active_node` in `root.md` is a relative path to the active node's directory
- Cycle artifacts (`plan.md`, `results.md`, `review.md`) follow schemas in `templates/schemas.md`
- `ls` shows the tree. `cat` shows the state. No parser needed.
