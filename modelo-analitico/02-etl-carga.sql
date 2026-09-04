-- ============================================================================
-- ETL: CARGA DEL MODELO ANALÍTICO DESDE EL OLTP (ventas_test)
-- SQL Server 2016+
-- ============================================================================
-- Ejecutar conectado a "ventas_bi". Lee la base "ventas_test" (t-sql/) por
-- nombre de tres partes — ambas bases deben estar en la misma instancia.
-- Reejecutable: cada bloque limpia y vuelve a cargar (Tipo 1 SCD, ver
-- DOCUMENTACION-MODELO.md).
-- ============================================================================

USE ventas_bi;
GO

IF DB_ID('ventas_test') IS NULL
BEGIN
    RAISERROR('La base ventas_test no existe. Ejecutar primero t-sql/01-03 y generar datos.', 16, 1);
    RETURN;
END
GO

-- ============================================================================
-- LIMPIAR HECHOS PRIMERO
-- Las dimensiones no se pueden TRUNCATE mientras existan filas de hechos que
-- las referencien por FK (TRUNCATE lo exige aunque la tabla esté vacía en la
-- práctica). Por eso los 3 hechos se vacían acá, antes de tocar ninguna
-- dimensión, y se vuelven a poblar al final del script.
-- ============================================================================
TRUNCATE TABLE dbo.fact_ventas;
TRUNCATE TABLE dbo.fact_pagos;
TRUNCATE TABLE dbo.fact_devoluciones;
GO

-- ============================================================================
-- DIM_FECHA — cubre desde la orden más antigua hasta 30 días después de la
-- más reciente (para no perder fechas de pago/entrega que caen después).
-- ============================================================================
DELETE FROM dbo.dim_fecha;

DECLARE @fecha_inicio DATE, @fecha_fin DATE;
SELECT
    @fecha_inicio = DATEADD(DAY, -7, CAST(MIN(fecha_orden) AS DATE)),
    @fecha_fin    = DATEADD(DAY, 30, CAST(MAX(fecha_orden) AS DATE))
FROM ventas_test.dbo.orden_encabezado;

;WITH fechas AS (
    SELECT @fecha_inicio AS fecha
    UNION ALL
    SELECT DATEADD(DAY, 1, fecha) FROM fechas WHERE fecha < @fecha_fin
)
INSERT INTO dbo.dim_fecha (
    fecha_key, fecha, anio, trimestre, nombre_trimestre, mes, nombre_mes,
    mes_anio, dia, dia_semana, nombre_dia, semana_anio, es_fin_semana
)
SELECT
    CAST(FORMAT(fecha, 'yyyyMMdd') AS INT),
    fecha,
    YEAR(fecha),
    DATEPART(QUARTER, fecha),
    'Q' + CAST(DATEPART(QUARTER, fecha) AS VARCHAR(1)),
    MONTH(fecha),
    DATENAME(MONTH, fecha),
    FORMAT(fecha, 'yyyy-MM'),
    DAY(fecha),
    DATEPART(WEEKDAY, fecha),
    DATENAME(WEEKDAY, fecha),
    DATEPART(ISO_WEEK, fecha),
    CASE WHEN DATEPART(WEEKDAY, fecha) IN (1, 7) THEN 1 ELSE 0 END
FROM fechas
OPTION (MAXRECURSION 0);
GO

-- ============================================================================
-- DIM_CLIENTE  (+ miembro "Desconocido" en cliente_key = -1)
-- ============================================================================
DELETE FROM dbo.dim_cliente;
DBCC CHECKIDENT ('dbo.dim_cliente', RESEED, 0);
SET IDENTITY_INSERT dbo.dim_cliente ON;

INSERT INTO dbo.dim_cliente (
    cliente_key, cliente_id, nombre, email, segmento, industria, tamano_empresa,
    pais, provincia, ciudad, fecha_adquisicion, activo
)
VALUES (-1, NULL, 'Desconocido', NULL, 'desconocido', NULL, NULL, NULL, NULL, NULL, NULL, 1);

SET IDENTITY_INSERT dbo.dim_cliente OFF;

INSERT INTO dbo.dim_cliente (
    cliente_id, nombre, email, segmento, industria, tamano_empresa,
    pais, provincia, ciudad, fecha_adquisicion, activo
)
SELECT
    id, nombre, email, segmento, industria, tamaño_empresa,
    pais, provincia, ciudad, fecha_adquisicion, activo
FROM ventas_test.dbo.clientes;
GO

-- ============================================================================
-- DIM_PRODUCTO  (+ miembro "Desconocido" en producto_key = -1)
-- ============================================================================
DELETE FROM dbo.dim_producto;
DBCC CHECKIDENT ('dbo.dim_producto', RESEED, 0);
SET IDENTITY_INSERT dbo.dim_producto ON;

INSERT INTO dbo.dim_producto (
    producto_key, producto_id, nombre, sku, categoria, subcategoria, marca,
    precio_lista_actual, es_digital, activo
)
VALUES (-1, NULL, 'Desconocido', NULL, 'desconocido', NULL, NULL, NULL, 0, 1);

SET IDENTITY_INSERT dbo.dim_producto OFF;

INSERT INTO dbo.dim_producto (
    producto_id, nombre, sku, categoria, subcategoria, marca,
    precio_lista_actual, es_digital, activo
)
SELECT
    id, nombre, sku, categoria, subcategoria, marca,
    precio_lista, es_digital, activo
FROM ventas_test.dbo.productos;
GO

-- ============================================================================
-- DIM_VENDEDOR  (+ miembro "Desconocido" en vendedor_key = -1)
-- ============================================================================
DELETE FROM dbo.dim_vendedor;
DBCC CHECKIDENT ('dbo.dim_vendedor', RESEED, 0);
SET IDENTITY_INSERT dbo.dim_vendedor ON;

INSERT INTO dbo.dim_vendedor (
    vendedor_key, vendedor_id, nombre, equipo, territorio, gerente_nombre, activo
)
VALUES (-1, NULL, 'Sin vendedor asignado', NULL, NULL, NULL, 1);

SET IDENTITY_INSERT dbo.dim_vendedor OFF;

INSERT INTO dbo.dim_vendedor (
    vendedor_id, nombre, equipo, territorio, gerente_nombre, activo
)
SELECT
    v.id, v.nombre, v.equipo, v.territorio, g.nombre, v.activo
FROM ventas_test.dbo.vendedores v
LEFT JOIN ventas_test.dbo.vendedores g ON v.gerente_id = g.id;
GO

-- ============================================================================
-- DIM_ESTADO_ORDEN  (combinaciones realmente presentes en el OLTP)
-- ============================================================================
DELETE FROM dbo.dim_estado_orden;
DBCC CHECKIDENT ('dbo.dim_estado_orden', RESEED, 0);

INSERT INTO dbo.dim_estado_orden (estado, estado_pago, es_cancelada, es_completada, es_pago_al_dia)
SELECT DISTINCT
    estado, estado_pago,
    CASE WHEN estado = 'cancelado' THEN 1 ELSE 0 END,
    CASE WHEN estado = 'entregado' THEN 1 ELSE 0 END,
    CASE WHEN estado_pago = 'pagado' THEN 1 ELSE 0 END
FROM ventas_test.dbo.orden_encabezado;
GO

-- ============================================================================
-- DIM_METODO_PAGO  (+ miembro "Desconocido" en metodo_pago_key = -1)
-- ============================================================================
DELETE FROM dbo.dim_metodo_pago;
DBCC CHECKIDENT ('dbo.dim_metodo_pago', RESEED, 0);
SET IDENTITY_INSERT dbo.dim_metodo_pago ON;

INSERT INTO dbo.dim_metodo_pago (metodo_pago_key, metodo_pago, descripcion)
VALUES (-1, 'desconocido', 'Método de pago no informado');

SET IDENTITY_INSERT dbo.dim_metodo_pago OFF;

INSERT INTO dbo.dim_metodo_pago (metodo_pago, descripcion)
SELECT DISTINCT metodo_pago, metodo_pago
FROM ventas_test.dbo.orden_encabezado
WHERE metodo_pago IS NOT NULL;
GO

-- ============================================================================
-- FACT_VENTAS  (grano: línea de orden)
-- ============================================================================
INSERT INTO dbo.fact_ventas (
    fecha_key, cliente_key, producto_key, vendedor_key, estado_orden_key, metodo_pago_key,
    orden_id, orden_detalle_id,
    cantidad, precio_unitario, porcentaje_descuento,
    monto_bruto_linea, monto_descuento_linea, total_linea,
    costo_linea, margen_bruto_linea, cantidad_devuelta
)
SELECT
    df.fecha_key,
    ISNULL(dc.cliente_key, -1),
    ISNULL(dp.producto_key, -1),
    ISNULL(dv.vendedor_key, -1),
    de.estado_orden_key,
    ISNULL(dm.metodo_pago_key, -1),
    od.orden_id,
    od.id,
    od.cantidad,
    od.precio_unitario,
    od.porcentaje_descuento,
    od.cantidad * od.precio_unitario AS monto_bruto_linea,
    (od.cantidad * od.precio_unitario) - od.total_linea AS monto_descuento_linea,
    od.total_linea,
    od.cantidad * p.precio_costo AS costo_linea,
    od.total_linea - (od.cantidad * p.precio_costo) AS margen_bruto_linea,
    od.cantidad_devuelta
FROM ventas_test.dbo.orden_detalles od
JOIN ventas_test.dbo.orden_encabezado o ON od.orden_id = o.id
JOIN ventas_test.dbo.productos p ON od.producto_id = p.id
JOIN dbo.dim_fecha df ON df.fecha = CAST(o.fecha_orden AS DATE)
JOIN dbo.dim_estado_orden de ON de.estado = o.estado AND de.estado_pago = o.estado_pago
LEFT JOIN dbo.dim_cliente dc  ON dc.cliente_id = o.cliente_id
LEFT JOIN dbo.dim_producto dp ON dp.producto_id = od.producto_id
LEFT JOIN dbo.dim_vendedor dv ON dv.vendedor_id = o.vendedor_id
LEFT JOIN dbo.dim_metodo_pago dm ON dm.metodo_pago = o.metodo_pago;
GO

-- ============================================================================
-- FACT_PAGOS  (grano: un pago)
-- ============================================================================
INSERT INTO dbo.fact_pagos (
    fecha_key, cliente_key, metodo_pago_key, orden_id, pago_id, monto_pago, es_completado
)
SELECT
    df.fecha_key,
    ISNULL(dc.cliente_key, -1),
    ISNULL(dm.metodo_pago_key, -1),
    pg.orden_id,
    pg.id,
    pg.monto,
    CASE WHEN pg.estado = 'completado' THEN 1 ELSE 0 END
FROM ventas_test.dbo.pagos pg
JOIN ventas_test.dbo.orden_encabezado o ON pg.orden_id = o.id
JOIN dbo.dim_fecha df ON df.fecha = CAST(pg.fecha_pago AS DATE)
LEFT JOIN dbo.dim_cliente dc ON dc.cliente_id = o.cliente_id
LEFT JOIN dbo.dim_metodo_pago dm ON dm.metodo_pago = pg.metodo_pago;
GO

-- ============================================================================
-- FACT_DEVOLUCIONES  (grano: una devolución)
-- ============================================================================
INSERT INTO dbo.fact_devoluciones (
    fecha_key, cliente_key, orden_id, devolucion_id, motivo, estado_devolucion, monto_reembolso
)
SELECT
    df.fecha_key,
    ISNULL(dc.cliente_key, -1),
    dv.orden_id,
    dv.id,
    dv.motivo,
    dv.estado,
    dv.monto_reembolso
FROM ventas_test.dbo.devoluciones dv
JOIN ventas_test.dbo.orden_encabezado o ON dv.orden_id = o.id
JOIN dbo.dim_fecha df ON df.fecha = CAST(dv.fecha_devolucion AS DATE)
LEFT JOIN dbo.dim_cliente dc ON dc.cliente_id = o.cliente_id;
GO

-- ============================================================================
-- RESUMEN DE CARGA
-- ============================================================================
SELECT 'dim_fecha' AS tabla, COUNT(*) AS filas FROM dbo.dim_fecha
UNION ALL SELECT 'dim_cliente', COUNT(*) FROM dbo.dim_cliente
UNION ALL SELECT 'dim_producto', COUNT(*) FROM dbo.dim_producto
UNION ALL SELECT 'dim_vendedor', COUNT(*) FROM dbo.dim_vendedor
UNION ALL SELECT 'dim_estado_orden', COUNT(*) FROM dbo.dim_estado_orden
UNION ALL SELECT 'dim_metodo_pago', COUNT(*) FROM dbo.dim_metodo_pago
UNION ALL SELECT 'fact_ventas', COUNT(*) FROM dbo.fact_ventas
UNION ALL SELECT 'fact_pagos', COUNT(*) FROM dbo.fact_pagos
UNION ALL SELECT 'fact_devoluciones', COUNT(*) FROM dbo.fact_devoluciones;

-- ============================================================================
-- EXTENSIÓN A SCD TIPO 2 (no implementada; queda documentada)
-- ============================================================================
-- Si se necesitara conservar historia de cambios en dim_cliente (p.ej. saber
-- el segmento del cliente AL MOMENTO de cada venta, no el actual), la
-- extensión estándar de Kimball es:
--   1. Agregar a dim_cliente: valido_desde DATETIME2, valido_hasta DATETIME2,
--      es_actual BIT.
--   2. En vez de TRUNCATE + INSERT, comparar cada fila del OLTP contra la
--      versión "es_actual = 1" existente; si cambió un atributo rastreado
--      (p.ej. segmento), cerrar la fila vieja (valido_hasta = GETDATE(),
--      es_actual = 0) e insertar una fila nueva con una nueva cliente_key.
--   3. En el ETL de fact_ventas, el JOIN a dim_cliente ya no sería por
--      cliente_id solamente, sino por cliente_id + fecha_orden BETWEEN
--      valido_desde AND valido_hasta.
-- No se implementa acá porque el generador de datos de prueba no guarda
-- historia de cambios en el OLTP: no hay nada real que versionar todavía.
-- ============================================================================
