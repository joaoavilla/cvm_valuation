# CLAUDE.md

**Leia `AGENTS.md` na raiz deste repositório antes de qualquer trabalho.** Ele é o documento
canônico: arquitetura, comandos, invariantes do domínio, convenções, riscos do ambiente e
definição de pronto. Este arquivo contém apenas o que é específico do Claude Code.

## Skills deste projeto

Em `.claude/skills/`. Invoque quando a tarefa corresponder:

| Skill | Quando usar |
|---|---|
| `validar-externo` | Conferir um indicador contra fonte de terceiros e transformar divergência em teste |
| `expandir-seed` | Acrescentar um conceito ao mapeamento de contas com segurança |
| `diagnostico-cobertura` | Descobrir coortes com dado ausente que a média esconde |

## Ferramentas

- Use **Bash** para consultas, medições e inspeção; **PowerShell** apenas quando precisar de
  cmdlets do Windows. O shell padrão do repositório nos exemplos é Bash.
- Consultas ao warehouse sempre com `read_only=True`.
- Arquivos temporários e downloads vão para o diretório de scratchpad da sessão, nunca para a
  árvore do projeto.

## Subagentes e paralelismo

Investigações amplas (varrer várias fontes, medir dimensões independentes) se beneficiam de
fan-out com verificação adversarial: um agente mede, outro tenta refutar re-medindo por outro
caminho. Nesta base, esse padrão já encontrou erros em investigações que pareciam sólidas.
Peça confirmação antes de disparar orquestrações grandes.

## Permissões

`.claude/settings.json` libera comandos de leitura frequentes (git de leitura, pytest, dbt,
consultas DuckDB) para reduzir interrupções. Comandos que escrevem continuam pedindo aprovação.
