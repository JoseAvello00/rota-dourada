"""Fonte dos pacotes de navegação.

MVP: arquivo JSON versionado no repositório (dados/).
Produção prevista: Firebase Cloud Firestore (ative com PACOTE_FONTE=firestore).
"""
from __future__ import annotations

import json
import os
from functools import lru_cache
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
ARQUIVO_PADRAO = RAIZ / "dados" / "pacote_capim_dourado.json"


class RepositorioJson:
    def __init__(self, caminho: Path = ARQUIVO_PADRAO):
        self.caminho = caminho

    def obter(self, pacote_id: str) -> dict | None:
        dados = json.loads(self.caminho.read_text(encoding="utf-8"))
        return dados if dados["versao"]["pacote_id"] == pacote_id else None

    def listar(self) -> list[dict]:
        dados = json.loads(self.caminho.read_text(encoding="utf-8"))
        return [dados["versao"]]


class RepositorioFirestore:
    """Cada pacote é um documento em `pacotes/{pacote_id}` com o JSON completo,
    garantindo que mapa, caminhos e beacons sejam sempre da mesma versão."""

    def __init__(self):
        from google.cloud import firestore  # dependência opcional

        self.db = firestore.Client()

    def obter(self, pacote_id: str) -> dict | None:
        doc = self.db.collection("pacotes").document(pacote_id).get()
        return doc.to_dict() if doc.exists else None

    def listar(self) -> list[dict]:
        return [d.to_dict()["versao"] for d in self.db.collection("pacotes").stream()]


@lru_cache
def repositorio():
    if os.getenv("PACOTE_FONTE") == "firestore":
        return RepositorioFirestore()
    return RepositorioJson(Path(os.getenv("PACOTE_ARQUIVO", ARQUIVO_PADRAO)))
