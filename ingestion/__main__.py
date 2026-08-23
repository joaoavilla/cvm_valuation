"""CLI: python -m ingestion --anos 2010-2025"""
import argparse
from pathlib import Path

from .config import ANOS_DISPONIVEIS, BASE_URL, MANIFEST_DIR, RAW_DIR
from .download import baixar_ano, sha256_de
from .extract import extrair_ano
from .manifest import gravar_manifesto


def parse_anos(texto: str) -> list[int]:
    if "-" in texto:
        a, b = texto.split("-")
        return list(range(int(a), int(b) + 1))
    return [int(x) for x in texto.split(",")]


def main() -> None:
    p = argparse.ArgumentParser(description="Ingestão DFP/CVM — raw fiel + manifesto")
    p.add_argument("--anos", default=f"{min(ANOS_DISPONIVEIS)}-{max(ANOS_DISPONIVEIS)}")
    args = p.parse_args()

    MANIFEST_DIR.mkdir(parents=True, exist_ok=True)
    for ano in parse_anos(args.anos):
        url = f"{BASE_URL}/dfp_cia_aberta_{ano}.zip"
        zip_path = baixar_ano(ano, RAW_DIR / f"_zips/dfp_{ano}.zip")
        linhas = extrair_ano(zip_path, ano, RAW_DIR)
        m = gravar_manifesto(ano, url, sha256_de(zip_path), zip_path.stat().st_size,
                             linhas, MANIFEST_DIR)
        print(f"[{ano}] {sum(linhas.values()):,} linhas | mudou: {m['mudou_vs_anterior']}")


if __name__ == "__main__":
    main()
