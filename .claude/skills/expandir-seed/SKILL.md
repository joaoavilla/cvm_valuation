---
name: expandir-seed
description: Acrescenta com segurança um conceito ou uma variante de descrição ao seed contas_canonicas.csv. Use quando pedirem um indicador novo, quando um conceito estiver ausente para alguma coorte, ou quando aparecer descrição de conta não mapeada.
---

# Expandir o mapeamento de contas

O seed traduz `(demonstrativo, cd_conta, ds_conta) → conceito`. É onde mora o **significado**
do produto: cada linha ausente é um indicador que não existe; cada linha errada é um número
errado publicado com aparência de correto.

**Premissa não negociável:** `cd_conta` não determina significado. O mesmo código tem contas
diferentes entre planos (padrão, financeiro, seguradora, legado, deslocado) e entre épocas.
Por isso a descrição faz parte da chave, casada por igualdade exata.

## Procedimento

### 1. Encontre o que falta, ranqueado por alcance

```sql
select f.demonstrativo, f.cd_conta, f.ds_conta,
       count(distinct f.cd_cvm) empresas,
       min(f.ano_exercicio) de, max(f.ano_exercicio) ate
from int_dfp_unificado f
left join contas_canonicas s
  on f.demonstrativo = s.demonstrativo
 and f.cd_conta      = s.cd_conta
 and f.ds_conta      = s.ds_conta
where f.conta_fixa and s.conceito is null and f.valor <> 0
group by 1,2,3
order by empresas desc
limit 30
```

Priorize por número de empresas. Um conceito que só existe para dez empresas raramente
justifica uma coluna no mart.

### 2. Verifique todas as variantes de descrição do mesmo código

```sql
select cd_conta, ds_conta, count(distinct cd_cvm) empresas
from int_dfp_unificado
where demonstrativo = '<DEM>' and cd_conta = '<CODIGO>' and conta_fixa
group by 1,2 order by empresas desc
```

Um código costuma ter várias descrições legítimas (maiúsculas, "Consolidado", plano bancário).
Cada uma precisa de sua própria linha. **Copie a descrição byte a byte do resultado da
consulta** — acento perdido já quebrou trinta chaves neste repositório.

### 3. Rejeite descrições corrompidas

A fonte contém lixo: descrições como `"0"`, `"A"` ou strings truncadas. Não as mapeie. O custo
é perder algumas linhas; o benefício é não promover lixo a conceito canônico.

### 4. Verifique conflito antes de gravar

Duas contas mapeando para o mesmo conceito na mesma empresa e exercício produzem ambiguidade
que o pivot resolve por desempate arbitrário. Meça antes:

```sql
with cand as (
  select f.cd_cvm, f.dt_fim_exercicio, s.conceito, f.cd_conta, f.valor
  from fct_fundamentos f
  join contas_canonicas s
    on f.demonstrativo = s.demonstrativo
   and f.cd_conta      = s.cd_conta
   and f.ds_conta      = s.ds_conta
  join int_empresas_tipo_df p
    on f.cd_cvm = p.cd_cvm and f.dt_fim_exercicio = p.dt_fim_exercicio
   and f.tipo_df = p.tipo_df_escolhido
  where f.safra_original
)
select conceito, count(*) grupos_ambiguos
from (
  select cd_cvm, dt_fim_exercicio, conceito,
         count(*) n, count(distinct valor) nv
  from cand group by 1,2,3
) where nv > 1
group by 1
```

Se o conceito novo criar grupos ambíguos, **não grave**. Ou escolha outra conta, ou defina
primeiro a regra explícita de resolução.

### 5. Não mapeie pai e filho para o mesmo conceito

`1.01` e `1.01.01` mapeados ambos para caixa somam duas vezes. Escolha um nível. Quando pai e
filhos existirem, prefira o pai: já foi medido que em centenas de exercícios os filhos vêm
zerados e só o pai carrega o valor.

### 6. Grave e valide

1. Acrescente a linha ao `dbt/seeds/contas_canonicas.csv`, mantendo a ordenação por
   `(demonstrativo, cd_conta, ds_conta)`.
2. Se o conceito for novo, acrescente-o à lista `accepted_values` em `dbt/seeds/_seeds.yml` —
   caso contrário o build falha.
3. Se o conceito deve aparecer no mart, acrescente a linha do pivot e, se for indicador
   derivado, a fórmula com `nullif` no denominador.

```bash
cd dbt && ../.venv/Scripts/dbt.exe build --select contas_canonicas+
```

### 7. Meça a cobertura por coorte

Cobertura global alta esconde coorte inteira ausente. Confira o conceito novo separando
financeiras de não-financeiras e por faixa de ano — foi assim que um plano contábil inteiro
ficou sem patrimônio líquido durante seis anos sem que nenhum teste acusasse.

## Critérios de saída

- Todas as variantes de descrição do código foram inspecionadas e mapeadas.
- Descrições foram copiadas exatamente da fonte.
- Zero grupos ambíguos criados.
- Nenhuma relação pai/filho duplicando valor.
- `dbt build` verde, com cobertura medida por coorte.
