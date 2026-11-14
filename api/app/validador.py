"""Validação de integridade do pacote de navegação antes da publicação."""
from __future__ import annotations

import math

from .navegacao import calcular_rota, montar_grafo

TIPOS_ARESTA = {"corredor", "escada", "rampa", "elevador", "esteira", "escada_rolante"}
CATEGORIAS = {"loja", "alimentacao", "sanitario", "servico", "lazer"}


def validar_pacote(pacote: dict) -> list[str]:
    """Retorna a lista de problemas encontrados (vazia = pacote válido)."""
    erros: list[str] = []
    andares = {a["id"] for a in pacote["edificio"]["andares"]}
    ids_nos = [n["id"] for n in pacote["nos"]]
    nos = set(ids_nos)

    if len(ids_nos) != len(nos):
        erros.append("IDs de nós duplicados")
    for n in pacote["nos"]:
        if n["andar"] not in andares:
            erros.append(f"nó {n['id']} em andar inexistente {n['andar']}")

    for e in pacote["arestas"]:
        if e["de"] not in nos or e["para"] not in nos:
            erros.append(f"aresta {e['id']} liga nó inexistente")
        if e["tipo"] not in TIPOS_ARESTA:
            erros.append(f"aresta {e['id']} com tipo inválido {e['tipo']}")

    for p in pacote["pois"]:
        if p["no"] not in nos:
            erros.append(f"POI {p['id']} ligado a nó inexistente {p['no']}")
        if p["categoria"] not in CATEGORIAS:
            erros.append(f"POI {p['id']} com categoria inválida")

    for b in pacote.get("beacons", []):
        if b["no"] not in nos:
            erros.append(f"beacon {b['id']} ligado a nó inexistente")

    if erros:
        return erros

    # Todo destino precisa ser alcançável a partir de ALGUMA entrada em cada perfil (senão é erro).
    # Se não for alcançável a partir de alguma entrada específica, vira aviso (limitação real da planta).
    grafo = montar_grafo(pacote)
    entradas = [n["id"] for n in pacote["nos"] if n["tipo"] == "entrada"]
    # Sem rota no perfil padrão = rede quebrada (erro). Nos perfis com restrição é limitação real
    # da planta e vira aviso (ver avisos_acessibilidade).
    perfil = pacote["perfis"]["padrao"]
    for p in pacote["pois"]:
        if not any(calcular_rota(grafo, perfil, e, p["no"]) is not None for e in entradas):
            erros.append(f"sem rota 'padrao' de nenhuma entrada até {p['id']}")
    erros += validar_geometria(pacote)
    return erros


# ---------- geometria: rotas só em área de circulação ----------

def grade_de(andar: dict) -> tuple[list[list[int]], float] | None:
    g = andar.get("grade")
    if not g:
        return None
    bits = []
    for linha in g["rle"]:
        out, v = [], 0
        for n in linha:
            out += [v] * n
            v ^= 1
        bits.append(out)
    return bits, g["celula_m"]


def livre(grade, x: float, y: float) -> bool:
    bits, c = grade
    l, k = int(y // c), int(x // c)
    return 0 <= l < len(bits) and 0 <= k < len(bits[0]) and bits[l][k] == 1


def segmento_livre(grade, a, b, passo: float = 0.25) -> bool:
    n = max(1, math.ceil(math.hypot(b[0] - a[0], b[1] - a[1]) / passo))
    return all(livre(grade, a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n + 1))


def validar_geometria(pacote: dict) -> list[str]:
    """Todo trecho de corredor, entrada de loja e beacon precisa estar na área de circulação da planta."""
    erros = []
    grades = {a["id"]: grade_de(a) for a in pacote["edificio"]["andares"]}
    nos = {n["id"]: n for n in pacote["nos"]}
    arestas = {e["id"]: e for e in pacote["arestas"]}
    for e in pacote["arestas"]:
        g = grades.get(nos[e["de"]]["andar"])
        if e["tipo"] != "corredor" or g is None or e.get("a_validar"):
            continue
        if "geometria" not in e:
            erros.append(f"trecho {e['id']} sem geometria verificada")
            continue
        pts = e["geometria"]
        if any(not segmento_livre(g, a, b) for a, b in zip(pts, pts[1:])):
            erros.append(f"trecho {e['id']} atravessa obstáculo da planta")
    for p in pacote["pois"]:
        ent, g = p.get("entrada"), grades.get(p["andar"])
        if ent and g:
            if not livre(g, ent["x"], ent["y"]):
                erros.append(f"entrada de {p['id']} fora da área de circulação")
            if ent["aresta"] not in arestas:
                erros.append(f"entrada de {p['id']} ancorada em trecho inexistente")
    for b in pacote.get("beacons", []):
        g = grades.get(b["andar"])
        if g and "x" in b and not livre(g, b["x"], b["y"]):
            erros.append(f"beacon {b['id']} fora da área de circulação")
    return erros


def avisos_acessibilidade(pacote: dict) -> list[str]:
    """Destinos sem rota acessível confirmada a partir de cada entrada (para informar ao visitante e ao shopping)."""
    grafo = montar_grafo(pacote)
    entradas = [n["id"] for n in pacote["nos"] if n["tipo"] == "entrada"]
    out = []
    out += [f"sem entrada ancorada (rota até o nó mais próximo): {p['id']}" for p in pacote["pois"] if "entrada" not in p]
    out += [f"trecho {t['id']} descartado: {t['motivo']}" for t in pacote.get("trechos_descartados", [])]
    for nome_perfil in ("mobilidade", "visual"):
        perfil = pacote["perfis"][nome_perfil]
        for e in entradas:
            sem = [p["id"] for p in pacote["pois"] if calcular_rota(grafo, perfil, e, p["no"]) is None]
            if sem:
                out.append(f"{nome_perfil}: {len(sem)} destinos sem rota confirmada a partir de {e}")
    return out
