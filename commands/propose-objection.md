---
description: "Propose a new challenge/objection and place it in the fractal tree. With no arguments, enters analyze mode: evaluates the active predicate and suggests a sub-objection. With text, reframes and places it manually."
argument-hint: "challenge or objection text in natural language, or empty to analyze the active predicate"
allowed-tools: AskUserQuestion, Agent, Bash, Read, Write, Edit, Glob
---

# /fractal:propose-objection

## Human gates

Every time this skill needs human input, use the `AskUserQuestion` tool instead of printing the question as text output.

Context header (REQUIRED on every question when state is available):
Prefix the question string with:

📍 <breadcrumb> | <state>
🎯 <active_predicate (max 80 chars)>

<actual question>

Variables come from the pre-loaded State section. If state is not yet loaded (e.g., early steps before tree detection), omit the header.

IMPORTANT: The header must be plain text. No markdown formatting (no **, ##, *, etc.) in the question string. Emojis are fine as visual anchors.

Input: $ARGUMENTS — challenge/objection text in natural language, or empty to enter analyze mode.

---

## Step 1: Route on arguments

### If `$ARGUMENTS` IS provided

Use it directly as the challenge text. Skip to Step 2 (Reframe).

---

### If `$ARGUMENTS` is empty — ANALYZE MODE

Enter analyze mode. This evaluates the active predicate and proposes the next sub-objection (i.e., the reason why the challenge still holds).

#### Step A: Detect tree

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
FRACTAL_DIR="$REPO_ROOT/.fractal"
TREES=()
for d in "$FRACTAL_DIR"/*/; do [ -f "${d}root.md" ] && TREES+=("$d"); done
if [ "${#TREES[@]}" -eq 1 ]; then
  TREE_DIR="${TREES[0]}"
elif [ "${#TREES[@]}" -gt 1 ]; then
  echo "multiple_trees: true"
  for t in "${TREES[@]}"; do echo "tree: $(basename "$t")"; done
fi
```

If no tree found: STOP with message "Nenhuma árvore fractal encontrada. Execute /fractal:init-objection primeiro."

If multiple trees found: ask the user which tree to work with via AskUserQuestion.

```bash
ROOT_MD="${TREE_DIR}root.md"
ACTIVE_NODE=$(grep "^active_node:" "$ROOT_MD" | sed 's/^active_node:[[:space:]]*//' | tr -d '"')
FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1)
[ -z "$FRACTAL_SCRIPTS" ] && FRACTAL_SCRIPTS="$REPO_ROOT/scripts"
bash "$FRACTAL_SCRIPTS/fractal-state.sh"
```

#### Step B: Determine target node

- If `active_node` is `"."` or empty → target is the root predicate (read from `${TREE_DIR}root.md`, `predicate:` field)
- Otherwise → target is the active predicate (read from `${TREE_DIR}${ACTIVE_NODE}/predicate.md`, `predicate:` field)

Set:
- `TARGET_PREDICATE` — the predicate text
- `TARGET_DIR` — full path to the target node directory (use `$TREE_DIR` if root, or `${TREE_DIR%/}/$ACTIVE_NODE` otherwise)
- `TARGET_PATH` — relative path within tree (`"."` if root, `$ACTIVE_NODE` otherwise)

#### Step C: Show current tree

```bash
bash "$FRACTAL_SCRIPTS/fractal-tree.sh"
```

Print the tree output to give the human spatial awareness before any question.

#### Step D: Spawn evaluate-objection agent

Collect existing children of the target node (same format as /fractal:run step 3):

```bash
EXISTING_CHILDREN=$(ls -d "$TARGET_DIR"/*/  2>/dev/null | while read d; do
  [ -f "${d}predicate.md" ] && grep "^predicate:" "${d}predicate.md" | sed 's/^predicate:[[:space:]]*//'
done | head -10)
```

```
Agent(
  description: "evaluate-objection: <slug of TARGET_PREDICATE>",
  subagent_type: "fractal:evaluate-objection",
  prompt: "predicate: <TARGET_PREDICATE>\ntree_path: <TARGET_DIR>\nrepo_root: <REPO_ROOT>\nexisting_children:\n<EXISTING_CHILDREN>"
)
```

Do NOT pass a model override — let the agent definition's `model: opus` take effect.

Wait for response. Parse: `response`, `confidence`, `reasoning`, `child_predicate`, `child_type`, `prd_seed`, `leaf_type`.

#### Step E: Route on response type

**If `response: unachievable`:**
Tell the user: "O desafio parece inatingível: <reasoning>. Considere usar /fractal:run-objection para podá-lo." STOP.

**If `response: leaf`:**
Tell the user via plain output (no question needed):
"O desafio '<TARGET_PREDICATE>' já é atômico (leaf): <prd_seed>. Use /fractal:run-objection para executá-lo ou /fractal:patch para uma mudança rápida." STOP.

**If `response: complete`:**
Tell the user: "O desafio já está completamente decomposto. Nenhuma nova sub-objeção necessária." STOP.

**If `response: new_child`:**
Proceed to Step F.

#### Step F: Present proposed child

Use `AskUserQuestion` (header: "Subdivisao"):

Format:
```
📍 <breadcrumb> | PROPOSE-OBJECTION
🎯 <TARGET_PREDICATE (max 80 chars)>

Nova sub-objeção proposta: "<child_predicate>" [<child_type>]
Razao: <reasoning>

Criar? (sim / nao — descreva alternativa)
```

Options:
- "Sim, criar"
- "Nao, quero propor outro"

#### Step G: Act on response

**"Sim, criar":** go to Step H with the single proposed child.

**"Nao, quero propor outro":** fall back to the manual flow — ask for challenge text via `AskUserQuestion`:
> "Qual desafio testável você quer propor?"
Wait for response. Use that text as challenge text. Proceed to Step 2 (Reframe) with TREE_DIR and ACTIVE_NODE already known; skip Step 3.

#### Step H: Create the child node

1. **Generate slug** (same rules as Step 6 below):
   - Lowercase, replace spaces/special chars with hyphens, remove non-alphanumeric/hyphen chars
   - Collapse multiple hyphens, strip leading/trailing, truncate to 30 chars at hyphen boundary
   - Check uniqueness within TARGET_DIR; append `-2`, `-3` if collision

2. **Create directory and write predicate.md:**

```bash
NODE_DIR="$TARGET_DIR/$SLUG"
mkdir -p "$NODE_DIR"
```

Write `predicate.md`:

```markdown
---
predicate: "<child_predicate>"
status: pending
created: <YYYY-MM-DD>
proposed_by: evaluate
---
```

Persist to disk before continuing.

#### Step I: Show updated tree and offer focus redirect

```bash
bash "$FRACTAL_SCRIPTS/fractal-tree.sh"
```

Print the tree output.

Use `AskUserQuestion` (header: "Foco"):

```
📍 <breadcrumb> | PROPOSE-OBJECTION
🎯 <TARGET_PREDICATE>

Criada sub-objeção: "<child_predicate>"

Redirecionar o foco para ela?
```

Options:
- "Sim, focar em <slug>"
- "Manter foco atual"

**If the node is selected:**
- Compute `NODE_REL` (path relative to TREE_DIR)
- Update `active_node` in `root.md` to `NODE_REL`
- Print: "Ponteiro atualizado para '<NODE_REL>'. Execute /fractal:run-objection para continuar."

**If "Manter foco atual":**
- Print: "Sub-objeção criada. O foco continua em <ACTIVE_NODE or 'raiz'>."

**STOP. Analyze mode complete.**

---

## Step 2: Reframe challenge

Assess the challenge text and determine whether it already is a well-formed challenge/objection or needs reframing.

**A well-formed challenge** meets all of the following:
- Describes a specific, testable doubt about the agent's capability (not an action or a vague quality)
- Can be confirmed as true or false by a human
- Refers to a single concern

**If the challenge is already well-formed**, skip reframing and proceed directly to Step 3.

**Otherwise**, attempt to reframe it. Apply the appropriate transformation:

**Task framing → challenge:**
Input: "implementar autenticação", "refatorar o módulo X", "adicionar testes"
Transform to a doubt about whether the agent can achieve the outcome.
Example: "implementar auth" → "o agente não consegue implementar auth que funcione em produção"

**Vague/abstract → specific challenge:**
Input: "o sistema é bom", "a UX tá ruim", "o código está limpo"
Identify the most likely intent and translate into a specific, testable doubt.
Example: "a UX tá ruim" → "o agente não consegue melhorar o fluxo de onboarding pra menos de 3 cliques"

**Compound statement → single concern:**
Input: "o login não funciona e o dashboard carrega devagar e os emails não chegam"
Split into individual candidates and ask the human which one to proceed with.
Example output: list each concern as a separate option.

After producing the reframe (or list of candidates for compound input), present it using `AskUserQuestion`:

For single reframes:
> "Reformulei seu input como um desafio testável:\n\n'<reframed challenge>'\n\nEssa formulação captura sua intenção?"

Options:
- "Sim, usar essa formulação"
- "Não, quero ajustar"

For compound splits:
> "Seu input cobre múltiplas preocupações. Com qual desafio você quer prosseguir agora?"

Options: one per identified concern (max 4), each as a reframed challenge candidate.

**If the human approves**: use the reframed challenge as the challenge text and proceed to Step 3.

**If the human rejects** (max 2 rounds):
- Round 1: ask "O que está errado? Me dê mais contexto e vou tentar de novo." via `AskUserQuestion`. Incorporate the feedback and produce a new reframe. Present it for approval again.
- Round 2: if still rejected, ask for the human to provide their own formulation directly via `AskUserQuestion`: "Qual seria a formulação correta para você?" Use that response as the challenge text and proceed to Step 3.

Once the challenge text is confirmed (either original if already well-formed, approved reframe, or human-supplied on round 2), proceed to Step 3.

---

## Step 3: Detect tree

(Skip this step if coming from analyze mode — tree is already detected.)

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
FRACTAL_DIR="$REPO_ROOT/.fractal"
```

Check that `.fractal/` exists and find the tree:

```bash
TREES=()
for d in "$FRACTAL_DIR"/*/; do [ -f "${d}root.md" ] && TREES+=("$d"); done
if [ "${#TREES[@]}" -eq 1 ]; then
  TREE_DIR="${TREES[0]}"
elif [ "${#TREES[@]}" -gt 1 ]; then
  echo "multiple_trees: true"
  for t in "${TREES[@]}"; do echo "tree: $(basename "$t")"; done
fi
```

If no tree found: STOP with message "Nenhuma árvore fractal encontrada. Execute /fractal:init-objection primeiro."

If multiple trees found: ask the user which tree to work with via AskUserQuestion.

Read current `active_node` from root.md:

```bash
ROOT_MD="${TREE_DIR}root.md"
ACTIVE_NODE=$(grep "^active_node:" "$ROOT_MD" | sed 's/^active_node:[[:space:]]*//' | tr -d '"')
```

---

## Step 4: Enumerate insertion positions

Run the insertion points script:

```bash
FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1)
[ -z "$FRACTAL_SCRIPTS" ] && FRACTAL_SCRIPTS="$REPO_ROOT/scripts"
bash "$FRACTAL_SCRIPTS/list-insertion-points.sh"
```

Parse the output. Each block has:
- `path:` — relative path within the tree (`.` for root)
- `predicate:` — the node's predicate text
- `depth:` — depth level
- `children:` — number of children
- `status:` — node status

Filter out nodes with `status: satisfied` or `status: pruned` — never insert into those.

---

## Step 5: Present positions

Select up to 4 positions to present. Priority order:
1. Active node (if `status` is `pending`) — shown first
2. Shallowest pending nodes first
3. Alphabetical by path within same depth

Build `AskUserQuestion` with options from the selected positions:

Format each option as:
- Label: last path segment (or "Raiz" for `.`)
- Description: truncated predicate (first 60 chars) + ` | profundidade: <depth> | filhos: <children>`

Example call:
```
AskUserQuestion(
  question: "📍 <tree> | PROPOSE-OBJECTION\n🎯 <proposed challenge text>\n\nOnde posicionar o desafio '<proposed challenge>'?",
  options: [
    { label: "captura-adhoc", description: "o humano pode propor um desafio avulso... | profundidade: 1 | filhos: 2" },
    { label: "Raiz", description: "desenvolvedores que usam Claude Code... | profundidade: 0 | filhos: 24" },
    { label: "skills-recursivas", description: "a skill /fractal:descend substitui... | profundidade: 1 | filhos: 6" },
    { label: "test-outsider", description: "um dev que nunca viu o fractal... | profundidade: 1 | filhos: 1" }
  ]
)
```

Wait for selection. Map the chosen label back to its full path.

---

## Step 6: Generate slug

From the challenge text, derive a kebab-case slug:
1. Lowercase the text
2. Replace spaces and special characters with hyphens
3. Remove characters that are not alphanumeric or hyphens
4. Collapse multiple consecutive hyphens into one
5. Strip leading/trailing hyphens
6. Truncate to 30 characters, cutting at the last hyphen boundary if possible

Examples:
```
"o agente nao consegue propor desafios avulsos" → "agente-nao-consegue-propor-des"
"o agente nao consegue implementar auth em prod" → "agente-nao-consegue-auth-prod"
"CI nao passa em todos os PRs"                  → "ci-nao-passa-em-todos-os-prs"
```

Check for uniqueness within the target parent directory. If the slug already exists as a subdirectory, append `-2`, `-3`, etc.

---

## Step 7: Create node

Resolve the parent directory:

```bash
# selected_path is the path value from the chosen option (e.g. "." or "propor-predicados/captura-adhoc")
if [ "$SELECTED_PATH" = "." ]; then
  PARENT_DIR="${TREE_DIR%/}"
else
  PARENT_DIR="${TREE_DIR%/}/$SELECTED_PATH"
fi

NODE_DIR="$PARENT_DIR/$SLUG"
mkdir -p "$NODE_DIR"
```

Write `predicate.md`:

```markdown
---
predicate: "<challenge text>"
status: pending
created: <YYYY-MM-DD>
proposed_by: human
---
```

Persist to disk before reporting.

---

## Step 8: Redirect option

Determine the new node's relative path within the tree (relative to TREE_DIR):

```bash
NODE_REL=$(realpath --relative-to="$TREE_DIR" "$NODE_DIR" 2>/dev/null || \
  echo "${NODE_DIR#${TREE_DIR%/}/}")
```

Use `AskUserQuestion`:

> "📍 <tree> | PROPOSE-OBJECTION\n🎯 <proposed challenge text>\n\nNó criado em <NODE_REL>. Quer redirecionar o foco para ele?"

Options:
- "Sim, redirecionar foco"
- "Não, manter foco atual"

If **"Sim, redirecionar foco"**:
- Update `active_node` in `root.md`:
  ```bash
  # Replace the active_node line
  # Use sed or Edit tool to update the frontmatter field
  ```
  Set `active_node: <NODE_REL>` in `root.md`.
- Print: "Ponteiro atualizado. Execute /fractal:run-objection para continuar."

If **"Não, manter foco atual"**:
- Print: "Nó criado. O foco continua em <ACTIVE_NODE or 'raiz'>."

---

## Step 9: Show updated tree

Run the tree renderer to give the human spatial awareness of the new structure:

```bash
FRACTAL_SCRIPTS=$(ls -d ~/.claude/plugins/cache/fractal/fractal/*/scripts 2>/dev/null | tail -1)
[ -z "$FRACTAL_SCRIPTS" ] && FRACTAL_SCRIPTS="$REPO_ROOT/scripts"
bash "$FRACTAL_SCRIPTS/fractal-tree.sh"
```

Print the tree output.

---

## Rules

- One question at a time. Never stack.
- `AskUserQuestion` for ALL human interaction — never plain text questions.
- Persist to disk before reporting success.
- Never create a node if no tree exists. Multiple trees are allowed.
- Never insert into `satisfied` or `pruned` nodes — filter them from position list.
- Generated slug must be unique within the parent directory — append suffix if collision.
- Do not write `discovery.md` for new nodes — that happens in `/fractal:run-objection`.
- **Analyze mode (no args):** status of new nodes is always `pending`, proposed_by always `evaluate`.
- **Manual mode (args provided):** status of new nodes is always `pending`, proposed_by always `human`.
- Maximum 4 options in `AskUserQuestion`.
- Analyze mode does NOT run the full manual flow (Steps 2–9) unless the user picks "Nao, quero propor outro".
