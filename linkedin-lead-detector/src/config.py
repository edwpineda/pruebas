import os
from pathlib import Path

import yaml
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
KEYWORDS_PATH = BASE_DIR.parent / "docs" / "linkedin-headhunter-detector-keywords.yaml"

load_dotenv(BASE_DIR / ".env")


class Config:
    google_cse_api_key = os.environ.get("GOOGLE_CSE_API_KEY", "")
    google_cse_cx = os.environ.get("GOOGLE_CSE_CX", "")
    anthropic_api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    telegram_bot_token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    telegram_chat_id = os.environ.get("TELEGRAM_CHAT_ID", "")
    confidence_threshold = float(os.environ.get("CONFIDENCE_THRESHOLD", "0.6"))
    db_path = os.environ.get("DB_PATH", str(BASE_DIR / "leads.db"))
    freshness_hours = int(os.environ.get("FRESHNESS_HOURS", "48"))


def load_keywords(path: Path = KEYWORDS_PATH) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)
