-- ============================================================================
-- SCHEMA DE BASE DE DATOS - SISTEMA DE VENTAS
-- MySQL 8.0+
-- ============================================================================
-- Este schema está diseñado para:
-- 1. Generar datos realistas de ventas
-- 2. Soportar análisis complejos en Power BI y dashboards custom
-- 3. Ser fácil de limpiar y resetear para pruebas
--
-- Equivalente funcional del schema de postgreSQL/ y t-sql/, adaptado a MySQL:
-- - BIGSERIAL/IDENTITY -> BIGINT AUTO_INCREMENT
-- - UUID nativo -> CHAR(36) DEFAULT (UUID())
-- - NUMERIC -> DECIMAL
-- - Columna GENERATED ALWAYS AS (...) STORED (soportada desde MySQL 5.7.6)
-- ============================================================================

CREATE DATABASE IF NOT EXISTS ventas_test
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE ventas_test;

-- ============================================================================
-- DIMENSIÓN: CLIENTES
-- ============================================================================
CREATE TABLE IF NOT EXISTS clientes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) NULL,
    telefono VARCHAR(20) NULL,

    -- Segmentación
    segmento VARCHAR(50) NOT NULL DEFAULT 'estandar',
        -- Valores: premium, estandar, prueba, vip, inactivo
    industria VARCHAR(100) NULL,
    tamano_empresa VARCHAR(50) NULL,
        -- Valores: startup, pequeña, mediana, grande, corporacion

    -- Ubicación
    pais VARCHAR(100) NULL,
    provincia VARCHAR(100) NULL,
    ciudad VARCHAR(100) NULL,
    codigo_postal VARCHAR(20) NULL,

    -- Información financiera
    limite_credito DECIMAL(15,2) NULL,
    valor_vida_total DECIMAL(15,2) NOT NULL DEFAULT 0,

    -- Metadatos
    fecha_adquisicion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_ultima_compra DATETIME NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    notas TEXT NULL,

    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_clientes_uuid (uuid),
    UNIQUE KEY uq_clientes_email (email),
    KEY idx_clientes_segmento (segmento),
    KEY idx_clientes_pais (pais),
    KEY idx_clientes_activo (activo),
    KEY idx_clientes_fecha_adquisicion (fecha_adquisicion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- DIMENSIÓN: PRODUCTOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS productos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    nombre VARCHAR(255) NOT NULL,
    sku VARCHAR(50) NOT NULL,
    descripcion TEXT NULL,

    -- Categorización
    categoria VARCHAR(100) NOT NULL,
    subcategoria VARCHAR(100) NULL,
    marca VARCHAR(100) NULL,

    -- Precios
    precio_lista DECIMAL(10,2) NOT NULL,
    precio_costo DECIMAL(10,2) NULL,

    -- Stock
    stock_actual INT NOT NULL DEFAULT 0,
    stock_minimo INT NOT NULL DEFAULT 10,

    -- Propiedades
    peso_kg DECIMAL(8,2) NULL,
    volumen_m3 DECIMAL(8,3) NULL,
    es_digital TINYINT(1) NOT NULL DEFAULT 0,

    -- Ciclo de vida del producto
    fecha_lanzamiento DATE NULL,
    fecha_descontinuacion DATE NULL,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_productos_uuid (uuid),
    UNIQUE KEY uq_productos_sku (sku),
    KEY idx_productos_categoria (categoria),
    KEY idx_productos_activo (activo),
    KEY idx_productos_marca (marca)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- DIMENSIÓN: VENDEDORES
-- ============================================================================
CREATE TABLE IF NOT EXISTS vendedores (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    nombre VARCHAR(255) NOT NULL,
    email VARCHAR(255) NULL,
    telefono VARCHAR(20) NULL,

    -- Organización
    equipo VARCHAR(100) NULL,
    territorio VARCHAR(100) NULL,
    gerente_id BIGINT UNSIGNED NULL,

    -- Performance
    tasa_comision DECIMAL(5,2) NOT NULL DEFAULT 0,
    cuota_mensual DECIMAL(15,2) NULL,

    -- Estatus
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_contratacion DATE NULL,
    fecha_baja DATE NULL,

    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_vendedores_uuid (uuid),
    UNIQUE KEY uq_vendedores_email (email),
    KEY idx_vendedores_equipo (equipo),
    KEY idx_vendedores_territorio (territorio),
    KEY idx_vendedores_activo (activo),
    KEY idx_vendedores_gerente_id (gerente_id),
    CONSTRAINT fk_vendedores_gerente FOREIGN KEY (gerente_id)
        REFERENCES vendedores (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- HECHO: ÓRDENES DE VENTAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS orden_encabezado (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),

    -- Foreign Keys
    cliente_id BIGINT UNSIGNED NOT NULL,
    vendedor_id BIGINT UNSIGNED NULL,

    -- Fechas clave
    fecha_orden DATETIME NOT NULL,
    fecha_entrega_prometida DATE NULL,
    fecha_entrega_real DATE NULL,

    -- Montos
    subtotal DECIMAL(15,2) NOT NULL DEFAULT 0,
    monto_descuento DECIMAL(15,2) NOT NULL DEFAULT 0,
    porcentaje_descuento DECIMAL(5,2) NOT NULL DEFAULT 0,
    monto_impuesto DECIMAL(15,2) NOT NULL DEFAULT 0,
    costo_envio DECIMAL(15,2) NOT NULL DEFAULT 0,
    monto_total DECIMAL(15,2) NOT NULL DEFAULT 0,

    -- Información de pago
    metodo_pago VARCHAR(50) NULL,
        -- Valores: tarjeta_credito, transferencia_bancaria, efectivo, cheque, otro
    estado_pago VARCHAR(50) NOT NULL DEFAULT 'pendiente',
        -- Valores: pendiente, parcial, pagado, vencido, reembolsado
    fecha_pago DATETIME NULL,

    -- Estado de la orden
    estado VARCHAR(50) NOT NULL DEFAULT 'pendiente',
        -- Valores: pendiente, confirmado, procesando, enviado, entregado, cancelado, devuelto

    -- Notas
    notas TEXT NULL,
    notas_internas TEXT NULL,

    -- Auditoría
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    creado_por VARCHAR(100) NULL,

    UNIQUE KEY uq_orden_encabezado_uuid (uuid),
    KEY idx_orden_encabezado_cliente_id (cliente_id),
    KEY idx_orden_encabezado_vendedor_id (vendedor_id),
    KEY idx_orden_encabezado_fecha_orden (fecha_orden),
    KEY idx_orden_encabezado_estado (estado),
    KEY idx_orden_encabezado_estado_pago (estado_pago),
    KEY idx_orden_encabezado_creado_en (creado_en),
    CONSTRAINT fk_orden_encabezado_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id),
    CONSTRAINT fk_orden_encabezado_vendedor FOREIGN KEY (vendedor_id) REFERENCES vendedores (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- DETALLE: ÍTEMS DE ÓRDENES
-- ============================================================================
CREATE TABLE IF NOT EXISTS orden_detalles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    orden_id BIGINT UNSIGNED NOT NULL,
    producto_id BIGINT UNSIGNED NOT NULL,

    -- Cantidad y precio
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    porcentaje_descuento DECIMAL(5,2) NOT NULL DEFAULT 0,
    total_linea DECIMAL(15,2) GENERATED ALWAYS AS
        (cantidad * precio_unitario * (1 - porcentaje_descuento / 100)) STORED,

    -- Control de inventario
    ubicacion_almacen VARCHAR(100) NULL,
    completado TINYINT(1) NOT NULL DEFAULT 0,

    -- Devoluciones
    cantidad_devuelta INT NOT NULL DEFAULT 0,
    motivo_devolucion VARCHAR(255) NULL,

    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT chk_orden_detalles_cantidad CHECK (cantidad > 0),
    KEY idx_orden_detalles_orden_id (orden_id),
    KEY idx_orden_detalles_producto_id (producto_id),
    KEY idx_orden_detalles_completado (completado),
    CONSTRAINT fk_orden_detalles_orden FOREIGN KEY (orden_id) REFERENCES orden_encabezado (id) ON DELETE CASCADE,
    CONSTRAINT fk_orden_detalles_producto FOREIGN KEY (producto_id) REFERENCES productos (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TRANSACCIONES: PAGOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS pagos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    orden_id BIGINT UNSIGNED NOT NULL,

    -- Monto
    monto DECIMAL(15,2) NOT NULL,
    fecha_pago DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Método
    metodo_pago VARCHAR(50) NOT NULL,
    numero_referencia VARCHAR(100) NULL,

    -- Estado
    estado VARCHAR(50) NOT NULL DEFAULT 'completado',
        -- Valores: pendiente, completado, fallido, reembolsado

    notas TEXT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_pagos_uuid (uuid),
    KEY idx_pagos_orden_id (orden_id),
    KEY idx_pagos_fecha_pago (fecha_pago),
    KEY idx_pagos_estado (estado),
    CONSTRAINT fk_pagos_orden FOREIGN KEY (orden_id) REFERENCES orden_encabezado (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- DEVOLUCIONES / REEMBOLSOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS devoluciones (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    orden_id BIGINT UNSIGNED NOT NULL,

    -- Información
    fecha_devolucion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo VARCHAR(255) NOT NULL,
    descripcion TEXT NULL,

    -- Monto
    monto_reembolso DECIMAL(15,2) NOT NULL,
    fecha_reembolso DATETIME NULL,

    -- Estado
    estado VARCHAR(50) NOT NULL DEFAULT 'pendiente',
        -- Valores: pendiente, aprobado, rechazado, reembolsado, reembolso_parcial

    aprobado_por VARCHAR(100) NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_devoluciones_uuid (uuid),
    KEY idx_devoluciones_orden_id (orden_id),
    KEY idx_devoluciones_fecha_devolucion (fecha_devolucion),
    KEY idx_devoluciones_estado (estado),
    CONSTRAINT fk_devoluciones_orden FOREIGN KEY (orden_id) REFERENCES orden_encabezado (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- INTERACCIONES CON CLIENTES (CRM)
-- ============================================================================
CREATE TABLE IF NOT EXISTS interacciones_clientes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    cliente_id BIGINT UNSIGNED NOT NULL,
    vendedor_id BIGINT UNSIGNED NULL,

    -- Tipo de interacción
    tipo_interaccion VARCHAR(50) NOT NULL,
        -- Valores: llamada, email, reunion, demo, soporte, seguimiento

    -- Contenido
    asunto VARCHAR(255) NULL,
    notas TEXT NULL,

    -- Resultado
    resultado VARCHAR(100) NULL,
        -- Valores: interesado, no_interesado, demo_programada, etc.
    fecha_proximo_seguimiento DATE NULL,

    -- Metadatos
    fecha_interaccion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    duracion_minutos INT NULL,

    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_interacciones_clientes_uuid (uuid),
    KEY idx_interacciones_clientes_cliente_id (cliente_id),
    KEY idx_interacciones_clientes_fecha (fecha_interaccion),
    KEY idx_interacciones_clientes_vendedor_id (vendedor_id),
    CONSTRAINT fk_interacciones_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE,
    CONSTRAINT fk_interacciones_vendedor FOREIGN KEY (vendedor_id) REFERENCES vendedores (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- CAMPAÑAS DE MARKETING
-- ============================================================================
CREATE TABLE IF NOT EXISTS campanas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    uuid CHAR(36) NOT NULL DEFAULT (UUID()),
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT NULL,

    -- Tipo y canal
    tipo_campana VARCHAR(100) NULL,
        -- Valores: email, webinar, feria, promocion, estacional
    canal VARCHAR(50) NULL,
        -- Valores: email, redes_sociales, correo_directo, eventos, referido, organico

    -- Período
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NULL,

    -- Presupuesto
    presupuesto DECIMAL(15,2) NULL,
    gasto_real DECIMAL(15,2) NOT NULL DEFAULT 0,

    -- Performance
    impresiones INT NOT NULL DEFAULT 0,
    clics INT NOT NULL DEFAULT 0,
    conversiones INT NOT NULL DEFAULT 0,
    ingresos_generados DECIMAL(15,2) NOT NULL DEFAULT 0,

    estado VARCHAR(50) NOT NULL DEFAULT 'activa',
        -- Valores: planificada, activa, completada, cancelada

    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uq_campanas_uuid (uuid),
    KEY idx_campanas_fecha_inicio (fecha_inicio),
    KEY idx_campanas_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- RELACIÓN: CLIENTES - CAMPAÑAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS campanas_clientes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    campana_id BIGINT UNSIGNED NOT NULL,
    cliente_id BIGINT UNSIGNED NOT NULL,

    -- Engagement
    fecha_contacto DATETIME NULL,
    abierto TINYINT(1) NOT NULL DEFAULT 0,
    hizo_clic TINYINT(1) NOT NULL DEFAULT 0,
    convirtio TINYINT(1) NOT NULL DEFAULT 0,
    fecha_conversion DATETIME NULL,

    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uq_campana_cliente (campana_id, cliente_id),
    KEY idx_campanas_clientes_campana_id (campana_id),
    KEY idx_campanas_clientes_cliente_id (cliente_id),
    CONSTRAINT fk_campanas_clientes_campana FOREIGN KEY (campana_id) REFERENCES campanas (id) ON DELETE CASCADE,
    CONSTRAINT fk_campanas_clientes_cliente FOREIGN KEY (cliente_id) REFERENCES clientes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TABLA DE AUDITORÍA / CONTROL DE CARGAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS cargas_datos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fecha_carga DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_carga VARCHAR(100) NULL,
        -- Valores: inicial, incremental, refresco, prueba
    registros_afectados INT NULL,
    estado VARCHAR(50) NULL,
    notas TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- TRIGGERS PARA MANTENER INTEGRIDAD DE DATOS
-- ============================================================================
DELIMITER //

-- Actualizar total de la orden cuando se agregan/modifican/eliminan ítems
CREATE TRIGGER trg_orden_detalles_ai_total
AFTER INSERT ON orden_detalles
FOR EACH ROW
BEGIN
    UPDATE orden_encabezado
    SET monto_total = COALESCE(
            (SELECT SUM(total_linea) FROM orden_detalles WHERE orden_id = NEW.orden_id), 0
        ) + COALESCE(monto_impuesto, 0) + COALESCE(costo_envio, 0) - COALESCE(monto_descuento, 0),
        actualizado_en = CURRENT_TIMESTAMP
    WHERE id = NEW.orden_id;
END//

CREATE TRIGGER trg_orden_detalles_au_total
AFTER UPDATE ON orden_detalles
FOR EACH ROW
BEGIN
    UPDATE orden_encabezado
    SET monto_total = COALESCE(
            (SELECT SUM(total_linea) FROM orden_detalles WHERE orden_id = NEW.orden_id), 0
        ) + COALESCE(monto_impuesto, 0) + COALESCE(costo_envio, 0) - COALESCE(monto_descuento, 0),
        actualizado_en = CURRENT_TIMESTAMP
    WHERE id = NEW.orden_id;
END//

CREATE TRIGGER trg_orden_detalles_ad_total
AFTER DELETE ON orden_detalles
FOR EACH ROW
BEGIN
    UPDATE orden_encabezado
    SET monto_total = COALESCE(
            (SELECT SUM(total_linea) FROM orden_detalles WHERE orden_id = OLD.orden_id), 0
        ) + COALESCE(monto_impuesto, 0) + COALESCE(costo_envio, 0) - COALESCE(monto_descuento, 0),
        actualizado_en = CURRENT_TIMESTAMP
    WHERE id = OLD.orden_id;
END//

-- Actualizar valor de vida del cliente al insertar o modificar una orden
CREATE TRIGGER trg_orden_encabezado_ai_valor_vida
AFTER INSERT ON orden_encabezado
FOR EACH ROW
BEGIN
    UPDATE clientes
    SET valor_vida_total = COALESCE(
            (SELECT SUM(monto_total) FROM orden_encabezado WHERE cliente_id = NEW.cliente_id AND estado <> 'cancelado'), 0
        ),
        fecha_ultima_compra = COALESCE(
            (SELECT MAX(fecha_orden) FROM orden_encabezado WHERE cliente_id = NEW.cliente_id AND estado <> 'cancelado'),
            fecha_ultima_compra
        ),
        actualizado_en = CURRENT_TIMESTAMP
    WHERE id = NEW.cliente_id;
END//

CREATE TRIGGER trg_orden_encabezado_au_valor_vida
AFTER UPDATE ON orden_encabezado
FOR EACH ROW
BEGIN
    UPDATE clientes
    SET valor_vida_total = COALESCE(
            (SELECT SUM(monto_total) FROM orden_encabezado WHERE cliente_id = NEW.cliente_id AND estado <> 'cancelado'), 0
        ),
        fecha_ultima_compra = COALESCE(
            (SELECT MAX(fecha_orden) FROM orden_encabezado WHERE cliente_id = NEW.cliente_id AND estado <> 'cancelado'),
            fecha_ultima_compra
        ),
        actualizado_en = CURRENT_TIMESTAMP
    WHERE id = NEW.cliente_id;
END//

DELIMITER ;

-- ============================================================================
-- PROCEDIMIENTO: Registrar en cargas_datos
-- ============================================================================
DELIMITER //

CREATE PROCEDURE sp_registrar_carga_datos(
    IN p_tipo_carga VARCHAR(100),
    IN p_registros_afectados INT,
    IN p_estado VARCHAR(50),
    IN p_notas TEXT
)
BEGIN
    INSERT INTO cargas_datos (tipo_carga, registros_afectados, estado, notas)
    VALUES (p_tipo_carga, p_registros_afectados, COALESCE(p_estado, 'completado'), p_notas);

    SELECT LAST_INSERT_ID() AS carga_id;
END//

DELIMITER ;

-- ============================================================================
-- FIN DEL SCHEMA
-- ============================================================================
