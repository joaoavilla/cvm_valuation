{{ config(materialized='table') }}

with base as (

    select *
    from {{ ref('mart_fundamentos_anuais') }}

),

percentis as (

    select
        cd_cvm,
        dt_fim_exercicio,
        case when margem_liquida is not null then
             percent_rank() over (
                 partition by ano_exercicio, (margem_liquida is null)
                 order by margem_liquida)
        end as pct_margem_liquida,
        case when roe is not null and patrimonio_liquido_controladores > 0 then
             percent_rank() over (
                 partition by ano_exercicio, (roe is null or patrimonio_liquido_controladores <= 0)
                 order by roe)
        end as pct_roe,
        case when liquidez_corrente is not null then
             percent_rank() over (
                 partition by ano_exercicio, (liquidez_corrente is null)
                 order by liquidez_corrente)
        end as pct_liquidez
    from base
    where not flag_financeira

),

revisao as (

    select
        cd_cvm,
        dt_fim_exercicio,
        count(*)                                                  as n_conceitos_revisados,
        max(abs(dif_pct))                                         as maior_revisao_pct,
        min(dt_referencia_revisada)                               as revisado_em
    from {{ ref('int_revisoes_entre_safras') }}
    where comparavel is true
      and abs(dif_pct) > 0.01
      and conceito_original in ('ativo_total', 'passivo_total', 'patrimonio_liquido',
                                'receita_liquida', 'lucro_liquido')
    group by 1, 2

)

select
    base.*,
    percentis.pct_margem_liquida,
    percentis.pct_roe,
    percentis.pct_liquidez,
    coalesce(revisao.n_conceitos_revisados, 0) as n_conceitos_revisados,
    revisao.maior_revisao_pct,
    revisao.revisado_em,
    revisao.cd_cvm is not null                 as teve_revisao_material

from base
left join percentis
    on  percentis.cd_cvm           = base.cd_cvm
   and  percentis.dt_fim_exercicio = base.dt_fim_exercicio
left join revisao
    on  revisao.cd_cvm           = base.cd_cvm
   and  revisao.dt_fim_exercicio = base.dt_fim_exercicio
