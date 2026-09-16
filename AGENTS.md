# AGENTS.md — cvm_valuation

Instruções para agentes de código (Claude Code, Codex, e outros que leiam este arquivo).
Este é o documento canônico. Configurações específicas de ferramentas são locais e não versionadas.

---

## 1. O que é este projeto

Plataforma de dados sobre as demonstrações financeiras das companhias abertas brasileiras
publicadas pela CVM. O diferencial técnico é a **modelagem bitemporal**: cada valor carrega
o período econômico a que se refere, o documento em que foi publicado e a data em que ficou
público — o que permite responder *"o que se sabia nesta data"* e *"quanto este número mudou
depois de divulgado"*.

Dados sob licença ODbL (atribuição e share-alike obrigatórios). Código sob MIT.

## 2. Arquitetura e responsabilidade de cada camada

```
ingestion/ (Python)     data/raw/ (Parquet)     dbt/ (SQL sobre DuckDB)      docs/ (Quarto)
─────────────────────────────────────────────────────────────────────────────────────────
transporta              espelho fiel            interpreta e testa           apresenta
não interpreta          tudo string             toda regra de negócio        só lê marts
```

| Camada | Responsabilidade | Não faz |
|---|---|---|
| `ingestion/` | Baixar, validar, extrair, registrar manifesto | Nenhuma transformação de valor |
| `data/raw/` | Um Parquet por CSV da fonte, esquema preservado | — |
| `dbt/models/staging/` | Tipagem, renomeação, escala monetária, deduplicação | Regra de negócio |
| `dbt/models/intermediate/` | Unificação, políticas explícitas, comparações entre safras | Cálculo de indicador |
| `dbt/models/marts/` | Grão de leitura, pivot de conceitos, indicadores | Acesso a source direto |
| `dbt/seeds/` | Tradução `(demonstrativo, código, descrição) → conceito` | Lógica |
| `docs/` | Site estático gerado por Quarto | Cálculo |

**Regra estrutural:** Python move dados; dbt transforma dados. Uma transformação em Python é
um desvio que precisa de justificativa explícita.

## 3. Ambiente e comandos

Windows. Ambiente virtual em `.venv/`. Use sempre os executáveis do venv.

```bash
# testes do código Python de ingestão
.venv/Scripts/python.exe -m pytest -q

# build completo: seeds, models e testes de dado, na ordem do DAG
cd dbt && ../.venv/Scripts/dbt.exe build

# subconjunto do DAG
cd dbt && ../.venv/Scripts/dbt.exe build --select +mart_fundamentos_anuais

# ingestão (ATENÇÃO: sobrescreve o raw — ver §6)
.venv/Scripts/python.exe -m ingestion --anos 2010-2025

# consulta ao warehouse
.venv/Scripts/python.exe -c "import duckdb; print(duckdb.connect('warehouse.duckdb', read_only=True).sql('select 1').fetchall())"
```

`store_failures` está ativo: linhas que violam um teste ficam em `main_dbt_test__audit.<nome_do_teste>`.

## 4. Invariantes do domínio

Estas afirmações devem continuar verdadeiras. Uma mudança que quebre qualquer uma delas
está errada até prova em contrário.

| Invariante | Onde é verificada |
|---|---|
| `Ativo = Passivo + Patrimônio Líquido` | `dbt/tests/assert_identidade_contabil.sql` (2 exceções nominais, defeito da fonte) |
| Cada tabela respeita o grão declarado | `dbt_utils.unique_combination_of_columns` nos `_*.yml` |
| Toda chave do seed existe no dado, byte a byte | `dbt/tests/assert_seed_contas_existe_no_dado.sql` |
| Instituição financeira não publica margem sobre receita não-financeira | `not (flag_financeira and margem_liquida is not null)` |
| A base escolhida é consolidada quando ela existe | `not (tem_consolidado and tipo_df_escolhido != 'CONSOLIDADO')` |
| Escala monetária desconhecida produz `NULL`, não silêncio | `case` sem `else` em `stg_cvm__*` + `not_null` em `valor` |

**Âncora de regressão ponta a ponta:** WEG (`cd_cvm = '005410'`), exercício 2023 —
receita R$ 32,50 bi · lucro consolidado R$ 5,87 bi · lucro dos controladores R$ 5,73 bi ·
margem 17,63% (controladores sobre receita) · validado contra
fonte externa em cinco exercícios. Se estes números mudarem, houve regressão.

## 5. Convenções

**Grão antes de SQL.** Todo model começa pela pergunta *"o que uma linha representa aqui?"*.
Se o grão não estiver declarado no `_*.yml` com um teste de unicidade, o model está incompleto.

**Ausência é `NULL`, nunca zero.** Em contabilidade `0` é um valor legítimo. Usar `0` como
padrão para "não encontrado" torna as duas coisas indistinguíveis a jusante. Indicadores
compostos expõem uma coluna `status_*` de completude.

**Nenhum desempate arbitrário decide significado.** `max()`, `min()` e `order by` de uma coluna
só não são regras contábeis. Quando houver mais de um candidato, ou existe regra explícita de
resolução, ou o caso vai para quarentena.

**Nomenclatura:** `stg_<fonte>__<entidade>` · `int_<assunto>` · `fct_<fato>` · `mart_<uso>` ·
colunas em snake_case e português, alinhadas ao vocabulário contábil da fonte.

**Uma definição, um lugar.** Uma regra de negócio (por exemplo, o que conta como "revisão
material") mora em um model e é consumida por análise, mart e site. Definições duplicadas
divergem — já ocorreu neste repositório.

## 6. Riscos conhecidos do ambiente

| Risco | Detalhe | Como evitar |
|---|---|---|
| **Ingestão destrói o histórico** | `ingestion` grava sempre no mesmo caminho e sobrescreve. A CVM reescreve arquivos de anos anteriores | Arquive `data/raw/dfp/_zips/` antes de rodar. Ver decisão D12 |
| **Views de staging dependem do diretório** | `stg_cvm__*` resolvem `../data/...` no momento da consulta; falham fora de `dbt/` | Consumidores externos leem apenas tabelas materializadas |
| **Warehouse é grande** | ~600 MB | Conecte com `read_only=True`; nunca use `SELECT *` sem limite em exploração |
| **`cd_conta` não determina significado** | O mesmo código tem contas diferentes entre planos e épocas | O seed é chaveado por `(demonstrativo, cd_conta, ds_conta)`. Nunca mapeie só por código |
| **`ano_exercicio` não é chave** | Empresas que mudaram o fim do exercício social têm dois fechamentos no mesmo ano civil | Use `dt_fim_exercicio` |
| **Cobertura agregada esconde coorte quebrada** | Uma métrica de 100% pode medir apenas a coorte saudável | Toda medida de cobertura é quebrada por coorte (plano, setor, ano) |

## 7. Como o trabalho é feito aqui

**O código é escrito pelo mantenedor.** O papel do agente é investigar, medir, propor contrato
e revisar — não implementar em silêncio. Entregue esqueleto com contrato e TODO onde há decisão
de projeto; entregue pronto o que for encanamento sem aprendizado.

**Não crie nem edite arquivos no repositório sem anunciar antes.** Arquivos temporários,
downloads e scripts de investigação vão para o diretório de scratchpad da sessão, nunca para a
árvore do projeto.

**Meça antes de afirmar.** Toda afirmação sobre o dado precisa do número e da consulta que o
produziu. Afirmação sem medição é a origem documentada da maioria dos defeitos deste
repositório. Quando não for possível medir, declare explicitamente que não foi medido.

**Generalize com cautela.** Confirmar uma hipótese em dois casos não a confirma no universo.
Quando publicar uma taxa, publique o denominador.

## 8. Definição de pronto

Uma mudança está pronta quando:

1. `pytest` passa (se tocou em `ingestion/` ou `scripts/`);
2. `dbt build` passa (se tocou em `dbt/`), com contagem de `PASS/WARN/ERROR` registrada;
3. o número que motivou a mudança foi medido antes e depois, e a diferença é a esperada;
4. a âncora de regressão da WEG continua reproduzindo;
5. se corrigiu um defeito de dado, existe um teste que falha sem a correção;
6. as decisões tomadas estão registradas com a razão.

## 9. Fluxo de trabalho

Uma frente por vez, cada etapa em sua própria branch, fechando com PR.

```
git switch main && git pull
git switch -c <fase>/<etapa>
# ... investigar → medir → propor → implementar → medir de novo
.venv/Scripts/python.exe -m pytest -q
cd dbt && ../.venv/Scripts/dbt.exe build
git add -A && git commit -m "<tipo>(<escopo>): <descrição no imperativo>"
```

Commits em português, sem acentos na primeira linha, no formato convencional
(`feat`, `fix`, `refactor`, `docs`, `ci`, `chore`).

## 10. Documentação de referência

| Arquivo | Conteúdo | Situação |
|---|---|---|
| `README.md` | Visão de produto e instruções de execução | versionado |
| `guias/NORTE.md` | Estado medido, decisões numeradas, roteiro de fases | **local — ver nota** |
| `guias/GUIA_04_ESPINHA_COMUM.md` | Guia da fase ativa, passo a passo | **local — ver nota** |
| `dbt/analyses/taxa_revisao.sql` | Receita oficial da métrica de revisão entre safras | versionado |

> **Nota:** `guias/` está em `.gitignore`, portanto não acompanha um clone. Este arquivo
> (`AGENTS.md`) é autossuficiente para o trabalho de engenharia; os guias acrescentam o
> histórico de decisão e o roteiro. A decisão de versioná-los está em aberto.

## 11. Fora de escopo

Não introduza sem discussão prévia: Spark, Kafka, Kubernetes, Iceberg/Delta, Airflow,
Postgres, frameworks de orquestração ou de qualidade de dados adicionais. O volume atual
(~8,5 M linhas no fato) não os justifica, e a decisão está registrada. Propostas de
infraestrutura precisam vir com a medição que as motiva.
