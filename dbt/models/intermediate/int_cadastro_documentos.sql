{{ config(materialized='table') }}

select
    CD_CVM                  as cd_cvm,
    cast(DT_REFER as date)  as dt_referencia,
    cast(VERSAO as integer) as versao,
    cast(DT_RECEB as date)  as dt_recebimento
from {{ source('cvm_dfp_raw', 'cadastro') }}