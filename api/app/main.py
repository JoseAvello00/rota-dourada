"""API Rota Dourada — pacotes de navegação e cadastro opcional de usuários.

O app baixa o pacote completo uma vez e navega offline. A API não recebe
a posição do visitante.
"""
from __future__ import annotations

import hashlib
import json

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware

from .repositorio import repositorio
from .contas import router as contas_router
from .validador import avisos_acessibilidade, validar_pacote

app = FastAPI(
    title="Rota Dourada API",
    version="0.1.0",
    description="Pacotes de navegação indoor acessível — HackaRun 2026",
)
app.include_router(contas_router)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["GET", "POST", "PUT", "DELETE"], allow_headers=["*"])


def _etag(pacote: dict) -> str:
    bruto = json.dumps(pacote, sort_keys=True, ensure_ascii=False).encode()
    return hashlib.sha256(bruto).hexdigest()[:16]


def _carregar(pacote_id: str) -> dict:
    pacote = repositorio().obter(pacote_id)
    if pacote is None:
        raise HTTPException(404, f"Pacote '{pacote_id}' não encontrado")
    return pacote


@app.get("/saude")
def saude():
    return {"status": "ok"}


@app.get("/pacotes")
def listar_pacotes():
    return repositorio().listar()


@app.get("/pacotes/{pacote_id}/versao")
def versao(pacote_id: str):
    """Chamada leve: o app compara com a versão salva antes de baixar de novo."""
    pacote = _carregar(pacote_id)
    return {**pacote["versao"], "hash": _etag(pacote)}


@app.get("/pacotes/{pacote_id}")
def baixar_pacote(pacote_id: str, request: Request, response: Response):
    """Pacote completo (mapa, POIs, caminhos, acessibilidade, beacons, perfis)."""
    pacote = _carregar(pacote_id)
    etag = _etag(pacote)
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304)
    response.headers["ETag"] = etag
    response.headers["Cache-Control"] = "no-cache"
    return pacote


@app.get("/pacotes/{pacote_id}/validacao")
def validacao(pacote_id: str):
    """Relatório de integridade — usado antes de publicar uma nova versão."""
    pacote = _carregar(pacote_id)
    erros = validar_pacote(pacote)
    return {"valido": not erros, "erros": erros, "avisos": avisos_acessibilidade(pacote)}


# ---------- cadastro de beacons (equipe do shopping) ----------
import os
from pydantic import BaseModel, Field

from .validador import grade_de, livre


class Beacon(BaseModel):
    id: str
    uuid: str = Field(pattern=r"^[0-9a-fA-F-]{36}$")
    major: int = Field(ge=0, le=65535)
    minor: int = Field(ge=0, le=65535)
    andar: int
    x: float
    y: float
    rssi_1m: float = Field(default=-59, ge=-100, le=-30)
    expoente: float = Field(default=2.2, ge=1.5, le=4.0)
    status: str = "instalado"


@app.put("/pacotes/{pacote_id}/beacons")
def cadastrar_beacons(pacote_id: str, beacons: list[Beacon], request: Request):
    """Substitui os beacons do pacote. Cada beacon precisa estar numa célula de circulação do seu andar.
    Gera nova versão (o app baixa pelo ETag). Protegido por ADMIN_TOKEN."""
    token = os.environ.get("ADMIN_TOKEN")
    if not token or request.headers.get("authorization") != f"Bearer {token}":
        raise HTTPException(401, "Acesso restrito à equipe do shopping")
    pacote = json.loads(json.dumps(_carregar(pacote_id)))
    andares = {a["id"]: a for a in pacote["edificio"]["andares"]}
    erros = []
    for b in beacons:
        if b.andar not in andares:
            erros.append(f"{b.id}: andar inexistente")
            continue
        g = grade_de(andares[b.andar])
        if g and not livre(g, b.x, b.y):
            erros.append(f"{b.id}: posição ({b.x:.1f}, {b.y:.1f}) fora da área de circulação")
    if len({(b.uuid.lower(), b.major, b.minor) for b in beacons}) != len(beacons):
        erros.append("identificadores uuid/major/minor repetidos")
    if erros:
        raise HTTPException(422, {"erros": erros})
    pacote["beacons"] = [b.model_dump() for b in beacons]
    maior, menor, patch = (int(x) for x in pacote["versao"]["versao"].split("."))
    pacote["versao"]["versao"] = f"{maior}.{menor}.{patch + 1}"
    repositorio().salvar(pacote_id, pacote)
    return {"versao": pacote["versao"]["versao"], "beacons": len(beacons)}
