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

You give it a goal. The agent turns it into a verifiable predicate: not "implement
billing" but "users can pay monthly per seat via Stripe." Then it breaks that down,
one piece at a time, always picking the piece that reduces the most uncertainty.

When a piece is done, the parent gets re-evaluated. Maybe it's satisfied. Maybe it
needs another piece. Maybe the whole direction was wrong and it prunes the branch
and tries something else. The tree of predicates that builds up in `.fractal/` is
the plan, the progress log, and the session state. You don't maintain anything
separately.

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
filesystem and knows where it left off.

## How is this different?

Other tools ask you to break your project into tasks upfront. You write a PRD,
it becomes a list, the agent follows the list. If a task turns out to be wrong,
you edit the list manually.

Fractal doesn't need a list. You state the goal, it picks the riskiest
piece, works on it, then reassesses. If a path doesn't work out, it backs up
and tries another. You never maintain a plan doc.

## The operation

One recursive function. Same operation at every scale.

```
fractal(predicate):
  discover(predicate)        → branch | leaf | unachievable
  if unachievable            → prune
  if leaf, patch can satisfy → patch → human validates
  if leaf, cycle needed      → prd → plan → build → review → ship → human validates
  if branch                  → find riskiest child → human validates → recurse
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/rmolines/fractal/master/install.sh | bash
```

Start a new session (quit and run `claude` again). Run `/fractal:run` in any repo.

## The tree

The `.fractal/` directory is where the agent keeps state. Each folder is a
predicate. Which files exist tells the agent what happened and what to do next.

```
.fractal/
  stripe-billing/
    root.md                    # the goal + which node is active
    seat-changes/
      predicate.md             # "Stripe handles mid-cycle seat changes"
      discovery.md             # node_type: leaf
      prd.md                   # acceptance criteria
      plan.md                  # how to verify it
      results.md               # what happened
      conclusion.md            # what was achieved (feeds parent re-evaluation)
    webhook-handler/
      predicate.md             # next piece
      discovery.md             # node_type: leaf
    pricing-page/
      predicate.md             # not started yet
```

No database. No JSON. `ls` shows the tree. `cat` shows where you are.

When a node is satisfied, it writes a `conclusion.md` summarizing what was
achieved. Parent nodes read their children's conclusions to decide if the branch
is complete or needs more work. This is how context survives across sessions
without loading every file.

## What it actually does

Beyond the core loop, fractal handles the mechanics that make recursive
decomposition work in practice:

**Risk-return election.** The evaluator scores each candidate by uncertainty
reduction and implementation cost. `select-next-node.sh` picks the highest
leverage option, prioritizing undiscovered and branch nodes over leaves so
direction gets validated before effort is committed.

**Session-scoped focus.** Each session discovers its own starting point by
traversing the tree. No global pointer to fight over. When a node completes,
the pointer resets so the next session can reassess from scratch.

**Parallel sessions.** Session locks prevent two sessions from working the same
node. If your node is locked, the traversal skips to a sibling or cousin.
`bash scripts/session-lock.sh cleanup` clears stale locks.

**Fast path.** `/fractal:patch` handles small changes without the full sprint
cycle. Agentic gates decide complexity, resolve ambiguities, and check for
conflicts automatically. Only the final validation is human.

**Bottom-up capture.** `/fractal:propose` takes a raw idea or task and reframes
it into a verifiable predicate, then places it in the tree. You don't need to
think in predicates to add work.

**Engineering standards.** `/fractal:init` generates `.claude/standards.md` from
your codebase. Sprint skills consume it as structured input, and each delivery
auto-updates the standards so they never drift from the code.

**Preventive research.** Before acting on assumptions about APIs, library
versions, or framework behavior, the agent runs a quick web search to validate
currency. Catches stale knowledge before it becomes wasted work.

**HTML viewer.** `bash scripts/view.sh` generates a standalone HTML dashboard
with two tabs: the skill chain and the full predicate tree with status
indicators. No dependencies.

## Skills

The plugin installs a chain of skills into Claude Code:

- `/fractal:init` — bootstrap. Extract an objective, create the tree, hand off to `/fractal:run`.
- `/fractal:run` — idempotent state machine. Evaluates the active predicate and advances one step. Call repeatedly to converge.
- `/fractal:propose` — capture a raw idea, reframe it as a predicate, place it in the tree.
- `/fractal:patch` — fast patch for small changes that don't need the full cycle.
- `/fractal:planning` — transforms a predicate into an executable plan.
- `/fractal:delivery` — orchestrates subagents to execute the plan.
- `/fractal:review` — validates the implementation against the predicate.
- `/fractal:ship` — PR, CI, deploy, cleanup.
- `/fractal:doctor` — validates tree integrity and optionally fixes inconsistencies.
- `/fractal:view` — open the HTML dashboard in your browser.

## Full spec

[LAW.md](./LAW.md) for the full spec if you want the details.
