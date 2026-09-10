{{ config(materialized='view') }}

{#
  Todas as observações de um mesmo período econômico, ordenadas pela data em que
  ficaram PÚBLICAS.

  Por que existe: `mart_fundamentos_anuais` publica uma leitura só — a do documento do
  próprio exercício — e o rótulo `safra_original` foi tratado por muito tempo como se
  significasse "primeira publicação". Não significa. `ORDEM_EXERC` diz a posição do
  exercício DENTRO do documento, e nada mais.

  Medido em 2026-09-09 (commit 19fc177):
    - `dt_recebimento` está preenchido em 8.563.240 de 8.563.240 linhas (100%) — a data
      pública é o único eixo temporal completo que o acervo tem;
    - 1.280.141 contextos têm uma observação, 3.639.101 têm duas e 1.590 têm três;
    - dos 3.638.752 contextos com duas observações: 3.585.122 (98,5%) têm a "original"
      recebida antes, 33.485 (0,92%) no MESMO DIA e 20.145 (0,55%) têm a "original"
      recebida DEPOIS da reapresentada. O rótulo não ordena o tempo, e é por isso que
      este model ordena por `dt_recebimento`.

  `ordem_publicacao = 1` é a PRIMEIRA OBSERVAÇÃO PRESERVADA NO ACERVO, e não
  necessariamente a primeira publicação da companhia: o acervo guarda apenas a versão
  corrente de cada documento, e 22,4% dos documentos foram refeitos (R-TMP-002).
#}

with observacoes as (

    select
        cd_cvm,
        razao_social,
        tipo_df,
        demonstrativo,
        cd_conta,
        ds_conta,

        dt_inicio_exercicio,
        dt_fim_exercicio,

        dt_referencia,
        versao,
        ordem_exercicio,
        safra_original,

        dt_recebimento,

        valor,
        status_valor

    from {{ ref('fct_fundamentos') }}

)

select
    *,

    row_number() over (partition by
            cd_cvm, tipo_df, demonstrativo, cd_conta, ds_conta,
            dt_inicio_exercicio, dt_fim_exercicio
        order by dt_recebimento, dt_referencia, versao
    )                                                       as ordem_publicacao,

    count(*) over (partition by
            cd_cvm, tipo_df, demonstrativo, cd_conta, ds_conta,
            dt_inicio_exercicio, dt_fim_exercicio
    )                                                       as n_observacoes

from observacoes
