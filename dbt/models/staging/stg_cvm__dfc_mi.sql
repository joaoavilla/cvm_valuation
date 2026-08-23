with

con as (
    select *, 'CONSOLIDADO' as tipo_df
    from {{ source('cvm_dfp_raw', 'dfc_mi_con') }}
),

ind as (
    select *, 'INDIVIDUAL' as tipo_df
    from {{ source('cvm_dfp_raw', 'dfc_mi_ind') }}
),

unificado as (
    select * from con
    union all
    select * from ind
),

transformado as (
    select
        CNPJ_CIA                               as cnpj,
        CD_CVM                                 as cd_cvm,
        DENOM_CIA                              as razao_social,
        tipo_df,
        cast(VERSAO as integer)                as versao,
        cast(DT_REFER as date)                 as dt_referencia,
        ORDEM_EXERC                            as ordem_exercicio,
        cast(DT_INI_EXERC as date)             as dt_inicio_exercicio,
        cast(DT_FIM_EXERC as date)             as dt_fim_exercicio,
        CD_CONTA                               as cd_conta,
        DS_CONTA                               as ds_conta,
        ST_CONTA_FIXA = 'S'                    as conta_fixa,
        cast(VL_CONTA as double)
          * case ESCALA_MOEDA
              when 'MIL' then 1000
              when 'UNIDADE' then 1
            end                                as valor
    from unificado
)

select *
from transformado
qualify row_number() over (
    partition by
        cd_cvm,
        tipo_df,
        dt_referencia,
        cd_conta,
        ordem_exercicio
    order by valor
) = 1