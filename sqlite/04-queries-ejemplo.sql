-- ============================================================================
-- QUERIES EJEMPLO PARA DASHBOARDS DE VENTAS
-- SQLite 3.39+ (usa FULL OUTER JOIN, agregado en esa versión)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- DASHBOARD PRINCIPAL (KPIs)
-- ============================================================================

-- Query 1: KPIs Principales del Mes
SELECT
    COUNT(DISTINCT o.id) AS total_ordenes,
    COUNT(DISTINCT o.cliente_id) AS clientes_unicos,
    SUM(o.monto_total) AS ingresos_totales,
    AVG(o.monto_total) AS valor_promedio_orden,
    SUM(CASE WHEN o.estado = 'entregado' THEN o.monto_total ELSE 0 END) AS ingresos_entregados,
    SUM(CASE WHEN o.estado_pago IN ('pendiente', 'vencido') THEN o.monto_total ELSE 0 END) AS monto_impago,
    COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) AS ordenes_pagadas,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas
FROM orden_encabezado o
WHERE strftime('%Y-%m', o.fecha_orden) = strftime('%Y-%m', 'now');

-- Query 2: Comparación Mes Actual vs Mes Anterior
WITH mes_actual AS (
    SELECT
        SUM(monto_total) AS ingresos,
        COUNT(*) AS ordenes,
        COUNT(DISTINCT cliente_id) AS clientes
    FROM orden_encabezado
    WHERE strftime('%Y-%m', fecha_orden) = strftime('%Y-%m', 'now')
),
mes_anterior AS (
    SELECT
        SUM(monto_total) AS ingresos,
        COUNT(*) AS ordenes,
        COUNT(DISTINCT cliente_id) AS clientes
    FROM orden_encabezado
    WHERE strftime('%Y-%m', fecha_orden) = strftime('%Y-%m', 'now', '-1 month')
)
SELECT
    ma.ingresos AS ingresos_mes_actual,
    mant.ingresos AS ingresos_mes_anterior,
    ROUND(100.0 * (ma.ingresos - mant.ingresos) / NULLIF(mant.ingresos, 0), 2) AS crecimiento_ingresos_pct,
    ma.ordenes AS ordenes_mes_actual,
    mant.ordenes AS ordenes_mes_anterior,
    ROUND(100.0 * (ma.ordenes - mant.ordenes) / NULLIF(mant.ordenes, 0), 2) AS crecimiento_ordenes_pct
FROM mes_actual ma
CROSS JOIN mes_anterior mant;

-- Query 3: Tendencia Última Semana (por día)
SELECT
    date(o.fecha_orden) AS fecha,
    CASE strftime('%w', o.fecha_orden)
        WHEN '0' THEN 'Domingo' WHEN '1' THEN 'Lunes' WHEN '2' THEN 'Martes'
        WHEN '3' THEN 'Miércoles' WHEN '4' THEN 'Jueves' WHEN '5' THEN 'Viernes' ELSE 'Sábado'
    END AS nombre_dia,
    COUNT(*) AS ordenes,
    SUM(o.monto_total) AS ingresos,
    AVG(o.monto_total) AS valor_promedio_orden,
    COUNT(CASE WHEN o.estado = 'entregado' THEN 1 END) AS entregadas,
    COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) AS ordenes_pagadas
FROM orden_encabezado o
WHERE o.fecha_orden >= datetime('now', '-7 days')
GROUP BY date(o.fecha_orden)
ORDER BY date(o.fecha_orden) DESC;

-- ============================================================================
-- ANÁLISIS DE VENDEDORES
-- ============================================================================

-- Query 4: Performance de Top 10 Vendedores (Mes Actual)
SELECT
    v.nombre AS nombre_vendedor,
    v.equipo,
    v.territorio,
    v.cuota_mensual,
    COUNT(DISTINCT o.id) AS ordenes,
    SUM(o.monto_total) AS ventas_totales,
    ROUND(SUM(o.monto_total) / NULLIF(v.cuota_mensual, 0) * 100, 2) AS pct_cumplimiento_cuota,
    ROUND(SUM(o.monto_total * v.tasa_comision / 100), 2) AS comision_ganada,
    COUNT(DISTINCT o.cliente_id) AS clientes_unicos,
    MAX(o.fecha_orden) AS fecha_ultima_venta
FROM vendedores v
LEFT JOIN orden_encabezado o ON v.id = o.vendedor_id
    AND strftime('%Y-%m', o.fecha_orden) = strftime('%Y-%m', 'now')
    AND o.estado <> 'cancelado'
WHERE v.activo = 1
GROUP BY v.id, v.nombre, v.equipo, v.territorio, v.cuota_mensual, v.tasa_comision
ORDER BY ventas_totales DESC
LIMIT 10;

-- Query 5: Comparativa de Vendedores (YTD vs Año Anterior)
WITH ytd_actual AS (
    SELECT v.id, v.nombre, SUM(o.monto_total) AS ventas_ytd
    FROM vendedores v
    LEFT JOIN orden_encabezado o ON v.id = o.vendedor_id
        AND strftime('%Y', o.fecha_orden) = strftime('%Y', 'now')
        AND o.estado <> 'cancelado'
    WHERE v.activo = 1
    GROUP BY v.id, v.nombre
),
ytd_anterior AS (
    SELECT v.id, v.nombre, SUM(o.monto_total) AS ventas_ytd
    FROM vendedores v
    LEFT JOIN orden_encabezado o ON v.id = o.vendedor_id
        AND strftime('%Y', o.fecha_orden) = strftime('%Y', 'now', '-1 year')
        AND o.estado <> 'cancelado'
    WHERE v.activo = 1
    GROUP BY v.id, v.nombre
)
SELECT
    COALESCE(a.nombre, ant.nombre) AS nombre,
    COALESCE(a.ventas_ytd, 0) AS ventas_ytd_actual,
    COALESCE(ant.ventas_ytd, 0) AS ventas_ytd_anterior,
    ROUND(100.0 * (COALESCE(a.ventas_ytd, 0) - COALESCE(ant.ventas_ytd, 0)) / NULLIF(COALESCE(ant.ventas_ytd, 1), 0), 2) AS crecimiento_yoy_pct
FROM ytd_actual a
FULL OUTER JOIN ytd_anterior ant ON a.id = ant.id
ORDER BY COALESCE(a.ventas_ytd, 0) DESC;

-- ============================================================================
-- ANÁLISIS DE CLIENTES
-- ============================================================================

-- Query 6: Segmentación de Clientes
SELECT
    c.segmento,
    COUNT(DISTINCT c.id) AS total_clientes,
    COUNT(DISTINCT o.id) AS total_ordenes,
    SUM(o.monto_total) AS ingresos_totales,
    ROUND(AVG(o.monto_total), 2) AS valor_promedio_orden,
    ROUND(SUM(o.monto_total) / NULLIF(COUNT(DISTINCT c.id), 0), 2) AS ingresos_por_cliente,
    COUNT(DISTINCT o.cliente_id) AS clientes_con_ordenes,
    ROUND(100.0 * COUNT(DISTINCT o.cliente_id) / NULLIF(COUNT(DISTINCT c.id), 0), 2) AS pct_conversion
FROM clientes c
LEFT JOIN orden_encabezado o ON c.id = o.cliente_id AND o.estado <> 'cancelado'
WHERE c.activo = 1
GROUP BY c.segmento
ORDER BY ingresos_totales DESC;

-- Query 7: Top 20 Clientes por Valor de Vida
SELECT
    c.id,
    c.nombre,
    c.segmento,
    c.industria,
    c.pais,
    COUNT(DISTINCT o.id) AS total_ordenes,
    SUM(o.monto_total) AS valor_vida,
    ROUND(AVG(o.monto_total), 2) AS valor_promedio_orden,
    MAX(o.fecha_orden) AS fecha_ultima_compra,
    CAST(julianday('now') - julianday(MAX(o.fecha_orden)) AS INTEGER) AS dias_desde_ultima_compra,
    COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) AS ordenes_pagadas,
    COUNT(CASE WHEN o.estado_pago IN ('pendiente', 'vencido') THEN 1 END) AS ordenes_sin_pago
FROM clientes c
LEFT JOIN orden_encabezado o ON c.id = o.cliente_id AND o.estado <> 'cancelado'
WHERE c.activo = 1
GROUP BY c.id, c.nombre, c.segmento, c.industria, c.pais
ORDER BY valor_vida DESC
LIMIT 20;

-- Query 8: Clientes en Riesgo (sin compras en últimos 90 días)
SELECT
    c.id,
    c.nombre,
    c.segmento,
    c.valor_vida_total,
    MAX(o.fecha_orden) AS fecha_ultima_compra,
    CAST(julianday('now') - julianday(MAX(o.fecha_orden)) AS INTEGER) AS dias_inactivo,
    COUNT(DISTINCT o.id) AS ordenes_totales,
    SUM(o.monto_total) AS total_gastado
FROM clientes c
LEFT JOIN orden_encabezado o ON c.id = o.cliente_id
WHERE c.activo = 1
GROUP BY c.id, c.nombre, c.segmento, c.valor_vida_total
HAVING MAX(o.fecha_orden) < datetime('now', '-90 days')
ORDER BY dias_inactivo DESC;

-- Query 9: Clientes Nuevos (últimos 30 días)
SELECT
    c.id,
    c.nombre,
    c.segmento,
    c.industria,
    c.tamano_empresa,
    c.fecha_adquisicion,
    COUNT(DISTINCT o.id) AS ordenes_desde_adquisicion,
    SUM(o.monto_total) AS valor_compra_inicial,
    MAX(o.fecha_orden) AS fecha_primera_orden
FROM clientes c
LEFT JOIN orden_encabezado o ON c.id = o.cliente_id
WHERE c.fecha_adquisicion >= datetime('now', '-30 days')
GROUP BY c.id, c.nombre, c.segmento, c.industria, c.tamano_empresa, c.fecha_adquisicion
ORDER BY c.fecha_adquisicion DESC;

-- ============================================================================
-- ANÁLISIS DE PRODUCTOS
-- ============================================================================

-- Query 10: Top 20 Productos por Ingresos
SELECT
    p.id,
    p.nombre,
    p.sku,
    p.categoria,
    p.marca,
    p.precio_lista,
    p.precio_costo,
    ROUND((p.precio_lista - p.precio_costo) / NULLIF(p.precio_lista, 0) * 100, 2) AS margen_pct,
    COUNT(DISTINCT io.orden_id) AS veces_pedido,
    SUM(io.cantidad) AS cantidad_total_vendida,
    SUM(io.total_linea) AS ingresos_totales,
    ROUND(SUM(io.total_linea) / NULLIF(SUM(io.cantidad), 0), 2) AS ingreso_promedio_por_unidad,
    ROUND(SUM(io.cantidad * p.precio_costo), 2) AS costo_total,
    ROUND(SUM(io.total_linea) - SUM(io.cantidad * p.precio_costo), 2) AS ganancia_bruta,
    SUM(io.cantidad_devuelta) AS total_devuelto
FROM productos p
LEFT JOIN orden_detalles io ON p.id = io.producto_id
LEFT JOIN orden_encabezado o ON io.orden_id = o.id AND o.estado <> 'cancelado'
WHERE p.activo = 1
GROUP BY p.id, p.nombre, p.sku, p.categoria, p.marca, p.precio_lista, p.precio_costo
ORDER BY ingresos_totales DESC
LIMIT 20;

-- Query 11: Productos sin Ventas
SELECT
    p.id,
    p.nombre,
    p.sku,
    p.categoria,
    p.marca,
    p.precio_lista,
    p.fecha_lanzamiento,
    CAST(julianday('now') - julianday(p.fecha_lanzamiento) AS INTEGER) AS dias_desde_lanzamiento,
    p.stock_actual,
    CASE
        WHEN p.fecha_lanzamiento > datetime('now', '-90 days') THEN 'Nuevo'
        WHEN p.fecha_descontinuacion IS NOT NULL THEN 'Descontinuado'
        ELSE 'Sin ventas'
    END AS razon_estado
FROM productos p
LEFT JOIN orden_detalles io ON p.id = io.producto_id
WHERE p.activo = 1
    AND io.id IS NULL
ORDER BY p.fecha_lanzamiento DESC;

-- Query 12: Rendimiento por Categoría
SELECT
    p.categoria,
    COUNT(DISTINCT p.id) AS cantidad_productos,
    COUNT(DISTINCT io.orden_id) AS ordenes,
    SUM(io.cantidad) AS unidades_vendidas,
    SUM(io.total_linea) AS ingresos,
    ROUND(AVG(io.precio_unitario), 2) AS precio_promedio,
    ROUND(SUM(io.total_linea) - SUM(io.cantidad * p.precio_costo), 2) AS ganancia_bruta,
    ROUND(100.0 * (SUM(io.total_linea) - SUM(io.cantidad * p.precio_costo)) / NULLIF(SUM(io.total_linea), 0), 2) AS margen_ganancia_pct,
    ROUND(100.0 * SUM(io.cantidad_devuelta) / NULLIF(SUM(io.cantidad), 0), 2) AS tasa_devolucion_pct
FROM productos p
LEFT JOIN orden_detalles io ON p.id = io.producto_id
LEFT JOIN orden_encabezado o ON io.orden_id = o.id AND o.estado <> 'cancelado'
WHERE p.activo = 1
GROUP BY p.categoria
ORDER BY ingresos DESC;

-- ============================================================================
-- ANÁLISIS DE PAGOS
-- ============================================================================

-- Query 13: Estado de Pagos (Resumen)
SELECT
    o.estado_pago,
    COUNT(DISTINCT o.id) AS cantidad_ordenes,
    SUM(o.monto_total) AS monto_pendiente,
    AVG(o.monto_total) AS monto_promedio_orden,
    MAX(o.fecha_orden) AS orden_mas_reciente
FROM orden_encabezado o
WHERE o.estado <> 'cancelado'
    AND o.estado_pago IN ('pendiente', 'parcial', 'vencido')
GROUP BY o.estado_pago
ORDER BY monto_pendiente DESC;

-- Query 14: Órdenes Atrasadas en Pago (más de 60 días)
SELECT
    o.id,
    o.uuid,
    c.nombre AS nombre_cliente,
    c.email,
    o.fecha_orden,
    o.monto_total,
    o.estado_pago,
    CAST(julianday('now') - julianday(o.fecha_orden) AS INTEGER) AS dias_atraso,
    CASE
        WHEN CAST(julianday('now') - julianday(o.fecha_orden) AS INTEGER) > 90 THEN 'Crítico'
        WHEN CAST(julianday('now') - julianday(o.fecha_orden) AS INTEGER) > 60 THEN 'Urgente'
        ELSE 'Seguimiento'
    END AS prioridad_cobranza
FROM orden_encabezado o
JOIN clientes c ON o.cliente_id = c.id
WHERE o.fecha_orden < datetime('now', '-60 days')
    AND o.estado_pago IN ('pendiente', 'parcial', 'vencido')
    AND o.estado <> 'cancelado'
ORDER BY dias_atraso DESC;

-- Query 15: Análisis de Métodos de Pago
SELECT
    o.metodo_pago,
    COUNT(*) AS cantidad_transacciones,
    SUM(o.monto_total) AS monto_total,
    ROUND(AVG(o.monto_total), 2) AS monto_promedio,
    COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) AS pagos_exitosos,
    COUNT(CASE WHEN o.estado_pago IN ('pendiente', 'vencido') THEN 1 END) AS pagos_pendientes,
    ROUND(100.0 * COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) / COUNT(*), 2) AS tasa_exito_pct
FROM orden_encabezado o
WHERE o.estado <> 'cancelado'
GROUP BY o.metodo_pago
ORDER BY monto_total DESC;

-- ============================================================================
-- ANÁLISIS DE DEVOLUCIONES
-- ============================================================================

-- Query 16: Resumen de Devoluciones
SELECT
    COUNT(DISTINCT d.id) AS total_devoluciones,
    COUNT(DISTINCT d.orden_id) AS ordenes_con_devolucion,
    SUM(d.monto_reembolso) AS total_reembolsado,
    ROUND(AVG(d.monto_reembolso), 2) AS reembolso_promedio,
    COUNT(CASE WHEN d.estado = 'aprobado' THEN 1 END) AS devoluciones_aprobadas,
    COUNT(CASE WHEN d.estado = 'pendiente' THEN 1 END) AS devoluciones_pendientes,
    COUNT(CASE WHEN d.estado = 'rechazado' THEN 1 END) AS devoluciones_rechazadas,
    ROUND(100.0 * COUNT(CASE WHEN d.estado = 'aprobado' THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS tasa_aprobacion_pct
FROM devoluciones d;

-- Query 17: Top 10 Motivos de Devolución
SELECT
    d.motivo,
    COUNT(*) AS cantidad_devoluciones,
    SUM(d.monto_reembolso) AS total_reembolsado,
    ROUND(AVG(d.monto_reembolso), 2) AS reembolso_promedio,
    COUNT(CASE WHEN d.estado = 'aprobado' THEN 1 END) AS aprobadas,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM devoluciones), 2) AS pct_del_total
FROM devoluciones d
WHERE d.fecha_devolucion >= datetime('now', '-1 year')
GROUP BY d.motivo
ORDER BY cantidad_devoluciones DESC
LIMIT 10;

-- Query 18: Productos con Mayor Tasa de Devolución
SELECT
    p.categoria,
    p.nombre,
    p.sku,
    COUNT(DISTINCT io.orden_id) AS veces_pedido,
    SUM(io.cantidad) AS total_vendido,
    SUM(io.cantidad_devuelta) AS total_devuelto,
    ROUND(100.0 * SUM(io.cantidad_devuelta) / NULLIF(SUM(io.cantidad), 0), 2) AS tasa_devolucion_pct
FROM productos p
LEFT JOIN orden_detalles io ON p.id = io.producto_id
GROUP BY p.id, p.categoria, p.nombre, p.sku
HAVING SUM(io.cantidad) >= 10  -- Mínimo de ventas para ser representativo
    AND SUM(io.cantidad_devuelta) > 0
ORDER BY tasa_devolucion_pct DESC;

-- ============================================================================
-- ANÁLISIS DE CAMPAÑAS
-- ============================================================================

-- Query 19: Performance de Campañas Activas
SELECT
    c.nombre,
    c.tipo_campana,
    c.canal,
    c.fecha_inicio,
    c.fecha_fin,
    COALESCE(c.presupuesto, 0) AS presupuesto,
    COALESCE(c.gasto_real, 0) AS gasto_real,
    ROUND(100.0 * COALESCE(c.gasto_real, 0) / NULLIF(COALESCE(c.presupuesto, 1), 0), 2) AS pct_presupuesto_usado,
    COALESCE(c.impresiones, 0) AS impresiones,
    COALESCE(c.clics, 0) AS clics,
    ROUND(100.0 * COALESCE(c.clics, 0) / NULLIF(COALESCE(c.impresiones, 1), 0), 2) AS ctr_pct,
    COALESCE(c.conversiones, 0) AS conversiones,
    ROUND(100.0 * COALESCE(c.conversiones, 0) / NULLIF(COALESCE(c.clics, 1), 0), 2) AS tasa_conversion_pct,
    COALESCE(c.ingresos_generados, 0) AS ingresos_generados,
    CASE
        WHEN COALESCE(c.gasto_real, 0) > 0
        THEN ROUND(COALESCE(c.ingresos_generados, 0) / COALESCE(c.gasto_real, 1), 2)
        ELSE 0
    END AS roi
FROM campanas c
WHERE c.estado = 'activa'
    OR c.fecha_fin >= datetime('now', '-30 days')
ORDER BY ingresos_generados DESC;

-- ============================================================================
-- ANÁLISIS DE TENDENCIAS
-- ============================================================================

-- Query 20: Tendencia Mensual (Últimos 12 Meses)
SELECT
    strftime('%Y-%m-01', o.fecha_orden) AS mes,
    COUNT(*) AS cantidad_ordenes,
    COUNT(DISTINCT o.cliente_id) AS clientes_unicos,
    SUM(o.monto_total) AS ingresos,
    ROUND(AVG(o.monto_total), 2) AS valor_promedio_orden,
    ROUND(SUM(o.monto_total) - SUM(io.cantidad * p.precio_costo), 2) AS ganancia_bruta,
    COUNT(CASE WHEN o.estado = 'entregado' THEN 1 END) AS ordenes_entregadas,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas
FROM orden_encabezado o
LEFT JOIN orden_detalles io ON o.id = io.orden_id
LEFT JOIN productos p ON io.producto_id = p.id
WHERE o.fecha_orden >= datetime('now', '-12 months')
    AND o.estado <> 'cancelado'
GROUP BY strftime('%Y-%m', o.fecha_orden)
ORDER BY mes DESC;

-- Query 21: Pronóstico Simple (Tendencia Lineal, regresión manual)
-- SQLite no tiene REGR_SLOPE/REGR_INTERCEPT: se calcula con las fórmulas
-- estadísticas estándar (igual que t-sql/ y mysql/).
-- Editar los literales 3 (meses a pronosticar) y 12 (meses de histórico) para ajustar.
WITH RECURSIVE datos_historicos AS (
    SELECT
        strftime('%Y-%m-01', o.fecha_orden) AS mes,
        SUM(o.monto_total) AS ingresos,
        ROW_NUMBER() OVER (ORDER BY strftime('%Y-%m-01', o.fecha_orden)) AS seq_mes
    FROM orden_encabezado o
    WHERE o.fecha_orden >= datetime('now', '-12 months')
      AND o.estado <> 'cancelado'
    GROUP BY strftime('%Y-%m', o.fecha_orden)
),
estadisticas AS (
    SELECT
        COUNT(*) AS n,
        SUM(seq_mes) AS sum_x,
        SUM(ingresos) AS sum_y,
        SUM(seq_mes * ingresos) AS sum_xy,
        SUM(seq_mes * seq_mes) AS sum_x2,
        MAX(seq_mes) AS ultimo_seq,
        MAX(mes) AS ultimo_mes
    FROM datos_historicos
),
tendencia AS (
    SELECT
        ultimo_seq, ultimo_mes,
        CASE WHEN (n * sum_x2 - sum_x * sum_x) = 0 THEN 0
             ELSE (n * sum_xy - sum_x * sum_y) * 1.0 / (n * sum_x2 - sum_x * sum_x)
        END AS pendiente,
        CASE WHEN (n * sum_x2 - sum_x * sum_x) = 0 THEN sum_y * 1.0 / NULLIF(n, 0)
             ELSE (sum_y - ((n * sum_xy - sum_x * sum_y) * 1.0 / (n * sum_x2 - sum_x * sum_x)) * sum_x) / NULLIF(n, 0)
        END AS intercepto
    FROM estadisticas
),
numeros_mes(n) AS (
    SELECT 1
    UNION ALL SELECT n + 1 FROM numeros_mes WHERE n < 3
)
SELECT
    date(t.ultimo_mes, '+' || nm.n || ' months') AS mes_pronostico,
    MAX(0, ROUND(t.intercepto + t.pendiente * (t.ultimo_seq + nm.n), 2)) AS ingreso_pronosticado
FROM tendencia t
CROSS JOIN numeros_mes nm
WHERE t.pendiente IS NOT NULL;

-- ============================================================================
-- QUERIES PARA REPORTES EJECUTIVOS
-- ============================================================================

-- Query 22: Reporte Ejecutivo Semanal
SELECT
    'Semana' AS periodo,
    date(MAX(o.fecha_orden), '-6 days') AS fecha_inicio,
    date(MAX(o.fecha_orden)) AS fecha_fin,
    COUNT(*) AS ordenes,
    SUM(o.monto_total) AS ingresos,
    COUNT(DISTINCT o.cliente_id) AS clientes_activos,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas,
    ROUND(100.0 * COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS pct_cobrado
FROM orden_encabezado o
WHERE o.fecha_orden >= datetime('now', '-7 days');

-- Query 23: Export para Power BI - Tabla de Hechos
SELECT
    o.id AS orden_id,
    o.uuid AS orden_uuid,
    o.fecha_orden,
    o.monto_total,
    o.estado,
    o.estado_pago,
    c.id AS cliente_id,
    c.segmento,
    c.industria,
    c.tamano_empresa,
    v.id AS vendedor_id,
    v.nombre AS nombre_vendedor,
    v.equipo,
    io.producto_id,
    io.cantidad,
    io.total_linea
FROM orden_encabezado o
JOIN clientes c ON o.cliente_id = c.id
LEFT JOIN vendedores v ON o.vendedor_id = v.id
LEFT JOIN orden_detalles io ON o.id = io.orden_id
WHERE o.fecha_orden >= datetime('now', '-12 months')
ORDER BY o.fecha_orden DESC;

-- ============================================================================
-- FUNCIONES ANALÍTICAS (plantillas de consulta)
-- SQLite no tiene stored functions/procedures: estas son consultas planas con
-- los parámetros como literales editables directamente en el SQL.
-- ============================================================================

-- ARR (Ingreso Anual Recurrente) por segmento — parámetro: 12 meses de período
SELECT
    t.segmento,
    ROUND(AVG(t.ventas_mensuales), 2) AS ingreso_mensual,
    ROUND(AVG(t.ventas_mensuales) * 12, 2) AS ingreso_anual
FROM (
    SELECT
        c.segmento,
        strftime('%Y-%m-01', o.fecha_orden) AS mes,
        SUM(o.monto_total) AS ventas_mensuales
    FROM orden_encabezado o
    JOIN clientes c ON o.cliente_id = c.id
    WHERE o.fecha_orden >= datetime('now', '-12 months')
      AND o.estado <> 'cancelado'
    GROUP BY c.segmento, strftime('%Y-%m', o.fecha_orden)
) t
GROUP BY t.segmento
ORDER BY ingreso_anual DESC;

-- Tasa de churn de clientes — parámetro: 90 días de período
WITH clientes_periodo AS (
    SELECT DISTINCT c.id, c.segmento
    FROM clientes c
    JOIN orden_encabezado o ON c.id = o.cliente_id
    WHERE o.fecha_orden >= datetime('now', '-90 days')
      AND o.estado <> 'cancelado'
),
clientes_activos_recientes AS (
    SELECT DISTINCT c.id
    FROM clientes c
    JOIN orden_encabezado o ON c.id = o.cliente_id
    WHERE o.fecha_orden >= datetime('now', '-30 days')
      AND o.estado <> 'cancelado'
),
clientes_perdidos AS (
    SELECT cp.id, cp.segmento
    FROM clientes_periodo cp
    WHERE cp.id NOT IN (SELECT id FROM clientes_activos_recientes)
)
SELECT
    cp.segmento,
    COUNT(DISTINCT cp.id) AS total_clientes_inicio_periodo,
    COUNT(DISTINCT cper.id) AS clientes_perdidos,
    ROUND(100.0 * COUNT(DISTINCT cper.id) / NULLIF(COUNT(DISTINCT cp.id), 0), 2) AS tasa_churn_pct
FROM clientes_periodo cp
LEFT JOIN clientes_perdidos cper ON cp.id = cper.id
GROUP BY cp.segmento
ORDER BY tasa_churn_pct DESC;

-- Análisis de cohortes — parámetro: métrica 'ingresos' (cambiar a 'ordenes' si se desea)
WITH cohortes_clientes AS (
    SELECT
        c.id,
        MIN(strftime('%Y-%m-01', o.fecha_orden)) AS mes_cohorte,
        strftime('%Y-%m-01', o.fecha_orden) AS mes_orden
    FROM clientes c
    JOIN orden_encabezado o ON c.id = o.cliente_id
    WHERE o.estado <> 'cancelado'
    GROUP BY c.id, strftime('%Y-%m', o.fecha_orden)
),
cohortes_con_metricas AS (
    SELECT
        cc.mes_cohorte,
        (CAST(strftime('%Y', cc.mes_orden) AS INTEGER) - CAST(strftime('%Y', cc.mes_cohorte) AS INTEGER)) * 12
            + (CAST(strftime('%m', cc.mes_orden) AS INTEGER) - CAST(strftime('%m', cc.mes_cohorte) AS INTEGER)) AS meses_transcurridos,
        SUM(o.monto_total) AS metrica_ingresos,
        COUNT(DISTINCT o.id) AS metrica_ordenes,
        COUNT(DISTINCT cc.id) AS clientes
    FROM cohortes_clientes cc
    JOIN orden_encabezado o
        ON cc.id = o.cliente_id AND strftime('%Y-%m-01', o.fecha_orden) = cc.mes_orden
    WHERE o.estado <> 'cancelado'
    GROUP BY cc.mes_cohorte,
             (CAST(strftime('%Y', cc.mes_orden) AS INTEGER) - CAST(strftime('%Y', cc.mes_cohorte) AS INTEGER)) * 12
                + (CAST(strftime('%m', cc.mes_orden) AS INTEGER) - CAST(strftime('%m', cc.mes_cohorte) AS INTEGER))
)
SELECT
    ccm.mes_cohorte,
    ccm.meses_transcurridos,
    ROUND(ccm.metrica_ingresos, 2) AS valor_metrica,
    ccm.clientes AS cantidad_clientes
FROM cohortes_con_metricas ccm
WHERE ccm.meses_transcurridos >= 0
ORDER BY ccm.mes_cohorte DESC, ccm.meses_transcurridos ASC;

-- ============================================================================
-- FIN DE QUERIES EJEMPLO
-- ============================================================================
