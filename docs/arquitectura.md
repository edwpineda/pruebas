# Arquitectura — Sistema de Prorrateo y Distribución de Costos (Vertical: Propiedad Horizontal)

## 1. Contexto

Sistema genérico de prorrateo de gastos (fijos y variables) entre N unidades pertenecientes a
una agrupación, con manejo de ingresos extraordinarios separados del fondo común. La primera
vertical a construir es **Propiedad Horizontal / Real Estate**: condominios residenciales,
centros comerciales, coworkings y parques industriales. El modelo de datos usa nombres
genéricos (`agrupaciones`, `unidades`, `gastos`, `conceptos_gasto`) para poder reutilizar el
mismo backend en otras verticales (FinOps, logística, agro, shared services) cambiando solo la
capa de presentación.

## 2. Restricción de infraestructura

Objetivo: bajo costo, desplegable en hosting compartido cPanel tipo Donweb (planes desde
~US$2-4/mes). Estos planes ofrecen:

- PHP (versión actualizada) + MySQL/MariaDB vía cPanel.
- Acceso SSH y Composer en la mayoría de los planes (verificar en el plan contratado).
- **Sin** proceso Node.js persistente, sin colas con Redis/Supervisor, sin Docker.
- Cron jobs disponibles (para `schedule:run` de Laravel).

Esto descarta stacks que requieran un servidor de aplicación propio (Node/Express, Python/Django
con Gunicorn, etc.) salvo que se pague un VPS/Cloud de Donweb (más caro). PHP + MySQL es la
única combinación que corre "gratis" dentro de un hosting compartido económico.

## 3. Stack recomendado

| Capa | Elección | Motivo |
|---|---|---|
| Backend | **PHP 8.3 + Laravel 11/12** | Framework maduro, Eloquent ORM, migraciones versionadas, ecosistema de paquetes (Spatie permissions, multi-tenancy), se ejecuta en cualquier cPanel con Composer. |
| Base de datos | **MySQL 8 / MariaDB 10.x (InnoDB, utf8mb4)** | Es lo que ofrece Donweb en shared hosting; soporta FKs, JSON, transacciones — necesario para un sistema financiero. |
| Frontend | **Blade + Livewire + Alpine.js** (o Blade + Vue/React compilado con Vite) | Livewire evita construir una API+SPA separada (menos infraestructura). El build de Vite se genera en CI/local y solo se sube el `public/build` ya compilado — el servidor **no** necesita Node corriendo. |
| Colas / tareas programadas | Driver `database` de Laravel + 1 cron (`* * * * * php artisan schedule:run`) | No requiere Redis ni Supervisor, compatible con cPanel Cron Jobs. |
| Autenticación / roles | Laravel Breeze/Fortify + `spatie/laravel-permission` | RBAC estándar: admin de plataforma, admin de agrupación, propietario, contador. |

Alternativa aún más económica (si el plan no permite Composer/SSH): PHP plano con un micro-router
(Slim/Bramus) — se pierde productividad y mantenibilidad, no se recomienda salvo restricción dura.

## 4. Patrón de diseño

**Monolito modular** (no microservicios: el volumen de datos y tráfico de este dominio no lo
justifica, y microservicios elevan el costo de hosting). Dentro del monolito:

### 4.1 Multi-tenancy: base de datos compartida, esquema compartido
Una sola base de datos MySQL, todas las tablas de negocio llevan `agrupacion_id`. Se implementa
un **Global Scope** de Eloquent (`AgrupacionScope`) que filtra automáticamente cada query por el
tenant del usuario autenticado, evitando fugas de datos entre agrupaciones sin tener que
recordarlo en cada consulta. Es la opción de multi-tenancy más barata: cPanel shared plans casi
siempre limitan la cantidad de bases de datos que se pueden crear, así que "una BD por cliente"
no es viable en el plan económico. Si el producto crece, se puede migrar por fases a
esquema-por-tenant o BD-por-tenant en un plan Cloud/VPS de Donweb.

### 4.2 Motor de prorrateo: Strategy Pattern
Es la pieza más reutilizable entre verticales. Una interfaz común:

```php
interface MetodoProrrateoInterface
{
    /** @return array<int, array{unidad_id:int, monto:float, base_calculo:?float}> */
    public function calcular(Gasto $gasto, Collection $unidades): array;
}
```

Implementaciones: `PorCoeficiente`, `PorPartesIguales`, `PorArea`, `PorConsumo`, `Directo`
(asignado a una sola unidad). El `ConceptoGasto` define el método por defecto; el `Gasto`
puede sobreescribirlo puntualmente. Cambiar de vertical (ej. centro comercial que prorratea por
m²) es simplemente elegir otra estrategia, sin tocar el resto del sistema.

### 4.3 Eventos de dominio (Observer/Event-driven)
Desacopla la escritura de la propagación de efectos:
- `GastoProrrateado` → listener crea `cargo_detalles` en cada unidad afectada.
- `PagoRegistrado` → listener aplica el pago a `cargos` pendientes (FIFO) y escribe en
  `movimientos_fondo`.
- `PeriodoCerrado` → listener calcula intereses de mora y genera el `cargo` del siguiente
  periodo con el saldo anterior.

### 4.4 Repository / Service Layer (ligero)
Los controladores no hablan directo con Eloquent para las reglas de negocio: usan servicios
(`ProrrateoService`, `PagoService`) que sí pueden usar Eloquent internamente. Esto permite testear
el cálculo de prorrateo con datos en memoria, sin levantar la base de datos completa.

### 4.5 Auditoría inmutable, no recálculo
`gasto_prorrateos` guarda el resultado congelado de cada distribución (monto, coeficiente
aplicado, base de cálculo). Nunca se recalcula "en caliente" para mostrar un histórico: se
recalcula solo si el gasto se anula/reversa explícitamente y se genera un nuevo registro. Esto es
crítico en un sistema financiero para poder auditar "qué se cobró y por qué" en cualquier fecha
pasada, incluso si luego cambian los coeficientes de las unidades.

## 5. Resumen de justificación

| Decisión | Alternativa descartada | Por qué se descarta |
|---|---|---|
| Laravel/PHP+MySQL | Node/NestJS + Postgres | Requeriría VPS, no corre en shared hosting barato |
| BD compartida (1 esquema) | BD por tenant | cPanel shared limita # de bases de datos |
| Monolito modular | Microservicios | Sobrecosto de infra/operación sin beneficio a este volumen |
| Cola `database` + cron | Redis + Supervisor/Horizon | No disponible en shared hosting económico |
| Prorrateo congelado (tabla) | Recalcular on-the-fly siempre | Rompe auditoría histórica si cambian coeficientes |
