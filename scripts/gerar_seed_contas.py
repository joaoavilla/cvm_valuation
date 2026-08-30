"""Gera e valida dbt/seeds/contas_canonicas.csv.

POR QUE ESTE SCRIPT EXISTE
--------------------------
O seed e curadoria humana: traduz (demonstrativo, cd_conta, ds_conta) da CVM
para um conceito economico. A curadoria nao e derivavel do dado -- mas as
DECISOES precisam ficar registradas, senao ninguem sabe por que uma descricao
foi incluida e outra nao.

O CSV continua sendo a fonte de verdade (convencao dbt: seed e dado versionado,
revisavel em diff de PR). Este script serve para (a) regerar o CSV de forma
reproduzivel, (b) VALIDAR que toda chave mapeada existe no dado, e (c) detectar
o erro pai/filho descrito abaixo.

    python scripts/gerar_seed_contas.py            # valida e regera
    python scripts/gerar_seed_contas.py --check    # so valida, nao escreve

A DESCOBERTA QUE DEFINIU O DESENHO
----------------------------------
cd_conta sozinho NAO determina significado. Coortes de empresas usam planos de
contas diferentes sob os mesmos codigos (medido em 8,5M linhas, 2010-2025):

  grupo       1.02                     2.03                      3.11
  --------------------------------------------------------------------------
  61 emp.     Ativo Realizavel a LP    Result. Exerc. Futuros    Reversao JCP
  27 emp.     Aplicacoes Financeiras   Provisoes                 Lucro Liquido
   4 emp.     -                        -                         Result Op Cont

No grupo de 4 a numeracao esta DESLOCADA: 3.07 neles = 3.05 no padrao.
Mapear por codigo daria "Reversao de JCP" como lucro liquido em 61 empresas.
Por isso ds_conta entra na chave: descricao nao mapeada nao faz join e vira
NULL -- ausencia detectavel em vez de numero errado silencioso.
"""

import argparse
import csv
import sys
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parents[1]
WAREHOUSE = RAIZ / "warehouse.duckdb"
DESTINO = RAIZ / "dbt" / "seeds" / "contas_canonicas.csv"

# (demonstrativo, cd_conta, ds_conta) -> (conceito, plano)
#
# Regra: so entra descricao cujo SIGNIFICADO e o conceito. Variantes de
# instituicao financeira ganham conceito proprio (prefixo fin_) para que o mart
# produza NULL em margem de banco por construcao, sem precisar de flag.
MAPEAMENTO = {
    # --- Ativo -------------------------------------------------------------
    ("BPA", "1", "Ativo Total"): ("ativo_total", "PADRAO"),
    ("BPA", "1", "Ativo"): ("ativo_total", "PADRAO"),
    ("BPA", "1", "Ativo total:"): ("ativo_total", "PADRAO"),
    # 1 = "0" e 1 = "A" ficam de fora: 1 empresa cada, descricao corrompida.

    ("BPA", "1.01", "Ativo Circulante"): ("ativo_circulante", "PADRAO"),
    # EXCLUIDO ("BPA","1.01","Caixa e Equivalentes de Caixa"): em 45 documentos
    # este codigo e o PAI de 1.01.01 (Caixa / Disponibilidades). Mapear os dois
    # somava caixa duas vezes. As empresas seguem cobertas pelo filho.

    ("BPA", "1.01.01", "Caixa e Equivalentes de Caixa"): ("caixa_e_equivalentes", "PADRAO"),
    ("BPA", "1.01.01", "Caixa e equivalentes de caixa"): ("caixa_e_equivalentes", "PADRAO"),
    ("BPA", "1.01.01", "Disponibilidades"): ("caixa_e_equivalentes", "LEGADO"),
    # EXCLUIDO ("BPA","1.01.01","Caixa"): mesmo motivo -- filho do 1.01 nas 27
    # empresas do plano financeiro; e caixa fisico, subconjunto do grupo.

    ("BPA", "1.02", "Ativo Não Circulante"): ("ativo_nao_circulante", "PADRAO"),
    ("BPA", "1.02", "Ativo Realizável a Longo Prazo"): ("ativo_nao_circulante", "LEGADO"),
    # 1.02 = "Ativos Financeiros" / "Aplicacoes Financeiras" ficam de fora:
    # no plano financeiro nao equivalem a ativo nao circulante.

    # --- Passivo -----------------------------------------------------------
    ("BPP", "2", "Passivo Total"): ("passivo_total", "PADRAO"),
    ("BPP", "2.01", "Passivo Circulante"): ("passivo_circulante", "PADRAO"),
    ("BPP", "2.02", "Passivo Não Circulante"): ("passivo_nao_circulante", "PADRAO"),
    ("BPP", "2.02", "Passivo Exigível a Longo Prazo"): ("passivo_nao_circulante", "LEGADO"),

    ("BPP", "2.03", "Patrimônio Líquido"): ("patrimonio_liquido", "PADRAO"),
    ("BPP", "2.03", "Patrimônio Líquido Consolidado"): ("patrimonio_liquido", "PADRAO"),
    # 2.03 = "Resultados de Exercicios Futuros" (61), "Passivos Financeiros ao
    # Custo Amortizado" (32) e "Provisoes" (27) NAO sao PL. E o caso que mais
    # justifica ter a descricao na chave.
    ("BPP", "2.08", "Patrimônio Líquido Consolidado"): ("patrimonio_liquido", "FINANCEIRO"),

    # --- Resultado ---------------------------------------------------------
    ("DRE", "3.01", "Receita de Venda de Bens e/ou Serviços"): ("receita_liquida", "PADRAO"),
    ("DRE", "3.01", "Receita Bruta de Venda de Bens e/ou Serviços"): ("receita_liquida", "PADRAO"),
    ("DRE", "3.01", "Receita"): ("receita_liquida", "PADRAO"),
    ("DRE", "3.01", "Receitas da Intermediação Financeira"): ("fin_receita_intermediacao", "FINANCEIRO"),
    ("DRE", "3.01", "Receitas de Intermediação Financeira"): ("fin_receita_intermediacao", "FINANCEIRO"),
    ("DRE", "3.01", "Receitas das Atividades Seguradoras/Resseguradoras"): ("fin_receita_seguros", "SEGURADORA"),

    ("DRE", "3.02", "Custo dos Bens e/ou Serviços Vendidos"): ("custo", "PADRAO"),
    ("DRE", "3.02", "Despesas da Intermediação Financeira"): ("fin_despesa_intermediacao", "FINANCEIRO"),
    ("DRE", "3.02", "Despesas de Intermediação Financeira"): ("fin_despesa_intermediacao", "FINANCEIRO"),

    ("DRE", "3.03", "Resultado Bruto"): ("lucro_bruto", "PADRAO"),
    ("DRE", "3.03", "Resultado Bruto Intermediação Financeira"): ("fin_resultado_intermediacao", "FINANCEIRO"),
    ("DRE", "3.03", "Resultado Bruto de Intermediação Financeira"): ("fin_resultado_intermediacao", "FINANCEIRO"),

    ("DRE", "3.04", "Despesas/Receitas Operacionais"): ("despesas_operacionais", "PADRAO"),

    # EBIT: "antes do resultado financeiro E dos tributos". No plano deslocado
    # a mesma frase aparece em 3.07 -- e a descricao que manda, nao o codigo.
    ("DRE", "3.05", "Resultado Antes do Resultado Financeiro e dos Tributos"): ("ebit", "PADRAO"),
    ("DRE", "3.07", "Resultado Antes do Resultado Financeiro e dos Tributos"): ("ebit", "DESLOCADO"),
    # 3.05 = "Resultado Operacional" (legado) fica de fora: incluia o nao
    # operacional, nao equivale a EBIT.

    ("DRE", "3.06", "Resultado Financeiro"): ("resultado_financeiro", "PADRAO"),

    ("DRE", "3.07", "Resultado Antes dos Tributos sobre o Lucro"): ("lucro_antes_tributos", "PADRAO"),
    ("DRE", "3.05", "Resultado Antes dos Tributos sobre o Lucro"): ("lucro_antes_tributos", "DESLOCADO"),
    ("DRE", "3.05", "Resultado antes dos Tributos sobre o Lucro"): ("lucro_antes_tributos", "DESLOCADO"),
    ("DRE", "3.07", "Resultado Antes Tributação/Participações"): ("lucro_antes_tributos", "LEGADO"),

    ("DRE", "3.11", "Lucro/Prejuízo do Período"): ("lucro_liquido", "PADRAO"),
    ("DRE", "3.11", "Lucro/Prejuízo Consolidado do Período"): ("lucro_liquido", "PADRAO"),
    ("DRE", "3.11", "Lucro ou Prejuízo Líquido do Período"): ("lucro_liquido", "FINANCEIRO"),
    ("DRE", "3.11", "Lucro ou Prejuízo Líquido Consolidado do Período"): ("lucro_liquido", "FINANCEIRO"),
    # 3.11 = "Reversao dos Juros sobre Capital Proprio" (61 empresas) NAO e
    # lucro liquido. E o exemplo canonico do risco de mapear por codigo.
    ("DRE", "3.13", "Lucro/Prejuízo do Período"): ("lucro_liquido", "FINANCEIRO"),
    ("DRE", "3.13", "Lucro/Prejuízo Consolidado do Período"): ("lucro_liquido", "FINANCEIRO"),

    # --- Fluxo de caixa ----------------------------------------------------
    ("DFC_MI", "6.01", "Caixa Líquido Atividades Operacionais"): ("fluxo_caixa_operacional", "PADRAO"),
    ("DFC_MI", "6.01", "Caixa Líquido das Atividades Operacionais"): ("fluxo_caixa_operacional", "PADRAO"),
    ("DFC_MI", "6.02", "Caixa Líquido Atividades de Investimento"): ("fluxo_caixa_investimento", "PADRAO"),
    ("DFC_MI", "6.03", "Caixa Líquido Atividades de Financiamento"): ("fluxo_caixa_financiamento", "PADRAO"),
    ("DFC_MD", "6.01", "Caixa Líquido Atividades Operacionais"): ("fluxo_caixa_operacional", "PADRAO"),
    ("DFC_MD", "6.02", "Caixa Líquido Atividades de Investimento"): ("fluxo_caixa_investimento", "PADRAO"),
    ("DFC_MD", "6.03", "Caixa Líquido Atividades de Financiamento"): ("fluxo_caixa_financiamento", "PADRAO"),
}

CABECALHO = ["demonstrativo", "cd_conta", "ds_conta", "conceito", "plano"]


def validar(con):
    """Devolve lista de problemas. Vazia = seed integro."""
    problemas = []

    existentes = set(
        con.sql(
            "select distinct demonstrativo, cd_conta, ds_conta "
            "from int_dfp_unificado where conta_fixa"
        ).fetchall()
    )
    for chave in MAPEAMENTO:
        if chave not in existentes:
            problemas.append("chave inexistente no dado: {}".format(chave))

    # Pai/filho: se A e B mapeiam o MESMO conceito e A e prefixo de B, os dois
    # somariam junto quando a empresa tiver ambos. Foi o bug do caixa.
    for (d1, c1, _), (conc1, _) in MAPEAMENTO.items():
        for (d2, c2, _), (conc2, _) in MAPEAMENTO.items():
            if d1 == d2 and conc1 == conc2 and c1 != c2 and c2.startswith(c1 + "."):
                problemas.append(
                    "hierarquia no mesmo conceito '{}': {} e pai de {}".format(conc1, c1, c2)
                )

    return sorted(set(problemas))


def main():
    p = argparse.ArgumentParser(description="Gera/valida o seed de contas canonicas.")
    p.add_argument("--check", action="store_true", help="apenas valida, nao escreve")
    args = p.parse_args()

    con = duckdb.connect(str(WAREHOUSE), read_only=True)
    problemas = validar(con)
    if problemas:
        print("[FALHA] problemas encontrados:")
        for x in problemas:
            print("  -", x)
        return 1
    print("[OK] {} chaves validadas contra o dado".format(len(MAPEAMENTO)))

    if args.check:
        return 0

    linhas = sorted(
        ((d, cd, ds, conc, plano) for (d, cd, ds), (conc, plano) in MAPEAMENTO.items()),
        key=lambda r: (r[0], r[1], r[3]),
    )
    with open(DESTINO, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(CABECALHO)
        w.writerows(linhas)

    print("[OK] {} -- {} linhas, {} conceitos".format(
        DESTINO.relative_to(RAIZ), len(linhas), len({r[3] for r in linhas})))
    return 0


if __name__ == "__main__":
    sys.exit(main())
