-- O critério que separa uma pergunta histórica de uma pergunta sobre o presente:
--
--     Uma consulta anterior à publicação de uma correção NUNCA pode selecionar
--     o valor corretivo.
--
-- Este teste fixa esse comportamento no caso documentado da CELGPAR (021393), exercício
-- 2023, base consolidada. Duas observações do MESMO período econômico:
--
--   documento 2023-12-31 v1, público em 2024-03-27  ->  3.01 = 0          e 3.11 = 0
--   documento 2024-12-31 v2, público em 2025-04-02  ->  3.01 = 28.735.000 e 3.11 = 48.731.000
--
-- O bloco consolidado do primeiro documento veio inteiramente zerado na fonte (é o caso
-- BASE_DEGENERADA), e a própria CVM publicou a correção na safra seguinte. O valor certo
-- portanto EXISTE no acervo — mas só se tornou público em 2025-04-02, e quem perguntar
-- "o que se sabia em 2025-04-01" tem de receber o zero, não a correção.
--
-- O teste falha se a seleção passar a olhar o futuro, e também se a evidência sumir do
-- acervo (uma reingestão que sobrescreva o documento de 2024, por exemplo).

with esperado (corte, cd_conta, valor_esperado) as (
    values
        -- antes da publicação da correção: vale o que estava público
        (date '2025-04-01', '3.01', 0.0),
        (date '2025-04-01', '3.11', 0.0),
        -- depois: vale a correção
        (date '2025-06-30', '3.01', 28735000.0),
        (date '2025-06-30', '3.11', 48731000.0)
),

vigente as (

    select
        e.corte,
        e.cd_conta,
        e.valor_esperado,
        o.valor       as valor_selecionado,
        o.dt_recebimento,
        row_number() over (
            partition by e.corte, e.cd_conta
            order by o.dt_recebimento desc, o.versao desc
        ) as rn

    from esperado as e

    left join {{ ref('int_observacoes_periodo') }} as o
        on  o.cd_cvm            = '021393'
       and  o.tipo_df           = 'CONSOLIDADO'
       and  o.demonstrativo     = 'DRE'
       and  o.dt_fim_exercicio  = date '2023-12-31'
       and  o.cd_conta          = e.cd_conta
       and  o.dt_recebimento   <= e.corte

)

select corte, cd_conta, valor_esperado, valor_selecionado, dt_recebimento
from vigente
where rn = 1
  and (
        valor_selecionado is distinct from valor_esperado
     or dt_recebimento > corte      -- olhou o futuro
  )
