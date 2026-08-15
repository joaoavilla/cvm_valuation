import os
import pandas as pd

BASE = "data_processed/cvm/dfp"

ARQUIVOS = {
    "DRE":     "dre_2010_2024.parquet",
    "DFC_MI":  "dfc_mi_2010_2024.parquet",
    "DFC_MD":  "dfc_md_2010_2024.parquet",
    "BPA":     "bpa_2010_2024.parquet",
    "BPP":     "bpp_2010_2024.parquet",
}

def validar_arquivo(nome, caminho):
    print("\n" + "="*80)
    print(f"VALIDANDO: {nome}")
    print("="*80)

    if not os.path.exists(caminho):
        print(f"[ERRO] Arquivo não encontrado: {caminho}")
        return

    df = pd.read_parquet(caminho)

    print(f"[OK] Linhas: {len(df):,}")
    print(f"[OK] Colunas: {list(df.columns)}")

    if "DT_REFER" in df.columns:
        print(f"Período: {df['DT_REFER'].min().date()} → {df['DT_REFER'].max().date()}")
    
    if "CD_CVM" in df.columns:
        print(f"Empresas únicas: {df['CD_CVM'].nunique()}")

    if "DS_CONTA" in df.columns:
        print("\nExemplos de contas:")
        print(df["DS_CONTA"].dropna().unique()[:10])

    if "VL_CONTA_REAL" in df.columns:
        print("\nDistribuição VL_CONTA_REAL:")
        print(df["VL_CONTA_REAL"].describe(percentiles=[0.01, 0.25, 0.5, 0.75, 0.99]))

    return df


def validar_empresas(dre):
    print("\n" + "="*80)
    print("VALIDAÇÃO DE EMPRESAS ÂNCORA")
    print("="*80)

    empresas = {
        "Petrobras": ("9512", 2023),
        "Vale": ("4170", 2023),
        "Itaú": ("18376", 2023)
    }

    for nome, (codigo, ano) in empresas.items():
        print(f"\n>>> {nome} (CVM {codigo}), Ano {ano}")

        sub = dre[(dre["CD_CVM"] == codigo) & (dre["DT_REFER"].dt.year == ano)]
        if sub.empty:
            print("  [ERRO] Empresa não encontrada.")
            continue

        # Seleciona maiores contas (receitas geralmente aparecem no topo)
        sub_sorted = sub.sort_values("VL_CONTA_REAL", ascending=False)
        top = sub_sorted.head(5)[["DS_CONTA", "VL_CONTA_REAL"]]

        print(top.to_string(index=False))


if __name__ == "__main__":
    dfs = {}

    print("\n### INICIANDO VALIDAÇÃO DOS PARQUETS ###")
    for nome, file in ARQUIVOS.items():
        caminho = os.path.join(BASE, file)
        dfs[nome] = validar_arquivo(nome, caminho)

    # Valida empresas-âncora no DRE
    if dfs.get("DRE") is not None:
        validar_empresas(dfs["DRE"])
