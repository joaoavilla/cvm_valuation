-- O critério que separa uma pergunta histórica de uma pergunta sobre o presente:
--
--     Uma consulta anterior à publicação de uma correção NUNCA pode selecionar
--     o valor corretivo.
--
-- Caso documentado: CELGPAR (021393), exercício 2023, base consolidada. Duas observações
-- do MESMO período econômico, publicadas em momentos diferentes:
--
--   documento 2023-12-31 v1, público em 2024-03-27  ->  3.01 = 0          e 3.11 = 0
--   documento 2024-12-31 v2, público em 2025-04-02  ->  3.01 = 28.735.000 e 3.11 = 48.731.000
--
-- O bloco consolidado do primeiro documento veio inteiramente zerado na fonte, e a própria
-- CVM publicou a correção na safra seguinte.
--
-- ESTE TESTE CHAMA O MACRO QUE OS CONSUMIDORES CHAMAM. A versão anterior filtrava a data
-- no JOIN, antes da janela, e por isso passava enquanto o macro — que aplicava o corte
-- DEPOIS da janela — devolvia zero linha. Um teste que reimplementa a regra não protege a
-- regra: ele testa a si mesmo.
--
-- Quatro cortes, cobrindo as quatro situações que importam:
--   2024-01-01  antes da primeira publicação  -> NENHUMA linha (histórico insuficiente)
--   2025-04-01  antes da correção             -> o valor antigo
--   2025-04-02  NO DIA da correção            -> o valor corretivo (o corte é inclusivo)
--   2025-06-30  depois                        -> o valor corretivo

{% set filtro_do_caso %}
    cd_cvm = '021393'
    and tipo_df = 'CONSOLIDADO'
    and demonstrativo = 'DRE'
    and dt_fim_exercicio = date '2023-12-31'
    and cd_conta in ('3.01', '3.11')
{% endset %}

with base as (

    select * from {{ ref('int_observacoes_periodo') }} where {{ filtro_do_caso }}

),

antes_da_primeira as ( {{ observacao_vigente_em('base', "date '2024-01-01'") }} ),
antes_da_correcao as ( {{ observacao_vigente_em('base', "date '2025-04-01'") }} ),
no_dia_da_correcao as ( {{ observacao_vigente_em('base', "date '2025-04-02'") }} ),
depois_da_correcao as ( {{ observacao_vigente_em('base', "date '2025-06-30'") }} ),

observado as (
    select date '2024-01-01' as corte, cd_conta, valor, dt_recebimento from antes_da_primeira
    union all
    select date '2025-04-01', cd_conta, valor, dt_recebimento from antes_da_correcao
    union all
    select date '2025-04-02', cd_conta, valor, dt_recebimento from no_dia_da_correcao
    union all
    select date '2025-06-30', cd_conta, valor, dt_recebimento from depois_da_correcao
),

-- 2024-01-01 NÃO aparece aqui de propósito: nada era público, e qualquer linha observada
-- naquele corte é falha (o full outer join abaixo a pega).
esperado (corte, cd_conta, valor_esperado) as (
    values
        (date '2025-04-01', '3.01',        0.0),
        (date '2025-04-01', '3.11',        0.0),
        (date '2025-04-02', '3.01', 28735000.0),
        (date '2025-04-02', '3.11', 48731000.0),
        (date '2025-06-30', '3.01', 28735000.0),
        (date '2025-06-30', '3.11', 48731000.0)
)

select
    coalesce(o.corte, e.corte)          as corte,
    coalesce(o.cd_conta, e.cd_conta)    as cd_conta,
    e.valor_esperado,
    o.valor                             as valor_selecionado,
    o.dt_recebimento

from observado as o
full outer join esperado as e
    on o.corte = e.corte and o.cd_conta = e.cd_conta

where o.corte is null                              -- esperado e não veio
   or e.corte is null                              -- veio e não era esperado
   or o.valor is distinct from e.valor_esperado    -- veio com outro valor
   or o.dt_recebimento > o.corte                   -- olhou o futuro
