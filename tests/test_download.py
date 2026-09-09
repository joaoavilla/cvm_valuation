import hashlib

from ingestion.download import sha256_de


def test_sha256_de(tmp_path):
    caminho = tmp_path / "arquivo.bin"

    conteudo = b"cvm-valuation"
    caminho.write_bytes(conteudo)

    resultado = sha256_de(caminho)

    esperado = hashlib.sha256(conteudo).hexdigest()

    assert resultado == esperado

def test_preservar_captura_arquiva_quando_o_conteudo_muda(tmp_path):
    """Uma nova coleta com conteúdo diferente não pode destruir a anterior."""
    from ingestion.download import dir_de_capturas, preservar_captura, sha256_de

    destino = tmp_path / "dfp_2024.zip"
    antigo = b"conteudo-antigo"
    destino.write_bytes(antigo)
    sha_antigo = hashlib.sha256(antigo).hexdigest()

    preservado = preservar_captura(destino, sha_novo="0" * 64)

    assert preservado is not None
    assert preservado == dir_de_capturas(destino) / f"dfp_2024__{sha_antigo[:12]}.zip"
    assert preservado.read_bytes() == antigo
    # o corrente segue intacto: quem sobrescreve é o rename, depois
    assert destino.read_bytes() == antigo
    assert sha256_de(preservado) == sha_antigo


def test_preservar_captura_nao_duplica_conteudo_identico(tmp_path):
    """Reingestão do mesmo conteúdo não gera captura nova nem apaga histórico."""
    from ingestion.download import dir_de_capturas, preservar_captura

    destino = tmp_path / "dfp_2024.zip"
    conteudo = b"mesmo-conteudo"
    destino.write_bytes(conteudo)
    sha = hashlib.sha256(conteudo).hexdigest()

    assert preservar_captura(destino, sha_novo=sha) is None
    assert not dir_de_capturas(destino).exists()


def test_preservar_captura_na_primeira_ingestao_nao_faz_nada(tmp_path):
    """Sem arquivo anterior não há o que preservar, e isso não é erro."""
    from ingestion.download import preservar_captura

    assert preservar_captura(tmp_path / "dfp_2024.zip", sha_novo="a" * 64) is None
