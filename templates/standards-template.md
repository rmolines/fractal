# Standards Template
# Copy to .claude/standards.md in your repo and fill in the values.
# Format: key: value on single lines. Section headers: ## Name. Lists: - item.
# Optional fields can be omitted — skills treat absent fields as empty/disabled.
# Add new fields freely; existing grep patterns are unaffected.

# Reading standards (bash snippets for skills)
#
# Single value:
#   BUILD=$(grep "^build:" .claude/standards.md | sed 's/^build: //')
#
# Boolean field (true if line present and value is "true"):
#   SIMPLIFY=$(grep "^simplify-after-delivery:" .claude/standards.md | awk '{print $2}')
#
# List section (e.g. protected-branches):
#   PROTECTED=$(awk '/^## Commit/{found=1} found && /^protected-branches:/{pb=1; next} pb && /^- /{print substr($0,3)} pb && /^[^-]/{exit}' .claude/standards.md)
#
# Review criteria list:
#   CRITERIA=$(awk '/^## Review/{found=1; next} found && /^- /{print} found && /^##/{exit}' .claude/standards.md)

## Gates
# Commands run before any commit or merge. All must exit 0.
build: <command>                # required — e.g. npm run build
test: <command>                 # required — e.g. npm test
lint: <command>                 # optional — e.g. npm run lint
type-check: <command>           # optional — e.g. npx tsc --noEmit
smoke: <command>                # optional — e.g. curl -sf http://localhost:3000/health

## Commit
format: <format>                # required — e.g. conventional | free | <custom pattern>
branch-prefix: <prefix>         # optional — e.g. feat/ | claude/
co-author: <name <email>>       # optional — injected into every commit message
protected-branches:             # optional — list of branches that must never be force-pushed
- main

## Code
max-lines-per-file: <int>       # optional — triggers warning when file exceeds this limit
simplify-after-delivery: <bool> # optional — if true, review skill checks for unnecessary complexity
hot-file-preflight: <bool>      # optional — if true, delivery skill reads hot files before editing
staleness-check: <bool>         # optional — if true, planning skill checks for stale plan artifacts

## Deploy
platform: <platform>            # optional — e.g. railway | vercel | docker-compose | dmg
verify: <command>               # optional — post-deploy health check command
ci-required: <bool>             # optional — if true, ship skill blocks merge until CI is green

## Review
# Each line is an additional criterion the review skill evaluates beyond the predicate.
# Format: - <criterion in plain language>
- <criterion>
