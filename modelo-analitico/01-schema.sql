-- ============================================================================
-- SCHEMA DEL MODELO ANALÍTICO (STAR SCHEMA) - VENTAS
-- SQL Server 2016+
-- ============================================================================
-- 6 dimensiones + 3 tablas de hechos (fact constellation). Ver
-- DOCUMENTACION-MODELO.md para el diagrama y la justificación de cada
-- decisión de diseño (grano, dimensiones achatadas, miembro "Desconocido").
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- ============================================================================
-- DIM_FECHA
-- ============================================================================
IF OBJECT_ID('dbo.dim_fecha', 'U') IS NULL
CREATE TABLE dbo.dim_fecha (
    fecha_key         INT NOT NULL PRIMARY KEY,      -- formato YYYYMMDD
    fecha             DATE NOT NULL,
    anio              INT NOT NULL,
    trimestre         INT NOT NULL,
    nombre_trimestre  VARCHAR(2) NOT NULL,            -- 'Q1'..'Q4'
    mes               INT NOT NULL,
    nombre_mes        VARCHAR(20) NOT NULL,
    mes_anio          VARCHAR(7) NOT NULL,            -- 'YYYY-MM'
    dia               INT NOT NULL,
    dia_semana        INT NOT NULL,                   -- 1=domingo .. 7=sábado
    nombre_dia        VARCHAR(20) NOT NULL,
    semana_anio       INT NOT NULL,
    es_fin_semana     BIT NOT NULL,

    CONSTRAINT uq_dim_fecha_fecha UNIQUE (fecha)
);
GO

-- ============================================================================
-- DIM_CLIENTE  (geografía y segmentación achatadas — ver documentación)
-- ============================================================================
IF OBJECT_ID('dbo.dim_cliente', 'U') IS NULL
CREATE TABLE dbo.dim_cliente (
    cliente_key         INT IDENTITY(1,1) PRIMARY KEY,
    cliente_id          BIGINT NULL,                  -- clave natural en el OLTP; NULL solo en el miembro "Desconocido"
    nombre              NVARCHAR(255) NOT NULL,
    email               NVARCHAR(255) NULL,
    segmento            NVARCHAR(50) NOT NULL,
    industria           NVARCHAR(100) NULL,
    tamano_empresa      NVARCHAR(50) NULL,
    pais                NVARCHAR(100) NULL,
    provincia           NVARCHAR(100) NULL,
    ciudad              NVARCHAR(100) NULL,
    fecha_adquisicion   DATETIME2 NULL,
    activo              BIT NOT NULL DEFAULT 1,
    actualizado_en      DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_dim_cliente_cliente_id UNIQUE (cliente_id)
);
GO

-- ============================================================================
-- DIM_PRODUCTO  (categoría/subcategoría/marca achatadas)
-- ============================================================================
IF OBJECT_ID('dbo.dim_producto', 'U') IS NULL
CREATE TABLE dbo.dim_producto (
    producto_key      INT IDENTITY(1,1) PRIMARY KEY,
    producto_id        BIGINT NULL,
    nombre              NVARCHAR(255) NOT NULL,
    sku                 NVARCHAR(50) NULL,
    categoria           NVARCHAR(100) NOT NULL,
    subcategoria        NVARCHAR(100) NULL,
    marca               NVARCHAR(100) NULL,
    precio_lista_actual DECIMAL(10,2) NULL,
    es_digital          BIT NOT NULL DEFAULT 0,
    activo              BIT NOT NULL DEFAULT 1,
    actualizado_en      DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_dim_producto_producto_id UNIQUE (producto_id)
);
GO

-- ============================================================================
-- DIM_VENDEDOR  (gerente resuelto por nombre, sin self-join en el reporte)
-- ============================================================================
IF OBJECT_ID('dbo.dim_vendedor', 'U') IS NULL
CREATE TABLE dbo.dim_vendedor (
    vendedor_key      INT IDENTITY(1,1) PRIMARY KEY,
    vendedor_id        BIGINT NULL,
    nombre              NVARCHAR(255) NOT NULL,
    equipo              NVARCHAR(100) NULL,
    territorio          NVARCHAR(100) NULL,
    gerente_nombre      NVARCHAR(255) NULL,
    activo              BIT NOT NULL DEFAULT 1,
    actualizado_en      DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT uq_dim_vendedor_vendedor_id UNIQUE (vendedor_id)
);
GO

-- ============================================================================
-- DIM_ESTADO_ORDEN  (dimensión "basura": estado + estado_pago combinados)
-- ============================================================================
IF OBJECT_ID('dbo.dim_estado_orden', 'U') IS NULL
CREATE TABLE dbo.dim_estado_orden (
    estado_orden_key  INT IDENTITY(1,1) PRIMARY KEY,
    estado              NVARCHAR(30) NOT NULL,
    estado_pago         NVARCHAR(30) NOT NULL,
    es_cancelada        BIT NOT NULL DEFAULT 0,
    es_completada       BIT NOT NULL DEFAULT 0,        -- estado = 'entregado'
    es_pago_al_dia      BIT NOT NULL DEFAULT 0,         -- estado_pago = 'pagado'

    CONSTRAINT uq_dim_estado_orden_combo UNIQUE (estado, estado_pago)
);
GO

-- ============================================================================
-- DIM_METODO_PAGO  (dimensión conformada: la usan fact_ventas y fact_pagos)
-- ============================================================================
IF OBJECT_ID('dbo.dim_metodo_pago', 'U') IS NULL
CREATE TABLE dbo.dim_metodo_pago (
    metodo_pago_key   INT IDENTITY(1,1) PRIMARY KEY,
    metodo_pago         NVARCHAR(50) NOT NULL,
    descripcion         NVARCHAR(100) NULL,

    CONSTRAINT uq_dim_metodo_pago_metodo UNIQUE (metodo_pago)
);
GO

-- ============================================================================
-- FACT_VENTAS   (grano: una línea de una orden)
-- ============================================================================
IF OBJECT_ID('dbo.fact_ventas', 'U') IS NULL
CREATE TABLE dbo.fact_ventas (
    fact_ventas_key      BIGINT IDENTITY(1,1) PRIMARY KEY,

    -- Claves foráneas a dimensiones
    fecha_key              INT NOT NULL,
    cliente_key             INT NOT NULL,
    producto_key            INT NOT NULL,
    vendedor_key            INT NOT NULL,               -- -1 = "Sin vendedor asignado"
    estado_orden_key        INT NOT NULL,
    metodo_pago_key         INT NOT NULL,                 -- -1 = "Desconocido"

    -- Dimensiones degeneradas (viven en el hecho, no ameritan tabla propia)
    orden_id                BIGINT NOT NULL,
    orden_detalle_id         BIGINT NOT NULL,

    -- Medidas
    cantidad                DECIMAL(10,2) NOT NULL,
    precio_unitario          DECIMAL(10,2) NOT NULL,
    porcentaje_descuento     DECIMAL(5,2) NOT NULL DEFAULT 0,
    monto_bruto_linea        DECIMAL(15,2) NOT NULL,      -- cantidad * precio_unitario, antes de descuento
    monto_descuento_linea    DECIMAL(15,2) NOT NULL,
    total_linea              DECIMAL(15,2) NOT NULL,      -- neto de descuento (lo que factura la línea)
    costo_linea              DECIMAL(15,2) NULL,
    margen_bruto_linea       DECIMAL(15,2) NULL,
    cantidad_devuelta        INT NOT NULL DEFAULT 0,

    CONSTRAINT fk_fact_ventas_fecha    FOREIGN KEY (fecha_key)    REFERENCES dbo.dim_fecha (fecha_key),
    CONSTRAINT fk_fact_ventas_cliente  FOREIGN KEY (cliente_key)  REFERENCES dbo.dim_cliente (cliente_key),
    CONSTRAINT fk_fact_ventas_producto FOREIGN KEY (producto_key) REFERENCES dbo.dim_producto (producto_key),
    CONSTRAINT fk_fact_ventas_vendedor FOREIGN KEY (vendedor_key) REFERENCES dbo.dim_vendedor (vendedor_key),
    CONSTRAINT fk_fact_ventas_estado   FOREIGN KEY (estado_orden_key) REFERENCES dbo.dim_estado_orden (estado_orden_key),
    CONSTRAINT fk_fact_ventas_metodo   FOREIGN KEY (metodo_pago_key)  REFERENCES dbo.dim_metodo_pago (metodo_pago_key)
);
GO

CREATE INDEX idx_fact_ventas_fecha    ON dbo.fact_ventas (fecha_key);
CREATE INDEX idx_fact_ventas_cliente  ON dbo.fact_ventas (cliente_key);
CREATE INDEX idx_fact_ventas_producto ON dbo.fact_ventas (producto_key);
CREATE INDEX idx_fact_ventas_vendedor ON dbo.fact_ventas (vendedor_key);
CREATE INDEX idx_fact_ventas_orden_id ON dbo.fact_ventas (orden_id);
GO

-- ============================================================================
-- FACT_PAGOS   (grano: un pago individual)
-- ============================================================================
IF OBJECT_ID('dbo.fact_pagos', 'U') IS NULL
CREATE TABLE dbo.fact_pagos (
    fact_pagos_key    BIGINT IDENTITY(1,1) PRIMARY KEY,

    fecha_key           INT NOT NULL,
    cliente_key          INT NOT NULL,
    metodo_pago_key      INT NOT NULL,                  -- -1 = "Desconocido"

    orden_id             BIGINT NOT NULL,
    pago_id              BIGINT NOT NULL,

    monto_pago           DECIMAL(15,2) NOT NULL,
    es_completado        BIT NOT NULL DEFAULT 0,

    CONSTRAINT fk_fact_pagos_fecha   FOREIGN KEY (fecha_key)      REFERENCES dbo.dim_fecha (fecha_key),
    CONSTRAINT fk_fact_pagos_cliente FOREIGN KEY (cliente_key)    REFERENCES dbo.dim_cliente (cliente_key),
    CONSTRAINT fk_fact_pagos_metodo  FOREIGN KEY (metodo_pago_key) REFERENCES dbo.dim_metodo_pago (metodo_pago_key)
);
GO

CREATE INDEX idx_fact_pagos_fecha   ON dbo.fact_pagos (fecha_key);
CREATE INDEX idx_fact_pagos_cliente ON dbo.fact_pagos (cliente_key);
GO

-- ============================================================================
-- FACT_DEVOLUCIONES   (grano: una devolución individual)
-- ============================================================================
IF OBJECT_ID('dbo.fact_devoluciones', 'U') IS NULL
CREATE TABLE dbo.fact_devoluciones (
    fact_devoluciones_key BIGINT IDENTITY(1,1) PRIMARY KEY,

    fecha_key               INT NOT NULL,
    cliente_key              INT NOT NULL,

    orden_id                 BIGINT NOT NULL,
    devolucion_id             BIGINT NOT NULL,

    motivo                   NVARCHAR(255) NULL,        -- dimensión degenerada
    estado_devolucion         NVARCHAR(50) NOT NULL,      -- dimensión degenerada

    monto_reembolso          DECIMAL(15,2) NOT NULL,

    CONSTRAINT fk_fact_devoluciones_fecha   FOREIGN KEY (fecha_key)   REFERENCES dbo.dim_fecha (fecha_key),
    CONSTRAINT fk_fact_devoluciones_cliente FOREIGN KEY (cliente_key) REFERENCES dbo.dim_cliente (cliente_key)
);
GO

CREATE INDEX idx_fact_devoluciones_fecha   ON dbo.fact_devoluciones (fecha_key);
CREATE INDEX idx_fact_devoluciones_cliente ON dbo.fact_devoluciones (cliente_key);
GO

-- ============================================================================
-- FIN DEL SCHEMA
-- ============================================================================
