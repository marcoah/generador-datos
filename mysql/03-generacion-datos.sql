-- ============================================================================
-- PROCEDIMIENTOS DE GENERACIÓN DE DATOS REALISTAS
-- MySQL 8.0+
-- ============================================================================
-- NOTA: MySQL no tiene arrays; se usa ELT(indice, val1, val2, ...) para elegir
-- un valor aleatorio de una lista fija. La generación es fila por fila con
-- WHILE (igual que postgreSQL/03-generacion-datos.sql) en vez de un INSERT
-- masivo tipo CROSS APPLY, para evitar que el optimizador cachee expresiones
-- no correlacionadas con RAND() (el mismo problema que se encontró y corrigió
-- en t-sql/03-generacion-datos.sql).
-- ============================================================================

USE ventas_test;

-- Requerido para crear funciones que no son DETERMINISTIC sin privilegio SUPER
SET GLOBAL log_bin_trust_function_creators = 1;

-- ============================================================================
-- FUNCIÓN AUXILIAR: Generar nombre completo aleatorio
-- ============================================================================
DROP FUNCTION IF EXISTS fn_nombre_aleatorio;

DELIMITER //
CREATE FUNCTION fn_nombre_aleatorio(p_genero CHAR(1))
RETURNS VARCHAR(255)
NOT DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_nombre VARCHAR(50);
    DECLARE v_apellido VARCHAR(50);

    IF p_genero = 'F' THEN
        SET v_nombre = ELT(FLOOR(1 + RAND() * 15),
            'María','Carmen','Rosa','Isabel','Josefina','Ana','Francisca','Dolores',
            'Catalina','Antonia','Montserrat','Pilar','Sofía','Teresa','Laura');
    ELSE
        SET v_nombre = ELT(FLOOR(1 + RAND() * 15),
            'Carlos','Miguel','Juan','Luis','Pedro','Roberto','Antonio','Diego',
            'Francisco','Alejandro','Javier','Andrés','Sergio','Ricardo','Fernando');
    END IF;

    SET v_apellido = ELT(FLOOR(1 + RAND() * 15),
        'García','Martínez','Rodríguez','López','Hernández','González','Pérez',
        'Sánchez','Ramírez','Torres','Flores','Rivera','Gómez','Díaz','Reyes');

    RETURN CONCAT(v_nombre, ' ', v_apellido);
END//
DELIMITER ;

-- ============================================================================
-- PROCEDIMIENTO: Generar clientes
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_generar_clientes;

DELIMITER //
CREATE PROCEDURE sp_generar_clientes(IN p_cantidad INT, IN p_limpiar TINYINT)
BEGIN
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_nombre VARCHAR(255);
    DECLARE v_segmento VARCHAR(50);
    DECLARE v_email VARCHAR(255);

    IF p_limpiar = 1 THEN
        DELETE FROM clientes;
    END IF;

    WHILE v_i < p_cantidad DO
        SET v_nombre = fn_nombre_aleatorio(IF(RAND() > 0.5, 'M', 'F'));
        SET v_segmento = ELT(FLOOR(1 + RAND() * 5), 'premium','estandar','prueba','vip','inactivo');
        SET v_email = CONCAT(
            LOWER(REPLACE(REPLACE(REPLACE(v_nombre, ' ', '.'), 'ó', 'o'), 'é', 'e')),
            '.', v_i, '@',
            ELT(FLOOR(1 + RAND() * 5), 'gmail.com','yahoo.com','outlook.com','empresa.com','mail.com')
        );

        INSERT INTO clientes (
            nombre, email, telefono, segmento, industria, tamano_empresa,
            pais, provincia, ciudad, codigo_postal,
            limite_credito, fecha_adquisicion, activo
        ) VALUES (
            v_nombre,
            v_email,
            CONCAT('+54 ', ELT(FLOOR(1 + RAND() * 3), '11','351','261'), ' ',
                   LPAD(CAST(FLOOR(RAND() * 99999999) AS CHAR), 8, '0')),
            v_segmento,
            ELT(FLOOR(1 + RAND() * 8), 'Tecnología','Finanzas','Salud','Comercio',
                'Manufactura','Educación','Consultoría','Energía'),
            ELT(FLOOR(1 + RAND() * 5), 'startup','pequeña','mediana','grande','corporacion'),
            ELT(FLOOR(1 + RAND() * 5), 'Argentina','Chile','Uruguay','Colombia','México'),
            ELT(FLOOR(1 + RAND() * 6), 'Buenos Aires','Córdoba','Santa Fe','Mendoza','Tucumán','Rosario'),
            ELT(FLOOR(1 + RAND() * 10), 'Buenos Aires','Córdoba','Rosario','Mendoza','Tucumán',
                'Mar del Plata','Salta','Santa Fe','San Juan','Resistencia'),
            LPAD(CAST(FLOOR(RAND() * 9999) AS CHAR), 4, '0'),
            ROUND(10000 + RAND() * 990000, 2),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 365) DAY),
            IF(v_segmento = 'inactivo', 0, 1)
        );

        SET v_i = v_i + 1;
    END WHILE;

    SELECT COUNT(*) AS registros_creados, 'completado' AS estado FROM clientes;
END//
DELIMITER ;

-- ============================================================================
-- PROCEDIMIENTO: Generar productos
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_generar_productos;

DELIMITER //
CREATE PROCEDURE sp_generar_productos(IN p_cantidad INT, IN p_limpiar TINYINT)
BEGIN
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_categoria VARCHAR(100);
    DECLARE v_subcategoria VARCHAR(100);
    DECLARE v_marca VARCHAR(100);

    IF p_limpiar = 1 THEN
        DELETE FROM productos;
    END IF;

    WHILE v_i < p_cantidad DO
        SET v_categoria = ELT(FLOOR(1 + RAND() * 5), 'Electrónica','Software','Servicios','Hardware','Consultoría');

        SET v_subcategoria = CASE v_categoria
            WHEN 'Electrónica' THEN ELT(FLOOR(1 + RAND() * 5), 'Laptops','Tablets','Accesorios','Monitores','Almacenamiento')
            WHEN 'Software'    THEN ELT(FLOOR(1 + RAND() * 5), 'Base de Datos','CRM','ERP','Analítica','Seguridad')
            WHEN 'Servicios'   THEN ELT(FLOOR(1 + RAND() * 5), 'Soporte','Capacitación','Implementación','Mantenimiento','Consultoría')
            ELSE 'Otro'
        END;

        SET v_marca = ELT(FLOOR(1 + RAND() * 6), 'TechCorp','InnovaTech','SoftPro','CloudSys','DataFlow','SecureIT');

        INSERT INTO productos (
            nombre, sku, descripcion, categoria, subcategoria, marca,
            precio_lista, precio_costo, stock_actual, stock_minimo,
            peso_kg, volumen_m3, es_digital, fecha_lanzamiento, activo
        ) VALUES (
            CONCAT(v_marca, ' ', v_subcategoria, ' ', v_i),
            CONCAT('SKU-', LPAD(CAST(v_i AS CHAR), 6, '0')),
            CONCAT('Producto de alta calidad: ', v_subcategoria, ' de ', v_marca),
            v_categoria,
            v_subcategoria,
            v_marca,
            ROUND(100 + RAND() * 9900, 2),
            ROUND(50 + RAND() * 4950, 2),
            FLOOR(RAND() * 1000),
            IF(RAND() > 0.7, FLOOR(RAND() * 50) + 10, 10),
            ROUND(0.1 + RAND() * 99.9, 2),
            ROUND(0.001 + RAND() * 9.999, 3),
            IF(RAND() > 0.7, 1, 0),
            DATE_SUB(CURRENT_DATE, INTERVAL FLOOR(RAND() * 730) DAY),
            IF(RAND() > 0.15, 1, 0)
        );

        SET v_i = v_i + 1;
    END WHILE;

    SELECT COUNT(*) AS registros_creados, 'completado' AS estado FROM productos;
END//
DELIMITER ;

-- ============================================================================
-- PROCEDIMIENTO: Generar vendedores
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_generar_vendedores;

DELIMITER //
CREATE PROCEDURE sp_generar_vendedores(IN p_cantidad INT, IN p_limpiar TINYINT)
BEGIN
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_nombre VARCHAR(255);
    DECLARE v_gerente_id BIGINT UNSIGNED;

    IF p_limpiar = 1 THEN
        DELETE FROM vendedores;
    END IF;

    WHILE v_i < p_cantidad DO
        SET v_nombre = fn_nombre_aleatorio(IF(RAND() > 0.5, 'M', 'F'));

        SET v_gerente_id = NULL;
        IF v_i > 0 AND RAND() > 0.7 THEN
            SELECT id INTO v_gerente_id FROM vendedores ORDER BY RAND() LIMIT 1;
        END IF;

        INSERT INTO vendedores (
            nombre, email, telefono, equipo, territorio, gerente_id,
            tasa_comision, cuota_mensual, activo, fecha_contratacion
        ) VALUES (
            v_nombre,
            CONCAT(LOWER(REPLACE(REPLACE(REPLACE(v_nombre, ' ', '.'), 'ó', 'o'), 'é', 'e')),
                   '.', v_i, '@empresa.com'),
            CONCAT('+54 11 ', LPAD(CAST(FLOOR(RAND() * 99999999) AS CHAR), 8, '0')),
            ELT(FLOOR(1 + RAND() * 4), 'Empresas','PyMEs','Startups','Estratégico'),
            ELT(FLOOR(1 + RAND() * 5), 'Norte','Sur','Este','Oeste','Centro'),
            v_gerente_id,
            ROUND(5 + RAND() * 10, 2),
            ROUND(50000 + RAND() * 200000, 2),
            IF(RAND() > 0.1, 1, 0),
            DATE_SUB(CURRENT_DATE, INTERVAL FLOOR(RAND() * 1095) DAY)
        );

        SET v_i = v_i + 1;
    END WHILE;

    SELECT COUNT(*) AS registros_creados, 'completado' AS estado FROM vendedores;
END//
DELIMITER ;

-- ============================================================================
-- PROCEDIMIENTO: Generar órdenes e ítems
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_generar_ordenes;

DELIMITER //
CREATE PROCEDURE sp_generar_ordenes(IN p_cantidad_ordenes INT, IN p_dias_atras INT, IN p_limpiar TINYINT)
BEGIN
    DECLARE v_cant_ordenes INT DEFAULT 0;
    DECLARE v_cant_items INT DEFAULT 0;
    DECLARE v_orden_id BIGINT UNSIGNED;
    DECLARE v_cliente_id BIGINT UNSIGNED;
    DECLARE v_vendedor_id BIGINT UNSIGNED;
    DECLARE v_producto_id BIGINT UNSIGNED;
    DECLARE v_precio_unitario DECIMAL(10,2);
    DECLARE v_fecha_orden DATETIME;
    DECLARE v_estado VARCHAR(50);
    DECLARE v_estado_pago VARCHAR(50);
    DECLARE v_items_por_orden INT;
    DECLARE v_item_i INT;
    DECLARE v_rand DOUBLE;

    IF p_limpiar = 1 THEN
        DELETE FROM orden_detalles;
        DELETE FROM orden_encabezado;
    END IF;

    WHILE v_cant_ordenes < p_cantidad_ordenes DO
        SELECT id INTO v_cliente_id FROM clientes WHERE activo = 1 ORDER BY RAND() LIMIT 1;

        IF RAND() > 0.2 THEN
            SELECT id INTO v_vendedor_id FROM vendedores WHERE activo = 1 ORDER BY RAND() LIMIT 1;
        ELSE
            SET v_vendedor_id = NULL;
        END IF;

        SET v_fecha_orden = DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * p_dias_atras) DAY);

        SET v_rand = RAND();
        SET v_estado = CASE
            WHEN v_rand < 0.05 THEN 'cancelado'
            WHEN v_rand < 0.10 THEN 'pendiente'
            WHEN v_rand < 0.15 THEN 'confirmado'
            WHEN v_rand < 0.20 THEN 'procesando'
            WHEN v_rand < 0.30 THEN 'enviado'
            ELSE 'entregado'
        END;

        SET v_estado_pago = CASE
            WHEN v_estado = 'entregado' THEN ELT(FLOOR(1 + RAND() * 5), 'pendiente','parcial','pagado','vencido','reembolsado')
            WHEN v_estado = 'cancelado' THEN 'reembolsado'
            ELSE 'pendiente'
        END;

        INSERT INTO orden_encabezado (
            cliente_id, vendedor_id, fecha_orden, fecha_entrega_prometida,
            estado, estado_pago, metodo_pago, monto_impuesto, costo_envio,
            porcentaje_descuento, creado_por
        ) VALUES (
            v_cliente_id,
            v_vendedor_id,
            v_fecha_orden,
            DATE_ADD(DATE(v_fecha_orden), INTERVAL 5 DAY),
            v_estado,
            v_estado_pago,
            ELT(FLOOR(1 + RAND() * 4), 'tarjeta_credito','transferencia_bancaria','efectivo','cheque'),
            ROUND(50 + RAND() * 450, 2),
            ROUND(10 + RAND() * 90, 2),
            IF(RAND() > 0.7, ROUND(5 + RAND() * 20, 2), 0),
            'sistema'
        );

        SET v_orden_id = LAST_INSERT_ID();

        SET v_items_por_orden = FLOOR(RAND() * 7) + 1;
        SET v_item_i = 0;

        WHILE v_item_i < v_items_por_orden DO
            SELECT id, precio_lista INTO v_producto_id, v_precio_unitario
            FROM productos WHERE activo = 1 ORDER BY RAND() LIMIT 1;

            INSERT INTO orden_detalles (
                orden_id, producto_id, cantidad, precio_unitario,
                porcentaje_descuento, completado, cantidad_devuelta
            ) VALUES (
                v_orden_id,
                v_producto_id,
                FLOOR(RAND() * 10) + 1,
                v_precio_unitario,
                IF(RAND() > 0.7, ROUND(RAND() * 20, 2), 0),
                IF(v_estado IN ('entregado', 'enviado'), 1, 0),
                IF(v_estado = 'devuelto' AND RAND() > 0.5, FLOOR(RAND() * 3) + 1, 0)
            );

            SET v_cant_items = v_cant_items + 1;
            SET v_item_i = v_item_i + 1;
        END WHILE;

        SET v_cant_ordenes = v_cant_ordenes + 1;
    END WHILE;

    SELECT v_cant_ordenes AS ordenes_creadas, v_cant_items AS items_creados, 'completado' AS estado;
END//
DELIMITER ;

-- ============================================================================
-- PROCEDIMIENTO: Generar pagos
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_generar_pagos;

DELIMITER //
CREATE PROCEDURE sp_generar_pagos(IN p_limpiar TINYINT)
BEGIN
    DECLARE v_done INT DEFAULT 0;
    DECLARE v_orden_id BIGINT UNSIGNED;
    DECLARE v_monto_total DECIMAL(15,2);
    DECLARE v_monto_pago DECIMAL(15,2);
    DECLARE v_cant_pagos INT DEFAULT 0;
    DECLARE cur CURSOR FOR
        SELECT id, monto_total FROM orden_encabezado
        WHERE estado_pago IN ('pagado', 'parcial', 'vencido') AND monto_total > 0;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    IF p_limpiar = 1 THEN
        DELETE FROM pagos;
    END IF;

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_orden_id, v_monto_total;
        IF v_done = 1 THEN
            LEAVE read_loop;
        END IF;

        IF RAND() > 0.3 THEN
            SET v_monto_pago = v_monto_total;
        ELSE
            SET v_monto_pago = ROUND(v_monto_total * (0.3 + RAND() * 0.7), 2);
        END IF;

        INSERT INTO pagos (orden_id, monto, metodo_pago, fecha_pago, numero_referencia, estado)
        VALUES (
            v_orden_id,
            v_monto_pago,
            ELT(FLOOR(1 + RAND() * 4), 'tarjeta_credito','transferencia_bancaria','efectivo','cheque'),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 365) DAY),
            CONCAT('REF-', LPAD(CAST(FLOOR(RAND() * 999999) AS CHAR), 8, '0')),
            'completado'
        );

        SET v_cant_pagos = v_cant_pagos + 1;
    END LOOP;
    CLOSE cur;

    SELECT v_cant_pagos AS registros_creados, 'completado' AS estado;
END//
DELIMITER ;

-- ============================================================================
-- PROCEDIMIENTO MAESTRO: Generar todos los datos de prueba
-- ============================================================================
DROP PROCEDURE IF EXISTS sp_generar_todos_los_datos;

DELIMITER //
CREATE PROCEDURE sp_generar_todos_los_datos(
    IN p_clientes INT, IN p_productos INT, IN p_vendedores INT,
    IN p_ordenes INT, IN p_dias_atras INT
)
BEGIN
    CALL sp_generar_clientes(p_clientes, 1);
    CALL sp_generar_productos(p_productos, 1);
    CALL sp_generar_vendedores(p_vendedores, 1);
    CALL sp_generar_ordenes(p_ordenes, p_dias_atras, 1);
    CALL sp_generar_pagos(1);
    CALL sp_refrescar_vistas_materializadas();

    SELECT
        (SELECT COUNT(*) FROM clientes) AS clientes,
        (SELECT COUNT(*) FROM productos) AS productos,
        (SELECT COUNT(*) FROM vendedores) AS vendedores,
        (SELECT COUNT(*) FROM orden_encabezado) AS ordenes,
        (SELECT COUNT(*) FROM orden_detalles) AS items,
        (SELECT COUNT(*) FROM pagos) AS pagos;
END//
DELIMITER ;

-- ============================================================================
-- FIN DE PROCEDIMIENTOS DE GENERACIÓN DE DATOS
-- ============================================================================
