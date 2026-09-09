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

## 2. Temporalidade e seleção documental

Reescrita em 2026-09-09 depois da terceira revisão externa, que apontou — com razão — que
`ORDEM_EXERC` distingue a **posição do exercício dentro do documento**, e não primeira
publicação nem conhecimento numa data.

### `R-TMP-001` · o que as duas leituras são, de fato

| Leitura | O que é | O que **não** é |
|---|---|---|
| `safra_original = true` | o exercício na **versão corrente do documento do próprio exercício** | **não é** a primeira publicação |
| `safra_original = false` | o mesmo exercício como comparativo em documento posterior | — |

`mart_fundamentos_anuais` publica hoje **exclusivamente a primeira leitura**.

### `R-TMP-002` · o que o acervo guarda, e o que isso impõe `[MEDIDO 2026-09-09]`

**O acervo guarda apenas a versão corrente de cada documento.**

```sql
select versao, count(*) documentos
from (select distinct cd_cvm, dt_referencia, versao from fct_fundamentos)
group by 1 order by 1;

select n_versoes, count(*) documentos from (
  select cd_cvm, dt_referencia, count(distinct versao) n_versoes
  from fct_fundamentos group by 1,2) group by 1;
```

| | |
|---|---:|
| Documentos com `versao = 1` | 8.420 |
| Documentos **refeitos** (`versao > 1`, chegando a 9) | **2.427** |
| Fichas do mart vindas de documento refeito | **2.427 de 10.847 — 22,4%** |
| Documentos com **mais de uma versão no acervo** | **0 de 10.847** |

Ou seja: em **22,4% das fichas**, o que chamamos de "safra original" é a versão **corrente** do
documento daquele exercício, que **já pode conter correções feitas depois**. A versão
originalmente publicada está perdida — os arquivos em massa da CVM só carregam a versão
vigente, e a ingestão sobrescreve o raw (defeito A1 do histórico).

**Correção de uma afirmação minha.** Eu havia registrado que "`versao` não é um terceiro eixo,
porque 0 de 492.814 chaves têm mais de uma versão com valor divergente". A conclusão não se
sustenta: **não há divergência porque só guardamos uma versão de cada documento**, e não porque
as versões coincidam. A revisão externa alertou exatamente para isso, e estava certa.

### `R-TMP-003` · as quatro perguntas, e o que o acervo responde

| Pergunta | Política necessária | Podemos responder hoje? |
|---|---|---|
| Qual foi a **primeira publicação**? | primeira observação documentada, declarando lacunas | **NÃO** para 22,4% — só temos a versão corrente |
| O que estava **disponível na data X**? | só documentos publicados até X | **PARCIALMENTE** — `dt_recebimento` existe, mas é o da versão que temos |
| Qual é a informação **mais recente**? | observação elegível mais recente, com origem preservada | **SIM** |
| O que o **pipeline já incorporara** na data X? | data de incorporação | **NÃO** — não registrada |

Duas colunas não bastam: é preciso definir a **seleção entre documentos e versões**, e as duas
lacunas acima são pré-requisito de qualquer recuperação por safra posterior.

### `R-TMP-004` · as duas séries divergem, e isso importa `[MEDIDO 2026-09-08]`

- **9.517 de 10.847 fichas (87,7%)** existem em mais de uma safra; **3.663 (38,5%)** divergem
  materialmente em algum conceito e **1.571 (16,5%)** em conceito central.
- `margem_liquida_total` muda em **980 de 7.770** fichas comparáveis (12,6%), 387 por mais de
  1 pp e **26 trocam de sinal**. `roe_total` muda em 762 de 8.312, 33 trocam de sinal.
- **AMERICANAS 2021**: o mart publica **+2,40%**; na safra seguinte, **−27,70%** — lucro de
  R$ 543,795 mi virou prejuízo de R$ 6,237 bi. CSN 2015: +10,54% contra −7,97%.

Um backtest que use a série reapresentada como se fosse conhecida na época **está olhando o
futuro**. Publicar a leitura do próprio exercício é a escolha certa; a outra precisa existir com
nome próprio, não substituir esta.

### `R-TMP-005` · recuperação documental não reescreve o passado

Um valor recuperado de documento posterior entra com **três datas**: **publicação** do
documento, **coleta** e **incorporação**. Ele aparece a partir da publicação do documento
corretivo, **preserva a observação anterior** e não retroage.

### `R-TMP-006` · nem toda diferença entre safras é revisão contábil `[MEDIDO]`

**1.832 de 23.394** diferenças materiais (7,8%) são fator exatamente 1000 — contradição de
etiqueta de **escala**, já instrumentada por `assert_escala_sem_contradicao`. Quem medir taxa
de revisão sem excluir isso conta artefato como fato.

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
**Aplicabilidade.** Só existe em base **CONSOLIDADO**.

**Fundamentação contábil** (corrigida em 2026-09-09 após revisão externa): numa demonstração
**individual** o resultado do período pertence aos sócios **daquela entidade** — não há
consolidação e portanto não há parcela a atribuir a terceiros. É isso que fundamenta a regra,
e não a ausência das linhas no formulário.

**Evidência do formato observado**, que corrobora sem fundamentar `[MEDIDO]`: das 4.529 fichas
de base individual, **0** têm `pl_minoritarios`, e no BPP as 3.911 linhas de "não
controladores" (500 empresas) estão **todas** em base consolidada.

**O que isto NÃO afirma.** Não afirma que demonstração individual e consolidada sejam
intercambiáveis, nem que "consolidado e controladores coincidem por construção" — formulação
que este documento usou e que estava errada. São perimetros econômicos diferentes; a base
publicada continua declarada em `tipo_df` e `R-CTX-002` continua proibindo misturá-los.
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
`coalesce` só atua em base individual, onde não há participação de não controladores a
subtrair (`R-LUC-002`). Não é ausência tratada como zero: é ausência que, naquele contexto,
significa zero — e o contexto está declarado em `tipo_df`, não presumido.
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

### `R-IND-002` · `margem_liquida_total`
**Significado.** Resultado **total da base publicada** sobre a receita líquida — inclui a
parcela dos não controladores quando a base é consolidada. Conceito próprio, não é substituto
de `R-IND-001`. **Renomeada em 2026-09-09**: `margem_liquida_consolidada` era impreciso, já
que a fórmula usa o lucro total da base SELECIONADA e em 4.529 fichas ela é INDIVIDUAL.
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

### `R-IND-004` · `roe_total`
Resultado consolidado sobre patrimônio líquido total, este último só quando positivo.

---

## 5. Matriz indicador → componentes → fontes → validação

Primeira versão `[MEDIDO 2026-09-08]`, sobre o warehouse com `R-IND-001` aplicado.
Denominador sempre **10.847 fichas = 620 financeiras + 10.227 não-financeiras**.
`n/N muda` = fichas cujo indicador recalculado na safra seguinte difere · `±` = trocas de sinal.

O mart publica **12 razões** e **4 valores derivados**, sobre 26 componentes lidos do seed em 5
demonstrativos. **Não há nenhum indicador de mercado publicado** — logo não há, hoje, lacuna
de preço ou de quantidade de ações a reportar. Isso responde à pergunta de quais ingestões o
projeto precisa: **nenhuma, para o que ele já publica.**

| Indicador | Componentes | Cobertura | Lacuna | Temporalidade |
|---|---|---|---|---|
| `margem_liquida` | lucro atribuível (R-IND-001); `receita_liquida` | **8.333 (76,8%)** · fin **0/620** | 620 financeiras sem receita mapeada (decisão 3.01×3.03); 1.377 não-fin com receita = 0 indistinguível de não mapeada; 532 consolidadas sem split resolvido | **980/7.770 (12,6%)**, 387 >1pp, **26 ±** |
| `margem_liquida_total` | `lucro_liquido`; `receita_liquida` | 8.807 (81,2%) · fin 0/620 | idem, menos a de split | 980/7.770, 387 >1pp, 26 ± |
| `margem_bruta` | `lucro_bruto`; `receita_liquida` | 8.807 (81,2%) · fin 0/620 | conceito não existe no plano FINANCEIRO/SEGURADORA | 956/7.770, 476 >1pp, 11 ± |
| `margem_ebit` | `ebit`; `receita_liquida` | 8.806 (81,2%) · fin 0/620 | EBIT nulo em 614/620 financeiras — não é lacuna, é inaplicabilidade | move |
| `roe` | lucro atribuível; `patrimonio_liquido_controladores` > 0 | **9.002 (83,0%)** | PL não positivo; split não resolvido | move |
| `roe_total` | `lucro_liquido`; `patrimonio_liquido` > 0 | 9.453 (87,1%) | PL não positivo | 762/8.312 (9,2%), **33 ±** |
| `cobertura_juros` | `ebit`; `despesas_financeiras` | — | — | 1.145/8.119, **920 >1pp** |
| `divida_bruta`, `divida_liquida` | `divida_bruta_*`, `caixa_e_equivalentes` | "100%" **falsa** | ver `R-DIV-001` | move |

**`R-DIV-001` — a cobertura de 100% de `divida_bruta` e `divida_liquida` é falsa.** `[MEDIDO]`
**650 de 10.847 fichas não têm NENHUM dos componentes** e recebem zero pelo `coalesce`;
**617 delas são financeiras**. É ausência publicada como zero — o oposto do que AGENTS.md §5
exige, e a mesma classe que esta auditoria já removeu em outros pontos. `[PENDENTE]`

**`R-REV-001` — `teve_revisao_material` subconta em ~24%.** `[MEDIDO]` Marca 1.263/10.847
(11,6%), mas: cobre só 5 conceitos; usa limiar relativo de 1% e por isso é **cego a 34 pares
em que o original era zero** (`dif_pct` fica NULL); **não filtra pelo `tipo_df` que o mart
publica** — 78 fichas são marcadas por revisão ocorrida numa base que o mart nem publica, o
que contraria `R-CTX-002`; e não exclui o artefato de escala de `R-TMP-005`. O critério
equivalente restrito à base eleita dá 1.189; com 6 conceitos centrais e limiar absoluto mais
relativo dá **1.571**. `[PENDENTE]`

---

## 6.1 `R-PL-003` — hipótese em investigação, e a correção de um erro meu

**Estado analisado:** commit `93da83b`, árvore limpa, warehouse de 2026-09-08 17:02:04.

### O erro, primeiro

Registrei em 2026-09-08 que **KLABIN 2025** publicava ROE de 21,28% contra 11,65% do total,
como exemplo de ficha com `pl_minoritarios = 0` reportado. **Está errado nos dois pontos**, e a
revisão externa o pegou. Medido por mim agora:

| KLABIN 2025 | valor |
|---|---:|
| `pl_minoritarios` | **R$ 6.515.155.000** — não é zero |
| `lucro_liquido_controladores` | NULL (`SPLIT_NAO_INFORMADO`) |
| `roe` | NULL |
| `roe_total` | 0,1165335206 |

O número 21,28% existe e é exatamente `1.678.211.000 / 7.885.946.000` — o **ROE de antes da
correção `R-IND-001`**, lucro total sobre PL dos controladores. Ou seja, ele ilustra o defeito
do fallback **que já foi corrigido**, e não o defeito patrimonial. A ficha nunca perteceu à
população de `R-PL-003`.

**Causa do erro:** incorporei ao registro um exemplo trazido por um agente **sem remedi-lo eu
mesmo**, contrariando a diretriz do próprio checkpoint. O agente mediu o warehouse pré-mudança
e misturou dois defeitos; eu propaguei.

### A população, essa reproduz `[MEDIDO por mim, 2026-09-09]`

| | fichas |
|---|---:|
| consolidadas com `pl_minoritarios = 0` reportado | 2.573 |
| dessas, a DRE do mesmo contexto declara lucro de não controladores ≠ 0 | **172** |
| dessas, `IDENTIDADE_OK` (sobrevivem à regra estrita) | **159** |
| dessas, publicam `roe` hoje | **126** |

Exemplos corretos: **CTEEP 2010** (lucro de não controladores R$ 506,795 mi com
`pl_minoritarios = 0`; `roe` 6,69% contra `roe_total` 17,80%), SOUZA CRUZ 2010, AES TIETÊ 2015,
SENDAS 2020, INSPIRALI 2023 e 2025.

### Por que continua sendo hipótese

**Saldo patrimonial no encerramento e resultado atribuído durante o exercício são medidas
diferentes.** Distribuições, mudanças de participação e outras transações com proprietários
alteram o saldo final sem contradizer o fluxo — a IAS 1 §106 exige justamente que a
reconciliação do patrimônio separe resultado abrangente de transações com proprietários. Uma
compra integral da participação durante o ano produz exatamente esta assinatura **sem que haja
erro nenhum**.

E **diferença entre `roe` e `roe_total` não mede erro**: são indicadores com componentes
diferentes por definição.

**Próximo passo:** conferir DMPL e notas de uma amostra das 126 antes de qualquer ação. **Não
ampliar o veto `CONTRADICAO_DRE_BPP` com base nesta hipótese.**

---

## 6. Pendências deste contrato

| ID | Pendência | Próximo passo |
|---|---|---|
| `R-TMP-002` | **primeira publicação é irrecuperável para 22,4% das fichas** — o acervo só tem a versão corrente | arquivar cada download antes de qualquer reingestão; declarar a lacuna nas séries |
| `R-TMP-003` | data de incorporação não é registrada | acrescentar ao manifesto e propagar |
| `R-TMP-004` | as duas séries divergem em 12,6% dos indicadores, com 26 trocas de sinal | expor a série reapresentada com nome próprio |
| `R-DIV-001` | 650 fichas publicam dívida zero sem nenhum componente; 617 são financeiras | mesma correção já aplicada aos outros `coalesce` |
| `R-REV-001` | `teve_revisao_material` subconta ~24% e mistura bases | reescrever com a base eleita, 6 conceitos e limiar duplo |
| `R-LUC-004` | derivação do pai em branco (3 fichas) | aval do mantenedor; altera número publicado |
| `R-PL-002` | saldo final contra saldo médio no ROE | medir para quantas fichas o médio é calculável |
| `R-PL-003` | **HIPÓTESE, não defeito comprovado** — ver §6.1 | conferir DMPL e notas antes de qualquer veto |
| `R-BASE-001` | base degenerada: recuar para a outra base está **descartado como política geral** — a receita individual da CELGPAR é zero em 12 de 13 anos saudáveis e o lucro da CLI SUL diverge −36% a −42%. Para CELGPAR a própria CVM publicou correção em safra posterior | tratar caso a caso por causa, e usar a safra posterior onde ela existe |
| `R-IND-001` | adoção do contrato (474 margens saem) | aval do mantenedor |
| §5 | matriz de fontes | concluir antes de qualquer ingestão nova |
