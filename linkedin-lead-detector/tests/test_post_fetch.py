from datetime import datetime, timezone
from pathlib import Path

from src.connectors.post_fetch import extract_published_at, extract_text

FIXTURES = Path(__file__).parent / "fixtures"


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def test_extract_published_at_from_jsonld():
    html = _read("sample_post_jsonld.html")
    assert extract_published_at(html) == datetime(2026, 7, 13, 10, 15, tzinfo=timezone.utc)


def test_extract_published_at_from_time_tag():
    html = _read("sample_post_time_tag.html")
    assert extract_published_at(html) == datetime(2026, 7, 10, 8, 0, tzinfo=timezone.utc)


def test_extract_published_at_returns_none_when_missing():
    html = _read("sample_post_no_date.html")
    assert extract_published_at(html) is None


def test_extract_text_parses_author_and_description():
    html = _read("sample_post_jsonld.html")
    fields = extract_text(html)
    assert fields["author_name"] == "Jane Doe"
    assert "headhunter" in fields["text"].lower()
