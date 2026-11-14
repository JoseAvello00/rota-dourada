"""Motor de rotas de referência (mesma regra usada no app Flutter e no protótipo web).

A API NÃO calcula rotas durante o percurso — isso acontece no celular.
Este módulo existe para VALIDAR o pacote antes de publicá-lo: garante que
cada destino tem rota em todos os perfis (em especial, rota sem escadas).
"""
from __future__ import annotations

import heapq
import math
from dataclasses import dataclass, field


@dataclass
class Aresta:
    id: str
    de: str
    para: str
    tipo: str
    distancia: float
    estimulo: str = "medio"
    confirmado: bool = True


@dataclass
class Grafo:
    nos: dict[str, dict]
    adj: dict[str, list[Aresta]] = field(default_factory=dict)


def distancia_nos(a: dict, b: dict) -> float:
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def montar_grafo(pacote: dict) -> Grafo:
    nos = {n["id"]: n for n in pacote["nos"]}
    g = Grafo(nos=nos, adj={nid: [] for nid in nos})
    for e in pacote["arestas"]:
        dist = e.get("distancia") or distancia_nos(nos[e["de"]], nos[e["para"]])
        conf = not e.get("a_validar", False)
        ida = Aresta(e["id"], e["de"], e["para"], e["tipo"], dist, e.get("estimulo", "medio"), conf)
        g.adj[e["de"]].append(ida)
        if e.get("bidirecional", True):
            volta = Aresta(e["id"], e["para"], e["de"], e["tipo"], dist, e.get("estimulo", "medio"), conf)
            g.adj[e["para"]].append(volta)
    return g


def _curva(nos: dict, a: str, b: str, c: str) -> bool:
    """True se houver mudança de direção relevante (> 30°) em b."""
    pa, pb, pc = nos[a], nos[b], nos[c]
    if pa["andar"] != pb["andar"] or pb["andar"] != pc["andar"]:
        return False
    v1 = (pb["x"] - pa["x"], pb["y"] - pa["y"])
    v2 = (pc["x"] - pb["x"], pc["y"] - pb["y"])
    n1, n2 = math.hypot(*v1), math.hypot(*v2)
    if n1 == 0 or n2 == 0:
        return False
    cos = (v1[0] * v2[0] + v1[1] * v2[1]) / (n1 * n2)
    return cos < math.cos(math.radians(30))


def calcular_rota(grafo: Grafo, perfil: dict, origem: str, destino: str) -> dict | None:
    """Dijkstra com estado (nó, nó anterior) para permitir penalidade de curva.

    Retorna {"nos": [...], "arestas": [...], "distancia": m, "custo": c}
    ou None quando não existe rota compatível com o perfil.
    A acessibilidade tem precedência: arestas proibidas nunca entram.
    """
    proibidos = set(perfil.get("proibidos", []))
    mult_tipo = perfil.get("multiplicador_tipo", {})
    mult_est = perfil.get("multiplicador_estimulo", {})
    pen_curva = perfil.get("penalidade_curva", 0)
    so_confirmados = perfil.get("exigir_confirmado", False)

    inicio = (origem, None)
    melhor = {inicio: 0.0}
    anterior: dict[tuple, tuple[tuple, Aresta]] = {}
    fila = [(0.0, 0, origem, None)]
    contador = 1
    final = None

    while fila:
        custo, _, no, veio = heapq.heappop(fila)
        if custo > melhor.get((no, veio), math.inf):
            continue
        if no == destino:
            final = (no, veio)
            break
        for a in grafo.adj[no]:
            if a.tipo in proibidos or (so_confirmados and not a.confirmado):
                continue
            c = a.distancia * mult_tipo.get(a.tipo, 1.0) * mult_est.get(a.estimulo, 1.0)
            if veio is not None and pen_curva and _curva(grafo.nos, veio, no, a.para):
                c += pen_curva
            novo = custo + c
            estado = (a.para, no)
            if novo < melhor.get(estado, math.inf):
                melhor[estado] = novo
                anterior[estado] = ((no, veio), a)
                heapq.heappush(fila, (novo, contador, a.para, no))
                contador += 1

    if final is None:
        return None

    nos_rota, arestas_rota = [final[0]], []
    estado = final
    while estado in anterior:
        estado_ant, aresta = anterior[estado]
        arestas_rota.append(aresta)
        nos_rota.append(estado_ant[0])
        estado = estado_ant
    nos_rota.reverse()
    arestas_rota.reverse()
    return {
        "nos": nos_rota,
        "arestas": [a.id for a in arestas_rota],
        "tipos": [a.tipo for a in arestas_rota],
        "distancia": round(sum(a.distancia for a in arestas_rota), 1),
        "custo": round(melhor[final], 1),
    }
