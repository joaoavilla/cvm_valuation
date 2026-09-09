# Pré-revisão final

Título sugerido: `fix: corrige fundamentos e valida selecao temporal`

## Descrição para o PR

Esta branch corrige indicadores que substituíam componentes ausentes por outros
conceitos ou por zero. Margem e ROE usam uma regra explícita por base; dívida,
alavancagem e liquidez seca exigem seus componentes. Indicadores sobre resultado
total usam o sufixo `_total`.

Também aprimora escala monetária e tratamento de ambiguidades, registra contratos
contábeis e introduz observações por período com três políticas de seleção temporal.
O corte de publicação precede a escolha; empates na data selecionada impedem uma
escolha automática, inclusive quando os valores coincidem. Os candidatos continuam
disponíveis no modelo de observações e na auditoria.

O piloto CELGPAR testa a mesma macro oferecida aos consumidores, antes da primeira
publicação, antes da correção, no dia da correção e depois. Testes sintéticos cobrem
as três políticas, datas desconhecidas e empates. A preservação de ZIPs anteriores
verifica SHA-256 completo e promove a cópia temporária atomicamente; uma falha impede
a substituição do arquivo corrente.

### Limites do escopo

- O piloto temporal ainda não alimenta os indicadores do painel.
- O acervo não contém todas as versões históricas; a seleção é limitada ao preservado.
- A granularidade pública é diária, sem garantia de disponibilidade intradiária.
- Não retornar uma observação exige consultar candidatos para distinguir empate de
  histórico insuficiente. A interface de status por contexto pertence à próxima etapa.
- Preservar ZIPs não substitui um histórico completo de manifestos e incorporações.
- Os avisos de dados permanecem visíveis; build sem erros não certifica todo o universo.

## Próxima branch

Separar classificação, candidatos, resolução e publicação antes do pivot, começando
pelos resultados. Registrar contexto completo, evidência e regra para cada escolha;
expor status de ausência, conflito e empate aos consumidores. Comparar valores e
disponibilidade antes/depois por coorte, sem editar os valores finais manualmente.

Manter histórico de capturas, manifestos e execuções como frente delimitada. ML só
deve propor classificações após existir referência revisada e avaliação independente.

## Validação final

- `python -m pytest -q`: **11 passed**.
- `dbt build`: **PASS=152 · WARN=8 · ERROR=0 · TOTAL=160**, término
  registrado em `run_results.json` da execução de 2026-09-09.
- Teste das três políticas: zero falhas; remover a proteção de empate numa cópia
  em memória do SQL compilado produz `politica_temporal_incorreta`.
- Âncora WEG 2023: receita 32.503.601.000; lucro total 5.867.615.000;
  controladores 5.731.670.000; margem 0,17633953850221087.
- Contagens mantidas frente ao checkpoint anterior: 10.847 fichas, 8.333 margens,
  9.002 ROEs, 10.197 dívidas brutas, 8.820 alavancagens e 10.015 liquidez secas.

Consultas reproduzíveis, conexão somente leitura após o build:

```sql
select receita_liquida, lucro_liquido, lucro_liquido_controladores, margem_liquida
from mart_fundamentos_anuais
where cd_cvm = '005410' and dt_fim_exercicio = date '2023-12-31';

select count(*) fichas, count(margem_liquida) margens, count(roe) roes,
       count(divida_bruta) dividas, count(alavancagem) alavancagens,
       count(liquidez_seca) liquidez_seca
from mart_fundamentos_anuais;
```

Os oito avisos são: descrição DRE ausente (2 linhas), deduplicação divergente (127),
escala contraditória (8.325), margem zero com lucro não zero (1), ROE extremo (20),
ativo ausente (3), ordem original posterior ao comparativo (20.145 contextos) e
empates de publicação (33.694 contextos/data). As contagens vêm dos resultados dos
respectivos testes em `dbt/target/run_results.json`, com linhas em
`main_dbt_test__audit`. O último aviso passou a incluir valores iguais, pois a origem
documental permanece ambígua. Não representa 33.694 erros contábeis demonstrados.

Parecer: os bloqueios P1 desta pré-revisão foram corrigidos. A branch está apta a
push e revisão do PR dentro do escopo descrito; não certifica o painel histórico
completo nem encerra as pendências contábeis já registradas.
