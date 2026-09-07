{#
  Balanço Patrimonial Ativo unificado. Fotografia: não tem DT_INI_EXERC.

  GRÃO: (cd_cvm, tipo_df, dt_referencia, versao, ordem_exercicio, cd_conta, ds_conta).

  `ds_conta` faz parte do grão porque `cd_conta` NÃO determina significado — é o princípio
  central deste repositório, e o grão anterior o contrariava. Medido em 2026-09-06 sobre os
  cinco demonstrativos: 26 grupos em que duas contas de nome diferente dividem o mesmo código
  no mesmo documento e uma delas era descartada em silêncio. Exemplo: HAPVIDA 2019, BPA
  1.02.01.10.05, "Depósitos judiciais" (R$ 187,6 mi) e "Outros ativos" (R$ 45,9 mi) —
  a segunda desaparecia.

  VALOR CONTRADITÓRIO NA FONTE VIRA AUSÊNCIA, NÃO DESEMPATE.
  O modelo anterior fazia `qualify row_number() over (... order by valor) = 1`, que:
    (a) escolhia o MENOR valor, o que não é regra contábil nenhuma;
    (b) não é ordenação total — empates eram resolvidos pela ordem física do arquivo, então
        a mesma fonte reordenada produzia warehouse diferente;
    (c) descartava em silêncio.
  Medido: 37.665 linhas descartadas no grão antigo; em 135 grupos os valores descartados eram
  DIFERENTES do escolhido, e 34 desses grupos casavam com o seed, ou seja, chegavam ao mart.
  Casos concretos: BRADSAÚDE 2023 publicava EBIT 0 no lugar de R$ 646,1 mi; AUTOMOB 2023
  publicava prejuízo de R$ 177,6 mi no lugar de lucro de R$ 89,4 mi (troca de sinal).
  No grão corrigido restam 127 conflitos genuínos da fonte — a mesma chave com dois valores.
  Para esses, `valor` é NULL e `status_valor` = 'CONFLITO_FONTE' (AGENTS.md §5: ou existe
  regra explícita de resolução, ou o caso vai para quarentena).
#}

with

con as (
    select *, 'CONSOLIDADO' as tipo_df
    from {{ source('cvm_dfp_raw', 'bpa_con') }}
),

ind as (
    select *, 'INDIVIDUAL' as tipo_df
    from {{ source('cvm_dfp_raw', 'bpa_ind') }}
),

unificado as (
    select * from con
    union all
    select * from ind
),

transformado as (
    select
        CNPJ_CIA                           as cnpj,
        CD_CVM                             as cd_cvm,
        DENOM_CIA                          as razao_social,
        tipo_df,
        cast(VERSAO as integer)            as versao,
        cast(DT_REFER as date)             as dt_referencia,
        ORDEM_EXERC                        as ordem_exercicio,

        cast(DT_FIM_EXERC as date)         as dt_fim_exercicio,
        CD_CONTA                           as cd_conta,
        DS_CONTA                           as ds_conta,
        ST_CONTA_FIXA = 'S'                as conta_fixa,
        {{ unidade_da_conta('BPA', 'CD_CONTA') }}                        as unidade,
        ESCALA_MOEDA                       as escala_moeda,
        {{ valor_em_reais('BPA', 'CD_CONTA', 'ESCALA_MOEDA', 'VL_CONTA') }} as valor
    from unificado
),

resolvido as (
    select
        cnpj,
        cd_cvm,
        razao_social,
        tipo_df,
        versao,
        dt_referencia,
        ordem_exercicio,

        dt_fim_exercicio,
        cd_conta,
        ds_conta,
        conta_fixa,
        unidade,

        -- `escala_moeda` sobe ao fato para tornar AUDITÁVEL a contradição de etiqueta
        -- entre safras: a mesma conta e período reportados em dois documentos com
        -- `ESCALA_MOEDA` diferente e `VL_CONTA` idêntico. Sem esta coluna o defeito não é
        -- escrevível fora do raw. `max()` aqui lê uma constante, não escolhe entre
        -- alternativas: a escala é atributo do documento e é uniforme dentro dele
        -- (medido: 10.847 de 10.847 documentos com uma única escala), e o grão é mais
        -- fino que o documento.
        max(escala_moeda)                                       as escala_moeda,

        count(*)                                                as n_linhas_fonte,
        count(distinct valor)                                   as n_valores_distintos,

        case when count(distinct valor) = 1 then max(valor) end as valor,

        case
            when count(distinct valor) = 1 then 'OK'
            when count(distinct valor) = 0 then 'ESCALA_DESCONHECIDA'
            else 'CONFLITO_FONTE'
        end                                                     as status_valor

    from transformado

    group by
        cnpj, cd_cvm, razao_social, tipo_df, versao, dt_referencia, ordem_exercicio,
        dt_fim_exercicio, cd_conta, ds_conta, conta_fixa, unidade
)

select * from resolvido
