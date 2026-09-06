{#
  Conversão do valor bruto da CVM para reais.

  Por que um macro e não a expressão repetida nos cinco stagings: a regra de escala é uma
  definição de negócio, e definição duplicada diverge (AGENTS.md §5, "uma definição, um lugar").
  Ela já estava escrita cinco vezes e as cinco estavam erradas do mesmo jeito.

  O DEFEITO QUE ISTO CORRIGE
  --------------------------
  `ESCALA_MOEDA` descreve a escala dos valores MONETÁRIOS do documento. O grupo `3.99`
  da DRE ("Lucro por Ação") não é monetário: a própria CVM escreve a unidade na descrição
  ("Lucro por Ação - (Reais / Ação)") e publica o número já em reais por ação. Multiplicar
  por 1.000 produz um lucro por ação mil vezes maior.

  Medido em 2026-09-06 sobre o warehouse:
    - 63.018 linhas não-zero de `3.99*` em fct_fundamentos receberam o fator indevido;
    - WEG 2023, conta 3.99.01.01 "ON": warehouse trazia 1366,08; o correto é R$ 1,36608;
    - SABESP 2024, mesma conta: 14020 no warehouse, R$ 14,02 correto
      (confere com lucro 9,58 bi / ~683 M ações);
    - `3.99*` é o ÚNICO grupo não-monetário dos cinco demonstrativos: uma varredura das
      descrições por unidade ("por ação", "/ ação", "quantidade") nos 8,5 M de linhas não
      retorna nenhuma linha fora de `DRE 3.99%`.

  O `case` continua SEM `else`, de propósito: escala desconhecida em conta monetária tem
  de virar NULL e quebrar o `not_null` de `valor` (invariante de AGENTS.md §4). Contas
  `3.99*` saem antes desse teste porque de fato não dependem da escala do documento.
#}

{% macro unidade_da_conta(demonstrativo, cd_conta) -%}
    case
        when '{{ demonstrativo }}' = 'DRE' and {{ cd_conta }} like '3.99%' then 'POR_ACAO'
        else 'MOEDA'
    end
{%- endmacro %}


{% macro valor_em_reais(demonstrativo, cd_conta, escala_moeda, vl_conta) -%}
    cast({{ vl_conta }} as double)
      * case
            when '{{ demonstrativo }}' = 'DRE' and {{ cd_conta }} like '3.99%' then 1
            when {{ escala_moeda }} = 'MIL'     then 1000
            when {{ escala_moeda }} = 'UNIDADE' then 1
        end
{%- endmacro %}
