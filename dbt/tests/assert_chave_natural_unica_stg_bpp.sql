select
    cd_cvm,
    tipo_df,
    dt_referencia,
    cd_conta,
    ordem_exercicio,
    count(*) as n_linhas

from {{ ref('stg_cvm__bpp') }}

group by 1, 2, 3, 4, 5
having count(*) > 1