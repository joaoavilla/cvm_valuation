with base as (

    select distinct
        cd_cvm,
        dt_fim_exercicio,
        tipo_df

    from {{ ref('fct_fundamentos') }}

    where safra_original

),

politica as (

    select
        cd_cvm,
        dt_fim_exercicio,

        count(*)                            as n_tipos_disponiveis,
        bool_or(tipo_df = 'CONSOLIDADO')    as tem_consolidado,
        bool_or(tipo_df = 'INDIVIDUAL')     as tem_individual,

        case
            when bool_or(tipo_df = 'CONSOLIDADO') then 'CONSOLIDADO'
            else 'INDIVIDUAL'
        end                                 as tipo_df_escolhido

    from base

    group by 1, 2

)

select *
from politica
