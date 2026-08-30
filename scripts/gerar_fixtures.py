"""Gera tests/fixtures/raw/ — amostra minima do raw para o CI executar dbt build.

POR QUE ESTE SCRIPT EXISTE
--------------------------
O runner do CI clona so o que esta versionado, e data/ esta no .gitignore
(corretamente: 170 MB reproduziveis). Sem dado, o CI so consegue rodar
`dbt parse`, que valida YAML, Jinja e referencias mas NAO executa SQL --
um `selec * frmo` passa verde. Ja aconteceu neste projeto.

A fixture e uma amostra versionavel do raw, com os mesmos nomes de arquivo e
o mesmo esquema, para que o CI rode `dbt build` de verdade a cada PR.

COMO AS EMPRESAS FORAM ESCOLHIDAS
---------------------------------
Nao sao as maiores nem as mais "representativas": sao as que fazem os testes
falharem quando algo quebra. Amostra so com casos limpos nao testa nada.
Cada uma cobre um comportamento especifico do pipeline (ver EMPRESAS abaixo).

    python scripts/gerar_fixtures.py
    python scripts/gerar_fixtures.py --check    # so mede, nao escreve
"""

import argparse
import shutil
import sys
from pathlib import Path

import duckdb

RAIZ = Path(__file__).resolve().parents[1]
ORIGEM = RAIZ / "data" / "raw" / "dfp"
DESTINO = RAIZ / "tests" / "fixtures" / "raw" / "dfp"
LIMITE_MB = 5.0

# Cada empresa existe na amostra para exercitar um caminho do pipeline.
# Remover qualquer uma cega o CI para o comportamento correspondente.
EMPRESAS = {
    "009512": "Petrobras: plano padrao, safra ULTIMO/PENULTIMO, grande porte",
    "005410": "WEG: ancora de sanidade (2023 -> margem 18,1%, ROE 32,9%)",
    "001023": "Banco do Brasil: plano financeiro, conceitos fin_*, PL em 2.08",
    "008427": "Estrela: mudou exercicio social em 2011, dois fechamentos no mesmo ano",
    "006629": "Hercules: descricao corrompida ('0') em 2010-2012, aciona o WARN",
    "019364": "Itapebi: excecao da identidade contabil (PL fora do Passivo Total)",
    "026557": "Datora: a outra excecao da identidade contabil",
}


def anos_disponiveis():
    return sorted(p for p in ORIGEM.glob("ano=*") if p.is_dir())


def gerar(con, escrever: bool) -> tuple[int, int]:
    """Filtra cada parquet pelas empresas da amostra. Devolve (arquivos, linhas)."""
    lista = ", ".join("'{}'".format(cd) for cd in EMPRESAS)
    n_arquivos = 0
    n_linhas = 0

    for dir_ano in anos_disponiveis():
        saida_ano = DESTINO / dir_ano.name
        if escrever:
            saida_ano.mkdir(parents=True, exist_ok=True)

        for parquet in sorted(dir_ano.glob("*.parquet")):
            colunas = [
                r[0] for r in con.sql(
                    "describe select * from read_parquet('{}')".format(parquet.as_posix())
                ).fetchall()
            ]
            if "CD_CVM" not in colunas:
                print("  [AVISO] {}/{} sem CD_CVM -- pulando".format(dir_ano.name, parquet.name))
                continue

            destino = saida_ano / parquet.name
            q = "select * from read_parquet('{}') where CD_CVM in ({})".format(
                parquet.as_posix(), lista
            )
            linhas = con.sql("select count(*) from ({})".format(q)).fetchone()[0]

            if escrever:
                con.sql("copy ({}) to '{}' (format parquet)".format(q, destino.as_posix()))

            n_arquivos += 1
            n_linhas += linhas

    return n_arquivos, n_linhas


def tamanho_mb(caminho: Path) -> float:
    if not caminho.exists():
        return 0.0
    return sum(f.stat().st_size for f in caminho.rglob("*") if f.is_file()) / 1e6


def main() -> int:
    p = argparse.ArgumentParser(description="Gera a amostra de raw usada pelo CI.")
    p.add_argument("--check", action="store_true", help="apenas mede, nao escreve")
    args = p.parse_args()

    if not ORIGEM.exists():
        print("[FALHA] {} nao existe. Rode antes: python -m ingestion".format(
            ORIGEM.relative_to(RAIZ)))
        return 1

    con = duckdb.connect()

    if not args.check and DESTINO.exists():
        shutil.rmtree(DESTINO)

    n_arquivos, n_linhas = gerar(con, escrever=not args.check)

    print("[OK] {} empresas | {} arquivos | {:,} linhas".format(
        len(EMPRESAS), n_arquivos, n_linhas))

    if args.check:
        return 0

    mb = tamanho_mb(DESTINO)
    print("[OK] {} -- {:.2f} MB".format(DESTINO.relative_to(RAIZ), mb))

    if mb > LIMITE_MB:
        print("[FALHA] amostra passou de {:.1f} MB. Reduza anos ou empresas.".format(LIMITE_MB))
        return 1

    faltando = [cd for cd in EMPRESAS if not any(
        con.sql("select count(*) from read_parquet('{}') where CD_CVM = '{}'".format(
            f.as_posix(), cd)).fetchone()[0] > 0
        for f in DESTINO.rglob("dre_*.parquet"))]
    if faltando:
        print("[FALHA] empresas sem nenhuma linha de DRE na amostra: {}".format(faltando))
        return 1

    print("[OK] todas as {} empresas presentes na amostra".format(len(EMPRESAS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
