select
    cd_cvm,
    dt_referencia,
    tipo_df,
    cd_conta,
    ordem_exercicio,
    count(*) as n_linhas

from {{ ref('stg_cvm__dfc_md') }}

group by 1, 2, 3, 4, 5
having count(*) > 1
