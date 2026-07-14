import json
import logging
import random
import time
from datetime import datetime, timezone
from typing import Optional

import requests
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

BLOCKED_URL_MARKERS = ("authwall", "/login", "/uas/login")


def polite_sleep(base: float = 3.0, jitter: float = 2.0) -> None:
    time.sleep(base + random.uniform(0, jitter))


def _find_date_published(node) -> Optional[str]:
    """Busca recursivamente una clave datePublished en un JSON-LD (puede venir anidado)."""
    if isinstance(node, dict):
        if "datePublished" in node:
            return node["datePublished"]
        for value in node.values():
            found = _find_date_published(value)
            if found:
                return found
    elif isinstance(node, list):
        for item in node:
            found = _find_date_published(item)
            if found:
                return found
    return None


def _parse_datetime(value: str) -> Optional[datetime]:
    try:
        cleaned = value.replace("Z", "+00:00")
        dt = datetime.fromisoformat(cleaned)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except (ValueError, TypeError):
        return None


def extract_published_at(html: str) -> Optional[datetime]:
    soup = BeautifulSoup(html, "html.parser")

    for script in soup.find_all("script", type="application/ld+json"):
        try:
            data = json.loads(script.string or "")
        except (json.JSONDecodeError, TypeError):
            continue
        raw = _find_date_published(data)
        if raw:
            parsed = _parse_datetime(raw)
            if parsed:
                return parsed

    time_tag = soup.find("time", attrs={"datetime": True})
    if time_tag:
        parsed = _parse_datetime(time_tag["datetime"])
        if parsed:
            return parsed

    for meta_attrs in (
        {"property": "article:published_time"},
        {"name": "date"},
        {"itemprop": "datePublished"},
    ):
        tag = soup.find("meta", attrs=meta_attrs)
        if tag and tag.get("content"):
            parsed = _parse_datetime(tag["content"])
            if parsed:
                return parsed

    return None


def extract_text(html: str) -> dict:
    soup = BeautifulSoup(html, "html.parser")

    def meta_content(attrs):
        tag = soup.find("meta", attrs=attrs)
        return tag["content"].strip() if tag and tag.get("content") else ""

    og_title = meta_content({"property": "og:title"})
    og_description = meta_content({"property": "og:description"})

    author_name = og_title.split(" on LinkedIn")[0].strip() if " on LinkedIn" in og_title else og_title

    return {"author_name": author_name, "text": og_description}


def fetch_post(url: str, timeout: int = 10) -> Optional[dict]:
    """GET anónimo (sin cookies de sesión) a la página pública del post.

    Devuelve None si LinkedIn bloqueó el acceso (authwall/login/rate limit) — el llamador debe
    tratar eso como "no se pudo confirmar", no como "el post no existe".
    """
    headers = {"User-Agent": USER_AGENT, "Accept-Language": "es-419,es;q=0.9,en;q=0.8"}
    try:
        resp = requests.get(url, headers=headers, timeout=timeout, allow_redirects=True)
    except requests.RequestException as exc:
        logger.warning("Fetch anónimo falló para %s: %s", url, exc)
        return None

    if resp.status_code in (999, 403, 429):
        logger.info("LinkedIn bloqueó el fetch anónimo (status %s) para %s", resp.status_code, url)
        return None

    if any(marker in resp.url for marker in BLOCKED_URL_MARKERS):
        logger.info("Fetch anónimo redirigido a authwall/login para %s", url)
        return None

    if resp.status_code != 200:
        return None

    published_at = extract_published_at(resp.text)
    fields = extract_text(resp.text)

    return {
        "author_name": fields["author_name"],
        "text": fields["text"],
        "published_at": published_at,
    }
