{#
  Seleção temporal: qual observação pode responder a cada pergunta.

  As três políticas são diferentes e nenhuma substitui a outra. O critério que as separa,
  e que este macro existe para tornar mecânico:

      Uma consulta anterior à publicação de uma correção NUNCA pode selecionar
      o valor corretivo.

  `vigente_em(data)`   -> a observação mais recente entre as que já eram públicas na data.
                          É a única adequada a pergunta histórica ou backtest.
  `mais_recente()`     -> a observação mais recente do acervo, sem corte de data.
                          É "o que se sabe hoje".
  `primeira_preservada()` -> a de menor `dt_recebimento` NO ACERVO. Não é a primeira
                          publicação da companhia quando o documento foi refeito (R-TMP-002).

  Data desconhecida permanece desconhecida: `dt_recebimento` nulo nunca é presumido, e a
  observação simplesmente não é elegível para pergunta histórica. Hoje o acervo tem 0 nulos.
#}

{% macro contexto_economico() -%}
    cd_cvm, tipo_df, demonstrativo, cd_conta, ds_conta, dt_inicio_exercicio, dt_fim_exercicio
{%- endmacro %}


{% macro vigente_em(data) -%}
    qualify row_number() over (
        partition by {{ contexto_economico() }}
        order by dt_recebimento desc, dt_referencia desc, versao desc
    ) = 1
    and dt_recebimento <= {{ data }}
{%- endmacro %}
