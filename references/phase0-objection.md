# Phase 0: Extract the challenge

## Phase 0: Extract the challenge (pre-condition)

This is NOT part of the primitive — it's the pre-condition. Invest maximum energy here.
A sharp challenge makes everything downstream work. A vague challenge produces a tree of vague sub-challenges.

### Crystallize the doubt

The human has a doubt, a worry, a dare. Your job: make it precise enough to decompose, but broad enough to survive implementation changes.

Use whatever techniques serve the situation — don't apply them mechanically:

- **Pre-mortem:** "Imagine I delivered this and you're disappointed. What went wrong?"
- **Inversion:** "What would definitely NOT satisfy you?" / "What's the worst version of this?"
- **Specificity test:** "Is this one doubt or several bundled together?"

Converge on a clear challenge. Iterate until the human recognizes it:
"Yes, that's what I doubt." If they can't confirm, you haven't found it yet.

**CRITICAL:** The challenge MUST remain as a negative/doubt — never invert into a positive predicate.
- ✅ "O agente não consegue fazer X" / "Isso não vai funcionar porque Y"
- ❌ "O agente consegue fazer X" / "O sistema funciona com Y"

**Agent-centric framing:** The challenge must be about what the AGENT can't do — not about the state of the world. "Não existe X" is a fact; "o agente não consegue construir X" is a challenge. Always frame from the agent's capability perspective.

### Assess scope — one challenge or many?

Once the doubt is clear, evaluate whether it's one challenge or multiple:

**Signs it's actually multiple challenges:**
- The doubt covers 3+ independent concerns ("can't do the UX, the performance, or the integration")
- You can't write a single focused challenge without "and"
- Different doubts could be tested independently

**If it's multiple:** push back and propose decomposition.

> "This sounds like 3 separate doubts: UX quality, backend performance, and API integration.
> Each can be tested independently. Which one first?"

### Identify blockers

With the challenge defined, map what would make it true:

| Blocker type | Question | Cheap validation |
|---|---|---|
| Epistemic | What does the agent not know that it needs to? | Ask the human, research |
| Capability | What might the agent not be able to do well? | Spike, mockup |
| Taste / vision | Does the human have something specific in mind that's hard to articulate? | Show options, iterate |
| Technical | Is there a hard constraint that could block? | API test, spike |
| Domain | Does the agent lack empirical knowledge about this space? | Web research |

**Epistemic and taste blockers are the most commonly missed.** Before decomposing,
ask: "Is there something you're picturing that I might not be imagining?" If yes →
the first sub-challenge should surface that, not jump to execution.

### Investigation cycles (when needed)

Same as standard fractal — research, mockup, spike, interview, analysis.
These are reusable regardless of framing.

### Converge on the challenge

After crystallization and any investigation:

1. Converge on a challenge in the **useful zone of abstraction**:
   - Too abstract ("you can't do anything well") → accepts everything, tests nothing
   - Useful ("you can't create a UX that makes me want to use this daily") → specific enough to test, broad enough to survive implementation changes
   - Too concrete ("this CSS animation won't have the right easing curve") → premature, tests one detail
   - Test: if the entire approach changed, would this challenge still be meaningful?
2. When the human confirms → create the root node

### Calibrate depth

| Context | Approach |
|---|---|
| Greenfield, vague doubt, no prior work | Deep — multiple rounds, pre-mortem, investigation |
| Existing project, specific concern | Light — crystallize + validate in one round |
| Existing project, trivial doubt | Skip Phase 0 — go straight to the primitive |

Default to light inside an existing repo. Deep is the exception.
