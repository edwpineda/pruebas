import logging
import sqlite3
from datetime import timedelta
from typing import Optional

from .classifier import llm_classifier, prefilter
from .config import Config, load_keywords
from .connectors import post_fetch
from .notifier import telegram
from .storage import db

logger = logging.getLogger(__name__)


def _classify_and_notify(
    conn: sqlite3.Connection,
    url: str,
    text: str,
    author_name: str,
    published_at,
    config: Config,
    keywords: dict,
) -> None:
    age = db.now_utc() - published_at
    if age > timedelta(hours=config.freshness_hours):
        print(f"[DESCARTADO] fuera de ventana de {config.freshness_hours}h ({age}): {url}")
        return

    if not prefilter.passes_prefilter(text, keywords):
        print(f"[DESCARTADO] no pasa prefiltro de keywords: {url}")
        return

    result = llm_classifier.classify(text, config.anthropic_api_key)
    print(f"[CLASIFICADO] {result}")

    if not result.get("es_busqueda_de_servicio") or result.get("confianza", 0.0) < config.confidence_threshold:
        print(f"[DESCARTADO] no califica como lead (umbral {config.confidence_threshold}): {url}")
        return

    lead = {
        "url": url,
        "author_name": author_name,
        "text": text,
        "published_at": published_at,
        "categoria": result.get("categoria"),
        "confianza": result.get("confianza"),
        "pais_probable": result.get("pais_probable"),
    }
    db.save_lead(conn, lead)
    telegram.notify(lead, config.telegram_bot_token, config.telegram_chat_id)
    print(f"[LEAD NOTIFICADO] {url}")


def run_manual_urls(urls: list[str], config: Config = Config(), force: bool = False) -> None:
    """Corre el pipeline completo (fetch anónimo incluido) sobre URLs de posts pasadas a mano."""
    keywords = load_keywords()
    db.init_db(config.db_path)

    with db.connect(config.db_path) as conn:
        for url in urls:
            if not force and db.is_seen(conn, url):
                print(f"[SKIP] ya visto: {url}")
                continue
            db.mark_seen(conn, url)

            fetched = post_fetch.fetch_post(url)
            if not fetched or not fetched["published_at"]:
                print(f"[DESCARTADO] LinkedIn bloqueó el fetch o no se pudo confirmar fecha: {url}")
                continue

            _classify_and_notify(conn, url, fetched["text"], fetched["author_name"], fetched["published_at"], config, keywords)


def run_manual_text(
    url: str,
    text: str,
    author_name: str = "",
    published_at: Optional[object] = None,
    config: Config = Config(),
    force: bool = False,
) -> None:
    """Salta el fetch (útil si LinkedIn bloquea el GET anónimo, o para probar sin depender de
    Google/LinkedIn): el texto del post se pega a mano, asumiendo que se vio recién ahora."""
    keywords = load_keywords()
    db.init_db(config.db_path)
    published_at = published_at or db.now_utc()

    with db.connect(config.db_path) as conn:
        if not force and db.is_seen(conn, url):
            print(f"[SKIP] ya visto: {url}")
            return
        db.mark_seen(conn, url)
        _classify_and_notify(conn, url, text, author_name, published_at, config, keywords)
