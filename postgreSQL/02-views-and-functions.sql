-- ============================================================================
-- VISTAS Y FUNCIONES ANALÍTICAS PARA DASHBOARDS
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- VISTAS: ANÁLISIS DE VENTAS
-- ============================================================================

-- Vista: Resumen diario de ventas
CREATE OR REPLACE VIEW v_daily_sales_summary AS
SELECT
    DATE(o.order_date) as sales_date,
    COUNT(DISTINCT o.id) as orders_count,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    COUNT(DISTINCT o.salesperson_id) as salespeople_involved,
    
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    MIN(o.total_amount) as min_order,
    MAX(o.total_amount) as max_order,
    
    SUM(o.subtotal) as subtotal_sum,
    SUM(o.discount_amount) as total_discounts,
    SUM(o.tax_amount) as total_taxes,
    SUM(o.shipping_cost) as total_shipping,
    
    COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as delivered_orders,
    COUNT(CASE WHEN o.status = 'cancelled' THEN 1 END) as cancelled_orders,
    COUNT(CASE WHEN o.payment_status = 'paid' THEN 1 END) as paid_orders,
    COUNT(CASE WHEN o.payment_status = 'pending' THEN 1 END) as pending_payment_orders
    
FROM orders o
WHERE o.order_date >= CURRENT_DATE - INTERVAL '2 years'
GROUP BY DATE(o.order_date)
ORDER BY sales_date DESC;

-- Vista: Ventas por categoría de producto
CREATE OR REPLACE VIEW v_sales_by_category AS
SELECT
    p.category,
    p.subcategory,
    COUNT(DISTINCT o.id) as orders_count,
    COUNT(DISTINCT oi.id) as items_sold,
    SUM(oi.quantity) as total_quantity,
    
    SUM(oi.line_total) as total_revenue,
    AVG(oi.unit_price) as avg_unit_price,
    
    SUM(oi.quantity * p.cost_price) as total_cost,
    SUM(oi.line_total) - SUM(oi.quantity * p.cost_price) as gross_profit,
    ROUND(
        100.0 * (SUM(oi.line_total) - SUM(oi.quantity * p.cost_price)) / NULLIF(SUM(oi.line_total), 0),
        2
    ) as profit_margin_percent,
    
    COUNT(DISTINCT o.customer_id) as unique_customers,
    SUM(oi.returned_quantity) as returned_items
    
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE o.status != 'cancelled'
GROUP BY p.category, p.subcategory
ORDER BY total_revenue DESC;

-- Vista: Performance de vendedores
CREATE OR REPLACE VIEW v_salesperson_performance AS
SELECT
    sp.id,
    sp.uuid,
    sp.name,
    sp.team,
    sp.territory,
    sp.quota_monthly,
    
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    
    SUM(o.total_amount) as total_sales,
    AVG(o.total_amount) as avg_order_value,
    
    SUM(o.total_amount) - SUM(o.total_amount * sp.commission_rate / 100) as net_sales,
    SUM(o.total_amount * sp.commission_rate / 100) as commission_amount,
    
    COUNT(DISTINCT DATE(o.order_date)) as active_sales_days,
    
    COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as delivered_orders,
    COUNT(CASE WHEN o.status = 'cancelled' THEN 1 END) as cancelled_orders,
    COUNT(CASE WHEN o.payment_status = 'pending' THEN 1 END) as unpaid_orders,
    
    -- Comparación con cuota (último mes)
    SUM(CASE 
        WHEN DATE_TRUNC('month', o.order_date) = DATE_TRUNC('month', CURRENT_DATE)
        THEN o.total_amount 
        ELSE 0 
    END) as month_sales,
    
    ROUND(
        100.0 * SUM(CASE 
            WHEN DATE_TRUNC('month', o.order_date) = DATE_TRUNC('month', CURRENT_DATE)
            THEN o.total_amount 
            ELSE 0 
        END) / NULLIF(sp.quota_monthly, 0),
        2
    ) as quota_achievement_percent,
    
    MAX(o.order_date) as last_sale_date,
    CURRENT_DATE - MAX(o.order_date)::DATE as days_since_last_sale
    
FROM salespeople sp
LEFT JOIN orders o ON sp.id = o.salesperson_id AND o.status != 'cancelled'
WHERE sp.is_active = TRUE
GROUP BY sp.id, sp.uuid, sp.name, sp.team, sp.territory, sp.quota_monthly, sp.commission_rate
ORDER BY total_sales DESC;

-- Vista: Segmentación de clientes
CREATE OR REPLACE VIEW v_customer_segmentation AS
SELECT
    c.id,
    c.uuid,
    c.name,
    c.segment,
    c.industry,
    c.company_size,
    c.country,
    
    COUNT(DISTINCT o.id) as total_orders,
    SUM(o.total_amount) as lifetime_value,
    AVG(o.total_amount) as avg_order_value,
    MAX(o.order_date) as last_purchase_date,
    CURRENT_DATE - MAX(o.order_date)::DATE as days_since_last_purchase,
    
    DATE(MAX(o.order_date)) - DATE(MIN(o.order_date)) as customer_lifespan_days,
    ROUND(
        COUNT(DISTINCT o.id)::NUMERIC / 
        GREATEST(1, (CURRENT_DATE - DATE(MIN(o.order_date))) / 30),
        2
    ) as orders_per_month,
    
    COUNT(DISTINCT DATE_TRUNC('month', o.order_date)) as active_months,
    
    COUNT(CASE WHEN o.status = 'cancelled' THEN 1 END) as cancelled_orders,
    COUNT(CASE WHEN o.payment_status != 'paid' THEN 1 END) as unpaid_orders,
    
    COUNT(DISTINCT ci.id) as total_interactions,
    MAX(ci.interaction_date) as last_interaction_date
    
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
LEFT JOIN customer_interactions ci ON c.id = ci.customer_id
WHERE c.is_active = TRUE
GROUP BY c.id, c.uuid, c.name, c.segment, c.industry, c.company_size, c.country
ORDER BY lifetime_value DESC;

-- Vista: Análisis de devoluciones
CREATE OR REPLACE VIEW v_returns_analysis AS
SELECT
    DATE(r.return_date) as return_date,
    p.category,
    p.subcategory,
    
    COUNT(DISTINCT r.id) as returns_count,
    SUM(r.refund_amount) as total_refunded,
    
    COUNT(DISTINCT r.order_id) as unique_orders_with_returns,
    COUNT(DISTINCT r.order_id) * 1.0 / (
        SELECT COUNT(DISTINCT id) FROM orders 
        WHERE DATE(order_date) = DATE(r.return_date)
    ) as return_rate_percent,
    
    COUNT(CASE WHEN r.status = 'approved' THEN 1 END) as approved_returns,
    COUNT(CASE WHEN r.status = 'pending' THEN 1 END) as pending_returns,
    COUNT(CASE WHEN r.status = 'rejected' THEN 1 END) as rejected_returns,
    
    r.reason
    
FROM returns r
JOIN orders o ON r.order_id = o.id
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.id
WHERE r.return_date >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY DATE(r.return_date), p.category, p.subcategory, r.reason
ORDER BY return_date DESC;

-- Vista: Análisis de flujo de pagos
CREATE OR REPLACE VIEW v_payment_analysis AS
SELECT
    DATE(p.payment_date) as payment_date,
    p.payment_method,
    
    COUNT(DISTINCT p.id) as payments_count,
    COUNT(DISTINCT p.order_id) as orders_paid,
    SUM(p.amount) as total_collected,
    AVG(p.amount) as avg_payment,
    
    COUNT(CASE WHEN p.status = 'completed' THEN 1 END) as successful_payments,
    COUNT(CASE WHEN p.status = 'failed' THEN 1 END) as failed_payments,
    COUNT(CASE WHEN p.status = 'refunded' THEN 1 END) as refunded_payments,
    
    -- Análisis de atrasos
    COUNT(DISTINCT CASE 
        WHEN (o.order_date + INTERVAL '30 days') < p.payment_date THEN o.id 
    END) as late_payments_30,
    
    COUNT(DISTINCT CASE 
        WHEN (o.order_date + INTERVAL '60 days') < p.payment_date THEN o.id 
    END) as late_payments_60
    
FROM payments p
JOIN orders o ON p.order_id = o.id
WHERE p.payment_date >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY DATE(p.payment_date), p.payment_method
ORDER BY payment_date DESC;

-- Vista: Análisis de campañas
CREATE OR REPLACE VIEW v_campaign_performance AS
SELECT
    c.id,
    c.uuid,
    c.name,
    c.campaign_type,
    c.channel,
    c.start_date,
    c.end_date,
    
    c.budget,
    c.actual_spend,
    ROUND(100.0 * c.actual_spend / NULLIF(c.budget, 0), 2) as spend_percent_of_budget,
    
    c.impressions,
    c.clicks,
    c.conversions,
    c.revenue_generated,
    
    ROUND(100.0 * c.clicks / NULLIF(c.impressions, 0), 2) as ctr_percent,
    ROUND(100.0 * c.conversions / NULLIF(c.clicks, 0), 2) as conversion_rate_percent,
    
    CASE 
        WHEN c.actual_spend > 0 
        THEN ROUND(c.revenue_generated / c.actual_spend, 2)
        ELSE 0 
    END as roi,
    
    CASE 
        WHEN c.conversions > 0 
        THEN ROUND(c.actual_spend / c.conversions, 2)
        ELSE 0 
    END as cost_per_conversion,
    
    COUNT(DISTINCT cc.customer_id) as total_customers_targeted,
    COUNT(DISTINCT CASE WHEN cc.contacted_date IS NOT NULL THEN cc.customer_id END) as customers_contacted,
    COUNT(DISTINCT CASE WHEN cc.converted = TRUE THEN cc.customer_id END) as customers_converted
    
FROM campaigns c
LEFT JOIN campaign_customers cc ON c.id = cc.campaign_id
WHERE c.start_date >= CURRENT_DATE - INTERVAL '2 years'
GROUP BY c.id, c.uuid, c.name, c.campaign_type, c.channel, c.start_date, c.end_date, 
         c.budget, c.actual_spend, c.impressions, c.clicks, c.conversions, c.revenue_generated
ORDER BY c.start_date DESC;

-- ============================================================================
-- VISTAS MATERIALIZADAS (para mejor performance)
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_sales_trend AS
SELECT
    DATE_TRUNC('month', o.order_date)::DATE as month,
    EXTRACT(YEAR FROM o.order_date)::INT as year,
    EXTRACT(MONTH FROM o.order_date)::INT as month_num,
    
    COUNT(DISTINCT o.id) as orders,
    COUNT(DISTINCT o.customer_id) as customers,
    SUM(o.total_amount) as revenue,
    AVG(o.total_amount) as avg_order_value,
    
    SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END) as delivered_revenue,
    SUM(CASE WHEN o.status = 'cancelled' THEN o.total_amount ELSE 0 END) as cancelled_revenue,
    
    SUM(o.total_amount) - SUM(COALESCE(oi.quantity * p.cost_price, 0)) as gross_profit
    
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.id
WHERE o.status != 'cancelled'
GROUP BY DATE_TRUNC('month', o.order_date), EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
ORDER BY month DESC;

CREATE INDEX idx_mv_monthly_sales_month ON mv_monthly_sales_trend(month);

-- Vista materializada: Top productos por categoría
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_top_products_by_category AS
SELECT
    p.category,
    p.id,
    p.uuid,
    p.name,
    p.sku,
    
    COUNT(DISTINCT oi.order_id) as times_ordered,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.line_total) as total_revenue,
    
    ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(oi.line_total) DESC) as category_rank
    
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.id AND o.status != 'cancelled'
WHERE p.is_active = TRUE
GROUP BY p.category, p.id, p.uuid, p.name, p.sku
ORDER BY p.category, total_revenue DESC;

-- ============================================================================
-- FUNCIONES ANALÍTICAS
-- ============================================================================

-- Función: Calcular ARR (Annual Recurring Revenue)
CREATE OR REPLACE FUNCTION calculate_arr(
    p_period_months INT DEFAULT 12
)
RETURNS TABLE (
    segment VARCHAR,
    monthly_revenue NUMERIC,
    annual_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.segment,
        ROUND(AVG(monthly_sales), 2) as monthly_revenue,
        ROUND(AVG(monthly_sales) * 12, 2) as annual_revenue
    FROM (
        SELECT
            c2.segment,
            DATE_TRUNC('month', o.order_date)::DATE as month,
            SUM(o.total_amount) as monthly_sales
        FROM orders o
        JOIN customers c2 ON o.customer_id = c2.id
        WHERE o.order_date >= CURRENT_DATE - (p_period_months || ' months')::INTERVAL
        AND o.status != 'cancelled'
        GROUP BY c2.segment, DATE_TRUNC('month', o.order_date)
    ) t
    GROUP BY segment
    ORDER BY annual_revenue DESC;
END;
$$ LANGUAGE plpgsql;

-- Función: Calcular churn de clientes
CREATE OR REPLACE FUNCTION calculate_churn(
    p_period_days INT DEFAULT 90
)
RETURNS TABLE (
    segment VARCHAR,
    total_customers_start_period BIGINT,
    customers_churned BIGINT,
    churn_rate_percent NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH period_customers AS (
        SELECT DISTINCT c.id, c.segment
        FROM customers c
        JOIN orders o ON c.id = o.customer_id
        WHERE o.order_date >= CURRENT_DATE - (p_period_days || ' days')::INTERVAL
        AND o.status != 'cancelled'
    ),
    churned_customers AS (
        SELECT DISTINCT c.id, c.segment
        FROM customers c
        WHERE c.id NOT IN (
            SELECT DISTINCT c2.id
            FROM customers c2
            JOIN orders o ON c2.id = o.customer_id
            WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
            AND o.status != 'cancelled'
        )
        AND c.id IN (
            SELECT DISTINCT c3.id
            FROM customers c3
            JOIN orders o ON c3.id = o.customer_id
            WHERE o.order_date >= CURRENT_DATE - (p_period_days || ' days')::INTERVAL
            AND o.status != 'cancelled'
        )
    )
    SELECT
        pc.segment,
        COUNT(DISTINCT pc.id) as total_customers_start_period,
        COUNT(DISTINCT cc.id) as customers_churned,
        ROUND(100.0 * COUNT(DISTINCT cc.id) / NULLIF(COUNT(DISTINCT pc.id), 0), 2) as churn_rate_percent
    FROM period_customers pc
    LEFT JOIN churned_customers cc ON pc.id = cc.id
    GROUP BY pc.segment
    ORDER BY churn_rate_percent DESC;
END;
$$ LANGUAGE plpgsql;

-- Función: Forecast simple de ventas (tendencia)
CREATE OR REPLACE FUNCTION forecast_sales(
    p_forecast_months INT DEFAULT 3,
    p_history_months INT DEFAULT 12
)
RETURNS TABLE (
    forecast_month DATE,
    forecasted_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH historical_data AS (
        SELECT
            DATE_TRUNC('month', o.order_date)::DATE as month,
            SUM(o.total_amount) as revenue,
            ROW_NUMBER() OVER (ORDER BY DATE_TRUNC('month', o.order_date)) as month_seq
        FROM orders o
        WHERE o.order_date >= CURRENT_DATE - (p_history_months || ' months')::INTERVAL
        AND o.status != 'cancelled'
        GROUP BY DATE_TRUNC('month', o.order_date)
    ),
    trend AS (
        SELECT
            REGR_SLOPE(revenue, month_seq) as slope,
            REGR_INTERCEPT(revenue, month_seq) as intercept,
            MAX(month_seq) as last_seq,
            MAX(month) as last_month
        FROM historical_data
    )
    SELECT
        (t.last_month + (n || ' months')::INTERVAL)::DATE as forecast_month,
        GREATEST(0, ROUND(t.intercept + t.slope * (t.last_seq + n), 2)) as forecasted_revenue
    FROM trend t
    CROSS JOIN GENERATE_SERIES(1, p_forecast_months) n
    WHERE t.slope IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Función: Análisis de cohortes
CREATE OR REPLACE FUNCTION cohort_analysis(
    p_metric VARCHAR DEFAULT 'revenue'  -- 'revenue', 'orders', 'retention'
)
RETURNS TABLE (
    cohort_month DATE,
    months_since_first_order INT,
    metric_value NUMERIC,
    customer_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH customer_cohorts AS (
        SELECT
            c.id,
            DATE_TRUNC('month', MIN(o.order_date))::DATE as cohort_month,
            DATE_TRUNC('month', o.order_date)::DATE as order_month
        FROM customers c
        JOIN orders o ON c.id = o.customer_id
        WHERE o.status != 'cancelled'
        GROUP BY c.id, DATE_TRUNC('month', o.order_date)
    ),
    cohort_with_metrics AS (
        SELECT
            cc.cohort_month,
            EXTRACT(MONTH FROM cc.order_month - cc.cohort_month)::INT / 1 as months_since,
            CASE p_metric
                WHEN 'revenue' THEN SUM(o.total_amount)
                WHEN 'orders' THEN COUNT(DISTINCT o.id)
                ELSE COUNT(DISTINCT cc.id)
            END as metric,
            COUNT(DISTINCT cc.id) as customers
        FROM customer_cohorts cc
        JOIN orders o ON cc.id = o.customer_id AND DATE_TRUNC('month', o.order_date) = cc.order_month
        WHERE o.status != 'cancelled'
        GROUP BY cc.cohort_month, EXTRACT(MONTH FROM cc.order_month - cc.cohort_month)
    )
    SELECT
        cohort_month,
        months_since,
        ROUND(metric, 2),
        customers
    FROM cohort_with_metrics
    WHERE months_since >= 0
    ORDER BY cohort_month DESC, months_since ASC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ACTUALIZAR VISTAS MATERIALIZADAS
-- ============================================================================

CREATE OR REPLACE FUNCTION refresh_all_materialized_views()
RETURNS TABLE (view_name TEXT, status TEXT, refresh_time INTERVAL) AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_view_name TEXT;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales_trend;
    v_end_time := CURRENT_TIMESTAMP;
    RETURN QUERY SELECT 'mv_monthly_sales_trend'::TEXT, 'completed'::TEXT, (v_end_time - v_start_time);
    
    v_start_time := CURRENT_TIMESTAMP;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_products_by_category;
    v_end_time := CURRENT_TIMESTAMP;
    RETURN QUERY SELECT 'mv_top_products_by_category'::TEXT, 'completed'::TEXT, (v_end_time - v_start_time);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FIN DE VISTAS Y FUNCIONES ANALÍTICAS
-- ============================================================================
