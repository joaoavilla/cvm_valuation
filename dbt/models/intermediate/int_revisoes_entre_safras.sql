{{ config(materialized='table') }}

with original as (

    select
        cd_cvm,
        razao_social,
        demonstrativo,
        tipo_df,
        cd_conta,
        ds_conta,
        dt_fim_exercicio,
        ano_exercicio,
        dt_referencia,
        valor,
        dt_recebimento
    from {{ ref('fct_fundamentos') }}
    where safra_original = true

),

revisado as (

    select
        cd_cvm,
        razao_social,
        demonstrativo,
        tipo_df,
        cd_conta,
        ds_conta,
        dt_fim_exercicio,
        ano_exercicio,
        dt_referencia,
        valor,
        dt_recebimento
    from {{ ref('fct_fundamentos') }}
    where safra_original = false

),

comparacao as (

    select
        original.cd_cvm,
        original.razao_social,
        original.demonstrativo,
        original.tipo_df,
        original.cd_conta,
        original.ds_conta,
        original.dt_fim_exercicio,
        original.ano_exercicio,

        original.dt_referencia as dt_referencia_original,
        revisado.dt_referencia as dt_referencia_revisada,

        original.valor as valor_original,
        revisado.valor as valor_revisado,

        revisado.valor - original.valor as dif_absoluta,

        case
            when original.valor = 0 then null
            else
                (revisado.valor - original.valor)
                / abs(original.valor)
        end as dif_pct,

        original.dt_recebimento as dt_receb_original,
        revisado.dt_recebimento as dt_receb_revisado

    from original

    inner join revisado
        on original.cd_cvm = revisado.cd_cvm
       and original.tipo_df = revisado.tipo_df
       and original.demonstrativo = revisado.demonstrativo
       and original.cd_conta = revisado.cd_conta
       and original.dt_fim_exercicio = revisado.dt_fim_exercicio

)

select *
from comparacao