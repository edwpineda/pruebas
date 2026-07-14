import logging
from datetime import timedelta

from .classifier import llm_classifier, prefilter
from .config import Config, load_keywords
from .connectors import google_search, post_fetch
from .notifier import telegram
from .storage import db

logger = logging.getLogger(__name__)


def run(config: Config = Config()) -> None:
    keywords = load_keywords()
    db.init_db(config.db_path)

    with db.connect(config.db_path) as conn:
        for query in keywords.get("queries_prioritarias", []):
            results = google_search.search(query, config.google_cse_api_key, config.google_cse_cx)
            logger.info("Query %r -> %d resultados", query, len(results))

            for item in results:
                url = item["link"]
                if db.is_seen(conn, url):
                    continue
                db.mark_seen(conn, url)

                post_fetch.polite_sleep()
                fetched = post_fetch.fetch_post(url)

                if fetched and fetched["published_at"]:
                    published_at = fetched["published_at"]
                    text = fetched["text"] or item["snippet"]
                    author_name = fetched["author_name"]
                else:
                    # No se pudo confirmar la fecha real (bloqueo anónimo o post sin metadata
                    # parseable): por diseño, descartamos en vez de asumir que está dentro de
                    # la ventana de 48hs (falso negativo > falso positivo para este caso de uso).
                    logger.info("Sin fecha confirmable, se descarta: %s", url)
                    continue

                age = db.now_utc() - published_at
                if age > timedelta(hours=config.freshness_hours):
                    logger.info("Post fuera de ventana de %sh (%s): %s", config.freshness_hours, age, url)
                    continue

                full_text = f"{item['title']}\n{text}"
                if not prefilter.passes_prefilter(full_text, keywords):
                    continue

                result = llm_classifier.classify(full_text, config.anthropic_api_key)
                if not result.get("es_busqueda_de_servicio"):
                    continue
                if result.get("confianza", 0.0) < config.confidence_threshold:
                    continue

                lead = {
                    "url": url,
                    "author_name": author_name,
                    "text": full_text,
                    "published_at": published_at,
                    "categoria": result.get("categoria"),
                    "confianza": result.get("confianza"),
                    "pais_probable": result.get("pais_probable"),
                }
                db.save_lead(conn, lead)
                telegram.notify(lead, config.telegram_bot_token, config.telegram_chat_id)
                logger.info("Lead nuevo notificado: %s", url)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    run()
