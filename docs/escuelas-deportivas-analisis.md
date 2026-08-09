# Plataforma de comunicación para escuelas deportivas

Nota de definición inicial: esquema de contenido, comparativa tecnológica y
arquitectura recomendada para un producto que sirva de canal de comunicación
de torneos, categorías por edad y comunicados, administrado de forma
autogestionada (webmaster) por el director de cada escuela deportiva.

Sitios de referencia (no accesibles desde este entorno por restricción de
red saliente; el esquema se basa en patrones estándar del sector):

- https://clubcaterpillarmotor.com/inicio/
- https://www.sierrafc.com.co/
- https://fortalezaceif.com.co/

## Definición confirmada

- **Alcance:** producto multi-escuela (multi-tenant) — no un sitio único.
- **Pagos:** inscripciones/mensualidades cobradas en línea con pasarela de pago.
- **Área privada:** login para padres/deportistas, contenido filtrado por su categoría.
- **Presupuesto:** inversión de producto, no de sitio institucional.

## Esquema de contenido

| Módulo | Tipo | Descripción |
|---|---|---|
| Inicio | Institucional | Feed de lo más reciente: próximo torneo, último comunicado, resultado destacado |
| La escuela | Institucional | Historia, cuerpo técnico, sedes y horarios |
| Categorías por edad | Núcleo | Una página por categoría (sub-8, sub-10... mayores): horario, entrenador, cupos, muro propio |
| Torneos y calendario | Núcleo | Fixture, resultados, tabla de posiciones, filtrable por categoría |
| Comunicados | Núcleo | Circulares del director con fecha, categoría destinataria y estado "nuevo" |
| Inscripciones y pagos | Núcleo | Matrícula/mensualidad con pasarela de pago, historial visible para padre y director |
| Cuenta de padres | Núcleo | Login: contenido de su categoría, historial de pagos, comunicados dirigidos |
| Galería | Comunidad | Fotos/video por torneo o categoría |
| Contacto | Comunidad | WhatsApp, mapa de sedes, formulario para prospectos |
| Panel del director | Backend | Formularios para publicar comunicados, resultados, categorías y fotos de su escuela |
| Panel de plataforma | Backend | Administración de todos los tenants: altas de escuelas, planes, facturación, soporte |

## Comparativa tecnológica

Con multi-tenant + pagos + roles, WordPress y las opciones no-code quedan
descartadas: ninguna modela bien "un tenant aislado por escuela" ni pagos
con conciliación real.

| Opción | Multi-tenant | Pagos + roles | Costo inicial | Cuándo usarla |
|---|---|---|---|---|
| **A medida (recomendado)** | Nativo, un `tenant_id` por escuela | Control total: roles propios, webhooks de pago | Medio-alto | Producto que se va a vender/operar a varias escuelas |
| CMS headless (Directus/Strapi) + frontend propio | Posible, pero el aislamiento hay que modelarlo igual | Requiere integración externa | Medio | Panel ya hecho aceptando menos control sobre pagos |
| WordPress Multisite + WooCommerce | Forzado, no diseñado para esto | WooCommerce cubre pagos, roles frágiles | Bajo | Solo como prueba de concepto muy rápida |

## Stack recomendado

- **Frontend + paneles:** Next.js (App Router) — sitio público, panel del director, panel de plataforma
- **Base de datos:** Postgres (Neon/Supabase) + Prisma, aislamiento por `tenant_id`
- **Autenticación:** Auth.js o Clerk, con roles `plataforma` / `director` / `entrenador` / `padre`
- **Pagos:** pasarela local (Wompi o ePayco para Colombia — PSE, tarjeta, Nequi) con webhooks de conciliación
- **Hosting:** Vercel (frontend/API) + Neon/Supabase (DB) + Cloudflare R2 o S3 (media)

Cada escuela es un tenant con su propio subdominio (`caterpillar.tuplataforma.com`),
sus categorías, torneos, comunicados y pagos, sin visibilidad cruzada entre
escuelas.

## Plan de trabajo

1. **Definición** — cerrar preguntas abiertas (país de operación, modelo de negocio, escuelas piloto, dominio por escuela, notificaciones)
2. **Esquema de contenido y wireframes** — categorías reales, plantilla de comunicado, plantilla de torneo, boceto de ambos paneles
3. **Construcción del MVP** — sitio público + panel director con comunicados, categorías y torneos
4. **Piloto con contenido real** — un director carga un torneo y dos comunicados reales antes del lanzamiento
5. **Lanzamiento y ajuste** — dominio, capacitación al director, ronda de ajustes tras la primera semana

## Preguntas abiertas

1. ~~¿País(es) de operación?~~ **Confirmado: Colombia** — pasarela de pago local (Wompi/ePayco: PSE, tarjeta, Nequi), montos en COP.
2. ¿Modelo de negocio con las escuelas? Suscripción fija, comisión por pago procesado, o ambas.
3. ¿Cuántas escuelas entran en el piloto y cuándo? (candidatas: Caterpillar, Sierra FC, Fortaleza CEIF)
4. ¿Dominio propio por escuela o subdominio compartido de la plataforma?
5. ¿Notificaciones más allá del sitio (WhatsApp/email) al publicar un comunicado?
6. ¿Quién construye esto — desarrollo en este repositorio, o esta nota es brief para un equipo externo?

---

Documento visual equivalente (con comparativas y esquema en formato navegable):
https://claude.ai/code/artifact/a20c5215-cd76-4382-99c1-d339aa27691c

Mockup navegable de la propuesta (sitio público, panel del director y portal
de padres, con las tres escuelas de referencia): [`mockup.html`](./mockup.html)
— también publicado en
https://claude.ai/code/artifact/9993fc45-3053-4257-b491-415816390fe5
