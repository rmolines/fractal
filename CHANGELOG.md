# Changelog

## 0.6.2 — 2026-03-16
Fix `view.sh` path resolution from plugin cache instead of relative CWD.

## 0.6.1 — 2026-03-16
Fix root re-evaluation on ascend — skip session traversal when ascending to root with children.

## 0.5.6 — 2026-03-15
Structured context headers in all human gates. Every AskUserQuestion across 7 skills now shows breadcrumb, state, and active predicate so a human context-switching between parallel sessions can orient instantly.

## 0.5.5 — 2026-03-15
Session lock guardrails for parallel sessions. New `session-lock.sh` manages per-session lock files. `select-next-node.sh` filters out locked nodes and their ancestors/descendants, forcing concurrent sessions onto sibling or cousin branches.

## 0.5.4 — 2026-03-15
New `/fractal:propose` skill for bottom-up predicate capture. Reframes raw ideas into verifiable predicates and places them in the tree.

## 0.5.3 — 2026-03-15
Auto-generate `.claude/standards.md` from codebase detection (build, test, lint, hooks, branch conventions). Integrated into `/fractal:init` as optional step.

## 0.5.2 — 2026-03-15
`active_node` is now session-scoped. Between sessions it rests at root. Each new session traverses the tree and discovers its own focus. No global pointer to fight over.

## 0.5.1 — 2026-03-15
Sprint skills (planning, delivery, review, ship) now consume `.claude/standards.md` as structured input. Delivery runs lint/type-check gates, validates commit format. Review injects engineering criteria. Fallback to CLAUDE.md when standards absent.

## 0.4.0 — 2026-03-15
**Breaking:** Unified `/fractal` as idempotent state machine (merged with `/fractal:recurse`). New `/fractal:init` bootstrap skill. New `/fractal:doctor` tree validation. Single-tree constraint enforced.

## 0.3.1 — 2026-03-15
Added recursive state machine with evaluate subagent. The evaluator classifies predicates as branch, leaf, or unachievable and proposes the next child.

## 0.2.2 — 2026-03-14
Persistent test-checklist.md artifact. Planning includes `human_test:` field per deliverable. Review consumes human validation results.

## 0.2.0 — 2026-03-14
Planning and delivery skills auto-load project context (satisfied nodes, files created) at startup. Skill reduced from 598 to 319 lines via progressive disclosure.
