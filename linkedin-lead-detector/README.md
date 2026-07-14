# LinkedIn Lead Detector — headhunter / consultoría RRHH (LatAm)

Implementación del diseño en [`../docs/linkedin-headhunter-detector.md`](../docs/linkedin-headhunter-detector.md).
Detecta posts públicos de LinkedIn (últimas 48hs) donde alguien busca contratar un headhunter o una
consultora de RRHH, **sin loguearse nunca en LinkedIn** (conector D del diseño): usa la API de
búsqueda de Google, y opcionalmente confirma la fecha real haciendo un GET anónimo a la página del
post.

## Setup

```bash
cd linkedin-lead-detector
pip install -r requirements.txt
cp .env.example .env   # completar con tus credenciales, ver abajo
pytest tests/          # corre los tests que no requieren red ni credenciales
```

### Credenciales necesarias (`.env`)

1. **Google Programmable Search Engine** (gratis hasta 100 queries/día):
   - Crear un motor en https://programmablesearchengine.google.com/ acotado a `linkedin.com`
     (desactivar "Search the entire web").
   - Habilitar la Custom Search API en Google Cloud Console y generar una API key.
   - Completar `GOOGLE_CSE_API_KEY` y `GOOGLE_CSE_CX`.
2. **Anthropic** (clasificador de intención, etapa 2): `ANTHROPIC_API_KEY` desde
   https://console.anthropic.com/.
3. **Telegram** (notificaciones): hablar con `@BotFather`, crear un bot, y usar
   `https://api.telegram.org/bot<TOKEN>/getUpdates` (después de mandarle un mensaje al bot) para
   obtener tu `chat_id`.

## Uso

```bash
python main.py
```

Corre una pasada completa: por cada query en
[`../docs/linkedin-headhunter-detector-keywords.yaml`](../docs/linkedin-headhunter-detector-keywords.yaml)
busca en Google, descarta lo ya visto, confirma fecha real del post, filtra por ventana de 48hs
(`FRESHNESS_HOURS` en `.env`), corre el prefiltro de keywords y clasifica con Claude los que pasan.
Los leads con confianza sobre `CONFIDENCE_THRESHOLD` se guardan en SQLite (`leads.db`) y se notifican
por Telegram.

No es un proceso long-running: está pensado para dispararse periódicamente vía cron.

### Cron sugerido (cada 3hs)

```
0 */3 * * * cd /ruta/a/linkedin-lead-detector && /usr/bin/python3 main.py >> cron.log 2>&1
```

## Estructura

```
src/
  config.py              # carga .env + keywords.yaml
  connectors/
    google_search.py     # query a Google CSE
    post_fetch.py         # GET anónimo + parseo de fecha/autor/texto del post
  classifier/
    prefilter.py          # etapa 1: descarta lo que ni menciona el servicio
    llm_classifier.py     # etapa 2: Claude distingue demanda vs oferta
  storage/
    db.py                  # SQLite: tablas leads y seen_urls
  notifier/
    telegram.py            # alerta por Telegram
  pipeline.py               # orquesta todo lo anterior
main.py
tests/                      # tests unitarios sin red (parseo de HTML, prefiltro)
```

## Limitaciones conocidas (ver diseño para el detalle)

- **Cobertura parcial**: Google no indexa todos los posts públicos de LinkedIn, ni al instante.
  Este pipeline captura una porción real de los leads, no el 100%.
- **Bloqueo del fetch anónimo**: si LinkedIn empieza a bloquear el GET a la página del post
  (status 403/429/999 o redirect a authwall), el pipeline **descarta** ese resultado en vez de
  asumir que está dentro de la ventana de 48hs — prioriza no generar falsos positivos.
- **Sin filtro geográfico en la query**: el país se infiere después (heurística simple sobre el
  nombre/headline del autor vía el LLM) — no hay forma de pedirle a Google resultados solo de
  LatAm.
