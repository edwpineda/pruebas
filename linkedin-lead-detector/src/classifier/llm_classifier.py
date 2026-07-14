import json
import logging

from anthropic import Anthropic

logger = logging.getLogger(__name__)

MODEL = "claude-haiku-4-5-20251001"

SYSTEM_PROMPT = """Sos un clasificador de leads B2B para una empresa de headhunting/consultoría de RRHH en Latinoamérica.
Te paso el texto de un post de LinkedIn. Respondé ÚNICAMENTE un JSON con este formato exacto:
{
  "es_busqueda_de_servicio": true|false,
  "categoria": "headhunter" | "consultoria_rrhh" | "ambos" | "no_aplica",
  "confianza": 0.0-1.0,
  "pais_probable": "string o null",
  "motivo": "una frase corta"
}

Marcá es_busqueda_de_servicio=true SOLO si el autor (persona o empresa) está buscando CONTRATAR
un headhunter o una consultora de RRHH para una búsqueda propia.
Marcá false si el autor está OFRECIENDO ese servicio, es un job posting común ("buscamos Gerente
de Finanzas, postulate"), habla del tema en general, o no está relacionado.
No respondas nada fuera del JSON."""


def classify(text: str, api_key: str) -> dict:
    client = Anthropic(api_key=api_key)
    try:
        response = client.messages.create(
            model=MODEL,
            max_tokens=300,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f'Post: "{text}"'}],
        )
    except Exception as exc:  # noqa: BLE001 — cualquier falla de API no debe tumbar el pipeline
        logger.warning("Clasificación LLM falló: %s", exc)
        return {"es_busqueda_de_servicio": False, "categoria": "no_aplica", "confianza": 0.0, "motivo": "error_api"}

    raw = response.content[0].text.strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        logger.warning("Respuesta del clasificador no es JSON válido: %r", raw)
        return {"es_busqueda_de_servicio": False, "categoria": "no_aplica", "confianza": 0.0, "motivo": "respuesta_invalida"}
