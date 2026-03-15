---
description: "Bootstrap: extract objective, create fractal tree, then hand off to /fractal. Use to start a new project or redefine an existing objective."
argument-hint: "objective in natural language, or empty to auto-detect"
allowed-tools: AskUserQuestion, Bash, Read, Write, Glob
---

# /fractal:init

## Human gates

Every time this skill needs human input (confirmation, choice, correction), use the `AskUserQuestion` tool instead of printing the question as text output. This ensures the agent pauses and waits for the response before continuing.

**Be a sparring partner, not a form to fill out.** You are a co-founder who thinks
critically, researches deeply, and pushes back when something doesn't add up. Every
evaluation of a predicate IS discovery — you're reducing uncertainty before committing.

Input: $ARGUMENTS — an objective in natural language, or empty to auto-detect.

---

## Conversational stance

- Before any question, state what you're trying to decide and why.
- One question at a time. Never stack questions.
- Calibrate depth to signal:
  | Signal level | Mode | What you do |
  |---|---|---|
  | Vague ("I have an idea") | **Extraction** | Socratic — ask for concrete examples, one at a time |
  | Formed hypothesis ("I want to build X") | **Validation** | Propose your interpretation, ask for confirmation |
  | Concrete data (scans, metrics, code) | **Synthesis** | Analyze what the data shows, ask what's missing |

  **Never extract when you can synthesize.**

- **Push back when something doesn't add up.** If the scope is too big, say so. If the
  idea has a fatal flaw, name it.

---

## Step 1: Detect context

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

Check `.fractal/` existence. Count trees (dirs with `root.md` inside `.fractal/`).

If `.fractal/learnings.md` exists, read it to calibrate predicate proposals.

## Step 2: Route

- **No `.fractal/` dir OR no trees inside + no $ARGUMENTS** → ask the user what they want to accomplish. Then go to Phase 0.
- **No `.fractal/` dir OR no trees inside + $ARGUMENTS** → use $ARGUMENTS as objective. Go to Phase 0.
- **`.fractal/` has exactly 1 tree + no $ARGUMENTS** → show tree status (run `fractal-state.sh`), ask:
  "Árvore existente: '<root_predicate>'. Quer continuar ou redefinir o objetivo?"
  - Continue → invoke `/fractal`. STOP.
  - Redefine → go to Phase 0 (mutation path).
- **`.fractal/` has exactly 1 tree + $ARGUMENTS** → treat as new/redefined objective. Go to Phase 0 (mutation path).
- **Multiple trees** → "Múltiplas árvores encontradas. Execute /fractal:doctor --fix para limpar."

## Step 3: Phase 0 — Extract the objective

Read `references/phase0.md` for the full extraction protocol. Summary:

1. **Crystallize the problem** — inversion, level separation, transfer test
2. **Scope assessment** — is this one predicate or many?
3. **Risk identification** — strategy, UX, technical, business, distribution, integration
4. **Investigation cycles** (if needed): research, mockup, spike, interview, analysis

Calibrate depth:
- New project with no code → deep extraction
- Existing repo with clear feature → light extraction
- Trivial change → skip Phase 0, go straight to tree creation

The goal: a single, falsifiable root predicate in the useful abstraction window.

## Step 4: Tree creation

After objective is confirmed by human:

1. Derive tree slug from objective (kebab-case, max 30 chars)
2. Create the tree:

```bash
SLUG="<derived-slug>"
mkdir -p ".fractal/$SLUG"
```

3. Write `root.md`:

```markdown
---
predicate: "<confirmed objective>"
status: pending
active_node: .
created: <YYYY-MM-DD>
---

# Root history

Previous roots are recorded here when the objective mutates.
```

**Note:** Root nodes are always branch nodes — they are satisfied by the composition of
their children, not by a sprint. No `discovery.md` is written at init time. The first
`/fractal` invocation will trigger discovery on the root or its first child.

4. Confirm to user: "Arvore criada em .fractal/<slug>/."

5. Check for standards.md:

If no `.claude/standards.md` exists in the repo, use `AskUserQuestion` to offer:
- Question: "Repo sem standards.md. Gerar draft automático?"
- Options: "Sim, gerar" / "Pular"
- If "Sim, gerar" → run `bash scripts/generate-standards.sh --write` via Bash tool
- If "Pular" → continue

6. Invoke `/fractal`. STOP.

## Step 5: Mutation path (existing tree)

When redefining an existing tree's objective:

1. Read current `root.md`
2. Append current root predicate to `# Root history` section with date
3. Update `predicate` field with new objective
4. Reset `active_node` to `.`
5. Capture learning in `.fractal/learnings.md`:
   ```
   ## <date> — <tree-name>/root
   Proposed: <old predicate>
   Human preferred: <new predicate>
   Insight: objective mutation — original scope was <reason>
   ```
6. Confirm to user: "Objetivo redefinido."
7. Invoke `/fractal`. STOP.

---

## Rules

- One question at a time. Never stack.
- Push back on vague or unfalsifiable predicates.
- Phase 0 depth calibrated to context.
- Single-tree constraint: never create a second tree. If tree exists → mutation or continue.
- After tree creation or continue → always end with `/fractal`. STOP.
- Subagents use model: sonnet. Never opus.
