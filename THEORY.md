# Arbol — Recursive Planning Primitive

## The Problem

Planning frameworks for code agents impose rigid taxonomies with fixed lifecycles. In practice: plans break on contact with reality, hierarchies are arbitrary, and artifacts go stale between sessions.

Launchpad (the previous framework) imposed mission → stage → module with a discovery → planning → delivery → review → ship lifecycle. It worked, but the hierarchy was arbitrary and the plan was a contract that couldn't adapt.

**Success condition:** a single recursive operation that works identically at any scale, from "build an app" to "implement this function", where the plan never goes stale because there is no plan — only the next predicate.

---

## The Primitive

### Fundamental operation

```
// entry point
root_predicate ← extract_goal(human)  // precondition, not part of the primitive
arbol(root_predicate)

arbol(predicate):
  if is_unachievable(predicate):
    prune(predicate)
    return pruned

  else if try_can_satisfy(predicate):
    try(predicate)
    human validates → satisfied | arbol(predicate)

  else if cycle_can_satisfy(predicate):
    cycle(predicate)  // discovery → delivery → review → ship
    human validates → satisfied | arbol(predicate)

  else:
    // pick the sub-predicate that, once satisfied, reduces the most uncertainty
    // about how to satisfy the parent — not the easiest, not the most
    // important, but the one that best clarifies the path forward
    child ← propose_sub_predicate
    human validates proposal:
      if accepted → arbol(child), then arbol(predicate)
      if rejected → arbol(predicate)  // propose another child
```

The operation is fractal — self-similar at any scale. Same structure, different time constants.

The tree grows lazy — one child at a time. After a child is satisfied, the parent is re-evaluated: maybe it's now satisfiable, maybe it needs another child. The re-evaluation decides.

### Predicate tree, not task tree

**The agent does not define atomic steps — it defines atomic predicates.** The entire tree is a tree of falsifiable predicates. Actions emerge from predicates: "what do I need to do to make this predicate true?"

```
Root predicate: "cyclists in São Paulo can see bike lanes in real time on their phones"
  └─ Child predicate 1: "CET bike lane data is accessible via API"
      └─ Atomic predicate: "endpoint /api/lanes returns valid GeoJSON"
  └─ Child predicate 2: "map renders with a bike lane layer"
  └─ Child predicate 3: "app works offline on mobile"
```

### Closure property

Each level of the tree inherits the same type (falsifiable predicate). Satisfying a child contributes to satisfying the parent. The algebra is closed by construction — no extra composition mechanism needed.

---

## Goal extraction

Precondition of the primitive, not part of it. Before the first `arbol()` call, the agent invests maximum energy in:
1. Uncovering the real goal behind the request (Socratic extraction)
2. Anticipating the "reality check" — when the human will discover they wanted something else
3. Making the goal falsifiable — a concrete condition that proves it was reached

Without a clear goal → predicate breaks down → recursion has no base case → divergence (= AutoGPT).

### Abstraction window

The goal has an optimal level of abstraction:

- **Too abstract** ("improve urban mobility") → zero discriminating power. Every step "works". At the limit, "be happy" is every human's goal — but it doesn't function as a predicate.
- **Useful zone** ("app that shows bike lanes in real time for urban cyclists in São Paulo") → rejects irrelevant steps, survives implementation changes.
- **Too concrete** ("PWA with Mapbox GL + CET layer") → rigid plan disguised as a goal. Does not survive a change in premise.

The useful zone is where the goal has **maximum discriminating power**. In information theory terms: the level with the highest useful conditional entropy. Test: if the entire stack changes, does the predicate still make sense?

### Resilience to mutation

The system is reactive, not contractual. If the root goal changes:
- A new root node is created in the tree
- The previous tree persists as history
- The recursion restarts from the new root
- Nothing is lost, and the depth corrects itself

Structurally identical to MPC (Model Predictive Control): plan N steps, commit 1, observe, replan.

---

## Human validation

The human is part of the primitive, not an obstacle. Validates at two moments:
- **Proposal:** the agent proposes a predicate, the human confirms it makes sense and moves in the right direction
- **Result:** the agent concludes it has satisfied the predicate, the human confirms it actually was

Rejection on proposal → agent proposes another predicate. Rejection on result → agent redoes the execution. These are not special cases — they are natural re-evaluations of the primitive.

When the agent recognizes that a predicate is unachievable, it prunes the node. This forces re-evaluation at the parent and generation of another path.

---

## Two execution modes

The base case has two modes, and the agent decides which:
- **Try:** trivial predicates. Implement, validate, approve or discard.
- **Full cycle:** complex predicates. Discovery → delivery → review → ship.

The Launchpad cycle survives as the execution engine in the base case. Arbol replaces the planning/hierarchy layer (mission/stage/module), but the execution cycle (discovery → delivery → review → ship) is the atomic unit of work for complex predicates.

Parallelism (multiple subagents) is an internal strategy of the cycle — it increases the capacity to satisfy larger predicates. From the tree's perspective, it is still one node, one predicate, one result.

---

## Persistence

The predicate tree is the persistent on-disk representation. Each node: predicate (falsifiable condition), status (pending | satisfied | pruned), children.

There is no separate "plan". The tree is the plan, the log, and the state. There is always exactly one active node — the predicate currently being worked on. A new session reads the tree, finds the active node, and continues. It is the complete state of the session.

Delegation changes the executor of the node, it does not create parallel nodes.

---

## Delegation by capability

- **Opus** at the upper levels: abstract predicates, architecture decisions, goal extraction
- **Sonnet** at the middle levels: technical predicates, implementation with context
- **Haiku** at the lower levels: atomic predicates, direct execution

Delegation criterion: "who can satisfy this predicate?" That is the only criterion.

---

## Theoretical grounding

### Convergence across 7 fields

| Field | Primitive | Subdivision criterion |
|---|---|---|
| AI Planning (HTN) | Task decomposition | Type check: primitive or composite |
| Reinforcement Learning (Options) | Option ⟨I, π, β⟩ | Learned β function (termination condition) |
| Control Theory (MPC) | Receding horizon | Horizon = dominant time constant |
| Information Theory (MDL) | Partition | ΔH < cost of representing the subdivision |
| Theoretical CS (Y combinator) | Fixed-point | Predicate in the argument, not depth |
| Category Theory (F-algebras) | Initial algebra | Same morphism at every level (catamorphism) |
| Spatial structures (Quadtree) | Adaptive subdivision | Internal heterogeneity of the cell |

### Related work

- **ADaPT** (Allen AI, NAACL 2024) — attempt → fail → decompose → repeat. +28% on benchmarks. Closest prior work, but no HITL and binary predicate.
- **HyperTree Planning** (ICML 2025) — hierarchical divide-and-conquer, 3.6x vs o1-preview
- **LADDER** (2025) — recursion that generates easier variants, bootstraps upward
- **"Learning When to Plan"** (2025) — optimal planning frequency is task-dependent
- **Option-Critic** (Bacon 2017) — termination can be learned end-to-end
- **Ralph Loop** (Huntley 2025) — flat loop with external verification = base case of the recursion
- **Autoresearch** (Karpathy 2026) — flat loop with hard constraints = base case validation

### Mathematical insights

**Termination is a predicate, not a depth.** The primitive needs a single parameter: the atomicity predicate. Depth, branching factor, total steps are consequences.

**Fractal dimension as a consistency check.** If the primitive is self-similar, the sub-goals/step ratio should be roughly constant. Deviation indicates a non-uniform decomposition rule.

**Analogy to a theory of everything in physics.** The primitive unifies planning, but complexity doesn't disappear — it migrates to goal extraction and calibration. The framework becomes simple; the hard work moves elsewhere.

---

## Risks resolved

| Risk | Resolution |
|---|---|
| Theoretical grounding | Convergence across 7+ independent fields |
| Similar prior implementation | ADaPT is closest, without HITL/gradual predicate |
| Does the base case work? | Ralph Loop + Autoresearch validate empirically |
| Agent calibration | Accepted for v1: trust the agent, natural feedback loops |
| Closure property | Resolved by design: predicate tree, closed algebra |
| Cost | Optimization via conservative/aggressive dial + model delegation |
| Persistence | Predicate tree on disk is the source of truth |

## Next steps (implementation)

- Concrete on-disk tree format
- Visualization UX for the human
- Model delegation heuristics
- Integration with git, tests, CI
- First prototype: a skill that operates with the primitive
