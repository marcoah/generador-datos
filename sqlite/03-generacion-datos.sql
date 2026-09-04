-- ============================================================================
-- GENERACIÓN DE DATOS REALISTAS DE PRUEBA
-- SQLite 3.35+
-- ============================================================================
-- NOTA: SQLite no tiene stored procedures, así que esto es un script plano
-- (no funciones reutilizables con parámetros). Para generar otra cantidad de
-- registros, editar los límites de los CTE recursivos "numeros" de cada
-- bloque (buscar "AJUSTAR CANTIDAD AQUÍ").
--
-- IMPORTANTE: SQLite evalúa una subconsulta no correlacionada (p.ej.
-- "(SELECT v FROM tabla ORDER BY RANDOM() LIMIT 1)") UNA SOLA VEZ y reutiliza
-- el resultado en todas las filas del SELECT exterior, en vez de recalcularla
-- fila por fila (mismo comportamiento que se encontró y corrigió en
-- t-sql/03-generacion-datos.sql). Por eso:
-- - Los valores tomados de listas fijas (segmento, categoría, etc.) se eligen
--   con una expresión CASE sobre RANDOM() en el propio SELECT, sin subconsulta.
-- - Los valores tomados de OTRA tabla (cliente_id, producto_id aleatorios) se
--   eligen con una subconsulta correlacionada agregando una condición trivial
--   "WHERE <alias_externo>.<col> = <alias_externo>.<col>" que fuerza a SQLite
--   a re-evaluarla en cada fila.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- LIMPIEZA (orden por dependencias de FK)
-- ============================================================================
DELETE FROM orden_detalles;
DELETE FROM pagos;
DELETE FROM devoluciones;
DELETE FROM campanas_clientes;
DELETE FROM interacciones_clientes;
DELETE FROM orden_encabezado;
DELETE FROM clientes;
DELETE FROM productos;
DELETE FROM vendedores;

-- ============================================================================
-- GENERAR CLIENTES  (AJUSTAR CANTIDAD AQUÍ: n < 500 -> 500 clientes)
-- ============================================================================
WITH RECURSIVE numeros(n) AS (
    SELECT 0
    UNION ALL
    SELECT n + 1 FROM numeros WHERE n < 499
),
generados AS (
    SELECT
        n,
        (CASE ABS(RANDOM() % 2)
            WHEN 0 THEN
                CASE ABS(RANDOM() % 15)
                    WHEN 0 THEN 'Carlos' WHEN 1 THEN 'Miguel' WHEN 2 THEN 'Juan' WHEN 3 THEN 'Luis'
                    WHEN 4 THEN 'Pedro' WHEN 5 THEN 'Roberto' WHEN 6 THEN 'Antonio' WHEN 7 THEN 'Diego'
                    WHEN 8 THEN 'Francisco' WHEN 9 THEN 'Alejandro' WHEN 10 THEN 'Javier' WHEN 11 THEN 'Andrés'
                    WHEN 12 THEN 'Sergio' WHEN 13 THEN 'Ricardo' ELSE 'Fernando'
                END
            ELSE
                CASE ABS(RANDOM() % 15)
                    WHEN 0 THEN 'María' WHEN 1 THEN 'Carmen' WHEN 2 THEN 'Rosa' WHEN 3 THEN 'Isabel'
                    WHEN 4 THEN 'Josefina' WHEN 5 THEN 'Ana' WHEN 6 THEN 'Francisca' WHEN 7 THEN 'Dolores'
                    WHEN 8 THEN 'Catalina' WHEN 9 THEN 'Antonia' WHEN 10 THEN 'Montserrat' WHEN 11 THEN 'Pilar'
                    WHEN 12 THEN 'Sofía' WHEN 13 THEN 'Teresa' ELSE 'Laura'
                END
        END) || ' ' ||
        (CASE ABS(RANDOM() % 15)
            WHEN 0 THEN 'García' WHEN 1 THEN 'Martínez' WHEN 2 THEN 'Rodríguez' WHEN 3 THEN 'López'
            WHEN 4 THEN 'Hernández' WHEN 5 THEN 'González' WHEN 6 THEN 'Pérez' WHEN 7 THEN 'Sánchez'
            WHEN 8 THEN 'Ramírez' WHEN 9 THEN 'Torres' WHEN 10 THEN 'Flores' WHEN 11 THEN 'Rivera'
            WHEN 12 THEN 'Gómez' WHEN 13 THEN 'Díaz' ELSE 'Reyes'
        END) AS nombre,
        CASE ABS(RANDOM() % 5)
            WHEN 0 THEN 'premium' WHEN 1 THEN 'estandar' WHEN 2 THEN 'prueba' WHEN 3 THEN 'vip' ELSE 'inactivo'
        END AS segmento,
        CASE ABS(RANDOM() % 8)
            WHEN 0 THEN 'Tecnología' WHEN 1 THEN 'Finanzas' WHEN 2 THEN 'Salud' WHEN 3 THEN 'Comercio'
            WHEN 4 THEN 'Manufactura' WHEN 5 THEN 'Educación' WHEN 6 THEN 'Consultoría' ELSE 'Energía'
        END AS industria,
        CASE ABS(RANDOM() % 5)
            WHEN 0 THEN 'startup' WHEN 1 THEN 'pequeña' WHEN 2 THEN 'mediana' WHEN 3 THEN 'grande' ELSE 'corporacion'
        END AS tamano_empresa,
        CASE ABS(RANDOM() % 5)
            WHEN 0 THEN 'Argentina' WHEN 1 THEN 'Chile' WHEN 2 THEN 'Uruguay' WHEN 3 THEN 'Colombia' ELSE 'México'
        END AS pais,
        CASE ABS(RANDOM() % 6)
            WHEN 0 THEN 'Buenos Aires' WHEN 1 THEN 'Córdoba' WHEN 2 THEN 'Santa Fe' WHEN 3 THEN 'Mendoza'
            WHEN 4 THEN 'Tucumán' ELSE 'Rosario'
        END AS provincia,
        CASE ABS(RANDOM() % 10)
            WHEN 0 THEN 'Buenos Aires' WHEN 1 THEN 'Córdoba' WHEN 2 THEN 'Rosario' WHEN 3 THEN 'Mendoza'
            WHEN 4 THEN 'Tucumán' WHEN 5 THEN 'Mar del Plata' WHEN 6 THEN 'Salta' WHEN 7 THEN 'Santa Fe'
            WHEN 8 THEN 'San Juan' ELSE 'Resistencia'
        END AS ciudad,
        printf('%04d', ABS(RANDOM() % 9999)) AS codigo_postal,
        ROUND(10000 + (ABS(RANDOM() % 1000000) / 1000000.0) * 990000, 2) AS limite_credito,
        printf('+54 %s %08d',
            CASE ABS(RANDOM() % 3) WHEN 0 THEN '11' WHEN 1 THEN '351' ELSE '261' END,
            ABS(RANDOM() % 99999999)
        ) AS telefono,
        CASE ABS(RANDOM() % 5)
            WHEN 0 THEN 'gmail.com' WHEN 1 THEN 'yahoo.com' WHEN 2 THEN 'outlook.com'
            WHEN 3 THEN 'empresa.com' ELSE 'mail.com'
        END AS dominio_email,
        datetime('now', '-' || ABS(RANDOM() % 365) || ' days') AS fecha_adquisicion
    FROM numeros
)
INSERT INTO clientes (
    nombre, email, telefono, segmento, industria, tamano_empresa,
    pais, provincia, ciudad, codigo_postal, limite_credito, fecha_adquisicion, activo
)
SELECT
    nombre,
    lower(replace(replace(replace(nombre, ' ', '.'), 'ó', 'o'), 'é', 'e')) || '.' || n || '@' || dominio_email,
    telefono,
    segmento,
    industria,
    tamano_empresa,
    pais,
    provincia,
    ciudad,
    codigo_postal,
    limite_credito,
    fecha_adquisicion,
    CASE WHEN segmento = 'inactivo' THEN 0 ELSE 1 END
FROM generados;

-- ============================================================================
-- GENERAR PRODUCTOS  (AJUSTAR CANTIDAD AQUÍ: n < 200 -> 200 productos)
-- ============================================================================
WITH RECURSIVE numeros(n) AS (
    SELECT 0
    UNION ALL
    SELECT n + 1 FROM numeros WHERE n < 199
),
generados AS (
    SELECT
        n,
        CASE ABS(RANDOM() % 5)
            WHEN 0 THEN 'Electrónica' WHEN 1 THEN 'Software' WHEN 2 THEN 'Servicios'
            WHEN 3 THEN 'Hardware' ELSE 'Consultoría'
        END AS categoria,
        CASE ABS(RANDOM() % 6)
            WHEN 0 THEN 'TechCorp' WHEN 1 THEN 'InnovaTech' WHEN 2 THEN 'SoftPro'
            WHEN 3 THEN 'CloudSys' WHEN 4 THEN 'DataFlow' ELSE 'SecureIT'
        END AS marca,
        ROUND(100 + (ABS(RANDOM() % 1000000) / 1000000.0) * 9900, 2) AS precio_lista,
        ROUND(50 + (ABS(RANDOM() % 1000000) / 1000000.0) * 4950, 2) AS precio_costo,
        ABS(RANDOM() % 1000) AS stock_actual,
        CASE WHEN ABS(RANDOM() % 10) > 7 THEN ABS(RANDOM() % 50) + 10 ELSE 10 END AS stock_minimo,
        ROUND(0.1 + (ABS(RANDOM() % 1000000) / 1000000.0) * 99.9, 2) AS peso_kg,
        ROUND(0.001 + (ABS(RANDOM() % 1000000) / 1000000.0) * 9.999, 3) AS volumen_m3,
        CASE WHEN ABS(RANDOM() % 10) > 7 THEN 1 ELSE 0 END AS es_digital,
        date('now', '-' || ABS(RANDOM() % 730) || ' days') AS fecha_lanzamiento,
        CASE WHEN ABS(RANDOM() % 100) > 15 THEN 1 ELSE 0 END AS activo
    FROM numeros
),
con_subcategoria AS (
    SELECT
        g.*,
        CASE g.categoria
            WHEN 'Electrónica' THEN
                CASE ABS(RANDOM() % 5)
                    WHEN 0 THEN 'Laptops' WHEN 1 THEN 'Tablets' WHEN 2 THEN 'Accesorios'
                    WHEN 3 THEN 'Monitores' ELSE 'Almacenamiento'
                END
            WHEN 'Software' THEN
                CASE ABS(RANDOM() % 5)
                    WHEN 0 THEN 'Base de Datos' WHEN 1 THEN 'CRM' WHEN 2 THEN 'ERP'
                    WHEN 3 THEN 'Analítica' ELSE 'Seguridad'
                END
            WHEN 'Servicios' THEN
                CASE ABS(RANDOM() % 5)
                    WHEN 0 THEN 'Soporte' WHEN 1 THEN 'Capacitación' WHEN 2 THEN 'Implementación'
                    WHEN 3 THEN 'Mantenimiento' ELSE 'Consultoría'
                END
            ELSE 'Otro'
        END AS subcategoria
    FROM generados g
)
INSERT INTO productos (
    nombre, sku, descripcion, categoria, subcategoria, marca,
    precio_lista, precio_costo, stock_actual, stock_minimo,
    peso_kg, volumen_m3, es_digital, fecha_lanzamiento, activo
)
SELECT
    marca || ' ' || subcategoria || ' ' || n,
    'SKU-' || printf('%06d', n),
    'Producto de alta calidad: ' || subcategoria || ' de ' || marca,
    categoria, subcategoria, marca,
    precio_lista, precio_costo, stock_actual, stock_minimo,
    peso_kg, volumen_m3, es_digital, fecha_lanzamiento, activo
FROM con_subcategoria;

-- ============================================================================
-- GENERAR VENDEDORES  (AJUSTAR CANTIDAD AQUÍ: n < 50 -> 50 vendedores)
-- ============================================================================
WITH RECURSIVE numeros(n) AS (
    SELECT 0
    UNION ALL
    SELECT n + 1 FROM numeros WHERE n < 49
),
generados AS (
    SELECT
        n,
        (CASE ABS(RANDOM() % 2)
            WHEN 0 THEN
                CASE ABS(RANDOM() % 15)
                    WHEN 0 THEN 'Carlos' WHEN 1 THEN 'Miguel' WHEN 2 THEN 'Juan' WHEN 3 THEN 'Luis'
                    WHEN 4 THEN 'Pedro' WHEN 5 THEN 'Roberto' WHEN 6 THEN 'Antonio' WHEN 7 THEN 'Diego'
                    WHEN 8 THEN 'Francisco' WHEN 9 THEN 'Alejandro' WHEN 10 THEN 'Javier' WHEN 11 THEN 'Andrés'
                    WHEN 12 THEN 'Sergio' WHEN 13 THEN 'Ricardo' ELSE 'Fernando'
                END
            ELSE
                CASE ABS(RANDOM() % 15)
                    WHEN 0 THEN 'María' WHEN 1 THEN 'Carmen' WHEN 2 THEN 'Rosa' WHEN 3 THEN 'Isabel'
                    WHEN 4 THEN 'Josefina' WHEN 5 THEN 'Ana' WHEN 6 THEN 'Francisca' WHEN 7 THEN 'Dolores'
                    WHEN 8 THEN 'Catalina' WHEN 9 THEN 'Antonia' WHEN 10 THEN 'Montserrat' WHEN 11 THEN 'Pilar'
                    WHEN 12 THEN 'Sofía' WHEN 13 THEN 'Teresa' ELSE 'Laura'
                END
        END) || ' ' ||
        (CASE ABS(RANDOM() % 15)
            WHEN 0 THEN 'García' WHEN 1 THEN 'Martínez' WHEN 2 THEN 'Rodríguez' WHEN 3 THEN 'López'
            WHEN 4 THEN 'Hernández' WHEN 5 THEN 'González' WHEN 6 THEN 'Pérez' WHEN 7 THEN 'Sánchez'
            WHEN 8 THEN 'Ramírez' WHEN 9 THEN 'Torres' WHEN 10 THEN 'Flores' WHEN 11 THEN 'Rivera'
            WHEN 12 THEN 'Gómez' WHEN 13 THEN 'Díaz' ELSE 'Reyes'
        END) AS nombre,
        CASE ABS(RANDOM() % 4)
            WHEN 0 THEN 'Empresas' WHEN 1 THEN 'PyMEs' WHEN 2 THEN 'Startups' ELSE 'Estratégico'
        END AS equipo,
        CASE ABS(RANDOM() % 5)
            WHEN 0 THEN 'Norte' WHEN 1 THEN 'Sur' WHEN 2 THEN 'Este' WHEN 3 THEN 'Oeste' ELSE 'Centro'
        END AS territorio,
        ROUND(5 + (ABS(RANDOM() % 1000000) / 1000000.0) * 10, 2) AS tasa_comision,
        ROUND(50000 + (ABS(RANDOM() % 1000000) / 1000000.0) * 200000, 2) AS cuota_mensual,
        CASE WHEN ABS(RANDOM() % 10) > 1 THEN 1 ELSE 0 END AS activo,
        date('now', '-' || ABS(RANDOM() % 1095) || ' days') AS fecha_contratacion,
        printf('+54 11 %08d', ABS(RANDOM() % 99999999)) AS telefono
    FROM numeros
)
INSERT INTO vendedores (
    nombre, email, telefono, equipo, territorio,
    tasa_comision, cuota_mensual, activo, fecha_contratacion
)
SELECT
    nombre,
    lower(replace(replace(replace(nombre, ' ', '.'), 'ó', 'o'), 'é', 'e')) || '.' || n || '@empresa.com',
    telefono, equipo, territorio, tasa_comision, cuota_mensual, activo, fecha_contratacion
FROM generados;

-- Asignar gerente a ~30% de los vendedores (elegido entre los ya generados)
UPDATE vendedores
SET gerente_id = (
    SELECT id FROM vendedores v2
    WHERE v2.id <> vendedores.id AND vendedores.id = vendedores.id
    ORDER BY RANDOM() LIMIT 1
)
WHERE ABS(RANDOM() % 10) > 7;

-- ============================================================================
-- GENERAR ÓRDENES  (AJUSTAR CANTIDAD AQUÍ: n < 5000 -> 5000 órdenes)
-- ============================================================================
WITH RECURSIVE numeros(n) AS (
    SELECT 0
    UNION ALL
    SELECT n + 1 FROM numeros WHERE n < 4999
),
generados AS (
    SELECT
        n,
        (SELECT id FROM clientes WHERE activo = 1 AND numeros.n = numeros.n ORDER BY RANDOM() LIMIT 1) AS cliente_id,
        CASE WHEN ABS(RANDOM() % 10) > 1
             THEN (SELECT id FROM vendedores WHERE activo = 1 AND numeros.n = numeros.n ORDER BY RANDOM() LIMIT 1)
             ELSE NULL
        END AS vendedor_id,
        datetime('now', '-' || ABS(RANDOM() % 365) || ' days') AS fecha_orden,
        (ABS(RANDOM() % 1000000) / 1000000.0) AS estado_rand,
        ROUND(50 + (ABS(RANDOM() % 1000000) / 1000000.0) * 450, 2) AS monto_impuesto,
        ROUND(10 + (ABS(RANDOM() % 1000000) / 1000000.0) * 90, 2) AS costo_envio,
        CASE WHEN ABS(RANDOM() % 10) > 7
             THEN ROUND(5 + (ABS(RANDOM() % 1000000) / 1000000.0) * 20, 2) ELSE 0 END AS porcentaje_descuento,
        CASE ABS(RANDOM() % 4)
            WHEN 0 THEN 'tarjeta_credito' WHEN 1 THEN 'transferencia_bancaria'
            WHEN 2 THEN 'efectivo' ELSE 'cheque'
        END AS metodo_pago,
        (ABS(RANDOM() % 1000000) / 1000000.0) AS pago_rand
    FROM numeros
),
con_estado AS (
    SELECT
        g.*,
        CASE
            WHEN estado_rand < 0.05 THEN 'cancelado'
            WHEN estado_rand < 0.10 THEN 'pendiente'
            WHEN estado_rand < 0.15 THEN 'confirmado'
            WHEN estado_rand < 0.20 THEN 'procesando'
            WHEN estado_rand < 0.30 THEN 'enviado'
            ELSE 'entregado'
        END AS estado
    FROM generados g
)
INSERT INTO orden_encabezado (
    cliente_id, vendedor_id, fecha_orden, fecha_entrega_prometida,
    estado, estado_pago, metodo_pago, monto_impuesto, costo_envio,
    porcentaje_descuento, creado_por
)
SELECT
    cliente_id,
    vendedor_id,
    fecha_orden,
    date(fecha_orden, '+5 days'),
    estado,
    CASE
        WHEN estado = 'cancelado' THEN 'reembolsado'
        WHEN estado = 'entregado' THEN
            CASE CAST(pago_rand * 5 AS INTEGER)
                WHEN 0 THEN 'pendiente' WHEN 1 THEN 'parcial' WHEN 2 THEN 'pagado'
                WHEN 3 THEN 'vencido' ELSE 'reembolsado'
            END
        ELSE 'pendiente'
    END,
    metodo_pago, monto_impuesto, costo_envio, porcentaje_descuento, 'sistema'
FROM con_estado;

-- ============================================================================
-- GENERAR ÍTEMS DE ÓRDENES (1 a 8 por orden)
-- ============================================================================
WITH RECURSIVE numeros_item(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM numeros_item WHERE n < 8
),
items AS (
    SELECT
        o.id AS orden_id,
        o.estado AS orden_estado,
        ni.n
    FROM orden_encabezado o
    JOIN numeros_item ni
    WHERE ni.n <= 1 + ABS((RANDOM() + o.id) % 8)
),
items_con_producto AS (
    SELECT
        i.*,
        (SELECT p.id FROM productos p WHERE p.activo = 1 AND i.orden_id = i.orden_id AND i.n = i.n
         ORDER BY RANDOM() LIMIT 1) AS producto_id
    FROM items i
)
INSERT INTO orden_detalles (
    orden_id, producto_id, cantidad, precio_unitario,
    porcentaje_descuento, completado, cantidad_devuelta
)
SELECT
    ip.orden_id,
    ip.producto_id,
    1 + ABS((RANDOM() + ip.orden_id + ip.n) % 10) AS cantidad,
    p.precio_lista AS precio_unitario,
    CASE WHEN ABS((RANDOM() + ip.orden_id) % 10) > 7
         THEN ROUND((ABS((RANDOM() + ip.n) % 1000000) / 1000000.0) * 20, 2) ELSE 0 END,
    CASE WHEN ip.orden_estado IN ('entregado', 'enviado') THEN 1 ELSE 0 END,
    CASE WHEN ip.orden_estado = 'devuelto' AND ABS((RANDOM() + ip.orden_id) % 2) = 0
         THEN 1 + ABS((RANDOM() + ip.n) % 3) ELSE 0 END
FROM items_con_producto ip
JOIN productos p ON p.id = ip.producto_id;

-- ============================================================================
-- GENERAR PAGOS (para órdenes pagadas, parciales o vencidas)
-- ============================================================================
INSERT INTO pagos (orden_id, monto, metodo_pago, fecha_pago, numero_referencia, estado)
SELECT
    o.id,
    CASE WHEN ABS((RANDOM() + o.id) % 10) > 3
         THEN o.monto_total
         ELSE ROUND(o.monto_total * (0.3 + (ABS((RANDOM() + o.id) % 1000000) / 1000000.0) * 0.7), 2)
    END,
    CASE ABS((RANDOM() + o.id) % 4)
        WHEN 0 THEN 'tarjeta_credito' WHEN 1 THEN 'transferencia_bancaria'
        WHEN 2 THEN 'efectivo' ELSE 'cheque'
    END,
    datetime('now', '-' || ABS((RANDOM() + o.id) % 365) || ' days'),
    'REF-' || printf('%08d', ABS((RANDOM() + o.id) % 99999999)),
    'completado'
FROM orden_encabezado o
WHERE o.estado_pago IN ('pagado', 'parcial', 'vencido') AND o.monto_total > 0;

-- ============================================================================
-- FIN DE GENERACIÓN DE DATOS
-- Recordar volver a ejecutar el bloque "REFRESCAR TABLAS DE CACHÉ" de
-- 02-vistas-y-funciones.sql después de correr este script.
-- ============================================================================
