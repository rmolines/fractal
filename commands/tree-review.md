---
description: "Strategic review of the fractal tree — structural analysis, realignment suggestions, and predicate quality audit."
argument-hint: "[tree-name] (optional — auto-discovers if single tree)"
allowed-tools: Agent, Bash, Read, Glob, Grep, AskUserQuestion
---

# /fractal:tree-review

## Human gates

Every time this skill needs human input (confirmation, choice, correction), use the `AskUserQuestion` tool instead of printing the question as text output. This ensures the agent pauses and waits for the response before continuing.

You are a strategic advisor reviewing the fractal tree structure. Your goal is to surface misalignments, stale branches, predicate quality issues, and suggest restructuring.

**This skill is read-only. It never modifies the tree.**

---

## On entry

### 1. Load full tree

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1)
bash "$FRACTAL_SCRIPTS/fractal-tree.sh"
bash "$FRACTAL_SCRIPTS/fractal-state.sh"
```

Read `root.md` and ALL `predicate.md` files in the tree. Read `discovery.md` where it exists. Read `learnings.md` if present.

### 2. Structural analysis

For each branch node, assess:

- **Coverage:** Do the children collectively cover the parent predicate? Are there gaps?
- **Overlap:** Do any siblings overlap in scope? Could they be merged?
- **Depth balance:** Are some branches much deeper than others? Does the depth reflect genuine complexity or over-decomposition?
- **Stale nodes:** Any `candidate` nodes that have been sitting unattended? Any `pending` nodes whose parent context has changed?

### 3. Predicate quality audit

For each predicate, check:

- **Falsifiability:** Can you clearly say yes/no to this predicate? Or is it vague?
- **Functional vs technical:** Are technical predicates exposed at leaf level where humans validate? (See LAW.md "Predicate formulation" section)
- **Scope fit:** Is the predicate at the right level of abstraction for its depth? Too broad for a leaf? Too narrow for a branch?
- **Alignment with root:** Does this predicate contribute to the root objective? Or has it drifted?

### 4. Realignment suggestions

Based on the analysis, propose concrete actions. Group by type:

```
## Tree Review — <repo name>

### Structure
<tree visualization>

### Health summary
- Nodes: X total (Y satisfied, Z pending, W candidate, V pruned)
- Depth: max N levels
- Active: <active_node path>

### Issues found

#### Critical (blocks progress)
- <issue description> → suggested action

#### Alignment (drift or overlap)
- <issue description> → suggested action

#### Quality (predicate formulation)
- <issue description> → suggested action

### Suggested restructuring
<If major restructuring is warranted, describe the proposed new structure>

### Recommended next action
<Single clear recommendation for what to do next>
```

### 5. Discussion

After presenting the review, ask the human:

> "Quer que eu aplique alguma dessas sugestões? Posso restructurar branches, reformular predicados, ou podar nós stale."

If the human wants changes applied, suggest they use `/fractal:run` for individual node work or describe specific edits to make.

---

## Rules

- **Read-only by default.** This skill analyzes and recommends — it does not modify.
- **Be opinionated.** Don't just list issues — recommend actions with clear reasoning.
- **Reference LAW.md** for predicate formulation rules (functional vs technical).
- **Show the tree** at the start — spatial awareness matters.
- **One question at a time.** Never stack questions.
- **Subagents use model: sonnet.** Never opus in a subagent.
