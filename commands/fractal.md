---
description: "Idempotent fractal state machine. Evaluates the active predicate and advances one step. Call repeatedly to converge on the root predicate."
argument-hint: "(none needed — auto-discovers single tree)"
allowed-tools: Skill(fractal *), Agent, Bash, Read, Write, Edit, Glob, AskUserQuestion
---

# /fractal

## Human gates

Every time this skill needs human input (confirmation, choice, correction), use the `AskUserQuestion` tool instead of printing the question as text output. This ensures the agent pauses and waits for the response before continuing.

You operate the recursive predicate primitive. Read `LAW.md` first — it is
the complete specification. This skill is the operational state machine.

**Be a sparring partner, not a form to fill out.** Think critically, push back
when something doesn't add up, and challenge scope or assumptions.

---

## Conversational stance

- Before any question, state what you're trying to decide and why.
- One question at a time. Never stack questions.
- Push back on vague or unfalsifiable predicates.
- When uncertain: "I'm interpreting this as X — is that right?"

---

## State (pre-loaded)

!`cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1); [ -n "$FRACTAL_SCRIPTS" ] && bash "$FRACTAL_SCRIPTS/fractal-state.sh" 2>/dev/null || echo "state: error"`

## Predicate (pre-loaded)

!`cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1); [ -n "$FRACTAL_SCRIPTS" ] && bash "$FRACTAL_SCRIPTS/active-predicate.sh" 2>/dev/null || echo "predicate: error"`

---

## Statechart — the canonical spec

```
GUARD → [error/no-tree: STOP | satisfied/pruned: ASCEND | else: SHOW]
SHOW → DISCOVER
DISCOVER → [has_discovery: ROUTE | else: spawn evaluator → write discovery.md → ROUTE]
ROUTE → [unachievable: PRUNE | branch: SUBDIVIDE | leaf+no_prd: SPECIFY | leaf+prd: EXECUTE]
SPECIFY → write prd.md → human validates → EXECUTE
PRUNE → persist status:pruned → ASCEND
EXECUTE → persist execution.md → [patch | sprint] → STOP
SUBDIVIDE → persist candidates + child → update pointer → self-invoke → STOP
VALIDATE → [satisfied: persist status:satisfied → ASCEND | not: self-invoke → STOP]
ASCEND → [depth=0: COMPLETE → STOP | else: update pointer → self-invoke → STOP]
```

Every transition persists to disk BEFORE acting. This guarantees idempotency:
calling `/fractal` again from the same state produces the same behavior.

---

## Steps — execute in order, do not skip, do not invent steps

### 1. GUARD

Read pre-loaded state.

**Always show the tree first** (unless state is error):

```bash
FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1)
bash "$FRACTAL_SCRIPTS/fractal-tree.sh"
```

Print the tree output immediately — this gives the human instant spatial awareness
of where we are before any decision is made.

Then route:

- `state: error` → STOP. Print "Nenhuma arvore encontrada. Execute /fractal:init."
- `active_status: satisfied` AND `depth: 0` → Print "Predicado raiz satisfeito." STOP.
- `active_status: satisfied` OR `active_status: pruned` → go to step 6 (ASCEND).
- Otherwise → go to step 2 (SHOW).

### 2. SHOW

Run the tree renderer:

```bash
FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1)
bash "$FRACTAL_SCRIPTS/fractal-tree.sh"
```

Print:

```
<breadcrumb>
Predicado: <active_predicate>
Estado: <state> | Filhos: <children_satisfied>/<children_total>
```

If notes exist in active_node's predicate.md → read them (context from prior session).
If `.fractal/learnings.md` exists → read it (calibrate proposals).

→ go to step 3 (DISCOVER).

### 3. DISCOVER

Spawn evaluator subagent:

```
Agent(
  description: "evaluate: <predicate slug>",
  subagent_type: "fractal:evaluate",
  model: "sonnet",
  prompt: "predicate: <active_predicate>\ntree_path: <tree_path>\nrepo_root: <git root>"
)
```

Wait for response. Parse: `achievable`, `node_type`, `confidence`, `proposed_children`, `prd_seed`, `reasoning`.

Present to human:

- `achievable: no`:
  "O predicado parece inatingivel: <reasoning>. Podar este no?"
  → Confirmed → go to 4a (PRUNE)
  → Denied → re-evaluate with human's additional context

- `node_type: leaf`:
  Decide execution mode:
  **Patch** if ALL: <=3 files, no architecture decisions, single concern, describable in 2-3 sentences.
  **Sprint** otherwise.
  "Executar '<prd_seed>' via [patch|sprint]. <reasoning>. Aceita?"
  → Confirmed → go to 4b (EXECUTE)
  → Rejected → ask what human prefers

- `node_type: branch`:
  Trigger candidate generation (see SUBDIVIDE step).
  Present candidates to human.
  → Confirmed → go to 4c (SUBDIVIDE)
  → Rejected → generate alternatives or accept human proposal

### 4a. PRUNE

**Persist BEFORE acting:**

1. Edit active node's `predicate.md`: set `status: pruned`

→ go to step 6 (ASCEND).

### 4b. EXECUTE (base case)

The sub-predicate fits in one sprint. Persist, then run.

**Persist BEFORE acting:**

1. If the sub-predicate differs from the active node's predicate:
   - Create child dir: `mkdir -p <tree_path>/<active_node_rel>/<slug>`
   - Write `<slug>/predicate.md` with `status: pending`, `predicate`, `created`
   - Update `active_node` in `root.md` to new child path

2. Write `execution.md` in the active node dir:

```markdown
---
mode: patch | sprint
sub_predicate: "<sub_predicate>"
reasoning: "<evaluator reasoning>"
created: <YYYY-MM-DD>
---
```

**Then execute:**

- **Patch** → invoke `/fractal:patch <sub_predicate text>`. STOP.
  After patch completes, the next `/fractal` invocation will enter VALIDATE
  (the node will have execution artifacts and human can validate).

- **Sprint** → invoke `/fractal:planning <node_dir_path>`. STOP.
  Follow with `/fractal:delivery`, `/fractal:review`, `/fractal:ship` — each
  receiving the same node dir path. After sprint completes, re-invoke `/fractal`.

### 4c. SUBDIVIDE

The predicate is too large or uncertain. Generate candidates.

**Step 0 — Check for existing candidates:**
Scan child directories for `status: candidate`. If candidates exist, read them.
They represent hypotheses from previous rounds — context may have changed.

**Step 1 — Generate 3-5 candidate sub-predicates** (discovery.md contains proposed_children from the evaluator as a starting point)**:**
Before generating, ask: "Do I have empirical knowledge or am I guessing?"
If guessing → at least one candidate MUST be a strategy investigation.

Each candidate has:
- A falsifiable predicate statement
- Type: scope decomposition | risk investigation | information acquisition
- Why it reduces uncertainty about the parent

**Step 2 — Select the best candidate:**
The one that, once satisfied, most reduces uncertainty about the parent.
Not the easiest. Not the most important. The most clarifying.

**Step 3 — Present to human:**

```
O predicado "<parent>" precisa de subdivisao.

Candidatos:
1. * "<selected>" — <why this most reduces uncertainty>
2.   "<candidate 2>" — <rationale>
3.   "<candidate 3>" — <rationale>
[4-5 if generated]

Recomendo o #1. Aceita, ou prefere outro?
```

**Step 4 — Persist ALL candidates BEFORE acting:**

- **Selected candidate:** create child dir with `predicate.md` (`status: pending`).
  Update `active_node` in `root.md`.
- **Non-selected:** create their dirs with `predicate.md` (`status: candidate`).
  Frontmatter: predicate, status, created, proposed_by, rationale.

If human rejects ALL and proposes something different → create their proposal as
active child, keep agent's as candidates, capture learning in `learnings.md`.

**Then:** invoke `/fractal`. STOP.

### 5. VALIDATE (post-execution)

After patch or sprint completes and human has seen the result.

Ask: "O predicado foi satisfeito?"
- **Yes** → write `status: satisfied` in active node's `predicate.md`. → go to step 6 (ASCEND).
- **No** → capture learning in `.fractal/learnings.md`. Invoke `/fractal`. STOP.

### 6. ASCEND (return)

Active node is satisfied or pruned. Bubble up.

6a. If `depth: 0` (root node):
- If `active_status: satisfied` → "Predicado raiz satisfeito. Arvore completa." STOP.
- If `active_status: pruned` → "Predicado raiz podado. Execute /fractal:init para redefinir." STOP.

6b. Update `active_node` in `root.md` to `parent_path` from pre-loaded state.

6c. Invoke `/fractal`. STOP.

---

## Objective mutation

If the user decides the root objective has changed mid-execution:

1. Record current root predicate in `root.md` `# Root history` section with date
2. Update `predicate` field with new objective
3. Reset `active_node` to `.`
4. Capture learning in `.fractal/learnings.md`
5. Invoke `/fractal`. STOP.

---

## Sprint cycle reference

When EXECUTE chooses patch mode, invoke `/fractal:patch`. When EXECUTE chooses sprint mode, the cycle is:
`/fractal:planning` → `/fractal:delivery` → `/fractal:review` → `/fractal:ship`

These four skills form a closed cycle. They are always invoked in sequence.
Each receives the node directory path as argument. Artifacts are saved inside the node dir.

---

## Rules

- **ONE question at a time.** Never stack questions.
- **ALWAYS write to disk before acting.** No transition without persistence.
- **After invoking `/fractal` or any Skill, STOP.** Each invocation handles one step.
- **Push back.** Challenge scope, assumptions, predicate quality.
- **The filesystem is truth.** Always read before acting, always save after.
- **HITL always.** Validate every proposed predicate. Validate every result.
- **Capture every invalidation.** When the human corrects the agent, write to `learnings.md`.
- **Read learnings on SHOW.** Accumulated insights inform future proposals.
- **Subagents use model: sonnet.** Never opus in a subagent.
- **Single tree per repo.** Auto-discovered, no argument needed.
- **ALWAYS persist discovery.md before routing.**
- **PRD is required for leaf nodes before planning.**
