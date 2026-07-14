import logging

import requests

logger = logging.getLogger(__name__)

API_TEMPLATE = "https://api.telegram.org/bot{token}/sendMessage"


def notify(lead: dict, bot_token: str, chat_id: str) -> None:
    categoria = lead.get("categoria", "")
    pais = lead.get("pais_probable") or "país no identificado"
    confianza = lead.get("confianza", 0.0)
    text_preview = (lead.get("text") or "")[:280]

    message = (
        f"🎯 Lead nuevo ({categoria}, {confianza:.0%} confianza)\n"
        f"{pais} — {lead.get('author_name', 'autor desconocido')}\n\n"
        f"{text_preview}\n\n"
        f"{lead['url']}"
    )

    try:
        resp = requests.post(
            API_TEMPLATE.format(token=bot_token),
            json={"chat_id": chat_id, "text": message, "disable_web_page_preview": False},
            timeout=10,
        )
        resp.raise_for_status()
    except requests.RequestException as exc:
        logger.warning("No se pudo notificar por Telegram: %s", exc)
