# Arquitectura — Sistema de Prorrateo y Distribución de Costos (Vertical: Propiedad Horizontal)

## 1. Contexto

Sistema genérico de prorrateo de gastos (fijos y variables) entre N unidades pertenecientes a
una agrupación, con manejo de ingresos extraordinarios separados del fondo común. La primera
vertical a construir es **Propiedad Horizontal / Real Estate**: condominios residenciales,
centros comerciales, coworkings y parques industriales. El modelo de datos usa nombres
genéricos (`agrupaciones`, `unidades`, `gastos`, `conceptos_gasto`) para poder reutilizar el
mismo backend en otras verticales (FinOps, logística, agro, shared services) cambiando solo la
capa de presentación.

## 2. Infraestructura elegida: Windows Hosting (Ferozo / Donweb)

Plan: **Windows Hosting** (panel Ferozo), desde ~AR$3.700/mes. Incluye:

- IIS sobre Windows Server 2025.
- ASP, ASP.NET, PHP 8.3.
- Bases de datos SQL Server y MySQL 8.0.

> ⚠️ **Punto a confirmar con soporte de Ferozo/Donweb antes de programar**: su material comercial
> dice "ASP.NET" sin especificar si el servidor tiene instalado el *ASP.NET Core Hosting Bundle*
> (módulo `ANCM` necesario para correr .NET 8/9, no solo el .NET Framework clásico). Si el plan
> solo trae .NET Framework, hay que bajar el diseño a ASP.NET MVC 5 + Entity Framework 6 (más
> viejo, pero corre en cualquier IIS sin instalar nada extra). El diseño de abajo asume que sí
> soportan **ASP.NET Core** (lo más probable dado que el plan ya corre Windows Server 2025), pero
> es la primera pregunta a hacerle a soporte antes de escribir código.

## 3. Por qué .NET no resuelve "ocultar código" distinto a PHP — y qué sí resuelve

Ningún lenguaje de servidor (PHP, C#, Java, Node) expone su código fuente al cliente: el
navegador solo recibe la salida (HTML/JSON), nunca el `.cs` ni el `.php`. Eso ya estaba
garantizado con la propuesta anterior en PHP. Lo que sí cambia con .NET es que **Blazor Server**
permite que incluso la lógica *interactiva* de una pantalla (qué pasa cuando arrastras un
componente, qué se habilita/deshabilita) se ejecute enteramente en el servidor: el navegador solo
recibe actualizaciones de DOM vía WebSocket (SignalR), sin descargar un bundle de JavaScript con
esa lógica de aplicación. Es la opción que más se acerca a tu objetivo original, así que la uso
puntualmente para la pantalla que más lo necesita: el **builder visual**.

No la uso para toda la aplicación porque cada usuario con una pantalla Blazor Server abierta
mantiene un "circuito" (estado + conexión WebSocket) vivo en el servidor — en hosting compartido
de recursos limitados eso no escala para cientos de propietarios consultando su estado de cuenta
a la vez. Para el resto del sistema (CRUD, reportes, portal del propietario) uso el patrón
tradicional request/response, mucho más liviano en memoria del servidor.

## 4. Stack

| Capa | Elección | Motivo |
|---|---|---|
| Backend | **ASP.NET Core 8 (LTS)** — Razor Pages/MVC para el grueso de la app | Corre sobre IIS vía el módulo ANCM, DI nativa, tooling maduro (Visual Studio/Rider). |
| Pantalla del builder visual | **Blazor Server** (aislado, solo esa ruta) | Interactividad rica (drag & drop) sin exponer lógica de UI como JS descargable; ver sección 3. |
| ORM | **Entity Framework Core 8** | Equivalente a Eloquent: migraciones versionadas, LINQ, Global Query Filters para multi-tenancy. |
| Base de datos | **SQL Server** (incluida en el plan Windows) | Integración nativa con EF Core, mejor tooling (SSMS), transacciones — necesario para un sistema financiero. |
| Autenticación / roles | **ASP.NET Core Identity** + roles propios (Admin Plataforma, Admin Agrupación, Propietario, Contador) | Estándar de la plataforma, evita reinventar hashing/tokens. |
| Mediador de eventos de dominio | **MediatR** | `INotification` + handlers, equivalente a Events/Listeners de Laravel. |
| Tareas programadas | **IHostedService** (`BackgroundService`) con temporizador, o Windows Task Scheduler llamando a un endpoint protegido | No hay Redis/queue worker disponible en hosting compartido; se simula con polling liviano. |

## 5. Patrón de diseño

**Monolito modular** (no microservicios: no se justifica el sobrecosto de infraestructura a este
volumen de datos/tráfico). Dentro del monolito:

### 5.1 Multi-tenancy: base de datos compartida, esquema compartido
Una sola base SQL Server, todas las tablas de negocio llevan `AgrupacionId`. Se implementa con
**Global Query Filters** de EF Core:

```csharp
modelBuilder.Entity<Unidad>()
    .HasQueryFilter(u => u.AgrupacionId == _tenantContext.AgrupacionId);
```

Cada consulta LINQ queda automáticamente filtrada por el tenant del usuario autenticado, sin
tener que recordarlo en cada repositorio. Es la opción más barata: el hosting compartido no
permite crear una base de datos por cliente sin costo adicional. Si el producto crece, se puede
migrar por fases a esquema-por-tenant o BD-por-tenant en un plan Cloud de Donweb.

### 5.2 Motor de prorrateo: Strategy Pattern + Inyección de Dependencias
Es la pieza más reutilizable entre verticales:

```csharp
public interface IMetodoProrrateo
{
    string Codigo { get; } // COEFICIENTE, PARTES_IGUALES, AREA, CONSUMO, DIRECTO
    IReadOnlyList<ProrrateoResultado> Calcular(Gasto gasto, IReadOnlyList<Unidad> unidades);
}

// Program.cs
builder.Services.AddKeyedScoped<IMetodoProrrateo, PorCoeficienteStrategy>("COEFICIENTE");
builder.Services.AddKeyedScoped<IMetodoProrrateo, PorAreaStrategy>("AREA");
// ...
```

El `ConceptoGasto` define el método por defecto; el `Gasto` puede sobreescribirlo. Cambiar de
vertical (ej. un centro comercial que prorratea por m²) es simplemente registrar/elegir otra
estrategia, sin tocar el resto del sistema.

### 5.3 Eventos de dominio (MediatR)
Desacopla la escritura de la propagación de efectos:
- `GastoProrrateadoEvent` → handler crea `CargoDetalle` en cada unidad afectada.
- `PagoRegistradoEvent` → handler aplica el pago a `Cargos` pendientes (FIFO) y escribe en
  `MovimientosFondo`.
- `PeriodoCerradoEvent` → handler calcula intereses de mora y genera el `Cargo` del siguiente
  periodo con el saldo anterior.

### 5.4 Repository / Service Layer (ligero)
Los controladores/Razor Pages no hablan directo con `DbContext` para las reglas de negocio: usan
servicios (`ProrrateoService`, `PagoService`) inyectados por DI. Esto permite testear el cálculo
de prorrateo con datos en memoria (xUnit + una lista de `Unidad` falsa), sin levantar SQL Server.

### 5.5 Auditoría inmutable, no recálculo
`GastoProrrateo` guarda el resultado congelado de cada distribución (monto, coeficiente aplicado,
base de cálculo). Nunca se recalcula "en caliente" para mostrar un histórico: se recalcula solo
si el gasto se anula/reversa explícitamente y se genera un nuevo registro. Crítico en un sistema
financiero para auditar "qué se cobró y por qué" en cualquier fecha pasada, aunque luego cambien
los coeficientes de las unidades.

## 6. El builder visual (Blazor Server)

Pantalla aislada, montada como un único componente Blazor dentro de la app Razor/MVC (patrón
"isla interactiva" — el resto del sitio sigue siendo request/response clásico).

- **Paleta izquierda**: tarjetas arrastrables por tipo de componente — `Unidad`, `Concepto de
  Gasto`, `Método de Prorrateo`, `Coeficiente`, `Persona/Rol`, `Cuenta/Fondo`.
- **Lienzo central**: árbol/organigrama (no un lienzo de posición libre tipo constructor de
  páginas) que refleja la jerarquía real del modelo: `Agrupación → Unidades → (Conceptos,
  Coeficientes)`. Arrastrar un componente lo ancla en el nodo padre válido; el árbol impide
  construir una estructura de datos inconsistente con el esquema relacional.
- **Panel derecho (propiedades)**: al seleccionar un nodo, un formulario dinámico muestra todo lo
  que no se arrastra — nombre, área, coeficiente, tasa de interés, método por defecto, etc.
  Generado a partir del mismo esquema que ya está en `database/schema.sql`.
- **Drag & drop**: eventos nativos HTML5 (`draggable`, `ondragstart`, `ondrop`) manejados por
  event handlers de Blazor (`@ondrop`) — sin librería de JavaScript externa; toda la decisión de
  "¿este drop es válido?" ocurre en C# en el servidor.
- **Persistencia**: cada arrastre o edición dispara una llamada al `ProrrateoConfigService` que
  crea/actualiza directamente filas en `Agrupaciones`, `Unidades`, `UnidadCoeficientes`,
  `ConceptosGasto` — nada de un "blob JSON de layout" como en los constructores de páginas
  genéricos (GrapesJS, Craft.js); los datos quedan íntegros con sus foreign keys.

Ver mockup interactivo del diseño (enviado como artefacto aparte).

## 7. Resumen de justificación

| Decisión | Alternativa descartada | Por qué se descarta |
|---|---|---|
| ASP.NET Core + SQL Server | Node/NestJS + Postgres | Requeriría VPS, no corre en el plan Windows Hosting elegido |
| Blazor Server solo en el builder | Blazor Server en toda la app | Cada usuario mantiene un circuito vivo en el servidor; no escala en hosting compartido para cientos de propietarios |
| BD compartida (1 esquema, `AgrupacionId`) | BD por tenant | El plan no permite crear una base de datos por cliente sin costo adicional |
| Monolito modular | Microservicios | Sobrecosto de infraestructura/operación sin beneficio a este volumen |
| `BackgroundService` / Task Scheduler | Redis + Hangfire/Supervisor | No disponible en hosting compartido |
| Prorrateo congelado (tabla) | Recalcular on-the-fly siempre | Rompe auditoría histórica si cambian los coeficientes |
