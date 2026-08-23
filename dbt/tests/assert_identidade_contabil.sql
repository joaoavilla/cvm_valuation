with ativo as (

    select
        cd_cvm,
        tipo_df,
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
        tipo_df,
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
        a.tipo_df,
        a.dt_referencia,
        a.ativo,
        p.passivo_mais_pl,
        a.ativo - p.passivo_mais_pl as diferenca

    from ativo a

    inner join passivo p
        on a.cd_cvm = p.cd_cvm
        and a.tipo_df = p.tipo_df
        and a.dt_referencia = p.dt_referencia

)

select *
from comparacao
where abs(diferenca) > 1000

-- Exceções conhecidas na fonte CVM, verificadas em 2026-08-21.
-- 019364 ITAPEBI, 2021, INDIVIDUAL:
-- conta 2 não incorpora o PL (2.03); a diferença de R$ 369.675.000
-- corresponde exatamente ao PL e o balanço reconstruído fecha.
and not (
    cd_cvm = '019364'
    and dt_referencia = date '2021-12-31'
    and tipo_df = 'INDIVIDUAL'
)

-- 026557 DATORA, 2021, INDIVIDUAL:
-- divergência de R$ 28.000 confirmada também na fonte bruta.
and not (
    cd_cvm = '026557'
    and dt_referencia = date '2021-12-31'
    and tipo_df = 'INDIVIDUAL'
)