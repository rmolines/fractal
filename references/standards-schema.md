# Standards Schema

Formal reference for `.claude/standards.md` — the engineering standards file consumed by fractal sprint skills.

**Template:** `templates/standards-template.md`
**Example:** `templates/standards-example.md`
**Format:** same key-value convention as `.claude/project.md` — `key: value` per line, `## Section` headers, `- item` for lists.

---

## Parsing conventions

```bash
# Single-value field
BUILD=$(grep "^build:" .claude/standards.md | sed 's/^build: //')

# Boolean field
SIMPLIFY=$(grep "^simplify-after-delivery:" .claude/standards.md | awk '{print $2}')

# Inline list (comma-separated value)
FILES=$(grep "^files:" .claude/standards.md | sed 's/^files: //')

# Multi-line list under a key
PROTECTED=$(awk '
  /^protected-branches:/{found=1; next}
  found && /^- /{print substr($0,3)}
  found && /^[^-]/{exit}
' .claude/standards.md)

# Entire section as list (## Review criteria)
CRITERIA=$(awk '/^## Review/{found=1; next} found && /^- /{print} found && /^##/{exit}' .claude/standards.md)
```

---

## Section: Gates

Commands that must exit 0 before any commit or merge. Skills run these in sequence and abort on first failure.

| Field | Type | Required | Default | Read by | Purpose |
|---|---|---|---|---|---|
| `build` | string (command) | required | — | delivery, ship | Compile/bundle step. Confirms no syntax or import errors. |
| `test` | string (command) | required | — | delivery, review, ship | Full test suite. Primary correctness gate. |
| `lint` | string (command) | optional | skipped | delivery, ship | Style and static analysis. Enforces code conventions. |
| `type-check` | string (command) | optional | skipped | delivery, ship | TypeScript / type checker pass. Catches type regressions. |
| `smoke` | string (command) | optional | skipped | ship | Lightweight runtime check post-deploy. Confirms service is alive. |

---

## Section: Commit

Controls how commits and branches are created and protected.

| Field | Type | Required | Default | Read by | Purpose |
|---|---|---|---|---|---|
| `format` | string | optional | free | delivery, ship | Commit message format. Values: `conventional`, `free`, or a custom regex pattern. |
| `branch-prefix` | string | optional | — | planning, delivery | Prefix prepended to all new branches. E.g. `feat/`, `claude/`. |
| `co-author` | string | optional | — | delivery, ship | `Name <email>` injected into every commit's `Co-Authored-By` trailer. |
| `protected-branches` | list | optional | — | ship | Branches that must never be force-pushed or deleted. Ship skill blocks direct pushes to these. |

---

## Section: Code

Quality thresholds and behavioral flags for delivery and review.

| Field | Type | Required | Default | Read by | Purpose |
|---|---|---|---|---|---|
| `max-lines-per-file` | int | optional | — | delivery, review | If a touched file exceeds this count after edits, review skill flags it. |
| `simplify-after-delivery` | bool | optional | false | review | If `true`, review evaluates whether delivered code introduced unnecessary complexity. |
| `hot-file-preflight` | bool | optional | false | delivery | If `true`, delivery reads hot files listed in `project.md` before editing any of them. |
| `staleness-check` | bool | optional | false | planning | If `true`, planning detects plan artifacts older than 7 days and warns before proceeding. |

---

## Section: Deploy

Deployment target and CI integration settings.

| Field | Type | Required | Default | Read by | Purpose |
|---|---|---|---|---|---|
| `platform` | string | optional | — | ship | Deployment platform identifier. Values: `railway`, `vercel`, `docker-compose`, `dmg`, etc. |
| `verify` | string (command) | optional | — | ship | Health-check command run after deploy. Must exit 0 to confirm successful deployment. |
| `ci-required` | bool | optional | false | ship | If `true`, ship skill blocks merge until the CI pipeline reports green on the PR. |

---

## Section: Review

A freeform list of additional criteria the review skill evaluates beyond the predicate. Each line is a single criterion in plain language.

```markdown
## Review
- No new `any` types without justification
- All async functions propagate errors explicitly
```

| Item | Type | Required | Read by | Purpose |
|---|---|---|---|---|
| `- <criterion>` | string (one per line) | optional | review | Appended to the evaluator's checklist on every review pass. |

---

## Evolution rules

1. **Add fields freely.** New fields in any section are invisible to skills that do not grep for them.
2. **Never rename existing fields.** Rename = breaking change for all skills that read the old name.
3. **New sections are safe.** An unknown `## Section` header is ignored by existing parsers.
4. **Booleans use `true` / `false` literals.** Absence of a boolean field is always treated as `false`.
5. **List items use `- ` prefix.** Skills parse lists with awk; any other prefix breaks extraction.
