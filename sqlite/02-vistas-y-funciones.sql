-- ============================================================================
-- VISTAS Y ANÁLISIS PARA DASHBOARDS
-- SQLite 3.35+
-- ============================================================================
-- NOTA: SQLite no soporta stored procedures/functions ni vistas materializadas.
-- Por eso:
-- - Las "funciones" analíticas de PostgreSQL/T-SQL (ARR, churn, pronóstico,
--   cohortes) se resuelven como plantillas de consulta con parámetros
--   literales editables directamente en el SQL — ver 04-queries-ejemplo.sql.
-- - Las vistas materializadas se implementan como tablas normales que se
--   recalculan re-ejecutando el bloque "REFRESCAR" de este archivo.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- VISTAS: ANÁLISIS DE VENTAS
-- ============================================================================

-- Vista: Resumen diario de ventas
DROP VIEW IF EXISTS v_resumen_ventas_diario;
CREATE VIEW v_resumen_ventas_diario AS
SELECT
    date(o.fecha_orden) AS fecha_venta,
    COUNT(DISTINCT o.id) AS cantidad_ordenes,
    COUNT(DISTINCT o.cliente_id) AS clientes_unicos,
    COUNT(DISTINCT o.vendedor_id) AS vendedores_involucrados,

    SUM(o.monto_total) AS ingresos_totales,
    AVG(o.monto_total) AS valor_promedio_orden,
    MIN(o.monto_total) AS orden_minima,
    MAX(o.monto_total) AS orden_maxima,

    SUM(o.subtotal) AS suma_subtotales,
    SUM(o.monto_descuento) AS total_descuentos,
    SUM(o.monto_impuesto) AS total_impuestos,
    SUM(o.costo_envio) AS total_envios,

    COUNT(CASE WHEN o.estado = 'entregado' THEN 1 END) AS ordenes_entregadas,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas,
    COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) AS ordenes_pagadas,
    COUNT(CASE WHEN o.estado_pago = 'pendiente' THEN 1 END) AS ordenes_pago_pendiente

FROM orden_encabezado o
WHERE o.fecha_orden >= datetime('now', '-2 years')
GROUP BY date(o.fecha_orden)
ORDER BY fecha_venta DESC;

-- Vista: Ventas por categoría de producto
DROP VIEW IF EXISTS v_ventas_por_categoria;
CREATE VIEW v_ventas_por_categoria AS
SELECT
    p.categoria,
    p.subcategoria,
    COUNT(DISTINCT o.id) AS cantidad_ordenes,
    COUNT(DISTINCT io.id) AS unidades_vendidas,
    SUM(io.cantidad) AS cantidad_total,

    SUM(io.total_linea) AS ingresos_totales,
    AVG(io.precio_unitario) AS precio_unitario_promedio,

    SUM(io.cantidad * p.precio_costo) AS costo_total,
    SUM(io.total_linea) - SUM(io.cantidad * p.precio_costo) AS ganancia_bruta,
    ROUND(
        100.0 * (SUM(io.total_linea) - SUM(io.cantidad * p.precio_costo)) / NULLIF(SUM(io.total_linea), 0),
        2
    ) AS margen_ganancia_pct,

    COUNT(DISTINCT o.cliente_id) AS clientes_unicos,
    SUM(io.cantidad_devuelta) AS unidades_devueltas

FROM orden_detalles io
JOIN orden_encabezado o ON io.orden_id = o.id
JOIN productos p ON io.producto_id = p.id
WHERE o.estado <> 'cancelado'
GROUP BY p.categoria, p.subcategoria
ORDER BY ingresos_totales DESC;

-- Vista: Performance de vendedores
DROP VIEW IF EXISTS v_performance_vendedores;
CREATE VIEW v_performance_vendedores AS
SELECT
    v.id,
    v.uuid,
    v.nombre,
    v.equipo,
    v.territorio,
    v.cuota_mensual,

    COUNT(DISTINCT o.id) AS total_ordenes,
    COUNT(DISTINCT o.cliente_id) AS clientes_unicos,

    SUM(o.monto_total) AS ventas_totales,
    AVG(o.monto_total) AS valor_promedio_orden,

    SUM(o.monto_total) - SUM(o.monto_total * v.tasa_comision / 100) AS ventas_netas,
    SUM(o.monto_total * v.tasa_comision / 100) AS monto_comision,

    COUNT(DISTINCT date(o.fecha_orden)) AS dias_activos_venta,

    COUNT(CASE WHEN o.estado = 'entregado' THEN 1 END) AS ordenes_entregadas,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas,
    COUNT(CASE WHEN o.estado_pago = 'pendiente' THEN 1 END) AS ordenes_sin_pago,

    -- Comparación con cuota (mes actual)
    SUM(CASE
        WHEN strftime('%Y-%m', o.fecha_orden) = strftime('%Y-%m', 'now')
        THEN o.monto_total ELSE 0
    END) AS ventas_mes_actual,

    ROUND(
        100.0 * SUM(CASE
            WHEN strftime('%Y-%m', o.fecha_orden) = strftime('%Y-%m', 'now')
            THEN o.monto_total ELSE 0
        END) / NULLIF(v.cuota_mensual, 0),
        2
    ) AS porcentaje_cumplimiento_cuota,

    MAX(o.fecha_orden) AS fecha_ultima_venta,
    CAST(julianday('now') - julianday(MAX(o.fecha_orden)) AS INTEGER) AS dias_desde_ultima_venta

FROM vendedores v
LEFT JOIN orden_encabezado o ON v.id = o.vendedor_id AND o.estado <> 'cancelado'
WHERE v.activo = 1
GROUP BY v.id, v.uuid, v.nombre, v.equipo, v.territorio, v.cuota_mensual, v.tasa_comision
ORDER BY ventas_totales DESC;

-- Vista: Segmentación de clientes
DROP VIEW IF EXISTS v_segmentacion_clientes;
CREATE VIEW v_segmentacion_clientes AS
SELECT
    c.id,
    c.uuid,
    c.nombre,
    c.segmento,
    c.industria,
    c.tamano_empresa,
    c.pais,

    COUNT(DISTINCT o.id) AS total_ordenes,
    SUM(o.monto_total) AS valor_vida,
    AVG(o.monto_total) AS valor_promedio_orden,
    MAX(o.fecha_orden) AS fecha_ultima_compra,
    CAST(julianday('now') - julianday(MAX(o.fecha_orden)) AS INTEGER) AS dias_desde_ultima_compra,

    CAST(julianday(MAX(o.fecha_orden)) - julianday(MIN(o.fecha_orden)) AS INTEGER) AS dias_como_cliente,
    ROUND(
        CAST(COUNT(DISTINCT o.id) AS REAL) /
        MAX(1, CAST(julianday('now') - julianday(MIN(o.fecha_orden)) AS INTEGER) / 30),
        2
    ) AS ordenes_por_mes,

    COUNT(DISTINCT strftime('%Y-%m', o.fecha_orden)) AS meses_activos,

    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas,
    COUNT(CASE WHEN o.estado_pago <> 'pagado' THEN 1 END) AS ordenes_sin_pago,

    COUNT(DISTINCT ic.id) AS total_interacciones,
    MAX(ic.fecha_interaccion) AS fecha_ultima_interaccion

FROM clientes c
LEFT JOIN orden_encabezado o ON c.id = o.cliente_id
LEFT JOIN interacciones_clientes ic ON c.id = ic.cliente_id
WHERE c.activo = 1
GROUP BY c.id, c.uuid, c.nombre, c.segmento, c.industria, c.tamano_empresa, c.pais
ORDER BY valor_vida DESC;

-- Vista: Análisis de devoluciones
DROP VIEW IF EXISTS v_analisis_devoluciones;
CREATE VIEW v_analisis_devoluciones AS
WITH devoluciones_por_dia AS (
    SELECT d.*, date(d.fecha_devolucion) AS dia_devolucion
    FROM devoluciones d
    WHERE d.fecha_devolucion >= datetime('now', '-1 year')
)
SELECT
    d.dia_devolucion AS fecha_devolucion,
    p.categoria,
    p.subcategoria,

    COUNT(DISTINCT d.id) AS cantidad_devoluciones,
    SUM(d.monto_reembolso) AS total_reembolsado,

    COUNT(DISTINCT d.orden_id) AS ordenes_con_devolucion,
    COUNT(DISTINCT d.orden_id) * 1.0 / (
        SELECT COUNT(DISTINCT id) FROM orden_encabezado
        WHERE date(fecha_orden) = d.dia_devolucion
    ) AS tasa_devolucion_pct,

    COUNT(CASE WHEN d.estado = 'aprobado' THEN 1 END) AS devoluciones_aprobadas,
    COUNT(CASE WHEN d.estado = 'pendiente' THEN 1 END) AS devoluciones_pendientes,
    COUNT(CASE WHEN d.estado = 'rechazado' THEN 1 END) AS devoluciones_rechazadas,

    d.motivo

FROM devoluciones_por_dia d
JOIN orden_encabezado o ON d.orden_id = o.id
LEFT JOIN orden_detalles io ON o.id = io.orden_id
LEFT JOIN productos p ON io.producto_id = p.id
GROUP BY d.dia_devolucion, p.categoria, p.subcategoria, d.motivo
ORDER BY fecha_devolucion DESC;

-- Vista: Análisis de flujo de pagos
DROP VIEW IF EXISTS v_analisis_pagos;
CREATE VIEW v_analisis_pagos AS
SELECT
    date(p.fecha_pago) AS fecha_pago,
    p.metodo_pago,

    COUNT(DISTINCT p.id) AS cantidad_pagos,
    COUNT(DISTINCT p.orden_id) AS ordenes_pagadas,
    SUM(p.monto) AS total_cobrado,
    AVG(p.monto) AS pago_promedio,

    COUNT(CASE WHEN p.estado = 'completado' THEN 1 END) AS pagos_exitosos,
    COUNT(CASE WHEN p.estado = 'fallido' THEN 1 END) AS pagos_fallidos,
    COUNT(CASE WHEN p.estado = 'reembolsado' THEN 1 END) AS pagos_reembolsados,

    -- Análisis de atrasos
    COUNT(DISTINCT CASE
        WHEN datetime(o.fecha_orden, '+30 days') < p.fecha_pago THEN o.id
    END) AS pagos_atrasados_30d,

    COUNT(DISTINCT CASE
        WHEN datetime(o.fecha_orden, '+60 days') < p.fecha_pago THEN o.id
    END) AS pagos_atrasados_60d

FROM pagos p
JOIN orden_encabezado o ON p.orden_id = o.id
WHERE p.fecha_pago >= datetime('now', '-1 year')
GROUP BY date(p.fecha_pago), p.metodo_pago
ORDER BY fecha_pago DESC;

-- Vista: Performance de campañas
DROP VIEW IF EXISTS v_performance_campanas;
CREATE VIEW v_performance_campanas AS
SELECT
    c.id,
    c.uuid,
    c.nombre,
    c.tipo_campana,
    c.canal,
    c.fecha_inicio,
    c.fecha_fin,

    c.presupuesto,
    c.gasto_real,
    ROUND(100.0 * c.gasto_real / NULLIF(c.presupuesto, 0), 2) AS pct_presupuesto_usado,

    c.impresiones,
    c.clics,
    c.conversiones,
    c.ingresos_generados,

    ROUND(100.0 * c.clics / NULLIF(c.impresiones, 0), 2) AS ctr_pct,
    ROUND(100.0 * c.conversiones / NULLIF(c.clics, 0), 2) AS tasa_conversion_pct,

    CASE
        WHEN c.gasto_real > 0
        THEN ROUND(c.ingresos_generados / c.gasto_real, 2)
        ELSE 0
    END AS roi,

    CASE
        WHEN c.conversiones > 0
        THEN ROUND(c.gasto_real / c.conversiones, 2)
        ELSE 0
    END AS costo_por_conversion,

    COUNT(DISTINCT cc.cliente_id) AS clientes_objetivo,
    COUNT(DISTINCT CASE WHEN cc.fecha_contacto IS NOT NULL THEN cc.cliente_id END) AS clientes_contactados,
    COUNT(DISTINCT CASE WHEN cc.convirtio = 1 THEN cc.cliente_id END) AS clientes_convertidos

FROM campanas c
LEFT JOIN campanas_clientes cc ON c.id = cc.campana_id
WHERE c.fecha_inicio >= datetime('now', '-2 years')
GROUP BY c.id, c.uuid, c.nombre, c.tipo_campana, c.canal, c.fecha_inicio, c.fecha_fin,
         c.presupuesto, c.gasto_real, c.impresiones, c.clics, c.conversiones, c.ingresos_generados
ORDER BY c.fecha_inicio DESC;

-- ============================================================================
-- TABLAS DE CACHÉ (equivalente a MATERIALIZED VIEW en PostgreSQL)
-- ============================================================================

CREATE TABLE IF NOT EXISTS mv_tendencia_ventas_mensual (
    mes TEXT PRIMARY KEY,
    anio INTEGER NOT NULL,
    numero_mes INTEGER NOT NULL,
    ordenes INTEGER NOT NULL,
    clientes INTEGER NOT NULL,
    ingresos DECIMAL(15,2) NOT NULL,
    valor_promedio_orden DECIMAL(15,2) NOT NULL,
    ingresos_entregados DECIMAL(15,2) NOT NULL,
    ingresos_cancelados DECIMAL(15,2) NOT NULL,
    ganancia_bruta DECIMAL(15,2) NOT NULL,
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS mv_top_productos_por_categoria (
    categoria VARCHAR(100) NOT NULL,
    id INTEGER NOT NULL,
    uuid TEXT NOT NULL,
    nombre VARCHAR(255) NOT NULL,
    sku VARCHAR(50) NOT NULL,
    veces_pedido INTEGER NOT NULL,
    cantidad_total_vendida INTEGER NOT NULL,
    ingresos_totales DECIMAL(15,2) NOT NULL,
    ranking_categoria INTEGER NOT NULL,
    actualizado_en TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (categoria, id)
);

-- ============================================================================
-- REFRESCAR TABLAS DE CACHÉ
-- Volver a ejecutar este bloque cada vez que se regeneren datos (03-).
-- ============================================================================

DELETE FROM mv_tendencia_ventas_mensual;

INSERT INTO mv_tendencia_ventas_mensual
    (mes, anio, numero_mes, ordenes, clientes, ingresos,
     valor_promedio_orden, ingresos_entregados, ingresos_cancelados, ganancia_bruta)
SELECT
    strftime('%Y-%m-01', o.fecha_orden) AS mes,
    CAST(strftime('%Y', o.fecha_orden) AS INTEGER) AS anio,
    CAST(strftime('%m', o.fecha_orden) AS INTEGER) AS numero_mes,
    COUNT(DISTINCT o.id) AS ordenes,
    COUNT(DISTINCT o.cliente_id) AS clientes,
    SUM(o.monto_total) AS ingresos,
    AVG(o.monto_total) AS valor_promedio_orden,
    SUM(CASE WHEN o.estado = 'entregado' THEN o.monto_total ELSE 0 END) AS ingresos_entregados,
    SUM(CASE WHEN o.estado = 'cancelado' THEN o.monto_total ELSE 0 END) AS ingresos_cancelados,
    SUM(o.monto_total) - SUM(COALESCE(io.cantidad * p.precio_costo, 0)) AS ganancia_bruta
FROM orden_encabezado o
LEFT JOIN orden_detalles io ON o.id = io.orden_id
LEFT JOIN productos p ON io.producto_id = p.id
WHERE o.estado <> 'cancelado'
GROUP BY strftime('%Y-%m', o.fecha_orden);

DELETE FROM mv_top_productos_por_categoria;

INSERT INTO mv_top_productos_por_categoria
    (categoria, id, uuid, nombre, sku, veces_pedido, cantidad_total_vendida, ingresos_totales, ranking_categoria)
SELECT
    p.categoria,
    p.id,
    p.uuid,
    p.nombre,
    p.sku,
    COUNT(DISTINCT io.orden_id) AS veces_pedido,
    COALESCE(SUM(io.cantidad), 0) AS cantidad_total_vendida,
    COALESCE(SUM(io.total_linea), 0) AS ingresos_totales,
    ROW_NUMBER() OVER (PARTITION BY p.categoria ORDER BY SUM(io.total_linea) DESC) AS ranking_categoria
FROM productos p
LEFT JOIN orden_detalles io ON p.id = io.producto_id
LEFT JOIN orden_encabezado o ON io.orden_id = o.id AND o.estado <> 'cancelado'
WHERE p.activo = 1
GROUP BY p.categoria, p.id, p.uuid, p.nombre, p.sku;

-- ============================================================================
-- FIN DE VISTAS Y ANÁLISIS
-- ============================================================================
