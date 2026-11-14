"""Tipos de deficiência do cadastro → perfis de rota (mesma tabela de web-demo/nucleo.js)."""
from __future__ import annotations

TIPOS_DEFICIENCIA: dict[str, str] = {
    "cadeirante": "mobilidade",
    "mobilidade_reduzida": "mobilidade",
    "cegueira": "visual",
    "baixa_visao": "visual",
    "auditiva": "auditiva",
    "fala": "padrao",  # muda a comunicação (Conversar), não o percurso
    "tea": "sensorial",
    "intelectual": "sensorial",
    "outra": "padrao",
}


def perfis_do_usuario(possui_deficiencia: bool, tipos: list[str]) -> list[str]:
    if not possui_deficiencia:
        return ["padrao"]
    perfis = sorted({TIPOS_DEFICIENCIA[t] for t in tipos} - {"padrao"})
    return perfis or ["padrao"]


def combinar_perfis(pacote: dict, ids: list[str]) -> dict:
    """Restrições somam; multiplicadores e penalidade de curva usam o maior valor."""
    ids = [i for i in ids if i in pacote["perfis"]] or ["padrao"]
    out = {"ids": ids, "proibidos": set(), "multiplicador_tipo": {}, "multiplicador_estimulo": {}, "penalidade_curva": 0,
           "exigir_confirmado": False}
    for i in ids:
        p = pacote["perfis"][i]
        out["proibidos"] |= set(p.get("proibidos", []))
        for campo in ("multiplicador_tipo", "multiplicador_estimulo"):
            for k, v in p.get(campo, {}).items():
                out[campo][k] = max(out[campo].get(k, 1), v)
        out["penalidade_curva"] = max(out["penalidade_curva"], p.get("penalidade_curva", 0))
        out["exigir_confirmado"] = out["exigir_confirmado"] or p.get("exigir_confirmado", False)
    out["proibidos"] = sorted(out["proibidos"])
    return out
