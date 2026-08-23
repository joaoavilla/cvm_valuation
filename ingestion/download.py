"""Download atômico e verificado dos ZIPs anuais da CVM.

Este módulo tem uma responsabilidade só: trazer o arquivo da internet para o
disco de forma confiável. Não interpreta nada do conteúdo — isso é do extract.
"""

import hashlib
import zipfile
from pathlib import Path

import requests

from .config import BASE_URL

# Identifica o projeto para o servidor. É cortesia, e alguns portais gov.br
# recusam clientes sem User-Agent.
UA = {"User-Agent": "cvm-valuation/0.1 (+https://github.com/joaoavilla/cvm_valuation)"}

# (timeout de conexão, timeout de leitura). O segundo NÃO é o tempo total do
# download: é o silêncio máximo tolerado entre dois blocos. Um download lento
# porém contínuo nunca estoura; um servidor que travou, sim.
TIMEOUT = (10, 60)

CHUNK = 1 << 20  # 1 MiB por bloco


def url_do_ano(ano: int) -> str:
    return f"{BASE_URL}/dfp_cia_aberta_{ano}.zip"


def baixar_ano(ano: int, destino: Path) -> Path:
    """Baixa o ZIP do ano e devolve o caminho local.

    SEMPRE baixa, sem cache por existência (decisão D6). O cache do pipeline
    legado era justamente o bug: a CVM reescreve arquivos de anos antigos
    (o FY2020 mudou em 12/2024), então "o arquivo existe" nunca significou
    "o arquivo está atual". Quem responde "mudou?" é o manifesto, por hash.
    """
    destino = Path(destino)
    destino.parent.mkdir(parents=True, exist_ok=True)

    # Baixa para um nome temporário ao lado do destino. Enquanto o download não
    # termina E não é validado, o nome final não existe. É isso que torna a
    # escrita atômica: um Ctrl+C no meio deixa lixo `.part`, jamais um ZIP
    # truncado se passando por válido — que foi o modo de falha do legado.
    parcial = destino.with_suffix(destino.suffix + ".part")

    url = url_do_ano(ano)
    print(f"  baixando {url}")

    with requests.get(url, headers=UA, timeout=TIMEOUT, stream=True) as r:
        # 404 / 500 viram exceção aqui. Sem isto, uma página de erro HTML seria
        # gravada com extensão .zip e só quebraria lá na frente.
        r.raise_for_status()
        with open(parcial, "wb") as f:
            # stream=True + iter_content: os bytes vão direto da rede para o
            # disco. Com r.content, o arquivo inteiro passaria pela RAM antes.
            for bloco in r.iter_content(chunk_size=CHUNK):
                f.write(bloco)

    # Só depois de escrito por completo perguntamos: isto é mesmo um ZIP?
    if not zipfile.is_zipfile(parcial):
        parcial.unlink(missing_ok=True)
        raise ValueError(f"[{ano}] o download não é um ZIP válido: {url}")

    # rename dentro do mesmo sistema de arquivos: operação atômica.
    # Ou o destino tem o arquivo íntegro, ou não tem nada. Nunca meio termo.
    parcial.replace(destino)
    return destino


def sha256_de(caminho: Path) -> str:
    """Impressão digital do arquivo — o que o manifesto compara entre execuções.

    Lê em blocos pelo mesmo motivo do stream: 13 MB cabem na RAM, 13 GB não,
    e o código não deveria depender de qual dos dois é o caso.
    O idioma `iter(callable, sentinela)` chama f.read(CHUNK) repetidamente até
    receber b"" (fim do arquivo).
    """
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(CHUNK), b""):
            h.update(bloco)
    return h.hexdigest()
