---
description: "Idempotent fractal state machine. Evaluates the active predicate and advances one step. Call repeatedly to converge on the root predicate."
argument-hint: "(none needed — auto-discovers single tree)"
allowed-tools: Skill(fractal *), Agent, Bash, Read, Write, Edit, Glob, AskUserQuestion
---

# /fractal:run

## Human gates

Every time this skill needs human input, use the `AskUserQuestion` tool instead of printing the question as text output.

Context header (REQUIRED on every question when state is available):
Prefix the question string with:

📍 <breadcrumb> | <state>
🎯 <active_predicate (max 80 chars)>

<actual question>

Variables come from the pre-loaded State section. If state is not yet loaded (e.g., early steps of /fractal:propose before tree detection), omit the header.

IMPORTANT: The header must be plain text. No markdown formatting (no **, ##, *, etc.) in the question string. Emojis are fine as visual anchors.

### Formatting rules for AskUserQuestion

- **Question leads.** The actual question comes immediately after the header — not buried at the end. Context after, not before.
- **header field** must be a short action-oriented label: "Foco", "Execucao", "Validacao", "Decomposicao", "Poda" — not a description of what the question is about.
- **Children status** (when relevant): use a compact inline format with visual indicators:
  `child-name ✅ | child-name ⏳ pending`
  Never describe children status in prose.
- **No redundancy.** State each fact once. Don't explain the same status twice.
- **Density.** Max 4 lines between header and question. Compress context, don't narrate it.
- **Concrete options.** Avoid open-ended "o que fazer?" — provide labeled choices (e.g., "Confirma? (sim/nao)", numbered candidates, yes/no).

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

## Tree (pre-loaded)

!`cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1); [ -n "$FRACTAL_SCRIPTS" ] && bash "$FRACTAL_SCRIPTS/fractal-tree.sh" 2>/dev/null || echo "tree: error"`

## Lock (pre-loaded)

!`cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1); ACTIVE=$([ -n "$FRACTAL_SCRIPTS" ] && bash "$FRACTAL_SCRIPTS/fractal-state.sh" 2>/dev/null | grep "^active_node:" | sed 's/^active_node: //'); [ -n "$FRACTAL_SCRIPTS" ] && [ -n "$ACTIVE" ] && [ "$ACTIVE" != "." ] && bash "$FRACTAL_SCRIPTS/session-lock.sh" check "$ACTIVE" 2>/dev/null || echo "locked: n/a"`

## Scripts path (for runtime mutations)

!`ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1`

In all runtime bash calls below, `<scripts_path>` refers to this pre-loaded value. Use it directly — never re-resolve with `ls -d`.

---

## Statechart — the canonical spec

```
GUARD → [error/no-tree: STOP | root satisfied: STOP | else: SHOW]
SHOW → EVALUATE
EVALUATE → collect existing_children → spawn evaluator → write discovery.md → ROUTE
ROUTE:
  → unachievable: PRUNE → ASCEND
  → leaf: SPECIFY → EXECUTE
  → new_child: CREATE_CHILD → set active → self-invoke → STOP
  → complete + has pending children: select next pending → self-invoke → STOP
  → complete + all satisfied: VALIDATE → mark satisfied → ASCEND
PRUNE → persist status:pruned → ASCEND
ASCEND → delete parent's discovery.md → set active=parent → self-invoke → STOP
         [depth=0: COMPLETE → STOP]
```

Every transition persists to disk BEFORE acting. This guarantees idempotency:
calling `/fractal:run` again from the same state produces the same behavior.

---

## Dry run mode

Check environment variable at the start of every invocation:

```bash
echo "${FRACTAL_DRY_RUN:-0}"
```

When `FRACTAL_DRY_RUN=1`, the state machine runs identically but with these overrides:

1. **No human gates.** Every `AskUserQuestion` is replaced by auto-accepting the agent's recommendation. Print the decision instead (e.g., "🏃 DRY RUN — auto-aprovando: <choice>").
2. **No locks.** Skip all `session-lock.sh` calls (create, remove, check). Treat ownership as always confirmed.
3. **No execution.** When ROUTE reaches `leaf`, leave the node as `pending` (do NOT execute patch/sprint). Go directly to ASCEND.
4. **Conversational stance is off.** No push-back, no challenges — just evaluate and recurse.

The recursion is the same: each transition ends with `invoke /fractal:run → STOP`. The tree builds itself through the normal recursive invocation chain.

**Purpose:** validate the fractal decomposition for any problem by building the full tree without executing anything. Analyze the resulting tree structure in `.fractal/`.

---

## Steps — execute in order, do not skip, do not invent steps

### 1. GUARD

Read pre-loaded state, tree, and lock status. All are already in the prompt — no bash calls needed.

**Print the pre-loaded tree output** immediately (unless state is error) — this gives the human instant spatial awareness of where we are before any decision is made.

Then route:

- `state: error` → STOP. Print "Nenhuma arvore encontrada. Execute /fractal:init."
- `active_status: satisfied` AND `depth: 0` → Print "Predicado raiz satisfeito." STOP.
- `active_node: "."` AND `root_status` is NOT `satisfied` AND NOT `pruned`:
  - If `children_total > 0` AND `has_discovery: false` → **Root re-evaluation.** The root has children and its discovery.md was deleted by ASCEND. Treat root as the active node and go directly to step 2 (SHOW). No session traversal needed.
  - Otherwise → **Session traversal** (see below).
- `active_node` is NOT `"."` → **check ownership first** (see below). This MUST happen before any other routing (including ASCEND for satisfied/pruned nodes).

#### Ownership check (active_node is not ".")

> **DRY RUN:** Skip ownership check entirely. Treat as always owned. Route directly based on `active_status`.

The pre-loaded state's `active_node` is already session-aware: `fractal-state.sh` overrides `root.md` with the session lock for `$PPID` when one exists. So by the time we reach this check, `active_node` already reflects THIS session's node (if a lock exists for us).

Use the **pre-loaded lock status** to verify ownership. No bash call needed for the check.

Parse the pre-loaded Lock output:

- `locked: true` AND `pid` = `$PPID` → this session owns it. Continue routing below.
- `locked: false` → no lock exists for this node. Claim it: `bash "<scripts_path>/session-lock.sh" create <active_node>` (use the pre-loaded Scripts path). Continue routing below.
- `locked: true` AND `pid` ≠ `$PPID` → this session does NOT own the node that root.md points to, and we have no session lock of our own. **Treat as session traversal** (go to "Session traversal" below).
- `locked: n/a` → active_node is "." or no tree. Handled by other routes.

NOTE: Because `fractal-state.sh` already overrides `active_node` from our session lock, the case where root.md points to another session's node but we have our own lock is handled automatically — the pre-loaded state will already show OUR node, not theirs.

After ownership is confirmed, route:

- `active_status: satisfied` OR `active_status: pruned` → go to step 5 (ASCEND).
- Otherwise → go to step 2 (SHOW).

#### Session traversal (active_node is ".")

This happens at the start of a fresh session. Find the best pending node and confirm with the human before focusing.

```bash
bash "<scripts_path>/select-next-node.sh"
```

(Use the pre-loaded Scripts path value.)

Parse the output:

- `selected_node: none` → Print "Nenhum nó pending encontrado." STOP.
- Otherwise → extract `selected_node` and `selected_predicate`.

> **DRY RUN:** Skip `AskUserQuestion`. Print "🏃 DRY RUN — focando em: <selected_predicate>". Skip session lock. Write `active_node` to `root.md` (dry run has no locks, so root.md is the only pointer). Invoke `/fractal:run`. STOP.

Use `AskUserQuestion` (header: "Foco"):

```
📍 <breadcrumb> | <state>
🎯 <active_predicate>

Focar em: "<selected_predicate>" (<selected_node>)?

Confirma? (sim / escolher outro)
```

- **Confirmed** → create session lock for the selected node: `bash "<scripts_path>/session-lock.sh" create <selected_node>`. Do NOT update `active_node` in `root.md` — the session lock is the source of truth. `fractal-state.sh` will derive the correct `active_node` on next invocation. Invoke `/fractal:run`. STOP.
- **Rejected** → show the tree (run `fractal-tree.sh`) and ask the human which node they prefer. Create session lock: `bash "<scripts_path>/session-lock.sh" create <chosen_node>`. Do NOT update `active_node` in `root.md`. Invoke `/fractal:run`. STOP.

Note: `select-next-node.sh` automatically ignores stale locks (dead PIDs). No manual cleanup needed.

### 2. SHOW

The tree is already pre-loaded — no bash call needed. Print:

```
📍 <breadcrumb> | <state>
🎯 <active_predicate>
Filhos: <child-name> ✅ | <child-name> ⏳ pending
```

(Omit the Filhos line if there are no children. Replace each entry with the actual child slug and its status icon: ✅ satisfied, 🔴 pruned, ⏳ pending.)

If notes exist in active_node's predicate.md → read them (context from prior session).
If `.fractal/learnings.md` exists → read it (calibrate proposals).

→ go to step 3 (EVALUATE).

### 3. EVALUATE

**Collect existing children** of the active node:

For each child directory with `predicate.md`:
- Read `status` from predicate.md
- Read `response` from `discovery.md` (if exists) — this tells us if the child was evaluated
- If `status: satisfied` and `conclusion.md` exists → read the conclusion summary

Format as:
```
existing_children:
- "<child predicate>" | status: <status> | evaluated: <response from discovery.md or "none">
- "<child predicate>" | status: satisfied | evaluated: leaf | conclusion: "<What was achieved summary>"
```

If no children exist, `existing_children` is empty.

**Spawn evaluator subagent:**

```
Agent(
  description: "evaluate: <predicate slug>",
  subagent_type: "fractal:evaluate",
  model: "sonnet",
  prompt: "predicate: <active_predicate>\ntree_path: <tree_path>\nrepo_root: <git root>\nexisting_children:\n<formatted list>"
)
```

Wait for response. Parse: `response`, `confidence`, `reasoning`, `child_predicate`, `child_type`, `prd_seed`, `leaf_type`.

**Persist discovery.md** with the evaluator's response BEFORE routing.

→ go to step 4 (ROUTE).

### 4. ROUTE

Based on the evaluator's `response` field:

> **DRY RUN:** Skip all human presentation below. Auto-route directly. Print "🏃 DRY RUN — <response>: <reasoning summary (1 line)>".

#### 4a. ROUTE: unachievable → PRUNE

Present to human (header: "Poda"):
"📍 <breadcrumb> | <state>\n🎯 <active_predicate>\n\nO predicado parece inatingivel: <reasoning>. Podar este no?"
→ Confirmed → set `status: pruned` in active node's `predicate.md`. → go to step 5 (ASCEND).
→ Denied → re-evaluate with human's additional context.

#### 4b. ROUTE: leaf → SPECIFY → EXECUTE

Present to human (header: "Execucao"):
"📍 <breadcrumb> | <state>\n🎯 <active_predicate>\n\nPredicado diretamente satisfazivel. <leaf_type>: '<prd_seed>'. <reasoning>. Aceita?"
→ Confirmed → proceed to execution below.
→ Rejected → ask what human prefers.

> **DRY RUN:** Leave node as `pending`. Do NOT execute. Print "🏃 DRY RUN — leaf mapeada: <predicate>". → go to step 5 (ASCEND).

**SPECIFY:** If no `prd.md` exists, write it:
- For `leaf_type: action` → write prd.md with evidence criteria (what human should bring back).
- For `leaf_type: patch | cycle` → write prd.md with acceptance criteria, out-of-scope, constraints.
- Human validates prd.md before execution.

**EXECUTE:**

Write `execution.md` in the active node dir:

```markdown
---
mode: patch | sprint | action
sub_predicate: "<predicate>"
reasoning: "<evaluator reasoning>"
created: <YYYY-MM-DD>
---
```

Then:
- **action** → present what the human needs to do. STOP. Human reports evidence on next `/fractal:run`.
- **patch** → invoke `/fractal:patch <predicate text>`. STOP.
- **sprint** → spawn the sprint agent to run the full cycle (planning → delivery → review → ship) without human gates:

```
Agent(
  description: "sprint: <predicate slug>",
  subagent_type: "fractal:sprint",
  model: "sonnet",
  prompt: "node_dir: <node_dir_path>\nrepo_root: <git root>"
)
```

Wait for the sprint agent to complete. Parse its result: `status`, `summary`, `conclusion`.

- If `status: success` → the sprint completed and shipped. Present to human (header: "Validacao"):
  "📍 <breadcrumb> | <state>\n🎯 <active_predicate>\n\nSprint concluída e shipped. <summary>.\n\nO predicado foi satisfeito? (sim / nao)"
  - **Yes** → write `status: satisfied` in `predicate.md`. → go to step 5 (ASCEND).
  - **No** → capture learning in `.fractal/learnings.md`. Invoke `/fractal:run`. STOP.
- If `status: review_rejected` → the review rejected twice. Present the rejection reasons to the human and ask for guidance.
- If `status: failed` → report the error. STOP.

After action leaf execution completes (next `/fractal:run` invocation):
- Check if human reported evidence.
- Use `AskUserQuestion` (header: "Validacao"): "O predicado foi satisfeito?"
- **Yes** → write `status: satisfied` in `predicate.md`. Write `conclusion.md`. → go to step 5 (ASCEND).
- **No** → capture learning in `.fractal/learnings.md`. Invoke `/fractal:run`. STOP.

#### 4c. ROUTE: new_child → CREATE CHILD

Present to human (header: "Decomposicao"):
```
📍 <breadcrumb> | <state>
🎯 <active_predicate>

Novo sub-predicado proposto: "<child_predicate>" [<child_type>]
Razao: <reasoning summary>

Aceita? (sim / nao — descreva alternativa)
```

→ Confirmed → proceed to creation.
→ Rejected → ask human for alternative. Capture learning in `learnings.md`.

**Create child:**
1. Generate slug from `child_predicate` (kebab-case, max 30 chars).
2. `mkdir -p <tree_path>/<active_node_rel>/<slug>`
3. Write `<slug>/predicate.md`:
   ```markdown
   ---
   predicate: "<child_predicate>"
   status: pending
   created: <YYYY-MM-DD>
   ---
   ```
4. Move session lock to the new child: `bash "<scripts_path>/session-lock.sh" remove <active_node>` then `bash "<scripts_path>/session-lock.sh" create <active_node_rel>/<slug>`. Do NOT write `active_node` to `root.md` — the session lock is the source of truth. `fractal-state.sh` will derive the correct `active_node` on next invocation.
5. Invoke `/fractal:run`. STOP.

#### 4d. ROUTE: complete

The evaluator says no more children are needed.

**If the node has pending children:**
Select the next pending child (iterate child dirs, pick first with `status: pending`).
Move session lock to the pending child: `bash "<scripts_path>/session-lock.sh" remove <active_node>` then `bash "<scripts_path>/session-lock.sh" create <pending_child_rel_path>`. Do NOT write `active_node` to `root.md` — the session lock is the source of truth.
Invoke `/fractal:run`. STOP.

> **DRY RUN with pending children:** → go to step 5 (ASCEND). The pending children were already mapped by previous recursions; the parent is fully decomposed.

**If all children are satisfied (or satisfied + pruned with at least 1 satisfied):**
Read conclusions from satisfied children. Present to human (header: "Validacao"):
```
📍 <breadcrumb> | <state>
🎯 <active_predicate>

Todos os filhos resolvidos. O predicado pai foi satisfeito?
<child-name> ✅: <conclusion summary>
<child-name> ✅: <conclusion summary>

(sim / nao — descreva o que falta)
```

- **Yes** → write `status: satisfied` in `predicate.md`. Write `conclusion.md` (synthesized from children, `satisfied_by: synthesis`). → go to step 5 (ASCEND).
- **No** → capture learning in `learnings.md`. Delete `discovery.md` (force re-evaluation to propose new child). Invoke `/fractal:run`. STOP.

**If all children are pruned:**
The predicate may be unachievable. Present to human: "Todos os filhos podados. Podar o pai também?"
- Yes → set `status: pruned`. → ASCEND.
- No → delete `discovery.md`. Invoke `/fractal:run`. STOP. (Evaluator will propose new approach.)

**If node has no children (complete without children):**
This is equivalent to `response: leaf` — the evaluator is saying the predicate is satisfiable as-is. Treat as 4b (leaf). This should be rare; if it happens, log it as unusual.

### 5. ASCEND

Active node is satisfied, pruned, or fully mapped (dry run).

> **DRY RUN:** Skip all lock operations. Skip human questions. Auto-proceed.

**5a.** If `depth: 0` (root node):
- If `active_status: satisfied` → "Predicado raiz satisfeito. Arvore completa." STOP.
- If `active_status: pruned` → "Predicado raiz podado. Execute /fractal:init para redefinir." STOP.
- Dry run: "🏃 DRY RUN — arvore completa." STOP.

**5b.** Move session lock from current node to parent: `bash "<scripts_path>/session-lock.sh" remove <active_node>` then `bash "<scripts_path>/session-lock.sh" create <parent_path>`. This ensures `fractal-state.sh` resolves the correct `active_node` for this session on the next `/fractal:run` invocation. (Skip the parent lock creation when ascending to root — parent_path is `"."` and root has no lock.)

**5c.** Compute parent path (strip last path segment from `active_node`).
If `active_node` has no `/` (depth 1), parent is `"."`.

**5d.** Delete the **parent's** `discovery.md` (if it exists):
```bash
rm -f "<tree_path>/<parent_rel>/discovery.md"
```
This forces re-evaluation of the parent on the next `/fractal:run` invocation. The evaluator will see the newly satisfied/pruned child and decide: propose another child, or declare complete.

**NOTE:** Only delete the PARENT's discovery.md. The current node's discovery.md is preserved — it contains `leaf_type`, `reasoning`, and other data that remains useful.

**5e.** Do NOT update `active_node` in `root.md`. The session lock (moved to the parent in 5b) is the source of truth. `fractal-state.sh` will derive the correct `active_node` from the session lock on next invocation.

Exception: when ascending to root (`parent_path = "."`), no parent lock is created (5b skips it). The session is ending — `fractal-state.sh` will find no lock for this PPID and fall back to root.md's `active_node`, which remains at whatever value the last session traversal set (or `"."`). This is correct: the next `/fractal:run` will trigger a fresh session traversal.

**`root.md`'s `active_node` is now a legacy fallback** — only meaningful for dry run mode (which has no locks). Normal sessions rely exclusively on session locks as the per-session pointer.

Print: "Nó [satisfied|pruned]. Subindo para o pai."
Invoke `/fractal:run`. STOP.

---

## Objective mutation

If the user decides the root objective has changed mid-execution:

1. Record current root predicate in `root.md` `# Root history` section with date
2. Update `predicate` field with new objective
3. Reset `active_node` to `.`
4. Capture learning in `.fractal/learnings.md`
5. Invoke `/fractal:run`. STOP.

---

## Sprint cycle reference

When EXECUTE chooses patch mode, invoke `/fractal:patch`. When EXECUTE chooses sprint mode, the sprint agent (`agents/sprint.md`) runs the full cycle:
`/fractal:planning` → `/fractal:delivery` → `/fractal:review` → `/fractal:ship`

The sprint agent runs as a single subagent (Sonnet) with no human gates. The review is the internal quality gate — if it rejects, the sprint agent loops back (max 2 retries). Ship runs automatically on approval. The human validates the predicate after the sprint completes.

---

## Rules

- **ONE question at a time.** Never stack questions.
- **ALWAYS write to disk before acting.** No transition without persistence.
- **After invoking `/fractal:run` or any Skill, STOP.** Each invocation handles one step.
- **Push back.** Challenge scope, assumptions, predicate quality. (Suspended in dry run mode.)
- **The filesystem is truth.** Always read before acting, always save after.
- **HITL always.** Validate every proposed predicate. Validate every result. (Suspended in dry run mode.)
- **Capture every invalidation.** When the human corrects the agent, write to `learnings.md`.
- **Read learnings on SHOW.** Accumulated insights inform future proposals.
- **Subagents use model: sonnet.** Never opus in a subagent.
- **Single tree per repo.** Auto-discovered, no argument needed.
- **ALWAYS persist discovery.md before routing.**
- **PRD is required for leaf nodes before execution.**
- **ASCEND always goes to the parent.** Never use select-next-node in ASCEND. The parent is re-evaluated.
- **Delete parent's discovery.md on ASCEND.** Forces re-evaluation with fresh context.
