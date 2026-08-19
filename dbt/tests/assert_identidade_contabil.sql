with ativo as (

    select
        cd_cvm,
        dt_referencia,
        valor as ativo

    from {{ ref('stg_cvm__bpa') }}

    where
        cd_conta = '1'
        and ordem_exercicio = 'ÚLTIMO'

),

passivo as (

    select
        cd_cvm,
        dt_referencia,
        valor as passivo_mais_pl

    from {{ ref('stg_cvm__bpp') }}

    where
        cd_conta = '2'
        and ordem_exercicio = 'ÚLTIMO'

),

comparacao as (

    select
        a.cd_cvm,
        a.dt_referencia,
        a.ativo,
        p.passivo_mais_pl,
        a.ativo - p.passivo_mais_pl as diferenca

    from ativo a

    inner join passivo p
        on a.cd_cvm = p.cd_cvm
        and a.dt_referencia = p.dt_referencia

)

select *
from comparacao
where abs(diferenca) > 1000