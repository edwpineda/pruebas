from src.classifier.llm_classifier import _strip_code_fence


def test_strip_code_fence_with_json_tag():
    raw = '```json\n{"es_busqueda_de_servicio": true}\n```'
    assert _strip_code_fence(raw) == '{"es_busqueda_de_servicio": true}'


def test_strip_code_fence_without_tag():
    raw = '```\n{"a": 1}\n```'
    assert _strip_code_fence(raw) == '{"a": 1}'


def test_strip_code_fence_plain_json_untouched():
    raw = '{"a": 1}'
    assert _strip_code_fence(raw) == '{"a": 1}'
