# Fractal — Recursive Planning Primitive

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
fractal(root_predicate)

fractal(predicate):
  discovery ← discover(predicate)  // evaluator classifies branch vs leaf

  if is_unachievable(predicate):
    prune(predicate)
    return pruned

  if discovery.node_type == leaf:
    prd ← specify(predicate, discovery.prd_seed)
    human validates prd

    if patch_can_satisfy(prd):
      patch(prd)
      human validates → satisfied | fractal(predicate)
    else:
      cycle(prd)  // planning → delivery → review → ship
      human validates → satisfied | fractal(predicate)

  else:  // branch
    child ← select_best(discovery.proposed_children)
    human validates proposal:
      if accepted → fractal(child), then fractal(predicate)
      if rejected → fractal(predicate)  // propose another child
```

The operation is fractal — self-similar at any scale. Same structure, different time constants.

The tree grows lazy — one child at a time. After a child is satisfied, the parent is re-evaluated: maybe it's now satisfiable, maybe it needs another child. The re-evaluation decides.

### The dual: objection trees

The same primitive runs in reverse to decompose challenges instead of goals. The root is a doubt ("you can't do X"), children are reasons that doubt might be true, and satisfying a node means refuting the argument. Construction trees ask "what parts compose the goal?" — objection trees ask "why would this challenge be true?" Same recursion, inverted semantics.

This means the primitive has two modes — construction and refutation — with identical mechanics.

### Predicate tree, not task tree

**The agent does not define atomic steps — it defines atomic predicates.** The entire tree is a tree of predicates — satisfiable at branches (human judges composition), verifiable at leaves (world confirms). Actions emerge from predicates: "what do I need to do to make this predicate true?"

```
Root predicate: "cyclists in São Paulo can see bike lanes in real time on their phones"
  └─ Child predicate 1: "CET bike lane data is accessible via API"
      └─ Atomic predicate: "endpoint /api/lanes returns valid GeoJSON"
  └─ Child predicate 2: "map renders with a bike lane layer"
  └─ Child predicate 3: "app works offline on mobile"
```

### Closure property

Each level of the tree inherits the same type (predicate). Branches are satisfiable (human judges "enough"); leaves are verifiable (world confirms). Satisfying a child contributes to satisfying the parent. The algebra is closed by construction — no extra composition mechanism needed.

---

## Goal extraction

Precondition of the primitive, not part of it. Before the first `fractal()` call, the agent invests maximum energy in:
1. Uncovering the real goal behind the request (Socratic extraction)
2. Anticipating the "reality check" — when the human will discover they wanted something else
3. Making the goal verifiable — a concrete condition that proves it was reached

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
- **Patch:** trivial predicates. Implement, validate, approve or discard.
- **Full cycle:** complex predicates. Planning → delivery → review → ship.

The Launchpad cycle survives as the execution engine in the base case. Fractal replaces the planning/hierarchy layer (mission/stage/module), but the execution cycle (planning → delivery → review → ship) is the atomic unit of work for complex predicates.

Parallelism (multiple subagents) is an internal strategy of the cycle — it increases the capacity to satisfy larger predicates. From the tree's perspective, it is still one node, one predicate, one result.

The full cycle now executes as a single Sonnet subagent (the sprint agent) with no human gates between steps. The review skill is the internal quality gate — if it rejects, the sprint agent loops back to the relevant step (max 2 retries). The human validates only the final result: was the predicate satisfied?

---

## Objection trees

### Why inversion

Jacobi's principle: "invert, always invert." Munger applied it to problem-solving: define success by identifying what prevents it. Klein's pre-mortem formalizes this: assume the project failed, then explain why.

These are epistemically prior to planning. Before asking "how do I build X?", ask "why would X fail?" The failure modes discovered through inversion often surprise — they reveal assumptions that construction planning takes for granted.

### Mechanics

The objection tree uses the same recursive primitive with inverted semantics:

| Aspect | Construction tree | Objection tree |
|---|---|---|
| Root | Goal to achieve | Challenge to stress-test |
| Node framing | Verifiable condition | Agent-centric doubt ("you can't do X") |
| Decomposition | "What parts compose the goal?" | "Why would this challenge be true?" |
| Satisfaction | Goal achieved | Challenge refuted |
| Pruning | Path doesn't work → try another | Challenge is correct → acknowledge it |

Every node is an agent-centric doubt, not a world-state fact. "The agent can't build auth that works in production" — not "auth doesn't work in production." This framing matters: the tree decomposes the agent's limitations, not the world's state.

The evaluator returns the same four responses: `new_child` (strongest reason the challenge stands), `complete` (every reason addressed), `leaf` (directly refutable by doing), `unachievable` (the challenge is correct — the agent genuinely can't).

### Durable refutation

The key constraint distinguishing objection trees from one-off experiments: a refutation counts only when the capability survives session reset.

Two classes:
- **Durable** — code merged, skill modified, gate added, standard documented. Start a fresh session, delete /tmp — the capability still exists.
- **Ephemeral** — files in /tmp, one-time demo, a proof-of-concept that consumed itself. The agent did X once, but nothing encodes that it can do X again.

Ephemeral refutations prove possibility, not capability. If a child's refutation is ephemeral, the evaluator proposes a new child: "the system doesn't encode the pattern demonstrated by <sibling>." That child's job: commit the capability so it survives.

Exception: epistemic objections ("the agent doesn't know X") are satisfied when knowledge is captured in `conclusion.md` — the document is the encoding. The durability test applies to capability claims, not knowledge claims.

### Child taxonomy

Children are classified by what they challenge:
- **Epistemic** — we don't know something critical
- **Risk** — something might not work
- **Scope** — work remaining that hasn't been addressed

Priority: epistemic and risk before scope. Kill the unknown before executing. This mirrors the construction tree's risk-first ordering — uncertainty reduction is the organizing principle in both modes.

### Theoretical connections

The objection tree maps cleanly to four independent traditions:

- **Popper's falsification** — the hypothesis "I can't do X" must fail every test. Satisfying all children means the hypothesis has been falsified exhaustively. The tree is a structured falsification attempt.
- **Klein's pre-mortem** — assume failure, then construct the argument. The tree IS the argument, decomposed recursively until every branch is addressed.
- **Jacobi/Munger inversion** — success defined by the absence of all identified failure modes. The tree enumerates failure modes; satisfying the tree eliminates them.
- **Toulmin argumentation** — data → warrant → claim, with rebuttals as branches. Each node is a claim ("you can't do X"), children are warrants ("because Y"), and refutation is the rebuttal.

---

## Persistence

The predicate tree is the persistent on-disk representation. Each node: predicate (condition — verifiable for leaves, satisfiable for branches), status (pending | satisfied | pruned), children.

There is no separate "plan". The tree is the plan, the log, and the state. There is no persistent active node pointer — each session discovers its own focus via `select-next-node.sh`, which traverses the tree and picks the highest-priority pending node. Session locks prevent collisions: parallel sessions work different branches simultaneously. The filesystem is the complete state; the session lock is the only ephemeral element.

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
| Argumentation theory (Toulmin) | Warrant + rebuttal | Objection tree = structured falsification |

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

## Current state (v0.9.0)

Operational as a Claude Code plugin. Key capabilities:

- **Construction and objection trees** — same primitive, dual framing. Construction decomposes goals; objection decomposes challenges. Both use the same recursive evaluate → classify → execute → re-evaluate loop.
- **Durable refutation** — objection nodes are refuted only when the capability survives session reset. Ephemeral proofs disqualified.
- **Multiple trees per repo** — scripts auto-discover; user selects when ambiguous.
- **Sprint agent** — full planning → delivery → review → ship cycle runs as a single Sonnet subagent, no human gates. The review is the quality gate (max 2 retries).
- **Session-per-pointer** — no persistent active node. Each session discovers its own focus via `select-next-node.sh`. Session locks enable true parallel sessions on different branches.
- **Visual validation** — mandatory gate in delivery and review for UI deliverables. Render + screenshot + 6-criterion evaluation via browser automation.
- **Progressive disclosure** — tree → conclusions → sprint artifacts. Each session reads `conclusion.md` from satisfied nodes instead of loading every file.
- **OpenServer prototype** — programmatic tree management via MCP tools (CRUD, state transitions). Four of five sub-predicates satisfied.

Skill chains:
- Construction: `/fractal:init` → `/fractal:run` (loop) → patch or sprint internally
- Objection: `/fractal:init-objection` → `/fractal:run-objection` (loop)
- Utilities: `/fractal:propose`, `/fractal:view`, `/fractal:doctor`
