import hashlib
from pathlib import Path

import pytest

from ingestion.download import sha256_de


def test_sha256_de(tmp_path):
    caminho = tmp_path / "arquivo.bin"

    conteudo = b"cvm-valuation"
    caminho.write_bytes(conteudo)

    resultado = sha256_de(caminho)

    esperado = hashlib.sha256(conteudo).hexdigest()

    assert resultado == esperado


ORIGINAL = b"CONTEUDO-ORIGINAL-COMPLETO-QUE-NAO-PODE-SER-PERDIDO"
SHA_ORIGINAL = hashlib.sha256(ORIGINAL).hexdigest()


def _com_zip_existente(tmp_path):
    destino = tmp_path / "dfp_2024.zip"
    destino.write_bytes(ORIGINAL)
    return destino


def test_preservar_captura_arquiva_quando_o_conteudo_muda(tmp_path):
    """Uma nova coleta com conteúdo diferente não pode destruir a anterior."""
    from ingestion.download import dir_de_capturas, preservar_captura, sha256_de

    destino = _com_zip_existente(tmp_path)

    preservado = preservar_captura(destino, sha_novo="0" * 64)

    assert preservado == dir_de_capturas(destino) / f"dfp_2024__{SHA_ORIGINAL}.zip"
    assert sha256_de(preservado) == SHA_ORIGINAL
    # o corrente segue intacto: quem sobrescreve é o rename, e ele vem depois
    assert destino.read_bytes() == ORIGINAL


def test_preservar_captura_nao_duplica_conteudo_identico(tmp_path):
    """Reingestão do mesmo conteúdo não gera captura nova nem apaga histórico."""
    from ingestion.download import dir_de_capturas, preservar_captura

    destino = _com_zip_existente(tmp_path)

    assert preservar_captura(destino, sha_novo=SHA_ORIGINAL) is None
    assert not dir_de_capturas(destino).exists()


def test_preservar_captura_na_primeira_ingestao_nao_faz_nada(tmp_path):
    """Sem arquivo anterior não há o que preservar, e isso não é erro."""
    from ingestion.download import preservar_captura

    assert preservar_captura(tmp_path / "dfp_2024.zip", sha_novo="a" * 64) is None


def test_preservar_captura_refaz_captura_corrompida(tmp_path):
    """Uma cópia interrompida no caminho de destino não pode passar por captura válida.

    Era o defeito: `if not alvo.exists()` aceitava qualquer arquivo com o nome certo, e a
    execução seguinte anunciava PRESERVADO liberando a sobrescrita do original.
    """
    from ingestion.download import dir_de_capturas, preservar_captura, sha256_de

    destino = _com_zip_existente(tmp_path)
    capturas = dir_de_capturas(destino)
    capturas.mkdir(parents=True, exist_ok=True)
    alvo = capturas / f"dfp_2024__{SHA_ORIGINAL}.zip"
    alvo.write_bytes(b"TRUNC")  # cópia parcial de uma execução interrompida

    preservado = preservar_captura(destino, sha_novo="0" * 64)

    assert preservado == alvo
    assert sha256_de(alvo) == SHA_ORIGINAL  # foi refeita, não aceita como estava
    assert alvo.read_bytes() == ORIGINAL


def test_preservar_captura_reaproveita_captura_integra(tmp_path):
    """Captura já existente e íntegra é reaproveitada, sem copiar de novo."""
    from ingestion.download import dir_de_capturas, preservar_captura

    destino = _com_zip_existente(tmp_path)
    capturas = dir_de_capturas(destino)
    capturas.mkdir(parents=True, exist_ok=True)
    alvo = capturas / f"dfp_2024__{SHA_ORIGINAL}.zip"
    alvo.write_bytes(ORIGINAL)
    mtime_antes = alvo.stat().st_mtime_ns

    assert preservar_captura(destino, sha_novo="0" * 64) == alvo
    assert alvo.stat().st_mtime_ns == mtime_antes  # não foi reescrita


def test_preservar_captura_levanta_se_a_copia_sair_corrompida(tmp_path, monkeypatch):
    """Se a preservação falhar, ela precisa ABORTAR — nunca liberar a sobrescrita.

    `baixar_ano` chama esta função antes do `replace` que sobrescreve o ZIP corrente, então
    a exceção é o que mantém o acervo intacto.
    """
    from ingestion import download as mod

    destino = _com_zip_existente(tmp_path)

    def copia_que_corrompe(origem, alvo, *a, **kw):
        Path(alvo).write_bytes(b"LIXO")
        return alvo

    monkeypatch.setattr(mod.shutil, "copy2", copia_que_corrompe)

    with pytest.raises(OSError, match="corrompida"):
        mod.preservar_captura(destino, sha_novo="0" * 64)

    # nenhum `.part` sobra e nenhuma captura inválida foi publicada
    capturas = mod.dir_de_capturas(destino)
    assert list(capturas.glob("*")) == []
    assert destino.read_bytes() == ORIGINAL


def test_download_nao_substitui_corrente_se_preservacao_falhar(tmp_path, monkeypatch):
    """Exercita o download real com rede simulada e falha na copia de arquivo."""
    import io
    import zipfile
    from ingestion import download as mod

    destino = _com_zip_existente(tmp_path)
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as z:
        z.writestr("dados.csv", "novo")

    class Resposta:
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def raise_for_status(self): pass
        def iter_content(self, chunk_size): yield buffer.getvalue()

    monkeypatch.setattr(mod.requests, "get", lambda *a, **k: Resposta())
    def falhar(*args, **kwargs):
        raise OSError("copia interrompida")
    monkeypatch.setattr(mod.shutil, "copy2", falhar)
    with pytest.raises(OSError, match="interrompida"):
        mod.baixar_ano(2024, destino)
    assert destino.read_bytes() == ORIGINAL
