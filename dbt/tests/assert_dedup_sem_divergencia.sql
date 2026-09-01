{{ config(severity = 'warn') }}

with linhas as (

    select
        'DRE'    as demonstrativo, cd_cvm, tipo_df, dt_referencia, cd_conta, ordem_exercicio, valor
    from {{ ref('stg_cvm__dre') }}
    union all
    select 'BPA', cd_cvm, tipo_df, dt_referencia, cd_conta, ordem_exercicio, valor
    from {{ ref('stg_cvm__bpa') }}
    union all
    select 'BPP', cd_cvm, tipo_df, dt_referencia, cd_conta, ordem_exercicio, valor
    from {{ ref('stg_cvm__bpp') }}
    union all
    select 'DFC_MI', cd_cvm, tipo_df, dt_referencia, cd_conta, ordem_exercicio, valor
    from {{ ref('stg_cvm__dfc_mi') }}
    union all
    select 'DFC_MD', cd_cvm, tipo_df, dt_referencia, cd_conta, ordem_exercicio, valor
    from {{ ref('stg_cvm__dfc_md') }}

),

bruto as (

    select
        demonstrativo, cd_cvm, tipo_df, dt_referencia, cd_conta, ordem_exercicio,
        count(*)                 as n_copias,
        count(distinct valor)    as n_valores_distintos,
        min(valor)               as valor_escolhido,
        max(valor)               as valor_descartado
    from linhas
    group by 1, 2, 3, 4, 5, 6

)

select *
from bruto
where n_valores_distintos > 1
