{{ config(materialized='table') }}

with dfp as (

    select *
    from {{ ref('int_dfp_unificado') }}

),


cadastro as (

    select
        cd_cvm,
        dt_referencia,
        versao,
        dt_recebimento
    from {{ ref('int_cadastro_documentos') }}
    qualify row_number() over (
        partition by cd_cvm, dt_referencia, versao
        order by dt_recebimento desc
    ) = 1

),

fundamentos as (

    select
        dfp.*,

        year(dfp.dt_fim_exercicio) as ano_exercicio,

        dfp.ordem_exercicio = 'ÚLTIMO' as safra_original,

        cadastro.dt_recebimento

    from dfp

    left join cadastro
        on dfp.cd_cvm = cadastro.cd_cvm
       and dfp.dt_referencia = cadastro.dt_referencia
       and dfp.versao = cadastro.versao

)

select *
from fundamentos
