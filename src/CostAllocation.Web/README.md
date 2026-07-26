# CostAllocation.Web — MVP (Login + Agrupaciones + Unidades)

Primera porción funcional de punta a punta del sistema de prorrateo, para validar el stack
completo (ASP.NET Core + EF Core + SQL Server) antes de construir el resto de las pantallas
del diseño (`docs/arquitectura.md`, `docs/erd.md`, mockup del builder visual).

No usa migraciones de EF Core: la fuente de verdad del esquema es `database/schema.sql`. El
`DbContext` (`Data/AppDbContext.cs`) mapea explícitamente a esas tablas ya existentes.

> **Nota sobre la versión de .NET**: el proyecto apunta a `net10.0` (la versión actual). Todavía
> no confirmamos si el Windows Hosting de Donweb/Ferozo tiene el Hosting Bundle de .NET 10
> instalado (es muy reciente) — ver `docs/despliegue-donweb.md`, sección 1. Si al momento de
> publicar resulta que el hosting solo soporta .NET 8 (LTS), retroceder es un cambio de una sola
> línea: `<TargetFramework>` en `CostAllocation.Web.csproj`, de `net10.0` a `net8.0`.

## 1. Revisar si tenés lo necesario en tu PC

Abrí una terminal (PowerShell en Windows) y corré:

```powershell
dotnet --version
```

- Si te devuelve un número de versión (ej. `10.0.xxx`) → ya tenés el SDK, pasá al paso 2.
- Si dice "no se reconoce el comando" o similar → no lo tenés instalado. Instalá el **SDK de
  .NET** desde https://dotnet.microsoft.com/download (no alcanza con el "Runtime", necesitás
  el "SDK" para poder compilar). En Windows, instalar **Visual Studio Community** (gratis) desde
  https://visualstudio.microsoft.com/ con la carga de trabajo "Desarrollo de ASP.NET y web" te
  instala el SDK automáticamente y te da un editor con debugger — es el camino más cómodo si no
  programás en .NET habitualmente.

También necesitás un SQL Server para probar localmente. La opción más simple en Windows es
**SQL Server LocalDB**, que se instala solo con Visual Studio (workload "Almacenamiento y
procesamiento de datos"). Alternativa: SQL Server Express, gratis, desde el sitio de Microsoft.

## 2. Preparar la base de datos local

1. Creá una base vacía (con SSMS, Azure Data Studio, o `sqlcmd`).
2. Ejecutá el contenido completo de `database/schema.sql` contra esa base — crea las tablas y
   carga los catálogos (`TiposAgrupacion`, `MetodosProrrateo`, `Roles`).

## 3. Configurar la cadena de conexión

Editá `appsettings.json` (o mejor, creá un `appsettings.Development.json` — está en
`.gitignore`, así no subís credenciales) con tu cadena real, por ejemplo para LocalDB:

```json
{
  "ConnectionStrings": {
    "Default": "Server=(localdb)\\mssqllocaldb;Database=CostAllocation;Trusted_Connection=True;TrustServerCertificate=True"
  }
}
```

## 4. Correr el proyecto

Desde la carpeta `src/CostAllocation.Web`:

```powershell
dotnet restore
dotnet run
```

Te va a mostrar una URL tipo `https://localhost:5001`. Abrila en el navegador:

1. Como todavía no hay usuarios, te va a convenir ir directo a `/Setup` para crear el primer
   administrador (correo + contraseña).
2. Iniciá sesión en `/Login`.
3. Te lleva a **Agrupaciones** — creá una, entrá a "Unidades" y cargá algunas.
4. Desde la fila de la agrupación, entrá a **Servicios** para configurar servicios opcionales
   (TV, comida, hospedaje, etc.) que la agrupación ofrece a sus unidades:
   - **Configurar**: builder drag & drop (Blazor Server, isla interactiva embebida en la Razor
     Page) con columnas por plan — arrastrá la columna completa por el ícono ⠿ del encabezado
     para reordenar planes, y arrastrá las tarjetas de características (⠿) para reordenarlas o
     moverlas a otro plan. Cada plan (salvo el primero) tiene un checkbox "Incluye lo de
     `<plan anterior>`" que hereda en cascada sus características. Todo se persiste de
     inmediato contra la base de datos.
   - **Vista pública**: la página que vería un propietario, con un botón **Pagar/Suscribirme**
     por plan. Es de acceso público (sin `[Authorize]`), pero pagar exige sesión iniciada: si no
     hay sesión, redirige a `/Login` y vuelve automáticamente a esta página al autenticarse
     (`ReturnUrl`). Al suscribirse se crea un registro en `UnidadServicioPlanes`.

## 5. Qué falta (fuera del alcance de este MVP)

Esto es la porción mínima para validar el pipeline completo. Lo que sigue el diseño pero
todavía no está construido: Conceptos de gasto, Gastos, el motor de prorrateo (Strategy),
Cargos/Pagos, y el resto de los roles/permisos. La suscripción de una Unidad a un
`ServicioPlan` (sección 4, punto 4) todavía no se refleja como cargo real: falta el paso que
la convierta en un `CargoDetalle` del período — se agrega junto con el resto del motor de
Cargos/Pagos, ya con el pipeline de publicación probado.
