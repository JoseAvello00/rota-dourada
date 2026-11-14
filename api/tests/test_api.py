import copy
import json

from fastapi.testclient import TestClient

from app.main import app
from app.navegacao import calcular_rota, montar_grafo
from app.repositorio import ARQUIVO_PADRAO
from app.validador import validar_pacote

cliente = TestClient(app)
PACOTE = json.loads(ARQUIVO_PADRAO.read_text(encoding="utf-8"))
GRAFO = montar_grafo(PACOTE)
PERFIS = PACOTE["perfis"]
ID = "capim-dourado-piloto"


# ---------- API ----------

def test_saude():
    assert cliente.get("/saude").json() == {"status": "ok"}


def test_versao_tem_hash_e_data():
    r = cliente.get(f"/pacotes/{ID}/versao").json()
    assert r["versao"] == PACOTE["versao"]["versao"] and r["atualizado_em"] and len(r["hash"]) == 16


def test_download_e_etag_304():
    r = cliente.get(f"/pacotes/{ID}")
    assert r.status_code == 200 and len(r.json()["pois"]) >= 15
    r2 = cliente.get(f"/pacotes/{ID}", headers={"If-None-Match": r.headers["etag"]})
    assert r2.status_code == 304


def test_pacote_inexistente_404():
    assert cliente.get("/pacotes/outro-shopping").status_code == 404


def test_validacao_endpoint_com_avisos_de_acessibilidade():
    j = cliente.get(f"/pacotes/{ID}/validacao").json()
    assert j["valido"] and j["erros"] == []
    assert any("mobilidade" in a and "t_p1" in a for a in j["avisos"])


# ---------- Regras de rota (rede traçada sobre a Planta Mix) ----------

def test_padrao_usa_escada_rolante_ate_a_praca_de_alimentacao():
    rota = calcular_rota(GRAFO, PERFIS["padrao"], "t_p1", "p_c")
    assert "escada_rolante" in rota["tipos"] and "t_esc" in rota["nos"]


def test_mobilidade_sem_rota_confirmada_por_dentro_ate_o_2o_piso():
    # a planta só mostra escadas rolantes/escada por dentro; o elevador fica no acesso oeste
    assert calcular_rota(GRAFO, PERFIS["mobilidade"], "t_p1", "p_c") is None


def test_mobilidade_pelo_acesso_oeste_usa_elevador():
    rota = calcular_rota(GRAFO, PERFIS["mobilidade"], "t_po", "p_c")
    assert "elevador" in rota["tipos"]
    assert not {"escada", "escada_rolante", "esteira"} & set(rota["tipos"])


def test_visual_prefere_escada_fixa_a_escada_rolante():
    rota = calcular_rota(GRAFO, PERFIS["visual"], "t_p1", "p_c")
    assert "escada" in rota["tipos"] and "escada_rolante" not in rota["tipos"]


def test_trecho_nao_confirmado_nao_entra_em_rota_acessivel():
    pacote = copy.deepcopy(PACOTE)
    for a in pacote["arestas"]:
        if a["id"] == "v_elevador":
            a["a_validar"] = True
    g = montar_grafo(pacote)
    assert calcular_rota(g, PERFIS["mobilidade"], "t_po", "p_c") is None
    assert calcular_rota(g, PERFIS["padrao"], "t_po", "p_c") is not None


def test_distancias_em_metros_reais():
    rota = calcular_rota(GRAFO, PERFIS["padrao"], "t_p1", "p_c")
    assert 100 < rota["distancia"] < 160


def test_sensorial_evita_praca_de_eventos_central():
    padrao = calcular_rota(GRAFO, PERFIS["padrao"], "t_p1", "t_rn")
    sens = calcular_rota(GRAFO, PERFIS["sensorial"], "t_p1", "t_rn")
    assert "t_praca" in padrao["nos"]
    assert "t_praca" not in sens["nos"]


def test_validador_detecta_poi_quebrado():
    pacote = copy.deepcopy(PACOTE)
    pacote["pois"][0]["no"] = "nao_existe"
    assert any("nó inexistente" in e for e in validar_pacote(pacote))


def test_validador_detecta_destino_inacessivel():
    pacote = copy.deepcopy(PACOTE)
    pacote["arestas"] = [a for a in pacote["arestas"] if a["id"] != "v_elevador"]
    erros = validar_pacote(pacote)
    assert any("sem rota 'mobilidade'" in e for e in erros)  # 2º piso sem nenhuma entrada acessível


def test_pacote_tem_lojas_da_planta_e_imagens():
    nomes = {p["nome"] for p in PACOTE["pois"]}
    assert {"Renner", "C&A", "Riachuelo", "Centauro", "Marisa", "Cinemark", "Outback", "McDonald's"} <= nomes
    assert len(PACOTE["pois"]) > 150
    for a in PACOTE["edificio"]["andares"]:
        assert set(a["imagens"]) == {"claro", "escuro", "terror"}
        assert all((ARQUIVO_PADRAO.parent / f).exists() for f in a["imagens"].values())
