{# Selecao por data publica: corte antes da janela; empates nao elegem documento.
   Os candidatos permanecem no modelo de origem e na auditoria.
   Corte diario inclusivo; ausencia exige consultar historico e empates. #}
{% macro contexto_economico() -%}
    cd_cvm, tipo_df, demonstrativo, cd_conta, ds_conta, dt_inicio_exercicio, dt_fim_exercicio
{%- endmacro %}

{% macro selecionar_observacao_temporal(relacao, data=none, primeira=false) -%}
select * exclude (posicao_data, n_na_data)
from (
    select *,
        dense_rank() over (
            partition by {{ contexto_economico() }}
            order by dt_recebimento {% if primeira %}asc{% else %}desc{% endif %}
        ) as posicao_data,
        count(*) over (
            partition by {{ contexto_economico() }}, dt_recebimento
        ) as n_na_data
    from {{ relacao }}
    where dt_recebimento is not null
    {% if data is not none %}and dt_recebimento <= {{ data }}{% endif %}
)
where posicao_data = 1 and n_na_data = 1
{%- endmacro %}

{% macro observacao_vigente_em(relacao, data) -%}
{{ selecionar_observacao_temporal(relacao, data=data) }}
{%- endmacro %}

{% macro observacao_mais_recente(relacao) -%}
{{ selecionar_observacao_temporal(relacao) }}
{%- endmacro %}

{% macro primeira_observacao_preservada(relacao) -%}
{{ selecionar_observacao_temporal(relacao, primeira=true) }}
{%- endmacro %}
