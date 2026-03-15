---
description: "Propose a new predicate and place it in the fractal tree. Use when you have an idea for a predicate but don't know where to put it."
argument-hint: "predicate text in natural language, or empty to be prompted"
allowed-tools: AskUserQuestion, Bash, Read, Write, Edit, Glob
---

# /fractal:propose

## Human gates

Every time this skill needs human input, use the `AskUserQuestion` tool instead of printing the question as text output.

Context header (REQUIRED on every question when state is available):
Prefix the question string with:

📍 <breadcrumb> | <state>
🎯 <active_predicate (max 80 chars)>

<actual question>

Variables come from the pre-loaded State section. If state is not yet loaded (e.g., early steps of /fractal:propose before tree detection), omit the header.

IMPORTANT: The header must be plain text. No markdown formatting (no **, ##, *, etc.) in the question string. Emojis are fine as visual anchors.

Input: $ARGUMENTS — predicate text in natural language, or empty to be prompted.

---

## Step 1: Parse input

If `$ARGUMENTS` is empty, use `AskUserQuestion`:

> "Qual predicado você quer propor?"

Wait for response. The answer becomes the predicate text.

If `$ARGUMENTS` is provided, use it directly as the predicate text.

---

## Step 2: Validate predicate (verifiability check)

Evaluate the predicate text for verifiability. A valid predicate must:
- Describe a concrete, observable condition
- Be confirmable as true or false by a human
- Refer to a single concern (not multiple unrelated things joined by "and")

Check for these failure modes and push back if found:

**Too abstract (no concrete condition):**
Examples: "o sistema é bom", "a UX está melhor", "o código está limpo"
Push back: "Esse predicado é vago demais. Um predicado precisa ser verificável — algo que pode ser confirmado como verdadeiro ou falso. Tente reformular com uma condição concreta: o que exatamente pode ser observado ou medido?"
Use `AskUserQuestion` to ask for a reformulation.

**Compound predicate (multiple unrelated concerns joined by "and"/"e"):**
Examples: "o login funciona e o dashboard carrega rápido e o usuário recebe emails"
Push back: "Esse predicado cobre múltiplas preocupações independentes. Prefiro trabalhar com um por vez — qual é o mais importante agora? Ou posso criar predicados separados para cada."
Use `AskUserQuestion` to select one concern or confirm splitting.

**Task framing (describes action, not condition):**
Examples: "implementar autenticação", "refatorar o módulo X", "adicionar testes"
Push back: "Isso soa como uma tarefa, não uma condição. Predicados descrevem um estado do mundo — o que será verdadeiro quando essa tarefa for concluída?"
Use `AskUserQuestion` to ask for rephrasing as a condition.

After each pushback, wait for the human to reformulate. If the reformulated predicate still fails, push back again — maximum 2 rounds. After 2 rounds, accept the predicate and note the concern.

Once the predicate passes (or after 2 rounds), proceed to step 3.

---

## Step 3: Detect tree

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
FRACTAL_DIR="$REPO_ROOT/.fractal"
```

Check that `.fractal/` exists and has exactly one tree (directory with `root.md` inside):

```bash
TREE_DIR=$(ls -d "$FRACTAL_DIR"/*/  2>/dev/null | while read d; do [ -f "${d}root.md" ] && echo "$d"; done | head -1)
```

If no tree found: STOP with message "Nenhuma árvore fractal encontrada. Execute /fractal:init primeiro."

If multiple trees found: STOP with message "Múltiplas árvores encontradas. Execute /fractal:doctor --fix para limpar."

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
1. Active node (if `status` is `pending` or `candidate`) — shown first
2. Shallowest pending nodes first
3. Alphabetical by path within same depth

Build `AskUserQuestion` with options from the selected positions:

Format each option as:
- Label: last path segment (or "Raiz" for `.`)
- Description: truncated predicate (first 60 chars) + ` | profundidade: <depth> | filhos: <children>`

Example call:
```
AskUserQuestion(
  question: "Onde posicionar o predicado '<proposed predicate>'?",
  options: [
    { label: "captura-adhoc", description: "o humano pode propor um predicado avulso... | profundidade: 1 | filhos: 2" },
    { label: "Raiz", description: "desenvolvedores que usam Claude Code... | profundidade: 0 | filhos: 24" },
    { label: "skills-recursivas", description: "a skill /fractal:descend substitui... | profundidade: 1 | filhos: 6" },
    { label: "test-outsider", description: "um dev que nunca viu o fractal... | profundidade: 1 | filhos: 1" }
  ]
)
```

Wait for selection. Map the chosen label back to its full path.

---

## Step 6: Generate slug

From the predicate text, derive a kebab-case slug:
1. Lowercase the text
2. Replace spaces and special characters with hyphens
3. Remove characters that are not alphanumeric or hyphens
4. Collapse multiple consecutive hyphens into one
5. Strip leading/trailing hyphens
6. Truncate to 30 characters, cutting at the last hyphen boundary if possible

Examples:
```
"o humano pode propor predicados avulsos" → "humano-pode-propor-predicados"
"a autenticação funciona em produção"    → "autenticacao-funciona-producao"
"CI passa em todos os PRs"               → "ci-passa-em-todos-os-prs"
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
predicate: "<predicate text>"
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

> "Nó criado em <NODE_REL>. Quer redirecionar o foco para ele?"

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
- Print: "Ponteiro atualizado. Execute /fractal:run para continuar."

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
- Respect single-tree constraint. Never create a node if no tree exists.
- Never insert into `satisfied` or `pruned` nodes — filter them from position list.
- Generated slug must be unique within the parent directory — append suffix if collision.
- Do not write `discovery.md` for the new node — that happens in `/fractal:run`.
- Do not run the evaluator — just create the bare `predicate.md`.
- Maximum 4 options in `AskUserQuestion`.
- Status of new node is always `pending`, proposed_by always `human`.
