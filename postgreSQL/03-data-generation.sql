-- ============================================================================
-- FUNCIONES DE GENERACIÓN DE DATOS REALISTAS
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- FUNCIONES AUXILIARES
-- ============================================================================

-- Función: Generar nombres realistas
CREATE OR REPLACE FUNCTION generate_random_name(p_gender CHAR DEFAULT 'M')
RETURNS VARCHAR AS $$
DECLARE
    v_first_names_m VARCHAR[] := ARRAY[
        'Carlos', 'Miguel', 'Juan', 'Luis', 'Pedro', 'Roberto', 'Antonio', 'Diego',
        'Francisco', 'García', 'López', 'Martínez', 'Rodríguez', 'Hernández', 'González'
    ];
    v_first_names_f VARCHAR[] := ARRAY[
        'María', 'Carmen', 'Rosa', 'Isabel', 'Josefina', 'Ana', 'Francisca', 'Dolores',
        'Catalina', 'Antonia', 'Montserrat', 'Pilar', 'Virtudes', 'Teresa'
    ];
    v_last_names VARCHAR[] := ARRAY[
        'García', 'Martínez', 'Rodríguez', 'López', 'Hernández', 'González', 'Pérez',
        'Sánchez', 'Ramirez', 'Torres', 'Flores', 'Rivera', 'Gómez', 'Díaz', 'Reyes'
    ];
BEGIN
    RETURN 
        CASE 
            WHEN p_gender = 'F' THEN 
                v_first_names_f[((RANDOM() * (ARRAY_LENGTH(v_first_names_f, 1) - 1))::INT) + 1] || ' ' ||
                v_last_names[((RANDOM() * (ARRAY_LENGTH(v_last_names, 1) - 1))::INT) + 1]
            ELSE 
                v_first_names_m[((RANDOM() * (ARRAY_LENGTH(v_first_names_m, 1) - 1))::INT) + 1] || ' ' ||
                v_last_names[((RANDOM() * (ARRAY_LENGTH(v_last_names, 1) - 1))::INT) + 1]
        END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Función: Generar email
CREATE OR REPLACE FUNCTION generate_random_email(p_name VARCHAR)
RETURNS VARCHAR AS $$
BEGIN
    RETURN LOWER(REPLACE(REPLACE(p_name, ' ', '.'), 'ó', 'o') || '@' || 
        CASE ((RANDOM() * 5)::INT)
            WHEN 0 THEN 'gmail.com'
            WHEN 1 THEN 'yahoo.com'
            WHEN 2 THEN 'outlook.com'
            WHEN 3 THEN 'empresa.com'
            ELSE 'mail.com'
        END);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Función: Generar número de teléfono
CREATE OR REPLACE FUNCTION generate_random_phone()
RETURNS VARCHAR AS $$
BEGIN
    RETURN '+34 ' || 
        CASE ((RANDOM() * 3)::INT)
            WHEN 0 THEN '91'
            WHEN 1 THEN '93'
            ELSE '96'
        END || ' ' ||
        LPAD(((RANDOM() * 99999999)::BIGINT)::TEXT, 8, '0');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Función: Generar nombres de ciudades
CREATE OR REPLACE FUNCTION get_random_city()
RETURNS VARCHAR[] AS $$
BEGIN
    RETURN ARRAY[
        'Madrid', 'Barcelona', 'Valencia', 'Sevilla', 'Bilbao',
        'Alicante', 'Córdoba', 'Murcia', 'Palma', 'Las Palmas'
    ][((RANDOM() * 10)::INT) + 1]::VARCHAR[];
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- FUNCIÓN PRINCIPAL: GENERAR CLIENTES
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_customers(
    p_count INT DEFAULT 500,
    p_clean BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    created_count INT,
    status TEXT
) AS $$
DECLARE
    v_i INT := 0;
    v_name VARCHAR;
    v_email VARCHAR;
    v_segment VARCHAR;
    v_industry_val VARCHAR;
    v_company_size VARCHAR;
    v_city VARCHAR;
    v_country_val VARCHAR;
    
    v_segments VARCHAR[] := ARRAY['premium', 'standard', 'trial', 'vip', 'inactive'];
    v_industries VARCHAR[] := ARRAY['Technology', 'Finance', 'Healthcare', 'Retail', 'Manufacturing', 'Education', 'Consulting', 'Energy'];
    v_company_sizes VARCHAR[] := ARRAY['startup', 'small', 'medium', 'large', 'enterprise'];
    v_countries VARCHAR[] := ARRAY['Spain', 'Portugal', 'France', 'Italy', 'UK'];
    v_states VARCHAR[] := ARRAY['Madrid', 'Barcelona', 'Catalonia', 'Basque', 'Valencia', 'Andalusia'];
BEGIN
    IF p_clean THEN
        DELETE FROM customers;
        RAISE NOTICE 'Tabla customers limpiada';
    END IF;
    
    WHILE v_i < p_count LOOP
        v_name := generate_random_name(CASE WHEN RANDOM() > 0.5 THEN 'M' ELSE 'F' END);
        v_email := generate_random_email(v_name);
        
        v_segment := v_segments[((RANDOM() * (ARRAY_LENGTH(v_segments, 1) - 1))::INT) + 1];
        v_industry_val := v_industries[((RANDOM() * (ARRAY_LENGTH(v_industries, 1) - 1))::INT) + 1];
        v_company_size := v_company_sizes[((RANDOM() * (ARRAY_LENGTH(v_company_size, 1) - 1))::INT) + 1];
        v_country_val := v_countries[((RANDOM() * (ARRAY_LENGTH(v_countries, 1) - 1))::INT) + 1];
        v_states := ARRAY['Madrid', 'Barcelona', 'Catalonia', 'Basque', 'Valencia', 'Andalusia'];
        
        INSERT INTO customers (
            name, email, phone, segment, industry, company_size,
            country, state, city, postal_code,
            credit_limit, acquisition_date, is_active
        ) VALUES (
            v_name,
            v_email,
            generate_random_phone(),
            v_segment,
            v_industry_val,
            v_company_size,
            v_country_val,
            v_states[((RANDOM() * (ARRAY_LENGTH(v_states, 1) - 1))::INT) + 1],
            (ARRAY['Madrid', 'Barcelona', 'Valencia', 'Sevilla', 'Bilbao', 'Alicante', 'Córdoba', 'Murcia', 'Palma', 'Las Palmas'])[((RANDOM() * 10)::INT) + 1],
            LPAD(((RANDOM() * 99999)::INT)::TEXT, 5, '0'),
            (10000 + RANDOM() * 990000)::NUMERIC(10, 2),
            CURRENT_TIMESTAMP - ((RANDOM() * 365)::INT || ' days')::INTERVAL,
            CASE WHEN v_segment = 'inactive' THEN FALSE ELSE TRUE END
        );
        
        v_i := v_i + 1;
        
        IF v_i % 100 = 0 THEN
            RAISE NOTICE 'Generados % clientes', v_i;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_i, 'completed'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN: GENERAR PRODUCTOS
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_products(
    p_count INT DEFAULT 200,
    p_clean BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    created_count INT,
    status TEXT
) AS $$
DECLARE
    v_i INT := 0;
    v_category VARCHAR;
    v_subcategory VARCHAR;
    v_brand VARCHAR;
    
    v_categories VARCHAR[] := ARRAY['Electronics', 'Software', 'Services', 'Hardware', 'Consulting'];
    v_electronics_sub VARCHAR[] := ARRAY['Laptops', 'Tablets', 'Accessories', 'Monitors', 'Storage'];
    v_software_sub VARCHAR[] := ARRAY['Database', 'CRM', 'ERP', 'Analytics', 'Security'];
    v_services_sub VARCHAR[] := ARRAY['Support', 'Training', 'Implementation', 'Maintenance', 'Consulting'];
    v_brands VARCHAR[] := ARRAY['TechCorp', 'InnovateTech', 'SoftWare Pro', 'CloudSys', 'DataFlow', 'SecureIT'];
BEGIN
    IF p_clean THEN
        DELETE FROM products;
        RAISE NOTICE 'Tabla products limpiada';
    END IF;
    
    WHILE v_i < p_count LOOP
        v_category := v_categories[((RANDOM() * (ARRAY_LENGTH(v_categories, 1) - 1))::INT) + 1];
        
        v_subcategory := CASE v_category
            WHEN 'Electronics' THEN v_electronics_sub[((RANDOM() * (ARRAY_LENGTH(v_electronics_sub, 1) - 1))::INT) + 1]
            WHEN 'Software' THEN v_software_sub[((RANDOM() * (ARRAY_LENGTH(v_software_sub, 1) - 1))::INT) + 1]
            WHEN 'Services' THEN v_services_sub[((RANDOM() * (ARRAY_LENGTH(v_services_sub, 1) - 1))::INT) + 1]
            ELSE 'Other'
        END;
        
        v_brand := v_brands[((RANDOM() * (ARRAY_LENGTH(v_brands, 1) - 1))::INT) + 1];
        
        INSERT INTO products (
            name,
            sku,
            description,
            category,
            subcategory,
            brand,
            list_price,
            cost_price,
            current_stock,
            minimum_stock,
            weight_kg,
            volume_m3,
            is_digital,
            launch_date,
            is_active
        ) VALUES (
            v_brand || ' ' || v_subcategory || ' ' || v_i,
            'SKU-' || LPAD(v_i::TEXT, 6, '0'),
            'High quality ' || v_subcategory || ' from ' || v_brand,
            v_category,
            v_subcategory,
            v_brand,
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
    
    RETURN QUERY SELECT v_i, 'completed'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN: GENERAR VENDEDORES
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_salespeople(
    p_count INT DEFAULT 50,
    p_clean BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    created_count INT,
    status TEXT
) AS $$
DECLARE
    v_i INT := 0;
    v_name VARCHAR;
    v_team VARCHAR;
    v_territory VARCHAR;
    
    v_teams VARCHAR[] := ARRAY['Enterprise', 'SMB', 'Startup', 'Strategic'];
    v_territories VARCHAR[] := ARRAY['North', 'South', 'East', 'West', 'Central'];
BEGIN
    IF p_clean THEN
        DELETE FROM salespeople;
        RAISE NOTICE 'Tabla salespeople limpiada';
    END IF;
    
    WHILE v_i < p_count LOOP
        v_name := generate_random_name(CASE WHEN RANDOM() > 0.5 THEN 'M' ELSE 'F' END);
        v_team := v_teams[((RANDOM() * (ARRAY_LENGTH(v_teams, 1) - 1))::INT) + 1];
        v_territory := v_territories[((RANDOM() * (ARRAY_LENGTH(v_territories, 1) - 1))::INT) + 1];
        
        INSERT INTO salespeople (
            name,
            email,
            phone,
            team,
            territory,
            manager_id,
            commission_rate,
            quota_monthly,
            is_active,
            hire_date
        ) VALUES (
            v_name,
            generate_random_email(v_name),
            generate_random_phone(),
            v_team,
            v_territory,
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
    
    RETURN QUERY SELECT v_i, 'completed'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN: GENERAR ÓRDENES Y ITEMS
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_orders(
    p_orders_count INT DEFAULT 5000,
    p_days_back INT DEFAULT 365,
    p_clean BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    orders_created INT,
    items_created INT,
    status TEXT
) AS $$
DECLARE
    v_order_count INT := 0;
    v_items_count INT := 0;
    v_order_id BIGINT;
    v_customer_id BIGINT;
    v_salesperson_id BIGINT;
    v_product_id BIGINT;
    v_quantity INT;
    v_unit_price NUMERIC(10, 2);
    v_discount_percent NUMERIC(5, 2);
    v_order_date TIMESTAMP;
    v_items_per_order INT;
    v_item_i INT;
    v_total_customers BIGINT;
    v_total_products BIGINT;
    v_total_salespeople BIGINT;
    v_status VARCHAR;
    v_payment_status VARCHAR;
    
    v_statuses VARCHAR[] := ARRAY['pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'returned'];
    v_payment_statuses VARCHAR[] := ARRAY['pending', 'partial', 'paid', 'overdue', 'refunded'];
BEGIN
    IF p_clean THEN
        DELETE FROM order_items;
        DELETE FROM orders;
        RAISE NOTICE 'Tablas de órdenes limpiadas';
    END IF;
    
    -- Obtener conteos
    SELECT COUNT(*) INTO v_total_customers FROM customers WHERE is_active = TRUE;
    SELECT COUNT(*) INTO v_total_products FROM products WHERE is_active = TRUE;
    SELECT COUNT(*) INTO v_total_salespeople FROM salespeople WHERE is_active = TRUE;
    
    RAISE NOTICE 'Generando % órdenes usando % clientes, % productos, % vendedores',
        p_orders_count, v_total_customers, v_total_products, v_total_salespeople;
    
    WHILE v_order_count < p_orders_count LOOP
        -- Seleccionar cliente aleatorio
        SELECT id INTO v_customer_id FROM customers 
        WHERE is_active = TRUE 
        ORDER BY RANDOM() LIMIT 1;
        
        -- Seleccionar vendedor (puede ser NULL)
        IF RANDOM() > 0.2 THEN
            SELECT id INTO v_salesperson_id FROM salespeople 
            WHERE is_active = TRUE 
            ORDER BY RANDOM() LIMIT 1;
        ELSE
            v_salesperson_id := NULL;
        END IF;
        
        -- Fecha aleatoria
        v_order_date := CURRENT_TIMESTAMP - ((RANDOM() * p_days_back)::INT || ' days')::INTERVAL;
        
        -- Estados con distribución realista
        v_status := CASE 
            WHEN RANDOM() < 0.05 THEN 'cancelled'
            WHEN RANDOM() < 0.10 THEN 'pending'
            WHEN RANDOM() < 0.15 THEN 'confirmed'
            WHEN RANDOM() < 0.20 THEN 'processing'
            WHEN RANDOM() < 0.30 THEN 'shipped'
            ELSE 'delivered'
        END;
        
        v_payment_status := CASE v_status
            WHEN 'delivered' THEN v_payment_statuses[((RANDOM() * (ARRAY_LENGTH(v_payment_statuses, 1) - 1))::INT) + 1]
            WHEN 'cancelled' THEN 'refunded'
            ELSE 'pending'
        END;
        
        -- Insertar orden
        INSERT INTO orders (
            customer_id,
            salesperson_id,
            order_date,
            promised_delivery_date,
            status,
            payment_status,
            payment_method,
            tax_amount,
            shipping_cost,
            discount_percent,
            created_by
        ) VALUES (
            v_customer_id,
            v_salesperson_id,
            v_order_date,
            v_order_date::DATE + INTERVAL '5 days',
            v_status,
            v_payment_status,
            ARRAY['credit_card', 'bank_transfer', 'cash', 'check'][((RANDOM() * 3)::INT) + 1],
            (50 + RANDOM() * 450)::NUMERIC(15, 2),
            (10 + RANDOM() * 90)::NUMERIC(15, 2),
            CASE WHEN RANDOM() > 0.7 THEN (5 + RANDOM() * 20)::NUMERIC(5, 2) ELSE 0 END,
            'system'
        ) RETURNING id INTO v_order_id;
        
        -- Generar items para esta orden (1-8 items)
        v_items_per_order := ((RANDOM() * 7)::INT) + 1;
        v_item_i := 0;
        
        WHILE v_item_i < v_items_per_order LOOP
            -- Seleccionar producto aleatorio
            SELECT id, list_price INTO v_product_id, v_unit_price FROM products 
            WHERE is_active = TRUE 
            ORDER BY RANDOM() LIMIT 1;
            
            v_quantity := ((RANDOM() * 10)::INT) + 1;
            v_discount_percent := CASE WHEN RANDOM() > 0.7 THEN RANDOM() * 20 ELSE 0 END;
            
            INSERT INTO order_items (
                order_id,
                product_id,
                quantity,
                unit_price,
                discount_percent,
                fulfilled,
                returned_quantity
            ) VALUES (
                v_order_id,
                v_product_id,
                v_quantity,
                v_unit_price,
                v_discount_percent,
                CASE WHEN v_status IN ('delivered', 'shipped') THEN TRUE ELSE FALSE END,
                CASE WHEN v_status = 'returned' AND RANDOM() > 0.5 THEN ((RANDOM() * v_quantity)::INT) ELSE 0 END
            );
            
            v_items_count := v_items_count + 1;
            v_item_i := v_item_i + 1;
        END LOOP;
        
        v_order_count := v_order_count + 1;
        
        IF v_order_count % 500 = 0 THEN
            RAISE NOTICE 'Generadas % órdenes con % items', v_order_count, v_items_count;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_order_count, v_items_count, 'completed'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN: GENERAR PAGOS
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_payments(
    p_clean BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    created_count INT,
    status TEXT
) AS $$
DECLARE
    v_payment_count INT := 0;
    v_order_id BIGINT;
    v_total_amount NUMERIC(15, 2);
    v_payment_amount NUMERIC(15, 2);
    v_payment_method VARCHAR;
BEGIN
    IF p_clean THEN
        DELETE FROM payments;
        RAISE NOTICE 'Tabla payments limpiada';
    END IF;
    
    -- Generar pagos para órdenes pagadas o parcialmente pagadas
    FOR v_order_id, v_total_amount IN
        SELECT id, total_amount FROM orders 
        WHERE payment_status IN ('paid', 'partial', 'overdue')
        AND total_amount > 0
    LOOP
        v_payment_method := ARRAY['credit_card', 'bank_transfer', 'cash', 'check'][((RANDOM() * 3)::INT) + 1];
        
        IF RANDOM() > 0.3 THEN
            -- Pago completo
            v_payment_amount := v_total_amount;
        ELSE
            -- Pago parcial
            v_payment_amount := v_total_amount * (0.3 + RANDOM() * 0.7);
        END IF;
        
        INSERT INTO payments (
            order_id,
            amount,
            payment_method,
            payment_date,
            reference_number,
            status
        ) VALUES (
            v_order_id,
            v_payment_amount,
            v_payment_method,
            CURRENT_TIMESTAMP - ((RANDOM() * 365)::INT || ' days')::INTERVAL,
            'REF-' || LPAD(((RANDOM() * 999999)::BIGINT)::TEXT, 8, '0'),
            'completed'
        );
        
        v_payment_count := v_payment_count + 1;
    END LOOP;
    
    RETURN QUERY SELECT v_payment_count, 'completed'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCIÓN: GENERAR TODAS LAS TABLAS DE DATOS
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_all_test_data(
    p_customers INT DEFAULT 500,
    p_products INT DEFAULT 200,
    p_salespeople INT DEFAULT 50,
    p_orders INT DEFAULT 5000,
    p_days_back INT DEFAULT 365
)
RETURNS TABLE (
    step TEXT,
    records_created INT,
    execution_time_seconds NUMERIC
) AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_result RECORD;
BEGIN
    RAISE NOTICE '====== INICIANDO GENERACIÓN DE DATOS DE PRUEBA ======';
    RAISE NOTICE 'Parámetros: Clientes=%, Productos=%, Vendedores=%, Órdenes=%',
        p_customers, p_products, p_salespeople, p_orders;
    
    -- Generar clientes
    v_start_time := CURRENT_TIMESTAMP;
    FOR v_result IN SELECT * FROM generate_customers(p_customers, TRUE) LOOP
        RETURN QUERY SELECT 
            'CUSTOMERS'::TEXT,
            v_result.created_count,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time))::NUMERIC;
    END LOOP;
    
    -- Generar productos
    v_start_time := CURRENT_TIMESTAMP;
    FOR v_result IN SELECT * FROM generate_products(p_products, TRUE) LOOP
        RETURN QUERY SELECT 
            'PRODUCTS'::TEXT,
            v_result.created_count,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time))::NUMERIC;
    END LOOP;
    
    -- Generar vendedores
    v_start_time := CURRENT_TIMESTAMP;
    FOR v_result IN SELECT * FROM generate_salespeople(p_salespeople, TRUE) LOOP
        RETURN QUERY SELECT 
            'SALESPEOPLE'::TEXT,
            v_result.created_count,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time))::NUMERIC;
    END LOOP;
    
    -- Generar órdenes
    v_start_time := CURRENT_TIMESTAMP;
    FOR v_result IN SELECT * FROM generate_orders(p_orders, p_days_back, TRUE) LOOP
        RETURN QUERY SELECT 
            'ORDERS & ITEMS'::TEXT,
            (v_result.orders_created + v_result.items_created),
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time))::NUMERIC;
    END LOOP;
    
    -- Generar pagos
    v_start_time := CURRENT_TIMESTAMP;
    FOR v_result IN SELECT * FROM generate_payments(TRUE) LOOP
        RETURN QUERY SELECT 
            'PAYMENTS'::TEXT,
            v_result.created_count,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_start_time))::NUMERIC;
    END LOOP;
    
    RAISE NOTICE '====== GENERACIÓN DE DATOS COMPLETADA ======';
    
    -- Llamar a refresh de vistas materializadas
    RAISE NOTICE 'Actualizando vistas materializadas...';
    PERFORM refresh_all_materialized_views();
    
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FIN DE FUNCIONES DE GENERACIÓN DE DATOS
-- ============================================================================
