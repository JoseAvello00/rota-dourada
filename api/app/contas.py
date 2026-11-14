"""Contas de usuário: criar conta, entrar com e-mail, ver/editar/apagar o perfil.

- Senha guardada só como hash PBKDF2-SHA256 com sal (nunca em texto).
- Deficiência é dado pessoal sensível (LGPD, art. 11): exige consentimento explícito.
- Quem não quiser conta usa o app como visitante (preferências só no aparelho).
"""
from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import secrets
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field, field_validator, model_validator

from .perfis import TIPOS_DEFICIENCIA, perfis_do_usuario

router = APIRouter(prefix="/contas", tags=["contas"])
EMAIL = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _so_digitos(t: str) -> str:
    return re.sub(r"\D", "", t or "")


class Perfil(BaseModel):
    nome: str = Field(min_length=1, max_length=80)
    telefone: str
    email: str = Field(max_length=120)
    idioma: str = Field(default="pt", pattern="^(pt|en|es)$")
    possui_deficiencia: bool = False
    tipos: list[str] = []
    consentimento_dados_sensiveis: bool = False

    @field_validator("nome")
    @classmethod
    def nome_ok(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("informe o nome")
        return v.strip()

    @field_validator("telefone")
    @classmethod
    def telefone_ok(cls, v: str) -> str:
        d = _so_digitos(v)
        if d.startswith("55") and len(d) in (12, 13):
            d = d[2:]
        if len(d) not in (10, 11):
            raise ValueError("telefone com DDD: 10 ou 11 dígitos")
        return d

    @field_validator("email")
    @classmethod
    def email_ok(cls, v: str) -> str:
        v = v.strip().lower()
        if not EMAIL.match(v):
            raise ValueError("e-mail inválido")
        return v

    @field_validator("tipos")
    @classmethod
    def tipos_validos(cls, v: list[str]) -> list[str]:
        invalidos = [t for t in v if t not in TIPOS_DEFICIENCIA]
        if invalidos:
            raise ValueError(f"tipos desconhecidos: {invalidos}")
        return sorted(set(v))

    @model_validator(mode="after")
    def coerencia(self):
        if not self.possui_deficiencia:
            self.tipos = []
        elif not self.tipos:
            raise ValueError("informe ao menos uma deficiência ou necessidade")
        if self.tipos and not self.consentimento_dados_sensiveis:
            raise ValueError("consentimento explícito é obrigatório para guardar dados de deficiência")
        return self


class NovaConta(Perfil):
    senha: str = Field(min_length=8, max_length=128)


class Entrada(BaseModel):
    email: str
    senha: str


def _hash(senha: str, sal: bytes) -> str:
    return hashlib.pbkdf2_hmac("sha256", senha.encode(), sal, 200_000).hex()


class Repositorio:
    """Arquivo JSON (MVP). Produção prevista: Firebase Auth + Firestore."""

    def __init__(self, caminho: Path | None):
        self.caminho = caminho
        self.trava = threading.Lock()
        self.contas: dict[str, dict] = {}
        self.sessoes: dict[str, str] = {}
        if caminho and caminho.exists():
            dados = json.loads(caminho.read_text(encoding="utf-8"))
            self.contas, self.sessoes = dados["contas"], dados["sessoes"]

    def salvar(self):
        if self.caminho:
            self.caminho.write_text(json.dumps({"contas": self.contas, "sessoes": self.sessoes}, ensure_ascii=False), encoding="utf-8")

    def por_email(self, email: str) -> dict | None:
        return next((c for c in self.contas.values() if c["email"] == email), None)


_arq = os.getenv("CONTAS_ARQUIVO")
repo = Repositorio(Path(_arq) if _arq else None)


def _publico(c: dict) -> dict:
    return {k: v for k, v in c.items() if k not in ("senha_hash", "sal")}


def _aplicar(c: dict, p: Perfil) -> dict:
    agora = datetime.now(timezone.utc).isoformat()
    c.update(p.model_dump(exclude={"senha"}))
    c["perfis"] = perfis_do_usuario(p.possui_deficiencia, p.tipos)
    c["consentimento_em"] = agora if p.tipos else None
    c["atualizado_em"] = agora
    return c


def conta_atual(authorization: str | None = Header(default=None)) -> dict:
    token = (authorization or "").removeprefix("Bearer ").strip()
    uid = repo.sessoes.get(token)
    if not uid or uid not in repo.contas:
        raise HTTPException(401, "sessão inválida ou expirada; entre novamente")
    return repo.contas[uid]


@router.get("/tipos-deficiencia")
def tipos_deficiencia():
    return [{"id": k, "perfil": v} for k, v in TIPOS_DEFICIENCIA.items()]


@router.post("", status_code=201)
def criar_conta(n: NovaConta):
    with repo.trava:
        if repo.por_email(n.email):
            raise HTTPException(409, "já existe uma conta com este e-mail; use Entrar com e-mail")
        sal = secrets.token_bytes(16)
        c = {"id": str(uuid.uuid4()), "criado_em": datetime.now(timezone.utc).isoformat(),
             "sal": sal.hex(), "senha_hash": _hash(n.senha, sal)}
        _aplicar(c, n)
        repo.contas[c["id"]] = c
        token = secrets.token_urlsafe(32)
        repo.sessoes[token] = c["id"]
        repo.salvar()
    return {"token": token, "conta": _publico(c)}


@router.post("/entrar")
def entrar(e: Entrada):
    c = repo.por_email(e.email.strip().lower())
    # mesma mensagem para e-mail ou senha errados (não revela se o e-mail existe)
    if not c or not hmac.compare_digest(_hash(e.senha, bytes.fromhex(c["sal"])), c["senha_hash"]):
        raise HTTPException(401, "e-mail ou senha incorretos")
    token = secrets.token_urlsafe(32)
    with repo.trava:
        repo.sessoes[token] = c["id"]
        repo.salvar()
    return {"token": token, "conta": _publico(c)}


@router.get("/eu")
def minha_conta(c: dict = Depends(conta_atual)):
    return _publico(c)


@router.put("/eu")
def editar(p: Perfil, c: dict = Depends(conta_atual)):
    with repo.trava:
        outra = repo.por_email(p.email)
        if outra and outra["id"] != c["id"]:
            raise HTTPException(409, "este e-mail já é usado por outra conta")
        _aplicar(c, p)
        repo.salvar()
    return _publico(c)


@router.post("/sair", status_code=204)
def sair(authorization: str | None = Header(default=None), c: dict = Depends(conta_atual)):
    with repo.trava:
        repo.sessoes.pop((authorization or "").removeprefix("Bearer ").strip(), None)
        repo.salvar()


@router.delete("/eu", status_code=204)
def apagar(c: dict = Depends(conta_atual)):
    """Direito de eliminação (LGPD, art. 18): apaga conta e sessões."""
    with repo.trava:
        repo.contas.pop(c["id"], None)
        repo.sessoes = {t: u for t, u in repo.sessoes.items() if u != c["id"]}
        repo.salvar()
