from pathlib import Path

BASE_URL = "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS"
RAW_DIR = Path("data/raw/dfp")
MANIFEST_DIR = RAW_DIR / "_manifests"

ANOS_DISPONIVEIS = range(2010, 2026)

DEMONSTRATIVOS = {
    "dre": "DRE",
    "bpa": "BPA",
    "bpp": "BPP",
    "dfc_mi": "DFC_MI",
    "dfc_md": "DFC_MD",
}
TIPOS = {"con": "con", "ind": "ind"}

COLUNAS = [
    "CNPJ_CIA", "DT_REFER", "VERSAO", "DENOM_CIA", "CD_CVM", "GRUPO_DFP",
    "MOEDA", "ESCALA_MOEDA", "ORDEM_EXERC", "DT_INI_EXERC", "DT_FIM_EXERC",
    "CD_CONTA", "DS_CONTA", "VL_CONTA", "ST_CONTA_FIXA",
]

# BPA e BPP são FOTOGRAFIAS (estoque): existem numa data, não num período —
# por isso não trazem DT_INI_EXERC. DRE, DFC e DVA são FILMES (fluxo) e trazem
# as duas datas. Registrar a ausência esperada aqui evita que o alerta de
# esquema vire ruído, sem deixar de gritar por ausências de verdade.
COLUNAS_AUSENTES_ESPERADAS = {
    "bpa": {"DT_INI_EXERC"},
    "bpp": {"DT_INI_EXERC"},
}
