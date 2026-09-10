with base as (
 select 'X' as cd_cvm, 'CONSOLIDADO' as tipo_df, 'DRE' as demonstrativo,
        '3.11' as cd_conta, 'Resultado' as ds_conta,
        date '2023-01-01' as dt_inicio_exercicio, date '2023-12-31' as dt_fim_exercicio,
        d as dt_recebimento, v as valor
 from (values (date '2024-01-01', 10), (date '2024-02-01', 20),
              (date '2024-02-01', 30), (null::date, 99)) t(d,v)
),
antiga as ({{ observacao_vigente_em('base', "date '2024-01-31'") }}),
empate as ({{ observacao_vigente_em('base', "date '2024-02-01'") }}),
recente as ({{ observacao_mais_recente('base') }}),
primeira as ({{ primeira_observacao_preservada('base') }}),
sem_historico as ({{ observacao_vigente_em('base', "date '2023-01-01'") }}),
igual as (select * replace (20 as valor) from base where dt_recebimento = date '2024-02-01'),
empate_igual as ({{ observacao_mais_recente('igual') }})
select 'politica_temporal_incorreta' as falha
where (select count(*) from antiga where valor=10) <> 1
   or (select count(*) from antiga) <> 1
   or (select count(*) from primeira where valor=10) <> 1
   or (select count(*) from primeira) <> 1
   or exists (select 1 from empate)
   or exists (select 1 from recente)
   or exists (select 1 from sem_historico)
   or exists (select 1 from empate_igual)
