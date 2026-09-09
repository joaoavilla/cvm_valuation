{{ config(severity = 'warn') }}

select
    cd_cvm,
    tipo_df,
    demonstrativo,
    cd_conta,
    ds_conta,
    dt_inicio_exercicio,
    dt_fim_exercicio,
    dt_recebimento,
    count(*)                as n_observacoes,
    count(distinct valor)   as n_valores_distintos,
    min(valor)              as valor_min,
    max(valor)              as valor_max

from {{ ref('int_observacoes_periodo') }}

group by 1, 2, 3, 4, 5, 6, 7, 8

having count(*) > 1
