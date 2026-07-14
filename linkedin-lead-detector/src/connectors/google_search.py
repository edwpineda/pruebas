import logging

import requests

logger = logging.getLogger(__name__)

CSE_ENDPOINT = "https://www.googleapis.com/customsearch/v1"


def search(query: str, api_key: str, cx: str, date_restrict: str = "d1") -> list[dict]:
    """Corre una query contra Google Programmable Search Engine.

    date_restrict usa la sintaxis de Google: d1 = último día, w1 = última semana, etc.
    Devuelve una lista de {title, link, snippet}; lista vacía si no hay resultados o hay error
    (falla silenciosa a propósito: una query sin resultados no debe tumbar todo el poleo).
    """
    params = {
        "key": api_key,
        "cx": cx,
        "q": query,
        "dateRestrict": date_restrict,
        "num": 10,
    }
    try:
        resp = requests.get(CSE_ENDPOINT, params=params, timeout=15)
        resp.raise_for_status()
    except requests.RequestException as exc:
        logger.warning("Google CSE falló para query %r: %s", query, exc)
        return []

    data = resp.json()
    items = data.get("items", [])
    return [
        {"title": item.get("title", ""), "link": item.get("link", ""), "snippet": item.get("snippet", "")}
        for item in items
        if "linkedin.com" in item.get("link", "")
    ]
