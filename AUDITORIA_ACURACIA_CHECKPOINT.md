# Auditoria de acurácia — estado, diretrizes e fila de trabalho

Documento único de continuidade da branch `fix/auditoria-acuracia-independente`.
Escrito para que uma sessão nova continue **sem depender de histórico de chat**.

- **Parte I** — reconstrução forense da auditoria de 2026-09-06, interrompida por limite de sessão
- **Parte II** — o que a sessão de 2026-09-07 fez
- **Parte III** — o que foi **refutado** e deliberadamente não virou código
- **Parte IV** — fila de trabalho, priorizada, com a medição já feita
- **Parte V** — diretrizes de método
- **Parte VI** — sessão de 2026-09-08: a consultoria externa e o que ela mudou

Marcas usadas na Parte I: **[A]** recuperado de artefato ou do Git · **[B]** inferido ·
**[C]** perdido. Memória de extensão e arquivos `memory/` **não** foram usados como prova.

---

## Estado atual, em um quadro

| | |
|---|---|
| Branch | `fix/auditoria-acuracia-independente`, **10 commits** à frente de `main`, **não publicada** |
| Suíte dbt | **PASS=138 · WARN=6 · ERROR=0** de 144 (era 95/2/97 antes da auditoria) |
| Conjunto dourado | 235 fichas · **189 TRAVA** · 27 DEFEITO_ABERTO · 19 DIVERGENCIA_FONTE |
| Âncora WEG 2023 | receita 3,25036e10 · lucro 5,86762e9 · controladores 5,73167e9 · margem 0,17634 · IDENTIDADE_OK |
| `fct_fundamentos` | 8.563.240 linhas · `mart_fundamentos_anuais` 10.847 fichas |

Os 6 WARN são conhecidos e intencionais — cada um é um defeito da **fonte** mantido visível e
sob contagem, não um teste quebrado:

| WARN | n | O que conta |
|---|---|---|
| `assert_escala_sem_contradicao` | 8.325 | contradição de etiqueta de escala na fonte (61 empresas, 83 fichas do mart) |
| `assert_dedup_sem_divergencia` | 127 | mesma chave com dois valores, em quarentena |
| `roe_is_null_or_abs_roe_100` | 20 | ROE fora de faixa plausível |
| `not_null mart ativo_total` | 3 | descrição corrompida na fonte |
| `not_null stg_dre ds_conta` | 2 | idem |
| `margem_liquida_0_and_lucro_liquido_0` | 1 | resíduo do defeito de atribuição |

---

# Parte I — Reconstrução forense (auditoria de 2026-09-06)

## Objetivo e escopo originais **[A]**

De `BRIEFING.md`, o documento que todos os agentes liam. Auditar a acurácia da camada de
tratamento — `data/raw/dfp/` → staging → `int_dfp_unificado` → `fct_fundamentos` →
`mart_fundamentos_anuais` → `mart_empresa_visao`, mais o seed. **Só DFP; ITR fora.**

Regras impostas: nunca escrever no warehouse, nunca rodar `dbt build`, nunca editar o repo.
Método: medir antes de afirmar, com o SQL exato; nunca aceitar cobertura agregada sem quebra
por coorte; publicar o denominador; dizer "não medido" em vez de estimar; ausência é NULL,
nunca zero; desempate arbitrário não é regra contábil.

## Execução **[A]**

Quatro workflows, **476 agentes**, **8,52 M de tokens**, **2.992 chamadas de ferramenta**,
todos em `claude-opus-5[1m]`.

| Workflow | Propósito | Agentes | `done` | `error` |
|---|---|---|---|---|
| `wgph1wlue` | Auditoria em 15 dimensões (1ª) | 155 | 10 | 145 |
| `wqsbsu2o0` | Conferência externa (1ª) | 64 | 17 | 47 |
| `wsz5ipw8a` | Auditoria em 15 dimensões (relançada) | 161 | 13 | 148 |
| `wm24zdfk9` | Conferência externa (relançada) | 96 | 36 | 60 |

Os 400 `error` têm a mesma causa — limite de sessão, com `tokens: 0` e `toolCalls: 0`. Não
são falhas de análise: os agentes nunca rodaram. A fase **Refutar** foi a mais destruída: de
~130 refutadores por rodada, **3 rodaram**.

Dimensões medidas: escala, dedup, seed-cobertura, seed-variantes, ambiguidade-pivot,
null-vs-zero, politica-con-ind, grao-periodo, sinais, ingestion, bitemporal — **11 de 15**.
Nunca medidas **[C]**: `outliers`, `fantasmas`, `warns-e-testes`, `identidades`.

Conferência externa: **36 de 59 empresas**. As 23 restantes **[C]**: V.Tal, MRS, Grupo SOMA,
CSN Mineração, Telemar (2), Cobrasma, Contax, Cyrela, Claro, ZAMP, Natura, Economatica,
Camil, Bradsaúde, Automob, Rio Alto, Revee, Sendas e outras.

## Achados **[A]**

O objeto `result` sobreviveu nos quatro `.output`. **83 achados** na rodada mais completa,
cada um com `sql`, `numero`, `alcance`, `camada`, `severidade`, `exemplo` e
`correcao_proposta`.

| Veredito | Qtd | | Severidade | Qtd | | Camada | Qtd |
|---|---|---|---|---|---|---|---|
| CONFIRMADO | 72 | | alta | 37 | | marts | 38 |
| REFUTADO | 1 | | média | 36 | | seed | 13 |
| não verificado | 10 | | baixa | 10 | | staging | 10 |
| | | | | | | intermediate | 9 |
| | | | | | | ingestion | 7 |
| | | | | | | testes | 3 |

**Fragilidade central [A]:** 62 dos 72 CONFIRMADOS têm `refutacoes: []` — o carimbo veio do
próprio agente que mediu. A arquitetura previa verificação adversarial e ela não aconteceu.
O único REFUTADO caiu porque **já tinha sido corrigido** no meio da execução (o auditor media
um warehouse anterior), não por mérito.

## O que se perdeu **[C]**

A síntese final (nenhum relatório consolidado foi escrito), a fase de refutação, quatro
dimensões, 23 empresas, as fichas do conjunto dourado (existiam como intenção, nunca como
arquivo) e a ordem de prioridade que o orquestrador teria dado aos 72 achados — os 4 commits
atacaram 4 deles e não há artefato dizendo por quê **[B]**.

Sobreviveram **862 arquivos** de scratchpad (695 `.sql`) com as consultas de cada medição,
em `…\Temp\claude\c--Users-jv-av-projects-cvm-valuation\71777617-…\scratchpad`, enquanto o
diretório existir.

## Correções da auditoria **[A]** — 4 commits, 2026-09-06

| Commit | O que fez | Antes → depois |
|---|---|---|
| `66aa5d2` | Escala num macro, LPA excluído | 63.018 linhas com fator 1000 indevido → 0. WEG `3.99.01.01`: 1366,08 → **R$ 1,36608** |
| `87f0088` | Grão natural da linha da CVM, contradição quarentenada | `fct` 8.563.118 → **8.563.240** (122 recuperadas). BRADSAUDE 2023 EBIT 0 → **R$ 646,1 mi**; AUTOMOB 2023 −177,6 mi → **+89,4 mi** |
| `b29c720` | PL dos planos bancários 2.05 e 2.07 no seed | Cobertura de PL em financeiras **39,4% → 100%**. BB 2024 ROE **14,67%**, Bradesco **10,24%**, Santander **11,19%** |
| `4ee3d69` | Controladores pela identidade contábil | Margens zero com lucro não nulo **390 → 1**; ROEs zerados **419 → 3**. SABESP 2024 0% → **26,50%**; AZUL 2024 +47,07% → **−46,87%** |

---

# Parte II — Sessão de 2026-09-07

## `a12d710` — conjunto dourado externo e a trava que faltava

**O buraco:** as conferências externas viviam só na saída temporária dos agentes. As quatro
correções não tinham nada que impedisse regressão.

233 fichas recuperadas dos artefatos, 36 empresas, 2011–2025, 5 indicadores. Fontes: 118
relatório anual / 20-F / demonstração auditada, 57 agregador, 55 release, 6 notícia —
**predominam fontes primárias**.

Cada ficha foi **reconferida contra o mart atual** antes de virar seed, e classificada:

| Status | Qtd | O que significa |
|---|---|---|
| `TRAVA` | 188 | o mart tem de bater; é o que reprova |
| `DEFEITO_ABERTO` | 27 | divergência confirmada, ainda não corrigida, causa medida em `observacao` |
| `DIVERGENCIA_FONTE` | 18 | o mart está certo e a fonte mede outra coisa |

As 18 `DIVERGENCIA_FONTE` não são defeito: IFRS contra BRGAAP/COSIF (BTG, PAN, ABC, Daycoval,
BB 2012), safra reapresentada (VALE 2011 — a fonte usa a reapresentação, o mart publica a
original por política) e número gerencial (Santander 2024, manchete de release). Ficam
registradas com a causa **para não serem reinvestigadas**.

**O teste foi conferido contra vacuidade** — `assert_dedup_sem_divergencia` já foi vácuo, e
por isso este não podia sê-lo. Rodando a mesma lógica sem o filtro de status, as 46 linhas
não-TRAVA são **todas** detectadas (27 `VALOR_NULO`, 19 `FORA_DA_TOLERANCIA`). O build só
fica verde porque o filtro é explícito.

Tolerância **relativa**, padrão 0,1%; cinco linhas usam 0,5% e cada uma nomeia na
`observacao` a fonte que publica arredondado.

## `0e46327` — desempate do bloco de atribuição pela identidade

**Achado novo, fora dos 83.** Dois blocos da DRE podem ter o mesmo total sem medirem a mesma
coisa. BANRISUL 2024 declara `3.09` "Lucro antes das Participações e Contribuições
Estatutárias" = R$ 727,798 mi com `.01` e `.02` zerados, e `3.11` "Lucro Líquido Consolidado"
= os **mesmos** R$ 727,798 mi com `.01` = R$ 727,253 mi e `.02` = R$ 545 mil. Os dois casavam,
`n_blocos` ia a 2, e a ficha caía em `CONFLITO_FONTE` — suprimindo um valor correto,
confirmado por fonte externa (R$ 727,250 mi).

A regra passa a ser: fica o bloco cuja **identidade contábil fecha**. Nenhum ou mais de um
fechando, todos permanecem e a ficha segue em conflito — a ambiguidade real continua recusada.

**Resultado medido:** `CONFLITO_FONTE` 110 → 103, `IDENTIDADE_OK` 5.787 → 5.794. São **7
fichas recuperadas, não 8** — a previsão errou por uma. A oitava, FINANCEIRA ALFA 2023,
continua em conflito e **está certa em continuar**: o bloco que fecha é o `3.09`
(controladores R$ 18,578 mi), mas o seed elege `3.11.01`, que a fonte preencheu com zero.

Isso expõe um defeito estrutural próprio, registrado na fila (item 3): **o valor publicado
vem do pivot do seed enquanto a identidade é conferida no bloco** — duas fontes para o mesmo
fato. Não se conserta desempatando.

BANRISUL 2020/2022/2023/2024 e BCO ALFA 2023 passam a publicar controladores e ROE.
BANRISUL 2024 foi promovido de `DEFEITO_ABERTO` a `TRAVA`.

## `be20b4a` — bloco financeiro exposto

O seed mapeava `fin_receita_intermediacao`, `fin_despesa_intermediacao`,
`fin_resultado_intermediacao` e `fin_receita_seguros` desde sempre, e o pivot **nunca os
projetava**: serviam só para calcular `flag_financeira`. As 620 fichas de financeira saíam
com **0,0% de cobertura de receita** com o dado intacto no fato. Depois: **619 de 620 (99,8%)**.

São projeções fiéis, com nome próprio, que **não** alimentam `receita_liquida`, margens nem
`giro_ativo` — ver Parte III, onde a proposta de unificação foi refutada. Um teste novo,
`not (flag_financeira and receita_liquida is not null)`, fixa a decisão contra uma expansão
futura do seed que a quebre em silêncio.

Documentado no modelo: `fin_despesa_intermediacao` vem **negativa em 552 de 614** linhas e
**positiva em 7** (BANCO MODAL 2020, CCB BRASIL 2015/16/18/19/20, BANCO BERJ 2011). A
identidade que fecha é `3.01 + 3.02 = 3.03`, em 611 de 613; a subtração fecha em 53.
**Some, não subtraia.**

## `33d14a4` — contradição de escala da fonte, agora auditável

`ESCALA_MOEDA` não é confiável e **nenhum teste do projeto conseguia vê-lo**: a identidade
contábil é invariante a multiplicação, então `assert_identidade_contabil` passa verde com o
número 1000x errado.

`escala_moeda` sobe dos cinco stagings até o fato — sem a coluna o defeito **não é escrevível
fora do raw**, e um teste que lesse `source()` direto furaria a camada. No agregado do
staging o `max()` lê uma constante e não escolhe entre alternativas: a escala é atributo do
documento, uniforme dentro dele, e o grão é mais fino que o documento.

O teste compara a linha `ÚLTIMO` do documento N com a linha `PENÚLTIMO` do documento seguinte
para o mesmo período, reconstrói o `VL_CONTA` bruto dividindo pela escala aplicada e compara
por **igualdade**. Nenhum limiar. Se o número que a CVM escreveu é o mesmo e a etiqueta mudou,
a fonte se contradisse — não há o que calibrar. E ele aponta **qual exercício** está sob
suspeita, coisa que uma razão entre anos não faz.

**Medido:** 8.325 linhas, **61 empresas**, **83 fichas do mart** (0,77% de 10.847), 2010–2024.
Por demonstrativo: BPP 2.930 · BPA 1.947 · DFC_MI 1.766 · DRE 1.622 · DFC_MD 60. ELDORADO é
pega em 2011, 2019 e 2020.

`warn`, não `error`, pela mesma razão de `assert_dedup_sem_divergencia`: o defeito é da fonte
e ainda não existe regra que decida qual etiqueta é a correta. **Nenhum número publicado
muda.**

---

# Parte III — Refutado, e por isso não virou código

Três propostas foram submetidas a refutação adversarial **antes** de virarem código. Duas
caíram. Este registro existe para que não sejam reabertas sem novo argumento.

## Refutada: `receita_operacional` unificada para bancos

**Proposta:** `receita_operacional = coalesce(receita_liquida, fin_receita_intermediacao,
fin_receita_seguros)` com uma coluna `origem_receita`.

**Por que caiu — a conta escolhida é a errada.** Conferido contra seis âncoras externas, a
DRE `3.01` reproduz **uma** (Banco PAN 2023):

| Empresa | Ano | Fonte externa | `3.01` publicaria | `3.03` | Bate com |
|---|---|---|---|---|---|
| Itaú Unibanco | 2024 | 168,05 bi | **335,328 bi** | 135,739 bi | nenhuma |
| Banco do Brasil | 2024 | 104,51 bi | 273,505 bi | **104,514 bi** | `3.03` |
| Bradesco | 2024 | 78,885 bi | 213,220 bi | 68,941 bi | nenhuma |
| Santander | 2024 | 47,185 bi | 137,183 bi | 56,679 bi | nenhuma |
| ABC Brasil | 2023 | 5,441 bi | 5,972 bi (CON) | 1,344 bi | `3.01` **INDIVIDUAL** |
| Banco PAN | 2023 | 15,308 bi | **15,308 bi** | 7,961 bi | `3.01` ✓ |

As seis âncoras usam **ao menos três definições diferentes** de "receita de banco". A premissa
"a conferência externa confirmou que o dado existe" é falsa como enunciada: confirmou que
*algum* número existe, não que é o `3.01`.

Três razões independentes reforçam: a definição não é comparável em corte transversal (giro
do ativo mediano **0,1206** na coorte financeira contra **0,3866** na não-financeira,
diferença puramente definicional); o invariante `not (flag_financeira and margem_liquida is
not null)` reprovaria **584 fichas**; e `flag_financeira` é circular — BB SEGURIDADE publica
`3.01 'Receitas das Operações'` (não mapeada) de 2012 a 2022 e `'Receitas das Atividades
Seguradoras/Resseguradoras'` (mapeada) de 2023 a 2025. **O negócio não mudou; a redação da
CVM mudou.** A série sairia NULL × 11 anos → 0,00 × 3 anos, para uma empresa com R$ 8,70 bi
de lucro. Restariam **43 fichas de 13 empresas** sem receita alguma, hoje uniformemente NULL
— honesto; depois, intermitente, que é pior para qualquer série ou CAGR.

## Refutada: derivar `lucro_liquido_controladores` quando `pl_minoritarios = 0`

**Proposta:** publicar `lucro_liquido_controladores = lucro_liquido` nas 384 fichas com
`status = 'SPLIT_NAO_INFORMADO'` e `pl_minoritarios = 0`.

**Por que caiu.** O zero do BPP é uma testemunha **sem contraditório** — não há identidade no
balanço que a valide. Mas dá para medir sua confiabilidade no conjunto **rotulado**: fichas
`IDENTIDADE_OK` com `pl_minoritarios = 0`, onde a resposta é conhecida.

**Medido, e reproduzido de forma independente:** **123 de 2.136 (5,76%)** falsificam a regra.
Restrito a 2021–2025, 30 de 540 — a mesma taxa; "dado velho" não salva. Erro mediano quando
falha: **4,35%** do lucro; p90 **64,25%**; máximo 156%.

**Prova de ficha única — CTEEP 2010, CONSOLIDADO, conferida no `fct_fundamentos`:**

| Demonstrativo | Conta | Valor |
|---|---|---|
| BPP | `2.03.09` Participação dos Acionistas Não Controladores | **0** |
| DRE | `3.11` Lucro/Prejuízo Consolidado | 812.171.000 |
| DRE | `3.11.01` Atribuído a Sócios da Empresa Controladora | 305.376.000 |
| DRE | `3.11.02` Atribuído a Sócios Não Controladores | **506.795.000** |

62,4% do lucro foi para não controladores enquanto o BPP declarava zero, com a identidade da
DRE fechando exatamente. A premissa da proposta é **demonstrável e materialmente falsa**.

**O argumento que encerra:** as 384 fichas **já** têm `lucro_atribuivel = lucro_liquido`, e
margem e ROE **já** são idênticos ao que a proposta produziria. O ganho em indicadores é
**exatamente zero**. A proposta trocaria um NULL auditável por uma afirmação não verificada
na coluna que o usuário lê direto — risco sem contrapartida. Publicando as 384, esperam-se
**~24 fichas erradas**; num estrato restrito de 191 (série limpa + testemunha positiva),
~1,3 — ainda assim, por zero benefício.

A validação externa que motivou a proposta cobriu 7 de 384 (**1,8%**) e todos os 7 caem no
estrato fácil. Confirmou a metade fácil, não o universo.

## Refutada e substituída: teste de degrau de escala por faixa de razão

**Proposta:** reprovar quando `greatest(ativo/prev, prev/ativo)` fica entre 200 e 5000 para
exercícios consecutivos **e** houve troca de `ESCALA_MOEDA`.

**Números que reproduziram:** 119 degraus na faixa, 80 com troca de escala em 57 empresas,
e o caso ELDORADO. **Que não reproduziram:** 125 transições → **128**; e o "119 degraus
totais" é falso por construção — são 162 pares com razão ≥200 mais 46 com zero de um lado,
total 208. Os "39 legítimos" eram apenas o complemento, e **não são legítimos**.

**Por que caiu:**

- **A faixa é desempate arbitrário** (AGENTS.md §5). O histograma das 9.621 razões não tem
  vale: a massa é contínua de 5x a 1e6. Entre os 80 casos, o mínimo é **435** e o máximo
  **4431** — nenhum encosta em 200 nem em 5000, então os dois cortes **não separam nada** nos
  verdadeiros positivos; só regulam quanto da cauda benigna entra.
- **Falsos positivos confirmados** pela reafirmação da própria fonte: B100 (027634) 2025 e
  NOVA SOCIEDADE DE NAVEGAÇÃO (027081) 2023 são degraus **econômicos reais** em que a troca de
  escala é consequência legítima da mudança de tamanho.
- **Falsos negativos:** ENCALSO (023701) 2015→2016 tem razão 1010,7 **sem** troca de etiqueta
  e é defeito real — ou seja, o balde dos "39 legítimos" contém defeitos. IGB ELETRONICA
  (006815) 2010 tem razão 5950 e escapa pelo teto. Seis dos oitenta escapavam.
- **Bloqueador estrutural não previsto:** `escala_moeda` não existia em model nenhum
  (`information_schema` → 0 colunas). O predicado não era escrevível sem mudar os models.
- Cobria só `ativo_total` e só exercícios consecutivos; 82 empresas têm um único exercício no
  mart e nunca seriam testadas.

O desenho substituto — contradição interna da fonte, sem limiar — foi o implementado
(`33d14a4`).

## Sobrevivida: projetar as colunas `fin_*` (implementada em `be20b4a`)

Resistiu a todos os ataques: **0** fichas têm `receita_liquida` e `fin_receita`
simultaneamente; **0** chaves do seed mapeiam dois conceitos; **0** grupos ambíguos novos no
pivot. O `coalesce` nunca escolheria hoje — mas a coluna unificada caiu pelas razões acima,
e só a projeção fiel foi implementada.

---

# Parte IV — Fila de trabalho

Ordenada por dano publicado, com a medição já feita. Cada item é executável sem reabrir
investigação.

### 1. `pl_minoritarios = 0` falso derruba o ROE de 93 fichas — **defeito vivo, medido hoje**

Descoberto pela refutação acima, **não está entre os 83 achados**. Como
`patrimonio_liquido_controladores = patrimonio_liquido − coalesce(pl_minoritarios, 0)`, um
zero falso publica um denominador errado. Medido em 2026-09-07:

> **93 fichas / 75 empresas** com `tipo_df='CONSOLIDADO'`, `pl_minoritarios = 0`, `roe` não
> nulo, `status = 'IDENTIDADE_OK'` e a DRE provando minoritários materiais
> (`|lucro_liquido − lucro_liquido_controladores| > max(1000, 0,1% do lucro)`).

Tratamento sugerido, no mesmo padrão de `status_lucro_controladores`: uma coluna
`status_pl_controladores` e `patrimonio_liquido_controladores` NULL quando a DRE contradiz o
balanço — nunca arbitrar. **Precisa de rodada de refutação própria antes de virar código**, e
muda 93 ROEs publicados: é decisão de produto, não só de modelagem.

### 2. Quarentenar o valor com escala contraditada — instrumentado, falta a correção

O defeito está agora **medido e sob contagem** por `assert_escala_sem_contradicao`
(`33d14a4`): **8.325 linhas, 61 empresas, 83 fichas do mart**. O que falta é a correção a
montante, que o teste deliberadamente não faz.

Caminho definido: `status_valor = 'ESCALA_CONTRADITA'` com `valor` NULL no staging, coerente
com a regra do repositório de que valor contraditório vira ausência e nunca desempate — o
mesmo padrão de `CONFLITO_FONTE`.

**Decisão que falta e que o dado sozinho não resolve:** o teste prova que a fonte se
contradiz, mas **não diz qual das duas etiquetas é a correta**. ENCALSO 2015 é o caso em que
a *reafirmação* é que está errada. Resolver exige uma regra externa — coerência com a série
da própria empresa, ou plausibilidade contábil (ativo de companhia aberta abaixo de R$ 1
milhão é impossível). Escolher a etiqueta modal da empresa seria um desempate disfarçado e
está fora da doutrina.

Enquanto a regra não existir, o `warn` é a resposta certa: 83 fichas ficam visíveis e
contadas em vez de invisíveis e publicadas.

### 3. Duas fontes de verdade para o lucro dos controladores

O valor publicado vem do **pivot do seed**; a identidade que o valida vem do **bloco da DRE**.
Quando discordam, a ficha cai em conflito mesmo havendo um bloco íntegro — FINANCEIRA ALFA
2023 é o caso concreto (Parte II). É o defeito P6 do projeto, dentro do próprio mart.

### 4. Os 27 `DEFEITO_ABERTO` do conjunto dourado

Já estão versionados com causa medida. Por motivo:

| Motivo | Fichas | Empresas |
|---|---|---|
| `cobertura_receita_financeira` | 14 | 11 |
| `split_nao_informado` | 7 | 5 |
| `split_nao_informado_com_minoritarios` | 2 | 2 |
| `sinal_invertido_na_fonte` (AZUL 2023/2024) | 2 | 1 |
| `base_individual_sem_consolidado` | 1 | 1 |
| `conta_3_01_traz_receita_bruta` (ELETROBRAS 2011) | 1 | 1 |

Os 14 de receita financeira dependem do item 5. Os 7 de `split_nao_informado` foram
**deliberadamente deixados abertos** (Parte III) e não devem ser "corrigidos" sem argumento
novo.

### 5. Decidir `3.01` contra `3.03` para receita de banco

Rodada de `validar-externo` com **≥10 bancos**, fonte e data de referência declaradas. Sem
isso não existe coluna de receita para a coorte financeira. Mapear também
`DRE 3.01 'Receitas das Operações'` (plano SEGURADORA) via `expandir-seed` — hoje deixa 43
fichas de 13 empresas sem receita alguma, entre elas BB SEGURIDADE de 2012 a 2022.

### 6. Refutar os achados altos que nunca foram contestados

62 dos 72 CONFIRMADOS nunca passaram por refutação. **Nesta sessão as 3 propostas submetidas
foram todas derrubadas** — duas abandonadas, uma redesenhada. A taxa não é desprezível e o
custo de agir sem refutar é publicar número errado. Priorize os 37 de severidade alta, e
refute **antes** de corrigir, nunca depois.

### 7. Cobertura que ficou faltando

Quatro dimensões nunca medidas (`outliers`, `fantasmas`, `warns-e-testes`, `identidades`) e
23 empresas sem conferência externa. Ampliar o conjunto dourado por aí.

### 8. `guias/` continua fora do clone

`guias/` está no `.gitignore` (linha 19): `NORTE.md` e `GUIA_04_ESPINHA_COMUM.md` existem em
disco e **não acompanham o clone**. Foi por isso que este documento ficou na raiz.

Resolução sugerida, ainda não executada: versionar `NORTE.md`, `GUIA_04_ESPINHA_COMUM.md`,
`DICIONARIO_CONTAS.md` e `GUIA_GIT_GITHUB.md`; mover o legado (`HANDOFF.md`,
`REVISAO_FINAL.md`, `ANALISE_DIDATICA_PROJETO.md`, o `.docx`) para `guias/_archive/` e
ignorar só essa subpasta.

`AGENTS.md`, `CLAUDE.md` e `.claude/` foram commitados em 2026-09-07, cumprindo o que o
próprio `.gitignore` já declarava.


---

# Parte VI — Sessão de 2026-09-08: a consultoria externa

Entrou `guias/analise_classificacao_contas_cvm_2026-09-08.md`, consultoria independente sobre
**classificação de contas e resolução de grão**, com acesso somente-leitura ao código e ao
warehouse no commit `1c0a843`.

## O que foi conferido, e o resultado

Todas as afirmações numéricas do documento foram remedidas antes de qualquer aceitação.
**Todas reproduziram exatamente.**

| Afirmação | Resultado |
|---|---|
| 8.563.240 linhas · 1.223 empresas em `int_dfp_unificado` | reproduz |
| Fixas 6.259.757 linhas / 1.025 triplas · livres 2.303.483 / 121.090 | reproduz |
| Seed 70 entradas / 35 conceitos · 43 PADRAO, 19 FINANCEIRO, 1 SEGURADORA, 4 LEGADO, 3 DESLOCADO | reproduz |
| 955 de 1.025 triplas fixas sem conceito · alcance 192 / 245 / 518 | reproduz |
| Pivot: 316.757 grupos, 29 multilinhas, 8 com valores distintos, 16 do `026239` | reproduz |
| 5.043 fichas usam lucro consolidado por ausência do dos controladores; 3.544 margens, 85 em `CONFLITO_FONTE` | reproduz |
| Conjunto dourado 188/27/18 enquanto o comentário do teste dizia 187/28/18 | reproduz — comentário velho |
| Banrisul 2024: a referência de `lucro_liquido` é, por definição, a parcela dos controladores | reproduz — 1 de 31 |
| `AGENTS.md` chama R$ 5,87 bi de "lucro dos controladores" | reproduz — é o consolidado |
| **Financeira Alfa 2023: o valor certo existe no fato e o mart publica NULL** | **reproduz** |

**Nada foi refutado.** Duas precisões acrescentadas por medição própria:

- O merge de dois períodos em `026239/2023` é real, mas os valores das duas linhas são
  **idênticos**: o impacto numérico hoje é **zero**. É lacuna de contrato, não erro publicado.
  Alcance: **1 ficha, 1 empresa** em todo o mart.
- A crítica ao veto por `pl_minoritarios = 0` procede em tese (estoque de encerramento contra
  fluxo anual). Medido: **10 fichas / 8 empresas, todas com zero EFETIVAMENTE REPORTADO** e
  nenhuma com o PL de minoritários nulo. O `coalesce(pl_minoritarios, 0) = 0` do código era
  latentemente errado — trataria ausência como zero — e foi estreitado para `= 0` explícito.

## O defeito estrutural, confirmado e corrigido

O pivot do seed e a resolução por bloco eram **dois caminhos para o mesmo fato**, e o modelo
usava um para decidir e o outro para publicar: `candidatos`/`preferidos`/`atribuicao`
identificavam o bloco íntegro e a escada de status voltava a ler
`p.lucro_liquido_controladores`. Quando discordavam, o valor resolvido era **calculado e
descartado**.

FINANCEIRA ALFA 2023: o bloco `3.09` traz 18.578.000 + 4.466.000 = 23.044.000, identidade
fechando exatamente; o seed elege `3.11.01`, que a fonte preencheu com zero, porque a descrição
de `3.09.01` tem **NBSP (U+00A0)** nas pontas e não casa com a chave. O mart publicava NULL.

**Confirmação em fonte primária**, obtida nesta sessão e não herdada da consultoria: *Proposta
da Administração*, fevereiro de 2024, **página 3 de 70**, seção "II Demonstrações Financeiras
Segundo os Padrões Internacionais (IFRS)" — *"as demonstrações financeiras consolidadas da
Sociedade ... O lucro líquido foi de R$ 23,0 milhões"*. A seção I, padrões do Banco Central,
traz **R$ 18,4 milhões** para a base individual: dois números diferentes no mesmo documento.
Uma busca web devolveu −4.290 / 14.493 / 10.203 mil para "Financeira Alfa 2023", que **não
confere com nenhuma das duas seções**, e foi descartada.

## Três formas de zero de formulário, agora separadas

A correção expôs que o zero de formulário aparece em lugares distintos, cada um precisando de
testemunha própria:

| Forma | Assinatura | Testemunha | Alcance medido |
|---|---|---|---|
| Filho zerado | `3.x.01` e `3.x.02` = 0 com pai != 0 | identidade do bloco | 421 fichas / 167 empresas |
| Bloco irmão | pai eleito = 0 havendo bloco irmão != 0 **na mesma base** | `maior_total_bloco` | 2 fichas (BCO ALFA 2021/2022) |
| Pai em branco | pai = 0 com filhos somando != 0 | `maior_soma_filhos` | 3 blocos / 3 fichas / 2 empresas |
| Base inteira | base eleita com lucro, receita e ativo = 0 e a outra com número | `base_degenerada` | **7 fichas / 4 empresas** |

## Estados de `status_lucro_controladores`

| Estado | Antes | Depois |
|---|---:|---:|
| `IDENTIDADE_OK` | 5.794 | 5.786 |
| `SEM_SPLIT` | 4.529 | 4.529 |
| `SPLIT_NAO_INFORMADO` | 421 | 421 |
| `CONFLITO_FONTE` | 103 | 94 |
| `CONTRADICAO_DRE_BPP` | — | 10 |
| `BASE_DEGENERADA` | — | 7 |

Build final **PASS=138 · WARN=6 · ERROR=0** de 144, idêntico à linha de base. Âncora WEG 2023
reproduz: receita 3,25036e10 · consolidado 5,86762e9 · controladores 5,73167e9 · margem 0,17634.

## O achado desta sessão que nenhum dos dois documentos tinha: TIM 2024 e 2025

**`TIM S.A.` publica `receita_liquida = 0` e `lucro_liquido = 0` em 2024 e 2025.** A base
CONSOLIDADO vem inteiramente zerada na fonte enquanto a INDIVIDUAL traz R$ 25,4 bi e R$ 26,6 bi
de receita e R$ 3,15 bi e R$ 4,31 bi de lucro. A política `int_empresas_tipo_df` elege
CONSOLIDADO porque linhas consolidadas *existem* — mas todas valem zero.

Alcance exato: **7 fichas / 4 empresas** de 6.235 que publicam as duas bases — TIM 2024/2025,
RIO PARANAPANEMA 2024/2025, CLI SUL 2025, CELGPAR 2022/2023.

Esta sessão **não corrigiu** o defeito: trocar a base eleita altera a política declarada, o
invariante `not (tem_consolidado and tipo_df_escolhido != 'CONSOLIDADO')` e números publicados.
É decisão do mantenedor. O que foi feito é recusar publicar o lucro dos controladores extraído
de formulário em branco (`BASE_DEGENERADA`) e deixar as 7 fichas localizáveis por consulta.

## Conjunto dourado

- **Banrisul 2024 `lucro_liquido`** rebaixada de `TRAVA` a `DIVERGENCIA_FONTE`: o agregador
  publica um único "Net Income" = 727,25 mi que é a parcela dos **controladores** (desvio
  4e-06, contra 7,5e-04 do consolidado). Passava por folga de tolerância, não por acerto de
  conceito. Requalificar exige fonte primária do consolidado, ainda não obtida.
- **Financeira Alfa 2023** entra com duas travas: `lucro_liquido` = 23.044.000 (fonte primária,
  tolerância 0,5% porque o documento arredonda para uma casa em milhões) e
  `lucro_liquido_controladores` = 18.578.000.
- Comentário do teste corrigido de 187/28/18 para **189/27/19**.

## Correções de documentação

`AGENTS.md` §4 chamava R$ 5,87 bi de "lucro dos controladores" — é o **consolidado**; os
controladores são R$ 5,73 bi, e é deles que sai a margem de 17,63% citada na mesma linha. O
mesmo erro estava no exemplo de `.claude/skills/validar-externo/SKILL.md`. Ambos corrigidos.
Um mantenedor futuro que "consertasse" o pipeline para bater com 5,87 quebraria a âncora.

## Decisões que ficaram com o mantenedor

1. **Base degenerada (7 fichas, TIM incluída).** Recuar para a outra base, publicar NULL, ou
   manter como está? Altera números publicados e o invariante da política.
2. **Receita bancária: `3.01` contra `3.03`.** Continua sem definição; 14 `DEFEITO_ABERTO` do
   conjunto dourado dependem dela.
3. **Adotar ou não a camada de resolução completa** proposta pela consultoria (212–368 h).


---

# Parte V — Diretrizes de método

## O conjunto dourado é o mecanismo, não um relatório

`dbt/seeds/conjunto_dourado.csv` + `dbt/tests/assert_conjunto_dourado.sql`. Toda divergência
confirmada entra **antes** da correção, para que o teste falhe, a correção o faça passar e a
regressão fique impedida. Quando um `DEFEITO_ABERTO` for corrigido, **promova a linha a
`TRAVA`** — foi o que aconteceu com BANRISUL 2024 nesta sessão, e é assim que a proteção
cresce sozinha.

Regras que já custaram caro e não se negociam:

- **Tolerância derivada da precisão publicada, não um percentual fixo.** A regra anterior
  dizia "relativa, nunca absoluta", e isso é cego: uma fonte que publica "R$ 23,0 milhões"
  sustenta o intervalo [22,95; 23,05] mi, e não uma tolerância de 0,5% escolhida a dedo.
  Quando a fonte publica arredondado, compare contra o intervalo de arredondamento; quando
  publica na unidade exata, compare por igualdade. O percentual relativo continua sendo a
  aproximação aceitável quando a precisão da fonte não está documentada — e nesse caso a
  limitação tem de estar escrita na `observacao`, em vez de virar exatidão inventada.
- **Registre a URL e a citação literal.** Agregador reformata o número conforme a consulta.
- **Classifique a divergência antes de chamá-la de defeito.** Metade das 37 desta auditoria
  era norma contábil diferente, safra reapresentada ou número gerencial — o mart estava certo.
- **Confira o teste contra vacuidade.** Rode a lógica sem o filtro e verifique que as linhas
  que deveriam reprovar reprovam. `assert_dedup_sem_divergencia` já foi vácuo por meses.

## Sobre agentes: poucos, no ponto de decisão

O que falhou em 2026-09-06 foi lançar 155–161 agentes contra um limite de sessão: 400 de 476
morreram com zero token e a fase de refutação evaporou. Nesta sessão foram **3 agentes**, um
por proposta prestes a virar código, e **2 derrubaram a proposta**.

- Use refutador adversarial **no ponto em que uma decisão vira código**, não para varrer.
- Um agente por afirmação, com o predicado exato a atacar e ordem explícita de marcar
  `refutado=true` na dúvida.
- **Re-meça você mesmo a alegação central** que o agente trouxer antes de agir. Nesta sessão
  a taxa de 5,76% e a ficha da CTEEP foram reproduzidas de forma independente antes de a
  proposta ser descartada.
- Persista o resultado em **arquivo do repositório** ao fim de cada lote. O `result` de
  workflow é temporário: 8,5 M de tokens de trabalho quase se perderam por isso.

## Carimbe o estado analisado em toda medição

Adotado em 2026-09-09, por pedido da revisão externa. Toda medição registrada declara:
**commit**, **estado da árvore**, e **mtime do warehouse**. Sem isso, um número medido é
irreproduzível — foi exatamente assim que o exemplo da KLABIN entrou errado no registro: o
agente mediu o warehouse pré-correção, e o número virou "defeito" numa seção que falava de
outro defeito.

```
commit: $(git rev-parse --short HEAD)  |  árvore: N alterações
warehouse mtime: AAAA-MM-DD HH:MM:SS
```

E a regra que dela decorre: **re-meça você mesmo a alegação central que um agente trouxer,
antes de escrevê-la no registro.** Esta diretriz já existia; ela foi violada e custou uma
correção pública.

## Não reconstrua o warehouse enquanto agentes medem

Erro cometido em 2026-09-08 e registrado para não se repetir. Dois refutadores foram lançados
sobre medições de impacto e, no meio da execução deles, o modelo foi corrigido e o
`dbt build` rodou. Os refutadores mediram uma tabela que já era outra e devolveram
`refutado = true` — com razão formal e conclusão errada: o que eles provaram foi que a
mudança **já tinha entrado**, não que a análise estivesse furada. A diferença que eles
mediram (474 margens e 451 ROEs) é exatamente a que o commit declara.

O warehouse é estado global e compartilhado: `dbt build` o substitui inteiro e ainda segura
lock exclusivo. Enquanto houver agente medindo, ele é imutável. Ou se mede antes e se aplica
depois, ou se aplica e se remede — nunca as duas coisas ao mesmo tempo.

## Ao retomar em lote

Uma dimensão por vez, medição → refutação → correção → conjunto dourado → commit. Cada
commit registra o número **antes e depois** e reproduz a âncora WEG 2023 — os sete commits da
branch seguem esse formato e ele é o que torna a auditoria auditável.

## Teste que reprova em massa nasce `warn`

Um teste novo que retorna 80 ou 127 linhas no estado atual quebra o build e o build quebrado
deixa de ser lido. `assert_dedup_sem_divergencia` (127) e `roe_is_null_or_abs_roe_100` (20)
já vivem assim, de propósito: o WARN mantém o número visível e sob contagem, e vira `error`
quando o alcance chegar a zero.
