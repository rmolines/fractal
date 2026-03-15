# openpredicate

You open a new project. You write a plan. Three days later the plan is wrong, the
doc is stale, and you're maintaining two sources of truth — the actual code and the
document that explains what the code was supposed to be.

Fractal is a Claude Code plugin that replaces planning hierarchies with a single
recursive operation. There is no separate plan, no roadmap doc, no task board. The
predicate tree living in `.fractal/` is the plan, the log, and the state —
simultaneously. `ls` shows the tree. `cat` shows the state. When a session dies and
a new one starts, the agent reads the filesystem and knows exactly where to continue.

## The operation

One function, applied at any scale:

```
fractal(predicate):
  if unachievable        → prune
  if a try can satisfy   → try → human validates
  if a cycle can satisfy → planning → delivery → review → ship → human validates
  else                   → propose one child predicate → human validates → recurse
```

That is the entire methodology. A predicate is a falsifiable condition — not a task,
not a user story, but a truth to be reached. The tree grows one node at a time. After
a child is satisfied, the parent is re-evaluated. Discovery is not a phase; it is the
recursion itself.

## Install

```bash
git clone https://github.com/rmolines/openpredicate ~/git/openpredicate
echo '{"plugins": [{"path": "~/git/openpredicate"}]}' >> ~/.claude/marketplace.json
```

Restart Claude Code. The `/fractal` skills will be available in any repo.

## Skills

| Skill | Invoke | What it does |
|---|---|---|
| `/fractal` | `/fractal build a cycling map app` | Entry point. Extracts the root predicate, creates the tree, or resumes from the active node. |
| `/fractal` (resume) | `/fractal` | No arguments — reads `.fractal/`, finds the active node, continues. |
| `/fractal:try` | `/fractal:try add dark mode toggle` | Fast path for simple predicates. Implements in an isolated worktree, shows diff, approve or discard. |
| `/fractal:planning` | `/fractal:planning .fractal/auth-flow` | Turns a predicate into an executable plan with parallel deliverables and a DAG. |
| `/fractal:delivery` | `/fractal:delivery .fractal/auth-flow` | Orchestrates subagents in parallel batches against the plan. Hard gate: baseline must pass first. |
| `/fractal:review` | `/fractal:review .fractal/auth-flow` | Spawns an independent evaluator that checks the diff against the predicate. Four outcomes: approved, back to delivery, back to planning, back to fractal. |
| `/fractal:ship` | `/fractal:ship .fractal/auth-flow` | PR + CI + deploy + simplify + docs + cleanup. Marks predicate as satisfied. |
| `/fractal:view` | `/fractal:view` | Generates an HTML dashboard of the predicate tree and opens it in the browser. |

## The tree

Every directory under `.fractal/` is a predicate node. Artifacts inside the directory
tell the agent what happened and what to do next — no explicit state is stored.

```
.fractal/
  cycling-map/                 # tree (one objective)
    root.md                    # root predicate + active_node pointer
    data-layer/                # child predicate
      predicate.md             # falsifiable condition, status, notes
      plan.md                  # created by /fractal:planning
      results.md               # created by /fractal:delivery
      review.md                # created by /fractal:review
      geojson-endpoint/        # grandchild (data-layer was subdivided)
        predicate.md
    map-render/                # sibling predicate
      predicate.md
```

The agent derives execution state from which files exist:

| Files present | State |
|---|---|
| `predicate.md` only | Not started — evaluate: try, cycle, or subdivide |
| `plan.md` exists | Planned — run delivery |
| `plan.md` + `results.md` | Executed — run review |
| `plan.md` + `results.md` + `review.md` | Reviewed — human validates, then ship |
| `status: satisfied` in frontmatter | Done — re-evaluate parent |

A new session reads the filesystem and picks up exactly where the last one stopped.

## The predicate window

Every predicate lives in a useful zone of abstraction:

```
Too abstract:  "improve the product"         → accepts everything, discriminates nothing
Useful zone:   "cycling map for SP commuters" → rejects irrelevant, survives stack changes
Too concrete:  "PWA with Mapbox GL + CET API" → a plan disguised as an objective
```

If the entire tech stack changed tomorrow and the predicate still made sense, it's in
the right zone.

## Full spec

[LAW.md](./LAW.md) — the complete specification, in dense form.
