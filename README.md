# OpenPredicate

You tell it what you want. It figures out how to get there.

Most AI coding tools wait for instructions. You say "build this feature," they build
it. You say "fix this bug," they fix it. The thinking is on you. You decide what to
work on, in what order, and hope you're not wasting time on the wrong thing.

OpenPredicate works differently. You state an objective. The agent figures out what
the biggest risk is, goes after that first, and keeps adjusting as it learns. It
doesn't follow a plan. At each step it asks: "what could I figure out right now
that would most change what we do next?"

It's a Claude Code plugin. Works on any project.

## How

You give it a goal. The agent turns it into a falsifiable predicate: not "implement
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

$ /fractal

> Reading .fractal/stripe-billing/ ...
> Active node: webhook-handler. plan.md exists, no results.md.
> Picking up at delivery.
```

Session dies, you come back, run `/fractal` with no arguments. It reads the
filesystem and knows where it left off.

## How is this different?

Other tools ask you to break your project into tasks upfront. You write a PRD,
it becomes a list, the agent follows the list. If a task turns out to be wrong,
you edit the list manually.

OpenPredicate doesn't need a list. You state the goal, it picks the riskiest
piece, works on it, then reassesses. If a path doesn't work out, it backs up
and tries another. You never maintain a plan doc.

## The operation

One recursive function. Same operation at every scale.

```
fractal(predicate):
  if unachievable        → prune
  if a try can satisfy   → try → human validates
  if a cycle can satisfy → plan → build → review → ship → human validates
  else                   → find the riskiest unknown → human validates → recurse
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/rmolines/openpredicate/master/install.sh | bash
```

Start a new session (quit and run `claude` again). Run `/fractal` in any repo.

## The tree

The `.fractal/` directory is where the agent keeps state. Each folder is a
predicate. Which files exist tells the agent what happened and what to do next.

```
.fractal/
  stripe-billing/
    root.md                    # the goal + which node is active
    seat-changes/
      predicate.md             # "Stripe handles mid-cycle seat changes"
      plan.md                  # how to verify it
      results.md               # what happened
    webhook-handler/
      predicate.md             # next piece
    pricing-page/
      predicate.md             # not started yet
```

No database. No JSON. `ls` shows the tree. `cat` shows where you are.

## Skills

The plugin installs a chain of skills into Claude Code:

- `/fractal:init` — bootstrap. Extract an objective, create the tree, hand off to `/fractal`.
- `/fractal` — idempotent state machine. Evaluates the active predicate and advances one step. Call repeatedly to converge.
- `/fractal:try` — fast iteration for small changes that don't need the full cycle.
- `/fractal:planning` — transforms a predicate into an executable plan.
- `/fractal:delivery` — orchestrates subagents to execute the plan.
- `/fractal:review` — validates the implementation against the predicate.
- `/fractal:ship` — PR, CI, deploy, cleanup.
- `/fractal:doctor` — validates tree integrity and optionally fixes inconsistencies.

## Full spec

[LAW.md](./LAW.md) for the full spec if you want the details.
