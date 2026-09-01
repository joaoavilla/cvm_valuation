{{ config(materialized='table') }}

with original as (

    select
        cd_cvm, razao_social, demonstrativo, tipo_df, cd_conta, ds_conta,
        dt_fim_exercicio, ano_exercicio, dt_referencia, valor, dt_recebimento
    from {{ ref('fct_fundamentos') }}
    where safra_original = true

),

revisado as (

    select
        cd_cvm, demonstrativo, tipo_df, cd_conta, ds_conta,
        dt_fim_exercicio, dt_referencia, valor, dt_recebimento
    from {{ ref('fct_fundamentos') }}
    where safra_original = false

),

conceito as (

    select demonstrativo, cd_conta, ds_conta, conceito, plano
    from {{ ref('contas_canonicas') }}

),

comparacao as (

    select
        original.cd_cvm,
        original.razao_social,
        original.demonstrativo,
        original.tipo_df,
        original.cd_conta,

        original.ds_conta as ds_conta_original,
        revisado.ds_conta as ds_conta_revisada,

        original.dt_fim_exercicio,
        original.ano_exercicio,

        original.dt_referencia as dt_referencia_original,
        revisado.dt_referencia as dt_referencia_revisada,

        original.valor as valor_original,
        revisado.valor as valor_revisado,

        revisado.valor - original.valor as dif_absoluta,

        case
            when original.valor = 0 then null
            else (revisado.valor - original.valor) / abs(original.valor)
        end as dif_pct,

        original.dt_recebimento as dt_receb_original,
        revisado.dt_recebimento as dt_receb_revisado,

        conceito_original.conceito as conceito_original,
        conceito_revisado.conceito as conceito_revisado,
        conceito_original.plano    as plano_original,
        conceito_revisado.plano    as plano_revisado

    from original

    inner join revisado
        on  original.cd_cvm           = revisado.cd_cvm
       and  original.tipo_df          = revisado.tipo_df
       and  original.demonstrativo    = revisado.demonstrativo
       and  original.cd_conta         = revisado.cd_conta
       and  original.dt_fim_exercicio = revisado.dt_fim_exercicio

    left join conceito as conceito_original
        on  conceito_original.demonstrativo = original.demonstrativo
       and  conceito_original.cd_conta      = original.cd_conta
       and  conceito_original.ds_conta      = original.ds_conta

    left join conceito as conceito_revisado
        on  conceito_revisado.demonstrativo = revisado.demonstrativo
       and  conceito_revisado.cd_conta      = revisado.cd_conta
       and  conceito_revisado.ds_conta      = revisado.ds_conta

),

sinalizado as (

    select
        comparacao.*,

        ds_conta_original is not distinct from ds_conta_revisada
            as mesma_descricao,

        regexp_replace(lower(strip_accents(ds_conta_original)), '[^a-z0-9]', '', 'g')
          is not distinct from
        regexp_replace(lower(strip_accents(ds_conta_revisada)), '[^a-z0-9]', '', 'g')
            as mesma_descricao_normalizada,

        case
            when conceito_original is null or conceito_revisado is null then null
            else conceito_original = conceito_revisado
        end as mesmo_conceito

    from comparacao

)

select
    sinalizado.*,

    case
        when mesmo_conceito is not null  then mesmo_conceito
        when mesma_descricao_normalizada then true
        else null
    end as comparavel

from sinalizado
