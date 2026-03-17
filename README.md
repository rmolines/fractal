# Fractal

Recursive project management for Claude Code.

You tell it what you want. It figures out how to get there.

Most AI coding tools wait for instructions. You say "build this feature," they build
it. You say "fix this bug," they fix it. The thinking is on you. You decide what to
work on, in what order, and hope you're not wasting time on the wrong thing.

Fractal works differently. You state an objective. The agent figures out what
the biggest risk is, goes after that first, and keeps adjusting as it learns. It
doesn't follow a plan. At each step it asks: "what could I figure out right now
that would most change what we do next?"

It's a Claude Code plugin. Works on any project.

## How

You give it a goal. The agent turns it into a verifiable condition: not "implement
billing" but "users can pay monthly per seat via Stripe." Then it breaks that down,
one piece at a time, always picking the piece that reduces the most uncertainty.

When a piece is done, the parent gets re-evaluated. Maybe it's satisfied. Maybe it
needs another piece. Maybe the whole direction was wrong and it prunes the branch
and tries something else.

```
$ /fractal:init add billing to the app

> Before I write the predicate: one-time payments, subscriptions, or both?

Both. Monthly plans, per-seat pricing.

> Predicate: "Users can subscribe to a monthly plan and be billed per seat
> via Stripe, with changes taking effect immediately."
> Create the node?

Yes.

> The biggest risk here is whether Stripe's API handles mid-cycle seat
> changes cleanly. Starting with that.

------- next day -------

$ /fractal:run

> Reading .fractal/stripe-billing/ ...
> Active node: webhook-handler. plan.md exists, no results.md.
> Picking up at delivery.
```

Session dies, you come back, run `/fractal:run` with no arguments. It reads the
filesystem and knows where it left off. The tree of predicates in `.fractal/` is
the plan, the progress log, and the session state — all at once.

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

20 of 71 nodes · 34 satisfied · 36 pending · 1 pruned
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

**Engineering standards.** `/fractal:init` generates `.claude/standards.md` from
your codebase. Each delivery auto-updates it so standards never drift.

## Skills

**You use:**
- `/fractal:init` — state an objective, create the tree.
- `/fractal:run` — advance one step. Call repeatedly to converge on the goal.
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
