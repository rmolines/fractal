# Phase 0: Extract the objective

## Phase 0: Extract the objective (pre-condition)

This is NOT part of the primitive — it's the pre-condition. Invest maximum energy here.
A 95% good predicate makes everything downstream work. A 70% good predicate causes
cascading rework.

### Crystallize the problem

Use whatever techniques serve the situation — don't apply them mechanically:

- **Inversion:** "What would definitely NOT be a good solution?"
- **Level separation:** "The surface frustration is X... but what's underneath?"
- **Transfer test:** "If you didn't exist, would someone else have this problem?"

Converge on a clear problem statement. Iterate until the human recognizes it:
"Yes, that's it." If they can't confirm, you haven't found it yet.

### Assess scope — one predicate or many?

Once the problem is clear, evaluate whether it's one predicate or multiple:

**Signs it's actually multiple predicates:**
- The problem has 3+ distinct user flows with no shared state
- You can't write a single, focused predicate without "and"
- Different parts could ship independently and each deliver value alone
- Planning would need 9+ deliverables to cover everything

**If it's multiple:** push back and propose decomposition into child nodes.

> "This looks like 3 separate things: auth, dashboard, and billing. Each delivers
> value independently. I suggest we create separate nodes for each. Which one first?"

Then create child directories under `.fractal/` — each with its own `predicate.md`.
The user runs `/fractal:run` on each independently.

### Identify risks

With the problem defined, map risks that need validation before building:

| Risk type | When relevant | Cheap validation |
|---|---|---|
| Strategy / domain | Agent lacks empirical knowledge about what works in this domain | Web research: find 3-5 real cases, extract patterns |
| Usability / UX | Has a user-facing interface | HTML mockup |
| Technical | Integration, API, performance | Spike (throwaway code) |
| Business / market | New product, monetization | Web research + analysis |
| Distribution | How it reaches users | Channel analysis |
| Integration | Depends on external service | API test, spike |

**Strategy / domain risk is the most commonly missed.** Before proposing sub-predicates,
ask: "Do I have empirical knowledge about what actually works here, or am I guessing?"
If guessing → the first sub-predicate should be a research investigation, not execution.

Present the risks and propose investigation order. Not all predicates need investigation —
if the predicate is clear and risks are low, skip straight to execution.

### Investigation cycles (when needed)

Before committing to a predicate, you may need to reduce uncertainty:

**research** — Launch 2-3 parallel subagents (model: sonnet) with WebSearch. Synthesize
results. Update notes in `predicate.md`.

**mockup** — Generate static HTML + Tailwind CSS + hardcoded data. Throwaway code.
Iterate with the human until aligned. Save in node dir.

**spike** — Write minimum code that answers "is this feasible?". Execute and collect
result. Save conclusion in notes.

**interview** — Prepare 3-5 focused questions. Human conducts externally. Synthesize
responses into notes.

**analysis** — Structured analysis (pros/cons, impact/effort, build vs buy). Document
decision in notes.

### Converge on the predicate

After crystallization and any investigation:

1. Converge on a falsifiable predicate in the **useful zone of abstraction**:
   - Too abstract ("facilitate urban mobility") → won't discriminate
   - Useful ("app showing bike lanes in real time for cyclists in SP") → rejects irrelevant, survives changes
   - Too concrete ("PWA with Mapbox GL + CET API layer") → rigid plan disguised as objective
   - Test: if the entire tech stack changed, would this predicate still make sense?
2. When the user confirms → create the root directory and `predicate.md` → save to disk

### Calibrate depth

| Context | Approach |
|---|---|
| New project, vague idea, no data | Deep — multiple rounds, Socratic extraction, investigation cycles |
| Existing project, clear feature | Light — synthesize + validate in one round, skip investigation |
| Existing project, trivial feature | Skip Phase 0 — go straight to the primitive |

Default to light inside an existing repo. Deep is the exception.
