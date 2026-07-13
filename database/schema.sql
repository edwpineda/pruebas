-- ============================================================================
-- Modelo de datos: Sistema de prorrateo y distribución de costos
-- Vertical inicial: Propiedad Horizontal / Real Estate
--   (condominios, centros comerciales, coworkings, parques industriales)
-- Motor: MySQL 8.x / MariaDB 10.x — InnoDB, utf8mb4
-- Multi-tenancy: base de datos compartida, discriminador agrupacion_id
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------------------
-- 1. TENANT / AGRUPACIÓN (la entidad matriz)
-- ----------------------------------------------------------------------------

CREATE TABLE tipos_agrupacion (
    id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo        VARCHAR(40)  NOT NULL UNIQUE,   -- CONDOMINIO, CENTRO_COMERCIAL, COWORKING, PARQUE_INDUSTRIAL
    nombre        VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE agrupaciones (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_agrupacion_id  INT UNSIGNED NOT NULL,
    nombre              VARCHAR(150) NOT NULL,
    identificacion_fiscal VARCHAR(40)  NULL,
    moneda              CHAR(3)      NOT NULL DEFAULT 'USD',
    direccion           VARCHAR(255) NULL,
    dia_corte_facturacion TINYINT UNSIGNED NOT NULL DEFAULT 1,   -- día del mes en que se cierra el periodo
    tasa_interes_mora   DECIMAL(6,4) NOT NULL DEFAULT 0,          -- % mensual
    configuracion       JSON         NULL,                        -- settings flexibles por tenant
    activo              BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at          TIMESTAMP    NULL,
    CONSTRAINT fk_agrupaciones_tipo FOREIGN KEY (tipo_agrupacion_id) REFERENCES tipos_agrupacion(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 2. UNIDADES (subentidades) y su coeficiente histórico
-- ----------------------------------------------------------------------------

CREATE TABLE unidades (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NOT NULL,
    codigo          VARCHAR(40)  NOT NULL,             -- "Apto 501", "Local 12", "Oficina 3B"
    tipo_unidad     VARCHAR(40)  NOT NULL,              -- residencial, comercial, bodega, oficina, lote
    area_m2         DECIMAL(10,2) NULL,
    estado          ENUM('activo','inactivo') NOT NULL DEFAULT 'activo',
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at      TIMESTAMP NULL,
    CONSTRAINT fk_unidades_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    UNIQUE KEY uq_unidad_codigo (agrupacion_id, codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- El coeficiente/alícuota puede cambiar en el tiempo (remodelaciones, subdivisiones).
-- Se historiza en vez de guardarlo como columna fija en `unidades`.
CREATE TABLE unidad_coeficientes (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    unidad_id       BIGINT UNSIGNED NOT NULL,
    coeficiente     DECIMAL(9,6) NOT NULL,          -- ej. 0.008345 (participación sobre el total)
    vigente_desde   DATE NOT NULL,
    vigente_hasta   DATE NULL,                      -- NULL = vigente actualmente
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_coef_unidad FOREIGN KEY (unidad_id) REFERENCES unidades(id),
    KEY idx_coef_vigencia (unidad_id, vigente_desde, vigente_hasta)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 3. PERSONAS / TERCEROS
-- ----------------------------------------------------------------------------

CREATE TABLE personas (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_documento  VARCHAR(10)  NULL,
    numero_documento VARCHAR(40) NULL,
    nombre          VARCHAR(150) NOT NULL,
    email           VARCHAR(150) NULL,
    telefono        VARCHAR(40)  NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_persona_doc (tipo_documento, numero_documento)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Relación N:M entre unidades y personas, con rol e histórico (propietario cambia, arrendatario cambia)
CREATE TABLE unidad_persona (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    unidad_id       BIGINT UNSIGNED NOT NULL,
    persona_id      BIGINT UNSIGNED NOT NULL,
    rol             ENUM('propietario','arrendatario','autorizado') NOT NULL,
    responsable_pago BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_desde     DATE NOT NULL,
    fecha_hasta     DATE NULL,
    CONSTRAINT fk_up_unidad FOREIGN KEY (unidad_id) REFERENCES unidades(id),
    CONSTRAINT fk_up_persona FOREIGN KEY (persona_id) REFERENCES personas(id),
    KEY idx_up_vigencia (unidad_id, rol, fecha_desde, fecha_hasta)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Usuarios del sistema (login), separados de "personas" del negocio
CREATE TABLE roles (
    id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo  VARCHAR(40) NOT NULL UNIQUE,   -- ADMIN_PLATAFORMA, ADMIN_AGRUPACION, PROPIETARIO, CONTADOR
    nombre  VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE usuarios (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NULL,          -- NULL = usuario de plataforma (soporte/super-admin)
    persona_id      BIGINT UNSIGNED NULL,
    rol_id          INT UNSIGNED NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuarios_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    CONSTRAINT fk_usuarios_persona FOREIGN KEY (persona_id) REFERENCES personas(id),
    CONSTRAINT fk_usuarios_rol FOREIGN KEY (rol_id) REFERENCES roles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 4. CATÁLOGOS DE PRORRATEO Y GASTOS
-- ----------------------------------------------------------------------------

CREATE TABLE metodos_prorrateo (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo      VARCHAR(30) NOT NULL UNIQUE,   -- COEFICIENTE, PARTES_IGUALES, AREA, CONSUMO, DIRECTO
    nombre      VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE proveedores (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NOT NULL,
    razon_social    VARCHAR(150) NOT NULL,
    identificacion_fiscal VARCHAR(40) NULL,
    categoria       VARCHAR(60) NULL,          -- seguridad, aseo, mantenimiento, servicios_publicos
    contacto        VARCHAR(150) NULL,
    CONSTRAINT fk_proveedores_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE conceptos_gasto (
    id                      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id           BIGINT UNSIGNED NOT NULL,
    nombre                  VARCHAR(120) NOT NULL,     -- "Vigilancia", "Aseo zonas comunes", "Internet"
    naturaleza              ENUM('fijo','variable') NOT NULL,
    metodo_prorrateo_id     INT UNSIGNED NOT NULL,     -- método por defecto
    activo                  BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_concepto_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    CONSTRAINT fk_concepto_metodo FOREIGN KEY (metodo_prorrateo_id) REFERENCES metodos_prorrateo(id),
    UNIQUE KEY uq_concepto_nombre (agrupacion_id, nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 5. PERIODOS DE FACTURACIÓN
-- ----------------------------------------------------------------------------

CREATE TABLE periodos (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NOT NULL,
    anio            SMALLINT UNSIGNED NOT NULL,
    mes             TINYINT UNSIGNED NOT NULL,
    fecha_inicio    DATE NOT NULL,
    fecha_fin       DATE NOT NULL,
    estado          ENUM('abierto','cerrado') NOT NULL DEFAULT 'abierto',
    fecha_cierre    TIMESTAMP NULL,
    CONSTRAINT fk_periodo_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    UNIQUE KEY uq_periodo (agrupacion_id, anio, mes)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 6. GASTOS (Y) Y SU PRORRATEO
-- ----------------------------------------------------------------------------

CREATE TABLE gastos (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id       BIGINT UNSIGNED NOT NULL,
    periodo_id          BIGINT UNSIGNED NOT NULL,
    concepto_id         BIGINT UNSIGNED NOT NULL,
    proveedor_id        BIGINT UNSIGNED NULL,
    metodo_prorrateo_id INT UNSIGNED NOT NULL,     -- puede sobreescribir el default del concepto
    monto               DECIMAL(14,2) NOT NULL,
    fecha_gasto         DATE NOT NULL,
    descripcion         VARCHAR(255) NULL,
    comprobante_url     VARCHAR(255) NULL,
    estado              ENUM('pendiente','prorrateado','anulado') NOT NULL DEFAULT 'pendiente',
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_gasto_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    CONSTRAINT fk_gasto_periodo FOREIGN KEY (periodo_id) REFERENCES periodos(id),
    CONSTRAINT fk_gasto_concepto FOREIGN KEY (concepto_id) REFERENCES conceptos_gasto(id),
    CONSTRAINT fk_gasto_proveedor FOREIGN KEY (proveedor_id) REFERENCES proveedores(id),
    CONSTRAINT fk_gasto_metodo FOREIGN KEY (metodo_prorrateo_id) REFERENCES metodos_prorrateo(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Resultado congelado (auditoría) de distribuir un gasto entre unidades.
-- No se recalcula on-the-fly: es la fuente de verdad de "qué se le cobró a quién y por qué".
CREATE TABLE gasto_prorrateos (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    gasto_id            BIGINT UNSIGNED NOT NULL,
    unidad_id           BIGINT UNSIGNED NOT NULL,
    monto_asignado      DECIMAL(14,2) NOT NULL,
    coeficiente_aplicado DECIMAL(9,6) NULL,
    base_calculo        DECIMAL(14,4) NULL,        -- ej. m2 o unidades de consumo usadas en el cálculo
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_gp_gasto FOREIGN KEY (gasto_id) REFERENCES gastos(id),
    CONSTRAINT fk_gp_unidad FOREIGN KEY (unidad_id) REFERENCES unidades(id),
    UNIQUE KEY uq_gasto_unidad (gasto_id, unidad_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 7. CARGOS (estado de cuenta por unidad y periodo) Y PAGOS
-- ----------------------------------------------------------------------------

CREATE TABLE cargos (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NOT NULL,
    unidad_id       BIGINT UNSIGNED NOT NULL,
    periodo_id      BIGINT UNSIGNED NOT NULL,
    saldo_anterior  DECIMAL(14,2) NOT NULL DEFAULT 0,
    total_gastos    DECIMAL(14,2) NOT NULL DEFAULT 0,
    intereses_mora  DECIMAL(14,2) NOT NULL DEFAULT 0,
    total           DECIMAL(14,2) NOT NULL DEFAULT 0,
    saldo_pendiente DECIMAL(14,2) NOT NULL DEFAULT 0,
    estado          ENUM('pendiente','parcial','pagado','vencido') NOT NULL DEFAULT 'pendiente',
    fecha_vencimiento DATE NOT NULL,
    CONSTRAINT fk_cargo_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    CONSTRAINT fk_cargo_unidad FOREIGN KEY (unidad_id) REFERENCES unidades(id),
    CONSTRAINT fk_cargo_periodo FOREIGN KEY (periodo_id) REFERENCES periodos(id),
    UNIQUE KEY uq_cargo_unidad_periodo (unidad_id, periodo_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cargo_detalles (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cargo_id            BIGINT UNSIGNED NOT NULL,
    gasto_prorrateo_id  BIGINT UNSIGNED NULL,      -- NULL si es un ajuste manual o interés
    concepto            VARCHAR(150) NOT NULL,
    monto               DECIMAL(14,2) NOT NULL,
    CONSTRAINT fk_cd_cargo FOREIGN KEY (cargo_id) REFERENCES cargos(id),
    CONSTRAINT fk_cd_gp FOREIGN KEY (gasto_prorrateo_id) REFERENCES gasto_prorrateos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE pagos (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NOT NULL,
    unidad_id       BIGINT UNSIGNED NOT NULL,
    persona_id      BIGINT UNSIGNED NULL,
    monto           DECIMAL(14,2) NOT NULL,
    fecha_pago      DATE NOT NULL,
    medio_pago      VARCHAR(40) NOT NULL,          -- efectivo, transferencia, pasarela, cheque
    referencia      VARCHAR(120) NULL,
    estado          ENUM('confirmado','pendiente','rechazado') NOT NULL DEFAULT 'confirmado',
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pago_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    CONSTRAINT fk_pago_unidad FOREIGN KEY (unidad_id) REFERENCES unidades(id),
    CONSTRAINT fk_pago_persona FOREIGN KEY (persona_id) REFERENCES personas(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Un pago puede aplicarse (total o parcialmente) a uno o más cargos, típicamente FIFO
CREATE TABLE pago_aplicaciones (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pago_id         BIGINT UNSIGNED NOT NULL,
    cargo_id        BIGINT UNSIGNED NOT NULL,
    monto_aplicado  DECIMAL(14,2) NOT NULL,
    CONSTRAINT fk_pa_pago FOREIGN KEY (pago_id) REFERENCES pagos(id),
    CONSTRAINT fk_pa_cargo FOREIGN KEY (cargo_id) REFERENCES cargos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 8. INGRESOS EXTRAORDINARIOS Y TESORERÍA (fondo separado, no se prorratea)
-- ----------------------------------------------------------------------------

CREATE TABLE ingresos_extraordinarios (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NOT NULL,
    periodo_id      BIGINT UNSIGNED NULL,
    fuente          VARCHAR(60) NOT NULL,   -- parqueadero, alquiler_espacio, evento, subsidio, otro
    concepto        VARCHAR(150) NOT NULL,
    monto           DECIMAL(14,2) NOT NULL,
    fecha           DATE NOT NULL,
    referencia      VARCHAR(120) NULL,
    CONSTRAINT fk_ie_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    CONSTRAINT fk_ie_periodo FOREIGN KEY (periodo_id) REFERENCES periodos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE cuentas_fondo (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NOT NULL,
    nombre          VARCHAR(100) NOT NULL,     -- Caja General, Fondo de Reserva
    tipo            VARCHAR(40) NOT NULL DEFAULT 'general',
    saldo_actual    DECIMAL(14,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_cf_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Ledger general: todo movimiento real de caja (pagos, ingresos extraordinarios, egresos por gasto pagado)
CREATE TABLE movimientos_fondo (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NOT NULL,
    cuenta_id       BIGINT UNSIGNED NOT NULL,
    tipo            ENUM('ingreso','egreso') NOT NULL,
    origen          VARCHAR(40) NOT NULL,       -- pago, ingreso_extraordinario, gasto, ajuste
    origen_id       BIGINT UNSIGNED NULL,
    monto           DECIMAL(14,2) NOT NULL,
    fecha           DATE NOT NULL,
    saldo_resultante DECIMAL(14,2) NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_mf_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    CONSTRAINT fk_mf_cuenta FOREIGN KEY (cuenta_id) REFERENCES cuentas_fondo(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------------------------------------------------------
-- 9. AUDITORÍA
-- ----------------------------------------------------------------------------

CREATE TABLE auditoria (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    agrupacion_id   BIGINT UNSIGNED NULL,
    usuario_id      BIGINT UNSIGNED NULL,
    tabla           VARCHAR(60) NOT NULL,
    registro_id     BIGINT UNSIGNED NOT NULL,
    accion          ENUM('crear','actualizar','eliminar') NOT NULL,
    datos_antes     JSON NULL,
    datos_despues   JSON NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_aud_agrupacion FOREIGN KEY (agrupacion_id) REFERENCES agrupaciones(id),
    CONSTRAINT fk_aud_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------------------
-- 10. SEEDS DE CATÁLOGOS BASE
-- ----------------------------------------------------------------------------

INSERT INTO tipos_agrupacion (codigo, nombre) VALUES
    ('CONDOMINIO', 'Condominio residencial'),
    ('CENTRO_COMERCIAL', 'Centro comercial'),
    ('COWORKING', 'Espacio de coworking'),
    ('PARQUE_INDUSTRIAL', 'Parque industrial / zona franca');

INSERT INTO metodos_prorrateo (codigo, nombre, descripcion) VALUES
    ('COEFICIENTE', 'Por coeficiente/alícuota', 'Distribuye según el coeficiente vigente de cada unidad'),
    ('PARTES_IGUALES', 'Partes iguales', 'Divide el monto en partes iguales entre las unidades activas'),
    ('AREA', 'Por área (m2)', 'Distribuye proporcional al área de cada unidad'),
    ('CONSUMO', 'Por consumo', 'Distribuye según una lectura/consumo individual registrado'),
    ('DIRECTO', 'Directo a una unidad', 'Se asigna el 100% del gasto a una única unidad');

INSERT INTO roles (codigo, nombre) VALUES
    ('ADMIN_PLATAFORMA', 'Administrador de la plataforma'),
    ('ADMIN_AGRUPACION', 'Administrador de la agrupación'),
    ('PROPIETARIO', 'Propietario / arrendatario'),
    ('CONTADOR', 'Contador / auditor');
