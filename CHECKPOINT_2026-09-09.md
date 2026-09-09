# Checkpoint — janela de 2026-09-08/09

> Atualização de fechamento: consulte `PR_REVISAO_FINAL.md` para o resultado da
> validação final. As contagens abaixo documentam o checkpoint anterior.
> Os dois P1 foram corrigidos: corte anterior à janela e captura verificada/atômica.
> Empates temporais agora impedem seleção em todas as políticas, incluindo valores
> iguais. A resolução desses candidatos e a integração ao painel seguem pendentes.

Ponto de retomada **compacto e autossuficiente**. Quem chegar aqui não precisa de histórico de
conversa. Os três documentos que este aponta são a leitura obrigatória, nesta ordem:

1. `AGENTS.md` — contrato de engenharia (arquitetura, comandos, invariantes, definição de pronto)
2. `CONTRATOS.md` — **o que cada número significa**, com identificadores de regra (`R-*`)
3. `PROXIMA_SEQUENCIA.md` — a fila, com estado de cada etapa

O histórico longo está em `AUDITORIA_ACURACIA_CHECKPOINT.md`. Este arquivo é o resumo da
janela mais recente e o direcionamento.

---

## Estado

| | |
|---|---|
| Branch | `fix/auditoria-acuracia-independente`, **21 commits** à frente de `main`, **nunca publicada**, sem upstream |
| Backup | `backup/auditoria-antes-da-reescrita` (estado anterior à reescrita de histórico) |
| Suíte dbt | **PASS=150 · WARN=7 · ERROR=0** de 157 |
| pytest | **7 passed** |
| Âncora WEG 2023 | receita 3,25036e10 · consolidado 5,86762e9 · **controladores 5,73167e9** · margem 0,17634 · ROE 0,330506 |
| Conjunto dourado | 239 fichas · 189 TRAVA · 31 DEFEITO_ABERTO · 19 DIVERGENCIA_FONTE |

**Os 7 WARN são defeitos da fonte mantidos visíveis e sob contagem**, não testes quebrados:
`assert_escala_sem_contradicao` 8.325 · `assert_safra_original_nao_e_primeira_publicacao`
20.145 · `assert_dedup_sem_divergencia` 127 · `roe abs<100` 20 · `not_null ativo_total` 3 ·
`not_null ds_conta` 2 · `margem 0 com lucro≠0` 1.

Cobertura do mart (10.847 fichas): margem 8.333 · ROE 9.002 · dívida bruta 10.197 ·
liquidez seca 10.015 · alavancagem 8.820.

`status_lucro_controladores`: IDENTIDADE_OK 5.786 · SEM_SPLIT 4.529 · SPLIT_NAO_INFORMADO 421 ·
CONFLITO_FONTE 94 · CONTRADICAO_DRE_BPP 10 · BASE_DEGENERADA 7.

---

## O que esta janela fez

Cinco commits, todos motivados por **três rodadas de revisão externa independente**.

| Commit | Entrega |
|---|---|
| `2f0ab7b` | Saneia o registro: `R-PL-003` volta a hipótese, Klabin reconciliada, fundamentação da base individual corrigida |
| `c231c3b` | **Dívida, alavancagem e liquidez seca param de publicar ausência como zero**; renomeia `*_consolidad*` para `*_total` |
| `18c4cf6` | Fecha a seleção temporal como contrato; corrige uma afirmação que a medição não sustentava |
| `19fc177` | Atualiza a fila |
| `8a0eaf4` | **Rastreabilidade temporal mínima + piloto CELGPAR + preservação de captura na ingestão** |

### As correções funcionais, com número

**Dívida (`R-DIV-001`).** `divida_bruta` e `divida_liquida` eram somas de
`coalesce(componente, 0)`: 650 fichas publicavam **zero sem nenhum componente**, e 617 delas
são financeiras, que não usam essas contas. Outras 640 publicavam `alavancagem` sobre essa
dívida inexistente. Agora: os dois componentes presentes → calcula; nenhum → NULL/`AUSENTE`;
só um → NULL/`PARCIAL` (0 ocorrências hoje, a regra existe para não depender disso); zero
reportado continua zero. `divida_liquida` exige caixa válido.
Antes → depois: dívida 10.847 → **10.197**, alavancagem 9.461 → **8.820**, zeros sem
componente 650 → **0**.

**Liquidez seca (`R-DIV-002`).** Mesmo defeito, achado ao medir o anterior: com
`coalesce(estoques, 0)`, **284 fichas** publicavam `liquidez_seca` idêntica à corrente, sem
nada indicando. Agora 10.015.

**Seleção temporal (`R-TMP-007`).** Novo `int_observacoes_periodo` expõe todas as observações
de um período ordenadas por `dt_recebimento` — **100% preenchido** (8.563.240/8.563.240).
Três políticas: `vigente_em(data)`, mais recente, primeira preservada.

**Piloto CELGPAR (021393/2023).** As duas observações já estavam no acervo:
documento `2023-12-31` público em **2024-03-27** com `3.01 = 0` e `3.11 = 0`; documento
`2024-12-31` público em **2025-04-02** com `3.01 = 28.735.000` e `3.11 = 48.731.000`.
Comportamento medido: consulta em 2024-01-01 → *histórico insuficiente*; em 2025-04-01 → **0**;
em 2025-06-30 → **os valores corretivos**. O critério decisivo — *consulta anterior à
publicação nunca seleciona o valor corretivo* — está travado em `assert_selecao_temporal`.

**Preservação de captura.** `ingestion/download.py` passa a arquivar o ZIP anterior em
`_zips/_capturas/` quando o conteúdo muda, com o hash do conteúdo no nome. Protege dali para
a frente; **não recupera o que já foi destruído**.

### Renomeações
`margem_liquida_consolidada` → **`margem_liquida_total`** e `roe_consolidado` → **`roe_total`**.
A fórmula usa o lucro total da base **selecionada**, e em 4.529 fichas ela é INDIVIDUAL, onde
não há consolidação. Ler sempre junto de `tipo_df`.

---

## Três erros meus, corrigidos — leia antes de confiar em qualquer número

Esta janela existiu em boa parte para consertar afirmações minhas que a medição não
sustentava. O padrão é sempre o mesmo e vale como aviso.

1. **Exemplo da Klabin.** Registrei KLABIN 2025 como ficha com `pl_minoritarios = 0`
   publicando ROE 21,28%. Ela tem `pl_minoritarios = R$ 6.515.155.000`. O 21,28% é
   `1.678.211.000 / 7.885.946.000` — o ROE **de antes** da correção `R-IND-001`, ou seja
   ilustrava um defeito **já corrigido**. **Causa: incorporei um exemplo de agente sem
   remedi-lo eu mesmo.**
2. **"`versao` não é eixo temporal".** Escrevi que 0 de 492.814 chaves têm versão divergente.
   Não há divergência porque **o acervo só guarda uma versão de cada documento** — não porque
   coincidam. 22,4% dos documentos têm `versao > 1`.
3. **"53.630 originais recebidas depois".** Era "não antes". O correto: **20.145 depois**,
   33.485 no mesmo dia, 3.585.122 antes. O primeiro cálculo também usava grão grosso, sem
   `dt_inicio_exercicio`.

**Regras que decorrem, e que não são negociáveis:**
- Carimbe **commit + estado da árvore + `mtime` do warehouse** em toda medição.
- **Re-meça você mesmo** a alegação central que um agente trouxer, antes de escrevê-la.
- **Nunca reconstrua o warehouse enquanto alguém mede.** Aconteceu nesta janela e dois
  refutadores devolveram `refutado=true` com razão formal e conclusão errada.
- Grão grosso inventa e esconde ao mesmo tempo: 28,7% de artefato numa medição anterior.

---

## Decisões que são do mantenedor, não do executor

1. **`R-LUC-004` — pai em branco.** 3 fichas (FINANCEIRA ALFA 2021/2022, CESP 2022) publicam
   lucro zero enquanto os filhos do bloco somam valor não nulo, **confirmado em documento**
   (Proposta da Administração da Alfa, p. 17: 79.326 e 38.967 mil). A derivação
   `total = controladores + não controladores` é auditável. **Altera número publicado.**
2. **`BASE_DEGENERADA` — 7 fichas**, incluindo TIM 2024/2025 com receita e lucro zerados.
   O zero já está no arquivo da CVM (provado por sha256 do ZIP). Recuar para a base
   individual **está descartado**: a receita individual da CELGPAR é zero em 12 de 13 anos e
   o lucro da CLI SUL diverge −36% a −42%.
3. **Receita bancária: `3.01` contra `3.03`.** 620 fichas financeiras sem coluna de receita;
   trava 14 `DEFEITO_ABERTO`. Seis âncoras externas usam ao menos três definições.
4. **`R-PL-003`** — 126 fichas publicam ROE com `pl_minoritarios = 0` reportado enquanto a DRE
   declara minoritário. **É hipótese**: estoque de encerramento não determina fluxo anual
   (IAS 1 §106). Exemplo correto: CTEEP 2010. **Não ampliar o veto sem DMPL e notas.**

---

## Fila, em ordem

| # | Próximo passo | Pré-requisito |
|---|---|---|
| 1 | **Arquivar os 16 ZIPs atuais** para local seguro | ação operacional do mantenedor; o código já protege dali para a frente |
| 2 | Investigar `R-PL-003` com DMPL e notas, amostra das 126 | — |
| 3 | Registrar **data de incorporação ao warehouse** (3ª camada temporal) | — |
| 4 | Demais 6 fichas `BASE_DEGENERADA`, com o procedimento do piloto da TIM | — |
| 5 | Extrair a resolução para **antes do pivot**, com linhagem completa | contratos (feito) |
| 6 | Generalizar por família: PL, depois receita/custo/EBIT | item 5 |
| 7 | Matriz indicador → fontes decide ingestões novas | — |

**Não fazer:** generalizar antes do item 5 · reingerir antes do item 1 · usar ML antes de
existir referência revisada para avaliá-lo · ampliar vetos com base em hipótese.

---

## Ambiente

```bash
.venv/Scripts/python.exe -m pytest -q
cd dbt && ../.venv/Scripts/dbt.exe build
```
Warehouse sempre com `read_only=True`. Temporários no scratchpad da sessão, nunca na árvore.
`guias/` está no `.gitignore` — o que precisa acompanhar o clone fica na raiz.
