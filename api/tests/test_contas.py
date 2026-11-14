import json

from fastapi.testclient import TestClient

from app.main import app
from app.navegacao import calcular_rota, montar_grafo
from app.perfis import combinar_perfis, perfis_do_usuario
from app.repositorio import ARQUIVO_PADRAO

c = TestClient(app)
PACOTE = json.loads(ARQUIVO_PADRAO.read_text(encoding="utf-8"))
_n = 0


def nova(**k):
    global _n
    _n += 1
    base = {"nome": "Ana", "telefone": "(63) 99999-0000", "email": f"ana{_n}@exemplo.com", "senha": "segredo123",
            "possui_deficiencia": True, "tipos": ["cadeirante"], "consentimento_dados_sensiveis": True}
    base.update(k)
    return c.post("/contas", json=base)


def auth(t):
    return {"Authorization": f"Bearer {t}"}


def test_criar_conta_retorna_token_e_perfil_sem_senha():
    r = nova()
    assert r.status_code == 201
    j = r.json()
    assert j["token"] and j["conta"]["perfis"] == ["mobilidade"] and j["conta"]["telefone"] == "63999990000"
    assert "senha_hash" not in j["conta"] and "sal" not in j["conta"]


def test_campos_obrigatorios_e_validacao():
    assert nova(nome=" ").status_code == 422
    assert nova(telefone="123").status_code == 422
    assert nova(email="sem-arroba").status_code == 422
    assert nova(senha="curta").status_code == 422
    assert nova(tipos=[]).status_code == 422          # disse que tem, mas não marcou
    assert nova(tipos=["voador"]).status_code == 422


def test_sem_consentimento_recusa_dados_sensiveis():
    r = nova(consentimento_dados_sensiveis=False)
    assert r.status_code == 422 and "consentimento" in r.text


def test_email_duplicado_409():
    nova(email="dup@exemplo.com")
    assert nova(email="DUP@exemplo.com").status_code == 409


def test_entrar_com_email_e_senha():
    nova(email="login@exemplo.com", senha="minhasenha1")
    ok = c.post("/contas/entrar", json={"email": "Login@Exemplo.com", "senha": "minhasenha1"})
    assert ok.status_code == 200 and ok.json()["conta"]["email"] == "login@exemplo.com"
    ruim = c.post("/contas/entrar", json={"email": "login@exemplo.com", "senha": "errada000"})
    assert ruim.status_code == 401 and "incorretos" in ruim.text
    nao_existe = c.post("/contas/entrar", json={"email": "ninguem@exemplo.com", "senha": "x" * 8})
    assert nao_existe.status_code == 401 and nao_existe.text == ruim.text


def test_editar_perfil_varias_necessidades_e_apagar():
    t = nova().json()["token"]
    eu = c.get("/contas/eu", headers=auth(t)).json()
    eu.update({"tipos": ["cegueira", "auditiva", "fala"], "consentimento_dados_sensiveis": True})
    r = c.put("/contas/eu", headers=auth(t), json=eu)
    assert r.status_code == 200 and r.json()["perfis"] == ["auditiva", "visual"]
    assert c.delete("/contas/eu", headers=auth(t)).status_code == 204
    assert c.get("/contas/eu", headers=auth(t)).status_code == 401


def test_sem_sessao_401():
    assert c.get("/contas/eu").status_code == 401


def test_tipos_inclui_fala():
    ids = {t["id"] for t in c.get("/contas/tipos-deficiencia").json()}
    assert {"cadeirante", "cegueira", "auditiva", "fala", "tea"} <= ids


def test_perfil_combinado_exige_trechos_confirmados():
    p = combinar_perfis(PACOTE, perfis_do_usuario(True, ["cadeirante", "cegueira"]))
    assert p["proibidos"] == ["escada", "escada_rolante", "esteira"] and p["exigir_confirmado"]
    g = montar_grafo(PACOTE)
    assert calcular_rota(g, p, "t_p1", "p_c") is None          # sem rota acessível confirmada por dentro
    assert "elevador" in calcular_rota(g, p, "t_po", "p_c")["tipos"]  # pelo acesso oeste, sim
