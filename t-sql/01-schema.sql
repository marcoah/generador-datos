-- ============================================================================
-- SCHEMA DE BASE DE DATOS - SISTEMA DE VENTAS
-- SQL Server 2016+
-- ============================================================================
-- Este schema está diseñado para:
-- 1. Generar datos realistas de ventas
-- 2. Soportar análisis complejos en Power BI y dashboards custom
-- 3. Ser fácil de limpiar y resetear para pruebas
-- ============================================================================

-- ============================================================================
-- DIMENSIÓN: CLIENTES
-- ============================================================================
IF OBJECT_ID('dbo.clientes', 'U') IS NULL
CREATE TABLE dbo.clientes (
    id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    uuid             UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    nombre           NVARCHAR(255) NOT NULL,
    email            NVARCHAR(255) NULL,
    telefono         NVARCHAR(20) NULL,

    -- Segmentación
    -- Valores: premium, estandar, prueba, vip, inactivo
    segmento         NVARCHAR(50) NOT NULL DEFAULT 'estandar',
    industria        NVARCHAR(100) NULL,
    -- Valores: startup, pequeña, mediana, grande, corporacion
    tamaño_empresa   NVARCHAR(50) NULL,

    -- Ubicación
    pais             NVARCHAR(100) NULL,
    provincia        NVARCHAR(100) NULL,
    ciudad           NVARCHAR(100) NULL,
    codigo_postal    NVARCHAR(20) NULL,

    -- Información financiera
    limite_credito   DECIMAL(15,2) NULL,
    valor_vida_total DECIMAL(15,2) NOT NULL DEFAULT 0,

    -- Metadatos
    fecha_adquisicion   DATETIME2 NOT NULL DEFAULT GETDATE(),
    fecha_ultima_compra DATETIME2 NULL,
    activo              BIT NOT NULL DEFAULT 1,
    notas               NVARCHAR(MAX) NULL,

    creado_en           DATETIME2 NOT NULL DEFAULT GETDATE(),
    actualizado_en      DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_clientes_uuid  UNIQUE (uuid),
    CONSTRAINT uq_clientes_email UNIQUE (email)
);
GO

CREATE INDEX idx_clientes_segmento          ON dbo.clientes (segmento);
CREATE INDEX idx_clientes_pais              ON dbo.clientes (pais);
CREATE INDEX idx_clientes_activo            ON dbo.clientes (activo);
CREATE INDEX idx_clientes_fecha_adquisicion ON dbo.clientes (fecha_adquisicion);
GO

-- ============================================================================
-- DIMENSIÓN: PRODUCTOS
-- ============================================================================
IF OBJECT_ID('dbo.productos', 'U') IS NULL
CREATE TABLE dbo.productos (
    id                     BIGINT IDENTITY(1,1) PRIMARY KEY,
    uuid                   UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    nombre                 NVARCHAR(255) NOT NULL,
    sku                    NVARCHAR(50) NOT NULL,
    descripcion            NVARCHAR(MAX) NULL,

    -- Categorización
    categoria              NVARCHAR(100) NOT NULL,
    subcategoria           NVARCHAR(100) NULL,
    marca                  NVARCHAR(100) NULL,

    -- Precios
    precio_lista           DECIMAL(10,2) NOT NULL,
    precio_costo           DECIMAL(10,2) NULL,

    -- Stock
    stock_actual           INT NOT NULL DEFAULT 0,
    stock_minimo           INT NOT NULL DEFAULT 10,

    -- Propiedades
    peso_kg                DECIMAL(8,2) NULL,
    volumen_m3             DECIMAL(8,3) NULL,
    es_digital             BIT NOT NULL DEFAULT 0,

    -- Ciclo de vida
    fecha_lanzamiento      DATE NULL,
    fecha_descontinuacion  DATE NULL,
    activo                 BIT NOT NULL DEFAULT 1,

    creado_en              DATETIME2 NOT NULL DEFAULT GETDATE(),
    actualizado_en         DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_productos_uuid UNIQUE (uuid),
    CONSTRAINT uq_productos_sku  UNIQUE (sku)
);
GO

CREATE INDEX idx_productos_categoria ON dbo.productos (categoria);
CREATE INDEX idx_productos_sku       ON dbo.productos (sku);
CREATE INDEX idx_productos_activo    ON dbo.productos (activo);
CREATE INDEX idx_productos_marca     ON dbo.productos (marca);
GO

-- ============================================================================
-- DIMENSIÓN: VENDEDORES
-- ============================================================================
IF OBJECT_ID('dbo.vendedores', 'U') IS NULL
CREATE TABLE dbo.vendedores (
    id                  BIGINT IDENTITY(1,1) PRIMARY KEY,
    uuid                UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    nombre              NVARCHAR(255) NOT NULL,
    email               NVARCHAR(255) NULL,
    telefono            NVARCHAR(20) NULL,

    -- Organización
    equipo              NVARCHAR(100) NULL,
    territorio          NVARCHAR(100) NULL,
    gerente_id          BIGINT NULL,

    -- Performance
    tasa_comision       DECIMAL(5,2) NOT NULL DEFAULT 0,
    cuota_mensual       DECIMAL(15,2) NULL,

    -- Estatus
    activo              BIT NOT NULL DEFAULT 1,
    fecha_contratacion  DATE NULL,
    fecha_baja          DATE NULL,

    creado_en           DATETIME2 NOT NULL DEFAULT GETDATE(),
    actualizado_en      DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_vendedores_uuid  UNIQUE (uuid),
    CONSTRAINT uq_vendedores_email UNIQUE (email),
    CONSTRAINT fk_vendedores_gerente FOREIGN KEY (gerente_id)
        REFERENCES dbo.vendedores (id)
);
GO

CREATE INDEX idx_vendedores_equipo     ON dbo.vendedores (equipo);
CREATE INDEX idx_vendedores_territorio ON dbo.vendedores (territorio);
CREATE INDEX idx_vendedores_activo     ON dbo.vendedores (activo);
GO

-- ============================================================================
-- HECHO: ÓRDENES DE VENTAS
-- ============================================================================
IF OBJECT_ID('dbo.ordenes', 'U') IS NULL
CREATE TABLE dbo.ordenes (
    id                       BIGINT IDENTITY(1,1) PRIMARY KEY,
    uuid                     UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),

    -- Foreign Keys
    cliente_id               BIGINT NOT NULL,
    vendedor_id              BIGINT NULL,

    -- Fechas clave
    fecha_orden              DATETIME2 NOT NULL,
    fecha_entrega_prometida  DATE NULL,
    fecha_entrega_real       DATE NULL,

    -- Montos
    subtotal                 DECIMAL(15,2) NOT NULL DEFAULT 0,
    monto_descuento          DECIMAL(15,2) NOT NULL DEFAULT 0,
    porcentaje_descuento     DECIMAL(5,2)  NOT NULL DEFAULT 0,
    monto_impuesto           DECIMAL(15,2) NOT NULL DEFAULT 0,
    costo_envio              DECIMAL(15,2) NOT NULL DEFAULT 0,
    monto_total              DECIMAL(15,2) NOT NULL DEFAULT 0,

    -- Información de pago
    -- Valores: tarjeta_credito, transferencia_bancaria, efectivo, cheque, otro
    metodo_pago              NVARCHAR(50) NULL,
    -- Valores: pendiente, parcial, pagado, vencido, reembolsado
    estado_pago              NVARCHAR(50) NOT NULL DEFAULT 'pendiente',
    fecha_pago               DATETIME2 NULL,

    -- Estado de la orden
    -- Valores: pendiente, confirmado, procesando, enviado, entregado, cancelado, devuelto
    estado                   NVARCHAR(50) NOT NULL DEFAULT 'pendiente',

    -- Notas
    notas                    NVARCHAR(MAX) NULL,
    notas_internas           NVARCHAR(MAX) NULL,

    -- Auditoría
    creado_en                DATETIME2 NOT NULL DEFAULT GETDATE(),
    actualizado_en           DATETIME2 NOT NULL DEFAULT GETDATE(),
    creado_por               NVARCHAR(100) NULL,

    CONSTRAINT uq_ordenes_uuid UNIQUE (uuid),
    CONSTRAINT fk_ordenes_cliente  FOREIGN KEY (cliente_id)  REFERENCES dbo.clientes  (id),
    CONSTRAINT fk_ordenes_vendedor FOREIGN KEY (vendedor_id) REFERENCES dbo.vendedores (id)
);
GO

CREATE INDEX idx_ordenes_cliente_id  ON dbo.ordenes (cliente_id);
CREATE INDEX idx_ordenes_vendedor_id ON dbo.ordenes (vendedor_id);
CREATE INDEX idx_ordenes_fecha_orden ON dbo.ordenes (fecha_orden);
CREATE INDEX idx_ordenes_estado      ON dbo.ordenes (estado);
CREATE INDEX idx_ordenes_estado_pago ON dbo.ordenes (estado_pago);
CREATE INDEX idx_ordenes_creado_en   ON dbo.ordenes (creado_en);
GO

-- ============================================================================
-- DETALLE: ÍTEMS DE ÓRDENES
-- ============================================================================
IF OBJECT_ID('dbo.items_orden', 'U') IS NULL
CREATE TABLE dbo.items_orden (
    id                   BIGINT IDENTITY(1,1) PRIMARY KEY,
    orden_id             BIGINT NOT NULL,
    producto_id          BIGINT NOT NULL,

    -- Cantidad y precio
    cantidad             INT NOT NULL CHECK (cantidad > 0),
    precio_unitario      DECIMAL(10,2) NOT NULL,
    porcentaje_descuento DECIMAL(5,2) NOT NULL DEFAULT 0,
    -- Columna calculada equivalente al GENERATED de PostgreSQL
    total_linea AS (CAST(cantidad * precio_unitario * (1 - porcentaje_descuento / 100.0) AS DECIMAL(15,2))) PERSISTED,

    -- Control de inventario
    ubicacion_almacen    NVARCHAR(100) NULL,
    completado           BIT NOT NULL DEFAULT 0,

    -- Devoluciones
    cantidad_devuelta    INT NOT NULL DEFAULT 0,
    motivo_devolucion    NVARCHAR(255) NULL,

    creado_en            DATETIME2 NOT NULL DEFAULT GETDATE(),
    actualizado_en       DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT fk_items_orden_orden    FOREIGN KEY (orden_id)    REFERENCES dbo.ordenes   (id) ON DELETE CASCADE,
    CONSTRAINT fk_items_orden_producto FOREIGN KEY (producto_id) REFERENCES dbo.productos (id)
);
GO

CREATE INDEX idx_items_orden_orden_id   ON dbo.items_orden (orden_id);
CREATE INDEX idx_items_orden_producto_id ON dbo.items_orden (producto_id);
CREATE INDEX idx_items_orden_completado  ON dbo.items_orden (completado);
GO

-- ============================================================================
-- TRANSACCIONES: PAGOS
-- ============================================================================
IF OBJECT_ID('dbo.pagos', 'U') IS NULL
CREATE TABLE dbo.pagos (
    id                 BIGINT IDENTITY(1,1) PRIMARY KEY,
    uuid               UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    orden_id           BIGINT NOT NULL,

    monto              DECIMAL(15,2) NOT NULL,
    fecha_pago         DATETIME2 NOT NULL DEFAULT GETDATE(),

    metodo_pago        NVARCHAR(50) NOT NULL,
    numero_referencia  NVARCHAR(100) NULL,

    -- Valores: pendiente, completado, fallido, reembolsado
    estado             NVARCHAR(50) NOT NULL DEFAULT 'completado',

    notas              NVARCHAR(MAX) NULL,
    creado_en          DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_pagos_uuid  UNIQUE (uuid),
    CONSTRAINT fk_pagos_orden FOREIGN KEY (orden_id) REFERENCES dbo.ordenes (id)
);
GO

CREATE INDEX idx_pagos_orden_id  ON dbo.pagos (orden_id);
CREATE INDEX idx_pagos_fecha     ON dbo.pagos (fecha_pago);
CREATE INDEX idx_pagos_estado    ON dbo.pagos (estado);
GO

-- ============================================================================
-- DEVOLUCIONES / REEMBOLSOS
-- ============================================================================
IF OBJECT_ID('dbo.devoluciones', 'U') IS NULL
CREATE TABLE dbo.devoluciones (
    id                BIGINT IDENTITY(1,1) PRIMARY KEY,
    uuid              UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    orden_id          BIGINT NOT NULL,

    fecha_devolucion  DATETIME2 NOT NULL DEFAULT GETDATE(),
    motivo            NVARCHAR(255) NOT NULL,
    descripcion       NVARCHAR(MAX) NULL,

    monto_reembolso   DECIMAL(15,2) NOT NULL,
    fecha_reembolso   DATETIME2 NULL,

    -- Valores: pendiente, aprobado, rechazado, reembolsado, reembolso_parcial
    estado            NVARCHAR(50) NOT NULL DEFAULT 'pendiente',

    aprobado_por      NVARCHAR(100) NULL,
    creado_en         DATETIME2 NOT NULL DEFAULT GETDATE(),
    actualizado_en    DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_devoluciones_uuid  UNIQUE (uuid),
    CONSTRAINT fk_devoluciones_orden FOREIGN KEY (orden_id) REFERENCES dbo.ordenes (id)
);
GO

CREATE INDEX idx_devoluciones_orden_id        ON dbo.devoluciones (orden_id);
CREATE INDEX idx_devoluciones_fecha_devolucion ON dbo.devoluciones (fecha_devolucion);
CREATE INDEX idx_devoluciones_estado           ON dbo.devoluciones (estado);
GO

-- ============================================================================
-- INTERACCIONES CON CLIENTES (CRM)
-- ============================================================================
IF OBJECT_ID('dbo.interacciones_clientes', 'U') IS NULL
CREATE TABLE dbo.interacciones_clientes (
    id                          BIGINT IDENTITY(1,1) PRIMARY KEY,
    uuid                        UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    cliente_id                  BIGINT NOT NULL,
    vendedor_id                 BIGINT NULL,

    -- Valores: llamada, email, reunion, demo, soporte, seguimiento
    tipo_interaccion            NVARCHAR(50) NOT NULL,
    asunto                      NVARCHAR(255) NULL,
    notas                       NVARCHAR(MAX) NULL,

    -- Valores: interesado, no_interesado, demo_programada, etc.
    resultado                   NVARCHAR(100) NULL,
    fecha_proximo_seguimiento   DATE NULL,

    fecha_interaccion           DATETIME2 NOT NULL DEFAULT GETDATE(),
    duracion_minutos            INT NULL,

    creado_en                   DATETIME2 NOT NULL DEFAULT GETDATE(),
    actualizado_en              DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_interacciones_uuid       UNIQUE (uuid),
    CONSTRAINT fk_interacciones_cliente    FOREIGN KEY (cliente_id)  REFERENCES dbo.clientes  (id) ON DELETE CASCADE,
    CONSTRAINT fk_interacciones_vendedor   FOREIGN KEY (vendedor_id) REFERENCES dbo.vendedores (id)
);
GO

CREATE INDEX idx_interacciones_cliente_id ON dbo.interacciones_clientes (cliente_id);
CREATE INDEX idx_interacciones_fecha      ON dbo.interacciones_clientes (fecha_interaccion);
CREATE INDEX idx_interacciones_vendedor   ON dbo.interacciones_clientes (vendedor_id);
GO

-- ============================================================================
-- CAMPAÑAS DE MARKETING
-- ============================================================================
IF OBJECT_ID('dbo.campanas', 'U') IS NULL
CREATE TABLE dbo.campanas (
    id                  BIGINT IDENTITY(1,1) PRIMARY KEY,
    uuid                UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    nombre              NVARCHAR(255) NOT NULL,
    descripcion         NVARCHAR(MAX) NULL,

    -- Valores: email, webinar, feria, promocion, estacional
    tipo_campana        NVARCHAR(100) NULL,
    -- Valores: email, redes_sociales, correo_directo, eventos, referido, organico
    canal               NVARCHAR(50) NULL,

    fecha_inicio        DATE NOT NULL,
    fecha_fin           DATE NULL,

    presupuesto         DECIMAL(15,2) NULL,
    gasto_real          DECIMAL(15,2) NOT NULL DEFAULT 0,

    impresiones         INT NOT NULL DEFAULT 0,
    clics               INT NOT NULL DEFAULT 0,
    conversiones        INT NOT NULL DEFAULT 0,
    ingresos_generados  DECIMAL(15,2) NOT NULL DEFAULT 0,

    -- Valores: planificada, activa, completada, cancelada
    estado              NVARCHAR(50) NOT NULL DEFAULT 'activa',

    creado_en           DATETIME2 NOT NULL DEFAULT GETDATE(),
    actualizado_en      DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_campanas_uuid UNIQUE (uuid)
);
GO

CREATE INDEX idx_campanas_fecha_inicio ON dbo.campanas (fecha_inicio);
CREATE INDEX idx_campanas_estado       ON dbo.campanas (estado);
GO

-- ============================================================================
-- RELACIÓN: CLIENTES - CAMPAÑAS
-- ============================================================================
IF OBJECT_ID('dbo.campanas_clientes', 'U') IS NULL
CREATE TABLE dbo.campanas_clientes (
    id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    campana_id       BIGINT NOT NULL,
    cliente_id       BIGINT NOT NULL,

    fecha_contacto   DATETIME2 NULL,
    abierto          BIT NOT NULL DEFAULT 0,
    hizo_clic        BIT NOT NULL DEFAULT 0,
    convirtio        BIT NOT NULL DEFAULT 0,
    fecha_conversion DATETIME2 NULL,

    creado_en        DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_campana_cliente    UNIQUE (campana_id, cliente_id),
    CONSTRAINT fk_cc_campana         FOREIGN KEY (campana_id) REFERENCES dbo.campanas (id) ON DELETE CASCADE,
    CONSTRAINT fk_cc_cliente         FOREIGN KEY (cliente_id) REFERENCES dbo.clientes  (id) ON DELETE CASCADE
);
GO

CREATE INDEX idx_campanas_clientes_campana_id ON dbo.campanas_clientes (campana_id);
CREATE INDEX idx_campanas_clientes_cliente_id ON dbo.campanas_clientes (cliente_id);
GO

-- ============================================================================
-- TABLA DE AUDITORÍA / CONTROL DE CARGAS
-- ============================================================================
IF OBJECT_ID('dbo.cargas_datos', 'U') IS NULL
CREATE TABLE dbo.cargas_datos (
    id                   BIGINT IDENTITY(1,1) PRIMARY KEY,
    fecha_carga          DATETIME2 NOT NULL DEFAULT GETDATE(),
    -- Valores: inicial, incremental, refresco, prueba
    tipo_carga           NVARCHAR(100) NULL,
    registros_afectados  INT NULL,
    estado               NVARCHAR(50) NULL,
    notas                NVARCHAR(MAX) NULL
);
GO

-- ============================================================================
-- EXTENDED PROPERTIES (equivalente a COMMENT ON en PostgreSQL)
-- ============================================================================
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description', @value = N'Tabla de dimensión de clientes con información demográfica y de segmentación',
    @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'clientes';

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description', @value = N'Tabla de dimensión de productos con categorización y precios',
    @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'productos';

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description', @value = N'Tabla de hechos de órdenes de ventas',
    @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ordenes';

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description', @value = N'Total final: subtotal - descuento + impuesto + envío',
    @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'ordenes',
    @level2type = N'COLUMN', @level2name = N'monto_total';

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description', @value = N'Calculado: cantidad * precio_unitario * (1 - descuento%)',
    @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'items_orden',
    @level2type = N'COLUMN', @level2name = N'total_linea';
GO

-- ============================================================================
-- TRIGGERS PARA MANTENER INTEGRIDAD DE DATOS
-- ============================================================================

-- Trigger: Actualizar total de la orden cuando se insertan/modifican/eliminan ítems
CREATE OR ALTER TRIGGER trg_actualizar_total_orden
ON dbo.items_orden
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Obtener los orden_id afectados (tanto de inserted como de deleted)
    DECLARE @ordenes_afectadas TABLE (orden_id BIGINT);

    INSERT INTO @ordenes_afectadas (orden_id)
    SELECT DISTINCT orden_id FROM inserted
    UNION
    SELECT DISTINCT orden_id FROM deleted;

    UPDATE o
    SET
        monto_total    = COALESCE((SELECT SUM(io.total_linea) FROM dbo.items_orden io WHERE io.orden_id = o.id), 0)
                         + COALESCE(o.monto_impuesto, 0)
                         + COALESCE(o.costo_envio, 0)
                         - COALESCE(o.monto_descuento, 0),
        actualizado_en = GETDATE()
    FROM dbo.ordenes o
    INNER JOIN @ordenes_afectadas oa ON o.id = oa.orden_id;
END;
GO

-- Trigger: Actualizar valor de vida del cliente cuando cambian órdenes
CREATE OR ALTER TRIGGER trg_actualizar_valor_vida_cliente
ON dbo.ordenes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE c
    SET
        valor_vida_total    = COALESCE(
            (SELECT SUM(o.monto_total) FROM dbo.ordenes o
             WHERE o.cliente_id = c.id AND o.estado <> 'cancelado'), 0),
        fecha_ultima_compra = (
            SELECT MAX(o.fecha_orden) FROM dbo.ordenes o
            WHERE o.cliente_id = c.id AND o.estado <> 'cancelado'),
        actualizado_en      = GETDATE()
    FROM dbo.clientes c
    INNER JOIN inserted i ON c.id = i.cliente_id;
END;
GO

-- ============================================================================
-- PROCEDIMIENTO: Registrar en cargas_datos
-- (En SQL Server usamos SP en lugar de función para operaciones DML)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_registrar_carga_datos
    @tipo_carga          NVARCHAR(100),
    @registros_afectados INT,
    @estado              NVARCHAR(50) = 'completado',
    @notas               NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.cargas_datos (tipo_carga, registros_afectados, estado, notas)
    VALUES (@tipo_carga, @registros_afectados, @estado, @notas);

    SELECT SCOPE_IDENTITY() AS carga_id;
END;
GO

-- ============================================================================
-- FIN DEL SCHEMA
-- ============================================================================
