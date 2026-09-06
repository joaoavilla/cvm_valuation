-- `valor` e `status_valor` têm de contar a mesma história.
--
-- Um valor presente com status de conflito, ou um NULL com status OK, significa que a
-- quarentena furou e um número não auditado voltou ao pipeline. Este é o teste que impede
-- a correção de regredir para um desempate silencioso.

{% set demonstrativos = ['dre', 'bpa', 'bpp', 'dfc_mi', 'dfc_md'] %}

with linhas as (

    {% for d in demonstrativos %}
    select '{{ d | upper }}' as demonstrativo, cd_cvm, dt_referencia, cd_conta, ds_conta,
           valor, status_valor, n_valores_distintos
    from {{ ref('stg_cvm__' ~ d) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

)

select *
from linhas
where (status_valor = 'OK'  and valor is null)
   or (status_valor <> 'OK' and valor is not null)
   or (status_valor = 'OK'  and n_valores_distintos <> 1)
