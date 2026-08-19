select
    cd_cvm,
    dt_referencia,
    cd_conta,
    ordem_exercicio,
    count(*) as n_linhas

from {{ ref('stg_cvm__bpp') }}

group by 1, 2, 3, 4
having count(*) > 1