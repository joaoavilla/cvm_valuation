import os
import pandas as pd

BASE = "data_processed/cvm/dfp"

FILES = {
    "DRE":    "dre_2010_2024.parquet",
    "BPA":    "bpa_2010_2024.parquet",
    "BPP":    "bpp_2010_2024.parquet",
    "DFC_MI": "dfc_mi_2010_2024.parquet",
    "DFC_MD": "dfc_md_2010_2024.parquet",
}


# ============================================================================
# AUXILIAR: Carrega todos os datasets
# ============================================================================
def load_all():
    dfs = {}
    for k, fname in FILES.items():
        path = os.path.join(BASE, fname)
        if not os.path.exists(path):
            print(f"[ERRO] Arquivo não encontrado: {path}")
        else:
            dfs[k] = pd.read_parquet(path)
            print(f"[OK] Carregado: {k}  ({len(dfs[k]):,} linhas)")
    return dfs


# ============================================================================
# 1. Validação estrutural simples
# ============================================================================
def validate_structure(dfs):

    print("\n==============================")
    print("VALIDAÇÃO ESTRUTURAL")
    print("==============================")

    for nome, df in dfs.items():
        print(f"\n### {nome} ###")
        print("Colunas:", list(df.columns))

        if "DT_REFER" in df:
            print("Período:", df["DT_REFER"].min().date(), "→", df["DT_REFER"].max().date())

        if "CD_CVM" in df:
            print("Empresas únicas:", df["CD_CVM"].nunique())

        if "VL_CONTA_REAL" in df:
            print("Distribuição VL_CONTA_REAL:")
            print(df["VL_CONTA_REAL"].describe(percentiles=[.01, .25, .5, .75, .99]))


# ============================================================================
# 2. Caçar automaticamente Petrobras, Vale e Itaú
# ============================================================================
def find_company_codes(df, nome):
    """Localiza o CD_CVM correto usando busca textual na DENOM_CIA."""
    sub = df[df["DENOM_CIA"].str.contains(nome, case=False, na=False)]
    if sub.empty:
        return None, None

    # pegar lista única de nomes e códigos
    uniq = sub[["DENOM_CIA", "CD_CVM"]].drop_duplicates()
    
    return uniq, uniq["CD_CVM"].unique().tolist()


# ============================================================================
# 3. Validação profunda de 3 empresas-âncora
# ============================================================================
def validate_anchor_companies(dfs):

    print("\n==============================")
    print("VALIDAÇÃO DE EMPRESAS ÂNCORA")
    print("==============================")

    dre = dfs["DRE"]
    bpa = dfs["BPA"]
    bpp = dfs["BPP"]

    empresas = {
        "PETRO": "PETROBRAS",
        "VALE": "VALE",
        "ITA": "ITAÚ UNIBANCO"
    }

    for chave, nome_print in empresas.items():
        print(f"\n>>> BUSCANDO: {nome_print}")

        uniq, cods = find_company_codes(dre, chave)

        if uniq is None:
            print("  [ERRO] Empresa não encontrada via DENOM_CIA.")
            continue

        print("  Nomes identificados:")
        print(uniq)

        for cod in cods:
            print(f"\n  :: Validando CD_CVM = {cod}")

            dre_sub = dre[(dre["CD_CVM"] == cod) & (dre["DT_REFER"].dt.year == 2023)]
            bpa_sub = bpa[(bpa["CD_CVM"] == cod) & (bpa["DT_REFER"].dt.year == 2023)]
            bpp_sub = bpp[(bpp["CD_CVM"] == cod) & (bpp["DT_REFER"].dt.year == 2023)]

            if dre_sub.empty:
                print("    - Sem DRE 2023.")
            else:
                print("    - Principais contas DRE 2023:")
                print(
                    dre_sub[["DS_CONTA", "VL_CONTA_REAL"]]
                    .sort_values("VL_CONTA_REAL", ascending=False)
                    .head(10)
                )

            if not bpa_sub.empty and not bpp_sub.empty:
                ativo = bpa_sub[bpa_sub["DS_CONTA"].str.contains("Ativo Total", case=False)]
                passivo = bpp_sub[bpp_sub["DS_CONTA"].str.contains("Passivo Total", case=False)]

                print("\n    - Ativo Total:")
                print(ativo[["DS_CONTA", "VL_CONTA_REAL"]])

                print("\n    - Passivo Total:")
                print(passivo[["DS_CONTA", "VL_CONTA_REAL"]])
            else:
                print("    - BPA/BPP para 2023 indisponíveis.")


# ============================================================================
# 4. Testes contábeis fundamentais (automáticos)
# ============================================================================
def validate_accounting_rules(dfs):
    print("\n==============================")
    print("TESTES CONTÁBEIS FUNDAMENTAIS")
    print("==============================")

    bpa = dfs["BPA"]
    bpp = dfs["BPP"]

    # Teste: Ativo Total ≈ Passivo Total + PL
    # (só verificamos Ativo vs Passivo, já que PL pode ser inferido)
    bpa_ativo = bpa[bpa["DS_CONTA"].str.contains("Ativo Total", case=False)]
    bpp_passivo = bpp[bpp["DS_CONTA"].str.contains("Passivo Total", case=False)]

    merged = pd.merge(
        bpa_ativo, bpp_passivo,
        on=["CD_CVM", "DT_REFER"],
        suffixes=("_ATV", "_PAS")
    )

    merged["diferença"] = merged["VL_CONTA_REAL_ATV"] - merged["VL_CONTA_REAL_PAS"]

    print("\nDiferença média Ativo - Passivo:", merged["diferença"].mean())
    print("Diferença absoluta média:", merged["diferença"].abs().mean())
    print("Percentil 99 da diferença:", merged["diferença"].abs().quantile(0.99))


# ============================================================================
# MAIN
# ============================================================================
if __name__ == "__main__":

    print("\n### INICIANDO VALIDAÇÃO COMPLETA ###\n")

    dfs = load_all()
    validate_structure(dfs)
    validate_anchor_companies(dfs)
    validate_accounting_rules(dfs)

    print("\n### VALIDAÇÃO CONCLUÍDA ###")
