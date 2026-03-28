-- ============================================================================
-- QUERIES EJEMPLO PARA DASHBOARDS DE VENTAS
-- Optimizadas y listas para usar en Power BI, Vue.js, etc.
-- ============================================================================

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
FROM ordenes o
WHERE DATE_TRUNC('month', o.fecha_orden) = DATE_TRUNC('month', CURRENT_DATE);

-- Query 2: Comparación Mes Actual vs Mes Anterior
WITH mes_actual AS (
    SELECT
        SUM(monto_total) AS ingresos,
        COUNT(*) AS ordenes,
        COUNT(DISTINCT cliente_id) AS clientes
    FROM ordenes
    WHERE DATE_TRUNC('month', fecha_orden) = DATE_TRUNC('month', CURRENT_DATE)
),
mes_anterior AS (
    SELECT
        SUM(monto_total) AS ingresos,
        COUNT(*) AS ordenes,
        COUNT(DISTINCT cliente_id) AS clientes
    FROM ordenes
    WHERE DATE_TRUNC('month', fecha_orden) = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
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
    DATE(o.fecha_orden) AS fecha,
    TO_CHAR(o.fecha_orden, 'TMDay') AS nombre_dia,
    COUNT(*) AS ordenes,
    SUM(o.monto_total) AS ingresos,
    AVG(o.monto_total) AS valor_promedio_orden,
    COUNT(CASE WHEN o.estado = 'entregado' THEN 1 END) AS entregadas,
    COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) AS ordenes_pagadas
FROM ordenes o
WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(o.fecha_orden), TO_CHAR(o.fecha_orden, 'TMDay')
ORDER BY DATE(o.fecha_orden) DESC;

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
LEFT JOIN ordenes o ON v.id = o.vendedor_id
    AND DATE_TRUNC('month', o.fecha_orden) = DATE_TRUNC('month', CURRENT_DATE)
    AND o.estado != 'cancelado'
WHERE v.activo = TRUE
GROUP BY v.id, v.nombre, v.equipo, v.territorio, v.cuota_mensual, v.tasa_comision
ORDER BY ventas_totales DESC NULLS LAST
LIMIT 10;

-- Query 5: Comparativa de Vendedores (YTD vs Año Anterior)
WITH ytd_actual AS (
    SELECT
        v.id,
        v.nombre,
        SUM(o.monto_total) AS ventas_ytd
    FROM vendedores v
    LEFT JOIN ordenes o ON v.id = o.vendedor_id
        AND DATE_TRUNC('year', o.fecha_orden) = DATE_TRUNC('year', CURRENT_DATE)
        AND o.estado != 'cancelado'
    WHERE v.activo = TRUE
    GROUP BY v.id, v.nombre
),
ytd_anterior AS (
    SELECT
        v.id,
        v.nombre,
        SUM(o.monto_total) AS ventas_ytd
    FROM vendedores v
    LEFT JOIN ordenes o ON v.id = o.vendedor_id
        AND DATE_TRUNC('year', o.fecha_orden) = DATE_TRUNC('year', CURRENT_DATE - INTERVAL '1 year')
        AND o.estado != 'cancelado'
    WHERE v.activo = TRUE
    GROUP BY v.id, v.nombre
)
SELECT
    a.nombre,
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
LEFT JOIN ordenes o ON c.id = o.cliente_id AND o.estado != 'cancelado'
WHERE c.activo = TRUE
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
    CURRENT_DATE - MAX(o.fecha_orden)::DATE AS dias_desde_ultima_compra,
    COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) AS ordenes_pagadas,
    COUNT(CASE WHEN o.estado_pago IN ('pendiente', 'vencido') THEN 1 END) AS ordenes_sin_pago
FROM clientes c
LEFT JOIN ordenes o ON c.id = o.cliente_id AND o.estado != 'cancelado'
WHERE c.activo = TRUE
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
    CURRENT_DATE - MAX(o.fecha_orden)::DATE AS dias_inactivo,
    COUNT(DISTINCT o.id) AS ordenes_totales,
    SUM(o.monto_total) AS total_gastado
FROM clientes c
LEFT JOIN ordenes o ON c.id = o.cliente_id
WHERE c.activo = TRUE
GROUP BY c.id, c.nombre, c.segmento, c.valor_vida_total
HAVING MAX(o.fecha_orden) < CURRENT_DATE - INTERVAL '90 days'
ORDER BY dias_inactivo DESC;

-- Query 9: Clientes Nuevos (últimos 30 días)
SELECT
    c.id,
    c.nombre,
    c.segmento,
    c.industria,
    c.tamaño_empresa,
    c.fecha_adquisicion,
    COUNT(DISTINCT o.id) AS ordenes_desde_adquisicion,
    SUM(o.monto_total) AS valor_compra_inicial,
    MAX(o.fecha_orden) AS fecha_primera_orden
FROM clientes c
LEFT JOIN ordenes o ON c.id = o.cliente_id
WHERE c.fecha_adquisicion >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY c.id, c.nombre, c.segmento, c.industria, c.tamaño_empresa, c.fecha_adquisicion
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
    ROUND((p.precio_lista - p.precio_costo) / p.precio_lista * 100, 2) AS margen_pct,
    COUNT(DISTINCT io.orden_id) AS veces_pedido,
    SUM(io.cantidad) AS cantidad_total_vendida,
    SUM(io.total_linea) AS ingresos_totales,
    ROUND(SUM(io.total_linea) / NULLIF(SUM(io.cantidad), 0), 2) AS ingreso_promedio_por_unidad,
    ROUND(SUM(io.cantidad * p.precio_costo), 2) AS costo_total,
    ROUND(SUM(io.total_linea) - SUM(io.cantidad * p.precio_costo), 2) AS ganancia_bruta,
    SUM(io.cantidad_devuelta) AS total_devuelto
FROM productos p
LEFT JOIN items_orden io ON p.id = io.producto_id
LEFT JOIN ordenes o ON io.orden_id = o.id AND o.estado != 'cancelado'
WHERE p.activo = TRUE
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
    CURRENT_DATE - p.fecha_lanzamiento::DATE AS dias_desde_lanzamiento,
    p.stock_actual,
    CASE
        WHEN p.fecha_lanzamiento > CURRENT_DATE - INTERVAL '90 days' THEN 'Nuevo'
        WHEN p.fecha_descontinuacion IS NOT NULL THEN 'Descontinuado'
        ELSE 'Sin ventas'
    END AS razon_estado
FROM productos p
LEFT JOIN items_orden io ON p.id = io.producto_id
WHERE p.activo = TRUE
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
LEFT JOIN items_orden io ON p.id = io.producto_id
LEFT JOIN ordenes o ON io.orden_id = o.id AND o.estado != 'cancelado'
WHERE p.activo = TRUE
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
FROM ordenes o
WHERE o.estado != 'cancelado'
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
    CURRENT_DATE - o.fecha_orden::DATE AS dias_atraso,
    CASE
        WHEN CURRENT_DATE - o.fecha_orden::DATE > 90 THEN 'Crítico'
        WHEN CURRENT_DATE - o.fecha_orden::DATE > 60 THEN 'Urgente'
        ELSE 'Seguimiento'
    END AS prioridad_cobranza
FROM ordenes o
JOIN clientes c ON o.cliente_id = c.id
WHERE o.fecha_orden < CURRENT_DATE - INTERVAL '60 days'
    AND o.estado_pago IN ('pendiente', 'parcial', 'vencido')
    AND o.estado != 'cancelado'
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
FROM ordenes o
WHERE o.estado != 'cancelado'
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
WHERE d.fecha_devolucion >= CURRENT_DATE - INTERVAL '1 year'
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
LEFT JOIN items_orden io ON p.id = io.producto_id
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
    OR c.fecha_fin >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY ingresos_generados DESC;

-- ============================================================================
-- ANÁLISIS DE TENDENCIAS
-- ============================================================================

-- Query 20: Tendencia Mensual (Últimos 12 Meses)
SELECT
    DATE_TRUNC('month', o.fecha_orden)::DATE AS mes,
    COUNT(*) AS cantidad_ordenes,
    COUNT(DISTINCT o.cliente_id) AS clientes_unicos,
    SUM(o.monto_total) AS ingresos,
    ROUND(AVG(o.monto_total), 2) AS valor_promedio_orden,
    ROUND(SUM(o.monto_total) - SUM(io.cantidad * p.precio_costo), 2) AS ganancia_bruta,
    COUNT(CASE WHEN o.estado = 'entregado' THEN 1 END) AS ordenes_entregadas,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas
FROM ordenes o
LEFT JOIN items_orden io ON o.id = io.orden_id
LEFT JOIN productos p ON io.producto_id = p.id
WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL '12 months'
    AND o.estado != 'cancelado'
GROUP BY DATE_TRUNC('month', o.fecha_orden)
ORDER BY mes DESC;

-- Query 21: Pronóstico Simple (Tendencia Lineal)
WITH ultimos_12_meses AS (
    SELECT
        DATE_TRUNC('month', o.fecha_orden)::DATE AS mes,
        ROW_NUMBER() OVER (ORDER BY DATE_TRUNC('month', o.fecha_orden)) AS numero_mes,
        SUM(o.monto_total) AS ingresos
    FROM ordenes o
    WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL '12 months'
        AND o.estado != 'cancelado'
    GROUP BY DATE_TRUNC('month', o.fecha_orden)
),
tendencia AS (
    SELECT
        REGR_SLOPE(ingresos, numero_mes) AS pendiente,
        REGR_INTERCEPT(ingresos, numero_mes) AS intercepto,
        MAX(numero_mes) AS ultimo_numero_mes,
        MAX(mes) AS ultimo_mes
    FROM ultimos_12_meses
)
SELECT
    (t.ultimo_mes + (n || ' months')::INTERVAL)::DATE AS mes_pronostico,
    GREATEST(0, ROUND(t.intercepto + t.pendiente * (t.ultimo_numero_mes + n), 2)) AS ingresos_pronosticados
FROM tendencia t
CROSS JOIN GENERATE_SERIES(1, 3) n
WHERE t.pendiente IS NOT NULL;

-- ============================================================================
-- QUERIES PARA REPORTES EJECUTIVOS
-- ============================================================================

-- Query 22: Reporte Ejecutivo Semanal
SELECT
    'Semana' AS periodo,
    MAX(o.fecha_orden)::DATE - INTERVAL '6 days' AS fecha_inicio,
    MAX(o.fecha_orden)::DATE AS fecha_fin,
    COUNT(*) AS ordenes,
    SUM(o.monto_total) AS ingresos,
    COUNT(DISTINCT o.cliente_id) AS clientes_activos,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas,
    ROUND(100.0 * COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS pct_cobrado
FROM ordenes o
WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY 'Semana';

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
    c.tamaño_empresa,
    v.id AS vendedor_id,
    v.nombre AS nombre_vendedor,
    v.equipo,
    io.producto_id,
    io.cantidad,
    io.total_linea
FROM ordenes o
JOIN clientes c ON o.cliente_id = c.id
LEFT JOIN vendedores v ON o.vendedor_id = v.id
LEFT JOIN items_orden io ON o.id = io.orden_id
WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL '12 months'
ORDER BY o.fecha_orden DESC;

-- ============================================================================
-- FIN DE QUERIES EJEMPLO
-- ============================================================================
