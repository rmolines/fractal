# OpenPredicate

One recursive operation. Predicates, not tasks.

You start a project. You write a plan. Three days in, the plan is wrong, the doc
is stale, and you're keeping two sources of truth in sync — the code and the
document describing what the code was supposed to do.

OpenPredicate is a Claude Code plugin. Instead of a plan that rots, it keeps a
tree of predicates in `.fractal/`. Each predicate is a falsifiable condition — a
truth to reach, not a task to check off. The tree doubles as plan, log, and
session state. `ls` shows the structure. `cat` shows where you are. When a session
dies and a new one starts, the agent reads the directory and picks up where it
left off.

## How is this different?

Most planning tools for coding agents decompose work into tasks: PRD → epic →
task → subtask. Task Master, CCPM, and BMAD work this way. Fixed hierarchy,
linear lifecycle, state in JSON or GitHub Issues.

OpenPredicate makes different bets:

| | Others | OpenPredicate |
|---|---|---|
| Unit of work | Task (action to complete) | Predicate (truth to reach) |
| Decomposition | Upfront, full project | One child at a time |
| State | JSON / database / Issues | Filesystem |
| Failed path | Error or stale task | Prune, re-evaluate parent, try another path |

"Implement auth" is a task. "Users can sign in with Google" is a predicate.
The difference: when you satisfy a child predicate, that is progress toward
the parent by definition. No tracking layer needed. And because the tree grows
one node at a time — re-evaluating the parent after each — the plan can't drift from reality.

## What it looks like

```
$ /fractal add stripe billing to the app

> Before I write the predicate — one-time payments, subscriptions, or both?

Both. Monthly plans, per-seat pricing.

> Predicate: "Users can subscribe to a monthly plan and be billed per seat
> via Stripe, with changes taking effect immediately."
> Create the node?

Yes.

> Created .fractal/stripe-billing/predicate.md
> First child: "Stripe customer created on signup and linked to user record."
> Starting there.

------- next day -------

$ /fractal

> Reading .fractal/stripe-billing/ ...
> Active node: webhook-handler — plan.md exists, no results.md.
> Picking up at delivery.
```

## The operation

One function. Works at any scale.

```
fractal(predicate):
  if unachievable        → prune
  if a try can satisfy   → try → human validates
  if a cycle can satisfy → planning → delivery → review → ship → human validates
  else                   → pick one child predicate → human validates → recurse
```

A predicate is a falsifiable condition. The tree grows one node at a time. After
a child is satisfied, the parent gets re-evaluated — maybe it's done, maybe it
needs another child. Discovery isn't a separate phase. It's the recursion.

## Install

```bash
git clone https://github.com/rmolines/openpredicate ~/git/openpredicate
```

Add to `~/.claude/marketplace.json` (create it if missing):

```json
{
  "plugins": [{"path": "~/git/openpredicate"}]
}
```

If the file exists, add `{"path": "~/git/openpredicate"}` to the `plugins` array.

Start a new session (quit and run `claude` again). `/fractal` will be available
in any repo.

Commands use the `/fractal` prefix — after the recursive operation at its core.

## Skills

You need one command: `/fractal`. It handles the rest.

**You run:**

| Skill | What it does |
|---|---|
| `/fractal` | Start a new objective or resume the active one. Orchestrates planning, delivery, review, and shipping. |
| `/fractal:try` | Quick path for simple predicates. Runs in an isolated worktree — approve or discard. |
| `/fractal:view` | Opens an HTML dashboard of the predicate tree in the browser. |

**Run internally** (called by `/fractal`):

| Skill | What it does |
|---|---|
| `/fractal:planning` | Turns a predicate into a plan with deliverables and a dependency graph. |
| `/fractal:delivery` | Runs subagents in parallel against the plan. |
| `/fractal:review` | Independent check of the diff against the predicate. Can send work back. |
| `/fractal:ship` | PR, CI, deploy, cleanup. Marks the predicate satisfied. |

## The tree

Every directory under `.fractal/` is a node. Which files exist tells the agent
what happened and what comes next.

```
.fractal/
  stripe-billing/
    root.md                    # root predicate + pointer to active node
    customer-setup/
      predicate.md             # the condition to satisfy
      plan.md                  # from /fractal:planning
      results.md               # from /fractal:delivery
      review.md                # from /fractal:review
    webhook-handler/
      predicate.md
    pricing-page/
      predicate.md
```

| Files present | State |
|---|---|
| `predicate.md` only | Not started |
| `plan.md` | Planned — run delivery |
| `plan.md` + `results.md` | Executed — run review |
| `plan.md` + `results.md` + `review.md` | Reviewed — validate, then ship |
| `status: satisfied` in frontmatter | Done — re-evaluate parent |

New session reads the tree and continues where the last one stopped.

## The predicate window

Every predicate should sit in a useful zone of abstraction:

```
Too abstract:  "improve the product"         → accepts anything
Useful:        "billing via Stripe for SaaS"  → rejects irrelevant work, survives stack changes
Too concrete:  "Stripe.js v3 + webhooks"      → a plan disguised as a goal
```

If you swapped the entire stack and the predicate still made sense, it's in the
right zone.

## Full spec

[LAW.md](./LAW.md) — the complete spec.
