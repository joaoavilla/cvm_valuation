import zipfile

import pandas as pd

from ingestion.config import COLUNAS, DEMONSTRATIVOS, TIPOS
from ingestion.extract import extrair_ano, nome_no_zip


def test_nome_no_zip():
    resultado = nome_no_zip("dre", "con", 2023)

    assert resultado == "dfp_cia_aberta_DRE_con_2023.csv"


def test_extrair_preserva_colunas_e_tipos(tmp_path):
    ano = 2023
    zip_path = tmp_path / "dfp_2023.zip"
    saida_dir = tmp_path / "raw"

    # Dados sintéticos.
    # ORDEM_EXERC contém caractere não-ASCII de propósito:
    # protege a decisão encoding='latin1'.
    dados = {
        coluna: ["valor_1", "valor_2", "valor_3"]
        for coluna in COLUNAS
    }

    dados["ORDEM_EXERC"] = ["ÚLTIMO", "ÚLTIMO", "PENÚLTIMO"]
    dados["DT_INI_EXERC"] = [
        "2023-01-01",
        "2023-01-01",
        "2022-01-01",
    ]
    dados["VERSAO"] = ["1", "1", "2"]
    dados["ST_CONTA_FIXA"] = ["S", "N", "S"]

    df = pd.DataFrame(dados)

    with zipfile.ZipFile(zip_path, "w") as zf:

        # 5 demonstrativos × 2 tipos = 10 CSVs
        for demonstrativo in DEMONSTRATIVOS:
            for tipo in TIPOS:
                nome = nome_no_zip(demonstrativo, tipo, ano)

                csv_bytes = df.to_csv(
                    sep=";",
                    index=False,
                ).encode("latin1")

                zf.writestr(nome, csv_bytes)

        # Cadastro
        cadastro = pd.DataFrame(
            {
                "CD_CVM": ["1", "2"],
                "DT_REFER": ["2023-12-31", "2023-12-31"],
                "DT_RECEB": ["2024-03-01", "2024-03-02"],
            }
        )

        cadastro_bytes = cadastro.to_csv(
            sep=";",
            index=False,
        ).encode("latin1")

        zf.writestr(
            f"dfp_cia_aberta_{ano}.csv",
            cadastro_bytes,
        )

    linhas = extrair_ano(
        zip_path=zip_path,
        ano=ano,
        saida_dir=saida_dir,
    )

    parquet = saida_dir / f"ano={ano}" / "dre_con.parquet"
    resultado = pd.read_parquet(parquet)

    # Protege as colunas que o legado perdia
    assert "DT_INI_EXERC" in resultado.columns
    assert "VERSAO" in resultado.columns
    assert "ST_CONTA_FIXA" in resultado.columns

    # Protege também o conteúdo, não só a existência da coluna
    assert resultado.loc[0, "ORDEM_EXERC"] == "ÚLTIMO"
    assert resultado.loc[0, "VERSAO"] == "1"
    assert resultado.loc[0, "ST_CONTA_FIXA"] == "S"

    # Protege contra voltar a extrair somente consolidado
    assert "dre_ind" in linhas
    assert linhas["dre_ind"] == 3

    # 5 demonstrativos × 2 tipos + cadastro
    assert len(linhas) == 11