# 🪾 Fractal

<p align="center">
  <img src="assets/fractal-recursion.png" alt="Fractal — recursive decomposition" width="600">
</p>

**Recursive project management for Claude Code. State a goal — it figures out what to do next.**

![version](https://img.shields.io/badge/version-0.9.0-blue) ![license](https://img.shields.io/badge/license-MIT-green)

[Install](#install) · [How it works](#how) · [Skills](#skills) · [Full spec](./LAW.md) · [Theory](./THEORY.md)

Fractal is a Claude Code plugin that decomposes goals into verifiable predicates and always works on the riskiest unknown first. You state an objective. The agent picks the piece with the most uncertainty, works on it, then reassesses. When a path fails, it backs up and tries another. Same operation at every scale. Works on any project.

## How

You give it a goal. It turns that into a verifiable condition, breaks it down one
piece at a time, and always picks the piece that reduces the most uncertainty.

```
$ /fractal:init I want to build an open-source Granola — local meeting
  recorder that transcribes and feeds context into Claude Code via MCP

> Before I write the root predicate: are you capturing system audio
> (the call), microphone (your voice), or both?

Both. I want the full conversation, locally, no cloud.

> Predicate: "Users run a local MCP server that captures meeting audio,
> transcribes it, and exposes structured notes to Claude Code —
> no data leaves the machine."
> Create the tree?

Yes.

> Biggest risk: whether macOS even allows capturing system audio
> programmatically without a kernel extension. If it doesn't, the
> entire approach changes. Starting with a spike on ScreenCaptureKit.
```

A few days later:

```
$ /fractal:run

> Reading tree... 8 nodes. 3 satisfied, 5 pending.
> "screencapturekit-spike" satisfied — system audio capture works
> without kernel extension on macOS 13+.
> Re-evaluating parent... next risk: chunking live audio into
> segments the transcription model can handle. Starting there.
```

Session dies, you come back, run `/fractal:run`. It reads the filesystem
and picks up where it left off. When a piece is done, the parent gets
re-evaluated — maybe it needs another piece, maybe the whole direction
was wrong and it prunes the branch and tries something else.

## Install

Requires [Claude Code](https://claude.ai/code) with plugin support.

```bash
curl -fsSL https://raw.githubusercontent.com/rmolines/fractal/master/install.sh | bash
```

Start a new session and run `/fractal:run` in any repo. Override the install path
with `INSTALL_DIR=~/your/path` before the curl command.

## How is this different?

Other tools ask you to decompose upfront. You write a PRD, it becomes a task
list, the agent follows the list. If a task turns out wrong, you fix the list.

Fractal doesn't need a list. You state the goal, it picks the riskiest piece,
works on it, then reassesses. If a path doesn't work out, it backs up and tries
another.

**vs. [Task Master](https://github.com/eyaltoledano/claude-task-master) (~27k stars):**
PRD becomes a flat task list. No re-evaluation after each task.

**vs. [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD):**
Specialized agents per phase (PM, Architect, Developer). Rich but rigid — six
phases in fixed order.

**vs. [CCPM](https://github.com/automazeio/ccpm):**
GitHub Issues + worktrees. Sound state management but fixed hierarchy. Doesn't
handle plan invalidation.

**vs. native Claude Code Tasks:**
Good for checklists. Not for goal decomposition.

**What fractal does differently:**
- Conditions, not tasks. "Users can authenticate with Google" vs. "implement auth."
- One recursive primitive at every scale. No fixed hierarchy.
- One child at a time. Re-evaluate the parent after each.
- Pruning is a feature. Failed path → back up → try another.
- The tree is the plan, the log, and the state. Nothing else to maintain.

## The operation

One recursive function. Same structure at every scale.

```
fractal(predicate):
  discover(predicate)        → branch | leaf | unachievable
  if unachievable            → prune
  if leaf, patch can satisfy → patch → human validates
  if leaf, cycle needed      → prd → plan → build → review → ship → human validates
  if branch                  → find riskiest child → human validates → recurse
```

## This is fractal's own tree

The project manages itself with the same primitive it gives you.

```
.fractal ○  "developers using Claude Code discover fractal, understand the value..."
├── validated-market-need ✓ — "Pain confirmed, no equivalent tool exists"
├── mapped-user-journey ✓ — "8-step journey from discovery to retention"
│   ├── added-session-example ✓ — "Concrete demo in README before install"
│   └── clarified-skill-hierarchy ✓ — "Separated 'you use' from 'runs internally'"
├── picks-riskiest-piece-first ○
│   ├── defined-scoring-rubric ✓ — "Uncertainty × impact × return"
│   ├── scores-persisted ✓ — "Recorded in each node's discovery file"
│   └── auto-selection-by-score ○
├── enforces-engineering-standards ✓ — "Auto-generates, consumes, and updates standards"
├── resumes-where-you-left-off ✓ — "Each session discovers its own focus"
├── runs-parallel-sessions-safely ✓ — "Locks force concurrent work onto sibling branches"
├── recursive-skill-invocation ○
│   ├── descend-into-children ✓ — "Self-invocation pattern validated"
│   └── return-to-parent ✗
├── captures-ideas-bottom-up ○
│   └── reframes-raw-input ✓ — "/fractal:propose turns tasks into conditions"
├── outsider-validation ○
├── multi-channel-distribution ○
├── competitive-positioning ✓ — "Compared against Task Master, BMAD, CCPM, ICM"
├── validates-assumptions-first ✓ — "Web search before acting on stale knowledge"
└── html-dashboard ✓ — "Standalone viewer, no dependencies"

88 nodes · 48 satisfied · 39 pending · 1 pruned
```

The pruned node (`return-to-parent`) was an approach that didn't work. The system
recognized it, backed up, and tried something else. That's the point.

Each satisfied node writes a `conclusion.md` — what was achieved, key decisions,
deferred items. Any future session reads conclusions instead of loading every
file. The tree is its own documentation.

## What it actually does

**Risk-first ordering.** The evaluator scores each candidate by uncertainty,
impact, and return. Highest uncertainty gets worked first — kill the unknown
before optimizing value delivery.

**Session continuity.** Die mid-sprint, come back next week. `/fractal:run`
reads the filesystem and picks up where you left off. No global pointer to fight
over.

**Parallel sessions.** Session locks prevent two sessions from working the same
node. Run multiple Claude Code sessions on the same project safely.

**Fast path.** `/fractal:patch` handles small changes without the full sprint
cycle. Only the final validation is human.

**Bottom-up capture.** `/fractal:propose` takes a raw idea, reframes it into a
verifiable condition, and places it in the tree.

**Objection trees.** `/fractal:init-objection` applies the same primitive in
reverse — decomposes challenges instead of goals. "You can't do X" becomes the
root, children are reasons it might be true, satisfaction means refutation.
Durable refutation required: the capability must survive session reset.

**Sprint agent.** The planning → delivery → review → ship cycle runs as a
single subagent with no human gates. The review is the quality gate. You
validate only the final result.

**Engineering standards.** `/fractal:init` generates `.claude/standards.md` from
your codebase. Each delivery auto-updates it so standards never drift.

## Skills

**You use:**
- `/fractal:init` — state an objective, create the tree.
- `/fractal:run` — advance one step. Call repeatedly to converge on the goal.
- `/fractal:init-objection` — stress-test a plan. Decomposes challenges instead of goals.
- `/fractal:propose` — capture a raw idea, reframe it, place it in the tree.
- `/fractal:view` — open the HTML dashboard in your browser.

**Runs internally:**
- `/fractal:patch` — fast path for small changes.
- `/fractal:planning` → `/fractal:delivery` → `/fractal:review` → `/fractal:ship` — the sprint cycle.
- `/fractal:doctor` — tree integrity validation.

## Full spec

[LAW.md](./LAW.md) for the formal specification. [THEORY.md](./THEORY.md) for the
theoretical grounding — how the primitive converges with HTN planning, reinforcement
learning options, model predictive control, and four other fields.
