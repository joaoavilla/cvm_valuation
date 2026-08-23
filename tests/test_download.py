import hashlib

from ingestion.download import sha256_de


def test_sha256_de(tmp_path):
    caminho = tmp_path / "arquivo.bin"

    conteudo = b"cvm-valuation"
    caminho.write_bytes(conteudo)

    resultado = sha256_de(caminho)

    esperado = hashlib.sha256(conteudo).hexdigest()

    assert resultado == esperado