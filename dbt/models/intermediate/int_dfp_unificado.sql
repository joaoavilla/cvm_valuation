{{ config(materialized='table') }}

select
    'DRE' as demonstrativo,
    cnpj,
    cd_cvm,
    razao_social,
    tipo_df,
    versao,
    dt_referencia,
    ordem_exercicio,
    dt_inicio_exercicio,
    dt_fim_exercicio,
    cd_conta,
    ds_conta,
    conta_fixa,
    valor
from {{ ref('stg_cvm__dre') }}

union all

select
    'BPA' as demonstrativo,
    cnpj,
    cd_cvm,
    razao_social,
    tipo_df,
    versao,
    dt_referencia,
    ordem_exercicio,
    cast(null as date) as dt_inicio_exercicio,
    dt_fim_exercicio,
    cd_conta,
    ds_conta,
    conta_fixa,
    valor
from {{ ref('stg_cvm__bpa') }}

union all

select
    'BPP' as demonstrativo,
    cnpj,
    cd_cvm,
    razao_social,
    tipo_df,
    versao,
    dt_referencia,
    ordem_exercicio,
    cast(null as date) as dt_inicio_exercicio,
    dt_fim_exercicio,
    cd_conta,
    ds_conta,
    conta_fixa,
    valor
from {{ ref('stg_cvm__bpp') }}

union all

select
    'DFC_MI' as demonstrativo,
    cnpj,
    cd_cvm,
    razao_social,
    tipo_df,
    versao,
    dt_referencia,
    ordem_exercicio,
    dt_inicio_exercicio,
    dt_fim_exercicio,
    cd_conta,
    ds_conta,
    conta_fixa,
    valor
from {{ ref('stg_cvm__dfc_mi') }}

union all

select
    'DFC_MD' as demonstrativo,
    cnpj,
    cd_cvm,
    razao_social,
    tipo_df,
    versao,
    dt_referencia,
    ordem_exercicio,
    dt_inicio_exercicio,
    dt_fim_exercicio,
    cd_conta,
    ds_conta,
    conta_fixa,
    valor
from {{ ref('stg_cvm__dfc_md') }}