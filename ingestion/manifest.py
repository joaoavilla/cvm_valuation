"""Manifesto de ingestão: o registro do que entrou, quando, e se mudou.

Existe para responder mecanicamente a pergunta que mais dói em pipeline de
dado externo: "essa diferença veio da fonte ou de um bug meu?".
Sem manifesto, a resposta é sempre "acho que...".
"""

import json
from datetime import datetime, timezone
from pathlib import Path


def caminho_do_manifesto(ano: int, dir_manifests: Path) -> Path:
    return Path(dir_manifests) / f"dfp_{ano}.json"


def ler_manifesto(ano: int, dir_manifests: Path) -> dict | None:
    """Devolve o manifesto da execução anterior, ou None se for a primeira."""
    caminho = caminho_do_manifesto(ano, dir_manifests)
    if not caminho.exists():
        return None
    return json.loads(caminho.read_text(encoding="utf-8"))


def gravar_manifesto(
    ano: int,
    url: str,
    sha256: str,
    bytes_zip: int,
    linhas_por_arquivo: dict[str, int],
    dir_manifests: Path,
) -> dict:
    """Grava dfp_{ano}.json e compara com a execução anterior.

    `mudou_vs_anterior` tem três estados, e os três significam coisas
    diferentes:
      None  -> primeira ingestão deste ano; não há com o que comparar
      False -> byte a byte idêntico ao que já tínhamos
      True  -> a CVM reescreveu o arquivo desde a última vez
    """
    dir_manifests = Path(dir_manifests)
    dir_manifests.mkdir(parents=True, exist_ok=True)

    anterior = ler_manifesto(ano, dir_manifests)
    agora = datetime.now(timezone.utc).isoformat()

    # O hash decide. Comparar tamanho ou data de modificação seria frágil:
    # dois arquivos diferentes podem ter o mesmo tamanho.
    mudou = None if anterior is None else (anterior.get("sha256") != sha256)

    if mudou:
        antes = sum((anterior.get("linhas") or {}).values())
        depois = sum(linhas_por_arquivo.values())
        print(
            f"  [MUDOU] FY{ano} foi reescrito na CVM desde {anterior.get('ingerido_em')}\n"
            f"          sha anterior : {(anterior.get('sha256') or '?')[:12]}...\n"
            f"          sha atual    : {sha256[:12]}...\n"
            f"          linhas antes : {antes:,}  ->  agora: {depois:,}  "
            f"(delta {depois - antes:+,})"
        )

    manifesto = {
        "ano": ano,
        "url": url,
        "sha256": sha256,
        "bytes": bytes_zip,
        "linhas": linhas_por_arquivo,
        "total_linhas": sum(linhas_por_arquivo.values()),
        "ingerido_em": agora,
        "mudou_vs_anterior": mudou,
    }

    # Guardar o estado anterior dentro do novo manifesto dá um rastro de um
    # nível — suficiente para saber "quando foi a última vez que isto mudou"
    # sem precisar de um banco de histórico.
    if anterior is not None:
        manifesto["ingestao_anterior_em"] = anterior.get("ingerido_em")
        manifesto["sha256_anterior"] = anterior.get("sha256")

    caminho_do_manifesto(ano, dir_manifests).write_text(
        json.dumps(manifesto, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return manifesto
