-- ============================================================================
-- PROCEDIMIENTOS DE GENERACIÓN DE DATOS REALISTAS
-- SQL Server 2016+
-- ============================================================================
-- NOTA: SQL Server no tiene arrays ni LOOP/WHILE sobre arrays como PL/pgSQL.
-- Se usan tablas temporales de valores y CROSS APPLY / NEWID() para aleatoriedad.
-- ============================================================================

-- ============================================================================
-- TABLA DE APOYO: Números del 1 al 10000 (reutilizable)
-- Se usa en lugar de GENERATE_SERIES que no existe en SQL Server < 2022
-- ============================================================================
IF OBJECT_ID('dbo.numeros', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.numeros (n INT PRIMARY KEY);

    WITH cte AS (
        SELECT 1 AS n
        UNION ALL
        SELECT n + 1 FROM cte WHERE n < 10000
    )
    INSERT INTO dbo.numeros SELECT n FROM cte OPTION (MAXRECURSION 10000);
END;
GO

-- ============================================================================
-- FUNCIÓN AUXILIAR: Obtener nombre aleatorio por indices
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_nombre_por_indices
(
    @genero CHAR(1),
    @i_nombre INT,
    @i_apellido INT
)
RETURNS TABLE
AS
RETURN
(
    WITH nombres_m AS (
        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS id, v
        FROM (VALUES 
            ('Carlos'),('Miguel'),('Juan'),('Luis'),('Pedro'),
            ('Jorge'),('Andrés'),('Fernando'),('Diego'),('Sergio')
        ) t(v)
    ),
    nombres_f AS (
        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS id, v
        FROM (VALUES 
            ('María'),('Ana'),('Lucía'),('Sofía'),('Valentina'),
            ('Camila'),('Daniela'),('Paula'),('Carla'),('Laura')
        ) t(v)
    ),
    apellidos AS (
        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS id, v
        FROM (VALUES 
            ('García'),('Martínez'),('Rodríguez'),('López'),('Pérez'),
            ('Gómez'),('Fernández'),('Díaz'),('Sánchez'),('Romero')
        ) t(v)
    )
    SELECT
        nombre = n.v,
        apellido = a.v,
        nombre_completo = n.v + ' ' + a.v
    FROM
        (
            SELECT id, v FROM nombres_m WHERE @genero = 'M'
            UNION ALL
            SELECT id, v FROM nombres_f WHERE @genero = 'F'
        ) n
    JOIN apellidos a 
        ON a.id = @i_apellido
    WHERE n.id = @i_nombre
);
GO

-- ============================================================================
-- FUNCIÓN AUXILIAR: Obtener nombre aleatorio
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_nombre_aleatorio(@genero CHAR(1) = 'M')
RETURNS NVARCHAR(255) AS
BEGIN
    DECLARE @nombres_m TABLE (n INT IDENTITY(1,1), v NVARCHAR(50));
    INSERT INTO @nombres_m (v) VALUES
        ('Carlos'),('Miguel'),('Juan'),('Luis'),('Pedro'),
        ('Roberto'),('Antonio'),('Diego'),('Francisco'),('Alejandro'),
        ('Javier'),('Andrés'),('Sergio'),('Ricardo'),('Fernando');

    DECLARE @nombres_f TABLE (n INT IDENTITY(1,1), v NVARCHAR(50));
    INSERT INTO @nombres_f (v) VALUES
        ('María'),('Carmen'),('Rosa'),('Isabel'),('Josefina'),
        ('Ana'),('Francisca'),('Dolores'),('Catalina'),('Antonia'),
        ('Montserrat'),('Pilar'),('Sofía'),('Teresa'),('Laura');

    DECLARE @apellidos TABLE (n INT IDENTITY(1,1), v NVARCHAR(50));
    INSERT INTO @apellidos (v) VALUES
        ('García'),('Martínez'),('Rodríguez'),('López'),('Hernández'),
        ('González'),('Pérez'),('Sánchez'),('Ramírez'),('Torres'),
        ('Flores'),('Rivera'),('Gómez'),('Díaz'),('Reyes');

    DECLARE @nombre NVARCHAR(50), @apellido NVARCHAR(50);

    IF @genero = 'F'
        SELECT @nombre   = v FROM @nombres_f WHERE n = (ABS(CHECKSUM(NEWID())) % 15) + 1;
    ELSE
        SELECT @nombre   = v FROM @nombres_m WHERE n = (ABS(CHECKSUM(NEWID())) % 15) + 1;

    SELECT @apellido = v FROM @apellidos WHERE n = (ABS(CHECKSUM(NEWID())) % 15) + 1;

    RETURN @nombre + N' ' + @apellido;
END;
GO

-- ============================================================================
-- PROCEDIMIENTO: Generar clientes
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_generar_clientes
    @cantidad INT = 500,
    @limpiar  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @limpiar = 1
    BEGIN
        DELETE FROM dbo.clientes;
        PRINT 'Tabla clientes limpiada';
    END;

    DECLARE
        @segmentos  TABLE (n INT IDENTITY(1,1), v NVARCHAR(50));
    INSERT INTO @segmentos (v) VALUES ('premium'),('estandar'),('prueba'),('vip'),('inactivo');

    DECLARE
        @industrias TABLE (n INT IDENTITY(1,1), v NVARCHAR(100));
    INSERT INTO @industrias (v) VALUES
        ('Tecnología'),('Finanzas'),('Salud'),('Comercio'),
        ('Manufactura'),('Educación'),('Consultoría'),('Energía');

    DECLARE
        @tamaños TABLE (n INT IDENTITY(1,1), v NVARCHAR(50));
    INSERT INTO @tamaños (v) VALUES ('startup'),('pequeña'),('mediana'),('grande'),('corporacion');

    DECLARE
        @paises TABLE (n INT IDENTITY(1,1), v NVARCHAR(100));
    INSERT INTO @paises (v) VALUES ('Argentina'),('Chile'),('Uruguay'),('Colombia'),('México');

    DECLARE
        @provincias TABLE (n INT IDENTITY(1,1), v NVARCHAR(100));
    INSERT INTO @provincias (v) VALUES
        ('Buenos Aires'),('Córdoba'),('Santa Fe'),('Mendoza'),('Tucumán'),('Rosario');

    DECLARE
        @ciudades TABLE (n INT IDENTITY(1,1), v NVARCHAR(100));
    INSERT INTO @ciudades (v) VALUES
        ('Buenos Aires'),('Córdoba'),('Rosario'),('Mendoza'),('Tucumán'),
        ('Mar del Plata'),('Salta'),('Santa Fe'),('San Juan'),('Resistencia');

    -- Insertar usando tabla de números para evitar cursor
    INSERT INTO dbo.clientes
        (nombre, email, telefono, segmento, industria, tamaño_empresa,
         pais, provincia, ciudad, codigo_postal,
         limite_credito, fecha_adquisicion, activo)
    SELECT TOP (@cantidad)
        dbo.fn_nombre_aleatorio(CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 'M' ELSE 'F' END) AS nombre,
        LOWER(REPLACE(
            dbo.fn_nombre_aleatorio(CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 'M' ELSE 'F' END),
            ' ', '.'
        )) + '@' +
        CASE ABS(CHECKSUM(NEWID())) % 5
            WHEN 0 THEN 'gmail.com' WHEN 1 THEN 'yahoo.com'
            WHEN 2 THEN 'outlook.com' WHEN 3 THEN 'empresa.com' ELSE 'mail.com'
        END                                                                                        AS email,
        '+54 ' + CASE ABS(CHECKSUM(NEWID())) % 3
            WHEN 0 THEN '11' WHEN 1 THEN '351' ELSE '261'
        END + ' ' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 99999999 AS NVARCHAR), 8)  AS telefono,
        s.v                                                                                     AS segmento,
        i.v                                                                                     AS industria,
        t.v                                                                                     AS tamaño_empresa,
        pa.v                                                                                    AS pais,
        pr.v                                                                                    AS provincia,
        ci.v                                                                                    AS ciudad,
        RIGHT('0000' + CAST(ABS(CHECKSUM(NEWID())) % 9999 AS NVARCHAR), 4)                      AS codigo_postal,
        CAST(10000 + ABS(CHECKSUM(NEWID())) % 990000 AS DECIMAL(10,2))                          AS limite_credito,
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 365), GETDATE())                                AS fecha_adquisicion,
        CASE WHEN s.v = 'inactivo' THEN 0 ELSE 1 END                                            AS activo
    FROM dbo.numeros num
    CROSS APPLY (SELECT TOP 1 v FROM @segmentos  ORDER BY NEWID()) s
    CROSS APPLY (SELECT TOP 1 v FROM @industrias ORDER BY NEWID()) i
    CROSS APPLY (SELECT TOP 1 v FROM @tamaños    ORDER BY NEWID()) t
    CROSS APPLY (SELECT TOP 1 v FROM @paises     ORDER BY NEWID()) pa
    CROSS APPLY (SELECT TOP 1 v FROM @provincias ORDER BY NEWID()) pr
    CROSS APPLY (SELECT TOP 1 v FROM @ciudades   ORDER BY NEWID()) ci
    WHERE num.n <= @cantidad;

    DECLARE @total INT = (SELECT COUNT(*) FROM dbo.clientes);
    PRINT 'Clientes generados: ' + CAST(@total AS NVARCHAR);

    SELECT @total AS registros_creados, 'completado' AS estado;
END;
GO

-- ============================================================================
-- PROCEDIMIENTO: Generar productos
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_generar_productos
    @cantidad INT = 200,
    @limpiar  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @limpiar = 1
    BEGIN
        DELETE FROM dbo.productos;
        PRINT 'Tabla productos limpiada';
    END;

    DECLARE @categorias TABLE (n INT IDENTITY(1,1), v NVARCHAR(100));
    INSERT INTO @categorias (v) VALUES
        ('Electrónica'),('Software'),('Servicios'),('Hardware'),('Consultoría');

    DECLARE @marcas TABLE (n INT IDENTITY(1,1), v NVARCHAR(100));
    INSERT INTO @marcas (v) VALUES
        ('TechCorp'),('InnovaTech'),('SoftPro'),('CloudSys'),('DataFlow'),('SecureIT');

    INSERT INTO dbo.productos
        (nombre, sku, descripcion, categoria, subcategoria, marca,
         precio_lista, precio_costo, stock_actual, stock_minimo,
         peso_kg, volumen_m3, es_digital, fecha_lanzamiento, activo)
    SELECT TOP (@cantidad)
        m.v + N' ' + sc.subcategoria + N' ' + CAST(num.n AS NVARCHAR)              AS nombre,
        'SKU-' + RIGHT('000000' + CAST(num.n AS NVARCHAR), 6)                       AS sku,
        N'Producto de alta calidad: ' + sc.subcategoria + N' de ' + m.v            AS descripcion,
        c.v                                                                         AS categoria,
        sc.subcategoria                                                             AS subcategoria,
        m.v                                                                         AS marca,
        CAST(100 + ABS(CHECKSUM(NEWID())) % 9900 AS DECIMAL(10,2))                 AS precio_lista,
        CAST(50  + ABS(CHECKSUM(NEWID())) % 4950 AS DECIMAL(10,2))                 AS precio_costo,
        ABS(CHECKSUM(NEWID())) % 1000                                               AS stock_actual,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 7 THEN ABS(CHECKSUM(NEWID())) % 50 + 10 ELSE 10 END AS stock_minimo,
        CAST(0.1 + ABS(CHECKSUM(NEWID())) % 99 AS DECIMAL(8,2))                    AS peso_kg,
        CAST(0.001 + ABS(CHECKSUM(NEWID())) % 9 AS DECIMAL(8,3))                   AS volumen_m3,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 7 THEN 1 ELSE 0 END               AS es_digital,
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 730), GETDATE())                   AS fecha_lanzamiento,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 100 > 15 THEN 1 ELSE 0 END             AS activo
    FROM dbo.numeros num
    CROSS APPLY (SELECT TOP 1 v FROM @categorias ORDER BY NEWID()) c
    CROSS APPLY (
        SELECT TOP 1 v AS subcategoria FROM (VALUES
            ('Laptops'),('Tablets'),('Accesorios'),('Monitores'),('Almacenamiento'),
            ('Base de Datos'),('CRM'),('ERP'),('Analítica'),('Seguridad'),
            ('Soporte'),('Capacitación'),('Implementación'),('Mantenimiento'),('Otro')
        ) sub(v) ORDER BY NEWID()
    ) sc
    CROSS APPLY (SELECT TOP 1 v FROM @marcas ORDER BY NEWID()) m
    WHERE num.n <= @cantidad;

    DECLARE @total INT = (SELECT COUNT(*) FROM dbo.productos);
    PRINT 'Productos generados: ' + CAST(@total AS NVARCHAR);
    SELECT @total AS registros_creados, 'completado' AS estado;
END;
GO

-- ============================================================================
-- PROCEDIMIENTO: Generar vendedores
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_generar_vendedores
    @cantidad INT = 50,
    @limpiar  BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @limpiar = 1
    BEGIN
        DELETE FROM dbo.vendedores;
        PRINT 'Tabla vendedores limpiada';
    END;

    DECLARE @equipos     TABLE (n INT IDENTITY(1,1), v NVARCHAR(100));
    DECLARE @territorios TABLE (n INT IDENTITY(1,1), v NVARCHAR(100));
    INSERT INTO @equipos     (v) VALUES ('Empresas'),('PyMEs'),('Startups'),('Estratégico');
    INSERT INTO @territorios (v) VALUES ('Norte'),('Sur'),('Este'),('Oeste'),('Centro');

    INSERT INTO dbo.vendedores
        (nombre, email, telefono, equipo, territorio, gerente_id,
         tasa_comision, cuota_mensual, activo, fecha_contratacion)
    SELECT TOP (@cantidad)
        dbo.fn_nombre_aleatorio(CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 'M' ELSE 'F' END) AS nombre,
        LOWER(REPLACE(
            dbo.fn_nombre_aleatorio('M'), ' ', '.'
        )) + '@empresa.com'                                                                       AS email,
        '+54 11 ' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 99999999 AS NVARCHAR), 8)   AS telefono,
        eq.v                                                                                      AS equipo,
        ter.v                                                                                     AS territorio,
        NULL                                                                                      AS gerente_id,
        CAST(5 + ABS(CHECKSUM(NEWID())) % 10 AS DECIMAL(5,2))                                    AS tasa_comision,
        CAST(50000 + ABS(CHECKSUM(NEWID())) % 200000 AS DECIMAL(15,2))                           AS cuota_mensual,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 1 THEN 1 ELSE 0 END                              AS activo,
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 1095), GETDATE())                                AS fecha_contratacion
    FROM dbo.numeros num
    CROSS APPLY (SELECT TOP 1 v FROM @equipos     ORDER BY NEWID()) eq
    CROSS APPLY (SELECT TOP 1 v FROM @territorios ORDER BY NEWID()) ter
    WHERE num.n <= @cantidad;

    -- Asignar gerentes aleatoriamente al ~30% de vendedores
    UPDATE v
    SET gerente_id = g.id
    FROM dbo.vendedores v
    CROSS APPLY (
        SELECT TOP 1 id FROM dbo.vendedores WHERE id <> v.id ORDER BY NEWID()
    ) g
    WHERE ABS(CHECKSUM(NEWID())) % 10 > 7;

    DECLARE @total INT = (SELECT COUNT(*) FROM dbo.vendedores);
    PRINT 'Vendedores generados: ' + CAST(@total AS NVARCHAR);
    SELECT @total AS registros_creados, 'completado' AS estado;
END;
GO

-- ============================================================================
-- PROCEDIMIENTO: Generar órdenes e ítems
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_generar_ordenes
    @cantidad_ordenes INT = 5000,
    @dias_atras       INT = 365,
    @limpiar          BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @limpiar = 1
    BEGIN
        DELETE FROM dbo.items_orden;
        DELETE FROM dbo.ordenes;
        PRINT 'Tablas de órdenes limpiadas';
    END;

    DECLARE @total_clientes  INT = (SELECT COUNT(*) FROM dbo.clientes  WHERE activo = 1);
    DECLARE @total_productos INT = (SELECT COUNT(*) FROM dbo.productos  WHERE activo = 1);
    DECLARE @total_vendedores INT = (SELECT COUNT(*) FROM dbo.vendedores WHERE activo = 1);

    PRINT 'Generando ' + CAST(@cantidad_ordenes AS NVARCHAR) + ' órdenes con ' +
          CAST(@total_clientes AS NVARCHAR)  + ' clientes, ' +
          CAST(@total_productos AS NVARCHAR) + ' productos, ' +
          CAST(@total_vendedores AS NVARCHAR) + ' vendedores';

    -- ---- Insertar órdenes ----
    INSERT INTO dbo.ordenes
        (cliente_id, vendedor_id, fecha_orden, fecha_entrega_prometida,
         estado, estado_pago, metodo_pago, monto_impuesto, costo_envio,
         porcentaje_descuento, creado_por)
    SELECT TOP (@cantidad_ordenes)
        c.id                                                                         AS cliente_id,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 2 THEN v.id ELSE NULL END           AS vendedor_id,
        DATEADD(DAY,   -(ABS(CHECKSUM(NEWID())) % @dias_atras), GETDATE())          AS fecha_orden,
        DATEADD(DAY,   5, CAST(DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % @dias_atras), GETDATE()) AS DATE)) AS fecha_entrega_prometida,
        CASE ABS(CHECKSUM(NEWID())) % 100
            WHEN 0 THEN 'cancelado' WHEN 1 THEN 'cancelado' WHEN 2 THEN 'cancelado'
            WHEN 3 THEN 'cancelado' WHEN 4 THEN 'cancelado'
            WHEN 5 THEN 'pendiente' WHEN 6 THEN 'pendiente' WHEN 7 THEN 'pendiente'
            WHEN 8 THEN 'pendiente' WHEN 9 THEN 'pendiente'
            WHEN 10 THEN 'confirmado' WHEN 11 THEN 'confirmado' WHEN 12 THEN 'confirmado'
            WHEN 13 THEN 'procesando' WHEN 14 THEN 'procesando'
            WHEN 15 THEN 'enviado'    WHEN 16 THEN 'enviado'
            WHEN 17 THEN 'enviado'    WHEN 18 THEN 'enviado'
            ELSE 'entregado'
        END                                                                          AS estado,
        CASE
            WHEN ABS(CHECKSUM(NEWID())) % 100 < 5  THEN 'reembolsado'  -- cancelado
            WHEN ABS(CHECKSUM(NEWID())) % 100 < 15 THEN 'pendiente'
            WHEN ABS(CHECKSUM(NEWID())) % 100 < 25 THEN 'parcial'
            WHEN ABS(CHECKSUM(NEWID())) % 100 < 35 THEN 'vencido'
            ELSE 'pagado'
        END                                                                          AS estado_pago,
        CASE ABS(CHECKSUM(NEWID())) % 4
            WHEN 0 THEN 'tarjeta_credito' WHEN 1 THEN 'transferencia_bancaria'
            WHEN 2 THEN 'efectivo' ELSE 'cheque'
        END                                                                          AS metodo_pago,
        CAST(50 + ABS(CHECKSUM(NEWID())) % 450 AS DECIMAL(15,2))                   AS monto_impuesto,
        CAST(10 + ABS(CHECKSUM(NEWID())) % 90  AS DECIMAL(15,2))                   AS costo_envio,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 7
             THEN CAST(5 + ABS(CHECKSUM(NEWID())) % 20 AS DECIMAL(5,2))
             ELSE 0 END                                                              AS porcentaje_descuento,
        'sistema'                                                                    AS creado_por
    FROM dbo.numeros num
    CROSS APPLY (SELECT TOP 1 id FROM dbo.clientes   WHERE activo = 1 ORDER BY NEWID()) c
    CROSS APPLY (SELECT TOP 1 id FROM dbo.vendedores WHERE activo = 1 ORDER BY NEWID()) v
    WHERE num.n <= @cantidad_ordenes;

    -- ---- Insertar ítems (1-8 por orden) ----
    INSERT INTO dbo.items_orden
        (orden_id, producto_id, cantidad, precio_unitario, porcentaje_descuento, completado, cantidad_devuelta)
    SELECT
        o.id                                                                        AS orden_id,
        p.id                                                                        AS producto_id,
        ABS(CHECKSUM(NEWID())) % 10 + 1                                            AS cantidad,
        p.precio_lista                                                              AS precio_unitario,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 7
             THEN CAST(ABS(CHECKSUM(NEWID())) % 20 AS DECIMAL(5,2)) ELSE 0 END    AS porcentaje_descuento,
        CASE WHEN o.estado IN ('entregado','enviado') THEN 1 ELSE 0 END            AS completado,
        CASE WHEN o.estado = 'devuelto' AND ABS(CHECKSUM(NEWID())) % 2 = 0
             THEN ABS(CHECKSUM(NEWID())) % 3 + 1 ELSE 0 END                        AS cantidad_devuelta
    FROM dbo.ordenes o
    CROSS APPLY (
        SELECT TOP (ABS(CHECKSUM(NEWID())) % 8 + 1) id, precio_lista
        FROM dbo.productos WHERE activo = 1
        ORDER BY NEWID()
    ) p;

    DECLARE @tot_ord  INT = (SELECT COUNT(*) FROM dbo.ordenes);
    DECLARE @tot_items INT = (SELECT COUNT(*) FROM dbo.items_orden);
    PRINT 'Órdenes creadas: ' + CAST(@tot_ord AS NVARCHAR) +
          ' | Ítems creados: ' + CAST(@tot_items AS NVARCHAR);

    SELECT @tot_ord AS ordenes_creadas, @tot_items AS items_creados, 'completado' AS estado;
END;
GO

-- ============================================================================
-- PROCEDIMIENTO: Generar pagos
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_generar_pagos
    @limpiar BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @limpiar = 1
    BEGIN
        DELETE FROM dbo.pagos;
        PRINT 'Tabla pagos limpiada';
    END;

    INSERT INTO dbo.pagos
        (orden_id, monto, metodo_pago, fecha_pago, numero_referencia, estado)
    SELECT
        o.id                                                                        AS orden_id,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 10 > 3
             THEN o.monto_total
             ELSE CAST(o.monto_total * (0.3 + (ABS(CHECKSUM(NEWID())) % 70) / 100.0) AS DECIMAL(15,2))
        END                                                                         AS monto,
        CASE ABS(CHECKSUM(NEWID())) % 4
            WHEN 0 THEN 'tarjeta_credito' WHEN 1 THEN 'transferencia_bancaria'
            WHEN 2 THEN 'efectivo' ELSE 'cheque'
        END                                                                         AS metodo_pago,
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 365), GETDATE())                  AS fecha_pago,
        'REF-' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 999999 AS NVARCHAR), 8) AS numero_referencia,
        'completado'                                                               AS estado
    FROM dbo.ordenes o
    WHERE o.estado_pago IN ('pagado', 'parcial', 'vencido')
      AND o.monto_total > 0;

    DECLARE @total INT = (SELECT COUNT(*) FROM dbo.pagos);
    PRINT 'Pagos generados: ' + CAST(@total AS NVARCHAR);
    SELECT @total AS registros_creados, 'completado' AS estado;
END;
GO

-- ============================================================================
-- PROCEDIMIENTO MAESTRO: Generar todos los datos
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_generar_todos_los_datos
    @clientes   INT = 500,
    @productos  INT = 200,
    @vendedores INT = 50,
    @ordenes    INT = 5000,
    @dias_atras INT = 365
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @inicio DATETIME2, @fin DATETIME2;

    PRINT '====== INICIANDO GENERACIÓN DE DATOS DE PRUEBA ======';
    PRINT 'Parámetros: Clientes=' + CAST(@clientes AS NVARCHAR) +
          ', Productos=' + CAST(@productos AS NVARCHAR) +
          ', Vendedores=' + CAST(@vendedores AS NVARCHAR) +
          ', Órdenes=' + CAST(@ordenes AS NVARCHAR);

    -- Resultados acumulados
    CREATE TABLE #resultados (
        paso NVARCHAR(50), registros_creados INT, tiempo_segundos DECIMAL(10,3)
    );

    -- Clientes
    SET @inicio = GETDATE();
    EXEC dbo.sp_generar_clientes @cantidad = @clientes, @limpiar = 1;
    SET @fin = GETDATE();
    INSERT INTO #resultados VALUES ('CLIENTES', @clientes, DATEDIFF(MILLISECOND, @inicio, @fin) / 1000.0);

    -- Productos
    SET @inicio = GETDATE();
    EXEC dbo.sp_generar_productos @cantidad = @productos, @limpiar = 1;
    SET @fin = GETDATE();
    INSERT INTO #resultados VALUES ('PRODUCTOS', @productos, DATEDIFF(MILLISECOND, @inicio, @fin) / 1000.0);

    -- Vendedores
    SET @inicio = GETDATE();
    EXEC dbo.sp_generar_vendedores @cantidad = @vendedores, @limpiar = 1;
    SET @fin = GETDATE();
    INSERT INTO #resultados VALUES ('VENDEDORES', @vendedores, DATEDIFF(MILLISECOND, @inicio, @fin) / 1000.0);

    -- Órdenes e ítems
    SET @inicio = GETDATE();
    EXEC dbo.sp_generar_ordenes @cantidad_ordenes = @ordenes, @dias_atras = @dias_atras, @limpiar = 1;
    SET @fin = GETDATE();
    DECLARE @total_ord  INT = (SELECT COUNT(*) FROM dbo.ordenes);
    DECLARE @total_items INT = (SELECT COUNT(*) FROM dbo.items_orden);
    INSERT INTO #resultados VALUES ('ÓRDENES E ÍTEMS', @total_ord + @total_items, DATEDIFF(MILLISECOND, @inicio, @fin) / 1000.0);

    -- Pagos
    SET @inicio = GETDATE();
    EXEC dbo.sp_generar_pagos @limpiar = 1;
    SET @fin = GETDATE();
    DECLARE @total_pagos INT = (SELECT COUNT(*) FROM dbo.pagos);
    INSERT INTO #resultados VALUES ('PAGOS', @total_pagos, DATEDIFF(MILLISECOND, @inicio, @fin) / 1000.0);

    PRINT '====== GENERACIÓN COMPLETADA ======';
    PRINT 'Actualizando caché de vistas materializadas...';
    EXEC dbo.sp_refrescar_vistas_materializadas;

    SELECT paso, registros_creados, tiempo_segundos FROM #resultados;
    DROP TABLE #resultados;
END;
GO

-- ============================================================================
-- FIN DE PROCEDIMIENTOS DE GENERACIÓN DE DATOS
-- ============================================================================
