-- Grão de uma linha de demonstrativo da CVM.
--
-- `ds_conta` entra na chave porque `cd_conta` não determina significado: o mesmo código
-- carrega contas diferentes entre planos e épocas. Medidos 26 grupos em que duas contas de
-- nome distinto dividiam o mesmo código no mesmo documento — no grão anterior, sem
-- `ds_conta`, uma delas era descartada e este teste passava assim mesmo.

select
    cd_cvm,
    tipo_df,
    dt_referencia,
    versao,
    ordem_exercicio,
    dt_inicio_exercicio,
    cd_conta,
    ds_conta,
    count(*) as n_linhas

from {{ ref('stg_cvm__dfc_md') }}

group by all
having count(*) > 1
