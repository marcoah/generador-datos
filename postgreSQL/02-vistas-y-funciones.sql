-- ============================================================================
-- VISTAS Y FUNCIONES ANALÍTICAS PARA DASHBOARDS
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- VISTAS: ANÁLISIS DE VENTAS
-- ============================================================================

-- Vista: Resumen diario de ventas
CREATE OR REPLACE VIEW v_resumen_ventas_diario AS
SELECT
    DATE(o.fecha_orden) AS fecha_venta,
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

FROM ordenes o
WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL '2 years'
GROUP BY DATE(o.fecha_orden)
ORDER BY fecha_venta DESC;

-- Vista: Ventas por categoría de producto
CREATE OR REPLACE VIEW v_ventas_por_categoria AS
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

FROM items_orden io
JOIN ordenes o ON io.orden_id = o.id
JOIN productos p ON io.producto_id = p.id
WHERE o.estado != 'cancelado'
GROUP BY p.categoria, p.subcategoria
ORDER BY ingresos_totales DESC;

-- Vista: Performance de vendedores
CREATE OR REPLACE VIEW v_performance_vendedores AS
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

    COUNT(DISTINCT DATE(o.fecha_orden)) AS dias_activos_venta,

    COUNT(CASE WHEN o.estado = 'entregado' THEN 1 END) AS ordenes_entregadas,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas,
    COUNT(CASE WHEN o.estado_pago = 'pendiente' THEN 1 END) AS ordenes_sin_pago,

    -- Comparación con cuota (mes actual)
    SUM(CASE
        WHEN DATE_TRUNC('month', o.fecha_orden) = DATE_TRUNC('month', CURRENT_DATE)
        THEN o.monto_total
        ELSE 0
    END) AS ventas_mes_actual,

    ROUND(
        100.0 * SUM(CASE
            WHEN DATE_TRUNC('month', o.fecha_orden) = DATE_TRUNC('month', CURRENT_DATE)
            THEN o.monto_total
            ELSE 0
        END) / NULLIF(v.cuota_mensual, 0),
        2
    ) AS porcentaje_cumplimiento_cuota,

    MAX(o.fecha_orden) AS fecha_ultima_venta,
    CURRENT_DATE - MAX(o.fecha_orden)::DATE AS dias_desde_ultima_venta

FROM vendedores v
LEFT JOIN ordenes o ON v.id = o.vendedor_id AND o.estado != 'cancelado'
WHERE v.activo = TRUE
GROUP BY v.id, v.uuid, v.nombre, v.equipo, v.territorio, v.cuota_mensual, v.tasa_comision
ORDER BY ventas_totales DESC;

-- Vista: Segmentación de clientes
CREATE OR REPLACE VIEW v_segmentacion_clientes AS
SELECT
    c.id,
    c.uuid,
    c.nombre,
    c.segmento,
    c.industria,
    c.tamaño_empresa,
    c.pais,

    COUNT(DISTINCT o.id) AS total_ordenes,
    SUM(o.monto_total) AS valor_vida,
    AVG(o.monto_total) AS valor_promedio_orden,
    MAX(o.fecha_orden) AS fecha_ultima_compra,
    CURRENT_DATE - MAX(o.fecha_orden)::DATE AS dias_desde_ultima_compra,

    DATE(MAX(o.fecha_orden)) - DATE(MIN(o.fecha_orden)) AS dias_como_cliente,
    ROUND(
        COUNT(DISTINCT o.id)::NUMERIC /
        GREATEST(1, (CURRENT_DATE - DATE(MIN(o.fecha_orden))) / 30),
        2
    ) AS ordenes_por_mes,

    COUNT(DISTINCT DATE_TRUNC('month', o.fecha_orden)) AS meses_activos,

    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END) AS ordenes_canceladas,
    COUNT(CASE WHEN o.estado_pago != 'pagado' THEN 1 END) AS ordenes_sin_pago,

    COUNT(DISTINCT ic.id) AS total_interacciones,
    MAX(ic.fecha_interaccion) AS fecha_ultima_interaccion

FROM clientes c
LEFT JOIN ordenes o ON c.id = o.cliente_id
LEFT JOIN interacciones_clientes ic ON c.id = ic.cliente_id
WHERE c.activo = TRUE
GROUP BY c.id, c.uuid, c.nombre, c.segmento, c.industria, c.tamaño_empresa, c.pais
ORDER BY valor_vida DESC;

-- Vista: Análisis de devoluciones
CREATE OR REPLACE VIEW v_analisis_devoluciones AS
SELECT
    DATE(d.fecha_devolucion) AS fecha_devolucion,
    p.categoria,
    p.subcategoria,

    COUNT(DISTINCT d.id) AS cantidad_devoluciones,
    SUM(d.monto_reembolso) AS total_reembolsado,

    COUNT(DISTINCT d.orden_id) AS ordenes_con_devolucion,
    COUNT(DISTINCT d.orden_id) * 1.0 / (
        SELECT COUNT(DISTINCT id) FROM ordenes
        WHERE DATE(fecha_orden) = DATE(d.fecha_devolucion)
    ) AS tasa_devolucion_pct,

    COUNT(CASE WHEN d.estado = 'aprobado' THEN 1 END) AS devoluciones_aprobadas,
    COUNT(CASE WHEN d.estado = 'pendiente' THEN 1 END) AS devoluciones_pendientes,
    COUNT(CASE WHEN d.estado = 'rechazado' THEN 1 END) AS devoluciones_rechazadas,

    d.motivo

FROM devoluciones d
JOIN ordenes o ON d.orden_id = o.id
LEFT JOIN items_orden io ON o.id = io.orden_id
LEFT JOIN productos p ON io.producto_id = p.id
WHERE d.fecha_devolucion >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY DATE(d.fecha_devolucion), p.categoria, p.subcategoria, d.motivo
ORDER BY fecha_devolucion DESC;

-- Vista: Análisis de flujo de pagos
CREATE OR REPLACE VIEW v_analisis_pagos AS
SELECT
    DATE(p.fecha_pago) AS fecha_pago,
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
        WHEN (o.fecha_orden + INTERVAL '30 days') < p.fecha_pago THEN o.id
    END) AS pagos_atrasados_30d,

    COUNT(DISTINCT CASE
        WHEN (o.fecha_orden + INTERVAL '60 days') < p.fecha_pago THEN o.id
    END) AS pagos_atrasados_60d

FROM pagos p
JOIN ordenes o ON p.orden_id = o.id
WHERE p.fecha_pago >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY DATE(p.fecha_pago), p.metodo_pago
ORDER BY fecha_pago DESC;

-- Vista: Performance de campañas
CREATE OR REPLACE VIEW v_performance_campanas AS
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
    COUNT(DISTINCT CASE WHEN cc.convirtio = TRUE THEN cc.cliente_id END) AS clientes_convertidos

FROM campanas c
LEFT JOIN campanas_clientes cc ON c.id = cc.campana_id
WHERE c.fecha_inicio >= CURRENT_DATE - INTERVAL '2 years'
GROUP BY c.id, c.uuid, c.nombre, c.tipo_campana, c.canal, c.fecha_inicio, c.fecha_fin,
         c.presupuesto, c.gasto_real, c.impresiones, c.clics, c.conversiones, c.ingresos_generados
ORDER BY c.fecha_inicio DESC;

-- ============================================================================
-- VISTAS MATERIALIZADAS (para mejor performance)
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_tendencia_ventas_mensual AS
SELECT
    DATE_TRUNC('month', o.fecha_orden)::DATE AS mes,
    EXTRACT(YEAR FROM o.fecha_orden)::INT AS anio,
    EXTRACT(MONTH FROM o.fecha_orden)::INT AS numero_mes,

    COUNT(DISTINCT o.id) AS ordenes,
    COUNT(DISTINCT o.cliente_id) AS clientes,
    SUM(o.monto_total) AS ingresos,
    AVG(o.monto_total) AS valor_promedio_orden,

    SUM(CASE WHEN o.estado = 'entregado' THEN o.monto_total ELSE 0 END) AS ingresos_entregados,
    SUM(CASE WHEN o.estado = 'cancelado' THEN o.monto_total ELSE 0 END) AS ingresos_cancelados,

    SUM(o.monto_total) - SUM(COALESCE(io.cantidad * p.precio_costo, 0)) AS ganancia_bruta

FROM ordenes o
LEFT JOIN items_orden io ON o.id = io.orden_id
LEFT JOIN productos p ON io.producto_id = p.id
WHERE o.estado != 'cancelado'
GROUP BY DATE_TRUNC('month', o.fecha_orden), EXTRACT(YEAR FROM o.fecha_orden), EXTRACT(MONTH FROM o.fecha_orden)
ORDER BY mes DESC;

CREATE INDEX idx_mv_tendencia_ventas_mes ON mv_tendencia_ventas_mensual(mes);

-- Vista materializada: Top productos por categoría
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_top_productos_por_categoria AS
SELECT
    p.categoria,
    p.id,
    p.uuid,
    p.nombre,
    p.sku,

    COUNT(DISTINCT io.orden_id) AS veces_pedido,
    SUM(io.cantidad) AS cantidad_total_vendida,
    SUM(io.total_linea) AS ingresos_totales,

    ROW_NUMBER() OVER (PARTITION BY p.categoria ORDER BY SUM(io.total_linea) DESC) AS ranking_categoria

FROM productos p
LEFT JOIN items_orden io ON p.id = io.producto_id
LEFT JOIN ordenes o ON io.orden_id = o.id AND o.estado != 'cancelado'
WHERE p.activo = TRUE
GROUP BY p.categoria, p.id, p.uuid, p.nombre, p.sku
ORDER BY p.categoria, ingresos_totales DESC;

-- ============================================================================
-- FUNCIONES ANALÍTICAS
-- ============================================================================

-- Función: Calcular ARR (Ingreso Anual Recurrente)
CREATE OR REPLACE FUNCTION calcular_arr(
    p_meses_periodo INT DEFAULT 12
)
RETURNS TABLE (
    segmento VARCHAR,
    ingreso_mensual NUMERIC,
    ingreso_anual NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.segmento,
        ROUND(AVG(ventas_mensuales), 2) AS ingreso_mensual,
        ROUND(AVG(ventas_mensuales) * 12, 2) AS ingreso_anual
    FROM (
        SELECT
            c2.segmento,
            DATE_TRUNC('month', o.fecha_orden)::DATE AS mes,
            SUM(o.monto_total) AS ventas_mensuales
        FROM ordenes o
        JOIN clientes c2 ON o.cliente_id = c2.id
        WHERE o.fecha_orden >= CURRENT_DATE - (p_meses_periodo || ' months')::INTERVAL
        AND o.estado != 'cancelado'
        GROUP BY c2.segmento, DATE_TRUNC('month', o.fecha_orden)
    ) t
    GROUP BY segmento
    ORDER BY ingreso_anual DESC;
END;
$$ LANGUAGE plpgsql;

-- Función: Calcular churn de clientes
CREATE OR REPLACE FUNCTION calcular_churn(
    p_dias_periodo INT DEFAULT 90
)
RETURNS TABLE (
    segmento VARCHAR,
    total_clientes_inicio_periodo BIGINT,
    clientes_perdidos BIGINT,
    tasa_churn_pct NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH clientes_periodo AS (
        SELECT DISTINCT c.id, c.segmento
        FROM clientes c
        JOIN ordenes o ON c.id = o.cliente_id
        WHERE o.fecha_orden >= CURRENT_DATE - (p_dias_periodo || ' days')::INTERVAL
        AND o.estado != 'cancelado'
    ),
    clientes_perdidos AS (
        SELECT DISTINCT c.id, c.segmento
        FROM clientes c
        WHERE c.id NOT IN (
            SELECT DISTINCT c2.id
            FROM clientes c2
            JOIN ordenes o ON c2.id = o.cliente_id
            WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL '30 days'
            AND o.estado != 'cancelado'
        )
        AND c.id IN (
            SELECT DISTINCT c3.id
            FROM clientes c3
            JOIN ordenes o ON c3.id = o.cliente_id
            WHERE o.fecha_orden >= CURRENT_DATE - (p_dias_periodo || ' days')::INTERVAL
            AND o.estado != 'cancelado'
        )
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
END;
$$ LANGUAGE plpgsql;

-- Función: Forecast simple de ventas (tendencia lineal)
CREATE OR REPLACE FUNCTION pronostico_ventas(
    p_meses_pronostico INT DEFAULT 3,
    p_meses_historico INT DEFAULT 12
)
RETURNS TABLE (
    mes_pronostico DATE,
    ingreso_pronosticado NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH datos_historicos AS (
        SELECT
            DATE_TRUNC('month', o.fecha_orden)::DATE AS mes,
            SUM(o.monto_total) AS ingresos,
            ROW_NUMBER() OVER (ORDER BY DATE_TRUNC('month', o.fecha_orden)) AS seq_mes
        FROM ordenes o
        WHERE o.fecha_orden >= CURRENT_DATE - (p_meses_historico || ' months')::INTERVAL
        AND o.estado != 'cancelado'
        GROUP BY DATE_TRUNC('month', o.fecha_orden)
    ),
    tendencia AS (
        SELECT
            REGR_SLOPE(ingresos, seq_mes) AS pendiente,
            REGR_INTERCEPT(ingresos, seq_mes) AS intercepto,
            MAX(seq_mes) AS ultimo_seq,
            MAX(mes) AS ultimo_mes
        FROM datos_historicos
    )
    SELECT
        (t.ultimo_mes + (n || ' months')::INTERVAL)::DATE AS mes_pronostico,
        GREATEST(0, ROUND(t.intercepto + t.pendiente * (t.ultimo_seq + n), 2)) AS ingreso_pronosticado
    FROM tendencia t
    CROSS JOIN GENERATE_SERIES(1, p_meses_pronostico) n
    WHERE t.pendiente IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Función: Análisis de cohortes
CREATE OR REPLACE FUNCTION analisis_cohortes(
    p_metrica VARCHAR DEFAULT 'ingresos'  -- 'ingresos', 'ordenes', 'retencion'
)
RETURNS TABLE (
    mes_cohorte DATE,
    meses_desde_primera_orden INT,
    valor_metrica NUMERIC,
    cantidad_clientes BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH cohortes_clientes AS (
        SELECT
            c.id,
            DATE_TRUNC('month', MIN(o.fecha_orden))::DATE AS mes_cohorte,
            DATE_TRUNC('month', o.fecha_orden)::DATE AS mes_orden
        FROM clientes c
        JOIN ordenes o ON c.id = o.cliente_id
        WHERE o.estado != 'cancelado'
        GROUP BY c.id, DATE_TRUNC('month', o.fecha_orden)
    ),
    cohortes_con_metricas AS (
        SELECT
            cc.mes_cohorte,
            EXTRACT(MONTH FROM cc.mes_orden - cc.mes_cohorte)::INT / 1 AS meses_transcurridos,
            CASE p_metrica
                WHEN 'ingresos' THEN SUM(o.monto_total)
                WHEN 'ordenes' THEN COUNT(DISTINCT o.id)
                ELSE COUNT(DISTINCT cc.id)
            END AS metrica,
            COUNT(DISTINCT cc.id) AS clientes
        FROM cohortes_clientes cc
        JOIN ordenes o ON cc.id = o.cliente_id AND DATE_TRUNC('month', o.fecha_orden) = cc.mes_orden
        WHERE o.estado != 'cancelado'
        GROUP BY cc.mes_cohorte, EXTRACT(MONTH FROM cc.mes_orden - cc.mes_cohorte)
    )
    SELECT
        mes_cohorte,
        meses_transcurridos,
        ROUND(metrica, 2),
        clientes
    FROM cohortes_con_metricas
    WHERE meses_transcurridos >= 0
    ORDER BY mes_cohorte DESC, meses_transcurridos ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ACTUALIZAR VISTAS MATERIALIZADAS
-- ============================================================================

CREATE OR REPLACE FUNCTION refrescar_vistas_materializadas()
RETURNS TABLE (nombre_vista TEXT, estado TEXT, tiempo_refresco INTERVAL) AS $$
DECLARE
    v_inicio TIMESTAMP;
    v_fin TIMESTAMP;
BEGIN
    v_inicio := CURRENT_TIMESTAMP;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tendencia_ventas_mensual;
    v_fin := CURRENT_TIMESTAMP;
    RETURN QUERY SELECT 'mv_tendencia_ventas_mensual'::TEXT, 'completado'::TEXT, (v_fin - v_inicio);

    v_inicio := CURRENT_TIMESTAMP;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_productos_por_categoria;
    v_fin := CURRENT_TIMESTAMP;
    RETURN QUERY SELECT 'mv_top_productos_por_categoria'::TEXT, 'completado'::TEXT, (v_fin - v_inicio);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FIN DE VISTAS Y FUNCIONES ANALÍTICAS
-- ============================================================================
