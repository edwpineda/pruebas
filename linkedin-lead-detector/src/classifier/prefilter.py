import re


def _flatten(*groups) -> list[str]:
    terms = []
    for group in groups:
        if isinstance(group, dict):
            for values in group.values():
                terms.extend(values)
        elif isinstance(group, list):
            terms.extend(group)
    return terms


def _any_match(text: str, terms: list[str]) -> bool:
    return any(re.search(re.escape(term), text) for term in terms)


def passes_prefilter(text: str, keywords: dict) -> bool:
    """Filtro barato: exige al menos un término de servicio en el texto.

    No intenta distinguir demanda de oferta (eso lo hace el LLM en la etapa 2) — acá solo se
    descarta lo que ni siquiera menciona un servicio de headhunting/RRHH, para no gastar tokens
    de LLM en resultados irrelevantes que puedan haber colado por el snippet de Google.
    """
    normalized = text.lower()
    servicio_terms = _flatten(keywords.get("servicio", {}))
    return _any_match(normalized, [t.lower() for t in servicio_terms])
