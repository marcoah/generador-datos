-- ============================================================================
-- VISTAS Y FUNCIONES ANALÍTICAS PARA DASHBOARDS
-- MySQL 8.0+
-- ============================================================================
-- NOTA: MySQL no permite DML (INSERT/UPDATE/DELETE) dentro de FUNCTIONs, y no
-- soporta funciones de tabla ni vistas materializadas. Por eso:
-- - Las funciones analíticas de PostgreSQL/T-SQL se implementan como
--   PROCEDURES (se invocan con CALL en vez de SELECT * FROM ...).
-- - Las vistas materializadas se implementan como tablas de caché +
--   un procedimiento de refresco (mismo patrón que t-sql/02-vistas-y-funciones.sql).
-- ============================================================================

USE ventas_test;

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

FROM orden_encabezado o
WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL 2 YEAR
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

FROM orden_detalles io
JOIN orden_encabezado o ON io.orden_id = o.id
JOIN productos p ON io.producto_id = p.id
WHERE o.estado <> 'cancelado'
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
        WHEN DATE_FORMAT(o.fecha_orden, '%Y-%m') = DATE_FORMAT(CURRENT_DATE, '%Y-%m')
        THEN o.monto_total
        ELSE 0
    END) AS ventas_mes_actual,

    ROUND(
        100.0 * SUM(CASE
            WHEN DATE_FORMAT(o.fecha_orden, '%Y-%m') = DATE_FORMAT(CURRENT_DATE, '%Y-%m')
            THEN o.monto_total
            ELSE 0
        END) / NULLIF(v.cuota_mensual, 0),
        2
    ) AS porcentaje_cumplimiento_cuota,

    MAX(o.fecha_orden) AS fecha_ultima_venta,
    DATEDIFF(CURRENT_DATE, MAX(o.fecha_orden)) AS dias_desde_ultima_venta

FROM vendedores v
LEFT JOIN orden_encabezado o ON v.id = o.vendedor_id AND o.estado <> 'cancelado'
WHERE v.activo = 1
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
    c.tamano_empresa,
    c.pais,

    COUNT(DISTINCT o.id) AS total_ordenes,
    SUM(o.monto_total) AS valor_vida,
    AVG(o.monto_total) AS valor_promedio_orden,
    MAX(o.fecha_orden) AS fecha_ultima_compra,
    DATEDIFF(CURRENT_DATE, MAX(o.fecha_orden)) AS dias_desde_ultima_compra,

    DATEDIFF(MAX(o.fecha_orden), MIN(o.fecha_orden)) AS dias_como_cliente,
    ROUND(
        COUNT(DISTINCT o.id) /
        GREATEST(1, DATEDIFF(CURRENT_DATE, MIN(o.fecha_orden)) / 30),
        2
    ) AS ordenes_por_mes,

    COUNT(DISTINCT DATE_FORMAT(o.fecha_orden, '%Y-%m')) AS meses_activos,

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
CREATE OR REPLACE VIEW v_analisis_devoluciones AS
WITH devoluciones_por_dia AS (
    SELECT d.*, DATE(d.fecha_devolucion) AS dia_devolucion
    FROM devoluciones d
    WHERE d.fecha_devolucion >= CURRENT_DATE - INTERVAL 1 YEAR
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
        WHERE DATE(fecha_orden) = d.dia_devolucion
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
        WHEN DATE_ADD(o.fecha_orden, INTERVAL 30 DAY) < p.fecha_pago THEN o.id
    END) AS pagos_atrasados_30d,

    COUNT(DISTINCT CASE
        WHEN DATE_ADD(o.fecha_orden, INTERVAL 60 DAY) < p.fecha_pago THEN o.id
    END) AS pagos_atrasados_60d

FROM pagos p
JOIN orden_encabezado o ON p.orden_id = o.id
WHERE p.fecha_pago >= CURRENT_DATE - INTERVAL 1 YEAR
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
    COUNT(DISTINCT CASE WHEN cc.convirtio = 1 THEN cc.cliente_id END) AS clientes_convertidos

FROM campanas c
LEFT JOIN campanas_clientes cc ON c.id = cc.campana_id
WHERE c.fecha_inicio >= CURRENT_DATE - INTERVAL 2 YEAR
GROUP BY c.id, c.uuid, c.nombre, c.tipo_campana, c.canal, c.fecha_inicio, c.fecha_fin,
         c.presupuesto, c.gasto_real, c.impresiones, c.clics, c.conversiones, c.ingresos_generados
ORDER BY c.fecha_inicio DESC;

-- ============================================================================
-- TABLAS DE CACHÉ (equivalente a MATERIALIZED VIEW en PostgreSQL)
-- MySQL no soporta vistas materializadas: se usan tablas + procedimiento de refresco.
-- ============================================================================

CREATE TABLE IF NOT EXISTS mv_tendencia_ventas_mensual (
    mes DATE NOT NULL PRIMARY KEY,
    anio INT NOT NULL,
    numero_mes INT NOT NULL,
    ordenes INT NOT NULL,
    clientes INT NOT NULL,
    ingresos DECIMAL(15,2) NOT NULL,
    valor_promedio_orden DECIMAL(15,2) NOT NULL,
    ingresos_entregados DECIMAL(15,2) NOT NULL,
    ingresos_cancelados DECIMAL(15,2) NOT NULL,
    ganancia_bruta DECIMAL(15,2) NOT NULL,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mv_top_productos_por_categoria (
    categoria VARCHAR(100) NOT NULL,
    id BIGINT UNSIGNED NOT NULL,
    uuid CHAR(36) NOT NULL,
    nombre VARCHAR(255) NOT NULL,
    sku VARCHAR(50) NOT NULL,
    veces_pedido INT NOT NULL,
    cantidad_total_vendida INT NOT NULL,
    ingresos_totales DECIMAL(15,2) NOT NULL,
    ranking_categoria INT NOT NULL,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (categoria, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER //

CREATE PROCEDURE sp_refrescar_vistas_materializadas()
BEGIN
    TRUNCATE TABLE mv_tendencia_ventas_mensual;

    INSERT INTO mv_tendencia_ventas_mensual
        (mes, anio, numero_mes, ordenes, clientes, ingresos,
         valor_promedio_orden, ingresos_entregados, ingresos_cancelados, ganancia_bruta)
    SELECT
        DATE(DATE_FORMAT(o.fecha_orden, '%Y-%m-01')) AS mes,
        YEAR(o.fecha_orden) AS anio,
        MONTH(o.fecha_orden) AS numero_mes,
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
    GROUP BY DATE(DATE_FORMAT(o.fecha_orden, '%Y-%m-01')), YEAR(o.fecha_orden), MONTH(o.fecha_orden);

    TRUNCATE TABLE mv_top_productos_por_categoria;

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
END//

DELIMITER ;

-- ============================================================================
-- PROCEDIMIENTOS ANALÍTICOS
-- (MySQL no permite funciones de tabla: se exponen como PROCEDURE, invocar con
--  CALL sp_calcular_arr(12); en vez de SELECT * FROM calcular_arr(12))
-- ============================================================================

DELIMITER //

-- Procedimiento: Calcular ARR (Ingreso Anual Recurrente) por segmento
CREATE PROCEDURE sp_calcular_arr(IN p_meses_periodo INT)
BEGIN
    SELECT
        t.segmento,
        ROUND(AVG(t.ventas_mensuales), 2) AS ingreso_mensual,
        ROUND(AVG(t.ventas_mensuales) * 12, 2) AS ingreso_anual
    FROM (
        SELECT
            c2.segmento,
            DATE_FORMAT(o.fecha_orden, '%Y-%m-01') AS mes,
            SUM(o.monto_total) AS ventas_mensuales
        FROM orden_encabezado o
        JOIN clientes c2 ON o.cliente_id = c2.id
        WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL p_meses_periodo MONTH
          AND o.estado <> 'cancelado'
        GROUP BY c2.segmento, DATE_FORMAT(o.fecha_orden, '%Y-%m-01')
    ) t
    GROUP BY t.segmento
    ORDER BY ingreso_anual DESC;
END//

-- Procedimiento: Calcular churn de clientes
CREATE PROCEDURE sp_calcular_churn(IN p_dias_periodo INT)
BEGIN
    WITH clientes_periodo AS (
        SELECT DISTINCT c.id, c.segmento
        FROM clientes c
        JOIN orden_encabezado o ON c.id = o.cliente_id
        WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL p_dias_periodo DAY
          AND o.estado <> 'cancelado'
    ),
    clientes_perdidos AS (
        SELECT DISTINCT c.id, c.segmento
        FROM clientes c
        WHERE c.id NOT IN (
            SELECT DISTINCT c2.id
            FROM clientes c2
            JOIN orden_encabezado o ON c2.id = o.cliente_id
            WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL 30 DAY
              AND o.estado <> 'cancelado'
        )
        AND c.id IN (
            SELECT DISTINCT c3.id
            FROM clientes c3
            JOIN orden_encabezado o ON c3.id = o.cliente_id
            WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL p_dias_periodo DAY
              AND o.estado <> 'cancelado'
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
END//

-- Procedimiento: Forecast simple de ventas (regresión lineal manual;
-- MySQL no tiene REGR_SLOPE/REGR_INTERCEPT)
CREATE PROCEDURE sp_pronostico_ventas(IN p_meses_pronostico INT, IN p_meses_historico INT)
BEGIN
    WITH RECURSIVE datos_historicos AS (
        SELECT
            DATE_FORMAT(o.fecha_orden, '%Y-%m-01') AS mes,
            SUM(o.monto_total) AS ingresos,
            ROW_NUMBER() OVER (ORDER BY DATE_FORMAT(o.fecha_orden, '%Y-%m-01')) AS seq_mes
        FROM orden_encabezado o
        WHERE o.fecha_orden >= CURRENT_DATE - INTERVAL p_meses_historico MONTH
          AND o.estado <> 'cancelado'
        GROUP BY DATE_FORMAT(o.fecha_orden, '%Y-%m-01')
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
            ultimo_seq,
            ultimo_mes,
            CASE WHEN (n * sum_x2 - sum_x * sum_x) = 0 THEN 0
                 ELSE (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
            END AS pendiente,
            CASE WHEN (n * sum_x2 - sum_x * sum_x) = 0 THEN sum_y / NULLIF(n, 0)
                 ELSE (sum_y - ((n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)) * sum_x) / NULLIF(n, 0)
            END AS intercepto
        FROM estadisticas
    ),
    numeros_mes AS (
        SELECT 1 AS n
        UNION ALL SELECT n + 1 FROM numeros_mes WHERE n < 24
    )
    SELECT
        DATE_ADD(t.ultimo_mes, INTERVAL nm.n MONTH) AS mes_pronostico,
        GREATEST(0, ROUND(t.intercepto + t.pendiente * (t.ultimo_seq + nm.n), 2)) AS ingreso_pronosticado
    FROM tendencia t
    CROSS JOIN numeros_mes nm
    WHERE nm.n <= p_meses_pronostico
      AND t.pendiente IS NOT NULL;
END//

-- Procedimiento: Análisis de cohortes
CREATE PROCEDURE sp_analisis_cohortes(IN p_metrica VARCHAR(20))
BEGIN
    WITH cohortes_clientes AS (
        SELECT
            c.id,
            DATE_FORMAT(MIN(o.fecha_orden), '%Y-%m-01') AS mes_cohorte,
            DATE_FORMAT(o.fecha_orden, '%Y-%m-01') AS mes_orden
        FROM clientes c
        JOIN orden_encabezado o ON c.id = o.cliente_id
        WHERE o.estado <> 'cancelado'
        GROUP BY c.id, DATE_FORMAT(o.fecha_orden, '%Y-%m-01')
    ),
    cohortes_con_metricas AS (
        SELECT
            cc.mes_cohorte,
            (YEAR(cc.mes_orden) - YEAR(cc.mes_cohorte)) * 12
                + (MONTH(cc.mes_orden) - MONTH(cc.mes_cohorte)) AS meses_transcurridos,
            CASE p_metrica
                WHEN 'ingresos' THEN SUM(o.monto_total)
                WHEN 'ordenes' THEN COUNT(DISTINCT o.id)
                ELSE COUNT(DISTINCT cc.id)
            END AS metrica,
            COUNT(DISTINCT cc.id) AS clientes
        FROM cohortes_clientes cc
        JOIN orden_encabezado o
            ON cc.id = o.cliente_id AND DATE_FORMAT(o.fecha_orden, '%Y-%m-01') = cc.mes_orden
        WHERE o.estado <> 'cancelado'
        GROUP BY cc.mes_cohorte,
                 (YEAR(cc.mes_orden) - YEAR(cc.mes_cohorte)) * 12 + (MONTH(cc.mes_orden) - MONTH(cc.mes_cohorte))
    )
    SELECT
        ccm.mes_cohorte,
        ccm.meses_transcurridos,
        ROUND(ccm.metrica, 2) AS valor_metrica,
        ccm.clientes AS cantidad_clientes
    FROM cohortes_con_metricas ccm
    WHERE ccm.meses_transcurridos >= 0
    ORDER BY ccm.mes_cohorte DESC, ccm.meses_transcurridos ASC;
END//

DELIMITER ;

-- ============================================================================
-- FIN DE VISTAS Y FUNCIONES ANALÍTICAS
-- ============================================================================
