# Próxima sequência — contratos antes de generalizar

Documento de trabalho da branch `fix/auditoria-acuracia-independente`, escrito em 2026-09-08
depois da **segunda revisão externa**. Complementa `AUDITORIA_ACURACIA_CHECKPOINT.md`, que
guarda o histórico; aqui ficam **as decisões pendentes e a ordem de execução**.

Regra de leitura: `[MEDIDO]` tem consulta e número · `[ACEITO]` crítica externa confirmada ·
`[DELIMITADO]` crítica externa cujo alcance foi medido, sem virar refutação · `[DECISÃO]` depende do mantenedor.

---

## 1. Conferência da segunda revisão

Toda crítica foi remedida antes de aceita. O resultado se divide em três.

### 1.1 Aceito e a corrigir

| # | Crítica | Medição | Situação |
|---|---|---|---|
| A1 | O fallback muda a definição de `margem_liquida` e `roe` conforme a disponibilidade do dado | **3.544 de 10.847 fichas** têm `lucro_liquido_controladores` nulo e `margem_liquida` preenchida, inclusive as 10 de `CONTRADICAO_DRE_BPP` | **[ACEITO]** defeito real |
| A2 | `base_degenerada` usa `coalesce(...,0)=0` e junta ausência com zero (corrigido; ver limitação em §1.4) | Nas 7 fichas os três conceitos estão **presentes e zero**; **0 NULL** | **[ACEITO]** latente, alcance 0 hoje |
| A3 | A trava da cisão da Alfa não é confirmação externa | A `observacao` já admite que a cisão veio do DFP, mas `fonte_tipo` diz `relatorio_anual` | **[ACEITO]** rótulo errado |
| A4 | "Tolerância relativa, nunca absoluta" é regra cega | "R$ 23,0 milhões" define o intervalo [22,95; 23,05] mi, não uma tolerância de 0,5% | **[ACEITO]** |
| A5 | Contrato antes de generalizar | — | **[ACEITO]** inverte a ordem que eu havia proposto |

### 1.2 Delimitado com número (correcao de 2026-09-08: NAO sao refutações)

**R1 — "Resultado final zero com outro bloco diferente de zero não prova contradição:
componentes positivos e negativos podem se compensar."**

Logicamente válido. **Não observado no recorte medido** — ver a ressalva abaixo. `[MEDIDO]`

```sql
with b as (
  select f.cd_cvm, f.dt_fim_exercicio,
    max(case when f.cd_conta='3.09' then f.valor end) c09,
    max(case when f.cd_conta='3.10' then f.valor end) c10,
    max(case when f.cd_conta='3.11' then f.valor end) c11
  from fct_fundamentos f join int_empresas_tipo_df p
    on f.cd_cvm=p.cd_cvm and f.dt_fim_exercicio=p.dt_fim_exercicio
   and f.tipo_df=p.tipo_df_escolhido
  where f.safra_original and f.status_valor='OK' and f.demonstrativo='DRE'
    and f.cd_conta in ('3.09','3.10','3.11') group by 1,2)
select count(*) filter (where c11=0 and coalesce(c09,0)<>0)                                   as padrao,
       count(*) filter (where c11=0 and coalesce(c09,0)<>0 and abs(coalesce(c09,0)+coalesce(c10,0))<=1000) as compensado
from b;
```

**119 fichas** com `3.11 = 0` e `3.09 ≠ 0`; em **0** delas o `3.10` compensa. E a guarda só
dispara em **2** — nas outras **117** o seed elege `3.13`, que carrega o valor correto
(BCO NORDESTE, DIBENS LEASING, SANTANDER LEASING, BTG 2010…). A guarda não é cega: ela só
engata quando o total eleito é ele próprio zero.

> **Correcao de registro, e a medição refeita.** Eu havia escrito "refutado". Está errado:
> isto é **contraexemplo não observado**, não hipótese refutada. A crítica à medição
> também procede, e **era pior do que ela supunha**. Refeita com o contexto documental
> completo `(cd_cvm, tipo_df, dt_referencia, versao, ordem_exercicio, dt_inicio_exercicio,
> dt_fim_exercicio)`:
>
> - No grão grosso o padrão aparecia em **328 fichas**; com contexto completo sobram **234**.
>   **94 (28,7%) eram artefato** do `max()` pegando o `3.09` do CONSOLIDADO e o `3.11 = 0` do
>   INDIVIDUAL — BRADESCO 2010–2019, BANESTES 2010–2018. E o grão grosso também
>   **escondia 3 casos reais**, dois deles entre os que a guarda de fato pega. A consulta
>   inventava e ocultava ao mesmo tempo.
> - **A guarda em produção nunca teve esse defeito:** `blocos_resumo` sempre agrupou por
>   `tipo_df` e o join sempre casou `p.tipo_df = r.tipo_df`. E o `max()` dentro de
>   `blocos_atribuicao` não desempata nada: **17.071 de 17.072** chaves já são o contexto
>   documental completo, com **0** casos de múltipla `dt_referencia` ou `versao` e
>   **0 de 47.151** células com duas descrições para o mesmo código.
> - **Contraexemplo varrido em 33.972 contextos** (plano PADRAO, 2009–2025, 1.222 empresas,
>   as duas ordens de exercício): **zero ocorrências**. Nas 5 fichas em que a guarda dispara,
>   o `3.10` está presente e vale exatamente zero nas cinco. Continua sendo **não observado**,
>   não refutado — o caso é contabilmente válido e a fonte pode produzi-lo.
> - **Alcance real da guarda: 5 fichas de 10.847 (0,046%)** — 125 têm lucro eleito zero, só 5
>   têm irmão não zero. Dos 94 `CONFLITO_FONTE` do mart, 5 vêm daqui.
> - Fato colateral que derruba a leitura fácil de "`3.10` quase nunca é diferente de zero":
>   ele é ≠ 0 em 5,81% do plano PADRAO mas em **47% a 91%** dos planos LEGADO_FIN, FIN_2020 e
>   DESLOCADO — onde não é operação descontinuada nenhuma. O código não determina o
>   significado, de novo.
>
> **Pendência:** criar o **teste sintético de compensação legítima**, que exercite o caso sem
> depender de a fonte um dia produzi-lo.

**R2 — "O consolidado zerado no fato não permite concluir que a companhia não tinha
consolidado válido."**

Correto como enunciado, e por isso **rastreei a TIM 2024 até o raw**. `[MEDIDO]`

```sql
select DT_REFER, ORDEM_EXERC, CD_CONTA, VL_CONTA
from read_parquet('../data/raw/dfp/ano=*/dre_con.parquet')
where CD_CVM='024929' and DT_REFER='2024-12-31'
  and CD_CONTA in ('3.01','3.09','3.10','3.11','3.11.01');
```

| ORDEM_EXERC | 3.01 | 3.09 | 3.10 | 3.11 |
|---|---:|---:|---:|---:|
| PENÚLTIMO (2023) | 23.833.893 | 2.837.422 | 0 | 2.837.422 |
| **ÚLTIMO (2024)** | **0** | **0** | **0** | **0** |

O zero **já está no Parquet**, com o comparativo do ano anterior preenchido no mesmo
arquivo.

> **Correcao de registro.** Isto ainda não inocenta a ingestão: **o Parquet é produzido
> por ela**. Falta comparar com o CSV de dentro do ZIP original, identificando versão e
> hash. Os ZIPs **estão preservados** em `data/raw/dfp/_zips/` com manifesto em
> `data/raw/dfp/_manifests/`, então a comparação é possível e virou a Etapa 3.1.

Isso não contradiz o revisor — **localiza a causa** na terceira linha da tabela dele:
*arquivo estruturado defeituoso, com documento publicado correto disponível*. O tratamento
indicado passa a ser recuperação rastreável a partir do documento, não troca de base por
política.

### 1.3 Impreciso

- A branch tem **10 commits** desde a reescrita desta sessão, não nove.

### 1.4 O que mudou depois da segunda revisão `[MEDIDO 2026-09-08]`

**A pendência externa da Alfa está fechada, e revelou dois defeitos novos.**

A evidência estava no documento que eu já tinha e não havia lido até o fim: *Proposta da
Administração*, **página 17 de 70**, tabela "Consolidado IFRS — R$ mil".

| | 2023 | 2022 | 2021 |
|---|---:|---:|---:|
| Resultado líquido dos exercícios | 23.044 | **38.967** | **79.326** |
| Parcela dos acionistas controladores | 18.578 | **38.643** | **77.245** |
| Parcela dos não controladores | 4.466 | 324 | 2.081 |

Confere com o DFP nos três anos: `3.09.01` e `3.09.02` trazem exatamente esses valores. Mas
em **2021 e 2022 o pai `3.09` vem VAZIO** no arquivo da CVM, e o mart publica
`lucro_liquido = 0` e `roe = 0` para uma empresa que lucrou R$ 79,3 mi e R$ 39,0 mi.

Isso separa **duas classes de recuperação**, que exigem tratamentos diferentes:

| Classe | Onde está o valor | Recuperação |
|---|---|---|
| **Pai em branco** (Alfa 2021/2022) | dentro do próprio arquivo da CVM, nos filhos completos | derivação auditável: `total = controladores + não controladores`, com os dois elegíveis |
| **Base inteira zerada** (TIM 2024/2025) | **não está** no bloco consolidado | exige documento externo ou a outra base, que é outro contexto contábil |

A primeira é uma derivação dentro do mesmo contexto e cabe no resolvedor. A segunda é
recuperação documental e precisa entrar como dado de fonte, com documento, página, período,
base, unidade, data de publicação, data de coleta e data de incorporação.

**Alcance de margem e ROE são diferentes, e não devem ser confundidos** `[MEDIDO]`:

```sql
select count(*) as fichas,
       count(*) filter (where lucro_liquido_controladores is null and margem_liquida is not null) as margem_fallback,
       count(*) filter (where lucro_liquido_controladores is null and roe is not null)            as roe_fallback
from mart_fundamentos_anuais;
```

10.847 fichas · **3.544** com margem por fallback · **4.254** com ROE por fallback.

**Limitação declarada de `base_degenerada`:** a regra agora exige ao menos um conceito central
observado e todos os observados iguais a zero, mas isso **não prova que a base inteira seja
inválida** — prova que os conceitos que o seed cobre estão zerados. É um **detector parcial**,
e o estado que ele produz deve ser lido como suspeita dirigida à investigação, não como
conclusão.

### 1.5 Piloto documental da TIM 2024 — conclusão `[MEDIDO 2026-09-08]`

A cadeia completa foi percorrida: ZIP original → CSV → manifesto → Parquet → staging → fato → mart.

**A ingestão está inocentada com prova documental.** O CSV `dfp_cia_aberta_DRE_con_2024.csv`
extraído do ZIP original da CVM (**sha256 `b46123d7…`, idêntico ao registrado no manifesto**)
já traz as 31 linhas de `ORDEM_EXERC='ÚLTIMO'` da TIM com `VL_CONTA = 0`, enquanto as 31 de
`PENÚLTIMO` trazem 22 valores não nulos. O Parquet é **cópia byte a byte**: o multiset das
32.776 linhas × 15 colunas é idêntico. Staging, `int`, `fct` e mart propagam o zero sem
alteração, com `status_valor = 'OK'` e `n_linhas_fonte = 1` — nenhuma quarentena, nenhum
desempate. E a conversão de escala funciona no **mesmo documento** (o PENÚLTIMO vira
2,3833893e10), então o zero não é artefato de escala.

**Três hipóteses derrubadas pela medição, e cada uma muda a proposta de recuperação:**

1. **Não é defeito da DRE, é do documento inteiro.** O bloco consolidado veio zerado em
   **277 de 277** linhas de BPA+BPP+DFC_MI+DRE, e também em `DRA_con` (0/7) e `DVA_con`
   (0/41) — arquivos que o projeto **nem sequer ingere**. O defeito é do transmissor.
2. **Não há uma assinatura, há três.** Só o ÚLTIMO zerado com PENÚLTIMO íntegro; documento
   inteiro zerado nas duas ordens; e o caso CELGPAR, em que **a própria CVM já publicou a
   correção numa safra posterior** e o mart continua publicando zero. Este terceiro é o mais
   acionável: a fonte de recuperação está dentro do dado que já temos.
3. **Trocar pela base individual seria errado em metade dos casos.** Para TIM e RIO
   PARANAPANEMA o individual é excelente (lucro idêntico ao consolidado em 100% dos anos
   saudáveis). Mas a receita individual da **CELGPAR é zero em 12 dos 13 anos saudáveis**
   enquanto a consolidada chega a R$ 2,2 bi, e o lucro individual da **CLI SUL diverge −36%
   a −42%**. Substituir cegamente trocaria um zero honesto por um número errado em 2 das 4
   empresas. **Isto encerra a opção "recuar para a outra base" como política geral.**

**O amplificador está na nossa camada, mas não na ingestão.** `int_empresas_tipo_df` elege a
base com `bool_or(tipo_df = 'CONSOLIDADO')` — olha a **existência** de linhas consolidadas,
nunca se elas carregam algum número. O mart já **detecta** (`BASE_DEGENERADA`) mas não **age**.

### 1.6 Um defeito novo, no denominador do ROE `[MEDIDO 2026-09-08]`

A hipótese de que `coalesce(pl_minoritarios, 0)` contaminava o denominador foi **refutada**:
`pl_minoritarios` é nulo exatamente nas 4.529 fichas individuais e em **0 de 6.318**
consolidadas, nos 16 anos e nos dois planos. É identidade contábil, não fallback.

**Mas o segundo fallback existe, e está no ZERO REPORTADO:** 2.573 fichas consolidadas trazem
`pl_minoritarios = 0` e, em **172 delas (6,7%)**, a DRE da mesma ficha declara lucro de não
controladores diferente de zero. Dessas 172, **159 são `IDENTIDADE_OK` e portanto sobrevivem
à regra estrita**, e **126 publicam `roe` hoje** com denominador igual ao PL total de uma
empresa que demonstravelmente tem minoritários. O mart sinaliza apenas 10 delas
(`CONTRADICAO_DRE_BPP`), porque aquele estado exige também `controladores = 0`.

Magnitude nas 81 fichas em que há divergência: p50 = 0,0000 pp · p90 = 0,0000 pp ·
p99 = 0,0140 pp · **max = 50,19 pp**; 18 acima de 1 pp, 7 acima de 5 pp. KLABIN 2025: 21,28%
contra 11,65% do consolidado. CPFL GERAÇÃO 2021: 50,78% contra 29,49%.

`[PENDENTE]` É o próximo defeito da fila, e é do mesmo tipo que os já corrigidos: zero
reportado tratado como fato quando outro demonstrativo o contradiz.

---

---

## 2. As três perguntas, e onde cada uma mora hoje

O diagnóstico do revisor — que classificação, resolução e definição do indicador estão
misturadas — está certo e é o eixo do plano.

| Pergunta | Responsabilidade | Onde mora hoje | Para onde vai |
|---|---|---|---|
| O que este número significa? | Classificação | `contas_canonicas.csv` (chave) + descrições da fonte | catálogo de conceitos versionado |
| Qual observação representa o significado? | Resolução | `blocos_atribuicao` → `candidatos` → `preferidos` → `atribuicao`, dentro do mart | etapa própria, antes do pivot, com linhagem |
| Como utilizá-lo? | Indicador | expressões no `select` final do mart | contrato de indicador, com aplicabilidade |

`origem_lucro_controladores` foi o primeiro passo de linhagem, mas guarda só o código do
bloco. Falta registrar candidatos considerados, regra aplicada, documento/versão, base e
período inicial e final.

---

## 3. Sequência — estado em 2026-09-09

Ordem revisada pela terceira revisão externa e adotada. Uma etapa por commit, com critério de
saída verificável. **Estado analisado carimbado em toda medição**: commit, estado da árvore e
`mtime` do warehouse.

| # | Etapa | Estado |
|---|---|---|
| 0 | Parar de afirmar o que não foi verificado | ✅ `f3bfd04` |
| 1 | Contratos mínimos de conceitos e indicadores | ✅ `b97fa82` |
| 2 | Correcao do fallback de margem e ROE | ✅ `dcaa7bf` |
| 3 | **Sanear registros** — `R-PL-003` a hipótese, Klabin reconciliada, linguagem da base individual, nomes das versões "consolidadas" | ✅ `2f0ab7b` + `c231c3b` |
| 4 | **Corrigir a dívida e seus consumidores** | ✅ `c231c3b` |
| 5 | **Fechar a seleção temporal** | ✅ contrato em `18c4cf6`; **duas lacunas do acervo ficam pendentes** |
| 6 | **CELGPAR como piloto de recuperação temporal** | ⏸ **bloqueado** — ver abaixo |
| 7 | Demais bases zeradas e investigação patrimonial | pendente |
| 8 | Extrair a resolução para antes do pivot; depois generalizar por família | pendente |

### Por que a CELGPAR está bloqueada, e não apenas não-feita

A recuperação por safra posterior exige, por `R-TMP-005`, que o valor entre com **data de
publicação, data de coleta e data de incorporação**, preservando a observação anterior. Duas
dessas não existem hoje:

- **data de incorporação não é registrada** em lugar nenhum do pipeline (`R-TMP-003`);
- **a primeira publicação é irrecuperável para 22,4% das fichas** (`R-TMP-002`), porque o
  acervo guarda apenas a versão corrente de cada documento.

Executar a recuperação antes disso produziria exatamente o que `R-TMP-005` proíbe: um valor
corretivo aparecendo como se sempre tivesse estado lá. A ordem correta é implementar a data de
incorporação, e só então a CELGPAR.

### O que a Etapa 5 deixou pronto e o que deixou em aberto

Pronto: a distinção entre as duas leituras, a medição de que elas divergem em 12,6% dos
indicadores com 26 trocas de sinal, e a regra de que recuperação não retroage.

Em aberto, e **antes de qualquer reingestão**: arquivar cada download. Enquanto isso não
existir, cada `python -m ingestion` destrói a única cópia do que a CVM dizia antes — e já se
sabe que 22,4% dos documentos foram refeitos.

## 4. Registros canônicos

Sugiro **três** arquivos versionados na raiz, não quatro, para não fragmentar:

| Arquivo | Conteúdo |
|---|---|
| `CONTRATOS.md` | Indicadores e resolução: definição, fórmula, componentes, aplicabilidade, grão, contexto, regras de escolha e publicação |
| `VALIDACAO.md` | Fontes de referência, precisão, tolerância, seleção de amostras, separação entre amostra de regressão e de avaliação |
| `DECISOES.md` | Hipótese, evidência, consulta reproduzível, decisão, impacto, pendências — com o identificador de regra |

`guias/` está no `.gitignore` e por isso não serve para nada que precise acompanhar o clone.

**Exigências de cada PR:** problema medido antes; regra e evidência; teste que reprova o
defeito antigo mais contraexemplos que a regra deve preservar; relação das fichas que mudaram
de valor, status ou disponibilidade; resultados por plano, setor e período com denominadores;
build com avisos explicados e âncoras conferidas.

---

## 5. Decisões que dependem do mantenedor

1. **Etapa 2** — tornar `margem_liquida` e `roe` estritos, perdendo 3.544 margens para a
   coluna consolidada. Sim, não, ou apenas para os estados de conflito?
2. **Bases zeradas** — depois do diagnóstico da Etapa 3, o tratamento por causa
   (recuperação documental, seleção explícita de base, ou indisponibilidade) precisa de aval,
   porque muda número publicado e o invariante da política.
3. **Receita bancária** — `3.01` contra `3.03` segue indefinida e trava 14 `DEFEITO_ABERTO`.

## 6. O que NÃO fazer agora

- Generalizar a resolução para PL, receita, custo ou EBIT (Etapa 5) antes das Etapas 1–4.
- Reescrever histórico ou descartar commits: o estado atual é o checkpoint.
- Iniciar ingestão nova antes da matriz da Etapa 6.
- Usar ML para sugerir mapeamento antes de existir referência confiável para avaliá-lo — sem
  isso, automatizar só acelera a reprodução das ambiguidades atuais.
