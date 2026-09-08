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

-- Os conceitos centrais em CADA base, antes de a politica escolher uma. Existe so para
-- servir de testemunha a `base_degenerada`; nenhum valor daqui e publicado.
valores_por_base as (

    select
        cd_cvm,
        dt_fim_exercicio,
        tipo_df,
        -- Conta o que foi OBSERVADO e o que foi observado DIFERENTE DE ZERO. Contar assim,
        -- e nao com coalesce(...,0), e o que impede tratar ausencia como zero: instituicao
        -- financeira nao mapeia `receita_liquida`, e um NULL ali nao e evidencia de base
        -- vazia -- e evidencia de nada.
        count(*) filter (where conceito in ('lucro_liquido','receita_liquida','ativo_total'))
            as n_observados,
        count(*) filter (where conceito in ('lucro_liquido','receita_liquida','ativo_total')
                           and valor <> 0)
            as n_nao_zero
    from fatos
    group by 1, 2, 3

),
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

        max(case when conceito = 'fluxo_caixa_operacional'     then valor end) as fluxo_caixa_operacional,

        -- ---------------------------------------------------------------------------
        -- Bloco de instituição financeira e seguradora. O seed mapeia estes quatro
        -- conceitos desde sempre, mas o pivot nunca os projetava: eles só alimentavam
        -- `flag_financeira`. O resultado era que as 620 fichas de financeira saíam com
        -- 0,0% de cobertura de receita enquanto o dado estava intacto no fato.
        --
        -- São projeções FIÉIS da conta que a CVM publica, com nome próprio. Elas
        -- deliberadamente NÃO alimentam `receita_liquida`, nem margens, nem `giro_ativo`:
        --
        --   (a) A conta certa ainda não foi decidida por medição. Conferido em
        --       2026-09-07 contra seis âncoras externas, o `3.01` reproduz UMA
        --       (Banco PAN 2023). Itaú 2024 traz 3.01 = R$ 335,3 bi contra R$ 168,05 bi
        --       da fonte; Banco do Brasil bate no `3.03`, não no `3.01`; ABC Brasil só
        --       bate na base INDIVIDUAL, que a política de base proíbe. As âncoras usam
        --       pelo menos três definições diferentes de "receita de banco".
        --   (b) A definição não é comparável em corte transversal: o giro do ativo
        --       mediano seria 0,12 na coorte financeira contra 0,39 na não-financeira,
        --       diferença puramente definicional.
        --   (c) O invariante `not (flag_financeira and margem_liquida is not null)`
        --       (AGENTS.md §4) reprovaria 584 fichas.
        --
        -- Publicar um número de receita para banco exige antes uma rodada de
        -- `validar-externo` que decida 3.01 contra 3.03 com fonte e data declaradas.
        --
        -- Atenção ao sinal de `fin_despesa_intermediacao`: vem negativa em 552 de 614
        -- linhas e POSITIVA em 7 (BANCO MODAL 2020, CCB BRASIL 2015/16/18/19/20,
        -- BANCO BERJ 2011). A identidade que fecha é `3.01 + 3.02 = 3.03` (611 de 613);
        -- a subtração fecha em apenas 53. Some, não subtraia.
        -- ---------------------------------------------------------------------------
        max(case when conceito = 'fin_receita_intermediacao'   then valor end) as fin_receita_intermediacao,
        max(case when conceito = 'fin_despesa_intermediacao'   then valor end) as fin_despesa_intermediacao,
        max(case when conceito = 'fin_resultado_intermediacao' then valor end) as fin_resultado_intermediacao,
        max(case when conceito = 'fin_receita_seguros'         then valor end) as fin_receita_seguros

    from selecionado

    group by 1, 2

),

-- Um bloco por ficha: aquele cujo TOTAL bate com o lucro que o seed elegeu.
-- É isso que impede tomar `3.09` (que no plano padrão é "Resultado Líquido das Operações
-- Continuadas", não o lucro do período) como se fosse o total. Se mais de um bloco casar,
-- `n_blocos` fica > 1 e a ficha cai em CONFLITO_FONTE em vez de ser desempatada.
candidatos as (

    select
        p.cd_cvm,
        p.dt_fim_exercicio,
        b.bloco,
        b.contr_bloco,
        b.minor_bloco,

        abs(b.contr_bloco + coalesce(b.minor_bloco, 0) - p.lucro_liquido)
              <= greatest(1000, abs(p.lucro_liquido) * 0.001)  as fecha_identidade

    from pivotado as p

    inner join blocos_atribuicao as b
        on  b.cd_cvm            = p.cd_cvm
        and b.dt_fim_exercicio  = p.dt_fim_exercicio
        and b.tipo_df           = p.tipo_df
        and b.contr_bloco is not null
        and abs(b.total_bloco - p.lucro_liquido)
              <= greatest(1000, abs(p.lucro_liquido) * 0.001)

),

-- Dois blocos podem ter o mesmo total sem medirem a mesma coisa. BANRISUL 2024 declara
-- `3.09` "Lucro antes das Participações e Contribuições Estatutárias" = R$ 727,798 mi com
-- `.01` e `.02` zerados, e `3.11` "Lucro Líquido Consolidado" = os mesmos R$ 727,798 mi com
-- `.01` = R$ 727,253 mi e `.02` = R$ 545 mil. Os dois casavam com o lucro do seed, a ficha
-- caía em CONFLITO_FONTE e um valor correto — conferido contra fonte externa, R$ 727,250 mi —
-- era suprimido.
--
-- O desempate não é arbitrário e não é uma lista de exceções: fica o bloco cuja identidade
-- contábil FECHA. Quando nenhum fecha, ou quando mais de um fecha, todos permanecem e a
-- ficha continua em CONFLITO_FONTE — a ambiguidade real segue sendo recusada.
--
-- Medido em 2026-09-07, no grão (cd_cvm, dt_fim_exercicio):
--   2 blocos, 1 fecha     8 fichas / 3 empresas   -> 7 recuperadas de imediato (BANRISUL
--                                                    2020/22/23/24, BCO ALFA 2023,
--                                                    FINANCEIRA ALFA 2021/2022). A oitava,
--                                                    FINANCEIRA ALFA 2023, so foi recuperada
--                                                    quando o valor resolvido passou a chegar
--                                                    ao mart -- ver o bloco de comentario da
--                                                    escada de status, mais abaixo.
--   2 blocos, 2 fecham    5 fichas / 5 empresas   -> seguem em CONFLITO_FONTE
--   1 bloco               6.304 fichas            -> inalteradas
preferidos as (

    select cd_cvm, dt_fim_exercicio, bloco, contr_bloco, minor_bloco

    from (
        select
            *,
            count(*) filter (fecha_identidade)
                over (partition by cd_cvm, dt_fim_exercicio)  as n_fecham
        from candidatos
    )

    where n_fecham <> 1
       or fecha_identidade

),

atribuicao as (

    select
        cd_cvm,
        dt_fim_exercicio,
        count(*)            as n_blocos,
        min(bloco)          as bloco_origem,
        min(contr_bloco)    as contr_bloco,
        min(minor_bloco)    as minor_bloco

    from preferidos

    group by 1, 2

),


-- Maior total entre os blocos da ficha DENTRO DA BASE ESCOLHIDA, casem eles com o
-- lucro eleito ou não. O escopo por `tipo_df` é deliberado: comparar bloco de bases
-- diferentes seria misturar contextos contábeis para preencher lacuna, que é
-- exatamente o que este modelo recusa. A degeneração da BASE inteira é um problema
-- distinto e tem testemunha própria logo abaixo.
-- Serve de testemunha contra um bloco degenerado: quando o lucro eleito pelo seed é zero
-- mas existe um bloco irmão com total diferente de zero, o zero é formulário em branco,
-- não resultado nulo. BCO ALFA DE INVESTIMENTO 2021 e 2022 são o caso: a base consolidada
-- traz `3.11` = 0 enquanto `3.09` traz R$ 73,88 mi e R$ 123,98 mi.
blocos_resumo as (

    select
        cd_cvm,
        dt_fim_exercicio,
        tipo_df,
        max(abs(total_bloco))                                        as maior_total_bloco,
        -- Pai em branco com filhos preenchidos e a terceira forma de zero de formulario.
        -- FINANCEIRA ALFA 2021 traz `3.09` = 0 com `3.09.01` = R$ 77,245 mi e
        -- `3.09.02` = R$ 2,081 mi; CESP 2022 traz `3.11` = 0 com `3.11.01` = R$ 2,447 bi.
        -- Sem esta testemunha o modelo publicava lucro dos controladores igual a zero
        -- para empresa que lucrou. Medido em 2026-09-08: 3 blocos, 3 fichas, 2 empresas.
        max(abs(coalesce(contr_bloco, 0) + coalesce(minor_bloco, 0))) as maior_soma_filhos
    from blocos_atribuicao
    group by 1, 2, 3

),


-- Testemunha de BASE degenerada: a base que a politica elegeu vem inteiramente zerada
-- (lucro, receita e ativo) enquanto a outra base da mesma ficha tem numero.
--
-- Medido em 2026-09-08: 7 fichas / 4 empresas, de 6.235 fichas que publicam as duas bases.
--   TIM S.A. 2024 e 2025          consolidado zerado; individual com R$ 25,4 e 26,6 bi de receita
--   RIO PARANAPANEMA 2024 e 2025  idem, R$ 1,20 bi e R$ 1,26 bi
--   CLI SUL 2025                  idem, R$ 723,1 mi
--   CELGPAR 2022 e 2023           idem
--
-- Isto NAO corrige `lucro_liquido` nem `receita_liquida`, que continuam saindo zerados:
-- trocar a base eleita altera a politica declarada em `int_empresas_tipo_df`, o invariante
-- que a acompanha e numeros publicados. E decisao do mantenedor e esta registrada como
-- pendencia. O que este modelo faz e recusar-se a publicar um lucro de controladores
-- extraido de um formulario em branco.
base_degenerada as (

    select
        p.cd_cvm,
        p.dt_fim_exercicio,
        true as base_eleita_zerada
    from {{ ref('int_empresas_tipo_df') }} as p
    join valores_por_base as e
        on  e.cd_cvm = p.cd_cvm and e.dt_fim_exercicio = p.dt_fim_exercicio
        and e.tipo_df = p.tipo_df_escolhido
    join valores_por_base as o
        on  o.cd_cvm = p.cd_cvm and o.dt_fim_exercicio = p.dt_fim_exercicio
        and o.tipo_df <> p.tipo_df_escolhido
    -- A base eleita observou pelo menos um conceito central e TODOS os observados valem
    -- zero; a outra base observou pelo menos um diferente de zero. Ausencia nao entra na
    -- conta de nenhum dos dois lados.
    where e.n_observados > 0
      and e.n_nao_zero = 0
      and o.n_nao_zero > 0

),

derivado as (

    select
        p.*,

        -- ---------------------------------------------------------------------------
        -- Lucro dos controladores: valor RESOLVIDO no bloco, nao lido do pivot.
        --
        -- O pivot do seed e a resolucao por bloco sao dois caminhos para o mesmo fato, e
        -- ate 2026-09-08 o modelo usava um para decidir e o outro para publicar: as etapas
        -- `candidatos`/`preferidos`/`atribuicao` identificavam o bloco integro e a escada
        -- de status logo abaixo voltava a ler `p.lucro_liquido_controladores`, do pivot.
        -- Quando os dois discordavam, o valor resolvido era calculado e descartado.
        --
        -- FINANCEIRA ALFA 2023 e o caso: o bloco `3.09` traz 18.578.000 + 4.466.000 =
        -- 23.044.000 e fecha exatamente, enquanto o seed elege `3.11.01`, que a fonte
        -- preencheu com zero -- a descricao do `3.09.01` tem NBSP (U+00A0) nas pontas e
        -- por isso nao casa com a chave do seed. O mart publicava NULL. A demonstracao
        -- consolidada IFRS da companhia confirma R$ 18.578 mil.
        --
        -- Agora o valor resolvido vem do bloco quando ha bloco, e o pivot so entra quando
        -- bloco nenhum foi identificado. Medido em 2026-09-08: das 6.317 fichas com bloco
        -- resolvido, apenas 3 discordavam do pivot, e NENHUMA ficha ganha valor onde o
        -- seed nada sabia -- a mudanca e cirurgica, nao uma troca de politica.
        --
        -- SPLIT_NAO_INFORMADO: SABESP 2024 publica 3.11 = R$ 9,58 bi com `.01` e `.02`
        -- zerados. Lido ao pe da letra, o mart publicava margem 0,0% e ROE 0 para uma
        -- empresa que lucrou R$ 9,58 bi.
        --
        -- CONFLITO_FONTE: AZUL 2024 publica 3.11 = -R$ 9,15 bi e 3.11.01 = +R$ 9,19 bi.
        -- O sinal esta invertido NA FONTE, conferido no parquet bruto. O mart publicava
        -- margem +47,07% para a empresa que mais perdeu dinheiro no ano.
        --
        -- Em todo caso nao resolvido o valor e NULL e os indicadores recuam para o
        -- consolidado, que e auto-consistente. `origem_lucro_controladores` diz de qual
        -- bloco o numero veio e `lucro_liquido_controladores_fonte` preserva o que o seed
        -- elegeu, para que a discordancia continue estudavel.
        -- ---------------------------------------------------------------------------
        coalesce(a.contr_bloco, p.lucro_liquido_controladores)     as contr_resolvido,
        a.bloco_origem                                             as origem_lucro_controladores,

        case
            when coalesce(a.contr_bloco, p.lucro_liquido_controladores) is null
                                                                       then 'SEM_SPLIT'
            when coalesce(a.n_blocos, 0) > 1                           then 'CONFLITO_FONTE'

            -- Bloco degenerado: o lucro eleito e zero, mas a propria empresa declara um
            -- bloco irmao com total diferente de zero. Publicar controladores = 0 aqui
            -- seria afirmar um numero que o formulario nao sustenta. BCO ALFA DE
            -- INVESTIMENTO 2021 e 2022: a base consolidada traz `3.11` = 0 enquanto
            -- `3.09` traz R$ 73,88 mi e R$ 123,98 mi.
            when p.lucro_liquido = 0
             and greatest(coalesce(r.maior_total_bloco, 0),
                          coalesce(r.maior_soma_filhos, 0)) > 0        then 'CONFLITO_FONTE'

            -- A base eleita veio inteiramente zerada e a outra base tem numero: o lucro
            -- dos controladores que sairia daqui e zero de formulario em branco.
            -- TIM 2024/2025, RIO PARANAPANEMA 2024/2025, CLI SUL 2025, CELGPAR 2022/2023.
            when coalesce(z.base_eleita_zerada, false)                 then 'BASE_DEGENERADA'

            -- Contradicao entre demonstrativos: a DRE atribui 100% do resultado aos NAO
            -- controladores enquanto o balanco declara, com um zero EFETIVAMENTE
            -- REPORTADO, que nao ha participacao de nao controladores. A identidade fecha
            -- justamente porque o erro e consistente consigo mesmo; so o cruzamento com o
            -- BPP o denuncia. Medido em 2026-09-08: 10 fichas / 8 empresas, TODAS com zero
            -- reportado e NENHUMA com PL de minoritarios nulo -- LOJAS RENNER 2016
            -- (R$ 625,1 mi), MARISA 2020, LINX 2011, VESTE 2014/2015. A excecao legitima e
            -- PPLA 2011, em que os minoritarios detem 100% do PL, e essa continua OK.
            --
            -- Limite conhecido: saldo de PL no encerramento e estoque e nao determina
            -- sozinho um fluxo anual -- a compra integral da participacao durante o ano
            -- produziria a mesma assinatura. Por isso o estado e proprio e nao se mistura
            -- com CONFLITO_FONTE: as 10 fichas ficam localizaveis para adjudicacao
            -- documental (DMPL/notas) em vez de sumirem num rotulo generico.
            when coalesce(a.contr_bloco, p.lucro_liquido_controladores) = 0
             and p.lucro_liquido <> 0
             and coalesce(a.minor_bloco, 0) <> 0
             and p.pl_minoritarios = 0                                 then 'CONTRADICAO_DRE_BPP'

            when abs(coalesce(a.contr_bloco, p.lucro_liquido_controladores)
                     + coalesce(a.minor_bloco, 0) - p.lucro_liquido)
                 <= greatest(1000, abs(p.lucro_liquido) * 0.001)       then 'IDENTIDADE_OK'

            when coalesce(a.contr_bloco, p.lucro_liquido_controladores) = 0
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

    left join blocos_resumo as r
        on  p.cd_cvm           = r.cd_cvm
        and p.dt_fim_exercicio = r.dt_fim_exercicio
        and p.tipo_df          = r.tipo_df

    left join base_degenerada as z
        on  p.cd_cvm           = z.cd_cvm
        and p.dt_fim_exercicio = z.dt_fim_exercicio

),

validado as (

    select
        * exclude (lucro_liquido_controladores, contr_resolvido),

        case
            when status_lucro_controladores = 'IDENTIDADE_OK'
            then contr_resolvido
        end                                                        as lucro_liquido_controladores

    from derivado

),

final as (

    select
        *,

        -- ------------------------------------------------------------------------------
        -- R-IND-001 -- numerador de margem_liquida e roe: resultado atribuivel aos socios
        -- da ENTIDADE QUE REPORTA. Uma definicao so, realizada em dois contextos.
        --
        -- Ate 2026-09-08 isto era `coalesce(lucro_liquido_controladores, lucro_liquido)`, e o
        -- campo mudava de significado conforme a disponibilidade do dado: 3.544 fichas
        -- publicavam margem "dos controladores" calculada com o lucro consolidado, sob um
        -- rotulo que prometia outra coisa.
        --
        -- A revisao externa recomendou tornar o indicador estrito em TODOS os casos. Medido,
        -- isso removeria as 3.544 -- mas 3.070 delas (86,6%) sao de base INDIVIDUAL, onde
        -- consolidado e controladores coincidem POR CONSTRUCAO e o numero esta certo. Numa
        -- demonstracao individual nao existe participacao de nao controladores, e isso esta
        -- medido, nao suposto: das 4.529 fichas individuais, 0 tem `pl_minoritarios`, e no
        -- BPP as 3.911 linhas de "nao controladores" (500 empresas) estao TODAS em base
        -- consolidada. O componente nao esta faltando; ele e identico ao total.
        --
        -- O contrato remove entao 474 margens e 451 ROEs -- as de base CONSOLIDADA em que a
        -- substituicao de fato troca o significado:
        --   SPLIT_NAO_INFORMADO 389 margens / 367 ROEs
        --   CONFLITO_FONTE       75 /  74
        --   CONTRADICAO_DRE_BPP  10 /  10
        --   BASE_DEGENERADA       0 /   0  (ja eram nulas)
        --
        -- Quem quiser o resultado consolidado tem coluna propria e com nome inequivoco:
        -- `margem_liquida_consolidada` e `roe_consolidado`.
        -- ------------------------------------------------------------------------------
        case
            when tipo_df = 'INDIVIDUAL' then lucro_liquido
            else lucro_liquido_controladores
        end                                                        as lucro_atribuivel
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
