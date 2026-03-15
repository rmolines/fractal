# Standards — Example (Node.js / TypeScript project)
# This is a filled example of .claude/standards.md for a typical TypeScript API.
# Copy the template (templates/standards-template.md) and adapt for your project.

## Gates
build: npm run build
test: npm test
lint: npm run lint
type-check: npx tsc --noEmit
smoke: curl -sf http://localhost:3000/health

## Commit
format: conventional
branch-prefix: feat/
co-author: Claude Sonnet 4.5 <noreply@anthropic.com>
protected-branches:
- main
- production

## Code
max-lines-per-file: 300
simplify-after-delivery: true
hot-file-preflight: true
staleness-check: true

## Deploy
platform: railway
verify: curl -sf https://api.example.com/health
ci-required: true

## Review
- No new any types introduced without explicit justification
- All new async functions have error handling or propagate errors explicitly
- Database queries use parameterized inputs — no string interpolation
- New endpoints are covered by at least one integration test
- No secrets or credentials appear in committed files
