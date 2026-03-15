# Learnings from invalidation

## Learnings from invalidation

Every time the human invalidates something — rejects a proposed predicate, changes a
predicate the agent wrote, says a result didn't satisfy the predicate — this reveals
information about what the human actually wants. **Capture it.**

### What counts as invalidation

- Agent proposes sub-predicate X, human says "no" or proposes Y instead
- Agent writes a predicate, human edits it to something different
- Human says result didn't satisfy the predicate (and explains why)
- Human mutates the root objective
- Human prunes a node the agent thought was viable

### How to capture

Append to `.fractal/learnings.md` (create if it doesn't exist):

```markdown
## <date> — <tree-name>/<node-path>

**Proposed:** <what the agent proposed>
**Human preferred:** <what the human said instead>
**Insight:** <1 sentence — what this reveals about the human's mental model or preferences>
```

### How to use

On every `/fractal:run` entry, if `.fractal/learnings.md` exists, **read it**. Use the
accumulated insights to:
- Propose better-calibrated predicates (avoid patterns the human has rejected before)
- Understand the human's abstraction preferences (too concrete? too abstract?)
- Anticipate the human's priorities and risk tolerance

Learnings are cumulative — they build a picture of the human's judgment over time.
Don't delete entries. The file grows as the project evolves.

### Examples

```markdown
## 2026-03-14 — ciclofaixas/dados-cet

**Proposed:** "endpoint /api/lanes retorna GeoJSON com todas as ciclofaixas da cidade"
**Human preferred:** "endpoint retorna GeoJSON filtrado por região, com cache de 5min"
**Insight:** humano prioriza performance e scoping geográfico sobre completude dos dados

## 2026-03-14 — onboarding-flow

**Proposed:** sub-predicado de spike técnico para testar auth provider
**Human preferred:** sub-predicado de mockup UX do signup flow
**Insight:** humano prioriza validação de UX antes de viabilidade técnica neste projeto
```
