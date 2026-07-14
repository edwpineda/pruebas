import argparse
import logging

from src.manual_pipeline import run_manual_text, run_manual_urls

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    parser = argparse.ArgumentParser(
        description="Corre el clasificador + notificador sin depender de la búsqueda automática de Google."
    )
    subparsers = parser.add_subparsers(dest="modo", required=True)

    p_urls = subparsers.add_parser("urls", help="Fetch anónimo real + clasificación sobre URLs de posts")
    p_urls.add_argument("urls", nargs="+", help="URLs de posts de LinkedIn")
    p_urls.add_argument("--force", action="store_true", help="Ignora el chequeo de 'ya visto'")

    p_text = subparsers.add_parser("text", help="Clasificación directa sobre texto pegado a mano (sin fetch)")
    p_text.add_argument("--url", required=True, help="URL del post (se usa como identificador único)")
    p_text.add_argument("--text", required=True, help="Texto del post, copiado a mano desde LinkedIn")
    p_text.add_argument("--author", default="", help="Nombre del autor (opcional)")
    p_text.add_argument("--force", action="store_true", help="Ignora el chequeo de 'ya visto'")

    args = parser.parse_args()

    if args.modo == "urls":
        run_manual_urls(args.urls, force=args.force)
    else:
        run_manual_text(args.url, args.text, author_name=args.author, force=args.force)
