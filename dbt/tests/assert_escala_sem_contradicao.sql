{{ config(severity = 'warn') }}

-- `ESCALA_MOEDA` da fonte não é confiável, e nenhum teste do projeto conseguia vê-lo.
--
-- A mesma empresa reporta o mesmo período e a mesma conta em dois documentos: uma vez como
-- ÚLTIMO (exercício corrente) e de novo, no ano seguinte, como PENÚLTIMO (comparativo).
-- Quando o `VL_CONTA` bruto é IDÊNTICO nas duas e só a etiqueta de escala muda, a fonte se
-- contradiz e o staging publica os dois valores com 1000x de diferença — obedecendo à
-- etiqueta sem defesa.
--
-- ELDORADO BRASIL CELULOSE (022810), Ativo Total consolidado: o documento de 2019 traz
-- 11.397.035 rotulado MIL; o de 2020 traz o MESMO 11.397.035 para o MESMO 31/12/2019,
-- rotulado UNIDADE. O mart publicou R$ 11,397 bi num exercício e R$ 12,7 MILHÕES no
-- seguinte, entre dois anos de R$ 11–12 bilhões.
--
-- POR QUE ESTE TESTE E NÃO O ÓBVIO
-- --------------------------------
-- O desenho intuitivo — reprovar quando o `ativo_total` de exercícios consecutivos salta
-- numa faixa de razão (200 a 5000, digamos) — foi medido e REFUTADO em 2026-09-07:
--
--   (a) A faixa é desempate arbitrário, o que AGENTS.md §5 proíbe. O histograma das 9.621
--       razões não tem vale: a massa é contínua de 5x a 1e6. Entre os 80 casos que a faixa
--       pegaria, o mínimo é 435 e o máximo 4431 — nenhum caso encosta em 200 nem em 5000,
--       então os dois cortes não separam nada; só regulam quanto da cauda benigna entra.
--   (b) Produz falso positivo. B100 (027634) 2025 e NOVA SOCIEDADE DE NAVEGAÇÃO (027081)
--       2023 são degraus ECONÔMICOS reais, confirmados pela reafirmação da própria fonte,
--       em que a troca de escala é consequência legítima da mudança de tamanho.
--   (c) Produz falso negativo. ENCALSO (023701) 2015→2016 tem razão 1010,7 SEM troca de
--       etiqueta e é defeito real; IGB ELETRONICA (006815) 2010 tem razão 5950 e escapa
--       pelo teto. Seis dos oitenta casos com contradição comprovada escapavam.
--   (d) Cobre só `ativo_total` e só exercícios consecutivos: 82 empresas têm um único
--       exercício no mart e nunca seriam testadas.
--
-- Este teste não tem limiar nenhum. Ele reconstrói o `VL_CONTA` bruto dividindo o valor
-- publicado pela escala que lhe foi aplicada, e compara por IGUALDADE. Se o número que a
-- CVM escreveu é o mesmo e a etiqueta mudou, a fonte se contradisse — não há o que calibrar.
-- E ele aponta QUAL exercício está sob suspeita, coisa que a razão entre anos não faz.
--
-- É WARN, não ERROR, pela mesma razão de `assert_dedup_sem_divergencia`: o defeito é da
-- fonte e ainda não existe regra que decida qual das duas etiquetas é a correta. A correção
-- de verdade é a montante — quarentena com `status_valor = 'ESCALA_CONTRADITA'` e `valor`
-- NULL, como manda a regra do repositório de que valor contraditório vira ausência e nunca
-- desempate. Até lá, o WARN mantém o alcance visível e sob contagem.
--
-- Cobertura: o oráculo da reafirmação alcança 9.514 de 10.844 fichas (87,7%). As 1.330
-- restantes — último exercício de cada empresa, deslistagens — não têm contraprova de
-- nenhum tipo dentro da base.

with reportado as (

    select
        cd_cvm,
        demonstrativo,
        tipo_df,
        cd_conta,
        ds_conta,
        coalesce(dt_inicio_exercicio, date '1900-01-01') as dt_inicio,
        dt_fim_exercicio,
        dt_referencia,
        ordem_exercicio,
        escala_moeda,
        valor,

        -- o número exatamente como a CVM o escreveu, desfazendo a escala aplicada
        valor / case escala_moeda when 'MIL' then 1000 else 1 end as vl_conta_bruto

    from {{ ref('fct_fundamentos') }}

    where status_valor = 'OK'
      and unidade      = 'MOEDA'   -- `3.99*` não recebe escala; não cabe aqui
      and valor       <> 0         -- zero é idêntico em qualquer escala

),

original   as (select * from reportado where ordem_exercicio = 'ÚLTIMO'),
reafirmado as (select * from reportado where ordem_exercicio = 'PENÚLTIMO')

select
    o.cd_cvm,
    o.demonstrativo,
    o.tipo_df,
    o.cd_conta,
    o.ds_conta,
    o.dt_fim_exercicio,
    o.dt_referencia    as safra_original,
    r.dt_referencia    as safra_reafirmada,
    o.escala_moeda     as escala_original,
    r.escala_moeda     as escala_reafirmada,
    o.valor            as valor_publicado,
    r.valor            as valor_reafirmado

from original as o

join reafirmado as r
    on  r.cd_cvm           = o.cd_cvm
    and r.demonstrativo    = o.demonstrativo
    and r.tipo_df          = o.tipo_df
    and r.cd_conta         = o.cd_conta
    and r.ds_conta         = o.ds_conta
    and r.dt_inicio        = o.dt_inicio
    and r.dt_fim_exercicio = o.dt_fim_exercicio
    and r.dt_referencia    > o.dt_referencia

where o.escala_moeda <> r.escala_moeda
  and abs(o.vl_conta_bruto - r.vl_conta_bruto)
        <= abs(o.vl_conta_bruto) * 1e-9
