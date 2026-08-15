import os
import zipfile
import requests
import pandas as pd

BASE_DFP = "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS"
RAW_DIR  = "data_raw/cvm/dfp"
OUT_DIR  = "data_processed/cvm/dfp"

os.makedirs(RAW_DIR, exist_ok=True)
os.makedirs(OUT_DIR, exist_ok=True)

# ========================================================================
# DOWNLOAD
# ========================================================================

def baixar_zip_ano(year: int) -> str:
    url = f"{BASE_DFP}/dfp_cia_aberta_{year}.zip"
    local = os.path.join(RAW_DIR, f"dfp_{year}.zip")

    if not os.path.exists(local):
        print(f"[INFO] Baixando {url} ...")
        r = requests.get(url, timeout=150)
        r.raise_for_status()
        with open(local, "wb") as f:
            f.write(r.content)
        print(f"[OK] Salvo: {local}")
    else:
        print(f"[INFO] ZIP já existe: {local}")

    return local


# ========================================================================
# LEITURA CRUA
# ========================================================================

def ler_zip_csvs(local_zip: str) -> dict[str, pd.DataFrame]:
    dfs = {}
    with zipfile.ZipFile(local_zip) as z:
        for name in z.namelist():
            if not name.lower().endswith(".csv"):
                continue
            df = pd.read_csv(
                z.open(name),
                sep=";",
                encoding="latin1",
                dtype=str
            )
            df.columns = [c.strip().upper() for c in df.columns]
            dfs[name] = df
    return dfs


# ========================================================================
# TRATAMENTO — ESSENCIAL
# ========================================================================

def aplicar_escala(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df["VL_CONTA"] = pd.to_numeric(df["VL_CONTA"], errors="coerce")

    multiplicador = df["ESCALA_MOEDA"].map({"MIL": 1000, "UNIDADE": 1})
    multiplicador = multiplicador.fillna(1)

    df["VL_CONTA_REAL"] = df["VL_CONTA"] * multiplicador
    return df


def limpar_basico(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    # Converte datas
    if "DT_REFER" in df.columns:
        df["DT_REFER"] = pd.to_datetime(df["DT_REFER"], errors="coerce")

    # Apenas REAL
    if "MOEDA" in df.columns:
        df = df[df["MOEDA"].str.upper() == "REAL"]

    colunas = [
        "CNPJ_CIA", "CD_CVM", "DENOM_CIA","DT_REFER", "GRUPO_DFP",
        "ORDEM_EXERC", "CD_CONTA", "DS_CONTA",
        "ESCALA_MOEDA", "VL_CONTA", "VL_CONTA_REAL"
    ]

    return df[[c for c in colunas if c in df.columns]].copy()


# ========================================================================
# PARSER — ESSENCIAL
# ========================================================================

def parse_dfp_ano(year: int) -> dict[str, pd.DataFrame]:
    local = baixar_zip_ano(year)
    dfs_raw = ler_zip_csvs(local)

    out = {
        "DRE": [],
        "DFC_MI": [],
        "DFC_MD": [],
        "BPA": [],
        "BPP": []
    }

    for name, df in dfs_raw.items():
        name_low = name.lower()

        if   "dre_con"     in name_low: grupo = "DRE"
        elif "dfc_mi_con"  in name_low: grupo = "DFC_MI"
        elif "dfc_md_con"  in name_low: grupo = "DFC_MD"
        elif "bpa_con"     in name_low: grupo = "BPA"
        elif "bpp_con"     in name_low: grupo = "BPP"
        else:
            continue

        df["GRUPO_DFP"] = grupo
        df = aplicar_escala(df)
        df = limpar_basico(df)

        out[grupo].append(df)

    for g in out:
        if out[g]:
            out[g] = pd.concat(out[g], ignore_index=True)
        else:
            out[g] = pd.DataFrame()

    return out


# ========================================================================
# EXECUÇÃO PRINCIPAL
# ========================================================================

def build_dfp(start_year=2010, end_year=2024):
    buckets = {"DRE": [], "DFC_MI": [], "DFC_MD": [], "BPA": [], "BPP": []}

    for year in range(start_year, end_year + 1):
        print(f"[ANO] {year}")
        ano_dfs = parse_dfp_ano(year)

        for g, df in ano_dfs.items():
            if not df.empty:
                buckets[g].append(df)

    for g, lst in buckets.items():
        if not lst:
            print(f"[WARN] Sem dados para {g}")
            continue

        full = pd.concat(lst, ignore_index=True)
        outpath = os.path.join(OUT_DIR, f"{g.lower()}_{start_year}_{end_year}.parquet")
        full.to_parquet(outpath, index=False)
        print(f"[OK] {g} salvo em {outpath}")


if __name__ == "__main__":
    build_dfp()
