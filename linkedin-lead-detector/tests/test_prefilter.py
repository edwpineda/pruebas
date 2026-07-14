from src.classifier.prefilter import passes_prefilter

KEYWORDS = {
    "servicio": {
        "es": ["headhunter", "consultora de RRHH"],
        "pt": ["caçador de talentos"],
    }
}


def test_passes_when_servicio_term_present():
    assert passes_prefilter("Buscamos un headhunter para una búsqueda confidencial", KEYWORDS)


def test_rejects_when_no_servicio_term():
    assert not passes_prefilter("Estamos contratando Desarrollador Senior, postulate", KEYWORDS)


def test_is_case_insensitive():
    assert passes_prefilter("NECESITAMOS UNA CONSULTORA DE RRHH", KEYWORDS)
