# Guía de publicación en Donweb / Ferozo (Windows Hosting)

Checklist para cuando contrates el plan Windows Hosting. Vas a necesitar hacerlo una vez que
tengas `src/CostAllocation.Web` compilando y probado localmente (ver su `README.md`).

## 1. Antes de contratar: la pregunta clave

Escribile a soporte de Donweb/Ferozo (chat o ticket) esta pregunta puntual, **antes de pagar el
plan** si podés, o apenas lo actives:

> "¿El plan Windows Hosting tiene instalado el ASP.NET Core Hosting Bundle (módulo ANCM) para
> IIS? Necesito correr una aplicación ASP.NET Core 8, no una clásica de .NET Framework."

Por qué importa: su material comercial dice "ASP.NET" sin aclarar si es el .NET Framework
clásico (Web Forms/MVC5, no sirve para este proyecto) o si el servidor tiene el componente que
permite correr .NET 8/9 sobre IIS. Si la respuesta es "no lo tenemos", avisame y adaptamos el
proyecto a ASP.NET MVC 5 + Entity Framework 6 (corre en cualquier IIS sin nada adicional, pero
es una versión más vieja del framework).

## 2. Contratar y activar

1. Contratá el plan **Windows Hosting** (panel Ferozo).
2. Desde el panel, creá:
   - Una base de datos **SQL Server** (anotá: servidor, nombre de base, usuario, contraseña).
   - Un sitio/aplicación apuntando al dominio o subdominio que vayas a usar.
3. Pedile a soporte que confirme el ANCM (paso 1) si no te respondieron antes de pagar.

## 3. Cargar el esquema de base de datos

Con las credenciales SQL Server que te dio el panel, conectate con **SQL Server Management
Studio** (SSMS, gratis) o Azure Data Studio y ejecutá el contenido completo de
`database/schema.sql` contra esa base — te crea las tablas y carga los catálogos base.

## 4. Publicar el proyecto (desde tu PC)

Desde la carpeta `src/CostAllocation.Web`:

```powershell
dotnet publish -c Release -o ./publish
```

Esto genera en `./publish` todo lo necesario para correr en el servidor: los `.dll` compilados,
`web.config` (lo genera automático el SDK, configura el módulo ANCM), y los archivos estáticos
de `wwwroot`.

## 5. Configurar la cadena de conexión de producción

**No** subas tu `appsettings.Development.json` (tiene tus credenciales locales, y además está en
`.gitignore`). En el servidor hay dos formas de setear la cadena de conexión real:

- **Opción simple**: editar `publish/appsettings.json` antes de subirlo, reemplazando los
  placeholders por los datos reales de SQL Server que te dio el panel de Ferozo.
- **Opción más segura**: configurar la variable de entorno
  `ConnectionStrings__Default` en el panel de la aplicación (si Ferozo lo permite para sitios
  .NET) en vez de dejarla escrita en un archivo.

## 6. Subir los archivos

Vía FTP (los datos están en el panel de Ferozo) o el Administrador de archivos del panel:
subí **todo el contenido** de la carpeta `publish/` a la carpeta raíz del sitio (normalmente
algo como `/httpdocs` o la que te indique el panel para esa aplicación).

## 7. Probar

Entrá a tu dominio. Si todo está bien:

1. Andá a `/Setup` y creá el primer usuario administrador.
2. Iniciá sesión en `/Login` y probá crear una agrupación y una unidad.

## 8. Si algo falla

- **Error 500 sin detalle**: es normal que producción no muestre el detalle del error (por
  seguridad). Revisá los logs desde el panel de Ferozo (sección de logs de la aplicación IIS) o
  temporalmente forzá `ASPNETCORE_ENVIRONMENT=Development` como variable de entorno del sitio
  para ver el detalle completo — **sacala después**, no dejarla así en producción.
- **"No se pudo cargar el módulo ANCM" o el sitio no arranca**: confirma que el plan no tiene el
  ASP.NET Core Hosting Bundle instalado (volvé al punto 1).
- **Error de conexión a SQL Server**: revisá que el usuario/contraseña de la cadena de conexión
  sean los del panel (no los tuyos locales), y que el firewall de la base permita conexiones
  desde el propio servidor de la aplicación (en shared hosting normalmente no hace falta tocar
  nada, pero puede variar).
