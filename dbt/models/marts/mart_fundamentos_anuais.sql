{{ config(materialized='table') }}

with fatos as (

    select
        f.cd_cvm,
        f.razao_social,
        f.dt_fim_exercicio,
        f.ano_exercicio,
        f.tipo_df,
        f.dt_referencia,
        f.dt_recebimento,
        f.valor,
        s.conceito

    from {{ ref('fct_fundamentos') }} as f

    inner join {{ ref('contas_canonicas') }} as s
        on  f.demonstrativo = s.demonstrativo
        and f.cd_conta      = s.cd_conta
        and f.ds_conta      = s.ds_conta

    where f.safra_original
      -- Valor que a fonte contradiz não entra no pivot: `max()` sobre ele publicaria um
      -- número que ninguém afirmou. Ausência declarada é melhor do que desempate.
      and f.status_valor = 'OK'

),


-- Bloco de atribuição do resultado, lido direto do fato porque o filho `.02`
-- (não controladores) não está no seed de propósito: o mesmo código `3.09.02` aparece
-- como "Obrigações Fiscais Diferidas" em uma empresa, e mapeá-lo por código criaria
-- ambiguidade. Aqui cada pai é casado com os SEUS próprios filhos, que é a relação
-- contábil de verdade.
blocos_atribuicao as (

    select
        f.cd_cvm,
        f.dt_fim_exercicio,
        f.tipo_df,
        substr(f.cd_conta, 1, 4)                                        as bloco,

        max(case when length(f.cd_conta) = 4 then f.valor end)          as total_bloco,

        max(case
                when f.cd_conta like '%.01'
                 and lower(strip_accents(f.ds_conta)) like '%empresa controladora%'
                then f.valor
            end)                                                        as contr_bloco,

        max(case
                when f.cd_conta like '%.02'
                 and lower(strip_accents(f.ds_conta)) like '%nao controladores%'
                then f.valor
            end)                                                        as minor_bloco

    from {{ ref('fct_fundamentos') }} as f

    where f.safra_original
      and f.status_valor = 'OK'
      and f.demonstrativo = 'DRE'
      and (
            f.cd_conta in ('3.09', '3.11', '3.13')
         or f.cd_conta in ('3.09.01', '3.11.01', '3.13.01',
                           '3.09.02', '3.11.02', '3.13.02')
          )

    group by 1, 2, 3, 4

),

selecionado as (

    select f.*

    from fatos as f

    inner join {{ ref('int_empresas_tipo_df') }} as p
        on  f.cd_cvm           = p.cd_cvm
        and f.dt_fim_exercicio = p.dt_fim_exercicio
        and f.tipo_df          = p.tipo_df_escolhido

),


pivotado as (

    select
        cd_cvm,
        dt_fim_exercicio,

        max(razao_social)                as razao_social,
        max(ano_exercicio)               as ano_exercicio,
        max(tipo_df)                     as tipo_df,
        max(dt_referencia)               as dt_referencia,
        max(dt_recebimento)              as dt_recebimento,

        bool_or(conceito like 'fin\_%' escape '\')  as flag_financeira,

        max(case when conceito = 'ativo_total'                 then valor end) as ativo_total,
        max(case when conceito = 'ativo_circulante'            then valor end) as ativo_circulante,
        max(case when conceito = 'caixa_e_equivalentes'        then valor end) as caixa_e_equivalentes,
        max(case when conceito = 'contas_a_receber'            then valor end) as contas_a_receber,
        max(case when conceito = 'estoques'                    then valor end) as estoques,
        max(case when conceito = 'passivo_total'               then valor end) as passivo_total,
        max(case when conceito = 'passivo_circulante'          then valor end) as passivo_circulante,
        max(case when conceito = 'patrimonio_liquido'          then valor end) as patrimonio_liquido,
        max(case when conceito = 'pl_minoritarios'             then valor end) as pl_minoritarios,
        max(case when conceito = 'fornecedores'                then valor end) as fornecedores,
        max(case when conceito = 'divida_bruta_circulante'     then valor end) as divida_bruta_circulante,
        max(case when conceito = 'divida_bruta_nao_circulante' then valor end) as divida_bruta_nao_circulante,

        max(case when conceito = 'receita_liquida'             then valor end) as receita_liquida,
        max(case when conceito = 'custo'                       then valor end) as custo,
        max(case when conceito = 'lucro_bruto'                 then valor end) as lucro_bruto,
        max(case when conceito = 'despesas_vendas'             then valor end) as despesas_vendas,
        max(case when conceito = 'despesas_administrativas'    then valor end) as despesas_administrativas,
        max(case when conceito = 'equivalencia_patrimonial'    then valor end) as equivalencia_patrimonial,
        max(case when conceito = 'ebit'                        then valor end) as ebit,
        max(case when conceito = 'resultado_financeiro'        then valor end) as resultado_financeiro,
        max(case when conceito = 'receitas_financeiras'        then valor end) as receitas_financeiras,
        max(case when conceito = 'despesas_financeiras'        then valor end) as despesas_financeiras,
        max(case when conceito = 'lucro_liquido'               then valor end) as lucro_liquido,
        max(case when conceito = 'lucro_liquido_controladores' then valor end) as lucro_liquido_controladores,

        max(case when conceito = 'fluxo_caixa_operacional'     then valor end) as fluxo_caixa_operacional

    from selecionado

    group by 1, 2

),

-- Um bloco por ficha: aquele cujo TOTAL bate com o lucro que o seed elegeu.
-- É isso que impede tomar `3.09` (que no plano padrão é "Resultado Líquido das Operações
-- Continuadas", não o lucro do período) como se fosse o total. Se mais de um bloco casar,
-- `n_blocos` fica > 1 e a ficha cai em CONFLITO_FONTE em vez de ser desempatada.
atribuicao as (

    select
        p.cd_cvm,
        p.dt_fim_exercicio,
        count(*)            as n_blocos,
        min(b.contr_bloco)  as contr_bloco,
        min(b.minor_bloco)  as minor_bloco

    from pivotado as p

    inner join blocos_atribuicao as b
        on  b.cd_cvm            = p.cd_cvm
        and b.dt_fim_exercicio  = p.dt_fim_exercicio
        and b.tipo_df           = p.tipo_df
        and b.contr_bloco is not null
        and abs(b.total_bloco - p.lucro_liquido)
              <= greatest(1000, abs(p.lucro_liquido) * 0.001)

    group by 1, 2

),

derivado as (

    select
        p.*,

        -- ---------------------------------------------------------------------------
        -- Lucro dos controladores, resolvido pela identidade e não pela leitura literal.
        --
        -- A identidade contábil do bloco é  total = controladores + não controladores.
        -- Quando ela não fecha, a linha `.01` não é o lucro dos controladores, seja lá o
        -- que a fonte tenha escrito ali. Medido em 2026-09-06 sobre 10.839 fichas:
        --
        --   IDENTIDADE_OK        5.809 fichas / 692 empresas   (usa a linha .01)
        --   SEM_SPLIT            4.521 / 637   (base individual: a linha não existe)
        --   SPLIT_NAO_INFORMADO    424 / 169   (.01 e .02 ambos zerados com total != 0)
        --   CONFLITO_FONTE          85 /  69   (não fecha por outro motivo)
        --
        -- Os dois últimos casos aparecem SÓ a partir de 2021 — zero ocorrências de 2010 a
        -- 2020, depois 51, 77, 92, 103 e 102. O gabarito da CVM passou a exigir as linhas
        -- e as empresas sem minoritários passaram a preenchê-las com zero.
        --
        -- SPLIT_NAO_INFORMADO: SABESP 2024 publica 3.11 = R$ 9,58 bi, 3.11.01 = 0 e
        -- 3.11.02 = 0. Lido ao pé da letra, o mart publicava margem_liquida = 0,0% e
        -- ROE = 0 para uma empresa que lucrou R$ 9,58 bi. Eram 390 margens e 419 ROEs
        -- zerados, em nomes como TIM, KLABIN, CSN MINERAÇÃO, GUARARAPES e MRS.
        --
        -- CONFLITO_FONTE: AZUL 2024 publica 3.11 = -R$ 9,15 bi (prejuízo) e
        -- 3.11.01 = +R$ 9,19 bi. O sinal está invertido NA FONTE — conferido no parquet
        -- bruto, VL_CONTA = 9190174 contra -9151371, então não é defeito da ingestão.
        -- O mart publicava margem_liquida = +47,07% para a empresa que mais perdeu
        -- dinheiro no ano.
        --
        -- Nos dois casos o valor volta a ser NULL e os indicadores recuam para o
        -- consolidado, que é auto-consistente. `status_lucro_controladores` deixa a
        -- decisão auditável e `lucro_liquido_controladores_fonte` preserva o que a CVM
        -- disse, para quem quiser estudar o defeito.
        -- ---------------------------------------------------------------------------
        case
            when p.lucro_liquido_controladores is null then 'SEM_SPLIT'
            when coalesce(a.n_blocos, 0) > 1                           then 'CONFLITO_FONTE'

            -- Contradição entre demonstrativos: a DRE atribui 100% do resultado aos NÃO
            -- controladores enquanto o balanço diz que não existe participação de não
            -- controladores. As duas linhas do bloco estão trocadas na fonte, e a
            -- identidade fecha justamente porque o erro é consistente consigo mesmo —
            -- só o cruzamento com o BPP o denuncia. Medido: 12 fichas atribuem tudo aos
            -- minoritários; em 10 delas (LOJAS RENNER 2016 com R$ 625,1 mi, MARISA 2020,
            -- LINX 2011, TEREOS 2013) o PL de minoritários é zero. A exceção legítima é
            -- PPLA 2011, em que os minoritários detêm 100% do PL — e essa continua OK.
            when p.lucro_liquido_controladores = 0
             and p.lucro_liquido <> 0
             and coalesce(a.minor_bloco, 0) <> 0
             and p.patrimonio_liquido is not null
             and coalesce(p.pl_minoritarios, 0) = 0                    then 'CONFLITO_FONTE'
            when abs(p.lucro_liquido_controladores + coalesce(a.minor_bloco, 0) - p.lucro_liquido)
                 <= greatest(1000, abs(p.lucro_liquido) * 0.001)       then 'IDENTIDADE_OK'
            when p.lucro_liquido_controladores = 0
             and coalesce(a.minor_bloco, 0) = 0
             and p.lucro_liquido <> 0                                  then 'SPLIT_NAO_INFORMADO'
            else 'CONFLITO_FONTE'
        end                                                        as status_lucro_controladores,

        p.lucro_liquido_controladores                              as lucro_liquido_controladores_fonte,

        patrimonio_liquido - coalesce(pl_minoritarios, 0)          as patrimonio_liquido_controladores,
        coalesce(divida_bruta_circulante, 0)
            + coalesce(divida_bruta_nao_circulante, 0)             as divida_bruta,
        coalesce(divida_bruta_circulante, 0)
            + coalesce(divida_bruta_nao_circulante, 0)
            - coalesce(caixa_e_equivalentes, 0)                    as divida_liquida

    from pivotado as p

    left join atribuicao as a
        on  p.cd_cvm           = a.cd_cvm
        and p.dt_fim_exercicio = a.dt_fim_exercicio

),

validado as (

    select
        * exclude (lucro_liquido_controladores),

        case
            when status_lucro_controladores = 'IDENTIDADE_OK'
            then lucro_liquido_controladores
        end                                                        as lucro_liquido_controladores

    from derivado

),

final as (

    select
        *,
        coalesce(lucro_liquido_controladores, lucro_liquido)       as lucro_atribuivel
    from validado

)

select
    * exclude (lucro_atribuivel),

    lucro_atribuivel  / nullif(receita_liquida, 0)                   as margem_liquida,
    lucro_liquido     / nullif(receita_liquida, 0)                   as margem_liquida_consolidada,
    lucro_bruto       / nullif(receita_liquida, 0)                   as margem_bruta,
    ebit              / nullif(receita_liquida, 0)                   as margem_ebit,
    -- Retorno sobre patrimônio negativo não é retorno: o sinal do quociente passa a
    -- depender do sinal do denominador e a leitura se inverte. Medido em 2026-09-06:
    -- 1.359 fichas têm patrimônio_liquido_controladores < 0 e, em 1.145 delas (299
    -- empresas), o prejuízo dividido pelo PL negativo era publicado como ROE POSITIVO.
    -- AZUL 2024: prejuízo de R$ 9,15 bi sobre PL de -R$ 30,4 bi saía como ROE +30,1%.
    -- Com denominador não positivo o indicador não existe, e dizer isso é a resposta certa.
    case when patrimonio_liquido_controladores > 0
         then lucro_atribuivel / patrimonio_liquido_controladores end as roe,
    case when patrimonio_liquido > 0
         then lucro_liquido / patrimonio_liquido end                  as roe_consolidado,
    lucro_liquido     / nullif(ativo_total, 0)                       as roa,
    ativo_circulante  / nullif(passivo_circulante, 0)                as liquidez_corrente,
    (ativo_circulante - coalesce(estoques, 0))
                      / nullif(passivo_circulante, 0)                as liquidez_seca,
    -- Mesma razão: dívida líquida sobre PL negativo devolve alavancagem NEGATIVA
    -- justamente para as empresas mais endividadas, que é a leitura oposta da verdadeira.
    case when patrimonio_liquido_controladores > 0
         then divida_liquida / patrimonio_liquido_controladores end   as alavancagem,
    ebit              / nullif(abs(despesas_financeiras), 0)         as cobertura_juros,
    receita_liquida   / nullif(ativo_total, 0)                       as giro_ativo

from final
