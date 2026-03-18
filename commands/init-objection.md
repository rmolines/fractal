---
description: "Bootstrap (objection mode): extract a challenge/objection, create fractal tree, then hand off to /fractal:run-objection. Use to start a pre-mortem or to stress-test a plan."
argument-hint: "challenge or objection in natural language, or empty to auto-detect"
allowed-tools: AskUserQuestion, Bash, Read, Write, Glob
---

# /fractal:init-objection

## Human gates

Every time this skill needs human input (confirmation, choice, correction), use the `AskUserQuestion` tool instead of printing the question as text output. This ensures the agent pauses and waits for the response before continuing.

**Be a sparring partner, not a form to fill out.** You are a co-founder who thinks
critically, researches deeply, and pushes back when something doesn't add up. Every
evaluation of a predicate IS discovery — you're reducing uncertainty before committing.

Input: $ARGUMENTS — a challenge or objection in natural language, or empty to auto-detect.

---

## Conversational stance

- Before any question, state what you're trying to decide and why.
- One question at a time. Never stack questions.
- Calibrate depth to signal:
  | Signal level | Mode | What you do |
  |---|---|---|
  | Vague ("não sei se vai funcionar") | **Extraction** | Socratic — ask for concrete examples of what could go wrong, one at a time |
  | Formed hypothesis ("acho que X vai falhar por Y") | **Validation** | Propose your interpretation of the blocker, ask for confirmation |
  | Concrete data (scans, metrics, code) | **Synthesis** | Analyze what the data shows about the risk, ask what's missing |

  **Never extract when you can synthesize.**

- **Push back when something doesn't add up.** If the objection is too vague to be falsifiable, say so. If the doubt has a trivial resolution, name it.

- The guiding question is: **"what do you doubt I can do?"** — not "what do you want?". The root node IS the challenge itself — framed as an objection ("you can't do X", "this won't work because Y"). Nodes in the objection tree stay as challenges. The evaluate-objection agent decomposes by asking "why would this challenge be true?" and children are also challenges. Satisfaction means refuting the challenge.

---

## Step 1: Detect context

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

Check `.fractal/` existence. Count trees (dirs with `root.md` inside `.fractal/`).

If `.fractal/learnings.md` exists, read it to calibrate predicate proposals.

## Step 2: Route

- **No `.fractal/` dir OR no trees inside + no $ARGUMENTS** → ask the user what they doubt or challenge. Then go to Phase 0.
- **No `.fractal/` dir OR no trees inside + $ARGUMENTS** → use $ARGUMENTS as the challenge/objection. Go to Phase 0.
- **`.fractal/` has exactly 1 tree + no $ARGUMENTS** → show tree status (run `fractal-state.sh`), ask:
  "Árvore existente: '<root_predicate>'. Quer continuar ou redefinir o desafio?"
  - Continue → invoke `/fractal:run-objection`. STOP.
  - Redefine → go to Phase 0 (mutation path).
- **`.fractal/` has exactly 1 tree + $ARGUMENTS** → treat as new/redefined challenge. Go to Phase 0 (mutation path).
- **Multiple trees + no $ARGUMENTS** → list existing trees, ask:
  "Árvores existentes: <list>. Quer continuar em uma delas ou criar nova?"
  - Continue → ask which tree, then invoke `/fractal:run-objection <tree-name>`. STOP.
  - New → go to Phase 0 (new tree will coexist with existing ones).
- **Multiple trees + $ARGUMENTS** → treat as new tree objective. Go to Phase 0.

## Step 3: Phase 0 — Extract the objection

Read `references/phase0-objection.md` for the full extraction protocol. Summary:

1. **Pre-mortem** — assume the project failed; what killed it?
2. **Inversion** — what would have to be true for this to definitely not work?
3. **Blocker identification** — which blockers are strategic, technical, UX, business, distribution, or integration?
4. **Investigation cycles** (if needed): research, spike, interview, analysis

Calibrate depth:
- New doubt with no prior evidence → deep extraction
- Existing repo with a named risk → light extraction
- Trivial concern → skip Phase 0, go straight to tree creation

The goal: a single challenge in the useful abstraction window — a doubt specific enough to decompose, broad enough to survive implementation changes.

**CRITICAL — objection framing:** The root node MUST be an objection/challenge/doubt — a negative claim about what can't be done or won't work. NEVER invert it into a positive predicate.

| ✅ Correct (agent-centric challenge) | ❌ Wrong (world-state fact) | ❌ Wrong (positive predicate) |
|---|---|---|
| "O agente não consegue criar uma UX que me surpreenda" | "A UX atual não surpreende" | "A UX surpreende o usuário" |
| "O agente não consegue fazer isso escalar pra 1000 usuários" | "Isso não escala pra 1000 usuários" | "O sistema escala para 1000 usuários" |
| "O agente não consegue entregar isso em 2 semanas" | "Não dá pra entregar em 2 semanas" | "A entrega acontece em 2 semanas" |

If you catch yourself writing a positive statement or a world-state fact, reframe as an agent capability doubt. The tree decomposes by asking "why would this challenge be true?" — positive predicates and world-state facts break this logic.

## Step 4: Tree creation

After the challenge/objection is confirmed by human:

1. Derive tree slug from the objection (kebab-case, max 30 chars)
2. Create the tree:

```bash
SLUG="<derived-slug>"
mkdir -p ".fractal/$SLUG"
```

3. Write `root.md`:

```markdown
---
predicate: "<MUST be an objection/challenge — e.g. 'o agente não consegue fazer X', 'isso não vai funcionar porque Y'. NEVER a positive predicate.>"
status: pending
active_node: .
mode: objection
created: <YYYY-MM-DD>
---

# Root history

Previous roots are recorded here when the objective mutates.
```

**Note:** Root nodes are always branch nodes — they are satisfied by the composition of
their children, not by a sprint. No `discovery.md` is written at init time. The first
`/fractal:run-objection` invocation will trigger discovery on the root or its first child.

4. Confirm to user: "Arvore criada em .fractal/<slug>/."

4b. Inject fractal tree context into CLAUDE.md:

Check if the repo has a CLAUDE.md (at root or `.claude/CLAUDE.md`). If neither exists, create `CLAUDE.md` at root.

Check if the file already contains `## Fractal tree` (idempotent guard). If it does, skip.

If not present, append the following section to the CLAUDE.md:

```markdown

## Fractal tree

This repo uses a fractal predicate tree in `.fractal/` for project management.
Run `bash scripts/fractal-tree.sh` to see current state.
For project context, read `conclusion.md` files from satisfied nodes.
See `references/context-protocol.md` in the fractal plugin for the full navigation protocol.
```

4c. Create `.claude/rules/fractal-nav.md` in the target repo (idempotent — skip if file already exists):

```bash
if [ ! -f ".claude/rules/fractal-nav.md" ]; then
  mkdir -p ".claude/rules"
  # write fractal-nav.md
fi
```

Content to write:

```markdown
---
paths:
  - ".fractal/**"
---
# Fractal tree navigation

When reading files in .fractal/:
- conclusion.md contains what was achieved (oriented toward parent predicate)
- discovery.md contains the evaluator's last response (ephemeral — deleted on re-evaluation)
- predicate.md contains the verifiable condition and status
- Read conclusions of satisfied siblings before proposing new children for a branch
```

This is a path-scoped rule — it loads only when the agent touches `.fractal/` files. Zero cost for sessions that don't interact with the tree.

5. Check for standards.md:

If no `.claude/standards.md` exists in the repo, use `AskUserQuestion` to offer:
- Question: "Repo sem standards.md. Gerar draft automático?"
- Options: "Sim, gerar" / "Pular"
- If "Sim, gerar" → invoke `/standards:generate`. Continue after it completes.
- If "Pular" → continue

6. Invoke `/fractal:run-objection`. STOP.

## Step 5: Mutation path (existing tree)

When redefining an existing tree's challenge:

1. Read current `root.md`
2. Append current root predicate to `# Root history` section with date
3. Update `predicate` field with new challenge expressed as falsifiable condition
4. Reset `active_node` to `.`
5. Capture learning in `.fractal/learnings.md`:
   ```
   ## <date> — <tree-name>/root
   Proposed: <old predicate>
   Human preferred: <new predicate>
   Insight: desafio redefinido — escopo original era <reason>
   ```
6. Confirm to user: "Desafio redefinido."
7. Invoke `/fractal:run-objection`. STOP.

---

## Rules

- One question at a time. Never stack.
- Push back on vague or unfalsifiable objections.
- Phase 0 depth calibrated to context.
- Multiple trees allowed. Each tree is independent under `.fractal/`.
- After tree creation or continue → always end with `/fractal:run-objection`. STOP.
- Subagents use model: sonnet. Never opus.
