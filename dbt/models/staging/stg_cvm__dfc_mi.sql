-- Staging da DFC_MI consolidada (DFP 2010-2024).
-- Contrato da camada: renomear, tipar, nada de lógica de negócio.

with fonte as (

    select * from {{ source('cvm_dfp_raw', 'dfc_mi') }}

),

renomeado as (

    select
        -- identidade da empresa
        CNPJ_CIA                          as cnpj,
        CD_CVM                            as cd_cvm,          -- zero-padded, 6 dígitos: MANTER como texto
        DENOM_CIA                         as razao_social,

        -- dimensão temporal (a incompleta — DT_INI/DT_FIM entram com a nova ingestão, Guia 2)
        cast(DT_REFER as date)            as dt_referencia,
        ORDEM_EXERC                       as ordem_exercicio, -- 'ÚLTIMO' | 'PENÚLTIMO'

        -- plano de contas
        CD_CONTA                          as cd_conta,
        DS_CONTA                          as ds_conta,

        -- valores
        ESCALA_MOEDA                      as escala_moeda,
        cast(VL_CONTA as double)          as valor_original,
        cast(VL_CONTA_REAL as double)     as valor            -- já normalizado p/ reais pelo pipeline legado

        -- GRUPO_DFP omitido de propósito: o pipeline legado o sobrescreveu com um valor
        -- constante por arquivo ('DRE'); o TIPO_DF verdadeiro entra com a nova ingestão (Guia 2)

    from fonte

),

deduplicado as (

    select *

    from renomeado

    qualify
        row_number() over (
            partition by
                cd_cvm,
                dt_referencia,
                cd_conta,
                ordem_exercicio
            order by valor
        ) = 1

)

select * from deduplicado
