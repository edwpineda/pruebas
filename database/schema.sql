-- ============================================================================
-- Modelo de datos: Sistema de prorrateo y distribución de costos
-- Vertical inicial: Propiedad Horizontal / Real Estate
--   (condominios, centros comerciales, coworkings, parques industriales)
-- Motor: SQL Server (Windows Hosting Ferozo/Donweb) — compatible con EF Core 8
-- Multi-tenancy: base de datos compartida, discriminador AgrupacionId
-- ============================================================================
-- Nota: los updated_at automáticos se manejan en la capa de aplicación
-- (interceptor de SaveChanges en EF Core), no con triggers en SQL Server.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TENANT / AGRUPACIÓN (la entidad matriz)
-- ----------------------------------------------------------------------------

CREATE TABLE TiposAgrupacion (
    Id       INT IDENTITY(1,1) PRIMARY KEY,
    Codigo   NVARCHAR(40)  NOT NULL,   -- CONDOMINIO, CENTRO_COMERCIAL, COWORKING, PARQUE_INDUSTRIAL
    Nombre   NVARCHAR(100) NOT NULL,
    CONSTRAINT UQ_TiposAgrupacion_Codigo UNIQUE (Codigo)
);
GO

CREATE TABLE Agrupaciones (
    Id                   BIGINT IDENTITY(1,1) PRIMARY KEY,
    TipoAgrupacionId     INT NOT NULL,
    Nombre               NVARCHAR(150) NOT NULL,
    IdentificacionFiscal NVARCHAR(40)  NULL,
    Moneda               CHAR(3)       NOT NULL DEFAULT 'USD',
    Direccion            NVARCHAR(255) NULL,
    DiaCorteFacturacion  TINYINT       NOT NULL DEFAULT 1,   -- día del mes en que se cierra el periodo
    TasaInteresMora      DECIMAL(6,4)  NOT NULL DEFAULT 0,    -- % mensual
    Configuracion        NVARCHAR(MAX) NULL,                  -- settings flexibles por tenant (JSON)
    Activo               BIT           NOT NULL DEFAULT 1,
    CreatedAt            DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt            DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    DeletedAt            DATETIME2     NULL,
    CONSTRAINT FK_Agrupaciones_Tipo FOREIGN KEY (TipoAgrupacionId) REFERENCES TiposAgrupacion(Id),
    CONSTRAINT CK_Agrupaciones_Configuracion CHECK (Configuracion IS NULL OR ISJSON(Configuracion) = 1)
);
GO

-- ----------------------------------------------------------------------------
-- 2. UNIDADES (subentidades) y su coeficiente histórico
-- ----------------------------------------------------------------------------

CREATE TABLE Unidades (
    Id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId  BIGINT NOT NULL,
    Codigo        NVARCHAR(40) NOT NULL,             -- "Apto 501", "Local 12", "Oficina 3B"
    TipoUnidad    NVARCHAR(40) NOT NULL,              -- residencial, comercial, bodega, oficina, lote
    AreaM2        DECIMAL(10,2) NULL,
    Estado        NVARCHAR(20) NOT NULL DEFAULT 'activo',
    CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    DeletedAt     DATETIME2 NULL,
    CONSTRAINT FK_Unidades_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT UQ_Unidades_Codigo UNIQUE (AgrupacionId, Codigo),
    CONSTRAINT CK_Unidades_Estado CHECK (Estado IN ('activo','inactivo'))
);
GO

-- El coeficiente/alícuota puede cambiar en el tiempo (remodelaciones, subdivisiones).
-- Se historiza en vez de guardarlo como columna fija en Unidades.
CREATE TABLE UnidadCoeficientes (
    Id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    UnidadId      BIGINT NOT NULL,
    Coeficiente   DECIMAL(9,6) NOT NULL,          -- ej. 0.008345 (participación sobre el total)
    VigenteDesde  DATE NOT NULL,
    VigenteHasta  DATE NULL,                      -- NULL = vigente actualmente
    CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Coef_Unidad FOREIGN KEY (UnidadId) REFERENCES Unidades(Id)
);
GO
CREATE INDEX IX_UnidadCoeficientes_Vigencia ON UnidadCoeficientes (UnidadId, VigenteDesde, VigenteHasta);
GO

-- ----------------------------------------------------------------------------
-- 2B. SERVICIOS OPCIONALES Y PLANES (ofrecidos por la Agrupación a sus Unidades)
-- ----------------------------------------------------------------------------
-- Ej: una Agrupación (condominio) ofrece TV por cable, servicio de comida u hospedaje
-- como servicios adicionales pagos, cada uno con N planes (Básico/Estándar/Premium).
-- Un plan superior puede heredar en cascada las características del plan con el Orden
-- inmediato anterior (HeredaDeInferior), además de sumar las propias.

CREATE TABLE Servicios (
    Id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId  BIGINT NOT NULL,
    Nombre        NVARCHAR(100) NOT NULL,     -- "TV por cable", "Servicio de comida", "Hospedaje"
    Icono         NVARCHAR(20) NULL,          -- emoji identificador, ej. "📺"
    Orden         INT NOT NULL DEFAULT 0,
    Activo        BIT NOT NULL DEFAULT 1,
    CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Servicios_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT UQ_Servicios_Nombre UNIQUE (AgrupacionId, Nombre)
);
GO

CREATE TABLE ServicioPlanes (
    Id                BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServicioId        BIGINT NOT NULL,
    Nombre            NVARCHAR(80) NOT NULL,      -- "Básico", "Estándar", "Premium"
    Precio            DECIMAL(14,2) NOT NULL DEFAULT 0,
    HeredaDeInferior  BIT NOT NULL DEFAULT 0,      -- incluye las características del plan con Orden-1
    Orden             INT NOT NULL DEFAULT 0,      -- jerarquía: 0 = plan más bajo
    CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ServicioPlanes_Servicio FOREIGN KEY (ServicioId) REFERENCES Servicios(Id)
);
GO
CREATE INDEX IX_ServicioPlanes_Servicio_Orden ON ServicioPlanes (ServicioId, Orden);
GO

CREATE TABLE ServicioPlanCaracteristicas (
    Id       BIGINT IDENTITY(1,1) PRIMARY KEY,
    PlanId   BIGINT NOT NULL,
    Texto    NVARCHAR(200) NOT NULL,
    Orden    INT NOT NULL DEFAULT 0,
    CONSTRAINT FK_SPC_Plan FOREIGN KEY (PlanId) REFERENCES ServicioPlanes(Id)
);
GO
CREATE INDEX IX_SPC_Plan_Orden ON ServicioPlanCaracteristicas (PlanId, Orden);
GO

-- Suscripción de una Unidad a un plan de servicio opcional. El cobro real se integra al
-- ciclo de Cargos (sección 7) cuando se genere el Cargo del periodo; todavía no está
-- automatizado (ver "Qué falta" en el README del proyecto).
CREATE TABLE UnidadServicioPlanes (
    Id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    UnidadId      BIGINT NOT NULL,
    PlanId        BIGINT NOT NULL,
    FechaDesde    DATE NOT NULL,
    FechaHasta    DATE NULL,             -- NULL = suscripción activa
    CONSTRAINT FK_USP_Unidad FOREIGN KEY (UnidadId) REFERENCES Unidades(Id),
    CONSTRAINT FK_USP_Plan FOREIGN KEY (PlanId) REFERENCES ServicioPlanes(Id)
);
GO
CREATE INDEX IX_USP_Unidad_Vigencia ON UnidadServicioPlanes (UnidadId, FechaDesde, FechaHasta);
GO

-- ----------------------------------------------------------------------------
-- 3. PERSONAS / TERCEROS
-- ----------------------------------------------------------------------------

CREATE TABLE Personas (
    Id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    TipoDocumento    NVARCHAR(10)  NULL,
    NumeroDocumento  NVARCHAR(40)  NULL,
    Nombre           NVARCHAR(150) NOT NULL,
    Email            NVARCHAR(150) NULL,
    Telefono         NVARCHAR(40)  NULL,
    CreatedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Personas_Doc UNIQUE (TipoDocumento, NumeroDocumento)
);
GO

-- Relación N:M entre unidades y personas, con rol e histórico (propietario cambia, arrendatario cambia)
CREATE TABLE UnidadPersona (
    Id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    UnidadId         BIGINT NOT NULL,
    PersonaId        BIGINT NOT NULL,
    Rol              NVARCHAR(20) NOT NULL,
    ResponsablePago  BIT NOT NULL DEFAULT 1,
    FechaDesde       DATE NOT NULL,
    FechaHasta       DATE NULL,
    CONSTRAINT FK_UP_Unidad FOREIGN KEY (UnidadId) REFERENCES Unidades(Id),
    CONSTRAINT FK_UP_Persona FOREIGN KEY (PersonaId) REFERENCES Personas(Id),
    CONSTRAINT CK_UP_Rol CHECK (Rol IN ('propietario','arrendatario','autorizado'))
);
GO
CREATE INDEX IX_UnidadPersona_Vigencia ON UnidadPersona (UnidadId, Rol, FechaDesde, FechaHasta);
GO

-- Usuarios del sistema (login vía ASP.NET Core Identity), separados de "Personas" del negocio
CREATE TABLE Roles (
    Id      INT IDENTITY(1,1) PRIMARY KEY,
    Codigo  NVARCHAR(40)  NOT NULL,   -- ADMIN_PLATAFORMA, ADMIN_AGRUPACION, PROPIETARIO, CONTADOR
    Nombre  NVARCHAR(100) NOT NULL,
    CONSTRAINT UQ_Roles_Codigo UNIQUE (Codigo)
);
GO

CREATE TABLE Usuarios (
    Id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId   BIGINT NULL,          -- NULL = usuario de plataforma (soporte/super-admin)
    PersonaId      BIGINT NULL,
    RolId          INT NOT NULL,
    Email          NVARCHAR(150) NOT NULL,
    PasswordHash   NVARCHAR(255) NOT NULL,
    Activo         BIT NOT NULL DEFAULT 1,
    CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Usuarios_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT FK_Usuarios_Persona FOREIGN KEY (PersonaId) REFERENCES Personas(Id),
    CONSTRAINT FK_Usuarios_Rol FOREIGN KEY (RolId) REFERENCES Roles(Id),
    CONSTRAINT UQ_Usuarios_Email UNIQUE (Email)
);
GO

-- ----------------------------------------------------------------------------
-- 4. CATÁLOGOS DE PRORRATEO Y GASTOS
-- ----------------------------------------------------------------------------

CREATE TABLE MetodosProrrateo (
    Id           INT IDENTITY(1,1) PRIMARY KEY,
    Codigo       NVARCHAR(30) NOT NULL,   -- COEFICIENTE, PARTES_IGUALES, AREA, CONSUMO, DIRECTO
    Nombre       NVARCHAR(100) NOT NULL,
    Descripcion  NVARCHAR(255) NULL,
    CONSTRAINT UQ_MetodosProrrateo_Codigo UNIQUE (Codigo)
);
GO

CREATE TABLE Proveedores (
    Id                   BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId         BIGINT NOT NULL,
    RazonSocial          NVARCHAR(150) NOT NULL,
    IdentificacionFiscal NVARCHAR(40) NULL,
    Categoria            NVARCHAR(60) NULL,          -- seguridad, aseo, mantenimiento, servicios_publicos
    Contacto             NVARCHAR(150) NULL,
    CONSTRAINT FK_Proveedores_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id)
);
GO

CREATE TABLE ConceptosGasto (
    Id                  BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId        BIGINT NOT NULL,
    Nombre              NVARCHAR(120) NOT NULL,     -- "Vigilancia", "Aseo zonas comunes", "Internet"
    Naturaleza          NVARCHAR(20) NOT NULL,       -- fijo, variable
    MetodoProrrateoId   INT NOT NULL,                -- método por defecto
    Activo              BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_Concepto_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT FK_Concepto_Metodo FOREIGN KEY (MetodoProrrateoId) REFERENCES MetodosProrrateo(Id),
    CONSTRAINT UQ_Concepto_Nombre UNIQUE (AgrupacionId, Nombre),
    CONSTRAINT CK_Concepto_Naturaleza CHECK (Naturaleza IN ('fijo','variable'))
);
GO

-- ----------------------------------------------------------------------------
-- 5. PERIODOS DE FACTURACIÓN
-- ----------------------------------------------------------------------------

CREATE TABLE Periodos (
    Id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId   BIGINT NOT NULL,
    Anio           SMALLINT NOT NULL,
    Mes            TINYINT NOT NULL,
    FechaInicio    DATE NOT NULL,
    FechaFin       DATE NOT NULL,
    Estado         NVARCHAR(20) NOT NULL DEFAULT 'abierto',
    FechaCierre    DATETIME2 NULL,
    CONSTRAINT FK_Periodo_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT UQ_Periodo UNIQUE (AgrupacionId, Anio, Mes),
    CONSTRAINT CK_Periodo_Estado CHECK (Estado IN ('abierto','cerrado'))
);
GO

-- ----------------------------------------------------------------------------
-- 6. GASTOS (Y) Y SU PRORRATEO
-- ----------------------------------------------------------------------------

CREATE TABLE Gastos (
    Id                  BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId        BIGINT NOT NULL,
    PeriodoId           BIGINT NOT NULL,
    ConceptoId          BIGINT NOT NULL,
    ProveedorId         BIGINT NULL,
    MetodoProrrateoId   INT NOT NULL,     -- puede sobreescribir el default del concepto
    Monto               DECIMAL(14,2) NOT NULL,
    FechaGasto          DATE NOT NULL,
    Descripcion         NVARCHAR(255) NULL,
    ComprobanteUrl      NVARCHAR(255) NULL,
    Estado              NVARCHAR(20) NOT NULL DEFAULT 'pendiente',
    CreatedAt           DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Gasto_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT FK_Gasto_Periodo FOREIGN KEY (PeriodoId) REFERENCES Periodos(Id),
    CONSTRAINT FK_Gasto_Concepto FOREIGN KEY (ConceptoId) REFERENCES ConceptosGasto(Id),
    CONSTRAINT FK_Gasto_Proveedor FOREIGN KEY (ProveedorId) REFERENCES Proveedores(Id),
    CONSTRAINT FK_Gasto_Metodo FOREIGN KEY (MetodoProrrateoId) REFERENCES MetodosProrrateo(Id),
    CONSTRAINT CK_Gasto_Estado CHECK (Estado IN ('pendiente','prorrateado','anulado'))
);
GO

-- Resultado congelado (auditoría) de distribuir un gasto entre unidades.
-- No se recalcula on-the-fly: es la fuente de verdad de "qué se le cobró a quién y por qué".
CREATE TABLE GastoProrrateos (
    Id                    BIGINT IDENTITY(1,1) PRIMARY KEY,
    GastoId               BIGINT NOT NULL,
    UnidadId              BIGINT NOT NULL,
    MontoAsignado         DECIMAL(14,2) NOT NULL,
    CoeficienteAplicado   DECIMAL(9,6) NULL,
    BaseCalculo           DECIMAL(14,4) NULL,        -- ej. m2 o unidades de consumo usadas en el cálculo
    CreatedAt             DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_GP_Gasto FOREIGN KEY (GastoId) REFERENCES Gastos(Id),
    CONSTRAINT FK_GP_Unidad FOREIGN KEY (UnidadId) REFERENCES Unidades(Id),
    CONSTRAINT UQ_Gasto_Unidad UNIQUE (GastoId, UnidadId)
);
GO

-- ----------------------------------------------------------------------------
-- 7. CARGOS (estado de cuenta por unidad y periodo) Y PAGOS
-- ----------------------------------------------------------------------------

CREATE TABLE Cargos (
    Id                BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId      BIGINT NOT NULL,
    UnidadId          BIGINT NOT NULL,
    PeriodoId         BIGINT NOT NULL,
    SaldoAnterior     DECIMAL(14,2) NOT NULL DEFAULT 0,
    TotalGastos       DECIMAL(14,2) NOT NULL DEFAULT 0,
    InteresesMora     DECIMAL(14,2) NOT NULL DEFAULT 0,
    Total             DECIMAL(14,2) NOT NULL DEFAULT 0,
    SaldoPendiente    DECIMAL(14,2) NOT NULL DEFAULT 0,
    Estado            NVARCHAR(20) NOT NULL DEFAULT 'pendiente',
    FechaVencimiento  DATE NOT NULL,
    CONSTRAINT FK_Cargo_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT FK_Cargo_Unidad FOREIGN KEY (UnidadId) REFERENCES Unidades(Id),
    CONSTRAINT FK_Cargo_Periodo FOREIGN KEY (PeriodoId) REFERENCES Periodos(Id),
    CONSTRAINT UQ_Cargo_Unidad_Periodo UNIQUE (UnidadId, PeriodoId),
    CONSTRAINT CK_Cargo_Estado CHECK (Estado IN ('pendiente','parcial','pagado','vencido'))
);
GO

CREATE TABLE CargoDetalles (
    Id                 BIGINT IDENTITY(1,1) PRIMARY KEY,
    CargoId            BIGINT NOT NULL,
    GastoProrrateoId   BIGINT NULL,      -- NULL si es un ajuste manual o interés
    Concepto           NVARCHAR(150) NOT NULL,
    Monto              DECIMAL(14,2) NOT NULL,
    CONSTRAINT FK_CD_Cargo FOREIGN KEY (CargoId) REFERENCES Cargos(Id),
    CONSTRAINT FK_CD_GP FOREIGN KEY (GastoProrrateoId) REFERENCES GastoProrrateos(Id)
);
GO

CREATE TABLE Pagos (
    Id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId   BIGINT NOT NULL,
    UnidadId       BIGINT NOT NULL,
    PersonaId      BIGINT NULL,
    Monto          DECIMAL(14,2) NOT NULL,
    FechaPago      DATE NOT NULL,
    MedioPago      NVARCHAR(40) NOT NULL,          -- efectivo, transferencia, pasarela, cheque
    Referencia     NVARCHAR(120) NULL,
    Estado         NVARCHAR(20) NOT NULL DEFAULT 'confirmado',
    CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Pago_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT FK_Pago_Unidad FOREIGN KEY (UnidadId) REFERENCES Unidades(Id),
    CONSTRAINT FK_Pago_Persona FOREIGN KEY (PersonaId) REFERENCES Personas(Id),
    CONSTRAINT CK_Pago_Estado CHECK (Estado IN ('confirmado','pendiente','rechazado'))
);
GO

-- Un pago puede aplicarse (total o parcialmente) a uno o más cargos, típicamente FIFO
CREATE TABLE PagoAplicaciones (
    Id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    PagoId         BIGINT NOT NULL,
    CargoId        BIGINT NOT NULL,
    MontoAplicado  DECIMAL(14,2) NOT NULL,
    CONSTRAINT FK_PA_Pago FOREIGN KEY (PagoId) REFERENCES Pagos(Id),
    CONSTRAINT FK_PA_Cargo FOREIGN KEY (CargoId) REFERENCES Cargos(Id)
);
GO

-- ----------------------------------------------------------------------------
-- 8. INGRESOS EXTRAORDINARIOS Y TESORERÍA (fondo separado, no se prorratea)
-- ----------------------------------------------------------------------------

CREATE TABLE IngresosExtraordinarios (
    Id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId   BIGINT NOT NULL,
    PeriodoId      BIGINT NULL,
    Fuente         NVARCHAR(60) NOT NULL,   -- parqueadero, alquiler_espacio, evento, subsidio, otro
    Concepto       NVARCHAR(150) NOT NULL,
    Monto          DECIMAL(14,2) NOT NULL,
    Fecha          DATE NOT NULL,
    Referencia     NVARCHAR(120) NULL,
    CONSTRAINT FK_IE_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT FK_IE_Periodo FOREIGN KEY (PeriodoId) REFERENCES Periodos(Id)
);
GO

CREATE TABLE CuentasFondo (
    Id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId   BIGINT NOT NULL,
    Nombre         NVARCHAR(100) NOT NULL,     -- Caja General, Fondo de Reserva
    Tipo           NVARCHAR(40) NOT NULL DEFAULT 'general',
    SaldoActual    DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT FK_CF_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id)
);
GO

-- Ledger general: todo movimiento real de caja (pagos, ingresos extraordinarios, egresos por gasto pagado)
CREATE TABLE MovimientosFondo (
    Id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId     BIGINT NOT NULL,
    CuentaId         BIGINT NOT NULL,
    Tipo             NVARCHAR(20) NOT NULL,       -- ingreso, egreso
    Origen           NVARCHAR(40) NOT NULL,       -- pago, ingreso_extraordinario, gasto, ajuste
    OrigenId         BIGINT NULL,
    Monto            DECIMAL(14,2) NOT NULL,
    Fecha            DATE NOT NULL,
    SaldoResultante  DECIMAL(14,2) NOT NULL,
    CreatedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_MF_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT FK_MF_Cuenta FOREIGN KEY (CuentaId) REFERENCES CuentasFondo(Id),
    CONSTRAINT CK_MF_Tipo CHECK (Tipo IN ('ingreso','egreso'))
);
GO

-- ----------------------------------------------------------------------------
-- 9. AUDITORÍA
-- ----------------------------------------------------------------------------

CREATE TABLE Auditoria (
    Id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    AgrupacionId   BIGINT NULL,
    UsuarioId      BIGINT NULL,
    Tabla          NVARCHAR(60) NOT NULL,
    RegistroId     BIGINT NOT NULL,
    Accion         NVARCHAR(20) NOT NULL,
    DatosAntes     NVARCHAR(MAX) NULL,
    DatosDespues   NVARCHAR(MAX) NULL,
    CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Aud_Agrupacion FOREIGN KEY (AgrupacionId) REFERENCES Agrupaciones(Id),
    CONSTRAINT FK_Aud_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuarios(Id),
    CONSTRAINT CK_Aud_Accion CHECK (Accion IN ('crear','actualizar','eliminar')),
    CONSTRAINT CK_Aud_DatosAntes CHECK (DatosAntes IS NULL OR ISJSON(DatosAntes) = 1),
    CONSTRAINT CK_Aud_DatosDespues CHECK (DatosDespues IS NULL OR ISJSON(DatosDespues) = 1)
);
GO

-- ----------------------------------------------------------------------------
-- 10. SEEDS DE CATÁLOGOS BASE
-- ----------------------------------------------------------------------------

INSERT INTO TiposAgrupacion (Codigo, Nombre) VALUES
    ('CONDOMINIO', 'Condominio residencial'),
    ('CENTRO_COMERCIAL', 'Centro comercial'),
    ('COWORKING', 'Espacio de coworking'),
    ('PARQUE_INDUSTRIAL', 'Parque industrial / zona franca');
GO

INSERT INTO MetodosProrrateo (Codigo, Nombre, Descripcion) VALUES
    ('COEFICIENTE', 'Por coeficiente/alícuota', 'Distribuye según el coeficiente vigente de cada unidad'),
    ('PARTES_IGUALES', 'Partes iguales', 'Divide el monto en partes iguales entre las unidades activas'),
    ('AREA', 'Por área (m2)', 'Distribuye proporcional al área de cada unidad'),
    ('CONSUMO', 'Por consumo', 'Distribuye según una lectura/consumo individual registrado'),
    ('DIRECTO', 'Directo a una unidad', 'Se asigna el 100% del gasto a una única unidad');
GO

INSERT INTO Roles (Codigo, Nombre) VALUES
    ('ADMIN_PLATAFORMA', 'Administrador de la plataforma'),
    ('ADMIN_AGRUPACION', 'Administrador de la agrupación'),
    ('PROPIETARIO', 'Propietario / arrendatario'),
    ('CONTADOR', 'Contador / auditor');
GO
