# haskell-linear-qlearning-pricing

[English](#english) | [Português](#português)

---

## English

Linear Q-Learning in Haskell: an agent that learns dynamic ticket pricing for an airline (revenue management).

Final project for **Paradigms and Emerging Technologies in Data Science** (topic 2.1, Linear Q-Learning), Data Science program at Fatec Baixada Santista.

- **Professor:** Felipe Cannarozzo
- **Team:** Adam Stader, Guilherme Franco, Lucas Laus and Victor Leme

### Scenario

An airline has 100 seats to sell over 30 days before takeoff. Seats left empty at takeoff are worth nothing. Every day the agent chooses a price, passengers buy according to demand and price elasticity, and the reward is the revenue of that day.

- **State (s):** share of seats still available, share of time left until the flight and a recent demand index. All continuous, so a table with one row per state is not feasible.
- **Actions (a):** three prices, promotional (R$ 300), standard (R$ 550) and premium (R$ 900).
- **Reward (r):** daily revenue, price times seats sold.

### Idea

Instead of a Q-table with one entry per state and action, Q(s, a) is approximated linearly:

```
Q(s, a) = w . phi(s, a)
```

where `phi(s, a)` is a feature vector (here, 5 features per action, 15 in total) and `w` is a weight vector updated at each step with the semi-gradient rule:

```
delta = r + gamma * max_a' Q(s', a') - Q(s, a)
w     = w + alpha * delta * phi(s, a)
```

`alpha` is the learning rate and `gamma` is the discount factor. Actions are chosen with an epsilon-greedy policy.

### Structure

```
app/
  Main.hs           Training loop, evaluation and report
src/
  Types.hs          Actions, state and hyperparameters
  Environment.hs    Stochastic flight simulator (demand and price elasticity)
  Features.hs       Feature vector phi(s, a) and vector operations
  Agent.hs          Q prediction, epsilon-greedy policy and weight update
  Metrics.hs        Averages, block summaries, CSV export and weights report
data/               Example data used in the demo
docs/               Logo, slides and notes
```

### Running

Requires GHC and Cabal.

```
cabal build
cabal run linear-q-pricing
```

### Status

Work in progress. Modules are being added by each team member.

---

## Português

Linear Q-Learning em Haskell: um agente que aprende a precificação dinâmica de passagens aéreas (revenue management).

Projeto final da disciplina **Paradigmas e Tecnologias Emergentes em Ciência de Dados** (tema 2.1, Linear Q-Learning), curso de Ciência de Dados da Fatec Baixada Santista.

- **Professor:** Felipe Cannarozzo
- **Equipe:** Adam Stader, Guilherme Franco, Lucas Laus e Victor Leme

### Cenário

Uma companhia aérea tem 100 assentos para vender em 30 dias antes da decolagem. Assento vazio na decolagem não vale nada. A cada dia o agente escolhe um preço, os passageiros compram conforme a demanda e a elasticidade ao preço, e a recompensa é a receita daquele dia.

- **Estado (s):** percentual de assentos ainda disponíveis, fração do tempo restante até o voo e um índice de demanda recente. Todos contínuos, então uma tabela com uma linha por estado é inviável.
- **Ações (a):** três preços, promocional (R$ 300), padrão (R$ 550) e premium (R$ 900).
- **Recompensa (r):** receita diária, preço vezes assentos vendidos.

### Ideia

Em vez de uma tabela Q com uma entrada por estado e ação, Q(s, a) é aproximada de forma linear:

```
Q(s, a) = w . phi(s, a)
```

em que `phi(s, a)` é um vetor de características (aqui, 5 por ação, 15 no total) e `w` é um vetor de pesos atualizado a cada passo com a regra semi-gradiente:

```
delta = r + gamma * max_a' Q(s', a') - Q(s, a)
w     = w + alpha * delta * phi(s, a)
```

`alpha` é a taxa de aprendizado e `gamma` é o fator de desconto. As ações são escolhidas com uma política epsilon-greedy.

### Estrutura

```
app/
  Main.hs           Laço de treinamento, avaliação e relatório
src/
  Types.hs          Ações, estado e hiperparâmetros
  Environment.hs    Simulador estocástico do voo (demanda e elasticidade ao preço)
  Features.hs       Vetor de características phi(s, a) e operações vetoriais
  Agent.hs          Predição de Q, política epsilon-greedy e atualização dos pesos
  Metrics.hs        Médias, resumo por blocos, exportação de CSV e relatório dos pesos
data/               Dados de exemplo usados na demonstração
docs/               Logo, slides e anotações
```

### Execução

Requer GHC e Cabal.

```
cabal build
cabal run linear-q-pricing
```

### Status

Em desenvolvimento. Os módulos estão sendo adicionados por cada integrante.
