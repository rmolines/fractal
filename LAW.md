# The Fractal Law

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
3. Making the goal verifiable — a concrete condition that proves it was reached

Without a clear goal, the recursion has no base case.

### Human validation

The human validates at two moments:
- **Proposal:** the agent proposes a predicate, the human confirms it makes sense and moves in the right direction
- **Result:** the agent concludes it has satisfied the predicate, the human confirms it actually was

Rejection on proposal → agent proposes another predicate. Rejection on result → agent redoes the execution. These are not special cases — they are natural re-evaluations of the primitive.

### Evaluate (Discovery)

The mechanism that drives the branching decisions in the primitive. An evaluate subagent receives a predicate and the full repo context. It answers one question: "Is this a branch (composite — satisfied by children) or a leaf (executable — satisfied by a sprint)?"

For branches: the evaluator proposes 2-5 candidate child predicates that together cover the parent. Each candidate is independently verifiable.

For leaves: the evaluator provides a `prd_seed` — one-sentence scope for the PRD that will be written in the specify step.

Its output is persisted as `discovery.md` before routing. The fractal skill reads the classification and routes accordingly: branch → subdivide, leaf → specify → execute. Evaluate is the intelligence inside the conditional — everything else in the primitive is structure.

## Definitions

**Predicate:** a condition that, when satisfied, constitutes progress toward the parent predicate. Not a task — a truth to be reached. Action emerges from the predicate. Predicates come in two kinds depending on how satisfaction is judged:

**Verifiable predicate (leaf):** a predicate whose satisfaction can be confirmed objectively — by running a test, observing output, or checking a concrete condition. Base case of the recursion. Scope is clear enough that a PRD can be written and a sprint executed against it. Never has children.

**Satisfiable predicate (branch):** a predicate whose satisfaction is judged by the human. The human decides when the composition of children is "enough." There is no binary test — the human exercises bounded judgment over the whole. Never has `prd.md`, `plan.md`, or other sprint artifacts. Its truth is derived from its parts, but the derivation is a human call.

**Predicate tree:** the persistent structure of the project. Each node is a predicate with: condition, status (pending | satisfied | pruned), children. The tree is the plan, the log, and the state — simultaneously. Branches are satisfiable; leaves are verifiable. The algebra is closed — both are predicates.

**Root predicate:** the goal extracted from the human. It sits in the useful abstraction window — specific enough to reject irrelevant steps, abstract enough to survive implementation changes. Always satisfiable (the human judges when the goal is reached).

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

## Predicate formulation

### Verifiable vs. satisfiable — the core distinction

The predicate tree has two kinds of nodes, distinguished by how satisfaction is judged:

| | **Verifiable (leaf)** | **Satisfiable (branch)** |
|---|---|---|
| **Judged by** | The world (tests, observable output) | The human (bounded judgment) |
| **Criterion** | Binary — passes or fails | Compositional — "enough" children satisfied |
| **Artifacts** | prd.md → plan.md → results.md | None — truth derived from children |
| **Prior art** | Popper's falsifiability; NFR hardgoal | Simon's satisficing; NFR softgoal |

This is not a limitation — it is the design. Branches cannot be objectively verified because they exist at a level of abstraction where the human's judgment is the only valid oracle. Leaves can and must be verified because they are concrete enough for the world to confirm.

### Functional vs. technical predicates

Within verifiable (leaf) predicates, there are two sub-kinds:

**Functional predicates** — describe observable behavior from the user's perspective.
Example: "user asks about fleet distribution and gets a correct, routed answer."

**Technical predicates** — describe internal system properties.
Example: "system-prompt maps 5 operational files with disambiguation signals."

Functional predicates are preferred at the leaf level because the human validates results. A human can confirm "I asked about fleet distribution and got the right answer" — they cannot easily confirm "the system-prompt maps operational files with disambiguation signals" without reading code.

### The wrapping rule

When a technical predicate surfaces as a leaf, it is almost always a child of an unstated functional predicate. The correct structure is:

```
[functional parent — human validates (satisfiable)]
  └── [technical child — auto-validated by tests (verifiable)]
```

Example:

```
Bad (technical leaf exposed to human validation):
  "system-prompt maps operational files"

Good (functional parent, technical child):
  "user asks operational questions and gets correct routing"   ← human validates
    └── "system-prompt maps operational files"                ← validated by tests
```

### When to apply

- If a leaf predicate uses internal identifiers, file counts, or system internals as its success criterion — wrap it.
- If a human cannot confirm the predicate is satisfied without reading source code — wrap it.
- If satisfaction requires running a test suite rather than observing user behavior — the predicate is technical; consider whether a functional wrapper belongs above it.

### Exception

A technical predicate may remain a direct leaf when:
- It belongs to a pure infrastructure or tooling context (no user-facing behavior exists), AND
- It will be validated automatically by CI/tests, AND
- The human has explicitly approved this validation method during the SPECIFY step.

Even then, document the validation method in `prd.md`.

---

## The abstraction window

Every predicate — including the root — must sit in the zone of maximum discriminating power:

```
Too abstract:  "be happy"                        → accepts everything, discriminates nothing
Useful zone:   "bike lane app for São Paulo"     → rejects irrelevant, survives changes
Too concrete:  "PWA with Mapbox + CET API"       → rigid plan disguised as a goal
```

A predicate in the useful zone is one that still makes sense even if the entire stack changes.

---

## Risk-return scoring

When the tree has multiple pending nodes, the system must pick one to work on next. The scoring model has three dimensions.

### 1. Incerteza (Uncertainty)

Measured as `max()` of three sub-dimensions:

**Executabilidade** — "Can the agent deliver this well, given its known limitations?" Covers both technical feasibility and agent self-awareness (e.g., the agent is weak at UI/UX, may have outdated information about a library, or lacks access to required external systems).

**Coerência** — "Does this clearly contribute to the parent predicate, and do human and agent understand the same thing?" Catches both drift from parent intent and miscommunication about scope.

**Verificabilidade** — "Can satisfaction be confirmed with available means?" Catches both external dependencies (requires real users, live APIs, or production data) and predicates whose success criterion is inherently subjective.

Each sub-dimension scores **high / medium / low**. Incerteza = max(executabilidade, coerência, verificabilidade).

| | High | Medium | Low |
|---|---|---|---|
| **Executabilidade** | "recursive skills work with 3 levels of nesting" (never tested if Skill tool supports recursion) | "readme converts visitors" (hypothesis but no data) | "add badge to README" (clear how to do, no unknowns) |
| **Coerência** | patch-improve-run-ui under eleicao-risco-retorno (UX improvement doesn't address risk-return logic) | "validacao-contextual" (related but tangential to parent) | "criterios-risco-retorno-doc" under eleicao-risco-retorno (directly addresses parent) |
| **Verificabilidade** | "test-outsider" (requires a real external user to validate) | "readme-converte" (partially testable with analytics) | "engineering-standards" (verifiable by code inspection) |

### 2. Impacto (Impact)

How much does satisfying this predicate change the truth value of its parent? **High** = parent is dramatically closer to satisfied. **Low** = marginal contribution.

| High | Medium | Low |
|---|---|---|
| "simulacao-novo-usuario" (validates the entire user journey) | "validacao-contextual" (improves one facet of the parent) | "auto-save-notes" (convenience feature, not load-bearing) |

### 3. Retorno (Return)

Value gained relative to effort required. **High** = large payoff for small investment. **Low** = substantial work for marginal gain.

| High | Medium | Low |
|---|---|---|
| 1-file patch that unblocks 3 downstream nodes | 1-week sprint that advances 1 node by one step | long open-ended investigation with uncertain result |

### Priority rule

**Incerteza-first.** Kill the unknown before optimizing value delivery. Within the same uncertainty tier, tiebreak by impacto × retorno.

| Tier | Condition | Rationale |
|---|---|---|
| 1 | Incerteza **alta** | Untested premise that could invalidate everything below it |
| 2 | Incerteza **média** | Meaningful uncertainty, but the direction is probably right |
| 3 | Incerteza **baixa** | Execution risk only — do after higher-uncertainty nodes |
| Tiebreak | Same tier | impacto alto + retorno alto > impacto alto + retorno médio > … |

The evaluate agent uses this model when proposing candidate children (ordered by priority). `select-next-node` uses this model when traversing the tree to choose the next active node.
