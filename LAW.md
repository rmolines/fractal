# The OpenPredicaTree Law

## The primitive

There is a single operation governing all work between human and agent:

```
// entry point
root_predicate ← extract_goal(human)  // precondition, not part of the primitive
fractal(root_predicate)

fractal(predicate):
  discovery ← discover(predicate)  // evaluator classifies the node

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
      planning(prd)
      delivery(prd)
      review(prd)
      ship(prd)
      human validates → satisfied | fractal(predicate)

  else:  // branch
    // evaluator proposed 3-5 candidates during discovery
    // unchosen candidates persist in the hierarchy as hypotheses
    candidates ← discovery.proposed_children
    child ← select_best(candidates)
    persist_as_candidates(candidates - child)
    human validates proposal:
      if accepted → fractal(child), then fractal(predicate)
      if rejected → fractal(predicate)  // propose another or promote a candidate
```

This operation is fractal. It works identically at any scale — from "build a company" to "rename this variable". There are no different kinds of planning. There is one operation, repeated.

The tree grows lazy — one child at a time. After a child is satisfied, the parent is re-evaluated: maybe it's now satisfiable, maybe it needs another child. The re-evaluation decides.

### Mapping to the execution cycle

- **Discovery** = a formalized phase. The evaluator examines the predicate and repo context, classifies the node as branch or leaf, and writes `discovery.md`. For branches, it proposes candidate children. For leaves, it provides a `prd_seed` — the one-sentence scope of the PRD.
- **Specify** = the step that turns a leaf's `prd_seed` into a full `prd.md` with acceptance criteria, out-of-scope, and constraints. Human validates before sprint begins.
- **Planning → Delivery → Review → Ship** = the atomic execution unit for leaf predicates. Reads `prd.md` as primary requirement.
- **Patch** = shortcut for leaf predicates too trivial for the full cycle.

### The sprint cycle

`planning → delivery → review → ship` is the atomic execution unit for leaf predicates. These four skills form a closed cycle — they are always invoked in sequence by `/fractal:run` when a leaf node's PRD requires more than a patch.

- `/fractal:planning` — prd.md → executable plan with verifiable deliverables
- `/fractal:delivery` — plan → subagent execution in parallel batches
- `/fractal:review` — results → decision gate (back-to-planning | back-to-delivery | back-to-discovery | approved)
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

### Evaluate (Discovery)

The mechanism that drives the branching decisions in the primitive. An evaluate subagent receives a predicate and the full repo context. It answers one question: "Is this a branch (composite — satisfied by children) or a leaf (executable — satisfied by a sprint)?"

For branches: the evaluator proposes 2-5 candidate child predicates that together cover the parent. Each candidate is independently falsifiable.

For leaves: the evaluator provides a `prd_seed` — one-sentence scope for the PRD that will be written in the specify step.

Its output is persisted as `discovery.md` before routing. The fractal skill reads the classification and routes accordingly: branch → subdivide, leaf → specify → execute. Evaluate is the intelligence inside the conditional — everything else in the primitive is structure.

## Definitions

**Predicate:** a falsifiable condition that, when satisfied, constitutes progress toward the parent predicate. Not a task — a truth to be reached. Action emerges from the predicate.

**Predicate tree:** the persistent structure of the project. Each node is a predicate with: falsifiable condition, status (pending | satisfied | pruned), children. The tree is the plan, the log, and the state — simultaneously.

**Root predicate:** the goal extracted from the human. It sits in the useful abstraction window — specific enough to reject irrelevant steps, abstract enough to survive implementation changes.

**Leaf predicate:** a predicate whose scope is clear enough that a PRD can be written and a sprint executed against it. Base case of the recursion. Never has children.

**Branch predicate:** a predicate satisfied when all its children are satisfied. Never has `prd.md`, `plan.md`, or other sprint artifacts. It is a composite — its truth is derived from its parts.

**Discovery:** the formalized evaluation phase. The evaluator examines a predicate, classifies it as branch or leaf, and produces `discovery.md`. This happens once per node. The presence of `discovery.md` indicates the node has been classified.

**Active node:** a session-scoped pointer to the predicate being worked on. Between sessions, `active_node` rests at `"."` (root). When `/fractal:run` is invoked and the pointer is at root, the system traverses the tree, identifies the highest-priority pending node, and presents it to the human for validation. Within a session, there is always exactly one active node per tree.

**Tree:** the single predicate tree for a repository. Each repo has at most one tree under `.fractal/`. If a sub-predicate falls outside the scope of the root predicate, either redefine the root (objective mutation) or discard the sub-predicate. Tree creation and objective mutation are handled by `/fractal:init`.

**Pruned:** a predicate the agent recognized as unachievable. Permanent at that node, but does not kill the parent — it forces re-evaluation and generation of another path.

**Candidate:** a hypothetical sub-predicate generated during subdivision but not selected as the active child. Persists in the hierarchy for future discovery rounds. Not validated by the human until promoted to pending.

## The rules

### 1. The goal is the predicate
There is no plan separate from the goal. The root goal is the first predicate. Each subdivision generates child predicates that inherit the same type. The algebra is closed.

### 2. Reactive, not contractual
There is no plan as contract. If the root goal changes, a new root node is created in the tree. The previous tree persists as history, but the recursion restarts from the new root. Nothing is lost, and the depth corrects itself.

### 3. One tree per repo, one active node per tree
Each repo has at most one predicate tree. Each tree has exactly one predicate being worked on. Delegation changes the executor of the node, it does not create parallel nodes. Parallelism is internal optimization of the execution cycle. Between sessions, the active node resets to root. Each new session discovers its own focus via tree traversal.

### 4. Delegation by capability
The predicate determines the executor. Abstract predicates → more capable model. Leaf predicates → cheaper model. "Who can satisfy this predicate?" is the only criterion.

## The abstraction window

Every predicate — including the root — must sit in the zone of maximum discriminating power:

```
Too abstract:  "be happy"                        → accepts everything, discriminates nothing
Useful zone:   "bike lane app for São Paulo"     → rejects irrelevant, survives changes
Too concrete:  "PWA with Mapbox + CET API"       → rigid plan disguised as a goal
```

A predicate in the useful zone is one that still makes sense even if the entire stack changes.
