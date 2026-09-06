{{ config(severity = 'warn') }}

-- Quarentena: linhas em que a CVM publica DOIS valores para a mesma conta no mesmo documento.
--
-- POR QUE ESTE TESTE FOI REESCRITO
-- A versão anterior lia os `stg_cvm__*` DEPOIS da deduplicação e agrupava pela mesma chave
-- que o dedup usava para deixar uma linha só. `count(distinct valor)` era 1 por construção:
-- o teste não podia falhar. Ele media o resultado do desempate, não o desempate.
--
-- Agora o staging não desempata mais: quando a fonte se contradiz, `valor` é NULL e
-- `status_valor` = 'CONFLITO_FONTE'. Este teste expõe esses casos.
--
-- Medido em 2026-09-06: 127 linhas, concentradas em 2022 (20, 4 empresas), 2023 (102, 6) e
-- 2024 (5, 1). 36 delas casam com o seed e portanto afetariam o mart — que agora recebe NULL
-- em vez do menor dos dois valores. Casos: BRADSAÚDE 2023 (EBIT 0 vs R$ 646,1 mi),
-- AUTOMOB 2023 (lucro -R$ 177,6 mi vs +R$ 89,4 mi), RIO ALTO 2022 (FCO 0 vs R$ 485,9 mi).
--
-- É WARN e não ERROR porque o defeito é da fonte e não temos regra contábil que o resolva.
-- O que o projeto controla é não inventar um número: a quarentena é a resposta correta.
-- Se a contagem crescer, a fonte piorou — e isso precisa ser visto, não absorvido.

{% set demonstrativos = ['dre', 'bpa', 'bpp', 'dfc_mi', 'dfc_md'] %}

with linhas as (

    {% for d in demonstrativos %}
    select
        '{{ d | upper }}' as demonstrativo,
        cd_cvm, razao_social, tipo_df, dt_referencia, ordem_exercicio,
        cd_conta, ds_conta, n_linhas_fonte, n_valores_distintos
    from {{ ref('stg_cvm__' ~ d) }}
    where status_valor = 'CONFLITO_FONTE'
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

)

select * from linhas
