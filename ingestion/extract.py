"""ZIP da CVM -> Parquets crus.

Regra do módulo: um CSV da CVM vira um Parquet, tudo texto, sem interpretar
nada. O raw é espelho da fonte — se um número está estranho, dá para auditar
contra o arquivo original. Transformação (escala, tipos, renome) é do dbt.
"""

import zipfile
from pathlib import Path

import pandas as pd

from .config import COLUNAS, COLUNAS_AUSENTES_ESPERADAS, DEMONSTRATIVOS, TIPOS


def nome_no_zip(demonstrativo: str, tipo: str, ano: int) -> str:
    """('dre', 'con', 2023) -> 'dfp_cia_aberta_DRE_con_2023.csv'"""
    return f"dfp_cia_aberta_{DEMONSTRATIVOS[demonstrativo]}_{tipo}_{ano}.csv"


def nome_cadastro(ano: int) -> str:
    """O arquivo cadastral do ano: um registro por documento entregue."""
    return f"dfp_cia_aberta_{ano}.csv"


def _ler_csv(zf: zipfile.ZipFile, nome: str) -> pd.DataFrame:
    """Lê um CSV de dentro do ZIP com as três escolhas que o legado já acertava.

    sep=';'           -> padrão brasileiro adotado pela CVM
    encoding='latin1' -> ISO-8859-1; é o que preserva 'ÚLTIMO' sem mojibake
    dtype=str         -> preserva o zero-padding de CD_CVM ('009512', não 9512)
                         e impede o pandas de inferir tipos diferentes a cada ano
    """
    with zf.open(nome) as f:
        df = pd.read_csv(f, sep=";", encoding="latin1", dtype=str)
    df.columns = [c.strip().upper() for c in df.columns]
    return df


def _selecionar_colunas(df: pd.DataFrame, demo: str, nome: str, ano: int) -> pd.DataFrame:
    """Mantém as COLUNAS do config, avisando alto se alguma sumiu.

    O legado fazia `[c for c in colunas if c in df.columns]` em silêncio: se a
    CVM renomeasse uma coluna, o Parquet saía incompleto sem um único aviso.
    Coluna ausente aqui é mudança de esquema da fonte — você quer saber.
    Nas 15 safras medidas isto nunca disparou; se disparar, investigue antes
    de seguir.
    """
    esperado_ausente = COLUNAS_AUSENTES_ESPERADAS.get(demo, set())
    presentes = [c for c in COLUNAS if c in df.columns]
    faltando = [c for c in COLUNAS if c not in df.columns and c not in esperado_ausente]
    if faltando:
        print(f"  [ALERTA] {ano} {nome}: colunas ausentes -> {faltando}")
    return df[presentes]


def extrair_ano(zip_path: Path, ano: int, saida_dir: Path) -> dict[str, int]:
    """Extrai os 10 demonstrativos (5 x con/ind) + o cadastral para Parquet.

    Devolve {'dre_con': 33970, ..., 'cadastro': 891}: as contagens que o
    manifesto guarda. Comparar contagem entre execuções é o jeito barato de
    perceber que a CVM mexeu no arquivo.

    O destino usa `ano=YYYY/` (particionamento estilo Hive): permite
    reprocessar um ano sem tocar nos outros, e o DuckDB deriva a coluna `ano`
    do próprio caminho ao ler com hive_partitioning.
    """
    destino = Path(saida_dir) / f"ano={ano}"
    destino.mkdir(parents=True, exist_ok=True)

    linhas: dict[str, int] = {}

    with zipfile.ZipFile(zip_path) as zf:
        disponiveis = set(zf.namelist())

        for demo in DEMONSTRATIVOS:
            for tipo in TIPOS:
                nome = nome_no_zip(demo, tipo, ano)
                chave = f"{demo}_{tipo}"

                if nome not in disponiveis:
                    print(f"  [AVISO] {ano}: {nome} não existe no ZIP — pulando")
                    continue

                df = _selecionar_colunas(_ler_csv(zf, nome), demo, nome, ano)
                df.to_parquet(destino / f"{chave}.parquet", index=False)
                linhas[chave] = len(df)

        # O cadastral vai INTEIRO (sem filtro de colunas): é dele que sai
        # DT_RECEB, a data em que cada documento ficou público. Sem essa coluna
        # não existe análise de safra com data real — só com data presumida.
        nome_cad = nome_cadastro(ano)
        if nome_cad in disponiveis:
            cad = _ler_csv(zf, nome_cad)
            cad.to_parquet(destino / "cadastro.parquet", index=False)
            linhas["cadastro"] = len(cad)
        else:
            print(f"  [AVISO] {ano}: {nome_cad} não existe no ZIP")

    return linhas
