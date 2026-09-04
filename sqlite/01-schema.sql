-- ============================================================================
-- SCHEMA DE BASE DE DATOS - SISTEMA DE VENTAS
-- SQLite 3.35+ (usa columnas GENERATED, agregado desde 3.31.0)
-- ============================================================================
-- Este schema está diseñado para:
-- 1. Generar datos realistas de ventas
-- 2. Soportar análisis complejos en Power BI y dashboards custom
-- 3. Ser fácil de limpiar y resetear para pruebas
--
-- Equivalente funcional del schema de postgreSQL/ y t-sql/, adaptado a SQLite:
-- - No hay tipo UUID nativo: se usa TEXT con un DEFAULT que genera un UUID v4.
-- - No hay stored procedures/functions: la generación de datos (03-) y las
--   funciones analíticas (02-) se resuelven como scripts SQL planos.
-- - No hay TIMESTAMP nativo: las fechas se guardan como TEXT en formato ISO-8601.
--
-- IMPORTANTE: SQLite no aplica FOREIGN KEY por defecto en cada conexión.
-- Ejecutar siempre "PRAGMA foreign_keys = ON;" al abrir la base (ver abajo).
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- DIMENSIÓN: CLIENTES
-- ============================================================================
CREATE TABLE IF NOT EXISTS clientes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE DEFAULT (
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
              substr(hex(randomblob(2)), 2) || '-' ||
              substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' ||
              hex(randomblob(6)))
    ),
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    telefono VARCHAR(20),

    -- Segmentación
    segmento VARCHAR(50) NOT NULL DEFAULT 'estandar',
        -- Valores: premium, estandar, prueba, vip, inactivo
    industria VARCHAR(100),
    tamano_empresa VARCHAR(50),
        -- Valores: startup, pequeña, mediana, grande, corporacion

    -- Ubicación
    pais VARCHAR(100),
    provincia VARCHAR(100),
    ciudad VARCHAR(100),
    codigo_postal VARCHAR(20),

    -- Información financiera
    limite_credito DECIMAL(15,2),
    valor_vida_total DECIMAL(15,2) NOT NULL DEFAULT 0,

    -- Metadatos
    fecha_adquisicion TEXT NOT NULL DEFAULT (datetime('now')),
    fecha_ultima_compra TEXT,
    activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
    notas TEXT,

    creado_en TEXT NOT NULL DEFAULT (datetime('now')),
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_clientes_segmento ON clientes(segmento);
CREATE INDEX IF NOT EXISTS idx_clientes_pais ON clientes(pais);
CREATE INDEX IF NOT EXISTS idx_clientes_activo ON clientes(activo);
CREATE INDEX IF NOT EXISTS idx_clientes_fecha_adquisicion ON clientes(fecha_adquisicion);

-- ============================================================================
-- DIMENSIÓN: PRODUCTOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS productos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE DEFAULT (
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
              substr(hex(randomblob(2)), 2) || '-' ||
              substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' ||
              hex(randomblob(6)))
    ),
    nombre VARCHAR(255) NOT NULL,
    sku VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,

    -- Categorización
    categoria VARCHAR(100) NOT NULL,
    subcategoria VARCHAR(100),
    marca VARCHAR(100),

    -- Precios
    precio_lista DECIMAL(10,2) NOT NULL,
    precio_costo DECIMAL(10,2),

    -- Stock
    stock_actual INTEGER NOT NULL DEFAULT 0,
    stock_minimo INTEGER NOT NULL DEFAULT 10,

    -- Propiedades
    peso_kg DECIMAL(8,2),
    volumen_m3 DECIMAL(8,3),
    es_digital INTEGER NOT NULL DEFAULT 0 CHECK (es_digital IN (0, 1)),

    -- Ciclo de vida del producto
    fecha_lanzamiento TEXT,
    fecha_descontinuacion TEXT,
    activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),

    creado_en TEXT NOT NULL DEFAULT (datetime('now')),
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos(categoria);
CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos(activo);
CREATE INDEX IF NOT EXISTS idx_productos_marca ON productos(marca);

-- ============================================================================
-- DIMENSIÓN: VENDEDORES
-- ============================================================================
CREATE TABLE IF NOT EXISTS vendedores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE DEFAULT (
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
              substr(hex(randomblob(2)), 2) || '-' ||
              substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' ||
              hex(randomblob(6)))
    ),
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    telefono VARCHAR(20),

    -- Organización
    equipo VARCHAR(100),
    territorio VARCHAR(100),
    gerente_id INTEGER REFERENCES vendedores(id) ON DELETE SET NULL,

    -- Performance
    tasa_comision DECIMAL(5,2) NOT NULL DEFAULT 0,
    cuota_mensual DECIMAL(15,2),

    -- Estatus
    activo INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0, 1)),
    fecha_contratacion TEXT,
    fecha_baja TEXT,

    creado_en TEXT NOT NULL DEFAULT (datetime('now')),
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_vendedores_equipo ON vendedores(equipo);
CREATE INDEX IF NOT EXISTS idx_vendedores_territorio ON vendedores(territorio);
CREATE INDEX IF NOT EXISTS idx_vendedores_activo ON vendedores(activo);
CREATE INDEX IF NOT EXISTS idx_vendedores_gerente_id ON vendedores(gerente_id);

-- ============================================================================
-- HECHO: ÓRDENES DE VENTAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS orden_encabezado (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE DEFAULT (
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
              substr(hex(randomblob(2)), 2) || '-' ||
              substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' ||
              hex(randomblob(6)))
    ),

    -- Foreign Keys
    cliente_id INTEGER NOT NULL REFERENCES clientes(id) ON DELETE RESTRICT,
    vendedor_id INTEGER REFERENCES vendedores(id) ON DELETE SET NULL,

    -- Fechas clave
    fecha_orden TEXT NOT NULL,
    fecha_entrega_prometida TEXT,
    fecha_entrega_real TEXT,

    -- Montos
    subtotal DECIMAL(15,2) NOT NULL DEFAULT 0,
    monto_descuento DECIMAL(15,2) NOT NULL DEFAULT 0,
    porcentaje_descuento DECIMAL(5,2) NOT NULL DEFAULT 0,
    monto_impuesto DECIMAL(15,2) NOT NULL DEFAULT 0,
    costo_envio DECIMAL(15,2) NOT NULL DEFAULT 0,
    monto_total DECIMAL(15,2) NOT NULL DEFAULT 0,

    -- Información de pago
    metodo_pago VARCHAR(50),
        -- Valores: tarjeta_credito, transferencia_bancaria, efectivo, cheque, otro
    estado_pago VARCHAR(50) NOT NULL DEFAULT 'pendiente',
        -- Valores: pendiente, parcial, pagado, vencido, reembolsado
    fecha_pago TEXT,

    -- Estado de la orden
    estado VARCHAR(50) NOT NULL DEFAULT 'pendiente',
        -- Valores: pendiente, confirmado, procesando, enviado, entregado, cancelado, devuelto

    -- Notas
    notas TEXT,
    notas_internas TEXT,

    -- Auditoría
    creado_en TEXT NOT NULL DEFAULT (datetime('now')),
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now')),
    creado_por VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_orden_encabezado_cliente_id ON orden_encabezado(cliente_id);
CREATE INDEX IF NOT EXISTS idx_orden_encabezado_vendedor_id ON orden_encabezado(vendedor_id);
CREATE INDEX IF NOT EXISTS idx_orden_encabezado_fecha_orden ON orden_encabezado(fecha_orden);
CREATE INDEX IF NOT EXISTS idx_orden_encabezado_estado ON orden_encabezado(estado);
CREATE INDEX IF NOT EXISTS idx_orden_encabezado_estado_pago ON orden_encabezado(estado_pago);
CREATE INDEX IF NOT EXISTS idx_orden_encabezado_creado_en ON orden_encabezado(creado_en);

-- ============================================================================
-- DETALLE: ÍTEMS DE ÓRDENES
-- ============================================================================
CREATE TABLE IF NOT EXISTS orden_detalles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    orden_id INTEGER NOT NULL REFERENCES orden_encabezado(id) ON DELETE CASCADE,
    producto_id INTEGER NOT NULL REFERENCES productos(id) ON DELETE RESTRICT,

    -- Cantidad y precio
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL,
    porcentaje_descuento DECIMAL(5,2) NOT NULL DEFAULT 0,
    total_linea DECIMAL(15,2) GENERATED ALWAYS AS
        (cantidad * precio_unitario * (1 - porcentaje_descuento / 100.0)) STORED,

    -- Control de inventario
    ubicacion_almacen VARCHAR(100),
    completado INTEGER NOT NULL DEFAULT 0 CHECK (completado IN (0, 1)),

    -- Devoluciones
    cantidad_devuelta INTEGER NOT NULL DEFAULT 0,
    motivo_devolucion VARCHAR(255),

    creado_en TEXT NOT NULL DEFAULT (datetime('now')),
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_orden_detalles_orden_id ON orden_detalles(orden_id);
CREATE INDEX IF NOT EXISTS idx_orden_detalles_producto_id ON orden_detalles(producto_id);
CREATE INDEX IF NOT EXISTS idx_orden_detalles_completado ON orden_detalles(completado);

-- ============================================================================
-- TRANSACCIONES: PAGOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS pagos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE DEFAULT (
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
              substr(hex(randomblob(2)), 2) || '-' ||
              substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' ||
              hex(randomblob(6)))
    ),
    orden_id INTEGER NOT NULL REFERENCES orden_encabezado(id) ON DELETE RESTRICT,

    -- Monto
    monto DECIMAL(15,2) NOT NULL,
    fecha_pago TEXT NOT NULL DEFAULT (datetime('now')),

    -- Método
    metodo_pago VARCHAR(50) NOT NULL,
    numero_referencia VARCHAR(100),

    -- Estado
    estado VARCHAR(50) NOT NULL DEFAULT 'completado',
        -- Valores: pendiente, completado, fallido, reembolsado

    notas TEXT,
    creado_en TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_pagos_orden_id ON pagos(orden_id);
CREATE INDEX IF NOT EXISTS idx_pagos_fecha_pago ON pagos(fecha_pago);
CREATE INDEX IF NOT EXISTS idx_pagos_estado ON pagos(estado);

-- ============================================================================
-- DEVOLUCIONES / REEMBOLSOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS devoluciones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE DEFAULT (
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
              substr(hex(randomblob(2)), 2) || '-' ||
              substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' ||
              hex(randomblob(6)))
    ),
    orden_id INTEGER NOT NULL REFERENCES orden_encabezado(id) ON DELETE RESTRICT,

    -- Información
    fecha_devolucion TEXT NOT NULL DEFAULT (datetime('now')),
    motivo VARCHAR(255) NOT NULL,
    descripcion TEXT,

    -- Monto
    monto_reembolso DECIMAL(15,2) NOT NULL,
    fecha_reembolso TEXT,

    -- Estado
    estado VARCHAR(50) NOT NULL DEFAULT 'pendiente',
        -- Valores: pendiente, aprobado, rechazado, reembolsado, reembolso_parcial

    aprobado_por VARCHAR(100),
    creado_en TEXT NOT NULL DEFAULT (datetime('now')),
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_devoluciones_orden_id ON devoluciones(orden_id);
CREATE INDEX IF NOT EXISTS idx_devoluciones_fecha_devolucion ON devoluciones(fecha_devolucion);
CREATE INDEX IF NOT EXISTS idx_devoluciones_estado ON devoluciones(estado);

-- ============================================================================
-- INTERACCIONES CON CLIENTES (CRM)
-- ============================================================================
CREATE TABLE IF NOT EXISTS interacciones_clientes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE DEFAULT (
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
              substr(hex(randomblob(2)), 2) || '-' ||
              substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' ||
              hex(randomblob(6)))
    ),
    cliente_id INTEGER NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    vendedor_id INTEGER REFERENCES vendedores(id) ON DELETE SET NULL,

    -- Tipo de interacción
    tipo_interaccion VARCHAR(50) NOT NULL,
        -- Valores: llamada, email, reunion, demo, soporte, seguimiento

    -- Contenido
    asunto VARCHAR(255),
    notas TEXT,

    -- Resultado
    resultado VARCHAR(100),
        -- Valores: interesado, no_interesado, demo_programada, etc.
    fecha_proximo_seguimiento TEXT,

    -- Metadatos
    fecha_interaccion TEXT NOT NULL DEFAULT (datetime('now')),
    duracion_minutos INTEGER,

    creado_en TEXT NOT NULL DEFAULT (datetime('now')),
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_interacciones_clientes_cliente_id ON interacciones_clientes(cliente_id);
CREATE INDEX IF NOT EXISTS idx_interacciones_clientes_fecha ON interacciones_clientes(fecha_interaccion);
CREATE INDEX IF NOT EXISTS idx_interacciones_clientes_vendedor_id ON interacciones_clientes(vendedor_id);

-- ============================================================================
-- CAMPAÑAS DE MARKETING
-- ============================================================================
CREATE TABLE IF NOT EXISTS campanas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL UNIQUE DEFAULT (
        lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
              substr(hex(randomblob(2)), 2) || '-' ||
              substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' ||
              hex(randomblob(6)))
    ),
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,

    -- Tipo y canal
    tipo_campana VARCHAR(100),
        -- Valores: email, webinar, feria, promocion, estacional
    canal VARCHAR(50),
        -- Valores: email, redes_sociales, correo_directo, eventos, referido, organico

    -- Período
    fecha_inicio TEXT NOT NULL,
    fecha_fin TEXT,

    -- Presupuesto
    presupuesto DECIMAL(15,2),
    gasto_real DECIMAL(15,2) NOT NULL DEFAULT 0,

    -- Performance
    impresiones INTEGER NOT NULL DEFAULT 0,
    clics INTEGER NOT NULL DEFAULT 0,
    conversiones INTEGER NOT NULL DEFAULT 0,
    ingresos_generados DECIMAL(15,2) NOT NULL DEFAULT 0,

    estado VARCHAR(50) NOT NULL DEFAULT 'activa',
        -- Valores: planificada, activa, completada, cancelada

    creado_en TEXT NOT NULL DEFAULT (datetime('now')),
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_campanas_fecha_inicio ON campanas(fecha_inicio);
CREATE INDEX IF NOT EXISTS idx_campanas_estado ON campanas(estado);

-- ============================================================================
-- RELACIÓN: CLIENTES - CAMPAÑAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS campanas_clientes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    campana_id INTEGER NOT NULL REFERENCES campanas(id) ON DELETE CASCADE,
    cliente_id INTEGER NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,

    -- Engagement
    fecha_contacto TEXT,
    abierto INTEGER NOT NULL DEFAULT 0 CHECK (abierto IN (0, 1)),
    hizo_clic INTEGER NOT NULL DEFAULT 0 CHECK (hizo_clic IN (0, 1)),
    convirtio INTEGER NOT NULL DEFAULT 0 CHECK (convirtio IN (0, 1)),
    fecha_conversion TEXT,

    creado_en TEXT NOT NULL DEFAULT (datetime('now')),

    UNIQUE (campana_id, cliente_id)
);

CREATE INDEX IF NOT EXISTS idx_campanas_clientes_campana_id ON campanas_clientes(campana_id);
CREATE INDEX IF NOT EXISTS idx_campanas_clientes_cliente_id ON campanas_clientes(cliente_id);

-- ============================================================================
-- TABLA DE AUDITORÍA / CONTROL DE CARGAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS cargas_datos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fecha_carga TEXT NOT NULL DEFAULT (datetime('now')),
    tipo_carga VARCHAR(100),
        -- Valores: inicial, incremental, refresco, prueba
    registros_afectados INTEGER,
    estado VARCHAR(50),
    notas TEXT
);

-- ============================================================================
-- TRIGGERS PARA MANTENER INTEGRIDAD DE DATOS
-- ============================================================================

-- Actualizar total de la orden cuando se agregan/modifican/eliminan ítems
CREATE TRIGGER IF NOT EXISTS trg_orden_detalles_ai_total
AFTER INSERT ON orden_detalles
BEGIN
    UPDATE orden_encabezado
    SET monto_total = COALESCE(
            (SELECT SUM(total_linea) FROM orden_detalles WHERE orden_id = NEW.orden_id), 0
        ) + COALESCE(monto_impuesto, 0) + COALESCE(costo_envio, 0) - COALESCE(monto_descuento, 0),
        actualizado_en = datetime('now')
    WHERE id = NEW.orden_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_orden_detalles_au_total
AFTER UPDATE ON orden_detalles
BEGIN
    UPDATE orden_encabezado
    SET monto_total = COALESCE(
            (SELECT SUM(total_linea) FROM orden_detalles WHERE orden_id = NEW.orden_id), 0
        ) + COALESCE(monto_impuesto, 0) + COALESCE(costo_envio, 0) - COALESCE(monto_descuento, 0),
        actualizado_en = datetime('now')
    WHERE id = NEW.orden_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_orden_detalles_ad_total
AFTER DELETE ON orden_detalles
BEGIN
    UPDATE orden_encabezado
    SET monto_total = COALESCE(
            (SELECT SUM(total_linea) FROM orden_detalles WHERE orden_id = OLD.orden_id), 0
        ) + COALESCE(monto_impuesto, 0) + COALESCE(costo_envio, 0) - COALESCE(monto_descuento, 0),
        actualizado_en = datetime('now')
    WHERE id = OLD.orden_id;
END;

-- Actualizar valor de vida del cliente al insertar o modificar una orden
CREATE TRIGGER IF NOT EXISTS trg_orden_encabezado_ai_valor_vida
AFTER INSERT ON orden_encabezado
BEGIN
    UPDATE clientes
    SET valor_vida_total = COALESCE(
            (SELECT SUM(monto_total) FROM orden_encabezado WHERE cliente_id = NEW.cliente_id AND estado <> 'cancelado'), 0
        ),
        fecha_ultima_compra = COALESCE(
            (SELECT MAX(fecha_orden) FROM orden_encabezado WHERE cliente_id = NEW.cliente_id AND estado <> 'cancelado'),
            fecha_ultima_compra
        ),
        actualizado_en = datetime('now')
    WHERE id = NEW.cliente_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_orden_encabezado_au_valor_vida
AFTER UPDATE ON orden_encabezado
BEGIN
    UPDATE clientes
    SET valor_vida_total = COALESCE(
            (SELECT SUM(monto_total) FROM orden_encabezado WHERE cliente_id = NEW.cliente_id AND estado <> 'cancelado'), 0
        ),
        fecha_ultima_compra = COALESCE(
            (SELECT MAX(fecha_orden) FROM orden_encabezado WHERE cliente_id = NEW.cliente_id AND estado <> 'cancelado'),
            fecha_ultima_compra
        ),
        actualizado_en = datetime('now')
    WHERE id = NEW.cliente_id;
END;

-- ============================================================================
-- FIN DEL SCHEMA
-- ============================================================================
