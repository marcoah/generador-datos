-- ============================================================================
-- QUERIES EJEMPLO PARA DASHBOARDS DE VENTAS
-- Optimizadas y listas para usar en Power BI, Vue.js, etc.
-- ============================================================================

-- ============================================================================
-- DASHBOARD PRINCIPAL (KPIs)
-- ============================================================================

-- Query 1: KPIs Principales del Mes
SELECT
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END) as delivered_revenue,
    SUM(CASE WHEN o.payment_status IN ('pending', 'overdue') THEN o.total_amount ELSE 0 END) as unpaid_amount,
    COUNT(CASE WHEN o.payment_status = 'paid' THEN 1 END) as paid_orders,
    COUNT(CASE WHEN o.status = 'cancelled' THEN 1 END) as cancelled_orders
FROM orders o
WHERE DATE_TRUNC('month', o.order_date) = DATE_TRUNC('month', CURRENT_DATE);

-- Query 2: Comparación Mes Actual vs Mes Anterior
WITH current_month AS (
    SELECT
        SUM(total_amount) as revenue,
        COUNT(*) as orders,
        COUNT(DISTINCT customer_id) as customers
    FROM orders
    WHERE DATE_TRUNC('month', order_date) = DATE_TRUNC('month', CURRENT_DATE)
),
previous_month AS (
    SELECT
        SUM(total_amount) as revenue,
        COUNT(*) as orders,
        COUNT(DISTINCT customer_id) as customers
    FROM orders
    WHERE DATE_TRUNC('month', order_date) = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
)
SELECT
    cm.revenue as current_revenue,
    pm.revenue as previous_revenue,
    ROUND(100.0 * (cm.revenue - pm.revenue) / NULLIF(pm.revenue, 0), 2) as revenue_growth_percent,
    cm.orders as current_orders,
    pm.orders as previous_orders,
    ROUND(100.0 * (cm.orders - pm.orders) / NULLIF(pm.orders, 0), 2) as orders_growth_percent
FROM current_month cm
CROSS JOIN previous_month pm;

-- Query 3: Tendencia Última Semana (por día)
SELECT
    DATE(o.order_date) as date,
    TO_CHAR(o.order_date, 'TMDay') as day_name,
    COUNT(*) as orders,
    SUM(o.total_amount) as revenue,
    AVG(o.total_amount) as avg_order_value,
    COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as delivered,
    COUNT(CASE WHEN o.payment_status = 'paid' THEN 1 END) as paid_orders
FROM orders o
WHERE o.order_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(o.order_date), TO_CHAR(o.order_date, 'TMDay')
ORDER BY DATE(o.order_date) DESC;

-- ============================================================================
-- ANÁLISIS DE VENDEDORES
-- ============================================================================

-- Query 4: Performance de Top 10 Vendedores (Mes Actual)
SELECT
    sp.name as salesperson_name,
    sp.team,
    sp.territory,
    sp.quota_monthly,
    COUNT(DISTINCT o.id) as orders,
    SUM(o.total_amount) as total_sales,
    ROUND(SUM(o.total_amount) / NULLIF(sp.quota_monthly, 0) * 100, 2) as quota_achievement_percent,
    ROUND(SUM(o.total_amount * sp.commission_rate / 100), 2) as commission_earned,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    MAX(o.order_date) as last_sale_date
FROM salespeople sp
LEFT JOIN orders o ON sp.id = o.salesperson_id 
    AND DATE_TRUNC('month', o.order_date) = DATE_TRUNC('month', CURRENT_DATE)
    AND o.status != 'cancelled'
WHERE sp.is_active = TRUE
GROUP BY sp.id, sp.name, sp.team, sp.territory, sp.quota_monthly, sp.commission_rate
ORDER BY total_sales DESC NULLS LAST
LIMIT 10;

-- Query 5: Comparativa de Vendedores (YTD vs Año Anterior)
WITH ytd_current AS (
    SELECT
        sp.id,
        sp.name,
        SUM(o.total_amount) as ytd_sales
    FROM salespeople sp
    LEFT JOIN orders o ON sp.id = o.salesperson_id
        AND DATE_TRUNC('year', o.order_date) = DATE_TRUNC('year', CURRENT_DATE)
        AND o.status != 'cancelled'
    WHERE sp.is_active = TRUE
    GROUP BY sp.id, sp.name
),
ytd_previous AS (
    SELECT
        sp.id,
        sp.name,
        SUM(o.total_amount) as ytd_sales
    FROM salespeople sp
    LEFT JOIN orders o ON sp.id = o.salesperson_id
        AND DATE_TRUNC('year', o.order_date) = DATE_TRUNC('year', CURRENT_DATE - INTERVAL '1 year')
        AND o.status != 'cancelled'
    WHERE sp.is_active = TRUE
    GROUP BY sp.id, sp.name
)
SELECT
    c.name,
    COALESCE(c.ytd_sales, 0) as ytd_current_sales,
    COALESCE(p.ytd_sales, 0) as ytd_previous_sales,
    ROUND(100.0 * (COALESCE(c.ytd_sales, 0) - COALESCE(p.ytd_sales, 0)) / NULLIF(COALESCE(p.ytd_sales, 1), 0), 2) as yoy_growth_percent
FROM ytd_current c
FULL OUTER JOIN ytd_previous p ON c.id = p.id
ORDER BY COALESCE(c.ytd_sales, 0) DESC;

-- ============================================================================
-- ANÁLISIS DE CLIENTES
-- ============================================================================

-- Query 6: Segmentación de Clientes (Top por Segment)
SELECT
    c.segment,
    COUNT(DISTINCT c.id) as total_customers,
    COUNT(DISTINCT o.id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    ROUND(AVG(o.total_amount), 2) as avg_order_value,
    ROUND(SUM(o.total_amount) / NULLIF(COUNT(DISTINCT c.id), 0), 2) as revenue_per_customer,
    COUNT(DISTINCT o.customer_id) as customers_with_orders,
    ROUND(100.0 * COUNT(DISTINCT o.customer_id) / NULLIF(COUNT(DISTINCT c.id), 0), 2) as conversion_percent
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id AND o.status != 'cancelled'
WHERE c.is_active = TRUE
GROUP BY c.segment
ORDER BY total_revenue DESC;

-- Query 7: Top 20 Clientes por Lifetime Value
SELECT
    c.id,
    c.name,
    c.segment,
    c.industry,
    c.country,
    COUNT(DISTINCT o.id) as total_orders,
    SUM(o.total_amount) as lifetime_value,
    ROUND(AVG(o.total_amount), 2) as avg_order_value,
    MAX(o.order_date) as last_purchase_date,
    CURRENT_DATE - MAX(o.order_date)::DATE as days_since_last_purchase,
    COUNT(CASE WHEN o.payment_status = 'paid' THEN 1 END) as paid_orders,
    COUNT(CASE WHEN o.payment_status IN ('pending', 'overdue') THEN 1 END) as unpaid_orders
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id AND o.status != 'cancelled'
WHERE c.is_active = TRUE
GROUP BY c.id, c.name, c.segment, c.industry, c.country
ORDER BY lifetime_value DESC
LIMIT 20;

-- Query 8: Clientes At-Risk (sin compras en últimos 90 días)
SELECT
    c.id,
    c.name,
    c.segment,
    c.total_lifetime_value,
    MAX(o.order_date) as last_purchase_date,
    CURRENT_DATE - MAX(o.order_date)::DATE as days_inactive,
    COUNT(DISTINCT o.id) as lifetime_orders,
    SUM(o.total_amount) as lifetime_spent
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE c.is_active = TRUE
GROUP BY c.id, c.name, c.segment, c.total_lifetime_value
HAVING MAX(o.order_date) < CURRENT_DATE - INTERVAL '90 days'
ORDER BY days_inactive DESC;

-- Query 9: Clientes Nuevos (últimos 30 días)
SELECT
    c.id,
    c.name,
    c.segment,
    c.industry,
    c.company_size,
    c.acquisition_date,
    COUNT(DISTINCT o.id) as orders_since_acquisition,
    SUM(o.total_amount) as initial_purchase_value,
    MAX(o.order_date) as first_order_date
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE c.acquisition_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY c.id, c.name, c.segment, c.industry, c.company_size, c.acquisition_date
ORDER BY c.acquisition_date DESC;

-- ============================================================================
-- ANÁLISIS DE PRODUCTOS
-- ============================================================================

-- Query 10: Top 20 Productos por Ingresos
SELECT
    p.id,
    p.name,
    p.sku,
    p.category,
    p.brand,
    p.list_price,
    p.cost_price,
    ROUND((p.list_price - p.cost_price) / p.list_price * 100, 2) as margin_percent,
    COUNT(DISTINCT oi.order_id) as times_ordered,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.line_total) as total_revenue,
    ROUND(SUM(oi.line_total) / NULLIF(SUM(oi.quantity), 0), 2) as avg_revenue_per_unit,
    ROUND(SUM(oi.quantity * p.cost_price), 2) as total_cost,
    ROUND(SUM(oi.line_total) - SUM(oi.quantity * p.cost_price), 2) as gross_profit,
    SUM(oi.returned_quantity) as total_returned
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.id AND o.status != 'cancelled'
WHERE p.is_active = TRUE
GROUP BY p.id, p.name, p.sku, p.category, p.brand, p.list_price, p.cost_price
ORDER BY total_revenue DESC
LIMIT 20;

-- Query 11: Productos sin Ventas (Oportunidad de Limpieza)
SELECT
    p.id,
    p.name,
    p.sku,
    p.category,
    p.brand,
    p.list_price,
    p.launch_date,
    CURRENT_DATE - p.launch_date::DATE as days_since_launch,
    p.current_stock,
    CASE
        WHEN p.launch_date > CURRENT_DATE - INTERVAL '90 days' THEN 'Nueva'
        WHEN p.discontinue_date IS NOT NULL THEN 'Descontinuada'
        ELSE 'Sin ventas'
    END as status_reason
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
WHERE p.is_active = TRUE
    AND oi.id IS NULL
ORDER BY p.launch_date DESC;

-- Query 12: Rendimiento por Categoría
SELECT
    p.category,
    COUNT(DISTINCT p.id) as product_count,
    COUNT(DISTINCT oi.order_id) as orders,
    SUM(oi.quantity) as items_sold,
    SUM(oi.line_total) as revenue,
    ROUND(AVG(oi.unit_price), 2) as avg_price,
    ROUND(SUM(oi.line_total) - SUM(oi.quantity * p.cost_price), 2) as gross_profit,
    ROUND(100.0 * (SUM(oi.line_total) - SUM(oi.quantity * p.cost_price)) / NULLIF(SUM(oi.line_total), 0), 2) as profit_margin_percent,
    ROUND(100.0 * SUM(oi.returned_quantity) / NULLIF(SUM(oi.quantity), 0), 2) as return_rate_percent
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.id AND o.status != 'cancelled'
WHERE p.is_active = TRUE
GROUP BY p.category
ORDER BY revenue DESC;

-- ============================================================================
-- ANÁLISIS DE PAGOS
-- ============================================================================

-- Query 13: Estado de Pagos (Resumen)
SELECT
    o.payment_status,
    COUNT(DISTINCT o.id) as order_count,
    SUM(o.total_amount) as amount_outstanding,
    AVG(o.total_amount) as avg_order_amount,
    MAX(o.order_date) as most_recent_order
FROM orders o
WHERE o.status != 'cancelled'
    AND o.payment_status IN ('pending', 'partial', 'overdue')
GROUP BY o.payment_status
ORDER BY amount_outstanding DESC;

-- Query 14: Órdenes Atrasadas en Pago (> 60 días)
SELECT
    o.id,
    o.uuid,
    c.name as customer_name,
    c.email,
    o.order_date,
    o.total_amount,
    o.payment_status,
    CURRENT_DATE - o.order_date::DATE as days_overdue,
    CASE
        WHEN CURRENT_DATE - o.order_date::DATE > 90 THEN 'Critical'
        WHEN CURRENT_DATE - o.order_date::DATE > 60 THEN 'Urgent'
        ELSE 'Follow-up'
    END as collection_priority
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.order_date < CURRENT_DATE - INTERVAL '60 days'
    AND o.payment_status IN ('pending', 'partial', 'overdue')
    AND o.status != 'cancelled'
ORDER BY days_overdue DESC;

-- Query 15: Análisis de Métodos de Pago
SELECT
    o.payment_method,
    COUNT(*) as transaction_count,
    SUM(o.total_amount) as total_amount,
    ROUND(AVG(o.total_amount), 2) as avg_amount,
    COUNT(CASE WHEN o.payment_status = 'paid' THEN 1 END) as successful_payments,
    COUNT(CASE WHEN o.payment_status IN ('pending', 'overdue') THEN 1 END) as pending_payments,
    ROUND(100.0 * COUNT(CASE WHEN o.payment_status = 'paid' THEN 1 END) / COUNT(*), 2) as success_rate_percent
FROM orders o
WHERE o.status != 'cancelled'
GROUP BY o.payment_method
ORDER BY total_amount DESC;

-- ============================================================================
-- ANÁLISIS DE DEVOLUCIONES
-- ============================================================================

-- Query 16: Resumen de Devoluciones
SELECT
    COUNT(DISTINCT r.id) as total_returns,
    COUNT(DISTINCT r.order_id) as orders_with_returns,
    SUM(r.refund_amount) as total_refunded,
    ROUND(AVG(r.refund_amount), 2) as avg_refund_amount,
    COUNT(CASE WHEN r.status = 'approved' THEN 1 END) as approved_returns,
    COUNT(CASE WHEN r.status = 'pending' THEN 1 END) as pending_returns,
    COUNT(CASE WHEN r.status = 'rejected' THEN 1 END) as rejected_returns,
    ROUND(100.0 * COUNT(CASE WHEN r.status = 'approved' THEN 1 END) / NULLIF(COUNT(*), 0), 2) as approval_rate_percent
FROM returns r;

-- Query 17: Top 10 Razones de Devolución
SELECT
    r.reason,
    COUNT(*) as return_count,
    SUM(r.refund_amount) as total_refunded,
    ROUND(AVG(r.refund_amount), 2) as avg_refund,
    COUNT(CASE WHEN r.status = 'approved' THEN 1 END) as approved,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM returns), 2) as percent_of_total_returns
FROM returns r
WHERE r.return_date >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY r.reason
ORDER BY return_count DESC
LIMIT 10;

-- Query 18: Productos con Mayor Tasa de Devolución
SELECT
    p.category,
    p.name,
    p.sku,
    COUNT(DISTINCT oi.order_id) as times_ordered,
    SUM(oi.quantity) as total_sold,
    SUM(oi.returned_quantity) as total_returned,
    ROUND(100.0 * SUM(oi.returned_quantity) / NULLIF(SUM(oi.quantity), 0), 2) as return_rate_percent
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
WHERE SUM(oi.quantity) >= 10 -- Mínimo de ventas
GROUP BY p.id, p.category, p.name, p.sku
HAVING SUM(oi.returned_quantity) > 0
ORDER BY return_rate_percent DESC;

-- ============================================================================
-- ANÁLISIS DE CAMPAÑAS
-- ============================================================================

-- Query 19: Performance de Campañas Activas
SELECT
    c.name,
    c.campaign_type,
    c.channel,
    c.start_date,
    c.end_date,
    COALESCE(c.budget, 0) as budget,
    COALESCE(c.actual_spend, 0) as actual_spend,
    ROUND(100.0 * COALESCE(c.actual_spend, 0) / NULLIF(COALESCE(c.budget, 1), 0), 2) as budget_utilization_percent,
    COALESCE(c.impressions, 0) as impressions,
    COALESCE(c.clicks, 0) as clicks,
    ROUND(100.0 * COALESCE(c.clicks, 0) / NULLIF(COALESCE(c.impressions, 1), 0), 2) as ctr_percent,
    COALESCE(c.conversions, 0) as conversions,
    ROUND(100.0 * COALESCE(c.conversions, 0) / NULLIF(COALESCE(c.clicks, 1), 0), 2) as conversion_rate_percent,
    COALESCE(c.revenue_generated, 0) as revenue_generated,
    CASE 
        WHEN COALESCE(c.actual_spend, 0) > 0
        THEN ROUND(COALESCE(c.revenue_generated, 0) / COALESCE(c.actual_spend, 1), 2)
        ELSE 0
    END as roi
FROM campaigns c
WHERE c.status = 'active'
    OR c.end_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY revenue_generated DESC;

-- ============================================================================
-- ANÁLISIS DE TENDENCIAS
-- ============================================================================

-- Query 20: Tendencia Mensual (Últimos 12 Meses)
SELECT
    DATE_TRUNC('month', o.order_date)::DATE as month,
    COUNT(*) as order_count,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    SUM(o.total_amount) as revenue,
    ROUND(AVG(o.total_amount), 2) as avg_order_value,
    ROUND(SUM(o.total_amount) - SUM(oi.quantity * p.cost_price), 2) as gross_profit,
    COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as delivered_orders,
    COUNT(CASE WHEN o.status = 'cancelled' THEN 1 END) as cancelled_orders
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '12 months'
    AND o.status != 'cancelled'
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month DESC;

-- Query 21: Forecast Simple (Tendencia Lineal)
WITH last_12_months AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE as month,
        ROW_NUMBER() OVER (ORDER BY DATE_TRUNC('month', o.order_date)) as month_number,
        SUM(o.total_amount) as revenue
    FROM orders o
    WHERE o.order_date >= CURRENT_DATE - INTERVAL '12 months'
        AND o.status != 'cancelled'
    GROUP BY DATE_TRUNC('month', o.order_date)
),
trend AS (
    SELECT
        REGR_SLOPE(revenue, month_number) as slope,
        REGR_INTERCEPT(revenue, month_number) as intercept,
        MAX(month_number) as last_month_num,
        MAX(month) as last_month
    FROM last_12_months
)
SELECT
    (t.last_month + (n || ' months')::INTERVAL)::DATE as forecast_month,
    GREATEST(0, ROUND(t.intercept + t.slope * (t.last_month_num + n), 2)) as forecasted_revenue
FROM trend t
CROSS JOIN GENERATE_SERIES(1, 3) n
WHERE t.slope IS NOT NULL;

-- ============================================================================
-- QUERIES PARA CMS/REPORTES ENVIABLES
-- ============================================================================

-- Query 22: Reporte Ejecutivo Semanal
SELECT
    'Semana' as period,
    MAX(o.order_date)::DATE - INTERVAL '6 days' as start_date,
    MAX(o.order_date)::DATE as end_date,
    COUNT(*) as orders,
    SUM(o.total_amount) as revenue,
    COUNT(DISTINCT o.customer_id) as new_customers,
    COUNT(CASE WHEN o.status = 'cancelled' THEN 1 END) as cancelled_orders,
    ROUND(100.0 * COUNT(CASE WHEN o.payment_status = 'paid' THEN 1 END) / NULLIF(COUNT(*), 0), 2) as payment_collection_percent
FROM orders o
WHERE o.order_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY 'Semana';

-- Query 23: Export para Power BI - Fact Table
SELECT
    o.id as order_id,
    o.uuid as order_uuid,
    o.order_date,
    o.total_amount,
    o.status,
    o.payment_status,
    c.id as customer_id,
    c.segment,
    c.industry,
    c.company_size,
    sp.id as salesperson_id,
    sp.name as salesperson_name,
    sp.team,
    oi.product_id,
    oi.quantity,
    oi.line_total
FROM orders o
JOIN customers c ON o.customer_id = c.id
LEFT JOIN salespeople sp ON o.salesperson_id = sp.id
LEFT JOIN order_items oi ON o.id = oi.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '12 months'
ORDER BY o.order_date DESC;

-- ============================================================================
-- FIN DE QUERIES EJEMPLO
-- ============================================================================
