{{ config(materialized='table') }}

{#
  Empilha os cinco demonstrativos num grão único.

  Escrito com laço Jinja em vez de cinco blocos copiados: os blocos precisam permanecer
  idênticos coluna a coluna, e cinco cópias divergem (AGENTS.md §5). BPA e BPP são
  fotografias e não têm DT_INI_EXERC — só esses dois recebem NULL na coluna.

  Colunas novas em relação à versão anterior: `unidade`, `status_valor` e
  `n_valores_distintos`, que sobem do staging para que a jusante seja possível distinguir
  "a fonte não disse" de "a fonte disse zero" e de "a fonte disse duas coisas".
#}

{% set demonstrativos = [
    ('DRE',    'stg_cvm__dre',    true),
    ('BPA',    'stg_cvm__bpa',    false),
    ('BPP',    'stg_cvm__bpp',    false),
    ('DFC_MI', 'stg_cvm__dfc_mi', true),
    ('DFC_MD', 'stg_cvm__dfc_md', true)
] %}

{% for nome, modelo, tem_inicio in demonstrativos %}
select
    '{{ nome }}' as demonstrativo,
    cnpj,
    cd_cvm,
    razao_social,
    tipo_df,
    versao,
    dt_referencia,
    ordem_exercicio,
    {% if tem_inicio %}dt_inicio_exercicio{% else %}cast(null as date) as dt_inicio_exercicio{% endif %},
    dt_fim_exercicio,
    cd_conta,
    ds_conta,
    conta_fixa,
    unidade,
    escala_moeda,
    n_valores_distintos,
    status_valor,
    valor
from {{ ref(modelo) }}

{% if not loop.last %}union all{% endif %}
{% endfor %}
