-- ============================================================================
-- QUERIES DE EJEMPLO SOBRE EL MODELO ANALÍTICO
-- SQL Server 2016+ | Base: ventas_bi
-- ============================================================================
-- Notar lo que NO aparece en estas queries: no hay un solo JOIN a una tabla
-- fuera de las 6 dimensiones + 3 hechos, no hay DATEADD/DATEPART repetido
-- (ya está resuelto en dim_fecha), y las medidas (total_linea, margen) vienen
-- pre-calculadas del ETL. Comparar contra el mismo análisis en 04-queries-
-- ejemplo.sql de t-sql/ para ver la diferencia.
-- ============================================================================

USE ventas_bi;
GO

-- ============================================================================
-- Query 1: Tendencia mensual de ventas e ingresos
-- ============================================================================
SELECT
    f.anio,
    f.mes_anio,
    SUM(v.total_linea) AS ingresos,
    SUM(v.margen_bruto_linea) AS margen_bruto,
    COUNT(DISTINCT v.orden_id) AS ordenes,
    SUM(v.cantidad) AS unidades_vendidas
FROM dbo.fact_ventas v
JOIN dbo.dim_fecha f ON v.fecha_key = f.fecha_key
JOIN dbo.dim_estado_orden e ON v.estado_orden_key = e.estado_orden_key
WHERE e.es_cancelada = 0
GROUP BY f.anio, f.mes_anio
ORDER BY f.mes_anio;

-- ============================================================================
-- Query 2: Crecimiento año contra año (YoY), por trimestre
-- ============================================================================
WITH por_trimestre AS (
    SELECT f.anio, f.trimestre, SUM(v.total_linea) AS ingresos
    FROM dbo.fact_ventas v
    JOIN dbo.dim_fecha f ON v.fecha_key = f.fecha_key
    JOIN dbo.dim_estado_orden e ON v.estado_orden_key = e.estado_orden_key
    WHERE e.es_cancelada = 0
    GROUP BY f.anio, f.trimestre
)
SELECT
    actual.anio, actual.trimestre, actual.ingresos AS ingresos_actual,
    anterior.ingresos AS ingresos_anio_anterior,
    ROUND(100.0 * (actual.ingresos - anterior.ingresos) / NULLIF(anterior.ingresos, 0), 2) AS crecimiento_yoy_pct
FROM por_trimestre actual
LEFT JOIN por_trimestre anterior
    ON anterior.anio = actual.anio - 1 AND anterior.trimestre = actual.trimestre
ORDER BY actual.anio, actual.trimestre;

-- ============================================================================
-- Query 3: Top 10 clientes por ingresos (con su segmento y país)
-- ============================================================================
SELECT TOP 10
    c.nombre, c.segmento, c.pais,
    SUM(v.total_linea) AS ingresos,
    SUM(v.margen_bruto_linea) AS margen_bruto,
    COUNT(DISTINCT v.orden_id) AS ordenes
FROM dbo.fact_ventas v
JOIN dbo.dim_cliente c ON v.cliente_key = c.cliente_key
JOIN dbo.dim_estado_orden e ON v.estado_orden_key = e.estado_orden_key
WHERE e.es_cancelada = 0 AND c.cliente_key <> -1
GROUP BY c.nombre, c.segmento, c.pais
ORDER BY ingresos DESC;

-- ============================================================================
-- Query 4: Ventas y margen por categoría de producto
-- ============================================================================
SELECT
    p.categoria,
    p.subcategoria,
    SUM(v.total_linea) AS ingresos,
    SUM(v.margen_bruto_linea) AS margen_bruto,
    ROUND(100.0 * SUM(v.margen_bruto_linea) / NULLIF(SUM(v.total_linea), 0), 2) AS margen_pct,
    SUM(v.cantidad) AS unidades_vendidas,
    ROUND(100.0 * SUM(v.cantidad_devuelta) / NULLIF(SUM(v.cantidad), 0), 2) AS tasa_devolucion_pct
FROM dbo.fact_ventas v
JOIN dbo.dim_producto p ON v.producto_key = p.producto_key
JOIN dbo.dim_estado_orden e ON v.estado_orden_key = e.estado_orden_key
WHERE e.es_cancelada = 0
GROUP BY p.categoria, p.subcategoria
ORDER BY ingresos DESC;

-- ============================================================================
-- Query 5: Performance de vendedores (ranking por equipo)
-- ============================================================================
SELECT
    ve.equipo,
    ve.nombre AS vendedor,
    ve.territorio,
    ve.gerente_nombre,
    SUM(v.total_linea) AS ventas_totales,
    COUNT(DISTINCT v.orden_id) AS ordenes,
    RANK() OVER (PARTITION BY ve.equipo ORDER BY SUM(v.total_linea) DESC) AS ranking_en_equipo
FROM dbo.fact_ventas v
JOIN dbo.dim_vendedor ve ON v.vendedor_key = ve.vendedor_key
JOIN dbo.dim_estado_orden e ON v.estado_orden_key = e.estado_orden_key
WHERE e.es_cancelada = 0 AND ve.vendedor_key <> -1
GROUP BY ve.equipo, ve.nombre, ve.territorio, ve.gerente_nombre
ORDER BY ve.equipo, ranking_en_equipo;

-- ============================================================================
-- Query 6: Ventas por segmento de cliente x mes (matriz para tabla dinámica)
-- ============================================================================
SELECT
    f.mes_anio,
    c.segmento,
    SUM(v.total_linea) AS ingresos
FROM dbo.fact_ventas v
JOIN dbo.dim_fecha f ON v.fecha_key = f.fecha_key
JOIN dbo.dim_cliente c ON v.cliente_key = c.cliente_key
JOIN dbo.dim_estado_orden e ON v.estado_orden_key = e.estado_orden_key
WHERE e.es_cancelada = 0
GROUP BY f.mes_anio, c.segmento
ORDER BY f.mes_anio, c.segmento;

-- ============================================================================
-- Query 7: Embudo de cobranza — cuánto está pagado, parcial, pendiente, vencido
-- ============================================================================
SELECT
    eo.estado_pago,
    COUNT(DISTINCT v.orden_id) AS ordenes,
    SUM(v.total_linea) AS monto_en_ese_estado
FROM dbo.fact_ventas v
JOIN dbo.dim_estado_orden eo ON v.estado_orden_key = eo.estado_orden_key
WHERE eo.es_cancelada = 0
GROUP BY eo.estado_pago
ORDER BY monto_en_ese_estado DESC;

-- ============================================================================
-- Query 8: Patrón de ventas por día de la semana (para detectar estacionalidad)
-- ============================================================================
SELECT
    f.dia_semana,
    f.nombre_dia,
    f.es_fin_semana,
    COUNT(DISTINCT v.orden_id) AS ordenes,
    SUM(v.total_linea) AS ingresos,
    ROUND(AVG(v.total_linea), 2) AS ingreso_promedio_linea
FROM dbo.fact_ventas v
JOIN dbo.dim_fecha f ON v.fecha_key = f.fecha_key
JOIN dbo.dim_estado_orden e ON v.estado_orden_key = e.estado_orden_key
WHERE e.es_cancelada = 0
GROUP BY f.dia_semana, f.nombre_dia, f.es_fin_semana
ORDER BY f.dia_semana;

-- ============================================================================
-- Query 9: Medios de pago — volumen y monto (fact_pagos, dimensión conformada)
-- ============================================================================
SELECT
    mp.metodo_pago,
    COUNT(*) AS cantidad_pagos,
    SUM(p.monto_pago) AS monto_total,
    SUM(CASE WHEN p.es_completado = 1 THEN 1 ELSE 0 END) AS pagos_completados
FROM dbo.fact_pagos p
JOIN dbo.dim_metodo_pago mp ON p.metodo_pago_key = mp.metodo_pago_key
GROUP BY mp.metodo_pago
ORDER BY monto_total DESC;

-- ============================================================================
-- Query 10: Motivos de devolución con mayor impacto económico
-- ============================================================================
SELECT
    d.motivo,
    COUNT(*) AS cantidad_devoluciones,
    SUM(d.monto_reembolso) AS total_reembolsado,
    ROUND(AVG(d.monto_reembolso), 2) AS reembolso_promedio
FROM dbo.fact_devoluciones d
GROUP BY d.motivo
ORDER BY total_reembolsado DESC;

-- ============================================================================
-- Query 11: KPI ejecutivo de una sola fila (para un tile de dashboard)
-- ============================================================================
SELECT
    SUM(v.total_linea) AS ingresos_totales,
    SUM(v.margen_bruto_linea) AS margen_bruto_total,
    COUNT(DISTINCT v.orden_id) AS ordenes_totales,
    COUNT(DISTINCT v.cliente_key) AS clientes_activos,
    ROUND(SUM(v.total_linea) / NULLIF(COUNT(DISTINCT v.orden_id), 0), 2) AS ticket_promedio
FROM dbo.fact_ventas v
JOIN dbo.dim_estado_orden e ON v.estado_orden_key = e.estado_orden_key
WHERE e.es_cancelada = 0;

-- ============================================================================
-- FIN DE QUERIES DE EJEMPLO
-- ============================================================================
