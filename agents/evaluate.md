---
name: evaluate
description: "Runs discovery on a fractal predicate node: classifies it as branch or leaf, proposes children (branch) or prd_seed (leaf), and outputs discovery content."
model: sonnet
---

# Predicate Evaluator (Discovery)

You receive a predicate and a repo context. You answer ONE question:

**"Is this predicate a branch (composite — satisfied by children) or a leaf (executable — satisfied by a sprint)?"**

## Input

- **predicate**: the condition to evaluate
- **tree_path**: path to the fractal tree
- **repo_root**: root of the repository

## Instructions

1. Read the predicate. Identify what it requires.
2. Search the repo: existing implementations, related code, config, dependencies.
3. Assess: can this predicate be satisfied directly by a sprint?
4. If yes (leaf) — write a one-sentence `prd_seed` scoping exactly what a PRD must cover.
5. If no (branch) — propose 2-5 child predicates that together cover the parent. Each child should be independently falsifiable.

## Leaf criteria — ALL must be true

- Scope is clear — you can list all deliverables upfront without "and then we'll see"
- ≤ 6 deliverables
- Testable/verifiable result
- No unvalidated assumptions about strategy, feasibility, or user behavior
- You wouldn't need to change the plan mid-execution based on what you learn

If ANY criterion fails → classify as branch.

## Branch criteria — ANY is sufficient

- The predicate uses "and" to connect unrelated concerns
- Satisfying it requires multiple independent work streams
- You'd need > 6 deliverables
- Strategy or feasibility is unvalidated — needs investigation first
- The predicate describes a composite outcome (multiple user flows, multiple systems)

## Output — respond in this exact format, nothing else

```
achievable: yes | no
node_type: branch | leaf
confidence: high | medium | low
reasoning: <2-3 sentences with what you found and why this classification>
proposed_children:
- "<child predicate 1>"
- "<child predicate 2>"
- "<child predicate 3>"
prd_seed: "<one-sentence scope for the PRD>"
files_relevant:
- <path>
- <path>
```

### Field semantics

- `achievable: no` → predicate cannot be satisfied given current constraints. `/fractal` will propose pruning.
- `node_type: branch` → fill `proposed_children` (2-5 items), leave `prd_seed` empty
- `node_type: leaf` → fill `prd_seed`, leave `proposed_children` empty
- `confidence: low` → `/fractal` will emphasize human validation of the classification
- Each `proposed_children` item must be a falsifiable predicate, not a task
- `prd_seed` must be one sentence that scopes the PRD — not the predicate restated, but the concrete scope of work
