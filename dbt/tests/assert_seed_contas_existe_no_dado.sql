{{ config(severity = 'warn' if target.name == 'ci' else 'error') }}

-- Toda linha do seed precisa corresponder a uma conta que existe de fato.
--
-- SEVERIDADE POR AMBIENTE: no CI o dado e uma amostra de 7 empresas, entao
-- linhas do seed que descrevem planos de contas que essas empresas nao usam
-- (DFC_MD, seguradora, variantes raras) nao tem correspondencia -- ausencia
-- legitima, nao erro. Contra a base completa a afirmacao vale e o teste e
-- error: foi ele que pegou 30 chaves quebradas quando os acentos se perderam.
--
-- Por que: a chave do seed inclui ds_conta, casada por igualdade exata. Um
-- acento errado, um espaco a mais ou uma descricao que a CVM parou de usar
-- fazem a linha nunca dar join — e o conceito some do mart em silencio, sem
-- erro nenhum. Este teste transforma esse silencio em falha de build.
--
-- Complementa scripts/gerar_seed_contas.py --check: o script so roda quando
-- alguem lembra; este teste roda em todo dbt build, inclusive no CI.

select
    s.demonstrativo,
    s.cd_conta,
    s.ds_conta,
    s.conceito

from {{ ref('contas_canonicas') }} as s

left join {{ ref('int_dfp_unificado') }} as f
    on  f.demonstrativo = s.demonstrativo
    and f.cd_conta      = s.cd_conta
    and f.ds_conta      = s.ds_conta

where f.cd_conta is null

group by 1, 2, 3, 4
