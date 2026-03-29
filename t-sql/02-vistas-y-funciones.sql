-- ============================================================================
-- VISTAS Y FUNCIONES ANALÍTICAS PARA DASHBOARDS
-- SQL Server 2016+
-- ============================================================================

-- ============================================================================
-- VISTAS: ANÁLISIS DE VENTAS
-- ============================================================================

-- Vista: Resumen diario de ventas
CREATE OR ALTER VIEW dbo.v_resumen_ventas_diario AS
SELECT
    CAST(o.fecha_orden AS DATE)                                          AS fecha_venta,
    COUNT(DISTINCT o.id)                                                 AS cantidad_ordenes,
    COUNT(DISTINCT o.cliente_id)                                         AS clientes_unicos,
    COUNT(DISTINCT o.vendedor_id)                                        AS vendedores_involucrados,

    SUM(o.monto_total)                                                   AS ingresos_totales,
    AVG(o.monto_total)                                                   AS valor_promedio_orden,
    MIN(o.monto_total)                                                   AS orden_minima,
    MAX(o.monto_total)                                                   AS orden_maxima,

    SUM(o.subtotal)                                                      AS suma_subtotales,
    SUM(o.monto_descuento)                                               AS total_descuentos,
    SUM(o.monto_impuesto)                                                AS total_impuestos,
    SUM(o.costo_envio)                                                   AS total_envios,

    COUNT(CASE WHEN o.estado = 'entregado' THEN 1 END)                  AS ordenes_entregadas,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END)                  AS ordenes_canceladas,
    COUNT(CASE WHEN o.estado_pago = 'pagado' THEN 1 END)                AS ordenes_pagadas,
    COUNT(CASE WHEN o.estado_pago = 'pendiente' THEN 1 END)             AS ordenes_pago_pendiente

FROM dbo.ordenes o
WHERE o.fecha_orden >= DATEADD(YEAR, -2, GETDATE())
GROUP BY CAST(o.fecha_orden AS DATE);
GO

-- Vista: Ventas por categoría de producto
CREATE OR ALTER VIEW dbo.v_ventas_por_categoria AS
SELECT
    p.categoria,
    p.subcategoria,
    COUNT(DISTINCT o.id)                                                        AS cantidad_ordenes,
    COUNT(DISTINCT io.id)                                                       AS unidades_vendidas,
    SUM(io.cantidad)                                                            AS cantidad_total,

    SUM(io.total_linea)                                                         AS ingresos_totales,
    AVG(io.precio_unitario)                                                     AS precio_unitario_promedio,

    SUM(CAST(io.cantidad AS DECIMAL(15,2)) * p.precio_costo)                   AS costo_total,
    SUM(io.total_linea) - SUM(CAST(io.cantidad AS DECIMAL(15,2)) * p.precio_costo) AS ganancia_bruta,
    ROUND(
        100.0 * (SUM(io.total_linea) - SUM(CAST(io.cantidad AS DECIMAL(15,2)) * p.precio_costo))
        / NULLIF(SUM(io.total_linea), 0), 2
    )                                                                           AS margen_ganancia_pct,

    COUNT(DISTINCT o.cliente_id)                                                AS clientes_unicos,
    SUM(io.cantidad_devuelta)                                                   AS unidades_devueltas

FROM dbo.items_orden io
JOIN dbo.ordenes  o ON io.orden_id   = o.id
JOIN dbo.productos p ON io.producto_id = p.id
WHERE o.estado <> 'cancelado'
GROUP BY p.categoria, p.subcategoria;
GO

-- Vista: Performance de vendedores
CREATE OR ALTER VIEW dbo.v_performance_vendedores AS
SELECT
    v.id,
    v.uuid,
    v.nombre,
    v.equipo,
    v.territorio,
    v.cuota_mensual,

    COUNT(DISTINCT o.id)                                                            AS total_ordenes,
    COUNT(DISTINCT o.cliente_id)                                                    AS clientes_unicos,

    SUM(o.monto_total)                                                              AS ventas_totales,
    AVG(o.monto_total)                                                              AS valor_promedio_orden,

    SUM(o.monto_total) - SUM(o.monto_total * v.tasa_comision / 100.0)              AS ventas_netas,
    SUM(o.monto_total * v.tasa_comision / 100.0)                                   AS monto_comision,

    COUNT(DISTINCT CAST(o.fecha_orden AS DATE))                                     AS dias_activos_venta,

    COUNT(CASE WHEN o.estado = 'entregado' THEN 1 END)                             AS ordenes_entregadas,
    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END)                             AS ordenes_canceladas,
    COUNT(CASE WHEN o.estado_pago = 'pendiente' THEN 1 END)                        AS ordenes_sin_pago,

    -- Ventas mes actual
    SUM(CASE
        WHEN DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1)
           = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)
        THEN o.monto_total ELSE 0
    END)                                                                            AS ventas_mes_actual,

    ROUND(
        100.0 * SUM(CASE
            WHEN DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1)
               = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)
            THEN o.monto_total ELSE 0
        END) / NULLIF(v.cuota_mensual, 0), 2
    )                                                                               AS porcentaje_cumplimiento_cuota,

    MAX(o.fecha_orden)                                                              AS fecha_ultima_venta,
    DATEDIFF(DAY, MAX(o.fecha_orden), GETDATE())                                    AS dias_desde_ultima_venta

FROM dbo.vendedores v
LEFT JOIN dbo.ordenes o ON v.id = o.vendedor_id AND o.estado <> 'cancelado'
WHERE v.activo = 1
GROUP BY v.id, v.uuid, v.nombre, v.equipo, v.territorio, v.cuota_mensual, v.tasa_comision;
GO

-- Vista: Segmentación de clientes
CREATE OR ALTER VIEW dbo.v_segmentacion_clientes AS
SELECT
    c.id,
    c.uuid,
    c.nombre,
    c.segmento,
    c.industria,
    c.tamaño_empresa,
    c.pais,

    COUNT(DISTINCT o.id)                                                        AS total_ordenes,
    SUM(o.monto_total)                                                          AS valor_vida,
    AVG(o.monto_total)                                                          AS valor_promedio_orden,
    MAX(o.fecha_orden)                                                          AS fecha_ultima_compra,
    DATEDIFF(DAY, MAX(o.fecha_orden), GETDATE())                                AS dias_desde_ultima_compra,

    DATEDIFF(DAY, MIN(o.fecha_orden), MAX(o.fecha_orden))                      AS dias_como_cliente,
    ROUND(
        CAST(COUNT(DISTINCT o.id) AS DECIMAL(15,2)) /
        NULLIF(DATEDIFF(DAY, MIN(o.fecha_orden), GETDATE()) / 30.0, 0), 2
    )                                                                           AS ordenes_por_mes,

    COUNT(DISTINCT DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1)) AS meses_activos,

    COUNT(CASE WHEN o.estado = 'cancelado' THEN 1 END)                         AS ordenes_canceladas,
    COUNT(CASE WHEN o.estado_pago <> 'pagado' THEN 1 END)                      AS ordenes_sin_pago,

    COUNT(DISTINCT ic.id)                                                       AS total_interacciones,
    MAX(ic.fecha_interaccion)                                                   AS fecha_ultima_interaccion

FROM dbo.clientes c
LEFT JOIN dbo.ordenes o                   ON c.id = o.cliente_id
LEFT JOIN dbo.interacciones_clientes ic   ON c.id = ic.cliente_id
WHERE c.activo = 1
GROUP BY c.id, c.uuid, c.nombre, c.segmento, c.industria, c.tamaño_empresa, c.pais;
GO

-- Vista: Análisis de devoluciones
CREATE OR ALTER VIEW dbo.v_analisis_devoluciones AS
SELECT
    CAST(d.fecha_devolucion AS DATE)                                AS fecha_devolucion,
    p.categoria,
    p.subcategoria,

    COUNT(DISTINCT d.id)                                            AS cantidad_devoluciones,
    SUM(d.monto_reembolso)                                          AS total_reembolsado,
    COUNT(DISTINCT d.orden_id)                                      AS ordenes_con_devolucion,

    COUNT(CASE WHEN d.estado = 'aprobado'  THEN 1 END)             AS devoluciones_aprobadas,
    COUNT(CASE WHEN d.estado = 'pendiente' THEN 1 END)             AS devoluciones_pendientes,
    COUNT(CASE WHEN d.estado = 'rechazado' THEN 1 END)             AS devoluciones_rechazadas,

    d.motivo

FROM dbo.devoluciones d
JOIN dbo.ordenes     o  ON d.orden_id    = o.id
LEFT JOIN dbo.items_orden io ON o.id     = io.orden_id
LEFT JOIN dbo.productos   p  ON io.producto_id = p.id
WHERE d.fecha_devolucion >= DATEADD(YEAR, -1, GETDATE())
GROUP BY CAST(d.fecha_devolucion AS DATE), p.categoria, p.subcategoria, d.motivo;
GO

-- Vista: Análisis de flujo de pagos
CREATE OR ALTER VIEW dbo.v_analisis_pagos AS
SELECT
    CAST(p.fecha_pago AS DATE)                                                              AS fecha_pago,
    p.metodo_pago,

    COUNT(DISTINCT p.id)                                                                    AS cantidad_pagos,
    COUNT(DISTINCT p.orden_id)                                                              AS ordenes_pagadas,
    SUM(p.monto)                                                                            AS total_cobrado,
    AVG(p.monto)                                                                            AS pago_promedio,

    COUNT(CASE WHEN p.estado = 'completado'  THEN 1 END)                                   AS pagos_exitosos,
    COUNT(CASE WHEN p.estado = 'fallido'     THEN 1 END)                                   AS pagos_fallidos,
    COUNT(CASE WHEN p.estado = 'reembolsado' THEN 1 END)                                   AS pagos_reembolsados,

    COUNT(DISTINCT CASE WHEN DATEADD(DAY, 30, o.fecha_orden) < p.fecha_pago THEN o.id END) AS pagos_atrasados_30d,
    COUNT(DISTINCT CASE WHEN DATEADD(DAY, 60, o.fecha_orden) < p.fecha_pago THEN o.id END) AS pagos_atrasados_60d

FROM dbo.pagos p
JOIN dbo.ordenes o ON p.orden_id = o.id
WHERE p.fecha_pago >= DATEADD(YEAR, -1, GETDATE())
GROUP BY CAST(p.fecha_pago AS DATE), p.metodo_pago;
GO

-- Vista: Performance de campañas
CREATE OR ALTER VIEW dbo.v_performance_campanas AS
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
    ROUND(100.0 * c.gasto_real / NULLIF(c.presupuesto, 0), 2)                      AS pct_presupuesto_usado,

    c.impresiones,
    c.clics,
    c.conversiones,
    c.ingresos_generados,

    ROUND(100.0 * CAST(c.clics AS DECIMAL)       / NULLIF(c.impresiones, 0), 2)    AS ctr_pct,
    ROUND(100.0 * CAST(c.conversiones AS DECIMAL) / NULLIF(c.clics, 0), 2)         AS tasa_conversion_pct,

    CASE WHEN c.gasto_real > 0
         THEN ROUND(c.ingresos_generados / c.gasto_real, 2)
         ELSE 0 END                                                                  AS roi,

    CASE WHEN c.conversiones > 0
         THEN ROUND(c.gasto_real / c.conversiones, 2)
         ELSE 0 END                                                                  AS costo_por_conversion,

    COUNT(DISTINCT cc.cliente_id)                                                    AS clientes_objetivo,
    COUNT(DISTINCT CASE WHEN cc.fecha_contacto IS NOT NULL THEN cc.cliente_id END)   AS clientes_contactados,
    COUNT(DISTINCT CASE WHEN cc.convirtio = 1             THEN cc.cliente_id END)    AS clientes_convertidos

FROM dbo.campanas c
LEFT JOIN dbo.campanas_clientes cc ON c.id = cc.campana_id
WHERE c.fecha_inicio >= DATEADD(YEAR, -2, GETDATE())
GROUP BY c.id, c.uuid, c.nombre, c.tipo_campana, c.canal, c.fecha_inicio, c.fecha_fin,
         c.presupuesto, c.gasto_real, c.impresiones, c.clics, c.conversiones, c.ingresos_generados;
GO

-- ============================================================================
-- TABLAS PARA CACHÉ (equivalente a MATERIALIZED VIEW en PostgreSQL)
-- SQL Server no soporta vistas materializadas generales; se usan tablas + SP de refresco.
-- Las vistas indexadas tienen restricciones muy estrictas y no admiten JOINs complejos.
-- ============================================================================

IF OBJECT_ID('dbo.mv_tendencia_ventas_mensual', 'U') IS NULL
CREATE TABLE dbo.mv_tendencia_ventas_mensual (
    mes                  DATE NOT NULL PRIMARY KEY,
    anio                 INT NOT NULL,
    numero_mes           INT NOT NULL,
    ordenes              INT NOT NULL,
    clientes             INT NOT NULL,
    ingresos             DECIMAL(15,2) NOT NULL,
    valor_promedio_orden DECIMAL(15,2) NOT NULL,
    ingresos_entregados  DECIMAL(15,2) NOT NULL,
    ingresos_cancelados  DECIMAL(15,2) NOT NULL,
    ganancia_bruta       DECIMAL(15,2) NOT NULL,
    actualizado_en       DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

IF OBJECT_ID('dbo.mv_top_productos_por_categoria', 'U') IS NULL
CREATE TABLE dbo.mv_top_productos_por_categoria (
    categoria              NVARCHAR(100) NOT NULL,
    id                     BIGINT NOT NULL,
    uuid                   UNIQUEIDENTIFIER NOT NULL,
    nombre                 NVARCHAR(255) NOT NULL,
    sku                    NVARCHAR(50) NOT NULL,
    veces_pedido           INT NOT NULL,
    cantidad_total_vendida INT NOT NULL,
    ingresos_totales       DECIMAL(15,2) NOT NULL,
    ranking_categoria      INT NOT NULL,
    actualizado_en         DATETIME2 NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (categoria, id)
);
GO

-- ============================================================================
-- FUNCIONES ANALÍTICAS
-- ============================================================================

-- Función tabla: Calcular ARR (Ingreso Anual Recurrente) por segmento
CREATE OR ALTER FUNCTION dbo.fn_calcular_arr (
    @meses_periodo INT = 12
)
RETURNS TABLE AS RETURN
(
    SELECT
        segmento,
        ROUND(AVG(ventas_mensuales), 2)        AS ingreso_mensual,
        ROUND(AVG(ventas_mensuales) * 12, 2)   AS ingreso_anual
    FROM (
        SELECT
            c.segmento,
            DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1) AS mes,
            SUM(o.monto_total)                                           AS ventas_mensuales
        FROM dbo.ordenes o
        JOIN dbo.clientes c ON o.cliente_id = c.id
        WHERE o.fecha_orden >= DATEADD(MONTH, -@meses_periodo, GETDATE())
          AND o.estado <> 'cancelado'
        GROUP BY c.segmento,
                 DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1)
    ) t
    GROUP BY segmento
);
GO

-- Función tabla: Calcular churn de clientes por segmento
CREATE OR ALTER FUNCTION dbo.fn_calcular_churn (
    @dias_periodo INT = 90
)
RETURNS TABLE AS RETURN
(
    WITH clientes_periodo AS (
        SELECT DISTINCT c.id, c.segmento
        FROM dbo.clientes c
        JOIN dbo.ordenes o ON c.id = o.cliente_id
        WHERE o.fecha_orden >= DATEADD(DAY, -@dias_periodo, GETDATE())
          AND o.estado <> 'cancelado'
    ),
    clientes_activos_recientes AS (
        SELECT DISTINCT c.id
        FROM dbo.clientes c
        JOIN dbo.ordenes o ON c.id = o.cliente_id
        WHERE o.fecha_orden >= DATEADD(DAY, -30, GETDATE())
          AND o.estado <> 'cancelado'
    ),
    clientes_perdidos AS (
        SELECT cp.id, cp.segmento
        FROM clientes_periodo cp
        WHERE cp.id NOT IN (SELECT id FROM clientes_activos_recientes)
    )
    SELECT
        cp.segmento,
        COUNT(DISTINCT cp.id)     AS total_clientes_inicio_periodo,
        COUNT(DISTINCT cper.id)   AS clientes_perdidos,
        ROUND(
            100.0 * COUNT(DISTINCT cper.id) / NULLIF(COUNT(DISTINCT cp.id), 0), 2
        )                         AS tasa_churn_pct
    FROM clientes_periodo cp
    LEFT JOIN clientes_perdidos cper ON cp.id = cper.id
    GROUP BY cp.segmento
);
GO

-- Función tabla: Pronóstico de ventas (regresión lineal manual)
-- SQL Server no tiene REGR_SLOPE/REGR_INTERCEPT; se calcula con fórmulas estadísticas
CREATE OR ALTER FUNCTION dbo.fn_pronostico_ventas (
    @meses_pronostico INT = 3,
    @meses_historico  INT = 12
)
RETURNS TABLE AS RETURN
(
    WITH datos_historicos AS (
        SELECT
            DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1) AS mes,
            SUM(o.monto_total)                                           AS ingresos,
            ROW_NUMBER() OVER (
                ORDER BY DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1)
            )                                                            AS seq_mes
        FROM dbo.ordenes o
        WHERE o.fecha_orden >= DATEADD(MONTH, -@meses_historico, GETDATE())
          AND o.estado <> 'cancelado'
        GROUP BY DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1)
    ),
    -- Regresión lineal: pendiente = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
    estadisticas AS (
        SELECT
            COUNT(*)                                               AS n,
            SUM(CAST(seq_mes AS DECIMAL(15,4)))                   AS sum_x,
            SUM(ingresos)                                         AS sum_y,
            SUM(CAST(seq_mes AS DECIMAL(15,4)) * ingresos)        AS sum_xy,
            SUM(CAST(seq_mes AS DECIMAL(15,4)) * CAST(seq_mes AS DECIMAL(15,4))) AS sum_x2,
            MAX(seq_mes)                                          AS ultimo_seq,
            MAX(mes)                                              AS ultimo_mes
        FROM datos_historicos
    ),
    tendencia AS (
        SELECT
            ultimo_seq,
            ultimo_mes,
            CASE
                WHEN (n * sum_x2 - sum_x * sum_x) = 0 THEN 0
                ELSE (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
            END AS pendiente,
            CASE
                WHEN (n * sum_x2 - sum_x * sum_x) = 0 THEN sum_y / NULLIF(n, 0)
                ELSE (sum_y - ((n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)) * sum_x) / NULLIF(n, 0)
            END AS intercepto
        FROM estadisticas
    ),
    numeros AS (
        SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3
        UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
    )
    SELECT
        CAST(DATEADD(MONTH, nums.n, t.ultimo_mes) AS DATE)              AS mes_pronostico,
        ROUND(
            CASE WHEN t.intercepto + t.pendiente * (t.ultimo_seq + nums.n) < 0
                 THEN 0
                 ELSE t.intercepto + t.pendiente * (t.ultimo_seq + nums.n)
            END, 2
        )                                                                AS ingreso_pronosticado
    FROM tendencia t
    CROSS JOIN numeros nums
    WHERE nums.n <= @meses_pronostico
      AND t.pendiente IS NOT NULL
);
GO

-- Función tabla: Análisis de cohortes
CREATE OR ALTER FUNCTION dbo.fn_analisis_cohortes (
    @metrica NVARCHAR(20) = 'ingresos'   -- 'ingresos', 'ordenes', 'retencion'
)
RETURNS TABLE AS RETURN
(
    WITH cohortes_clientes AS (
        SELECT
            c.id,
            DATEFROMPARTS(YEAR(MIN(o.fecha_orden)), MONTH(MIN(o.fecha_orden)), 1)  AS mes_cohorte,
            DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1)            AS mes_orden
        FROM dbo.clientes c
        JOIN dbo.ordenes o ON c.id = o.cliente_id
        WHERE o.estado <> 'cancelado'
        GROUP BY c.id, DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1)
    ),
    cohortes_con_metricas AS (
        SELECT
            cc.mes_cohorte,
            DATEDIFF(MONTH, cc.mes_cohorte, cc.mes_orden)   AS meses_transcurridos,
            CASE @metrica
                WHEN 'ingresos'   THEN SUM(o.monto_total)
                WHEN 'ordenes'    THEN CAST(COUNT(DISTINCT o.id) AS DECIMAL(15,2))
                ELSE CAST(COUNT(DISTINCT cc.id) AS DECIMAL(15,2))
            END                                             AS metrica,
            COUNT(DISTINCT cc.id)                           AS clientes
        FROM cohortes_clientes cc
        JOIN dbo.ordenes o
            ON cc.id = o.cliente_id
            AND DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1) = cc.mes_orden
        WHERE o.estado <> 'cancelado'
        GROUP BY cc.mes_cohorte, DATEDIFF(MONTH, cc.mes_cohorte, cc.mes_orden)
    )
    SELECT
        mes_cohorte,
        meses_transcurridos,
        ROUND(metrica, 2)   AS valor_metrica,
        clientes            AS cantidad_clientes
    FROM cohortes_con_metricas
    WHERE meses_transcurridos >= 0
);
GO

-- ============================================================================
-- PROCEDIMIENTO: Refrescar tablas de caché (equivalente a REFRESH MATERIALIZED VIEW)
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_refrescar_vistas_materializadas
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @inicio DATETIME2, @fin DATETIME2;

    -- ----- mv_tendencia_ventas_mensual -----
    SET @inicio = GETDATE();

    TRUNCATE TABLE dbo.mv_tendencia_ventas_mensual;

    INSERT INTO dbo.mv_tendencia_ventas_mensual
        (mes, anio, numero_mes, ordenes, clientes, ingresos,
         valor_promedio_orden, ingresos_entregados, ingresos_cancelados, ganancia_bruta)
    SELECT
        DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1)  AS mes,
        YEAR(o.fecha_orden)                                           AS anio,
        MONTH(o.fecha_orden)                                          AS numero_mes,
        COUNT(DISTINCT o.id)                                          AS ordenes,
        COUNT(DISTINCT o.cliente_id)                                  AS clientes,
        SUM(o.monto_total)                                            AS ingresos,
        AVG(o.monto_total)                                            AS valor_promedio_orden,
        SUM(CASE WHEN o.estado = 'entregado' THEN o.monto_total ELSE 0 END) AS ingresos_entregados,
        SUM(CASE WHEN o.estado = 'cancelado' THEN o.monto_total ELSE 0 END) AS ingresos_cancelados,
        SUM(o.monto_total) - SUM(COALESCE(CAST(io.cantidad AS DECIMAL(15,2)) * p.precio_costo, 0)) AS ganancia_bruta
    FROM dbo.ordenes o
    LEFT JOIN dbo.items_orden io ON o.id = io.orden_id
    LEFT JOIN dbo.productos   p  ON io.producto_id = p.id
    WHERE o.estado <> 'cancelado'
    GROUP BY DATEFROMPARTS(YEAR(o.fecha_orden), MONTH(o.fecha_orden), 1),
             YEAR(o.fecha_orden), MONTH(o.fecha_orden);

    SET @fin = GETDATE();
    PRINT 'mv_tendencia_ventas_mensual: completado en ' + CAST(DATEDIFF(MILLISECOND, @inicio, @fin) AS NVARCHAR) + ' ms';

    -- ----- mv_top_productos_por_categoria -----
    SET @inicio = GETDATE();

    TRUNCATE TABLE dbo.mv_top_productos_por_categoria;

    INSERT INTO dbo.mv_top_productos_por_categoria
        (categoria, id, uuid, nombre, sku, veces_pedido, cantidad_total_vendida, ingresos_totales, ranking_categoria)
    SELECT
        p.categoria,
        p.id,
        p.uuid,
        p.nombre,
        p.sku,
        COUNT(DISTINCT io.orden_id)                                                 AS veces_pedido,
        COALESCE(SUM(io.cantidad), 0)                                               AS cantidad_total_vendida,
        COALESCE(SUM(io.total_linea), 0)                                            AS ingresos_totales,
        ROW_NUMBER() OVER (PARTITION BY p.categoria ORDER BY SUM(io.total_linea) DESC) AS ranking_categoria
    FROM dbo.productos p
    LEFT JOIN dbo.items_orden io ON p.id = io.producto_id
    LEFT JOIN dbo.ordenes     o  ON io.orden_id = o.id AND o.estado <> 'cancelado'
    WHERE p.activo = 1
    GROUP BY p.categoria, p.id, p.uuid, p.nombre, p.sku;

    SET @fin = GETDATE();
    PRINT 'mv_top_productos_por_categoria: completado en ' + CAST(DATEDIFF(MILLISECOND, @inicio, @fin) AS NVARCHAR) + ' ms';

END;
GO

-- ============================================================================
-- FIN DE VISTAS Y FUNCIONES ANALÍTICAS
-- ============================================================================
