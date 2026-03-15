# The Fractal Law

## The primitive

There is a single operation governing all work between human and agent:

```
// entry point
root_predicate ← extract_goal(human)  // precondition, not part of the primitive
fractal(root_predicate)

fractal(predicate):
  // this evaluation IS discovery — the agent reasoning about the predicate

  if is_unachievable(predicate):
    prune(predicate)
    return pruned

  else if try_can_satisfy(predicate):
    try(predicate)
    human validates → satisfied | fractal(predicate)

  else if cycle_can_satisfy(predicate):
    planning(predicate)
    delivery(predicate)
    review(predicate)
    ship(predicate)
    human validates → satisfied | fractal(predicate)

  else:
    // generate 3-5 candidates, pick the one that reduces uncertainty most
    // unchosen candidates persist in the hierarchy as hypotheses
    // for future discovery rounds
    candidates ← generate_sub_predicates(predicate)
    child ← select_best(candidates)
    persist_as_candidates(candidates - child)
    human validates proposal:
      if accepted → fractal(child), then fractal(predicate)
      if rejected → fractal(predicate)  // propose another or promote a candidate
```

This operation is fractal. It works identically at any scale — from "build a company" to "rename this variable". There are no different kinds of planning. There is one operation, repeated.

The tree grows lazy — one child at a time. After a child is satisfied, the parent is re-evaluated: maybe it's now satisfiable, maybe it needs another child. The re-evaluation decides.

### Mapping to the execution cycle

- **Discovery** = the primitive itself. Every time `fractal()` runs, it is doing discovery: evaluating the predicate, deciding whether it's atomic or needs subdivision, proposing sub-predicates.
- **Planning → Delivery → Review → Ship** = the atomic execution unit for complex predicates. Satisfies the predicate.
- **Try** = shortcut for predicates too trivial for the full cycle.

Discovery is not a separate phase — it is the recursion itself.

### The sprint cycle

`planning → delivery → review → ship` is the atomic execution unit for complex predicates. These four skills form a closed cycle — they are always invoked in sequence by `/fractal` when `cycle_can_satisfy(predicate)` is true.

- `/fractal:planning` — predicate → executable plan with verifiable deliverables
- `/fractal:delivery` — plan → subagent execution in parallel batches
- `/fractal:review` — results → decision gate (back-to-planning | back-to-delivery | approved)
- `/fractal:ship` — approved code → PR, CI, deploy, cleanup

The cycle is internal to the primitive. From the tree's perspective: one node, one predicate, one result. Parallelism within delivery is an optimization, not a structural change.

### Goal extraction

Precondition of the primitive. Before the first `fractal()` call, the agent invests maximum energy in:
1. Uncovering the real goal behind the request (the human may not know what they want)
2. Anticipating the "reality check" — when the human will discover they wanted something else
3. Making the goal falsifiable — a concrete condition that proves it was reached

Without a clear goal, the recursion has no base case.

### Human validation

The human validates at two moments:
- **Proposal:** the agent proposes a predicate, the human confirms it makes sense and moves in the right direction
- **Result:** the agent concludes it has satisfied the predicate, the human confirms it actually was

Rejection on proposal → agent proposes another predicate. Rejection on result → agent redoes the execution. These are not special cases — they are natural re-evaluations of the primitive.

### Evaluate

The mechanism that drives the branching decisions in the primitive. An evaluate subagent receives a predicate and the full repo context. It answers one question: "What is the largest sub-predicate I'm confident will move us closest to satisfying the parent, and does it fit in one sprint?"

Its output determines the branch taken: if the predicate is unachievable → prune; if it fits a try or a full cycle → execute; if it's too large → subdivide with the proposed sub-predicate. Evaluate is the intelligence inside the conditional — everything else in the primitive is structure.

## Definitions

**Predicate:** a falsifiable condition that, when satisfied, constitutes progress toward the parent predicate. Not a task — a truth to be reached. Action emerges from the predicate.

**Predicate tree:** the persistent structure of the project. Each node is a predicate with: falsifiable condition, status (pending | satisfied | pruned), children. The tree is the plan, the log, and the state — simultaneously.

**Root predicate:** the goal extracted from the human. It sits in the useful abstraction window — specific enough to reject irrelevant steps, abstract enough to survive implementation changes.

**Atomic predicate:** one that a try or a full cycle (planning → delivery → review → ship) can satisfy directly. It is the base case of the recursion.

**Active node:** there is always exactly one predicate being worked on per tree. A new session reads the tree, finds the active node, and continues. It is the complete state of the session.

**Tree:** the single predicate tree for a repository. Each repo has at most one tree under `.fractal/`. If a sub-predicate falls outside the scope of the root predicate, either redefine the root (objective mutation) or discard the sub-predicate. Tree creation and objective mutation are handled by `/fractal:init`.

**Pruned:** a predicate the agent recognized as unachievable. Permanent at that node, but does not kill the parent — it forces re-evaluation and generation of another path.

**Candidate:** a hypothetical sub-predicate generated during subdivision but not selected as the active child. Persists in the hierarchy for future discovery rounds. Not validated by the human until promoted to pending.

## The rules

### 1. The goal is the predicate
There is no plan separate from the goal. The root goal is the first predicate. Each subdivision generates child predicates that inherit the same type. The algebra is closed.

### 2. Reactive, not contractual
There is no plan as contract. If the root goal changes, a new root node is created in the tree. The previous tree persists as history, but the recursion restarts from the new root. Nothing is lost, and the depth corrects itself.

### 3. One tree per repo, one active node per tree
Each repo has at most one predicate tree. Each tree has exactly one predicate being worked on. Delegation changes the executor of the node, it does not create parallel nodes. Parallelism is internal optimization of the execution cycle.

### 4. Delegation by capability
The predicate determines the executor. Abstract predicates → more capable model. Atomic predicates → cheaper model. "Who can satisfy this predicate?" is the only criterion.

## The abstraction window

Every predicate — including the root — must sit in the zone of maximum discriminating power:

```
Too abstract:  "be happy"                        → accepts everything, discriminates nothing
Useful zone:   "bike lane app for São Paulo"     → rejects irrelevant, survives changes
Too concrete:  "PWA with Mapbox + CET API"       → rigid plan disguised as a goal
```

A predicate in the useful zone is one that still makes sense even if the entire stack changes.
