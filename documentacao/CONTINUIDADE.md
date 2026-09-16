# Decisões e continuidade

As regras de engenharia estão em `AGENTS.md`; definições contábeis em `CONTRATOS.md`.
Este documento substitui os registros de sessão como orientação permanente. A consolidação
documental de 2026-09-16 não altera modelos, dados, testes ou fórmulas.

## Decisões preservadas

- Ausência não é zero. Indicadores exigem componentes completos e expõem indisponibilidade.
- Resultado total e resultado dos controladores têm definições distintas. A base individual
  tem tratamento explícito, sem substituir silenciosamente o consolidado.
- Seleção temporal filtra a data pública antes de escolher a observação. Empates na data
  selecionada impedem escolha automática, mesmo com valores iguais. Candidatos permanecem
  consultáveis; ausência de seleção não distingue sozinha conflito de histórico insuficiente.
- `safra_original` não garante primeira publicação. O acervo preservado pode não conter
  versões anteriores. Datas desconhecidas não devem ser inventadas.
- Publicação, ingestão do arquivo e incorporação ao warehouse são eventos distintos.
- Preservação de ZIPs exige hash completo verificado e cópia atômica. Falha na preservação
  impede substituir o arquivo corrente; isso não recupera capturas anteriormente perdidas.
- O piloto temporal CELGPAR é protegido por `dbt/tests/assert_selecao_temporal.sql`.
  Ainda não constitui recuperação integrada aos indicadores do painel.
- Coerência entre saldo patrimonial de encerramento e resultado anual exige reconciliação
  documental. `R-PL-003` permanece hipótese; não ampliar vetos sem DMPL e notas.
- Não substituir bases consolidadas zeradas por individuais como política geral.

## Próxima frente: resolução antes do pivot

1. Separar classificação, geração de candidatos, resolução e publicação para resultados.
2. Registrar contexto econômico e documental completo, regra aplicada, evidência e rejeições.
3. Expor status para ausência, conflito, empate e indisponibilidade temporal.
4. Comparar valores, status e cobertura antes/depois por conceito, base, plano e período.
5. Integrar ao painel somente após validar casos independentes dos usados na implementação.
6. Generalizar por família: patrimônio, depois receita, custos e EBIT.

Pendências documentais: `R-LUC-004` (total derivado de filhos), bases zeradas, receita
bancária e `R-PL-003`. Cada uma exige fonte, período, unidade, base e justificativa próprios.
Não decidir significado apenas por fechamento aritmético ou código de conta.

Frente temporal adicional: preservar manifestos e execuções, vincular capturas às observações
e registrar incorporação. Investigar versões ausentes sem prometer recuperação integral.

## Procedimento de validação

- Identificar commit, estado da árvore, execução e fontes de cada medição.
- Não reconstruir o warehouse enquanto outra investigação mede esse estado.
- Guardar consulta reproduzível e denominador; revalidar conclusões antes de promovê-las a regra.
- Testar a implementação efetivamente consumida, incluindo contraexemplos e dados independentes.
- Referências externas devem comprovar o conceito exato e sua precisão; regressão interna não
  equivale a validação externa. Tolerância depende da unidade e arredondamento da fonte.
- Rodar as verificações de AGENTS.md, incluindo fixtures de CI quando o escopo as alcançar.
- Avisos são ocorrências a investigar, não prova automática de defeito da fonte.
- ML pode propor mapeamentos depois de existir referência revisada e avaliação independente;
  não deve estimar valores ausentes para publicá-los como reportados.

## Organização do repositório

Configurações específicas de ferramentas e relatos de sessão ficam locais e ignorados.
Contratos, documentação de produto, decisões permanentes e testes continuam versionados.
Remover arquivos do estado atual não os elimina do histórico Git; a limpeza documental
usa commit normal e PR, sem reescrita das branches publicadas.
