# HANDOVER

---

## 2026-03-15 — guardrail-sessoes-paralelas

**Predicate:** sessões paralelas na mesma árvore não atuam no mesmo branch — apenas irmãos/primos

### What was done

Implementado um mecanismo de session locks baseado em arquivos para garantir que múltiplas sessões Claude Code rodando no mesmo repo com a mesma árvore fractal nunca trabalhem no mesmo branch ao mesmo tempo. Antes desta mudança, `select-next-node.sh` era cego a outras sessões — duas sessões podiam escolher o mesmo nó ou nós ancestral/descendente, causando conflitos de edição. Agora, ao focar num nó, a sessão cria um `session.lock` no diretório do nó; o script de seleção lê todos os locks ativos e exclui da seleção o nó locked, seus descendentes e seus ancestrais — forçando sessões paralelas a trabalhar em irmãos ou primos.

Os três deliverables foram executados em dois batches:

- **D1** — criado `scripts/session-lock.sh` com 5 subcomandos (`create`, `remove`, `list`, `cleanup`, `check`). O lock armazena PID, session_id, timestamp e caminho relativo do nó em frontmatter YAML.
- **D2** — modificado `scripts/select-next-node.sh` com lógica de branch exclusion: lê `session.lock` diretamente (sem subprocess), valida PIDs com `kill -0`, filtra nós locked + ancestrais + descendentes. Adiciona campos `locked_count` e `reason: all_pending_locked` no output.
- **D3** — integrado lifecycle de locks em `commands/run.md` (criação ao focar, remoção no ASCEND), documentado `session.lock` em `references/filesystem.md`, adicionado `**/session.lock` ao `.gitignore`.

Todos os 6 critérios do PRD satisfeitos. Review aprovado.

### Key decisions

- **PID-based locks:** cada lock armazena o PID do processo pai (`$PPID`) — verificável em runtime sem estado externo. Stale locks (PID morto) são ignorados automaticamente em toda leitura.
- **Branch exclusion em select-next-node.sh:** a lógica de exclusão lê os locks diretamente (sem chamar session-lock.sh como subprocess) para evitar overhead. O filtro cobre exato, descendente (`locked/`→ prefix) e ancestral (→ `node/` prefix).
- **Stale cleanup opportunístico:** `session-lock.sh cleanup` remove locks com PID morto. O script de seleção já ignora stale locks mesmo sem cleanup explícito — cleanup é convenência, não requisito de segurança.
- **Sem mudança de comportamento sem locks:** adição é puramente aditiva — se não há `session.lock` no tree, `select-next-node.sh` se comporta identicamente ao estado anterior.

### Pitfalls descobertos

- **Risco de PID reuse:** um PID morto pode ser reatribuído a outro processo pelo OS, fazendo `kill -0` retornar true para um PID que não é da sessão fractal. Risco baixo em prática (window muito pequeno), mas sem mitigação explícita além de `session_id` no lock.
- **Lock persistence em crash:** se a sessão travar sem ASCEND, o lock fica no disco com PID válido enquanto o processo-pai existir. O stale detection resolve após o processo morrer. Não há cleanup ativo em crash — a próxima sessão que rodar `select-next-node.sh` ignora o lock automaticamente quando o PID morrer.

### Next steps

- **T1 (manual):** abrir duas sessões Claude Code no mesmo repo. Na sessão A, rodar `/fractal:run` e focar num nó. Na sessão B, rodar `/fractal:run` — deve sugerir um nó em branch diferente. Este teste ainda não foi executado; foi deferido para o primeiro uso real de sessões paralelas.

### Key files changed

- `scripts/session-lock.sh` — novo (gestão de locks: create/remove/list/cleanup/check)
- `scripts/select-next-node.sh` — branch exclusion logic (+~65 linhas)
- `commands/run.md` — lock lifecycle integrado (4 referências a session-lock.sh)
- `references/filesystem.md` — seção `session.lock` adicionada
- `.gitignore` — `**/session.lock` adicionado
