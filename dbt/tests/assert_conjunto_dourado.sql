-- Conferência do mart contra fonte externa.
--
-- Os testes internos do projeto provam CONSISTÊNCIA: que o pipeline faz o que foi escrito.
-- Só a fonte externa prova CORREÇÃO: que o que foi escrito é a coisa certa. Todos os defeitos
-- graves já encontrados neste repositório apareceram por comparação externa enquanto a suíte
-- interna estava verde — este é o teste que fecha esse laço.
--
-- O seed `conjunto_dourado` tem três classes e só uma reprova:
--
--   TRAVA (189 fichas)             o mart tem de bater com a fonte dentro da tolerância.
--                                  É a trava de regressão das correções já feitas.
--   DEFEITO_ABERTO (31)            divergência confirmada e ainda não corrigida. Fica
--                                  registrada com a causa medida, fora da reprovação, para
--                                  não travar o build por algo que já se sabe.
--   DIVERGENCIA_FONTE (19)         o mart está certo e a fonte mede outra coisa — norma
--                                  contábil diferente (IFRS × BRGAAP/COSIF), safra
--                                  reapresentada, número gerencial. Não é defeito.
--
-- Quando um DEFEITO_ABERTO for corrigido, promova a linha a TRAVA no seed: a correção passa a
-- ser protegida contra regressão pelo mesmo mecanismo.
--
-- A tolerância é RELATIVA porque o valor absoluto depende de como a fonte formata o número.
-- O padrão é 0,1%; as cinco linhas com 0,5% são fontes que publicam arredondado e estão
-- nomeadas na coluna `observacao`.

{% set conceitos = [
    'ativo_total',
    'patrimonio_liquido',
    'receita_liquida',
    'lucro_liquido',
    'lucro_liquido_controladores'
] %}

with mart_longo as (

    {% for c in conceitos %}
    select cd_cvm, ano_exercicio as ano, '{{ c }}' as conceito, {{ c }} as valor
    from {{ ref('mart_fundamentos_anuais') }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

),

comparado as (

    select
        d.cd_cvm,
        d.ano,
        d.conceito,
        d.razao_social,
        d.valor_esperado,
        m.valor                                as valor_mart,
        d.tolerancia_rel,
        d.fonte_tipo,
        d.fonte_url,

        case
            when m.cd_cvm is null then 'FICHA_AUSENTE'
            when m.valor   is null then 'VALOR_NULO'
            when abs(m.valor - d.valor_esperado)
                 > abs(d.valor_esperado) * d.tolerancia_rel then 'FORA_DA_TOLERANCIA'
        end                                    as falha,

        case when d.valor_esperado <> 0
             then (m.valor - d.valor_esperado) / abs(d.valor_esperado)
        end                                    as desvio_rel

    from {{ ref('conjunto_dourado') }} as d

    -- `left join`: a ficha que sumir do mart tem de reprovar, não desaparecer do teste.
    left join mart_longo as m
        on  m.cd_cvm   = d.cd_cvm
        and m.ano      = d.ano
        and m.conceito = d.conceito

    where d.status = 'TRAVA'

)

select *
from comparado
where falha is not null
