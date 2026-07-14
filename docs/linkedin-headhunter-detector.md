# Diseño — Agente detector de publicaciones LinkedIn buscando headhunter / consultoría RRHH

## 1. Objetivo

Detectar, en una ventana de **máximo 48 horas** desde su publicación, posts públicos de LinkedIn
donde una persona o empresa está **buscando contratar** (no ofreciendo) alguno de estos servicios:

- Headhunter / executive search.
- Consultoría o tercerización de Recursos Humanos (selección de personal, reclutamiento, etc).

El caso de uso típico es *sales intelligence / generación de leads*: apenas alguien publica "estamos
buscando un headhunter para cubrir una posición de gerencia", el agente lo detecta y avisa para poder
contactar mientras el lead está fresco. Las 48hs son la restricción de negocio central: un lead de
5 días es casi inútil porque ya lo contactaron 20 headhunters más.

## 2. Restricción crítica a resolver primero: LinkedIn no tiene una API de búsqueda abierta

Antes de diseñar el pipeline hay que resolver **de dónde sale el dato**, porque condiciona todo lo
demás. LinkedIn:

- No ofrece una API pública de búsqueda de posts por palabra clave (su API oficial es para
  partners de Marketing/Talent Solutions, con aprobación manual y casos de uso específicos).
- Prohíbe en sus Términos de Servicio el scraping automatizado, y persigue activamente cuentas y
  herramientas que lo hacen (rate limiting agresivo, baneos de cuenta, y en algunos casos acciones
  legales contra proveedores de scraping).

Esto no es un detalle técnico menor: define qué tan "automático" puede ser el agente sin poner en
riesgo la cuenta de LinkedIn del usuario o exponerlo legalmente. Hay tres caminos, de más a menos
seguro:

| Opción | Cómo funciona | Riesgo ToS/legal | Cobertura / freshness |
|---|---|---|---|
| **A. Sales Navigator (recomendada)** | LinkedIn Sales Navigator (plan pago oficial) permite guardar búsquedas booleanas y activar **alertas** que notifican por email/in-app cuando aparece contenido nuevo que matchea. Es una función contractual del producto, no automatización externa. | Ninguno (es una feature pagada del propio LinkedIn) | Alertas casi en tiempo real, pero el *matching* de LinkedIn es más limitado que un filtro propio (booleano simple, no NLP) |
| **B. Herramienta de social listening con licencia de datos** (Meltwater, Talkwalker, Brand24, etc) | Estas plataformas tienen acuerdos de datos con LinkedIn y exponen API/webhook propios | Ninguno para vos (el proveedor asume el cumplimiento) | Depende del proveedor; suele haber delay de minutos a horas |
| **C. Scraping no oficial** (Playwright con sesión logueada, o proveedores tipo Proxycurl/PhantomBuster) | Un bot navega LinkedIn autenticado y extrae posts de resultados de búsqueda | Alto: viola ToS, riesgo real de suspensión de cuenta y exposición legal | Total flexibilidad de filtro, pero frágil (LinkedIn cambia el DOM/detección seguido) |
| **D. Búsqueda vía motor de búsqueda, sin login** (Google/Bing indexando `linkedin.com`) | El agente nunca inicia sesión en LinkedIn: consulta periódicamente la API de búsqueda de Google/Bing acotada a `site:linkedin.com`, y opcionalmente hace un GET anónimo (sin cookies de sesión) a la URL del post para leer metadatos públicos de la página | Bajo — no toca tu cuenta de LinkedIn en ningún momento, así que no hay riesgo de baneo de cuenta. El GET anónimo a la página del post sigue siendo "acceso automatizado" a LinkedIn, pero sin credenciales en juego el peor caso es que te bloqueen la IP, no la cuenta | **Limitada**: LinkedIn indexa en Google solo una fracción de los posts (los de visibilidad pública), y con demora — puede no alcanzar a cumplir la ventana de 48hs de forma confiable en todos los casos |

**Como no tenés LinkedIn pago, la opción elegida es D.** Es la única que no requiere ni pagar ni
loguearse con tu cuenta personal, a costa de menor cobertura (no vas a detectar el 100% de los
posts relevantes, pero sí una porción real, sin ningún riesgo de cuenta). El resto del diseño
(secciones 3.2 en adelante) es igual sea cual sea el conector — así que si más adelante conseguís
Sales Navigator o decidís asumir el riesgo de un scraper, se agrega como otro conector sin tocar
el resto del pipeline.

## 3. Arquitectura general

```
┌──────────────┐   ┌───────────────┐   ┌────────────────┐   ┌───────────────┐   ┌─────────────┐
│  Conectores  │──▶│  Normalizador │──▶│ Filtro 48hs +   │──▶│  Clasificador │──▶│ Notificador │
│  de ingesta  │   │  (schema      │   │ dedup           │   │  de intención │   │  + storage  │
│  (A/B/C)     │   │   común)      │   │                 │   │  (LLM)        │   │             │
└──────────────┘   └───────────────┘   └────────────────┘   └───────────────┘   └─────────────┘
```

### 3.1 Conectores de ingesta

Interfaz común, cada uno devuelve una lista de posts crudos:

```
Post {
  external_id: string
  author_name: string
  author_headline: string   # ej: "CEO en Acme SRL"
  text: string
  url: string
  published_at: datetime    # normalizado a UTC
  source: "google_search" | "sales_navigator" | "social_listening" | "scraper"
}
```

Poleo cada 30–60 minutos (suficiente margen para no perder la ventana de 48hs, sin ser agresivo).

#### Detalle del conector D (búsqueda vía Google, sin login)

**Paso 1 — Query a la API de búsqueda.** Nunca scrapear la página de resultados de Google
directamente (eso sí tiene fricción legal/técnica propia — Google también bloquea bots). Usar una
API oficial:

- **Google Programmable Search Engine (CSE) API**: tier gratuito de 100 queries/día, pagas
  US$5 cada 1000 adicionales. Se configura un "motor" restringido a `linkedin.com`.
- Alternativa si 100/día se queda corto: **SerpApi** o **Serper.dev** (proveedores que devuelven
  resultados de Google como JSON limpio, unos pocos dólares por 1000 búsquedas) — resuelven el
  scraping de la SERP de Google por vos de forma legal (tienen licencia para eso), así que tu
  código nunca toca Google directamente.

Se arma un set de queries combinando keywords ES/EN con `site:linkedin.com/posts`, por ejemplo:

```
site:linkedin.com/posts "buscamos headhunter"
site:linkedin.com/posts "necesitamos consultora de RRHH"
site:linkedin.com/posts "búsqueda ejecutiva" contratar
site:linkedin.com/posts "looking for a recruiter"
site:linkedin.com/posts "need a headhunter"
```

Y se filtra por fecha usando el parámetro de rango temporal de Google (`tbs=qdr:d` = último día,
`tbs=qdr:w` = última semana). Como no hay un valor exacto de "últimas 48hs", conviene correr con
`qdr:d` (24hs) en cada poleo, corriendo el poleo cada pocas horas — así casi ningún post relevante
queda fuera de una corrida u otra dentro de la ventana de 48hs.

**Paso 2 — Confirmar fecha real del post (sin login).** El snippet de Google no es confiable para
la fecha exacta. Para cada URL de resultado, hacer un `GET` HTTP anónimo (sin cookies de sesión,
identificándose con un User-Agent normal de navegador) a la página pública del post y leer las
meta tags que LinkedIn expone para SEO (`og:title`, `og:description`, y en varios casos
`article:published_time` o similar en el HTML). Si la página no expone fecha parseable, descartar
el post en vez de asumir que está dentro de la ventana — falso negativo es preferible a falso
positivo acá, porque el problema de negocio es "no perder tiempo con leads viejos".

**Paso 3 — Fallback si LinkedIn bloquea el GET anónimo.** Si empieza a devolver 999/429 o un muro
de login (puede pasar, LinkedIn también limita tráfico anónimo sospechoso), quedarse con lo que
devuelve el snippet de Google + fecha relativa de la SERP, marcando esos posts con menor
confianza, y bajar la frecuencia de estos GETs (ej. 1 cada 3-5 segundos, con jitter) para no
parecer un bot agresivo.

### 3.2 Filtro de frescura (48hs) y deduplicación

- Descartar todo post con `now - published_at > 48h`.
- Ojo con la fuente del timestamp: LinkedIn muestra tiempos relativos ("hace 2h", "1d") en vez de
  fecha absoluta en varias vistas — hay que parsear eso a un instante concreto en el momento de la
  ingesta (no recalcular después, porque "hace 2h" visto hoy y visto mañana no es lo mismo).
- Deduplicar por hash de `(author_name, texto_normalizado)` para no re-alertar reposts/shares del
  mismo contenido.

### 3.3 Clasificador de intención (la parte difícil)

El filtro por keywords solo no alcanza porque hay que distinguir:

- ✅ **Demanda** (lo que queremos detectar): *"Buscamos una consultora de RRHH para tercerizar
  selección"*, *"¿Alguien recomienda un headhunter para una búsqueda de CFO?"*
- ❌ **Oferta** (ruido, hay que descartarlo): *"Soy headhunter, si buscás talento contactame"*,
  *"Lanzamos nuestra consultora de executive search"*

Esto es exactamente el tipo de matiz donde un filtro de keywords se queda corto y conviene un LLM.
Diseño en dos etapas para no gastar de más:

**Etapa 1 — prefiltro barato (regex/keywords)**, corre sobre el 100% de los posts, solo para
descartar lo obviamente irrelevante:

```
ES: headhunter, head hunter, executive search, consultora de RRHH, consultora de RH,
    reclutamiento, selección de personal, tercerizar selección, búsqueda ejecutiva,
    buscamos.*(headhunter|consultora|recruiter), necesitamos.*(headhunter|RRHH)
EN: headhunter, executive search, HR consulting, recruiting agency, talent acquisition partner,
    looking for a recruiter, need a headhunter
```

**Etapa 2 — clasificación por LLM**, corre solo sobre lo que pasó la etapa 1 (mucho menos volumen,
así el costo de tokens es bajo). Ejemplo de prompt (usando Claude, modelo económico tipo Haiku
porque es una tarea de clasificación simple, no generación):

```
Sos un clasificador de leads B2B. Te paso el texto de un post de LinkedIn.
Respondé JSON: {
  "es_busqueda_de_servicio": true|false,
  "categoria": "headhunter" | "consultoria_rrhh" | "ambos" | "no_aplica",
  "confianza": 0.0-1.0,
  "motivo": "una frase corta"
}

Marcá true SOLO si el autor (persona o empresa) está buscando CONTRATAR el servicio.
Marcá false si el autor está OFRECIENDO el servicio, hablando del tema en general,
o es un contenido no relacionado.

Post: "{texto}"
```

### 3.4 Almacenamiento

Tabla simple (Postgres/SQLite alcanza para el volumen esperado):

```sql
CREATE TABLE leads (
  id UUID PRIMARY KEY,
  external_id TEXT UNIQUE,
  author_name TEXT,
  author_headline TEXT,
  text TEXT,
  url TEXT,
  published_at TIMESTAMPTZ,
  categoria TEXT,
  confianza NUMERIC,
  estado TEXT DEFAULT 'nuevo',  -- nuevo | contactado | descartado
  detected_at TIMESTAMPTZ DEFAULT now()
);
```

### 3.5 Notificación

Dado que el valor del lead cae con el tiempo, notificar **casi en tiempo real** (no como digest
diario): apenas un post pasa el clasificador con `confianza > umbral`, mandar a:

- Slack/Telegram (webhook simple, primer canal a implementar).
- Email como respaldo.
- Marcar en la tabla `leads` para que quede en un tablero simple de seguimiento (nuevo → contactado
  → descartado).

## 4. Stack sugerido para el MVP

- **Orquestación**: si se quiere ir rápido y sin mucho código, **n8n** (self-hosted o cloud) permite
  armar todo el pipeline (poleo del conector, filtro, llamada a Claude, notificación a Slack) con
  nodos, y da más flexibilidad que Zapier para la lógica de clasificación en dos etapas.
- **Alternativa a medida**: Python + APScheduler/cron para el poleo, llamada a la API de Claude
  (Haiku) para clasificación, Postgres/SQLite para storage, y un webhook de Slack/Telegram para
  notificar.
- **LLM**: Claude Haiku 4.5 alcanza y sobra para esta clasificación (tarea corta, output
  estructurado); usar Sonnet solo si se necesita mayor precisión en casos ambiguos.

## 5. MVP recomendado (primeras 2 semanas)

1. Dar de alta una **Google Programmable Search Engine** (o cuenta en SerpApi/Serper.dev) acotada
   a `linkedin.com`, y armar el set inicial de 8–10 queries (keywords ES/EN combinadas).
2. Script de poleo (cron cada 2-3hs) que corre las queries con `tbs=qdr:d`, dedupea URLs ya vistas,
   y para cada resultado nuevo intenta el GET anónimo para confirmar fecha real (conector D,
   sección 3.1).
3. Construir el clasificador de intención (etapa 1 + 2) sobre el texto obtenido (snippet + texto de
   la página si el GET anónimo funcionó).
4. Conectar la notificación a Slack/Telegram.
5. Medir cobertura real después de 1-2 semanas: cuántos leads reales capturó vs. los que el usuario
   ve manualmente navegando LinkedIn. Si la cobertura es insuficiente, recién ahí evaluar sumar
   Sales Navigator (opción A, cuando se pueda pagar) o un conector de social listening (opción B).

## 6. Métrica de éxito

- **Precision** del clasificador (de los leads notificados, cuántos eran reales) — más importante
  que el recall al principio, para no quemar confianza en las alertas.
- **Latencia detección→notificación** — objetivo: bajo 1 hora, para dejar margen dentro de la
  ventana de 48hs.
- Tasa de `estado = contactado` sobre el total de leads nuevos, como proxy de utilidad real.
