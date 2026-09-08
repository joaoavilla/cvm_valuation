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

> **Correcao de registro.** Eu havia escrito "refutado". Está errado, e a segunda revisão
> tem razão: isto é **contraexemplo não observado neste recorte**, não hipótese refutada.
> Não achar compensação nas fichas medidas não transforma a guarda em regra contábil
> universal. Duas limitações do recorte, declaradas: a consulta agrega com `max()` por
> `(cd_cvm, dt_fim_exercicio)` e portanto **não preserva contexto documental nem de
> período**; e ela varre só a base eleita pela política, não as duas. **Pendência aberta:**
> refazer preservando `(tipo_df, dt_referencia, versao, ordem_exercicio,
> dt_inicio_exercicio)` e criar um **teste sintético de compensação legítima**, que
> exercite o caso sem depender de a fonte um dia produzi-lo.

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

## 3. Sequência proposta

Uma etapa por branch/PR, com critério de saída verificável. **Nada de generalizar para
patrimônio, receita, custo ou EBIT antes da Etapa 4.**

### Etapa 0 — Parar de afirmar o que não foi verificado
Barata, sem decisão de produto, sem mudar número publicado.

- **0.1** `conjunto_dourado.csv`: a linha `003891,2023,lucro_liquido_controladores` passa a
  `fonte_tipo = 'dfp_interno'`, com a pendência de confirmação externa registrada. A linha
  `lucro_liquido` continua `relatorio_anual` — essa **está** confirmada em documento.
- **0.2** `base_degenerada`: exigir valor presente em vez de `coalesce(...,0)=0`.
- **0.3** Substituir a diretriz "tolerância relativa, nunca absoluta" por **tolerância
  derivada da precisão publicada**, com as duas formas (intervalo de arredondamento quando a
  fonte publica arredondado; igualdade quando publica na unidade exata).

**Saída:** nenhuma afirmação do repositório sustentada por evidência de tipo diferente do
declarado. Build inalterado, nenhum número publicado muda.

### Etapa 1 — Contrato dos indicadores
Registrar, por indicador: significado, numerador, denominador, base, período, aplicabilidade,
comportamento diante de **ausência**, de **zero reportado** e de **conflito**, e o tipo de
fonte que o sustenta.

**Entram na Etapa 1, e não na 6** (correção pedida pela segunda revisão — deixá-las para
o fim obrigaria a refazer a resolução):
- **Temporalidade**: qual série cada coluna representa — valor reapresentado ou valor
  conhecido na data. O projeto já tem `safra_original`; falta o contrato dizer a qual
  série cada coluna pertence, e uma recuperação documental feita hoje **não pode
  aparecer como se já fosse conhecida no passado**.
- **Grão documental**: documento, versão, base e período inicial e final fazem parte do
  contexto de todo valor publicado.
- **Matriz inicial** indicador → componentes → fontes → validação, ainda que a
  implementação seja gradual. Escopo mínimo: `lucro_liquido`, `lucro_liquido_controladores`,
`patrimonio_liquido`, `patrimonio_liquido_controladores`, `margem_liquida`, `roe`.

Cada regra ganha **identificador** (`R-LUC-001`) usado no código, no teste e no registro da
decisão, para que "por que este número?" se responda sem reconstruir conversa.

**Saída:** nenhum campo com definição implícita ou fallback que mude seu significado.

### Etapa 2 — Aplicar o contrato onde ele já contradiz o código `[DECISÃO]`
`margem_liquida` e `roe` passam a ser estritos: NULL quando o componente contratado falta.
`margem_liquida_consolidada` e `roe_consolidado` continuam sendo as versões consolidadas.

**Alcance medido: 3.544 fichas perdem `margem_liquida`** e passam a depender da coluna
consolidada. Muda números publicados — **é decisão do mantenedor**, não minha.

**Saída:** numerador, denominador, base e período compatíveis e explicitados em cada coluna.

### Etapa 3 — Diagnóstico documental das ocorrências abertas
Sem concluir defeito por comparação estrutural.

- **3.1** Bases zeradas (7 fichas). TIM 2024 já rastreada até o raw (§1.2 R2). Repetir para
  Rio Paranapanema 2024/2025, CLI Sul 2025, Celgpar 2022/2023 e TIM 2025, classificando cada
  uma como erro de ingestão, arquivo defeituoso com documento correto, consolidado
  inaplicável, ou evidência insuficiente.
- **3.2** `CONTRADICAO_DRE_BPP` (10 fichas). Buscar DMPL e notas. Saldo final de participação
  e resultado atribuído no exercício são medidas diferentes: sem documento, a classificação
  permanece suspeita e não vira conclusão.
- **3.3** Confirmar externamente a cisão da Alfa (23.044 / 18.578 / 4.466). A publicação de
  demonstrações não foi acessível deste ambiente; o resumo da administração confirma só o
  total consolidado.

**Saída:** cada ocorrência com causa demonstrada ou pendência delimitada, com próxima
evidência nomeada.

### Etapa 4 — Resolução com linhagem completa
Separar geração de candidatos, validação, escolha e publicação numa etapa anterior ao pivot,
registrando candidatos considerados e rejeitados, regra aplicada, documento e versão, base,
período inicial e final.

**Saída:** valor publicado com contexto completo e rastreabilidade; ambiguidade não
desempatada arbitrariamente.

### Etapa 5 — Generalizar por família, uma de cada vez
Patrimônio líquido primeiro (2.03 / 2.05 / 2.07 / 2.08 e os respectivos minoritários), com
validação própria incluindo casos que não orientaram a implementação. Depois receita, custo e
EBIT.

### Etapa 6 — Matriz indicador → componentes → fontes → validação
É ela que decide as próximas ingestões, e não o contrário. ITR, FRE, preços, quantidade de
ações e proventos entram quando um indicador contratado os exigir.

Aqui também se decide o significado de **histórico**: série reapresentada contra série
conhecida na data. O projeto já tem `safra_original`; falta o contrato dizer a qual série
cada coluna pertence.

---

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
