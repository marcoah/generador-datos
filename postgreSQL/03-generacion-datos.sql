-- ============================================================================
-- FUNCIONES DE GENERACIÓN DE DATOS REALISTAS
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- FUNCIONES AUXILIARES
-- ============================================================================

-- Función: Generar nombres realistas
CREATE OR REPLACE FUNCTION generar_nombre_aleatorio(p_genero CHAR DEFAULT 'M')
RETURNS VARCHAR AS $$
DECLARE
    v_nombres_m VARCHAR[] := ARRAY[
        'Carlos', 'Miguel', 'Juan', 'Luis', 'Pedro', 'Roberto', 'Antonio', 'Diego',
        'Francisco', 'Alejandro', 'Javier', 'Andrés', 'Sergio', 'Ricardo', 'Fernando'
    ];
    v_nombres_f VARCHAR[] := ARRAY[
        'María', 'Carmen', 'Rosa', 'Isabel', 'Josefina', 'Ana', 'Francisca', 'Dolores',
        'Catalina', 'Antonia', 'Montserrat', 'Pilar', 'Sofía', 'Teresa', 'Laura'
    ];
    v_apellidos VARCHAR[] := ARRAY[
        'García', 'Martínez', 'Rodríguez', 'López', 'Hernández', 'González', 'Pérez',
        'Sánchez', 'Ramírez', 'Torres', 'Flores', 'Rivera', 'Gómez', 'Díaz', 'Reyes'
    ];
BEGIN
    RETURN
        CASE
            WHEN p_genero = 'F' THEN
                v_nombres_f[((RANDOM() * (ARRAY_LENGTH(v_nombres_f, 1) - 1))::INT) + 1] || ' ' ||
                v_apellidos[((RANDOM() * (ARRAY_LENGTH(v_apellidos, 1) - 1))::INT) + 1]
            ELSE
                v_nombres_m[((RANDOM() * (ARRAY_LENGTH(v_nombres_m, 1) - 1))::INT) + 1] || ' ' ||
                v_apellidos[((RANDOM() * (ARRAY_LENGTH(v_apellidos, 1) - 1))::INT) + 1]
        END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Función: Generar email
CREATE OR REPLACE FUNCTION generar_email_aleatorio(p_nombre VARCHAR)
RETURNS VARCHAR AS $$
BEGIN
    RETURN LOWER(
        REPLACE(REPLACE(REPLACE(p_nombre, ' ', '.'), 'ó', 'o'), 'é', 'e')
        || '@' ||
        CASE ((RANDOM() * 5)::INT)
            WHEN 0 THEN 'gmail.com'
            WHEN 1 THEN 'yahoo.com'
            WHEN 2 THEN 'outlook.com'
            WHEN 3 THEN 'empresa.com'
            ELSE 'mail.com'
        END
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Función: Generar número de teléfono
CREATE OR REPLACE FUNCTION generar_telefono_aleatorio()
RETURNS VARCHAR AS $$
BEGIN
    RETURN '+54 ' ||
        CASE ((RANDOM() * 3)::INT)
            WHEN 0 THEN '11'
            WHEN 1 THEN '351'
            ELSE '261'
        END || ' ' ||
        LPAD(((RANDOM() * 99999999)::BIGINT)::TEXT, 8, '0');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- FUNCIÓN PRINCIPAL: GENERAR CLIENTES
-- ============================================================================

CREATE OR REPLACE FUNCTION generar_clientes(
    p_cantidad INT DEFAULT 500,
    p_limpiar BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    registros_creados INT,
    estado TEXT
) AS $$
DECLARE
    v_i INT := 0;
    v_nombre VARCHAR;
    v_email VARCHAR;
    v_segmento VARCHAR;
    v_industria VARCHAR;
    v_tamaño_empresa VARCHAR;
    v_ciudad VARCHAR;
    v_pais VARCHAR;

    v_segmentos VARCHAR[] := ARRAY['premium', 'estandar', 'prueba', 'vip', 'inactivo'];
    v_industrias VARCHAR[] := ARRAY['Tecnología', 'Finanzas', 'Salud', 'Comercio', 'Manufactura', 'Educación', 'Consultoría', 'Energía'];
    v_tamaños VARCHAR[] := ARRAY['startup', 'pequeña', 'mediana', 'grande', 'corporacion'];
    v_paises VARCHAR[] := ARRAY['Argentina', 'Chile', 'Uruguay', 'Colombia', 'México'];
    v_provincias VARCHAR[] := ARRAY['Buenos Aires', 'Córdoba', 'Santa Fe', 'Mendoza', 'Tucumán', 'Rosario'];
    v_ciudades VARCHAR[] := ARRAY['Buenos Aires', 'Córdoba', 'Rosario', 'Mendoza', 'Tucumán', 'Mar del Plata', 'Salta', 'Santa Fe', 'San Juan', 'Resistencia'];
BEGIN
    IF p_limpiar THEN
        DELETE FROM clientes;
        RAISE NOTICE 'Tabla clientes limpiada';
    END IF;

    WHILE v_i < p_cantidad LOOP
        v_nombre := generar_nombre_aleatorio(CASE WHEN RANDOM() > 0.5 THEN 'M' ELSE 'F' END);
        v_email := generar_email_aleatorio(v_nombre);

        v_segmento := v_segmentos[((RANDOM() * (ARRAY_LENGTH(v_segmentos, 1) - 1))::INT) + 1];
        v_industria := v_industrias[((RANDOM() * (ARRAY_LENGTH(v_industrias, 1) - 1))::INT) + 1];
        v_tamaño_empresa := v_tamaños[((RANDOM() * (ARRAY_LENGTH(v_tamaños, 1) - 1))::INT) + 1];
        v_pais := v_paises[((RANDOM() * (ARRAY_LENGTH(v_paises, 1) - 1))::INT) + 1];

        INSERT INTO clientes (
            nombre, email, telefono, segmento, industria, tamaño_empresa,
            pais, provincia, ciudad, codigo_postal,
            limite_credito, fecha_adquisicion, activo
        ) VALUES (
            v_nombre,
            v_email,
            generar_telefono_aleatorio(),
            v_segmento,
            v_industria,
            v_tamaño_empresa,
            v_pais,
            v_provincias[((RANDOM() * (ARRAY_LENGTH(v_provincias, 1) - 1))::INT) + 1],
            v_ciudades[((RANDOM() * (ARRAY_LENGTH(v_ciudades, 1) - 1))::INT) + 1],
            LPAD(((RANDOM() * 9999)::INT)::TEXT, 4, '0'),
            (10000 + RANDOM() * 990000)::NUMERIC(10, 2),
            CURRENT_TIMESTAMP - ((RANDOM() * 365)::INT || ' days')::INTERVAL,
            CASE WHEN v_segmento = 'inactivo' THEN FALSE ELSE TRUE END
        );

        v_i := v_i + 1;

        IF v_i % 100 = 0 THEN
            RAISE NOTICE 'Generados % clientes', v_i;
        END IF;
    END LOOP;

    RETURN QUERY SELECT v_i, 'completado'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN: GENERAR PRODUCTOS
-- ============================================================================

CREATE OR REPLACE FUNCTION generar_productos(
    p_cantidad INT DEFAULT 200,
    p_limpiar BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    registros_creados INT,
    estado TEXT
) AS $$
DECLARE
    v_i INT := 0;
    v_categoria VARCHAR;
    v_subcategoria VARCHAR;
    v_marca VARCHAR;

    v_categorias VARCHAR[] := ARRAY['Electrónica', 'Software', 'Servicios', 'Hardware', 'Consultoría'];
    v_sub_electronica VARCHAR[] := ARRAY['Laptops', 'Tablets', 'Accesorios', 'Monitores', 'Almacenamiento'];
    v_sub_software VARCHAR[] := ARRAY['Base de Datos', 'CRM', 'ERP', 'Analítica', 'Seguridad'];
    v_sub_servicios VARCHAR[] := ARRAY['Soporte', 'Capacitación', 'Implementación', 'Mantenimiento', 'Consultoría'];
    v_marcas VARCHAR[] := ARRAY['TechCorp', 'InnovaTech', 'SoftPro', 'CloudSys', 'DataFlow', 'SecureIT'];
BEGIN
    IF p_limpiar THEN
        DELETE FROM productos;
        RAISE NOTICE 'Tabla productos limpiada';
    END IF;

    WHILE v_i < p_cantidad LOOP
        v_categoria := v_categorias[((RANDOM() * (ARRAY_LENGTH(v_categorias, 1) - 1))::INT) + 1];

        v_subcategoria := CASE v_categoria
            WHEN 'Electrónica' THEN v_sub_electronica[((RANDOM() * (ARRAY_LENGTH(v_sub_electronica, 1) - 1))::INT) + 1]
            WHEN 'Software' THEN v_sub_software[((RANDOM() * (ARRAY_LENGTH(v_sub_software, 1) - 1))::INT) + 1]
            WHEN 'Servicios' THEN v_sub_servicios[((RANDOM() * (ARRAY_LENGTH(v_sub_servicios, 1) - 1))::INT) + 1]
            ELSE 'Otro'
        END;

        v_marca := v_marcas[((RANDOM() * (ARRAY_LENGTH(v_marcas, 1) - 1))::INT) + 1];

        INSERT INTO productos (
            nombre,
            sku,
            descripcion,
            categoria,
            subcategoria,
            marca,
            precio_lista,
            precio_costo,
            stock_actual,
            stock_minimo,
            peso_kg,
            volumen_m3,
            es_digital,
            fecha_lanzamiento,
            activo
        ) VALUES (
            v_marca || ' ' || v_subcategoria || ' ' || v_i,
            'SKU-' || LPAD(v_i::TEXT, 6, '0'),
            'Producto de alta calidad: ' || v_subcategoria || ' de ' || v_marca,
            v_categoria,
            v_subcategoria,
            v_marca,
            (100 + RANDOM() * 9900)::NUMERIC(10, 2),
            (50 + RANDOM() * 4950)::NUMERIC(10, 2),
            ((RANDOM() * 1000)::INT),
            CASE WHEN RANDOM() > 0.7 THEN ((RANDOM() * 50)::INT) + 10 ELSE 10 END,
            (0.1 + RANDOM() * 99.9)::NUMERIC(8, 2),
            (0.001 + RANDOM() * 9.999)::NUMERIC(8, 3),
            CASE WHEN RANDOM() > 0.7 THEN TRUE ELSE FALSE END,
            CURRENT_DATE - ((RANDOM() * 730)::INT || ' days')::INTERVAL,
            CASE WHEN RANDOM() > 0.15 THEN TRUE ELSE FALSE END
        );

        v_i := v_i + 1;

        IF v_i % 50 = 0 THEN
            RAISE NOTICE 'Generados % productos', v_i;
        END IF;
    END LOOP;

    RETURN QUERY SELECT v_i, 'completado'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN: GENERAR VENDEDORES
-- ============================================================================

CREATE OR REPLACE FUNCTION generar_vendedores(
    p_cantidad INT DEFAULT 50,
    p_limpiar BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    registros_creados INT,
    estado TEXT
) AS $$
DECLARE
    v_i INT := 0;
    v_nombre VARCHAR;
    v_equipo VARCHAR;
    v_territorio VARCHAR;

    v_equipos VARCHAR[] := ARRAY['Empresas', 'PyMEs', 'Startups', 'Estratégico'];
    v_territorios VARCHAR[] := ARRAY['Norte', 'Sur', 'Este', 'Oeste', 'Centro'];
BEGIN
    IF p_limpiar THEN
        DELETE FROM vendedores;
        RAISE NOTICE 'Tabla vendedores limpiada';
    END IF;

    WHILE v_i < p_cantidad LOOP
        v_nombre := generar_nombre_aleatorio(CASE WHEN RANDOM() > 0.5 THEN 'M' ELSE 'F' END);
        v_equipo := v_equipos[((RANDOM() * (ARRAY_LENGTH(v_equipos, 1) - 1))::INT) + 1];
        v_territorio := v_territorios[((RANDOM() * (ARRAY_LENGTH(v_territorios, 1) - 1))::INT) + 1];

        INSERT INTO vendedores (
            nombre,
            email,
            telefono,
            equipo,
            territorio,
            gerente_id,
            tasa_comision,
            cuota_mensual,
            activo,
            fecha_contratacion
        ) VALUES (
            v_nombre,
            generar_email_aleatorio(v_nombre),
            generar_telefono_aleatorio(),
            v_equipo,
            v_territorio,
            CASE WHEN v_i > 0 AND RANDOM() > 0.7
                THEN ((RANDOM() * (v_i - 1))::INT) + 1
                ELSE NULL
            END,
            (5 + RANDOM() * 10)::NUMERIC(5, 2),
            (50000 + RANDOM() * 200000)::NUMERIC(15, 2),
            CASE WHEN RANDOM() > 0.1 THEN TRUE ELSE FALSE END,
            CURRENT_DATE - ((RANDOM() * 1095)::INT || ' days')::INTERVAL
        );

        v_i := v_i + 1;
    END LOOP;

    RETURN QUERY SELECT v_i, 'completado'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN: GENERAR ÓRDENES E ÍTEMS
-- ============================================================================

CREATE OR REPLACE FUNCTION generar_ordenes(
    p_cantidad_ordenes INT DEFAULT 5000,
    p_dias_atras INT DEFAULT 365,
    p_limpiar BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    ordenes_creadas INT,
    items_creados INT,
    estado TEXT
) AS $$
DECLARE
    v_cant_ordenes INT := 0;
    v_cant_items INT := 0;
    v_orden_id BIGINT;
    v_cliente_id BIGINT;
    v_vendedor_id BIGINT;
    v_producto_id BIGINT;
    v_cantidad INT;
    v_precio_unitario NUMERIC(10, 2);
    v_pct_descuento NUMERIC(5, 2);
    v_fecha_orden TIMESTAMP;
    v_items_por_orden INT;
    v_item_i INT;
    v_total_clientes BIGINT;
    v_total_productos BIGINT;
    v_total_vendedores BIGINT;
    v_estado VARCHAR;
    v_estado_pago VARCHAR;

    v_estados VARCHAR[] := ARRAY['pendiente', 'confirmado', 'procesando', 'enviado', 'entregado', 'cancelado', 'devuelto'];
    v_estados_pago VARCHAR[] := ARRAY['pendiente', 'parcial', 'pagado', 'vencido', 'reembolsado'];
BEGIN
    IF p_limpiar THEN
        DELETE FROM items_orden;
        DELETE FROM ordenes;
        RAISE NOTICE 'Tablas de órdenes limpiadas';
    END IF;

    -- Obtener conteos
    SELECT COUNT(*) INTO v_total_clientes FROM clientes WHERE activo = TRUE;
    SELECT COUNT(*) INTO v_total_productos FROM productos WHERE activo = TRUE;
    SELECT COUNT(*) INTO v_total_vendedores FROM vendedores WHERE activo = TRUE;

    RAISE NOTICE 'Generando % órdenes usando % clientes, % productos, % vendedores',
        p_cantidad_ordenes, v_total_clientes, v_total_productos, v_total_vendedores;

    WHILE v_cant_ordenes < p_cantidad_ordenes LOOP
        -- Seleccionar cliente aleatorio
        SELECT id INTO v_cliente_id FROM clientes
        WHERE activo = TRUE
        ORDER BY RANDOM() LIMIT 1;

        -- Seleccionar vendedor (puede ser NULL)
        IF RANDOM() > 0.2 THEN
            SELECT id INTO v_vendedor_id FROM vendedores
            WHERE activo = TRUE
            ORDER BY RANDOM() LIMIT 1;
        ELSE
            v_vendedor_id := NULL;
        END IF;

        -- Fecha aleatoria
        v_fecha_orden := CURRENT_TIMESTAMP - ((RANDOM() * p_dias_atras)::INT || ' days')::INTERVAL;

        -- Estados con distribución realista
        v_estado := CASE
            WHEN RANDOM() < 0.05 THEN 'cancelado'
            WHEN RANDOM() < 0.10 THEN 'pendiente'
            WHEN RANDOM() < 0.15 THEN 'confirmado'
            WHEN RANDOM() < 0.20 THEN 'procesando'
            WHEN RANDOM() < 0.30 THEN 'enviado'
            ELSE 'entregado'
        END;

        v_estado_pago := CASE v_estado
            WHEN 'entregado' THEN v_estados_pago[((RANDOM() * (ARRAY_LENGTH(v_estados_pago, 1) - 1))::INT) + 1]
            WHEN 'cancelado' THEN 'reembolsado'
            ELSE 'pendiente'
        END;

        -- Insertar orden
        INSERT INTO ordenes (
            cliente_id,
            vendedor_id,
            fecha_orden,
            fecha_entrega_prometida,
            estado,
            estado_pago,
            metodo_pago,
            monto_impuesto,
            costo_envio,
            porcentaje_descuento,
            creado_por
        ) VALUES (
            v_cliente_id,
            v_vendedor_id,
            v_fecha_orden,
            v_fecha_orden::DATE + INTERVAL '5 days',
            v_estado,
            v_estado_pago,
            ARRAY['tarjeta_credito', 'transferencia_bancaria', 'efectivo', 'cheque'][((RANDOM() * 3)::INT) + 1],
            (50 + RANDOM() * 450)::NUMERIC(15, 2),
            (10 + RANDOM() * 90)::NUMERIC(15, 2),
            CASE WHEN RANDOM() > 0.7 THEN (5 + RANDOM() * 20)::NUMERIC(5, 2) ELSE 0 END,
            'sistema'
        ) RETURNING id INTO v_orden_id;

        -- Generar ítems para esta orden (1-8 ítems)
        v_items_por_orden := ((RANDOM() * 7)::INT) + 1;
        v_item_i := 0;

        WHILE v_item_i < v_items_por_orden LOOP
            -- Seleccionar producto aleatorio
            SELECT id, precio_lista INTO v_producto_id, v_precio_unitario FROM productos
            WHERE activo = TRUE
            ORDER BY RANDOM() LIMIT 1;

            v_cantidad := ((RANDOM() * 10)::INT) + 1;
            v_pct_descuento := CASE WHEN RANDOM() > 0.7 THEN RANDOM() * 20 ELSE 0 END;

            INSERT INTO items_orden (
                orden_id,
                producto_id,
                cantidad,
                precio_unitario,
                porcentaje_descuento,
                completado,
                cantidad_devuelta
            ) VALUES (
                v_orden_id,
                v_producto_id,
                v_cantidad,
                v_precio_unitario,
                v_pct_descuento,
                CASE WHEN v_estado IN ('entregado', 'enviado') THEN TRUE ELSE FALSE END,
                CASE WHEN v_estado = 'devuelto' AND RANDOM() > 0.5 THEN ((RANDOM() * v_cantidad)::INT) ELSE 0 END
            );

            v_cant_items := v_cant_items + 1;
            v_item_i := v_item_i + 1;
        END LOOP;

        v_cant_ordenes := v_cant_ordenes + 1;

        IF v_cant_ordenes % 500 = 0 THEN
            RAISE NOTICE 'Generadas % órdenes con % ítems', v_cant_ordenes, v_cant_items;
        END IF;
    END LOOP;

    RETURN QUERY SELECT v_cant_ordenes, v_cant_items, 'completado'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN: GENERAR PAGOS
-- ============================================================================

CREATE OR REPLACE FUNCTION generar_pagos(
    p_limpiar BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    registros_creados INT,
    estado TEXT
) AS $$
DECLARE
    v_cant_pagos INT := 0;
    v_orden_id BIGINT;
    v_monto_total NUMERIC(15, 2);
    v_monto_pago NUMERIC(15, 2);
    v_metodo_pago VARCHAR;
BEGIN
    IF p_limpiar THEN
        DELETE FROM pagos;
        RAISE NOTICE 'Tabla pagos limpiada';
    END IF;

    -- Generar pagos para órdenes pagadas o parcialmente pagadas
    FOR v_orden_id, v_monto_total IN
        SELECT id, monto_total FROM ordenes
        WHERE estado_pago IN ('pagado', 'parcial', 'vencido')
        AND monto_total > 0
    LOOP
        v_metodo_pago := ARRAY['tarjeta_credito', 'transferencia_bancaria', 'efectivo', 'cheque'][((RANDOM() * 3)::INT) + 1];

        IF RANDOM() > 0.3 THEN
            -- Pago completo
            v_monto_pago := v_monto_total;
        ELSE
            -- Pago parcial
            v_monto_pago := v_monto_total * (0.3 + RANDOM() * 0.7);
        END IF;

        INSERT INTO pagos (
            orden_id,
            monto,
            metodo_pago,
            fecha_pago,
            numero_referencia,
            estado
        ) VALUES (
            v_orden_id,
            v_monto_pago,
            v_metodo_pago,
            CURRENT_TIMESTAMP - ((RANDOM() * 365)::INT || ' days')::INTERVAL,
            'REF-' || LPAD(((RANDOM() * 999999)::BIGINT)::TEXT, 8, '0'),
            'completado'
        );

        v_cant_pagos := v_cant_pagos + 1;
    END LOOP;

    RETURN QUERY SELECT v_cant_pagos, 'completado'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN MAESTRA: GENERAR TODOS LOS DATOS DE PRUEBA
-- ============================================================================

CREATE OR REPLACE FUNCTION generar_todos_los_datos(
    p_clientes INT DEFAULT 500,
    p_productos INT DEFAULT 200,
    p_vendedores INT DEFAULT 50,
    p_ordenes INT DEFAULT 5000,
    p_dias_atras INT DEFAULT 365
)
RETURNS TABLE (
    paso TEXT,
    registros_creados INT,
    tiempo_ejecucion_segundos NUMERIC
) AS $$
DECLARE
    v_inicio TIMESTAMP;
    v_fin TIMESTAMP;
    v_resultado RECORD;
BEGIN
    RAISE NOTICE '====== INICIANDO GENERACIÓN DE DATOS DE PRUEBA ======';
    RAISE NOTICE 'Parámetros: Clientes=%, Productos=%, Vendedores=%, Órdenes=%',
        p_clientes, p_productos, p_vendedores, p_ordenes;

    -- Generar clientes
    v_inicio := CURRENT_TIMESTAMP;
    FOR v_resultado IN SELECT * FROM generar_clientes(p_clientes, TRUE) LOOP
        RETURN QUERY SELECT
            'CLIENTES'::TEXT,
            v_resultado.registros_creados,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_inicio))::NUMERIC;
    END LOOP;

    -- Generar productos
    v_inicio := CURRENT_TIMESTAMP;
    FOR v_resultado IN SELECT * FROM generar_productos(p_productos, TRUE) LOOP
        RETURN QUERY SELECT
            'PRODUCTOS'::TEXT,
            v_resultado.registros_creados,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_inicio))::NUMERIC;
    END LOOP;

    -- Generar vendedores
    v_inicio := CURRENT_TIMESTAMP;
    FOR v_resultado IN SELECT * FROM generar_vendedores(p_vendedores, TRUE) LOOP
        RETURN QUERY SELECT
            'VENDEDORES'::TEXT,
            v_resultado.registros_creados,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_inicio))::NUMERIC;
    END LOOP;

    -- Generar órdenes
    v_inicio := CURRENT_TIMESTAMP;
    FOR v_resultado IN SELECT * FROM generar_ordenes(p_ordenes, p_dias_atras, TRUE) LOOP
        RETURN QUERY SELECT
            'ÓRDENES E ÍTEMS'::TEXT,
            (v_resultado.ordenes_creadas + v_resultado.items_creados),
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_inicio))::NUMERIC;
    END LOOP;

    -- Generar pagos
    v_inicio := CURRENT_TIMESTAMP;
    FOR v_resultado IN SELECT * FROM generar_pagos(TRUE) LOOP
        RETURN QUERY SELECT
            'PAGOS'::TEXT,
            v_resultado.registros_creados,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_inicio))::NUMERIC;
    END LOOP;

    RAISE NOTICE '====== GENERACIÓN DE DATOS COMPLETADA ======';

    -- Refrescar vistas materializadas
    RAISE NOTICE 'Actualizando vistas materializadas...';
    PERFORM refrescar_vistas_materializadas();

END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FIN DE FUNCIONES DE GENERACIÓN DE DATOS
-- ============================================================================
