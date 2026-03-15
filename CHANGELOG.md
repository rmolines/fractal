# Changelog

## captura-adhoc — PR #6 — 2026-03-15
**Type:** feat
**Node:** propor-predicados/captura-adhoc
**Commit:** `git show a338844`
**What:** New `/fractal:propose` skill for bottom-up predicate capture. Human can propose a predicate at any time and the agent helps position it in the tree. New `scripts/list-insertion-points.sh` enumerates valid insertion positions. Plugin version bumped to 0.5.4.

## geracao-inicial — PR #5 — 2026-03-15
**Type:** feat
**Node:** engineering-standards/standards-pra-mim/geracao-inicial
**Commit:** `git show 11d641d`
**What:** Auto-generate .claude/standards.md from codebase detection (build/test/lint/hooks/branch conventions). Integrated into /fractal:init as optional step.
**Version:** 0.5.3

## ponteiro-por-sessao — PR #4 — 2026-03-15
**Type:** feat
**Node:** ponteiro-por-sessao
**Commit:** `git show cdff908`
**What:** `active_node` is now a session-scoped pointer. Between sessions it rests at `"."` (root). On `/fractal` entry, the system traverses the tree via `scripts/select-next-node.sh`, identifies the deepest leaf-like pending node, and presents it to the user for validation. ASCEND resets to `"."` instead of ascending to parent — each session discovers its own focus. LAW.md and filesystem.md updated. Plugin version bumped to 0.5.2.

## consumo-skills — PR #3 — 2026-03-15
**Type:** feat
**Node:** engineering-standards/standards-pra-mim/consumo-skills
**Commit:** `git show 5fb4858`
**What:** All 4 sprint skills (planning, delivery, review, ship) now consume `.claude/standards.md` as structured input. Delivery runs lint/type-check gates, validates commit format, checks max-lines. Review injects engineering criteria into evaluator prompt. Planning reads branch-prefix and staleness-check. Ship enforces protected-branches, ci-required, and deploy config overrides. Fallback to project.md when standards.md absent. Plugin version bumped to 0.5.1.

## fractal-ux-refactor — 2026-03-15
**Type:** feat (breaking)
**What:** v0.4.0 — Unified `/fractal` as idempotent state machine (merged `fractal.md` + `recurse.md`). New `/fractal:init` bootstrap skill (Phase 0 + tree creation). New `/fractal:doctor` tree validation skill. Single-tree constraint (one tree per repo). Sprint cycle formalized in LAW.md. Scripts auto-discover single tree without arguments. XState-inspired statechart as canonical spec.
**Breaking:** `/fractal:recurse` removed — use `/fractal` directly. Bootstrap via `/fractal:init`.

## recurse-and-evaluate — 2026-03-15
**Type:** feat
**What:** Added /fractal:recurse command (recursive state machine that evaluates, executes, or subdivides predicates) with evaluate subagent (finds largest confident sub-predicate and assesses sprint-fitness). New active-predicate.sh helper script. Plugin version bumped to 0.3.1.

## contexto-cross-node — PR #2 — 2026-03-15
**Type:** feat
**Node:** contexto-cross-node
**Commit:** `git show 2f8afe9`
**What:** Planning and delivery skills now auto-load project context (satisfied nodes, files created) at startup — no human prompt needed. Applied to both fractal and launchpad frameworks.

## teste-pos-delivery — PR #1 — 2026-03-14
**Type:** feat
**Node:** progressive-dx/teste-pos-delivery
**Commit:** `git show b63d5d1`
**What:** Persistent test-checklist.md artifact replaces ad-hoc chat-only manual test lists. Planning now includes `human_test:` field per deliverable. Delivery generates Schema 9 checklist mapped to predicate aspects. Review consumes human validation results in evaluator prompt and decision framework. Plugin version bumped to 0.2.2.

## enxugar-skill — 076b343 — 2026-03-14
**Type:** improvement
**Node:** recursao-real/enxugar-skill
**Commit:** `git show 076b343`
**What:** Skill /fractal reduced from 598 to 319 lines via progressive disclosure. Auxiliary content (Phase 0, filesystem spec, learnings protocol) moved to `references/`. State detection + breadcrumb extracted to `scripts/fractal-state.sh`. Explicit recursion loop added to prevent premature stops after subdivision.
