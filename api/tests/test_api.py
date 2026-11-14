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
    assert any("descartado" in a for a in j["avisos"])  # trecho sem passagem na planta é informado


# ---------- Regras de rota (rede traçada sobre a Planta Mix) ----------

def test_padrao_usa_escada_rolante_ate_a_praca_de_alimentacao():
    rota = calcular_rota(GRAFO, PERFIS["padrao"], "t_p1", "p_c")
    assert "escada_rolante" in rota["tipos"] and "t_esc" in rota["nos"]


def test_mobilidade_sem_elevador_nao_recebe_escada():
    pacote = copy.deepcopy(PACOTE)
    pacote["arestas"] = [a for a in pacote["arestas"] if a["tipo"] != "elevador"]
    assert calcular_rota(montar_grafo(pacote), PERFIS["mobilidade"], "t_p1", "p_c") is None


def test_mobilidade_chega_ao_2o_piso_pelo_elevador_atras_da_renner():
    rota = calcular_rota(GRAFO, PERFIS["mobilidade"], "t_p1", "p_c")
    assert "elevador" in rota["tipos"] and not {"escada", "escada_rolante", "esteira"} & set(rota["tipos"])
    assert all(n in rota["nos"] for n in ("t_rp", "t_elev", "p_elev"))


def test_visual_prefere_escada_fixa_a_escada_rolante():
    rota = calcular_rota(GRAFO, PERFIS["visual"], "t_p1", "p_c")
    assert "escada" in rota["tipos"] and "escada_rolante" not in rota["tipos"]


def test_trecho_nao_confirmado_nao_entra_em_rota_acessivel():
    base = calcular_rota(GRAFO, PERFIS["mobilidade"], "t_p1", "t_rn")
    alvo = base["arestas"][1]
    pacote = copy.deepcopy(PACOTE)
    next(a for a in pacote["arestas"] if a["id"] == alvo)["a_validar"] = True
    r = calcular_rota(montar_grafo(pacote), PERFIS["mobilidade"], "t_p1", "t_rn")
    assert r is None or alvo not in r["arestas"]


def test_distancias_em_metros_reais():
    rota = calcular_rota(GRAFO, PERFIS["padrao"], "t_p1", "p_c")
    assert 100 < rota["distancia"] < 160


def test_sensorial_reduz_trecho_em_area_de_estimulo_alto():
    est = {e["id"]: e.get("estimulo") for e in PACOTE["arestas"]}
    dist = {e["id"]: e.get("distancia") for e in PACOTE["arestas"]}
    alto = lambda r: sum(dist[a] or 0 for a in r["arestas"] if est[a] == "alto")
    padrao = calcular_rota(GRAFO, PERFIS["padrao"], "t_p1", "t_rn")
    sens = calcular_rota(GRAFO, PERFIS["sensorial"], "t_p1", "t_rn")
    assert alto(sens) < alto(padrao)


def test_rede_e_entradas_dentro_da_area_de_circulacao():
    from app.validador import validar_geometria
    assert validar_geometria(PACOTE) == []
    pacote = copy.deepcopy(PACOTE)
    e = next(a for a in pacote["arestas"] if a.get("geometria"))
    e["geometria"] = [e["geometria"][0], [0.2, 0.2], e["geometria"][-1]]  # atalho por fora do prédio
    assert any("atravessa obstáculo" in x for x in validar_geometria(pacote))


def test_cadastro_de_beacons_valida_posicao(monkeypatch, tmp_path):
    import json as _json
    from app import repositorio as R
    arq = tmp_path / "p.json"; arq.write_text(_json.dumps(PACOTE), encoding="utf-8")
    monkeypatch.setenv("PACOTE_ARQUIVO", str(arq)); monkeypatch.setenv("ADMIN_TOKEN", "t")
    R.repositorio.cache_clear()
    n = next(n for n in PACOTE["nos"] if n["id"] == "t_rs")
    ok = {"id": "b1", "uuid": "f7826da6-4fa2-4e98-8024-bc5b71e0893e", "major": 1, "minor": 1, "andar": 0, "x": n["x"], "y": n["y"]}
    assert cliente.put(f"/pacotes/{ID}/beacons", json=[ok]).status_code == 401
    ruim = dict(ok, id="b2", minor=2, x=1.0, y=1.0)
    r = cliente.put(f"/pacotes/{ID}/beacons", json=[ok, ruim], headers={"authorization": "Bearer t"})
    assert r.status_code == 422 and "b2" in str(r.json())
    r = cliente.put(f"/pacotes/{ID}/beacons", json=[ok], headers={"authorization": "Bearer t"})
    assert r.status_code == 200 and r.json()["beacons"] == 1
    R.repositorio.cache_clear()


def test_validador_detecta_poi_quebrado():
    pacote = copy.deepcopy(PACOTE)
    pacote["pois"][0]["no"] = "nao_existe"
    assert any("nó inexistente" in e for e in validar_pacote(pacote))


def test_validador_detecta_destino_inacessivel():
    pacote = copy.deepcopy(PACOTE)
    pacote["arestas"] = [a for a in pacote["arestas"] if a["tipo"] not in ("escada", "escada_rolante", "elevador")]
    erros = validar_pacote(pacote)
    assert any("sem rota 'padrao'" in e for e in erros)  # 2º piso isolado até no perfil padrão


def test_pacote_tem_lojas_da_planta_e_imagens():
    nomes = {p["nome"] for p in PACOTE["pois"]}
    assert {"Renner", "C&A", "Riachuelo", "Centauro", "Marisa", "Cinemark", "Outback", "McDonald's"} <= nomes
    assert len(PACOTE["pois"]) > 150
    for a in PACOTE["edificio"]["andares"]:
        assert set(a["imagens"]) == {"claro", "escuro", "terror"}
        assert all((ARQUIVO_PADRAO.parent / f).exists() for f in a["imagens"].values())
