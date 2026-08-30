# cvm_valuation

Pipeline de dados sobre as demonstrações financeiras das companhias abertas brasileiras (CVM), com modelagem que separa **o período a que um valor se refere** do **documento em que ele foi publicado**.

> **Estado:** em construção. A plataforma de dados funciona ponta a ponta; a camada de consumo (console de research) ainda não existe. Este README descreve o que há hoje, não o que se pretende.

---

## O problema

A CVM republica o mesmo exercício em documentos diferentes, com valores diferentes. Cada documento anual traz o exercício corrente e o comparativo do ano anterior - e o comparativo frequentemente **não coincide** com o que foi publicado à época.

Exemplo verificável nos dados: a Natura reportou **R$ 20,2 bi** de receita para 2022 no documento daquele ano, e **R$ 13,1 bi** para o mesmo exercício no documento de 2023.

A maior parte dos consumidores desse dado ignora a distinção - inclusive a versão anterior deste projeto, que somava dois exercícios como se fossem um por usar a data do documento como se fosse a data do fato.

---

## O que existe hoje

**Ingestão** (`ingestion/`) - baixa os ZIPs anuais da CVM com escrita atômica e validação, extrai um Parquet por CSV preservando o esquema original, e grava um manifesto por ano com hash, contagens e detecção de mudança na fonte. A CVM reescreve arquivos de anos antigos (o de 2020 foi alterado em dez/2024), então a ingestão sempre rebaixa e o manifesto informa o que mudou.

**Transformação** (`dbt/`) - camadas staging → intermediate → fato → mart sobre DuckDB.

| Camada | Conteúdo |
|---|---|
| `stg_cvm__*` | Tipagem, normalização de escala monetária, deduplicação, união de demonstrativos consolidados e individuais |
| `int_dfp_unificado` | Os cinco demonstrativos num grão único |
| `fct_fundamentos` | Grão `(empresa, período, safra, tipo_df, conta)` - a tabela central |
| `int_revisoes_entre_safras` | Compara o valor publicado no ano contra o reapresentado no ano seguinte |
| `mart_fundamentos_anuais` | Uma linha por empresa e exercício, com indicadores |

**Escala:** 16 anos (2010–2025) · 1.223 empresas · ~8,5 M linhas no fato · 10.847 linhas no mart. Roda em uma máquina, em segundos. Não há aqui volume que justifique processamento distribuído, e o projeto não finge que há.

---

## Decisões de modelagem

**A descrição da conta faz parte da chave.** O código da CVM não determina o significado: `2.03` é Patrimônio Líquido para 1.867 empresas e outra coisa para ~120; `3.11` é lucro líquido na maioria e *"Reversão dos Juros sobre Capital Próprio"* em 61. O seed (`dbt/seeds/contas_canonicas.csv`) mapeia `(demonstrativo, código, descrição) → conceito`. Descrição não mapeada não faz join e vira nulo - ausência detectável em vez de número errado silencioso.

**Instituições financeiras têm conceitos próprios.** A receita de um banco é `fin_receita_intermediacao`, não `receita_liquida`. Isso faz margem de banco sair nula por construção do modelo, sem filtro no consumidor.

**O mart tem grão `(empresa, fim do exercício)`, não `(empresa, ano)`.** Vinte empresas mudaram o fim do exercício social e têm dois fechamentos no mesmo ano civil.

---

## Como rodar

Requer Python 3.12.

```bash
python -m venv .venv && source .venv/Scripts/activate   # Git Bash no Windows
pip install -r requirements.txt

python -m ingestion --anos 2010-2025                    # baixa e extrai (~170 MB)
```

Crie `~/.dbt/profiles.yml`:

```yaml
dbt_cvm:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: /caminho/absoluto/para/cvm_valuation/warehouse.duckdb
      threads: 4
```

```bash
cd dbt
dbt deps && dbt seed && dbt build
dbt docs generate && dbt docs serve                     # linhagem no navegador
```

Os comandos do dbt rodam de dentro de `dbt/` - os caminhos das fontes são relativos a esse diretório.

---

## Testes

```bash
python -m pytest              # ingestão
cd dbt && dbt build           # modelos + dados
```

A suíte codifica regra de negócio, não só estrutura: a identidade contábil `Ativo = Passivo + PL` (com duas exceções documentadas, defeitos da própria fonte), o grão declarado de cada modelo, e invariantes de desenho - por exemplo, que instituição financeira não pode ter margem calculada.

O CI executa `dbt build` a cada pull request sobre uma amostra versionada de 7 empresas (`tests/fixtures/`), escolhidas não por porte mas pelos comportamentos que exercitam: mudança de exercício social, descrição corrompida na fonte, plano de contas financeiro e as exceções da identidade contábil.

---

## Dados e licença

**Código:** MIT - ver [`LICENSE`](LICENSE).

**Dados:** a amostra em `tests/fixtures/` deriva dos microdados públicos da CVM e está sob **Open Database License (ODbL) v1.0** - ver [`LICENSE-DATA`](LICENSE-DATA).

> Contém informações da Comissão de Valores Mobiliários (CVM), obtidas do Portal de Dados Abertos e disponibilizadas sob Open Database License (ODbL) v1.0.

Fonte: <https://dados.cvm.gov.br/dataset/cia_aberta-doc-dfp>
