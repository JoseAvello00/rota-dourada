"""Validação de integridade do pacote de navegação antes da publicação."""
from __future__ import annotations

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
    for nome_perfil, perfil in pacote["perfis"].items():
        for p in pacote["pois"]:
            alcancavel = [e for e in entradas if calcular_rota(grafo, perfil, e, p["no"]) is not None]
            if not alcancavel:
                erros.append(f"sem rota '{nome_perfil}' de nenhuma entrada até {p['id']}")
    return erros


def avisos_acessibilidade(pacote: dict) -> list[str]:
    """Destinos sem rota acessível confirmada a partir de cada entrada (para informar ao visitante e ao shopping)."""
    grafo = montar_grafo(pacote)
    entradas = [n["id"] for n in pacote["nos"] if n["tipo"] == "entrada"]
    out = []
    for nome_perfil in ("mobilidade", "visual"):
        perfil = pacote["perfis"][nome_perfil]
        for e in entradas:
            sem = [p["id"] for p in pacote["pois"] if calcular_rota(grafo, perfil, e, p["no"]) is None]
            if sem:
                out.append(f"{nome_perfil}: {len(sem)} destinos sem rota confirmada a partir de {e}")
    return out
