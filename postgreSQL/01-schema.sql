-- ============================================================================
-- SCHEMA DE BASE DE DATOS - SISTEMA DE VENTAS
-- PostgreSQL 14+
-- ============================================================================
-- Este schema está diseñado para:
-- 1. Generar datos realistas de ventas
-- 2. Soportar análisis complejos en Power BI y dashboards custom
-- 3. Ser fácil de limpiar y resetear para pruebas
-- ============================================================================

-- EXTENSIONES REQUERIDAS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- DIMENSIÓN: CLIENTES
-- ============================================================================
CREATE TABLE IF NOT EXISTS clientes (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    telefono VARCHAR(20),

    -- Segmentación
    segmento VARCHAR(50) NOT NULL DEFAULT 'estandar',
        -- Valores: premium, estandar, prueba, vip, inactivo
    industria VARCHAR(100),
    tamaño_empresa VARCHAR(50),
        -- Valores: startup, pequeña, mediana, grande, corporacion

    -- Ubicación
    pais VARCHAR(100),
    provincia VARCHAR(100),
    ciudad VARCHAR(100),
    codigo_postal VARCHAR(20),

    -- Información financiera
    limite_credito NUMERIC(15,2),
    valor_vida_total NUMERIC(15,2) DEFAULT 0,

    -- Metadatos
    fecha_adquisicion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_ultima_compra TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    notas TEXT,

    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_clientes_segmento ON clientes(segmento);
CREATE INDEX idx_clientes_pais ON clientes(pais);
CREATE INDEX idx_clientes_activo ON clientes(activo);
CREATE INDEX idx_clientes_fecha_adquisicion ON clientes(fecha_adquisicion);

-- ============================================================================
-- DIMENSIÓN: PRODUCTOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS productos (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    nombre VARCHAR(255) NOT NULL,
    sku VARCHAR(50) UNIQUE NOT NULL,
    descripcion TEXT,

    -- Categorización
    categoria VARCHAR(100) NOT NULL,
    subcategoria VARCHAR(100),
    marca VARCHAR(100),

    -- Precios
    precio_lista NUMERIC(10,2) NOT NULL,
    precio_costo NUMERIC(10,2),

    -- Stock
    stock_actual INT DEFAULT 0,
    stock_minimo INT DEFAULT 10,

    -- Propiedades
    peso_kg NUMERIC(8,2),
    volumen_m3 NUMERIC(8,3),
    es_digital BOOLEAN DEFAULT FALSE,

    -- Ciclo de vida del producto
    fecha_lanzamiento DATE,
    fecha_descontinuacion DATE,
    activo BOOLEAN DEFAULT TRUE,

    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_productos_categoria ON productos(categoria);
CREATE INDEX idx_productos_sku ON productos(sku);
CREATE INDEX idx_productos_activo ON productos(activo);
CREATE INDEX idx_productos_marca ON productos(marca);

-- ============================================================================
-- DIMENSIÓN: VENDEDORES
-- ============================================================================
CREATE TABLE IF NOT EXISTS vendedores (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    telefono VARCHAR(20),

    -- Organización
    equipo VARCHAR(100),
    territorio VARCHAR(100),
    gerente_id BIGINT REFERENCES vendedores(id) ON DELETE SET NULL,

    -- Performance
    tasa_comision NUMERIC(5,2) DEFAULT 0,
    cuota_mensual NUMERIC(15,2),

    -- Estatus
    activo BOOLEAN DEFAULT TRUE,
    fecha_contratacion DATE,
    fecha_baja DATE,

    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_vendedores_equipo ON vendedores(equipo);
CREATE INDEX idx_vendedores_territorio ON vendedores(territorio);
CREATE INDEX idx_vendedores_activo ON vendedores(activo);

-- ============================================================================
-- HECHO: ÓRDENES DE VENTAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS ordenes (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),

    -- Foreign Keys
    cliente_id BIGINT NOT NULL REFERENCES clientes(id) ON DELETE RESTRICT,
    vendedor_id BIGINT REFERENCES vendedores(id) ON DELETE SET NULL,

    -- Fechas clave
    fecha_orden TIMESTAMP NOT NULL,
    fecha_entrega_prometida DATE,
    fecha_entrega_real DATE,

    -- Montos
    subtotal NUMERIC(15,2) NOT NULL DEFAULT 0,
    monto_descuento NUMERIC(15,2) DEFAULT 0,
    porcentaje_descuento NUMERIC(5,2) DEFAULT 0,
    monto_impuesto NUMERIC(15,2) DEFAULT 0,
    costo_envio NUMERIC(15,2) DEFAULT 0,
    monto_total NUMERIC(15,2) NOT NULL DEFAULT 0,

    -- Información de pago
    metodo_pago VARCHAR(50),
        -- Valores: tarjeta_credito, transferencia_bancaria, efectivo, cheque, otro
    estado_pago VARCHAR(50) DEFAULT 'pendiente',
        -- Valores: pendiente, parcial, pagado, vencido, reembolsado
    fecha_pago TIMESTAMP,

    -- Estado de la orden
    estado VARCHAR(50) DEFAULT 'pendiente',
        -- Valores: pendiente, confirmado, procesando, enviado, entregado, cancelado, devuelto

    -- Notas
    notas TEXT,
    notas_internas TEXT,

    -- Auditoría
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    creado_por VARCHAR(100)
);

CREATE INDEX idx_ordenes_cliente_id ON ordenes(cliente_id);
CREATE INDEX idx_ordenes_vendedor_id ON ordenes(vendedor_id);
CREATE INDEX idx_ordenes_fecha_orden ON ordenes(fecha_orden);
CREATE INDEX idx_ordenes_estado ON ordenes(estado);
CREATE INDEX idx_ordenes_estado_pago ON ordenes(estado_pago);
CREATE INDEX idx_ordenes_creado_en ON ordenes(creado_en);

-- ============================================================================
-- DETALLE: ÍTEMS DE ÓRDENES
-- ============================================================================
CREATE TABLE IF NOT EXISTS items_orden (
    id BIGSERIAL PRIMARY KEY,
    orden_id BIGINT NOT NULL REFERENCES ordenes(id) ON DELETE CASCADE,
    producto_id BIGINT NOT NULL REFERENCES productos(id) ON DELETE RESTRICT,

    -- Cantidad y precio
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL,
    porcentaje_descuento NUMERIC(5,2) DEFAULT 0,
    total_linea NUMERIC(15,2) GENERATED ALWAYS AS
        (cantidad * precio_unitario * (1 - porcentaje_descuento / 100)) STORED,

    -- Control de inventario
    ubicacion_almacen VARCHAR(100),
    completado BOOLEAN DEFAULT FALSE,

    -- Devoluciones
    cantidad_devuelta INT DEFAULT 0,
    motivo_devolucion VARCHAR(255),

    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_items_orden_orden_id ON items_orden(orden_id);
CREATE INDEX idx_items_orden_producto_id ON items_orden(producto_id);
CREATE INDEX idx_items_orden_completado ON items_orden(completado);

-- ============================================================================
-- TRANSACCIONES: PAGOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS pagos (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    orden_id BIGINT NOT NULL REFERENCES ordenes(id) ON DELETE RESTRICT,

    -- Monto
    monto NUMERIC(15,2) NOT NULL,
    fecha_pago TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Método
    metodo_pago VARCHAR(50) NOT NULL,
    numero_referencia VARCHAR(100),

    -- Estado
    estado VARCHAR(50) DEFAULT 'completado',
        -- Valores: pendiente, completado, fallido, reembolsado

    notas TEXT,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_pagos_orden_id ON pagos(orden_id);
CREATE INDEX idx_pagos_fecha_pago ON pagos(fecha_pago);
CREATE INDEX idx_pagos_estado ON pagos(estado);

-- ============================================================================
-- DEVOLUCIONES / REEMBOLSOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS devoluciones (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    orden_id BIGINT NOT NULL REFERENCES ordenes(id) ON DELETE RESTRICT,

    -- Información
    fecha_devolucion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo VARCHAR(255) NOT NULL,
    descripcion TEXT,

    -- Monto
    monto_reembolso NUMERIC(15,2) NOT NULL,
    fecha_reembolso TIMESTAMP,

    -- Estado
    estado VARCHAR(50) DEFAULT 'pendiente',
        -- Valores: pendiente, aprobado, rechazado, reembolsado, reembolso_parcial

    aprobado_por VARCHAR(100),
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_devoluciones_orden_id ON devoluciones(orden_id);
CREATE INDEX idx_devoluciones_fecha_devolucion ON devoluciones(fecha_devolucion);
CREATE INDEX idx_devoluciones_estado ON devoluciones(estado);

-- ============================================================================
-- INTERACCIONES CON CLIENTES (CRM)
-- ============================================================================
CREATE TABLE IF NOT EXISTS interacciones_clientes (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    cliente_id BIGINT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    vendedor_id BIGINT REFERENCES vendedores(id) ON DELETE SET NULL,

    -- Tipo de interacción
    tipo_interaccion VARCHAR(50) NOT NULL,
        -- Valores: llamada, email, reunion, demo, soporte, seguimiento

    -- Contenido
    asunto VARCHAR(255),
    notas TEXT,

    -- Resultado
    resultado VARCHAR(100),
        -- Valores: interesado, no_interesado, demo_programada, etc.
    fecha_proximo_seguimiento DATE,

    -- Metadatos
    fecha_interaccion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    duracion_minutos INT,

    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_interacciones_clientes_cliente_id ON interacciones_clientes(cliente_id);
CREATE INDEX idx_interacciones_clientes_fecha ON interacciones_clientes(fecha_interaccion);
CREATE INDEX idx_interacciones_clientes_vendedor_id ON interacciones_clientes(vendedor_id);

-- ============================================================================
-- CAMPAÑAS DE MARKETING
-- ============================================================================
CREATE TABLE IF NOT EXISTS campanas (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,

    -- Tipo y canal
    tipo_campana VARCHAR(100),
        -- Valores: email, webinar, feria, promocion, estacional
    canal VARCHAR(50),
        -- Valores: email, redes_sociales, correo_directo, eventos, referido, organico

    -- Período
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,

    -- Presupuesto
    presupuesto NUMERIC(15,2),
    gasto_real NUMERIC(15,2) DEFAULT 0,

    -- Performance
    impresiones INT DEFAULT 0,
    clics INT DEFAULT 0,
    conversiones INT DEFAULT 0,
    ingresos_generados NUMERIC(15,2) DEFAULT 0,

    estado VARCHAR(50) DEFAULT 'activa',
        -- Valores: planificada, activa, completada, cancelada

    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_campanas_fecha_inicio ON campanas(fecha_inicio);
CREATE INDEX idx_campanas_estado ON campanas(estado);

-- ============================================================================
-- RELACIÓN: CLIENTES - CAMPAÑAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS campanas_clientes (
    id BIGSERIAL PRIMARY KEY,
    campana_id BIGINT NOT NULL REFERENCES campanas(id) ON DELETE CASCADE,
    cliente_id BIGINT NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,

    -- Engagement
    fecha_contacto TIMESTAMP,
    abierto BOOLEAN DEFAULT FALSE,
    hizo_clic BOOLEAN DEFAULT FALSE,
    convirtio BOOLEAN DEFAULT FALSE,
    fecha_conversion TIMESTAMP,

    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_campana_cliente UNIQUE(campana_id, cliente_id)
);

CREATE INDEX idx_campanas_clientes_campana_id ON campanas_clientes(campana_id);
CREATE INDEX idx_campanas_clientes_cliente_id ON campanas_clientes(cliente_id);

-- ============================================================================
-- TABLA DE AUDITORÍA / CONTROL DE CARGAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS cargas_datos (
    id BIGSERIAL PRIMARY KEY,
    fecha_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo_carga VARCHAR(100),
        -- Valores: inicial, incremental, refresco, prueba
    registros_afectados INT,
    estado VARCHAR(50),
    notas TEXT
);

-- ============================================================================
-- COMENTARIOS DE TABLAS Y COLUMNAS
-- ============================================================================
COMMENT ON TABLE clientes IS 'Tabla de dimensión de clientes con información demográfica y de segmentación';
COMMENT ON TABLE productos IS 'Tabla de dimensión de productos con categorización y precios';
COMMENT ON TABLE ordenes IS 'Tabla de hechos de órdenes de ventas';
COMMENT ON TABLE items_orden IS 'Detalles de líneas en órdenes';
COMMENT ON TABLE pagos IS 'Transacciones de pagos y cobros';
COMMENT ON TABLE devoluciones IS 'Registro de devoluciones y reembolsos';
COMMENT ON COLUMN ordenes.monto_total IS 'Total final: subtotal - descuento + impuesto + envío';
COMMENT ON COLUMN items_orden.total_linea IS 'Generado automáticamente: cantidad * precio_unitario * (1 - descuento%)';

-- ============================================================================
-- TRIGGERS PARA MANTENER INTEGRIDAD DE DATOS
-- ============================================================================

-- Actualizar total de órdenes cuando se agregan ítems
CREATE OR REPLACE FUNCTION actualizar_total_orden()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE ordenes
    SET monto_total = COALESCE(
        (SELECT SUM(total_linea) FROM items_orden WHERE orden_id = NEW.orden_id),
        0
    ) + COALESCE(monto_impuesto, 0) + COALESCE(costo_envio, 0) - COALESCE(monto_descuento, 0),
        actualizado_en = CURRENT_TIMESTAMP
    WHERE id = NEW.orden_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_total_orden_insert
AFTER INSERT ON items_orden
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_orden();

CREATE TRIGGER trg_actualizar_total_orden_update
AFTER UPDATE ON items_orden
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_orden();

CREATE TRIGGER trg_actualizar_total_orden_delete
AFTER DELETE ON items_orden
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_orden();

-- Actualizar valor de vida del cliente
CREATE OR REPLACE FUNCTION actualizar_valor_vida_cliente()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE clientes
    SET valor_vida_total = COALESCE(
        (SELECT SUM(monto_total) FROM ordenes WHERE cliente_id = NEW.cliente_id AND estado != 'cancelado'),
        0
    ),
        fecha_ultima_compra = COALESCE(
            (SELECT MAX(fecha_orden) FROM ordenes WHERE cliente_id = NEW.cliente_id AND estado != 'cancelado'),
            fecha_ultima_compra
        ),
        actualizado_en = CURRENT_TIMESTAMP
    WHERE id = NEW.cliente_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_actualizar_valor_vida_cliente
AFTER INSERT OR UPDATE ON ordenes
FOR EACH ROW
EXECUTE FUNCTION actualizar_valor_vida_cliente();

-- Registrar en cargas_datos
CREATE OR REPLACE FUNCTION registrar_carga_datos(
    p_tipo_carga VARCHAR,
    p_registros_afectados INT,
    p_estado VARCHAR DEFAULT 'completado',
    p_notas TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_carga_id BIGINT;
BEGIN
    INSERT INTO cargas_datos (tipo_carga, registros_afectados, estado, notas)
    VALUES (p_tipo_carga, p_registros_afectados, p_estado, p_notas)
    RETURNING id INTO v_carga_id;

    RETURN v_carga_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FIN DEL SCHEMA
-- ============================================================================
