import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone

SCHEMA = """
CREATE TABLE IF NOT EXISTS leads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    url TEXT UNIQUE NOT NULL,
    author_name TEXT,
    text TEXT,
    published_at TEXT,
    categoria TEXT,
    confianza REAL,
    pais_probable TEXT,
    estado TEXT DEFAULT 'nuevo',
    detected_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS seen_urls (
    url TEXT PRIMARY KEY,
    first_seen_at TEXT DEFAULT (datetime('now'))
);
"""


@contextmanager
def connect(db_path: str):
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db(db_path: str) -> None:
    with connect(db_path) as conn:
        conn.executescript(SCHEMA)


def is_seen(conn: sqlite3.Connection, url: str) -> bool:
    row = conn.execute("SELECT 1 FROM seen_urls WHERE url = ?", (url,)).fetchone()
    return row is not None


def mark_seen(conn: sqlite3.Connection, url: str) -> None:
    conn.execute("INSERT OR IGNORE INTO seen_urls (url) VALUES (?)", (url,))


def save_lead(conn: sqlite3.Connection, lead: dict) -> None:
    published_at = lead.get("published_at")
    published_at_str = published_at.isoformat() if isinstance(published_at, datetime) else published_at
    conn.execute(
        """
        INSERT OR IGNORE INTO leads
            (url, author_name, text, published_at, categoria, confianza, pais_probable)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            lead["url"],
            lead.get("author_name", ""),
            lead.get("text", ""),
            published_at_str,
            lead.get("categoria", ""),
            lead.get("confianza", 0.0),
            lead.get("pais_probable"),
        ),
    )


def now_utc() -> datetime:
    return datetime.now(timezone.utc)
