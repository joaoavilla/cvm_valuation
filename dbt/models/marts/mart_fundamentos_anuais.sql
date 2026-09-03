{{ config(materialized='table') }}

with fatos as (

    select
        f.cd_cvm,
        f.razao_social,
        f.dt_fim_exercicio,
        f.ano_exercicio,
        f.tipo_df,
        f.dt_referencia,
        f.dt_recebimento,
        f.valor,
        s.conceito

    from {{ ref('fct_fundamentos') }} as f

    inner join {{ ref('contas_canonicas') }} as s
        on  f.demonstrativo = s.demonstrativo
        and f.cd_conta      = s.cd_conta
        and f.ds_conta      = s.ds_conta

    where f.safra_original

),

selecionado as (

    select f.*

    from fatos as f

    inner join {{ ref('int_empresas_tipo_df') }} as p
        on  f.cd_cvm           = p.cd_cvm
        and f.dt_fim_exercicio = p.dt_fim_exercicio
        and f.tipo_df          = p.tipo_df_escolhido

),

pivotado as (

    select
        cd_cvm,
        dt_fim_exercicio,

        max(razao_social)                as razao_social,
        max(ano_exercicio)               as ano_exercicio,
        max(tipo_df)                     as tipo_df,
        max(dt_referencia)               as dt_referencia,
        max(dt_recebimento)              as dt_recebimento,

        bool_or(conceito like 'fin\_%' escape '\')  as flag_financeira,

        max(case when conceito = 'ativo_total'                 then valor end) as ativo_total,
        max(case when conceito = 'ativo_circulante'            then valor end) as ativo_circulante,
        max(case when conceito = 'caixa_e_equivalentes'        then valor end) as caixa_e_equivalentes,
        max(case when conceito = 'contas_a_receber'            then valor end) as contas_a_receber,
        max(case when conceito = 'estoques'                    then valor end) as estoques,
        max(case when conceito = 'passivo_total'               then valor end) as passivo_total,
        max(case when conceito = 'passivo_circulante'          then valor end) as passivo_circulante,
        max(case when conceito = 'patrimonio_liquido'          then valor end) as patrimonio_liquido,
        max(case when conceito = 'pl_minoritarios'             then valor end) as pl_minoritarios,
        max(case when conceito = 'fornecedores'                then valor end) as fornecedores,
        max(case when conceito = 'divida_bruta_circulante'     then valor end) as divida_bruta_circulante,
        max(case when conceito = 'divida_bruta_nao_circulante' then valor end) as divida_bruta_nao_circulante,

        max(case when conceito = 'receita_liquida'             then valor end) as receita_liquida,
        max(case when conceito = 'custo'                       then valor end) as custo,
        max(case when conceito = 'lucro_bruto'                 then valor end) as lucro_bruto,
        max(case when conceito = 'despesas_vendas'             then valor end) as despesas_vendas,
        max(case when conceito = 'despesas_administrativas'    then valor end) as despesas_administrativas,
        max(case when conceito = 'equivalencia_patrimonial'    then valor end) as equivalencia_patrimonial,
        max(case when conceito = 'ebit'                        then valor end) as ebit,
        max(case when conceito = 'resultado_financeiro'        then valor end) as resultado_financeiro,
        max(case when conceito = 'receitas_financeiras'        then valor end) as receitas_financeiras,
        max(case when conceito = 'despesas_financeiras'        then valor end) as despesas_financeiras,
        max(case when conceito = 'lucro_liquido'               then valor end) as lucro_liquido,
        max(case when conceito = 'lucro_liquido_controladores' then valor end) as lucro_liquido_controladores,

        max(case when conceito = 'fluxo_caixa_operacional'     then valor end) as fluxo_caixa_operacional

    from selecionado

    group by 1, 2

),

derivado as (

    select
        *,
        patrimonio_liquido - coalesce(pl_minoritarios, 0)          as patrimonio_liquido_controladores,
        coalesce(lucro_liquido_controladores, lucro_liquido)       as lucro_atribuivel,
        coalesce(divida_bruta_circulante, 0)
            + coalesce(divida_bruta_nao_circulante, 0)             as divida_bruta,
        coalesce(divida_bruta_circulante, 0)
            + coalesce(divida_bruta_nao_circulante, 0)
            - coalesce(caixa_e_equivalentes, 0)                    as divida_liquida

    from pivotado

)

select
    * exclude (lucro_atribuivel),

    lucro_atribuivel  / nullif(receita_liquida, 0)                   as margem_liquida,
    lucro_liquido     / nullif(receita_liquida, 0)                   as margem_liquida_consolidada,
    lucro_bruto       / nullif(receita_liquida, 0)                   as margem_bruta,
    ebit              / nullif(receita_liquida, 0)                   as margem_ebit,
    lucro_atribuivel  / nullif(patrimonio_liquido_controladores, 0)  as roe,
    lucro_liquido     / nullif(patrimonio_liquido, 0)                as roe_consolidado,
    lucro_liquido     / nullif(ativo_total, 0)                       as roa,
    ativo_circulante  / nullif(passivo_circulante, 0)                as liquidez_corrente,
    (ativo_circulante - coalesce(estoques, 0))
                      / nullif(passivo_circulante, 0)                as liquidez_seca,
    divida_liquida    / nullif(patrimonio_liquido_controladores, 0)  as alavancagem,
    ebit              / nullif(abs(despesas_financeiras), 0)         as cobertura_juros,
    receita_liquida   / nullif(ativo_total, 0)                       as giro_ativo

from derivado
