-- ============================================================================
-- SALES TEST DATABASE SCHEMA
-- PostgreSQL 14+
-- ============================================================================
-- Este schema está diseñado para:
-- 1. Generar datos realistas de ventas
-- 2. Soportar análisis complejos en Power BI y dashboards custom
-- 3. Ser fácil de limpiar y resetear para pruebas
-- ============================================================================

-- EXTENSIONES REQUERIDAS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- DIMENSION: CLIENTES
-- ============================================================================
CREATE TABLE IF NOT EXISTS customers (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    
    -- Segmentación
    segment VARCHAR(50) NOT NULL DEFAULT 'standard',
        -- Valores: premium, standard, trial, vip, inactive
    industry VARCHAR(100),
    company_size VARCHAR(50),
        -- Valores: startup, small, medium, large, enterprise
    
    -- Ubicación
    country VARCHAR(100),
    state VARCHAR(100),
    city VARCHAR(100),
    postal_code VARCHAR(20),
    
    -- Información financiera
    credit_limit NUMERIC(15,2),
    total_lifetime_value NUMERIC(15,2) DEFAULT 0,
    
    -- Metadatos
    acquisition_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_purchase_date TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_segment ON customers(segment);
CREATE INDEX idx_customers_country ON customers(country);
CREATE INDEX idx_customers_is_active ON customers(is_active);
CREATE INDEX idx_customers_acquisition_date ON customers(acquisition_date);

-- ============================================================================
-- DIMENSION: PRODUCTOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS products (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    sku VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    
    -- Categorización
    category VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    brand VARCHAR(100),
    
    -- Precios
    list_price NUMERIC(10,2) NOT NULL,
    cost_price NUMERIC(10,2),
    
    -- Stock
    current_stock INT DEFAULT 0,
    minimum_stock INT DEFAULT 10,
    
    -- Propiedades
    weight_kg NUMERIC(8,2),
    volume_m3 NUMERIC(8,3),
    is_digital BOOLEAN DEFAULT FALSE,
    
    -- Ciclo de vida del producto
    launch_date DATE,
    discontinue_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_is_active ON products(is_active);
CREATE INDEX idx_products_brand ON products(brand);

-- ============================================================================
-- DIMENSION: VENDEDORES/REPRESENTANTES
-- ============================================================================
CREATE TABLE IF NOT EXISTS salespeople (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    
    -- Organización
    team VARCHAR(100),
    territory VARCHAR(100),
    manager_id BIGINT REFERENCES salespeople(id) ON DELETE SET NULL,
    
    -- Performance
    commission_rate NUMERIC(5,2) DEFAULT 0,
    quota_monthly NUMERIC(15,2),
    
    -- Estatus
    is_active BOOLEAN DEFAULT TRUE,
    hire_date DATE,
    termination_date DATE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_salespeople_team ON salespeople(team);
CREATE INDEX idx_salespeople_territory ON salespeople(territory);
CREATE INDEX idx_salespeople_is_active ON salespeople(is_active);

-- ============================================================================
-- HECHO: ÓRDENES DE VENTAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS orders (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    
    -- Foreign Keys
    customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    salesperson_id BIGINT REFERENCES salespeople(id) ON DELETE SET NULL,
    
    -- Fechas clave
    order_date TIMESTAMP NOT NULL,
    promised_delivery_date DATE,
    actual_delivery_date DATE,
    
    -- Montos
    subtotal NUMERIC(15,2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(15,2) DEFAULT 0,
    discount_percent NUMERIC(5,2) DEFAULT 0,
    tax_amount NUMERIC(15,2) DEFAULT 0,
    shipping_cost NUMERIC(15,2) DEFAULT 0,
    total_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
    
    -- Información de pago
    payment_method VARCHAR(50),
        -- Valores: credit_card, bank_transfer, cash, check, other
    payment_status VARCHAR(50) DEFAULT 'pending',
        -- Valores: pending, partial, paid, overdue, refunded
    payment_date TIMESTAMP,
    
    -- Estado de la orden
    status VARCHAR(50) DEFAULT 'pending',
        -- Valores: pending, confirmed, processing, shipped, delivered, cancelled, returned
    
    -- Notas
    notes TEXT,
    internal_notes TEXT,
    
    -- Auditoría
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100)
);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_salesperson_id ON orders(salesperson_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_orders_created_at ON orders(created_at);

-- ============================================================================
-- DETALLE: ITEMS DE ÓRDENES
-- ============================================================================
CREATE TABLE IF NOT EXISTS order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    
    -- Cantidad y precio
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL,
    discount_percent NUMERIC(5,2) DEFAULT 0,
    line_total NUMERIC(15,2) GENERATED ALWAYS AS 
        (quantity * unit_price * (1 - discount_percent / 100)) STORED,
    
    -- Control de inventario
    warehouse_location VARCHAR(100),
    fulfilled BOOLEAN DEFAULT FALSE,
    
    -- Devoluciones
    returned_quantity INT DEFAULT 0,
    return_reason VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_order_items_fulfilled ON order_items(fulfilled);

-- ============================================================================
-- TRANSACCIONES: PAGOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS payments (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    
    -- Monto
    amount NUMERIC(15,2) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Método
    payment_method VARCHAR(50) NOT NULL,
    reference_number VARCHAR(100),
    
    -- Estado
    status VARCHAR(50) DEFAULT 'completed',
        -- Valores: pending, completed, failed, refunded
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_payment_date ON payments(payment_date);
CREATE INDEX idx_payments_status ON payments(status);

-- ============================================================================
-- DEVOLUCIONES / REEMBOLSOS
-- ============================================================================
CREATE TABLE IF NOT EXISTS returns (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
    
    -- Información
    return_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reason VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Monto
    refund_amount NUMERIC(15,2) NOT NULL,
    refund_date TIMESTAMP,
    
    -- Estado
    status VARCHAR(50) DEFAULT 'pending',
        -- Valores: pending, approved, rejected, refunded, partial_refund
    
    approved_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_returns_order_id ON returns(order_id);
CREATE INDEX idx_returns_return_date ON returns(return_date);
CREATE INDEX idx_returns_status ON returns(status);

-- ============================================================================
-- CONTACTOS / INTERACCIONES
-- ============================================================================
CREATE TABLE IF NOT EXISTS customer_interactions (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    salesperson_id BIGINT REFERENCES salespeople(id) ON DELETE SET NULL,
    
    -- Tipo de interacción
    interaction_type VARCHAR(50) NOT NULL,
        -- Valores: call, email, meeting, demo, support, follow_up
    
    -- Contenido
    subject VARCHAR(255),
    notes TEXT,
    
    -- Resultado
    outcome VARCHAR(100),
        -- Valores: interested, not_interested, scheduled_demo, etc
    next_follow_up_date DATE,
    
    -- Metadatos
    interaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    duration_minutes INT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customer_interactions_customer_id ON customer_interactions(customer_id);
CREATE INDEX idx_customer_interactions_interaction_date ON customer_interactions(interaction_date);
CREATE INDEX idx_customer_interactions_salesperson_id ON customer_interactions(salesperson_id);

-- ============================================================================
-- CAMPAÑAS / MARKETING
-- ============================================================================
CREATE TABLE IF NOT EXISTS campaigns (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Tipo y canal
    campaign_type VARCHAR(100),
        -- Valores: email, webinar, trade_show, promotion, seasonal
    channel VARCHAR(50),
        -- Valores: email, social, direct_mail, events, referral, organic
    
    -- Período
    start_date DATE NOT NULL,
    end_date DATE,
    
    -- Presupuesto
    budget NUMERIC(15,2),
    actual_spend NUMERIC(15,2) DEFAULT 0,
    
    -- Performance
    impressions INT DEFAULT 0,
    clicks INT DEFAULT 0,
    conversions INT DEFAULT 0,
    revenue_generated NUMERIC(15,2) DEFAULT 0,
    
    status VARCHAR(50) DEFAULT 'active',
        -- Valores: planned, active, completed, cancelled
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_campaigns_start_date ON campaigns(start_date);
CREATE INDEX idx_campaigns_status ON campaigns(status);

-- ============================================================================
-- RELACIÓN: CLIENTES - CAMPAÑAS
-- ============================================================================
CREATE TABLE IF NOT EXISTS campaign_customers (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
    customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    
    -- Engagement
    contacted_date TIMESTAMP,
    opened BOOLEAN DEFAULT FALSE,
    clicked BOOLEAN DEFAULT FALSE,
    converted BOOLEAN DEFAULT FALSE,
    conversion_date TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_campaign_customer UNIQUE(campaign_id, customer_id)
);

CREATE INDEX idx_campaign_customers_campaign_id ON campaign_customers(campaign_id);
CREATE INDEX idx_campaign_customers_customer_id ON campaign_customers(customer_id);

-- ============================================================================
-- TABLAS DE AUDITORÍA/CONTROL
-- ============================================================================
CREATE TABLE IF NOT EXISTS data_loads (
    id BIGSERIAL PRIMARY KEY,
    load_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    load_type VARCHAR(100),
        -- Valores: initial, incremental, refresh, test
    records_affected INT,
    status VARCHAR(50),
    notes TEXT
);

-- ============================================================================
-- COMENTARIOS DE TABLAS Y COLUMNAS
-- ============================================================================
COMMENT ON TABLE customers IS 'Tabla de dimensión de clientes con información demográfica y de segmentación';
COMMENT ON TABLE products IS 'Tabla de dimensión de productos con categorización y precios';
COMMENT ON TABLE orders IS 'Tabla de hechos de órdenes de ventas';
COMMENT ON TABLE order_items IS 'Detalles de líneas en órdenes';
COMMENT ON TABLE payments IS 'Transacciones de pagos y cobros';
COMMENT ON TABLE returns IS 'Registro de devoluciones y reembolsos';
COMMENT ON COLUMN orders.total_amount IS 'Total final: subtotal - descuento + impuesto + envío';
COMMENT ON COLUMN order_items.line_total IS 'Generado automáticamente: cantidad * precio unitario * (1 - descuento%)';

-- ============================================================================
-- TRIGGERS PARA MANTENER INTEGRIDAD DE DATOS
-- ============================================================================

-- Actualizar total de órdenes cuando se agregan items
CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE orders
    SET total_amount = COALESCE(
        (SELECT SUM(line_total) FROM order_items WHERE order_id = NEW.order_id),
        0
    ) + COALESCE(tax_amount, 0) + COALESCE(shipping_cost, 0) - COALESCE(discount_amount, 0),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.order_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_order_total_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_order_total();

CREATE TRIGGER trg_update_order_total_after_update
AFTER UPDATE ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_order_total();

CREATE TRIGGER trg_update_order_total_after_delete
AFTER DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_order_total();

-- Actualizar lifetime value del cliente
CREATE OR REPLACE FUNCTION update_customer_lifetime_value()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE customers
    SET total_lifetime_value = COALESCE(
        (SELECT SUM(total_amount) FROM orders WHERE customer_id = NEW.customer_id AND status != 'cancelled'),
        0
    ),
        last_purchase_date = COALESCE(
            (SELECT MAX(order_date) FROM orders WHERE customer_id = NEW.customer_id AND status != 'cancelled'),
            last_purchase_date
        ),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.customer_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_customer_ltv
AFTER INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION update_customer_lifetime_value();

-- Registrar en data_loads
CREATE OR REPLACE FUNCTION log_data_load(
    p_load_type VARCHAR,
    p_records_affected INT,
    p_status VARCHAR DEFAULT 'completed',
    p_notes TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_load_id BIGINT;
BEGIN
    INSERT INTO data_loads (load_type, records_affected, status, notes)
    VALUES (p_load_type, p_records_affected, p_status, p_notes)
    RETURNING id INTO v_load_id;
    
    RETURN v_load_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FIN DEL SCHEMA
-- ============================================================================
