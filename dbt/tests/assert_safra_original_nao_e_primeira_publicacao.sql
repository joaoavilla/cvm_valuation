{{ config(severity = 'warn') }}

-- `safra_original` NÃO ordena o tempo, e este teste existe para manter isso visível.
--
-- O rótulo vem de `ORDEM_EXERC = 'ÚLTIMO'`, que diz a posição do exercício DENTRO do
-- documento. Não diz que aquele documento foi publicado antes do outro que reporta o mesmo
-- período. Medido em 2026-09-09, sobre 3.638.752 contextos econômicos com exatamente duas
-- observações: 3.585.122 (98,5%) têm a "original" recebida antes, 33.485 (0,92%) no MESMO
-- DIA, e 20.145 (0,55%) têm a "original" recebida DEPOIS da reapresentada — que é o que
-- este teste conta.
--
-- É WARN e não ERROR porque não é defeito nosso nem da fonte: é uma propriedade do acervo,
-- e o que ela exige é que ninguém use `safra_original` como garantia de anterioridade. Quem
-- precisa de anterioridade usa `dt_recebimento`, que está preenchido em 100% das linhas.
--
-- Se este número crescer muito, a leitura "série do próprio exercício" fica menos confiável
-- como proxy histórico e a seleção por data passa a ser obrigatória, não recomendada.

select
    cd_cvm,
    tipo_df,
    demonstrativo,
    cd_conta,
    ds_conta,
    dt_inicio_exercicio,
    dt_fim_exercicio,
    min(dt_recebimento) filter (where safra_original)       as recebimento_original,
    min(dt_recebimento) filter (where not safra_original)   as recebimento_reapresentado

from {{ ref('int_observacoes_periodo') }}

where status_valor = 'OK'

group by 1, 2, 3, 4, 5, 6, 7

having count(*) = 2
   and count(*) filter (where safra_original) = 1
   and min(dt_recebimento) filter (where safra_original)
       > min(dt_recebimento) filter (where not safra_original)
