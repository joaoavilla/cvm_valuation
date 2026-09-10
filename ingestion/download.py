"""Download atômico e verificado dos ZIPs anuais da CVM.

Este módulo tem uma responsabilidade só: trazer o arquivo da internet para o
disco de forma confiável. Não interpreta nada do conteúdo — isso é do extract.
"""

import hashlib
import shutil
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

    # Antes de sobrescrever, preserva a captura anterior se o conteúdo mudou.
    # Sem isto, cada execução destrói a única cópia do que a CVM dizia antes — e já se
    # sabe que a CVM reescreve: o manifesto de 2024 registra `mudou_vs_anterior: true`,
    # com o ZIP anterior perdido. 22,4% dos documentos do acervo têm `versao > 1`.
    preservar_captura(destino, sha256_de(parcial))

    # rename dentro do mesmo sistema de arquivos: operação atômica.
    # Ou o destino tem o arquivo íntegro, ou não tem nada. Nunca meio termo.
    parcial.replace(destino)
    return destino


def dir_de_capturas(destino: Path) -> Path:
    """Onde as capturas anteriores ficam: `_capturas/` ao lado dos ZIPs correntes."""
    return Path(destino).parent / "_capturas"


def preservar_captura(destino: Path, sha_novo: str) -> Path | None:
    """Arquiva o ZIP que está prestes a ser sobrescrito, quando o conteúdo mudou.

    O nome carrega o SHA-256 COMPLETO do conteúdo: duas execuções que baixem o mesmo
    conteúdo não geram duas cópias, e a identidade da captura é verificável sem consultar
    metadado nenhum.

    Devolve o caminho preservado, ou None quando não havia o que preservar — primeira
    ingestão do ano, ou conteúdo idêntico ao que já está em disco.

    LEVANTA `OSError` se não conseguir preservar. Isso é deliberado: `baixar_ano` chama esta
    função ANTES do `replace` que sobrescreve o ZIP corrente, então uma falha aqui aborta a
    substituição e o acervo fica intacto. Preservação que falha em silêncio é pior que
    preservação nenhuma, porque dá a impressão de que existe.

    DEFEITO CORRIGIDO EM 2026-09-09, apontado por revisão externa: a primeira versão aceitava
    um arquivo já existente no caminho de destino SEM conferir o conteúdo. Uma cópia
    interrompida deixava um arquivo truncado ali, e a execução seguinte o tomava por captura
    válida, anunciava PRESERVADO e liberava a sobrescrita — perdendo o original. Reproduzido:
    captura de 5 bytes aceita no lugar de um conteúdo de 51.

    O que esta função NÃO faz: recuperar capturas destruídas antes de ela existir. Para os
    documentos já sobrescritos, a versão anterior está ausente do acervo.
    """
    destino = Path(destino)
    if not destino.exists():
        return None

    sha_antigo = sha256_de(destino)
    if sha_antigo == sha_novo:
        return None

    capturas = dir_de_capturas(destino)
    capturas.mkdir(parents=True, exist_ok=True)
    alvo = capturas / f"{destino.stem}__{sha_antigo}{destino.suffix}"

    # Captura já existente só conta se o conteúdo conferir. Um arquivo com o nome certo e
    # o conteúdo errado é exatamente o modo de falha que esta verificação existe para pegar.
    if alvo.exists():
        if sha256_de(alvo) == sha_antigo:
            return alvo
        alvo.unlink()

    # Copia para `.part` e só promove ao nome final depois de verificar. Mesmo idioma do
    # download: ou o nome final tem o conteúdo íntegro, ou não existe.
    parcial = alvo.with_suffix(alvo.suffix + ".part")
    try:
        # copy2 preserva mtime, que é o registro mais próximo de "quando esta captura entrou".
        # Não é a data de publicação do documento e não deve ser usada como tal.
        shutil.copy2(destino, parcial)
        sha_copia = sha256_de(parcial)
        if sha_copia != sha_antigo:
            raise OSError(
                f"captura de {destino.name} saiu corrompida: "
                f"esperado {sha_antigo[:12]}, obtido {sha_copia[:12]}"
            )
        parcial.replace(alvo)
    except BaseException:
        parcial.unlink(missing_ok=True)
        raise

    print(f"  [PRESERVADO] captura anterior de {destino.name} -> {alvo.name}")
    return alvo


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
