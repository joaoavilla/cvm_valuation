# Contratos de conceitos e indicadores

Documento canônico de **significado**. Enquanto `AGENTS.md` diz como se trabalha aqui e
`AUDITORIA_ACURACIA_CHECKPOINT.md` guarda o histórico, este arquivo responde uma pergunta só:
**o que cada número publicado quer dizer, em qual contexto vale, e quando ele não existe.**

Escrito em 2026-09-08, Etapa 1 de `PROXIMA_SEQUENCIA.md`. Cobre os conceitos e indicadores
centrais; as demais famílias entram uma de cada vez.

Regra de leitura: `[MEDIDO]` tem consulta e número · `[DECISÃO]` julgamento registrado, aberto
a contestação · `[PENDENTE]` ainda não resolvido, com o próximo passo nomeado.

Cada regra tem **identificador**. O identificador é usado no código, no teste e no registro da
decisão, para que "por que este número é este?" se responda sem reconstruir conversa.

---

## 0. As três perguntas que este arquivo separa

O defeito estrutural do projeto foi resolver as três juntas dentro do mart, de modo que
corrigir uma deixava outra errada.

| Pergunta | Responsabilidade | Onde a resposta mora |
|---|---|---|
| O que este número significa? | **Classificação** | seed `contas_canonicas` + §3 deste arquivo |
| Qual observação representa o significado? | **Resolução** | blocos de atribuição + §3, campo *resolução* |
| Como ele é usado? | **Indicador** | §4 deste arquivo |

Um indicador **nunca** redefine um conceito para preencher lacuna. Se o componente contratado
não existe, o indicador fica indisponível e diz por quê.

---

## 1. Contexto obrigatório de todo valor `R-CTX-001`

Nenhum valor é comparável sem o contexto completo. Todo valor publicado carrega, explícita ou
implicitamente pelo grão da tabela:

| Dimensão | Coluna | Observação |
|---|---|---|
| Entidade | `cd_cvm` | |
| Base contábil | `tipo_df` | CONSOLIDADO ou INDIVIDUAL — **não são intercambiáveis** |
| Período | `dt_inicio_exercicio`, `dt_fim_exercicio` | fluxo precisa dos dois; estoque só do fim |
| Documento | `dt_referencia`, `versao` | a safra em que o valor apareceu |
| Publicidade | `dt_recebimento` | quando ficou público |
| Unidade | `unidade` no staging | `MOEDA` ou `POR_ACAO` |

**`R-CTX-002` — proibição de mistura.** É vedado compor um indicador com componentes de bases
diferentes, de períodos diferentes ou de documentos diferentes. Preencher lacuna da base
consolidada com valor da individual não é recuperação: é troca de significado.

---

## 2. Temporalidade `R-TMP-001`

Existem **duas séries diferentes** e cada coluna precisa dizer a qual pertence:

| Série | O que é | Como se obtém hoje |
|---|---|---|
| **Original** | o que a companhia publicou para aquele exercício, no documento daquele exercício | `safra_original = true` (`ordem_exercicio = 'ÚLTIMO'`) |
| **Reapresentada** | o mesmo exercício como aparece em documento posterior | `safra_original = false` |

`mart_fundamentos_anuais` publica hoje **exclusivamente a série original**. Isso é uma escolha,
não um acidente, e passa a estar escrito aqui.

**`R-TMP-002` — recuperação documental não reescreve o passado.** Um valor recuperado hoje de
um documento antigo entra com três datas distintas: **data de publicação** do documento, **data
de coleta** e **data de incorporação** ao pipeline. Ele não pode aparecer como se já fosse
conhecido pelo sistema antes da incorporação.

`[PENDENTE]` A magnitude da diferença entre as duas séries por conceito ainda não foi medida
com denominador. Sem isso não se decide se as duas precisam existir como colunas distintas.

---

## 3. Conceitos

### `R-LUC-001` · `lucro_liquido`
**Significado.** Resultado líquido do período da base reportada, incluindo a parcela dos não
controladores quando a base é consolidada.
**Resolução.** Conta eleita pelo seed no bloco de resultado do plano aplicável
(`3.11`, `3.13` ou `3.09`, conforme a descrição — o código sozinho não determina).
**Indisponível quando** nenhuma conta do seed casa, ou o valor está em quarentena
(`status_valor <> 'OK'`).
**Defeito conhecido** `[MEDIDO]`: quando o pai do bloco vem em branco e os filhos estão
íntegros, o valor eleito é zero. FINANCEIRA ALFA 2021 e 2022 publicam `0` contra
R$ 79.326.000 e R$ 38.967.000 confirmados em documento. → `R-LUC-004`.

### `R-LUC-002` · `lucro_liquido_controladores`
**Significado.** Parcela do resultado atribuível aos sócios da controladora.
**Aplicabilidade.** Só existe em base **CONSOLIDADO**. Uma demonstração individual não tem
participação de não controladores. `[MEDIDO]`: das 4.529 fichas de base individual, **0** têm
`pl_minoritarios`, e no BPP as 3.911 linhas de "não controladores" (500 empresas) estão
**todas** em base consolidada.
**Resolução.** Linha `.01` do bloco cuja identidade `total = controladores + não controladores`
fecha, escolhido entre os blocos candidatos. Publicado apenas com
`status_lucro_controladores = 'IDENTIDADE_OK'`.
**Indisponível quando** o status é qualquer outro. Os estados e seus alcances estão em
`_marts.yml`.

### `R-LUC-003` · resolução do bloco de atribuição
Um bloco é candidato quando seu total bate com `lucro_liquido` e ele tem a linha `.01`.
Vence o bloco cuja identidade fecha. Nenhum ou mais de um fechando → conflito, sem desempate.
Registrado em `origem_lucro_controladores`.

### `R-LUC-004` · pai em branco `[PENDENTE]`
Quando o pai do bloco é zero e os filhos `.01` e `.02` estão ambos presentes e somam valor não
nulo, o total do bloco **é derivável**: `total = controladores + não controladores`. É
derivação auditável dentro do mesmo contexto, não estimativa.
Alcance `[MEDIDO]`: **3 blocos, 3 fichas, 2 empresas** (FINANCEIRA ALFA 2021 e 2022, CESP 2022).
**Não implementado** — altera números publicados, depende de aval.

### `R-PL-001` · `patrimonio_liquido`
**Significado.** Patrimônio líquido total da base reportada, incluindo a participação de não
controladores quando consolidada.
**Resolução.** Conta eleita pelo seed (`2.03`, `2.05`, `2.07` ou `2.08`, conforme a descrição).

### `R-PL-002` · `patrimonio_liquido_controladores`
**Significado.** Patrimônio atribuível aos sócios da controladora.
**Fórmula.** `patrimonio_liquido − coalesce(pl_minoritarios, 0)`.
**Por que o `coalesce` aqui é legítimo, ao contrário dos outros** `[MEDIDO]`: `pl_minoritarios`
é **não nulo em 6.318 de 6.318** fichas consolidadas — nunca falta onde poderia existir. O
`coalesce` só atua em base individual, onde o valor correto **é** zero por construção
(`R-LUC-002`). Não é ausência tratada como zero; é ausência que significa zero, e isso está
medido, não suposto.
`[PENDENTE]` decidir saldo final contra saldo médio do período.

---

## 4. Indicadores

### `R-IND-001` · `margem_liquida`
**Significado.** Resultado atribuível aos sócios da **entidade que reporta**, sobre a receita
líquida do mesmo período e da mesma base.

**Numerador, por base** — é uma definição só, realizada em dois contextos:

| Base | Numerador | Justificativa |
|---|---|---|
| CONSOLIDADO | `lucro_liquido_controladores`, exigindo `IDENTIDADE_OK` | há minoritários a separar |
| INDIVIDUAL | `lucro_liquido` | não existe participação de não controladores (`R-LUC-002`) |

**Denominador.** `receita_liquida` da mesma base e período, com `nullif(..., 0)`.

**Indisponível quando** a base é consolidada e o status não é `IDENTIDADE_OK`; ou a receita é
nula ou zero; ou a receita não é aplicável à atividade (instituição financeira).

**`[DECISÃO]` Isto NÃO é o `coalesce` atual, e também não é "estrito para todos".** A revisão
externa recomendou estrito para todos os casos. Medido, isso removeria **3.544** margens — mas
**3.070 delas (86,6%) são de base INDIVIDUAL**, onde consolidado e controladores coincidem por
construção e o número está certo. O contrato acima remove **474**, que são exatamente as de
base consolidada em que a substituição muda o significado:

| Base | Status | Margens que saem |
|---|---|---:|
| CONSOLIDADO | `SPLIT_NAO_INFORMADO` | 389 |
| CONSOLIDADO | `CONFLITO_FONTE` | 75 |
| CONSOLIDADO | `CONTRADICAO_DRE_BPP` | 10 |
| CONSOLIDADO | `BASE_DEGENERADA` | 0 (já nulas) |
| **total** | | **474** |

### `R-IND-002` · `margem_liquida_consolidada`
**Significado.** Resultado consolidado, **incluindo** a parcela dos não controladores, sobre a
receita líquida. Conceito próprio, não é substituto de `R-IND-001`.
Numerador: `lucro_liquido`. Denominador: `receita_liquida`.

### `R-IND-003` · `roe`
**Significado.** Resultado atribuível aos sócios da entidade que reporta sobre o patrimônio
atribuível aos mesmos sócios.
**Numerador.** O mesmo de `R-IND-001`, com a mesma regra por base.
**Denominador.** `patrimonio_liquido_controladores`, **apenas quando positivo**.
**Indisponível quando** o numerador é indisponível, ou o patrimônio não é positivo — razão
sobre patrimônio negativo inverte a leitura.
Alcance da adoção `[MEDIDO]`: saem **451** (367 + 74 + 10 + 0), não 4.254. A diferença para a
margem (474) vem de receita nula em financeiras e de patrimônio não positivo.
`[PENDENTE]` saldo final ou médio.

### `R-IND-004` · `roe_consolidado`
Resultado consolidado sobre patrimônio líquido total, este último só quando positivo.

---

## 5. Matriz indicador → componentes → fontes → validação

`[PENDENTE]` Em construção. A matriz precisa, por indicador: componentes, demonstrativo e conta
de origem, cobertura medida por coorte, lacuna, e temporalidade aplicável. É ela que decide
quais ingestões novas o projeto precisa — e não o contrário.

---

## 6. Pendências deste contrato

| ID | Pendência | Próximo passo |
|---|---|---|
| `R-TMP-001` | magnitude da diferença entre série original e reapresentada, por conceito | medir com denominador |
| `R-LUC-004` | derivação do pai em branco (3 fichas) | aval do mantenedor; altera número publicado |
| `R-PL-002` | saldo final contra saldo médio no ROE | medir para quantas fichas o médio é calculável |
| `R-PL-003` | **defeito novo**: 126 fichas publicam ROE com `pl_minoritarios = 0` REPORTADO enquanto a DRE da mesma ficha declara lucro de não controladores ≠ 0. 159 das 172 são `IDENTIDADE_OK` e sobrevivem à regra estrita. Máx. 50,19 pp (KLABIN 2025: 21,28% contra 11,65%) | mesma classe já corrigida em outros pontos: zero reportado tratado como fato quando outro demonstrativo o contradiz |
| `R-BASE-001` | base degenerada: recuar para a outra base está **descartado como política geral** — a receita individual da CELGPAR é zero em 12 de 13 anos saudáveis e o lucro da CLI SUL diverge −36% a −42%. Para CELGPAR a própria CVM publicou correção em safra posterior | tratar caso a caso por causa, e usar a safra posterior onde ela existe |
| `R-IND-001` | adoção do contrato (474 margens saem) | aval do mantenedor |
| §5 | matriz de fontes | concluir antes de qualquer ingestão nova |
