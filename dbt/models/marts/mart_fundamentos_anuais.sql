{{ config(materialized='table') }}

-- Fundamentos anuais por empresa, prontos para leitura.
--
-- Grão: (cd_cvm, dt_fim_exercicio). NÃO é (cd_cvm, ano_exercicio) — 20 empresas
-- mudaram o fim do exercício social e têm dois fechamentos no mesmo ano civil.
-- `ano_exercicio` fica como coluna para filtro, nunca como chave.
--
-- Três filtros definem o conteúdo:
--   1. safra_original  -> só o valor como publicado no próprio documento do
--                         exercício, nunca o comparativo reapresentado depois
--   2. inner join seed -> só contas com conceito curado; descrição não mapeada
--                         vira ausência, não número errado
--   3. política con/ind -> uma base por exercício, escolhida explicitamente
--
-- Indicadores de margem saem NULL para instituições financeiras por construção:
-- a receita de banco é mapeada como `fin_receita_intermediacao`, conceito
-- distinto de `receita_liquida`, então o numerador simplesmente não existe.
-- Não há flag filtrando nada — o modelo de dados é que impede o número sem
-- sentido. `flag_financeira` fica apenas como informação ao consumidor.

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

        -- Presença de qualquer conceito do plano financeiro identifica o setor.
        bool_or(conceito like 'fin\_%' escape '\')  as flag_financeira,

        -- Balanço
        max(case when conceito = 'ativo_total'            then valor end) as ativo_total,
        max(case when conceito = 'ativo_circulante'       then valor end) as ativo_circulante,
        max(case when conceito = 'caixa_e_equivalentes'   then valor end) as caixa_e_equivalentes,
        max(case when conceito = 'passivo_total'          then valor end) as passivo_total,
        max(case when conceito = 'passivo_circulante'     then valor end) as passivo_circulante,
        max(case when conceito = 'patrimonio_liquido'     then valor end) as patrimonio_liquido,

        -- Resultado
        max(case when conceito = 'receita_liquida'        then valor end) as receita_liquida,
        max(case when conceito = 'custo'                  then valor end) as custo,
        max(case when conceito = 'lucro_bruto'            then valor end) as lucro_bruto,
        max(case when conceito = 'ebit'                   then valor end) as ebit,
        max(case when conceito = 'resultado_financeiro'   then valor end) as resultado_financeiro,
        max(case when conceito = 'lucro_liquido'          then valor end) as lucro_liquido,

        -- Caixa
        max(case when conceito = 'fluxo_caixa_operacional' then valor end) as fluxo_caixa_operacional

    from selecionado

    group by 1, 2

)

select
    *,

    -- nullif em todo denominador: empresa pré-operacional com receita zero
    -- ou PL zerado devolveria erro de divisão sem isso.
    lucro_liquido    / nullif(receita_liquida, 0)     as margem_liquida,
    lucro_bruto      / nullif(receita_liquida, 0)     as margem_bruta,
    ebit             / nullif(receita_liquida, 0)     as margem_ebit,
    lucro_liquido    / nullif(patrimonio_liquido, 0)  as roe,
    lucro_liquido    / nullif(ativo_total, 0)         as roa,
    ativo_circulante / nullif(passivo_circulante, 0)  as liquidez_corrente

from pivotado
