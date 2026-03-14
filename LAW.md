# A Lei do Fractal

## A primitiva

Existe uma única operação que governa todo trabalho entre humano e agente:

```
// ponto de entrada
predicado_raiz ← extrair_objetivo(humano)  // pré-condição, não parte da primitiva
fractal(predicado_raiz)

fractal(predicado):
  // esta avaliação É discovery — o agente raciocinando sobre o predicado

  se inatingível(predicado):
    podar(predicado)
    retorna podado

  senão se try_consegue_satisfazer(predicado):
    try(predicado)
    humano valida → satisfeito | fractal(predicado)

  senão se ciclo_consegue_satisfazer(predicado):
    planning(predicado)
    delivery(predicado)
    review(predicado)
    ship(predicado)
    humano valida → satisfeito | fractal(predicado)

  senão:
    // escolhe o sub-predicado que, satisfeito, mais reduz a incerteza
    // sobre como satisfazer o pai — não o mais fácil, nem o mais
    // importante, mas o que mais clarifica o caminho
    filho ← propor sub-predicado
    humano valida proposta:
      se aceita → fractal(filho), depois fractal(predicado)
      se rejeita → fractal(predicado)  // propõe outro filho
```

Essa operação é fractal. Funciona identicamente em qualquer escala — de "criar uma empresa" a "renomear essa variável". Não existem tipos diferentes de planejamento. Existe uma operação, repetida.

A árvore cresce lazy — um filho por vez. Depois de satisfazer um filho, o pai é re-avaliado: talvez já seja satisfazível, talvez precise de outro filho. A re-avaliação decide.

### Mapeamento com o ciclo de execução

- **Discovery** = a própria primitiva. Toda vez que `fractal()` roda, está fazendo discovery: avaliando o predicado, decidindo se é atômico ou precisa subdividir, propondo sub-predicados.
- **Planning → Delivery → Review → Ship** = a unidade atômica de execução para predicados complexos. Satisfaz o predicado.
- **Try** = atalho para predicados triviais demais pro ciclo completo.

Discovery não é uma fase separada — é a recursão em si.

### Extração do objetivo

Pré-condição da primitiva. Antes da primeira chamada `fractal()`, o agente investe energia máxima em:
1. Descobrir o verdadeiro objetivo por trás do pedido (o humano pode não saber o que quer)
2. Antecipar o "cair na real" — quando o humano vai descobrir que queria outra coisa
3. Tornar o objetivo falsificável — condição concreta que prova que foi atingido

Sem objetivo claro, a recursão não tem caso base.

### Validação humana

O humano valida em dois momentos:
- **Proposta:** o agente propõe um predicado, humano confirma que faz sentido e progride na direção correta
- **Resultado:** o agente conclui que satisfez o predicado, humano confirma que foi de fato satisfeito

Rejeição na proposta → agente propõe outro predicado. Rejeição no resultado → agente refaz a execução. Não são casos especiais — são re-avaliações naturais da primitiva.

## Definições

**Predicado:** uma condição falsificável que, quando satisfeita, constitui progresso em direção ao predicado pai. Não é uma tarefa — é uma verdade a ser alcançada. A ação emerge do predicado.

**Árvore de predicados:** a estrutura persistente do projeto. Cada nó é um predicado com: condição falsificável, status (pendente | satisfeito | podado), filhos. A árvore é o plano, o log e o estado — simultaneamente.

**Predicado raiz:** o objetivo extraído do humano. Está na zona útil de abstração — específico o suficiente para rejeitar passos irrelevantes, abstrato o suficiente para sobreviver a mudanças de implementação.

**Predicado atômico:** aquele que um try ou um ciclo (planning → delivery → review → ship) consegue satisfazer diretamente. É o caso base da recursão.

**Nó ativo:** existe sempre um e apenas um predicado sendo trabalhado. Uma sessão nova lê a árvore, encontra o nó ativo, e continua. É o estado completo da sessão.

**Podado:** predicado que o agente reconheceu como inatingível. Permanente naquele nó, mas não mata o pai — força re-avaliação e geração de outro caminho.

## As regras

### 1. O objetivo é o predicado
Não existe plano separado do objetivo. O objetivo raiz é o primeiro predicado. Cada subdivisão gera predicados filhos que herdam o mesmo tipo. A álgebra é fechada.

### 2. Reativo, não contratual
Não existe plano como contrato. Se o objetivo raiz muda, cria-se um novo nó raiz na árvore. A árvore anterior persiste como histórico, mas a recursão recomeça do novo raiz. Nada se perde, e a profundidade se corrige.

### 3. Um nó ativo
Existe sempre um e apenas um predicado sendo trabalhado. Delegação muda o executor do nó, não cria nós paralelos. Paralelismo é otimização interna do ciclo de execução.

### 4. Delegação por capacidade
O predicado determina o executor. Predicados abstratos → modelo mais capaz. Predicados atômicos → modelo mais barato. "Quem consegue satisfazer este predicado?" é o único critério.

## A janela de abstração

Todo predicado — incluindo o raiz — deve estar na zona de máximo poder de discriminação:

```
Muito abstrato:  "ser feliz"                    → aceita tudo, não discrimina
Zona útil:       "app de ciclofaixas em SP"      → rejeita irrelevantes, sobrevive a mudanças
Muito concreto:  "PWA com Mapbox + API da CET"   → plano rígido disfarçado de objetivo
```

Um predicado na zona útil é aquele que, se toda a stack mudar, ainda faz sentido.
