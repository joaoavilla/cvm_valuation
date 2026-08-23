from ingestion.manifest import gravar_manifesto


def test_manifesto_detecta_mudanca(tmp_path):
    dir_manifests = tmp_path / "manifests"

    primeiro = gravar_manifesto(
        ano=2023,
        url="https://exemplo.com/dfp_2023.zip",
        sha256="aaa",
        bytes_zip=100,
        linhas_por_arquivo={"dre_con": 3},
        dir_manifests=dir_manifests,
    )

    segundo = gravar_manifesto(
        ano=2023,
        url="https://exemplo.com/dfp_2023.zip",
        sha256="bbb",
        bytes_zip=100,
        linhas_por_arquivo={"dre_con": 3},
        dir_manifests=dir_manifests,
    )

    terceiro = gravar_manifesto(
        ano=2023,
        url="https://exemplo.com/dfp_2023.zip",
        sha256="bbb",
        bytes_zip=100,
        linhas_por_arquivo={"dre_con": 3},
        dir_manifests=dir_manifests,
    )

    assert primeiro["mudou_vs_anterior"] is None
    assert segundo["mudou_vs_anterior"] is True
    assert terceiro["mudou_vs_anterior"] is False