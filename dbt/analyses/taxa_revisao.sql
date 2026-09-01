with pares as (

    select
        r.cd_cvm,
        r.demonstrativo,
        r.tipo_df,
        r.dt_fim_exercicio,
        r.ano_exercicio,
        r.valor_original,
        r.valor_revisado,
        r.dif_pct,
        r.comparavel,
        f.conta_fixa,
        s.conceito,
        p.tipo_df_escolhido

    from {{ ref('int_revisoes_entre_safras') }} as r

    left join {{ ref('fct_fundamentos') }} as f
        on  f.cd_cvm           = r.cd_cvm
        and f.dt_fim_exercicio = r.dt_fim_exercicio
        and f.tipo_df          = r.tipo_df
        and f.demonstrativo    = r.demonstrativo
        and f.cd_conta         = r.cd_conta
        and f.dt_referencia    = r.dt_referencia_original

    left join {{ ref('contas_canonicas') }} as s
        on  s.demonstrativo = r.demonstrativo
        and s.cd_conta      = r.cd_conta
        and s.ds_conta      = r.ds_conta_original

    left join {{ ref('int_empresas_tipo_df') }} as p
        on  p.cd_cvm           = r.cd_cvm
        and p.dt_fim_exercicio = r.dt_fim_exercicio

),

classificado as (

    select
        *,
        valor_revisado <> valor_original as mudou,
        case
            when valor_original = 0 and valor_revisado = 0 then false
            when valor_original = 0                        then true
            else abs(dif_pct) > 0.01
        end as material,
        conceito in ('ativo_total', 'passivo_total', 'patrimonio_liquido',
                     'receita_liquida', 'lucro_liquido') as eh_sintese
    from pares

),

por_par as (

    select '01. universo completo' as recorte, mudou, material from classificado
    union all
    select '01b. universo, exceto pares 0 -> 0', mudou, material from classificado
      where not (valor_original = 0 and valor_revisado = 0)
    union all
    select '02. so contas fixas', mudou, material from classificado where conta_fixa
    union all
    select '03. so consolidado', mudou, material from classificado where tipo_df = 'CONSOLIDADO'
    union all
    select '04. so contas com conceito mapeado', mudou, material from classificado
      where conceito is not null
    union all
    select '05. so conceitos de sintese', mudou, material from classificado where eh_sintese
    union all
    select '05b. sintese, na politica con/ind do mart', mudou, material from classificado
      where eh_sintese and tipo_df = tipo_df_escolhido
    union all
    select '05c. sintese, apenas pares comparaveis', mudou, material from classificado
      where eh_sintese and tipo_df = tipo_df_escolhido and comparavel is true
    union all
    select '06. demonstrativo: ' || demonstrativo, mudou, material from classificado
    union all
    select '07. exercicio ' || cast(ano_exercicio as varchar), mudou, material from classificado

),

agregado as (

    select
        recorte,
        count(*)                                   as pares,
        sum(case when mudou    then 1 else 0 end)  as n_mudou,
        round(100.0 * sum(case when mudou    then 1 else 0 end) / count(*), 2) as pct_mudou,
        sum(case when material then 1 else 0 end)  as n_material,
        round(100.0 * sum(case when material then 1 else 0 end) / count(*), 2) as pct_material
    from por_par
    group by 1

),

ficha as (

    select
        cd_cvm,
        dt_fim_exercicio,
        max(case when mudou    then 1 else 0 end) as mudou,
        max(case when material then 1 else 0 end) as material
    from classificado
    where eh_sintese
      and tipo_df = tipo_df_escolhido
    group by 1, 2

)

select * from agregado

union all

select
    '08. POR FICHA (empresa x exercicio) -- MANCHETE',
    count(*),
    sum(mudou),
    round(100.0 * sum(mudou) / count(*), 2),
    sum(material),
    round(100.0 * sum(material) / count(*), 2)
from ficha

order by 1
