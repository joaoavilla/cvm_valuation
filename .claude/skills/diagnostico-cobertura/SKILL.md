---
name: diagnostico-cobertura
description: Mede cobertura de indicadores quebrando por coorte para revelar grupos com dado ausente que a média esconde. Use antes de publicar um indicador, ao investigar valores nulos ou zerados, ou como verificação periódica de saúde do mart.
---

# Diagnóstico de cobertura por coorte

Uma métrica de cobertura calculada sobre a população inteira pode ser alta e verdadeira
enquanto uma coorte inteira está quebrada. Neste repositório, "100% das não-financeiras têm
patrimônio líquido" era verdade — e escondia que quatro em cada cinco instituições financeiras
não tinham. O denominador excluía o grupo defeituoso.

**Regra:** nunca reporte cobertura sem quebrar por coorte.

## As coortes que importam aqui

| Coorte | Por que separa | Como identificar |
|---|---|---|
| Financeira vs. não-financeira | Planos de contas distintos, códigos com significados diferentes | `flag_financeira` |
| Plano de contas | Padrão, financeiro, seguradora, legado, deslocado | coluna `plano` em `contas_canonicas` |
| Época | O plano mudou com a convergência a IFRS | faixas de `ano_exercicio` |
| Base | Consolidado vs. individual | `tipo_df` |
| Exercício social | Empresas com fechamento fora de dezembro | `month(dt_fim_exercicio) != 12` |

## Procedimento

### 1. Cobertura da métrica, por coorte e por ano

```python
import duckdb
c = duckdb.connect("warehouse.duckdb", read_only=True)
c.sql("""
select ano_exercicio,
  count(*) filter (not flag_financeira)                                        as nao_fin,
  count(*) filter (not flag_financeira and <coluna> is not null)               as nao_fin_ok,
  count(*) filter (flag_financeira)                                            as fin,
  count(*) filter (flag_financeira and <coluna> is not null)                   as fin_ok
from mart_fundamentos_anuais
where ano_exercicio >= 2015
group by 1 order by 1
""").show()
```

Procure por **degraus**: uma coorte que cai de um ano para o outro indica mudança de plano de
contas na fonte, não deterioração gradual.

### 2. Cobertura de todas as colunas de uma vez

```python
cols = [r[0] for r in c.sql("describe mart_fundamentos_anuais").fetchall()]
alvo = [x for x in cols if x not in ("cd_cvm","dt_fim_exercicio","razao_social",
                                     "ano_exercicio","tipo_df","dt_referencia",
                                     "dt_recebimento","flag_financeira")]
sel = ", ".join(f"count({x})*100.0/count(*) as {x}" for x in alvo)
c.sql(f"select flag_financeira, count(*) n, {sel} from mart_fundamentos_anuais group by 1").show()
```

### 3. Distinga os três estados

Não basta contar nulos. Separe:

| Estado | Significado | Como detectar |
|---|---|---|
| **Ausente** | O pipeline não encontrou o dado | `is null` |
| **Zero reportado** | A fonte trouxe a linha com valor zero | valor `= 0` com o pai diferente de zero |
| **Zero legítimo** | A empresa realmente não tem aquilo | valor `= 0` e o contexto confirma |

O segundo é o perigoso: parece dado e não é. Um indicador derivado sobre ele publica zero com
aparência de medição.

### 4. Cobertura do mapeamento de contas

```sql
select
  count(*)                                  as linhas_conta_fixa,
  count(*) filter (s.conceito is not null)  as com_conceito,
  round(100.0*count(*) filter (s.conceito is not null)/count(*), 1) as pct
from int_dfp_unificado f
left join contas_canonicas s
  on f.demonstrativo=s.demonstrativo and f.cd_conta=s.cd_conta and f.ds_conta=s.ds_conta
where f.conta_fixa
```

Cobertura baixa aqui não é defeito por si: o seed mapeia apenas os conceitos que os indicadores
usam. É um indicador de **território disponível**, não de erro.

### 5. Deriva entre execuções

Depois de reingerir, compare a cobertura com a execução anterior. Queda em qualquer coorte
significa que a fonte mudou de esquema ou que uma descrição deixou de casar — as duas exigem
investigação antes de publicar.

## Critérios de saída

- Nenhuma cobertura foi reportada sem quebra por coorte.
- Degraus entre anos foram investigados até a causa na fonte.
- Ausência, zero reportado e zero legítimo foram separados.
- Quedas em relação à execução anterior foram explicadas.
