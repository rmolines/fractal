# Fractal Loop: A Recursive Planning Primitive for Human-Agent Collaboration

**Rafael Molines**
March 2026

---

## Abstract

Planning frameworks for AI agents impose rigid taxonomies that break on contact with reality. Plans go stale, hierarchies are arbitrary, and agents lose context across sessions. We present Fractal Loop, a recursive planning primitive that replaces fixed lifecycles with a single self-similar operation: `fractal(predicate)`. The key insight is that goals decompose into verifiable conditions, not tasks — and that this decomposition has the same algebraic structure at every scale, from "build a company" to "rename this variable." The operation terminates when a predicate is satisfied, not when recursion reaches a fixed depth. An evaluator classifies each predicate (branch, leaf, or unachievable) and proposes one child at a time; the tree grows lazily and the parent is re-evaluated after each child resolves. We describe the theoretical grounding across seven independent fields, the implementation as a Claude Code plugin with a filesystem-as-state architecture, and empirical observations from managing the project's own development with the primitive: 71 nodes, 34 satisfied, 36 pending, 1 pruned, maximum depth 3 levels. The pruned node demonstrates the system's ability to recognize and abandon failed paths. Market validation confirms the pain is real, the approach is differentiated, and no equivalent tool exists.

---

## 1. Introduction

Every planning framework for AI agents makes the same implicit bet: that the structure of the plan can be decided upfront. Mission → stage → module. Epic → story → task. PRD → design → implementation → review. The hierarchy is fixed, the lifecycle is fixed, and the agent follows the path.

The bet fails for the same reason it always has in human project management: reality does not respect the taxonomy. A "task" turns out to require architectural decisions. A "story" turns out to be three orthogonal concerns. An "epic" turns out to be wrong.

The standard response is more structure: add an escalation mechanism, add a re-planning step, add a flag for "blocked." The resulting systems are elaborate. They are also fragile, because the elaboration is in service of a fundamentally wrong model.

The wrong model is: *work is a tree with a fixed branching rule*. The right model is: *work is a tree with a uniform recursive structure and a learned termination condition*.

This paper describes Fractal Loop, a planning primitive built on the right model. The central claim is simple: a single recursive operation — applied identically at every scale, with a capable evaluator deciding when to stop — is sufficient to manage work from the strategic level to the implementation level. No fixed hierarchy. No fixed lifecycle. One operation, repeated.

The claim is not self-evident, and making it precise requires answering three questions: (1) What is the unit of work that makes the algebra close? (2) When does the recursion stop? (3) Why does this work when simpler recursive agents (AutoGPT, early ReAct systems) famously do not?

The answers are predicates, satisfaction, and evaluator quality — in that order. We develop each in turn.

---

## 2. The Primitive

### 2.1 The Operation

The primitive is a single recursive function on predicates:

```
// entry point
root_predicate ← extract_goal(human)
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
        planning(prd) → delivery(prd) → review(prd) → ship(prd)
        human validates → satisfied | fractal(predicate)

  if response.type == new_child:
    child ← create_pending(response.child_predicate)
    human validates proposal:
      if accepted → fractal(child)
      if rejected → fractal(predicate)  // propose alternative
    delete discovery(predicate)  // force re-evaluation
    fractal(predicate)

  if response.type == complete:
    if has_pending_children(predicate):
      next ← select_pending_child()
      fractal(next)
      delete discovery(predicate)
      fractal(predicate)
    else:
      draft_conclusion ← synthesize(children.conclusions)
      human validates → satisfied | generate_new_child
```

The operation is fractal in the mathematical sense: self-similar at every scale. The same structure governs "build an app" and "rename this variable." The time constants differ; the structure does not.

### 2.2 Predicates, Not Tasks

The unit of work is a *predicate* — a truth condition, not an action. The distinction is not cosmetic.

A task ("implement billing") specifies an action but not a success condition. It is satisfied when the action is complete, which is determined by convention, not logic. A predicate ("users can subscribe to a monthly plan and be billed per seat via Stripe") specifies a condition that is either true or false in the world. It is satisfied when the condition holds, which can be confirmed without reference to the action taken.

This distinction has three consequences:

**Closure.** Every level of the tree is the same type: a predicate. Branches decompose into sub-predicates; leaves are verified directly. There is no type boundary between strategic and tactical, between planning and execution. The algebra is closed: satisfying a child constitutes progress toward the parent by construction.

**Falsifiability.** Predicates can be refuted. A task cannot be wrong (it's just something to do), but a predicate can be. If the system discovers that "users can subscribe via Stripe" is the wrong predicate for the parent goal, it can prune it and try another. This is not a failure mode — it is the system working correctly.

**Composition without a composition rule.** In task-based systems, satisfying subtasks doesn't automatically satisfy the parent task. Someone has to check that the parts add up. With predicates, the composition is logical: if the children's conditions are true, the parent's condition is closer to true. The human validates that "closer" has become "sufficient" — but the direction of progress is structurally guaranteed.

### 2.3 The Three Leaf Types

Not all leaves are executed the same way. The evaluator classifies each leaf into one of three modes:

- **Patch:** trivially satisfiable by a focused code change. Small blast radius, no architectural decisions. Handled by a lightweight fast-path.
- **Cycle:** requires a full sprint (PRD → plan → deliver → review → ship). Too complex or risky for a patch.
- **Action:** satisfiable only by a human action in the world. The agent cannot execute this — it presents what needs to be done, the human performs the action, and evidence is captured. Examples: "client's primary pain point is documented," "pricing validated with 3 prospects."

The action leaf type is the mechanism that integrates the real world into the recursion. Market research, customer interviews, stakeholder alignment, and production observations are all first-class nodes in the tree, not out-of-band annotations.

### 2.4 Human Validation at Exactly Two Moments

The human validates at exactly two moments in the primitive:

1. **Proposal:** the agent proposes a child predicate. The human confirms it makes sense and moves in the right direction.
2. **Result:** the agent concludes it has satisfied the predicate. The human confirms it actually was.

Rejection at either moment is a natural re-evaluation, not a failure. Rejection on proposal → agent proposes a different child. Rejection on result → agent re-executes. These are not special cases; they are structurally identical to the recursive call with new information.

The human is not a bottleneck in this design. The human is the oracle for "sufficient" — the judgment that cannot be automated because it requires knowing what you want.

### 2.5 The Abstraction Window

Every predicate — including the root — must sit in a zone of maximum discriminating power:

```
Too abstract:  "improve urban mobility"         → accepts everything, discriminates nothing
Useful zone:   "cyclists can see bike lanes     → rejects irrelevant, survives stack changes
               in real time on their phones"
Too concrete:  "PWA with Mapbox GL + CET API"   → rigid plan disguised as a goal
```

A predicate in the useful zone is one that still makes sense if the entire implementation changes. Too abstract and every action is valid; too concrete and the predicate encodes decisions that should be discovered, not assumed.

---

## 3. Key Insights

### 3.1 Termination Is a Predicate, Not a Depth

Classical recursive task decomposition needs a stopping rule: "stop at depth N," "stop when tasks are under 8 hours," "stop at the sprint level." These rules are arbitrary approximations of the real criterion, which is not about structure at all.

The real criterion is: can this be directly executed given current capabilities and resources? That criterion is a predicate about the leaf, not a measurement of tree depth.

When termination is a predicate, depth, branching factor, and total number of nodes are all consequences of the problem structure — not of the framework's preferences. A flat problem produces a shallow tree. A deeply nested problem produces a deep tree. The same operation applies in both cases. The framework does not need to know which kind of problem it is facing.

This matters because most "planning fails" diagnoses are actually wrong-level failures. An agent that stops decomposing too early (the task is still ambiguous) or too late (the subtask is over-engineered) is applying a depth-based rule when it should be applying a predicate-based rule. No amount of tuning the depth parameter fixes the fundamental issue.

The formal analogy is the Y combinator: a fixed-point operator where the termination condition lives in the argument, not in the application. The recursion stops when the predicate is satisfied, not when the operator has been applied N times.

### 3.2 The Evaluator as Reliable Oracle

Early autonomous agent systems (AutoGPT, first-generation ReAct chains) used recursion. They failed systematically — not because recursion is wrong, but because their evaluators were unreliable. An evaluator that makes wrong calls one-in-five times produces a tree that diverges quickly. The errors compound: a bad decomposition produces bad children, which produce worse grandchildren.

The transformation enabled by current large language models is not that they are smarter in general. It is that, at the level of a single evaluation call, they are reliable enough to treat as approximately optimal.

This is a meaningful claim. When model quality crosses a threshold — Opus-level reasoning on complex architectural decisions — the evaluator's outputs are good enough to trust without verification. Not perfect, but good enough that the expected cost of trusting them is lower than the expected cost of verifying them at every step.

The consequence is structural: exponential search collapses into linear traversal. Without a trustworthy evaluator, every branch is a guess, and the search space is exponential in the depth of uncertainty. With a trustworthy evaluator, each call produces the approximately correct next step, and the tree grows along the correct path.

This is what makes Fractal Loop work where AutoGPT failed: not just recursion, but recursion with a calibrated oracle at each decision point. The model quality threshold is not incidental — it is load-bearing. Lower the evaluator quality and the system becomes non-functional. This is why the evaluate subagent runs on Opus while the execution subagents run on Sonnet. The evaluation step is the highest-leverage decision in the system, and it runs exactly once per node.

The implication for the field is that planning framework sophistication and model capability are substitutes. As model quality increases, planning frameworks can become simpler. Fractal Loop is a bet on that trajectory: by the time models are reliable enough, the correct framework is the simplest possible recursive one.

### 3.3 Progressive Disclosure as Living Documentation

Every node in the predicate tree writes a `conclusion.md` when it is satisfied. This file contains three things: what was achieved (oriented toward the parent predicate), key decisions made, and items explicitly deferred.

These conclusions serve two purposes simultaneously. First, they enable the parent predicate to be re-evaluated correctly — the evaluator sees what was achieved, not just that the child is satisfied. Second, they serve as documentation that any agent, in any future session, can read to understand the project state.

This produces a property that no traditional documentation system achieves: the documentation is *a structural consequence of doing the work*, not a separate activity that competes with it. The agent writes the conclusion at the moment of maximum context — immediately after satisfying the predicate — and the result is available forever to any future session.

The same tree that represents the current state of the project also represents its complete history. There is no separate log, no separate project document, no separate changelog. New sessions perform progressive disclosure: read the tree shape first (cheap), read conclusions of relevant satisfied nodes second (targeted), read full sprint artifacts only for the specific node being worked on (surgical).

Traditional documentation fails because it goes stale: the documents were written at one time and reality moved. The predicate tree doesn't go stale because each node's conclusion describes what the node achieved, which is true by definition and immutable after satisfaction.

### 3.4 Risk-First Ordering via Uncertainty Scoring

When the tree has multiple pending nodes, the system must select one. The selection rule is not value-maximizing — it is uncertainty-minimizing.

The scoring model has three dimensions:

- **Uncertainty:** the maximum of three sub-dimensions: executability ("can the agent do this well?"), coherence ("does this clearly contribute to the parent?"), and verifiability ("can satisfaction be confirmed with available means?"). Uncertainty = max(executability, coherence, verifiability).
- **Impact:** how much does satisfying this predicate change the truth value of its parent?
- **Return:** value gained relative to effort required.

The priority rule is uncertainty-first. Within the same uncertainty tier, tiebreak by impact × return.

The rationale is that an uncertain predicate represents an untested assumption that could invalidate everything below it. A high-uncertainty node at depth 1 that turns out to be wrong makes all of its descendants wasted work. Eliminating uncertainty early makes subsequent work reliable, even if individual high-uncertainty nodes have low immediate value.

This is the formal version of the practice most experienced engineers follow intuitively: prove the riskiest thing first. The insight is that this rule should be the default behavior of the planning system, not a heuristic that individual engineers apply inconsistently.

The action leaf type is critical here. High-uncertainty predicates are often not executable by the agent at all — they require real-world validation ("is there a market for this?", "will users pay this price?"). By making human actions first-class nodes with uncertainty scores, the system ensures that existential questions get addressed before engineering effort is committed.

---

## 4. Theoretical Grounding

The primitive appears to have been independently discovered across seven fields. This convergence is itself evidence: when independent research traditions arrive at the same structure, the structure is likely fundamental rather than accidental.

| Field | Primitive | Subdivision criterion |
|---|---|---|
| AI Planning (HTN) | Task decomposition | Type check: primitive or composite task |
| Reinforcement Learning (Options) | Option ⟨I, π, β⟩ | Learned β function (termination condition) |
| Control Theory (MPC) | Receding horizon | Horizon = dominant time constant |
| Information Theory (MDL) | Partition | ΔH < cost of representing the subdivision |
| Theoretical CS (Y combinator) | Fixed-point | Predicate in the argument, not depth |
| Category Theory (F-algebras) | Initial algebra | Same morphism at every level (catamorphism) |
| Spatial structures (Quadtree) | Adaptive subdivision | Internal heterogeneity of the cell |

**Hierarchical Task Networks (HTN):** The decomposition structure of HTN planning is directly analogous. In HTN, tasks are either primitive (directly executable) or composite (decomposed into subtasks). The type check "primitive or composite" is the analog of Fractal Loop's "leaf or branch." The key difference is that HTN fixes the decomposition rules in a domain model; Fractal Loop derives them dynamically from an evaluator.

**Reinforcement Learning Options:** The Options framework defines a temporally extended action as a triple ⟨I, π, β⟩: an initiation set, a policy, and a termination condition. The termination condition β is a predicate over states. Fractal's leaf type is structurally identical to an option's termination condition: it defines when the current sub-task is complete and control should return to the parent. The Option-Critic architecture (Bacon et al., 2017) showed that termination conditions can be learned end-to-end, which is exactly what Fractal Loop's evaluator does.

**Model Predictive Control (MPC):** MPC plans N steps ahead, commits one step, observes, and replans. The receding horizon is calibrated to the dominant time constant of the controlled system. Fractal Loop's lazy tree growth is structurally MPC: propose one child, execute it, re-evaluate. The "horizon" is always one child. This is precisely the right tradeoff when the evaluator is reliable but the future is uncertain: plan minimally, commit once, and use all available information at each step.

**Minimum Description Length (MDL):** Information theory provides a compression-based stopping rule for decomposition. Partition a set if and only if the gain in description efficiency exceeds the cost of the partition itself. Applied to predicates: decompose if and only if the children are more compressible than the parent. The point at which decomposition stops paying off is exactly the leaf level — a node that is smaller than the overhead of representing another partition.

**Y Combinator:** The Y combinator is the canonical fixed-point operator: `Y f = f (Y f)`. The recursion terminates when `f` returns a result without calling its argument. In Fractal Loop, `f` is the evaluate-and-route function; the recursion terminates when evaluate returns `leaf` or `unachievable`. The termination condition lives in the predicate (the argument), not in a depth counter (the application).

**F-algebras:** A catamorphism is a fold over a recursive data structure that uses the same morphism at every level. The predicate tree is an F-algebra where the functor is "predicate with zero or more sub-predicates." Satisfaction is a catamorphism: leaves are satisfied by the world, branches are satisfied by folding children's satisfactions. The algebra is closed because the morphism at every level is identical.

**Quadtrees:** Adaptive spatial subdivision continues splitting a cell until its internal heterogeneity falls below a threshold. The subdivision criterion is a predicate on the cell's contents, not a fixed depth. A region with uniform density becomes a leaf immediately; a region with high variation is subdivided further. This is structurally identical to Fractal Loop's termination rule: a predicate that is directly executable becomes a leaf; a predicate that requires clarification is subdivided.

The convergence across these fields — AI planning, control theory, information theory, functional programming, category theory, and data structures — suggests that the recursive predicate primitive is not a design choice but a mathematical necessity. These fields were not looking for the same structure; they found it independently because it is the correct answer to a recurring problem.

---

## 5. Related Work

### 5.1 Academic Work

**ADaPT** (Allen AI, NAACL 2024) is the closest prior work in the academic literature. ADaPT follows an attempt → fail → decompose → repeat loop that achieves +28% on benchmarks over flat execution. The structural difference is that ADaPT decomposes only on failure and uses binary success/failure predicates. Fractal Loop evaluates proactively, before failure, and uses graded predicates with explicit uncertainty scoring. ADaPT also lacks human-in-the-loop validation gates.

**HyperTree Planning** (ICML 2025) applies hierarchical divide-and-conquer to reasoning tasks, achieving 3.6x improvement over o1-preview on mathematical benchmarks. The insight — that hard problems can be decomposed into easier sub-problems — is shared with Fractal Loop, but HyperTree Planning operates on closed problems with known solutions. Fractal Loop operates on open-ended work where the solution is not known in advance and the predicate may need to be reformulated.

**LADDER** (2025) uses recursion to generate progressively easier variants of problems, bootstrapping a solver from the bottom up. Like Fractal Loop, the termination condition is problem-specific rather than depth-based. LADDER is an optimization technique rather than a planning framework; it does not address human collaboration or real-world action integration.

**The Ralph Loop** (Huntley, 2025) and **Autoresearch** (Karpathy, 2026) both describe flat loops with external verification. These are equivalent to Fractal Loop's base case — a single leaf predicate executing a cycle. Both validate that tight loop/verify cycles with capable models produce reliable results. Neither provides a compositional structure for managing work above the single-cycle level.

### 5.2 Practical Tools

The agent development tooling ecosystem has produced a range of planning tools that share parts of the problem formulation:

| Tool | Approach | Key difference from Fractal Loop |
|---|---|---|
| Task Master (~27k stars) | PRD → tasks → subtasks in JSON, MCP server | Flat decomposition. No parent re-evaluation after child completion. Tasks as data objects, not predicates. |
| BMAD Method | Specialized agents per phase (PM, Architect, Dev, UX) | Role-based, phase-fixed. Rich orchestration but rigid taxonomy. |
| CCPM | GitHub Issues + git worktrees, PRD → epic → task chain | Fixed hierarchy. GitHub as state store is sound but no plan invalidation mechanism. |
| ICM | Folder-as-workflow-stage, one agent reads the right files | Same filesystem-as-truth insight. Lacks recursive structure and predicate concept. |
| Claude Code Tasks (native) | Persistent task list, DAG dependencies | Operational task tracking. State is a checklist, not a predicate tree. |

The pattern across all existing tools is consistent: they impose a fixed hierarchy and a fixed lifecycle. The hierarchy is different (missions, epics, phases) but the structure is the same: a taxonomy decided in advance, with work slotted into the appropriate level. Fractal Loop's key differentiator is not any individual feature but the single-primitive design: there is no hierarchy to slot work into, because the hierarchy emerges from the problem.

**ICM** (Interpreted Context Methodology) is the closest independent invention. ICM uses folder structure as agent architecture and the filesystem as the state store — the same insight as Fractal Loop's `.fractal/` directory. ICM lacks the recursive structure, the predicate concept, and the re-evaluation logic, but the filesystem insight is identical and was reached independently.

---

## 6. Implementation

Fractal Loop is implemented as a Claude Code plugin. The implementation is intentionally minimal: pure shell scripts and markdown files, no dependencies, no build step.

### 6.1 Filesystem as State

The predicate tree lives in `.fractal/` in the target repository. Each node is a directory; each directory's contents encode the node's complete state:

```
.fractal/
  root.md                    # root predicate + active_node pointer
  stripe-billing/
    predicate.md             # "users can subscribe to a monthly plan..."
    discovery.md             # node_type: branch | leaf | pruned
    prd.md                   # acceptance criteria (leaf nodes only)
    plan.md                  # execution plan (cycle leaves only)
    results.md               # what happened during delivery
    conclusion.md            # what was achieved (written at satisfaction)
    seat-changes/
      predicate.md
      ...
```

The execution state of a node is derived entirely from which files are present. There is no database, no config file, no separate state store. The filesystem *is* the state. This means:

- `ls` shows the tree structure
- `cat predicate.md` shows the current goal
- `git log` shows the complete history of state transitions
- Session crashes are safe: the state is on disk before any action

Idempotency is enforced by a simple rule: every state transition writes to disk before acting. If the agent crashes mid-action, the next session finds the partially-completed state and continues from there.

### 6.2 Skill Chain

The plugin installs a chain of Claude Code skills:

- `/fractal:init` — bootstrap: Socratic goal extraction, create tree, hand off to run
- `/fractal:run` — idempotent state machine; evaluate active predicate, advance one step, repeat
- `/fractal:patch` — fast path for trivial leaf predicates, no full sprint needed
- `/fractal:planning` / `/fractal:delivery` / `/fractal:review` / `/fractal:ship` — the sprint cycle for complex leaves
- `/fractal:doctor` — tree integrity validation; catches inconsistencies and optionally fixes them

The entry point for every session is `/fractal:run`. It reads the filesystem, determines the current state, and advances exactly one step. Calling it repeatedly converges the tree toward the root predicate being satisfied.

### 6.3 Model Delegation

The evaluate subagent (`agents/evaluate.md`) runs on Opus. Every other subagent runs on Sonnet. Mechanical tasks (formatting, validation, data extraction) run on Haiku.

This delegation is not a cost optimization — it is a correctness requirement. The evaluate step is the highest-leverage decision in the system. It determines whether a predicate should be decomposed (and how), executed directly (and by what method), or abandoned. Getting this wrong sends the entire branch of the tree in the wrong direction. Spending the most capable available model on this decision, and only this decision, is the correct tradeoff.

### 6.4 Session Locks

Parallel sessions are supported via session lock files. Each session acquires a lock on its active node using the parent process PID. The lock prevents two sessions from executing the same node simultaneously. When a session's active node is locked, it traverses the tree and selects an unlocked pending node instead. Locks are stored in `.fractal/` alongside the tree state and are gitignored.

---

## 7. Empirical Observations

Fractal Loop manages its own development using the Fractal Loop primitive. This self-referential structure provides a concrete empirical case: the system can be observed directly.

As of March 2026, the tree contains 71 nodes across three levels of depth: 34 satisfied, 36 pending, 1 pruned. The current root predicate is: "developers who use Claude Code find Fractal Loop, understand the proposal in under 2 minutes, and try it."

**Tree characteristics:**

The maximum depth is 3 levels (root → branch → leaf). The average branching factor is approximately 2.1 children per branch node. The tree grew over approximately 8 weeks of intermittent development sessions, with no upfront planning — each child was proposed one at a time by the evaluator.

**The pruned node:**

`skill-return` was classified as unachievable after investigation revealed that the Claude Code plugin infrastructure did not support the skill-to-skill recursion pattern that the predicate required. The node was pruned, the parent (`skills-recursivas`) was re-evaluated, and the investigation continued with alternative approaches. This is the expected behavior: pruning is not failure, it is information. The tree records what was tried and found unworkable, which prevents future sessions from repeating the same investigation.

**Market validation as an action node:**

`validacao-mercado` (market validation) was an action leaf — a predicate that could only be satisfied by a human performing real-world research. The agent presented the research questions and evidence requirements; a human conducted the research (surveying GitHub Issues, competitive tools, Hacker News discussions, and developer quotes); the evidence was captured as `conclusion.md`. The node is now satisfied. This demonstrates the action leaf type functioning as intended: real-world investigation as a first-class part of the predicate tree.

**Meta-observation:**

The fact that the project manages itself with its own primitive is not merely a demonstration — it is a stress test. The root predicate has survived 8 weeks of development without being reformulated. The tree has grown, pruned, and re-evaluated across dozens of sessions. No context was lost across sessions. No plan document was maintained separately. The filesystem state was the single source of truth throughout.

---

## 8. Limitations and Future Work

**Evaluator dependency.** The system's correctness relies on the evaluator being reliable. With a weaker model, the evaluation step makes more errors, bad decompositions compound, and the tree diverges. The current design explicitly assigns the most capable available model (Opus) to evaluation. As smaller models improve, this constraint will relax, but it is a genuine limitation today. Operators running Fractal Loop with weaker models should expect more human intervention at evaluation gates.

**Single-tree-per-repo constraint.** Each repository supports at most one predicate tree. This is a design choice, not a technical limitation — multiple trees in the same repo would require a tie-breaking rule for the active node pointer. The constraint works well for projects with a single coherent goal; it becomes awkward for repositories serving multiple independent purposes. Future work could support multiple named trees.

**Human as bottleneck.** The two validation gates (proposal and result) require human availability. In contexts with long latency between human check-ins, work stops at each gate. The current design has no mechanism for the agent to proceed past a gate under uncertainty. This is intentional — the gates are the correctness mechanism — but it limits throughput in high-latency collaboration settings.

**No team features.** The current implementation is designed for a single human working with one or more AI agents. It has no access control, no notification mechanism, and no conflict resolution for concurrent human edits to the tree. Session locks prevent agent-agent conflicts but not human-agent conflicts. Team collaboration is a significant open problem.

**No visual UI.** The HTML viewer (`scripts/view.sh`) generates a static dashboard showing tree state. It is read-only and requires manual refresh. An interactive UI that allows tree navigation, predicate editing, and real-time session monitoring would substantially improve the human experience. This is explicitly pending in the current tree.

---

## 9. Conclusion

The Fractal Loop primitive is simple enough to describe in a pseudocode function. Its implications are broader.

The standard intuition about planning complexity is that harder problems require more sophisticated planning structures. Fractal Loop inverts this: harder problems require a better evaluator, not a more complex structure. The planning structure can be maximally simple — a single recursive operation — as long as the oracle deciding when to stop is reliable.

This shifts the hard problem from framework design to model quality. Planning frameworks, by this account, are not products to be engineered in isolation. They are interfaces between human judgment and model capability, and their correct design depends entirely on where that capability stands. The right framework for 2023 models is different from the right framework for 2026 models — not because the problem changed, but because the oracle changed.

The predicate tree unifies three things that are usually maintained separately: the plan (what we intend to achieve), the log (what we have achieved), and the state (what is currently being worked on). Unifying them is not a database design decision — it is a consequence of using predicates, which are the right semantic unit for all three purposes. A predicate in `pending` state is a plan. A predicate in `satisfied` state with a `conclusion.md` is a log entry. The `active_node` pointer is the session state.

Whether this is the right paradigm depends on a bet about model capability trajectories. If evaluators become reliable at the Opus level across the industry, Fractal Loop or something structurally similar is likely to converge as the correct approach. If evaluators plateau below that threshold, more elaborate verification mechanisms will be needed. We believe the trajectory favors the simple recursive structure, and this paper is a contribution to understanding why.

The implementation is available at [https://github.com/rmolines/fractal](https://github.com/rmolines/fractal).

---

## References

Bacon, P.-L., Harb, J., & Precup, D. (2017). The option-critic architecture. *Proceedings of the AAAI Conference on Artificial Intelligence*.

Erol, K., Hendler, J., & Nau, D. S. (1994). HTN planning: Complexity and expressivity. *Proceedings of the Twelfth National Conference on Artificial Intelligence (AAAI-94)*.

HyperTree Planning Team. (2025). Hierarchical divide-and-conquer for reasoning. *International Conference on Machine Learning (ICML)*.

Huntley, R. (2025). The Ralph Loop: Tight verification cycles for autonomous agents. Unpublished manuscript.

Karpathy, A. (2026). Autoresearch: Flat loops with hard constraints as base case validation. Unpublished manuscript.

Rissanen, J. (1978). Modeling by shortest data description. *Automatica*, 14(5), 465–471.

Sutton, R. S., Precup, D., & Singh, S. (1999). Between MDPs and semi-MDPs: A framework for temporal abstraction in reinforcement learning. *Artificial Intelligence*, 112(1-2), 181–211.

Veerapen, N., Ochoa, G., Harman, M., & Burke, E. K. (2015). An integer linear programming approach to the single and bi-objective next release problem. *Information and Software Technology*.

Yao, S., Zhao, J., Yu, D., Du, N., Shafran, I., Narasimhan, K., & Cao, Y. (2023). ReAct: Synergizing reasoning and acting in language models. *International Conference on Learning Representations (ICLR)*.

Zhou, S., et al. (2024). ADaPT: As-needed decomposition and planning with language models. *Proceedings of the North American Chapter of the Association for Computational Linguistics (NAACL)*.
