# The Fractal Law

## The primitive

There is a single operation governing all work between human and agent:

```
// entry point
root_predicate ← extract_goal(human)  // precondition, not part of the primitive
fractal(root_predicate)

fractal(predicate):
  response ← evaluate(predicate, existing_children)

  if is_unachievable(response):
    prune(predicate)
    return pruned

  if response.type == leaf:
    if response.leaf_type == action:
      present_action(predicate, response.prd_seed)
      human reports evidence → satisfied | fractal(predicate)

    else:
      prd ← specify(predicate, response.prd_seed)
      human validates prd

      if response.leaf_type == patch:
        patch(prd)
        human validates → satisfied | fractal(predicate)

      else:  // cycle
        planning(prd)
        delivery(prd)
        review(prd)
        ship(prd)
        human validates → satisfied | fractal(predicate)

  if response.type == new_child:
    child ← create_pending(response.child_predicate)
    human validates proposal:
      if accepted → fractal(child)
      if rejected → fractal(predicate)  // propose alternative
    // after child resolves, re-evaluate parent:
    delete discovery(predicate)  // force re-evaluation
    fractal(predicate)  // re-enters with updated children

  if response.type == complete:
    if has_pending_children(predicate):
      next ← select_pending_child()
      fractal(next)
      delete discovery(predicate)
      fractal(predicate)
    else:  // all children satisfied
      draft_conclusion ← synthesize(children.conclusions)
      human validates → satisfied | generate_new_child
```

This operation is fractal. It works identically at any scale — from "build a company" to "rename this variable". There are no different kinds of planning. There is one operation, repeated.

The tree grows incrementally — one child at a time. After a child is resolved, the parent is re-evaluated: the evaluator sees all existing children (including their conclusions) and decides whether more decomposition is needed. Branch and leaf are not classifications — they emerge from the evaluator's responses.

### Leaf execution modes

The evaluator classifies every leaf into one of three execution modes, persisted as `leaf_type` in `discovery.md`:

- **patch** — resolves with a focused code change. Trivial scope, small blast radius, no architectural decisions. `/fractal:patch` handles it directly.
- **cycle** — resolves with the full sprint: prd → plan → delivery → review → ship. Too complex or risky for a patch. Goes through the `specify` step first.
- **action** — resolves with a real-world human action. The agent cannot execute this — it presents what needs to be done, the human performs the action and reports evidence. Examples: "discover client's main pain point", "validate pricing with 3 prospects". No code artifacts produced. Evidence is captured as `conclusion.md` when the human reports back.

### Mapping to the execution cycle

- **Discovery** = a formalized phase. The evaluator examines the predicate, its existing children, and repo context. It returns one of four responses (`new_child`, `complete`, `leaf`, `unachievable`) and writes `discovery.md`. For `leaf` responses, it provides a `prd_seed` — the one-sentence scope of the PRD (or, for `action` leaves, the evidence required). Parent `discovery.md` is deleted when a child ascends, forcing re-evaluation.
- **Specify** = the step that turns a leaf's `prd_seed` into a full `prd.md` with acceptance criteria, out-of-scope, and constraints. Human validates before sprint begins. Only applies to `patch` and `cycle` leaves.
- **Planning → Delivery → Review → Ship** = the atomic execution unit for `cycle` leaf predicates. Reads `prd.md` as primary requirement.
- **Patch** = shortcut for `patch` leaf predicates — trivially satisfiable without a full sprint.
- **Action** = human-executed path for `action` leaf predicates — the agent presents the task, the human acts and reports back.

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

### Satisfaction

There are three satisfaction paths, each with its own conclusion-writing protocol.

**Leaf (patch/cycle)** — agent-driven satisfaction:
After ship marks `status: satisfied`, the ship step writes `conclusion.md` in the node directory. The agent has full context (review.md, results.md, PR) and writes it automatically.

**Leaf (action)** — human-driven satisfaction:
1. Agent presents what needs to be done + what evidence to bring back (from `prd_seed`)
2. Human performs the real-world action
3. Human returns and reports evidence (via AskUserQuestion gate)
4. Agent captures the human's report as `conclusion.md`
5. Agent asks: "does this satisfy the predicate?"
6. If yes → `status: satisfied`, advance
7. If not → agent reformulates what's missing, back to step 1

**Branch** — compositional satisfaction:
1. Child satisfied → run re-evaluates the branch
2. If more children needed → propose next child, continue
3. If "looks sufficient" → agent drafts conclusion from children's conclusions (synthesizes how children compose to satisfy the parent)
4. Agent presents draft conclusion to human: "is this branch satisfied?"
5. If yes → human validates/edits conclusion → `status: satisfied`
6. If not → human says what's missing → generate new child

### Objection satisfaction — durability requirement

In objection mode, "satisfied" (refuted) means the capability is permanently encoded. The test: if every /tmp file were deleted and the session reset, would the agent still possess the capability?

A one-time demonstration proves *possibility*. Refutation requires *encoding*: a committed skill, gate, standard, test, or documented conclusion that survives session reset.

**Intrinsic exception:** Epistemic objections ("o agente não sabe X") are satisfied when the knowledge is captured as conclusion.md — the document IS the encoding. The durability test applies to capability claims, not one-time knowledge acts.

### Evaluate (Discovery)

The mechanism that drives all branching and routing decisions in the primitive. An evaluate subagent receives a predicate, its existing children (with status and conclusions), and the full repo context. It returns exactly one of four responses:

- **new_child** — the predicate needs decomposition. One child is proposed, prioritizing risk/acquisition before scope.
- **complete** — all necessary children exist. No more decomposition needed.
- **leaf** — the predicate is directly satisfiable. Includes `prd_seed` and `leaf_type`.
- **unachievable** — the predicate cannot be satisfied given current constraints.

The evaluator is called repeatedly on the same node as children are resolved. Each call sees the updated tree. Its output is persisted as `discovery.md` before routing — but `discovery.md` on parent nodes is deleted when a child ascends, forcing re-evaluation with fresh context. Child nodes retain their `discovery.md`.

## Definitions

**Predicate:** a condition that, when satisfied, constitutes progress toward the parent predicate. Not a task — a truth to be reached. Action emerges from the predicate. Predicates come in two kinds depending on how satisfaction is judged:

**Verifiable predicate (leaf):** a predicate whose satisfaction can be confirmed objectively — by running a test, observing output, or checking a concrete condition. Base case of the recursion. Never has children. Verification happens through one of three modes depending on the predicate's nature:

- **test** — automated check confirms satisfaction (code, CI, integration test)
- **observation** — human observes system behavior and confirms (demo, user flow, manual QA)
- **evidence** — human performs a real-world action and reports what was learned (customer call, market research, stakeholder meeting)

All three modes are falsifiable — they differ in mechanism, not in rigor. A predicate verified by evidence ("client's pain point is documented") is as legitimate as one verified by test ("API returns 200").

**Satisfiable predicate (branch):** a predicate whose satisfaction is judged by the human. The human decides when the composition of children is "enough." There is no binary test — the human exercises bounded judgment over the whole. Never has `prd.md`, `plan.md`, or other sprint artifacts. Its truth is derived from its parts, but the derivation is a human call.

**Predicate tree:** the persistent structure of the project. Each node is a predicate with: condition, status (pending | satisfied | pruned), children. The tree is the plan, the log, and the state — simultaneously. Branches are satisfiable; leaves are verifiable. The algebra is closed — both are predicates.

**Root predicate:** the goal extracted from the human. It sits in the useful abstraction window — specific enough to reject irrelevant steps, abstract enough to survive implementation changes. Always satisfiable (the human judges when the goal is reached).

**Discovery:** the ephemeral evaluation artifact. The evaluator examines a predicate and its existing children, writes `discovery.md` with its response. Parent nodes' `discovery.md` is deleted when a child ascends, forcing re-evaluation. Child nodes retain theirs.

**Active node:** a session-scoped pointer to the predicate being worked on. Between sessions, `active_node` rests at `"."` (root). When `/fractal:run` is invoked and the pointer is at root, the system traverses the tree, identifies the highest-priority pending node, and presents it to the human for validation. Within a session, there is always exactly one active node per tree.

**Tree:** a predicate tree for a repository. Each repo may have multiple trees under `.fractal/`, each tracking an independent objective. If a sub-predicate falls outside the scope of the root predicate, either redefine the root (objective mutation), discard the sub-predicate, or create a separate tree. Tree creation and objective mutation are handled by `/fractal:init`.

**Pruned:** a predicate the agent recognized as unachievable. Permanent at that node, but does not kill the parent — it forces re-evaluation and generation of another path.

**Conclusion:** per-node artifact written at the moment of satisfaction. Records what was achieved (oriented toward the parent predicate), key decisions made, and items explicitly deferred. For technical leaves, written automatically by ship. For action leaves, captured from the human's evidence report. For branches, synthesized from children's conclusions and validated by the human. Persisted as `conclusion.md` in the node directory. Conclusions enable progressive disclosure: the tree summary reads conclusions to present up-to-date project state without loading sprint artifacts.

**Leaf type:** classification of how a leaf predicate is satisfied. Determined by the evaluator during discovery and persisted in `discovery.md`.

- **patch** — trivially satisfiable by a focused code change. No architectural decisions, clear scope, small blast radius.
- **cycle** — requires the full sprint: prd → plan → delivery → review → ship. Too complex or risky for a patch.
- **action** — satisfiable only by a human action in the real world. The agent cannot execute this — it presents what needs to be done, the human performs the action and reports evidence. Examples: "client's primary pain point is documented after discovery call", "pricing validated with 3 prospects", "team alignment confirmed in meeting". Evidence is captured as `conclusion.md` when the human reports back.

## The rules

### 1. The goal is the predicate
There is no plan separate from the goal. The root goal is the first predicate. Each subdivision generates child predicates that inherit the same type. The algebra is closed.

### 2. Reactive, not contractual
There is no plan as contract. If the root goal changes, a new root node is created in the tree. The previous tree persists as history, but the recursion restarts from the new root. Nothing is lost, and the depth corrects itself.

### 3. One active node per tree, multiple trees allowed
Each repo may have multiple predicate trees. Each tree has exactly one predicate being worked on. When multiple trees exist, the session selects which tree to operate on (via argument or interactive selection). Delegation changes the executor of the node, it does not create parallel nodes. Parallelism is internal optimization of the execution cycle. Between sessions, the active node resets to root. Each new session discovers its own focus via tree traversal.

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

The evaluate agent uses this model when proposing child predicates (prioritizing highest-uncertainty nodes). `select-next-node` uses this model when traversing the tree to choose the next active node.
