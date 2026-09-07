---
name: validar-externo
description: Confere um indicador do mart contra uma fonte externa e converte divergência em teste de regressão permanente. Use quando pedirem para validar acurácia, comparar com Investidor10/StatusInvest/Fundamentus, investigar suspeita de número errado, ou ampliar o conjunto dourado.
---

# Validação contra fonte externa

Testes internos provam **consistência** — que o pipeline faz o que foi escrito.
Só fonte externa prova **correção** — que o que foi escrito é a coisa certa.

Neste repositório, todos os defeitos graves conhecidos foram encontrados por comparação
externa enquanto a suíte interna estava verde. Este é o laço que os encontra.

## Procedimento

### 1. Estabeleça o valor interno

```python
import duckdb
c = duckdb.connect("warehouse.duckdb", read_only=True)
c.sql("""
  select ano_exercicio, razao_social, receita_liquida, lucro_liquido_controladores,
         patrimonio_liquido, margem_liquida, roe
  from mart_fundamentos_anuais
  where cd_cvm = '<código>' and ano_exercicio between <a> and <b>
  order by 1
""").show()
```

Registre o número exato, sem arredondar.

### 2. Obtenha o valor externo

Fontes utilizáveis, em ordem de confiabilidade:

1. **Documento original da CVM** — a demonstração publicada. É a verdade, mas exige leitura manual.
2. **Agregadores** (Investidor10, StatusInvest, Fundamentus) — rápidos, e úteis justamente
   porque erram de forma diferente da nossa.

**Armadilha medida:** agregadores formatam o número conforme o intervalo consultado. O mesmo
lucro pode sair como `19.722,87 M` numa consulta e `19,72 B` noutra. Registre **qual consulta**
produziu o valor, e nunca conclua a partir do último dígito exibido.

### 3. Quando divergir, não presuma a causa

Investigue por camada, nesta ordem — cada uma é uma hipótese testável:

| Hipótese | Como testar |
|---|---|
| **Definição** — numeradores diferentes (consolidado vs. controladores) | Compare as duas versões que o mart já publica |
| **Conta** — o seed mapeou um código que naquele plano significa outra coisa | Consulte `contas_canonicas` e as linhas de `fct_fundamentos` daquela empresa |
| **Escala** — fator 1.000 ou 1.000.000 | A razão entre os valores é potência de mil? |
| **Base** — consolidado vs. individual | Consulte `int_empresas_tipo_df` |
| **Período** — exercício não-calendário | `dt_fim_exercicio` é 31/12? |
| **Safra** — a fonte usa o valor reapresentado | Consulte `int_revisoes_entre_safras` |

Uma diferença de definição é a causa mais comum e a mais fácil de confundir com erro de cálculo.
Descarte-a antes de mexer em código.

### 4. Transforme o achado em teste

Toda divergência confirmada vira ficha do conjunto dourado **antes** da correção, para que o
teste falhe, a correção o faça passar, e a regressão fique impedida.

```csv
cd_cvm,ano,conceito,valor_esperado,tolerancia_rel,fonte,url,data_verificacao,observacao
005410,2023,lucro_liquido_controladores,5731670000,0.001,<fonte>,<url>,<data>,
```

Tolerância **relativa** (`0,001` = 0,1%), nunca absoluta — o valor absoluto varia com a
formatação da fonte.

### 5. Verifique se o defeito é sistêmico

Um defeito encontrado numa empresa quase nunca afeta só ela. Antes de fechar, meça o alcance:

```sql
-- exemplo: quantas fichas têm o mesmo sintoma?
select count(*) fichas, count(distinct cd_cvm) empresas
from mart_fundamentos_anuais
where <condição do sintoma>
```

Quebre por coorte (plano de contas, setor, ano, financeira ou não). Um defeito com 63,8% de
alcance já passou despercebido neste repositório porque foi observado em uma empresa só.

## Critérios de saída

- O valor interno e o externo foram registrados com a consulta que os produziu.
- A causa foi identificada por camada, não presumida.
- O alcance foi medido e quebrado por coorte.
- Existe ficha no conjunto dourado e um teste que falha sem a correção.
