# Protocolo de design com Paper MCP

Referência para iterar no design do fractal viewer usando o Paper MCP. Usado durante
`/fractal:patch` ou `/fractal:delivery` quando o deliverable é UI.

---

## Ferramentas relevantes

| Ferramenta | Uso |
|---|---|
| `get_basic_info` | Entender estrutura do arquivo antes de modificar |
| `create_artboard` | Criar nova superfície de design |
| `write_html` | Adicionar conteúdo — um grupo visual por chamada, máx ~15 linhas |
| `get_screenshot` | Checkpoint visual — obrigatório a cada 2-3 modificações |
| `get_jsx` | Exportar estrutura do componente como código |
| `get_selection`, `get_tree_summary`, `get_children`, `get_node_info` | Explorar design existente |
| `get_computed_styles` | Extrair valores CSS precisos de elementos existentes |
| `update_styles`, `set_text_content` | Modificar elementos existentes |
| `duplicate_nodes` | Reutilizar padrões de forma eficiente |
| `finish_working_on_nodes` | **Obrigatório** ao terminar qualquer sessão de edição |

---

## Brief de design (antes de qualquer trabalho)

Gerar antes de abrir o Paper:

- **Paleta** — 5-6 hex com papéis definidos (background, surface, primary, muted, text, border)
- **Tipografia** — fonte, pesos, escala de tamanhos (body, label, heading, mono)
- **Ritmo de espaçamento** — gaps por nível: seção / grupo / elemento
- **Direção visual** — uma frase (ex: "terminal minimalista, alta densidade, sem ornamento")

---

## Estágios do workflow

### Estágio 1 — Wireframe

Objetivo: estrutura do layout no canvas, sem polish visual.

1. `create_artboard` com dimensões do viewport alvo
2. `write_html` — blocos estruturais (header, tree area, status bar, etc.) com cores neutras
3. `get_screenshot` — validar proporções e hierarquia antes de continuar

### Estágio 2 — Refinamento

Objetivo: tipografia, cores, espaçamento, polish visual.

1. `update_styles` para aplicar paleta e tipografia
2. `write_html` para adicionar detalhes visuais — uma região por chamada
3. `get_screenshot` a cada 2-3 modificações — nunca pular
4. `duplicate_nodes` para padrões repetidos (nodes, badges, separadores)

### Estágio 3 — Checkpoint de revisão

Executar o checklist abaixo a partir do último screenshot:

| Critério | Verificar |
|---|---|
| Espaçamento | Gaps uniformes, ritmo visual consistente |
| Tipografia | Tamanhos legíveis, hierarquia clara |
| Contraste | Legibilidade do texto, distinção entre elementos |
| Alinhamento | Eixos verticais e horizontais respeitados |
| Clipping | Nenhum conteúdo cortado ou escondido |
| Repetição | Variação de escala/peso/espaçamento — sem monotonia |

Se algum critério falhar: `update_styles` ou `write_html` para corrigir, depois novo screenshot.

### Estágio 4 — Gate humano

Apresentar screenshot ao humano com `AskUserQuestion`. Aguardar aprovação explícita da
direção visual antes de exportar. Não avançar com "parece ok" implícito.

### Estágio 5 — Exportação

1. `get_jsx` para extrair HTML do componente
2. Adaptar para uso no repo: inline styles, sem dependências externas
3. Verificar integração com `view.sh` e estrutura do fractal viewer
4. `finish_working_on_nodes` — obrigatório antes de fechar a sessão Paper

---

## Gates de saída

Antes de commitar o HTML no repo:

- [ ] Humano viu screenshot e aprovou direção visual
- [ ] Checkpoint de revisão passou nos 6 critérios
- [ ] HTML exportado é self-contained (inline styles, zero deps externos)
- [ ] HTML integra com `view.sh` / estrutura do fractal viewer existente

---

## Exportação concreta para view.sh

`view.sh` gera HTML completamente inline — CSS, estrutura e JS embutidos num único `cat` heredoc
que escreve em `/tmp/fractal-view.html`. Não há template externo. Mudanças de design viram
modificações diretas no heredoc do script.

### Workflow de exportação

1. **`get_computed_styles`** nos elementos-chave do artboard — extraia valores exatos de cor,
   espaçamento e tipografia.
2. **`get_jsx`** no componente ou região para capturar a estrutura HTML e os atributos de estilo.
3. Abra `view.sh` e localize o bloco `<style>` — as variáveis CSS ficam em `:root` nas linhas
   ~615–691.

### Tradução para view.sh

| Paper output | O que fazer em view.sh |
|---|---|
| Cores brutas (hex/rgba) | Atualizar variáveis `--color-*` e `--bg-*` no `:root` |
| Espaçamentos (px) | Atualizar variáveis `--spacing-*` ou valores inline nas rules |
| Tipografia (font-size, weight, family) | Atualizar variáveis `--font-*` e rules de `body`, `.node`, etc. |
| Estrutura HTML nova | Reescrever o trecho equivalente no heredoc de `view.sh` |
| Inline styles do JSX | Converter para custom properties se o valor for reutilizado; manter inline só se pontual |

**Regra principal:** Paper usa inline styles; `view.sh` usa CSS custom properties. O export
não é copy-paste — é extração de tokens de design que depois alimentam as variáveis do `:root`.

### O que extrair vs o que adaptar

- **Extrair** — valores concretos: paleta, escala tipográfica, gaps, border-radius, opacidade.
- **Adaptar** — estrutura HTML (simplificar nesting desnecessário do Paper), nomes de classes/IDs
  (manter os que `view.sh` já usa), lógica de JS (não vem do Paper).

### Checklist antes de aplicar

- [ ] Variáveis CSS usam os mesmos nomes já definidos no `:root` de `view.sh`
- [ ] Nenhuma referência externa (fontes, ícones, CDN) foi introduzida
- [ ] `bash view.sh` executa sem erro e abre `/tmp/fractal-view.html`
- [ ] Light mode e dark mode verificados (toggle no viewer ou edição manual da variável `--mode`)
- [ ] HTML resultante é self-contained e legível offline

---

## Integração com o ciclo fractal

**Quando usar:** qualquer predicate leaf que envolva mudanças de UI/UX no viewer.

**Trigger:** durante `/fractal:patch` (mudança pontual) ou `/fractal:delivery` (sprint completo)
quando o deliverable é um arquivo HTML do viewer.

**Output:** arquivo HTML commitado no repo, referenciado no `results.md` do nó ativo.
