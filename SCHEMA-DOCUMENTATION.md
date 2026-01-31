# Schema de Base de Datos - Sistema de Ventas para Dashboards

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Estructura de Tablas](#estructura-de-tablas)
3. [Relaciones y Foreign Keys](#relaciones-y-foreign-keys)
4. [Diccionario de Datos](#diccionario-de-datos)
5. [Vistas Analíticas](#vistas-analíticas)
6. [Funciones de Generación](#funciones-de-generación)
7. [Guía de Uso](#guía-de-uso)
8. [Optimizaciones](#optimizaciones)

---

## Visión General

Este schema está diseñado para:

- ✅ Generar datos realistas de ventas para testing
- ✅ Soportar análisis complejos en Power BI
- ✅ Facilitar dashboards customizados en código (Vue.js, etc.)
- ✅ Ser escalable y fácil de resetear

### Arquitectura de Datos

```
DIMENSIONES (Contexto)
├── customers (clientes)
├── products (productos)
└── salespeople (vendedores)

HECHOS (Transacciones)
├── orders (órdenes)
├── order_items (detalles de órdenes)
├── payments (pagos)
└── returns (devoluciones)

RELACIÓN (Marketing)
├── campaigns (campañas)
└── campaign_customers (relación campañas-clientes)

INTERACCIÓN (CRM)
└── customer_interactions (contactos y seguimientos)
```

---

## Estructura de Tablas

### 📊 CUSTOMERS

**Propósito:** Información completa de clientes

| Columna              | Tipo          | Descripción                               |
| -------------------- | ------------- | ----------------------------------------- |
| id                   | BIGSERIAL     | PK                                        |
| uuid                 | UUID          | Identificador único universal             |
| name                 | VARCHAR(255)  | Nombre del cliente                        |
| email                | VARCHAR(255)  | Email único                               |
| segment              | VARCHAR(50)   | premium, standard, trial, vip, inactive   |
| industry             | VARCHAR(100)  | Sector (Technology, Finance, etc.)        |
| company_size         | VARCHAR(50)   | startup, small, medium, large, enterprise |
| country              | VARCHAR(100)  | País                                      |
| state                | VARCHAR(100)  | Provincia/Estado                          |
| city                 | VARCHAR(100)  | Ciudad                                    |
| credit_limit         | NUMERIC(15,2) | Límite de crédito                         |
| total_lifetime_value | NUMERIC(15,2) | Calculado automáticamente                 |
| acquisition_date     | TIMESTAMP     | Fecha de adquisición                      |
| last_purchase_date   | TIMESTAMP     | Última compra (actualizado por trigger)   |
| is_active            | BOOLEAN       | Estado activo/inactivo                    |

**Índices Principales:**

- segment, country, is_active, acquisition_date

---

### 📦 PRODUCTS

**Propósito:** Catálogo de productos

| Columna          | Tipo          | Descripción                             |
| ---------------- | ------------- | --------------------------------------- |
| id               | BIGSERIAL     | PK                                      |
| sku              | VARCHAR(50)   | Código único de producto (UNIQUE)       |
| name             | VARCHAR(255)  | Nombre del producto                     |
| category         | VARCHAR(100)  | Categoría (Electronics, Software, etc.) |
| subcategory      | VARCHAR(100)  | Subcategoría                            |
| brand            | VARCHAR(100)  | Marca                                   |
| list_price       | NUMERIC(10,2) | Precio de lista                         |
| cost_price       | NUMERIC(10,2) | Costo                                   |
| current_stock    | INT           | Stock actual                            |
| is_active        | BOOLEAN       | Producto activo                         |
| launch_date      | DATE          | Fecha de lanzamiento                    |
| discontinue_date | DATE          | Fecha de discontinuación                |

**Índices Principales:**

- sku, category, brand, is_active

**Cálculo de Margen:**

```sql
profit_margin = (list_price - cost_price) / list_price * 100
```

---

### 👤 SALESPEOPLE

**Propósito:** Datos de vendedores y performance

| Columna         | Tipo          | Descripción                     |
| --------------- | ------------- | ------------------------------- |
| id              | BIGSERIAL     | PK                              |
| name            | VARCHAR(255)  | Nombre completo                 |
| team            | VARCHAR(100)  | Equipo (Enterprise, SMB, etc.)  |
| territory       | VARCHAR(100)  | Territorio (North, South, etc.) |
| manager_id      | BIGINT        | FK a vendedor gerente           |
| commission_rate | NUMERIC(5,2)  | Porcentaje de comisión          |
| quota_monthly   | NUMERIC(15,2) | Cuota mensual                   |
| is_active       | BOOLEAN       | Vendedor activo                 |
| hire_date       | DATE          | Fecha de contratación           |

**Índices Principales:**

- team, territory, is_active

---

### 📋 ORDERS (Tabla de Hechos Principal)

**Propósito:** Registro de todas las órdenes de ventas

| Columna          | Tipo          | Descripción                                                             |
| ---------------- | ------------- | ----------------------------------------------------------------------- |
| id               | BIGSERIAL     | PK                                                                      |
| customer_id      | BIGINT        | FK → customers                                                          |
| salesperson_id   | BIGINT        | FK → salespeople (nullable)                                             |
| order_date       | TIMESTAMP     | Fecha de la orden                                                       |
| status           | VARCHAR(50)   | pending, confirmed, processing, shipped, delivered, cancelled, returned |
| subtotal         | NUMERIC(15,2) | Suma antes de descuentos                                                |
| discount_amount  | NUMERIC(15,2) | Monto de descuento                                                      |
| discount_percent | NUMERIC(5,2)  | Porcentaje de descuento                                                 |
| tax_amount       | NUMERIC(15,2) | Impuestos                                                               |
| shipping_cost    | NUMERIC(15,2) | Costo de envío                                                          |
| total_amount     | NUMERIC(15,2) | **Total final = subtotal - discount + tax + shipping**                  |
| payment_method   | VARCHAR(50)   | credit_card, bank_transfer, cash, check                                 |
| payment_status   | VARCHAR(50)   | pending, partial, paid, overdue, refunded                               |
| notes            | TEXT          | Notas públicas                                                          |

**Indices:**

- customer_id, salesperson_id, order_date, status, payment_status, created_at

**Triggers Asociados:**

- `update_order_total()`: Recalcula total cuando cambian items
- `update_customer_lifetime_value()`: Actualiza LTV del cliente

---

### 🔗 ORDER_ITEMS

**Propósito:** Detalles de cada línea en una orden

| Columna           | Tipo          | Descripción                                            |
| ----------------- | ------------- | ------------------------------------------------------ |
| id                | BIGSERIAL     | PK                                                     |
| order_id          | BIGINT        | FK → orders (CASCADE)                                  |
| product_id        | BIGINT        | FK → products                                          |
| quantity          | INT           | Cantidad pedida                                        |
| unit_price        | NUMERIC(10,2) | Precio unitario                                        |
| discount_percent  | NUMERIC(5,2)  | Descuento por línea                                    |
| line_total        | NUMERIC(15,2) | **GENERATED: quantity _ unit_price _ (1 - discount%)** |
| fulfilled         | BOOLEAN       | ¿Línea cumplida?                                       |
| returned_quantity | INT           | Cantidad devuelta                                      |
| return_reason     | VARCHAR(255)  | Razón de devolución                                    |

**Características:**

- `line_total` es una columna GENERATED (calculada automáticamente)
- Índices en order_id y product_id para queries rápidas

---

### 💳 PAYMENTS

**Propósito:** Registro de transacciones de pago

| Columna          | Tipo          | Descripción                 |
| ---------------- | ------------- | --------------------------- |
| id               | BIGSERIAL     | PK                          |
| order_id         | BIGINT        | FK → orders                 |
| amount           | NUMERIC(15,2) | Monto pagado                |
| payment_date     | TIMESTAMP     | Fecha del pago              |
| payment_method   | VARCHAR(50)   | Método usado                |
| status           | VARCHAR(50)   | completed, failed, refunded |
| reference_number | VARCHAR(100)  | Número de referencia        |

**Nota:** Una orden puede tener múltiples pagos (pagos parciales).

---

### 🔙 RETURNS

**Propósito:** Registro de devoluciones y reembolsos

| Columna       | Tipo          | Descripción                           |
| ------------- | ------------- | ------------------------------------- |
| id            | BIGSERIAL     | PK                                    |
| order_id      | BIGINT        | FK → orders                           |
| return_date   | TIMESTAMP     | Fecha de devolución                   |
| reason        | VARCHAR(255)  | Motivo (defective, wrong_item, etc.)  |
| refund_amount | NUMERIC(15,2) | Monto reembolsado                     |
| status        | VARCHAR(50)   | pending, approved, rejected, refunded |
| approved_by   | VARCHAR(100)  | Quién aprobó                          |

---

### 📧 CUSTOMER_INTERACTIONS

**Propósito:** CRM - Registro de contactos

| Columna             | Tipo         | Descripción                                |
| ------------------- | ------------ | ------------------------------------------ |
| id                  | BIGSERIAL    | PK                                         |
| customer_id         | BIGINT       | FK → customers                             |
| salesperson_id      | BIGINT       | FK → salespeople                           |
| interaction_type    | VARCHAR(50)  | call, email, meeting, demo, support        |
| subject             | VARCHAR(255) | Asunto                                     |
| outcome             | VARCHAR(100) | interested, not_interested, scheduled_demo |
| next_follow_up_date | DATE         | Próximo seguimiento                        |
| interaction_date    | TIMESTAMP    | Fecha del contacto                         |
| duration_minutes    | INT          | Duración en minutos                        |

---

### 📣 CAMPAIGNS & CAMPAIGN_CUSTOMERS

**Propósito:** Marketing y relación con clientes

**CAMPAIGNS:**
| Columna | Descripción |
|--------- |------------- |
| name | Nombre de la campaña |
| campaign_type | email, webinar, trade_show, promotion |
| channel | email, social, direct_mail, events |
| start_date, end_date | Período de campaña |
| budget | Presupuesto asignado |
| impressions, clicks, conversions | Métricas |
| revenue_generated | Ingresos atribuibles |

**CAMPAIGN_CUSTOMERS:**
| Columna | Descripción |
|---------|-------------|
| campaign_id | FK → campaigns |
| customer_id | FK → customers |
| contacted_date | Cuándo se contactó |
| opened, clicked, converted | Engagement flags |

---

## Relaciones y Foreign Keys

### Diagrama de Relaciones

```
customers ◄─────┬────► orders ──► order_items ◄─── products
                 │        ▲            │
                 │        │            ▼
                 ├──────────► payments
                 │
                 ├──────────► returns
                 │
                 ├──────────► customer_interactions ◄─── salespeople
                 │
                 └──────────► campaign_customers ◄──── campaigns

salespeople ──────────────────────► orders
                ▲
                │
                └─ manager_id (self-reference)
```

### Integridad Referencial

- **ON DELETE RESTRICT:** customers (no se pueden eliminar con órdenes asociadas)
- **ON DELETE CASCADE:** order_items (si se borra orden, desaparecen items)
- **ON DELETE SET NULL:** salesperson_id en orders (si se borra vendedor, queda NULL)

---

## Diccionario de Datos

### Enumeraciones

**order_item.status:**

```
pending      → Pendiente de confirmar
confirmed    → Confirmada por cliente
processing   → En proceso de preparación
shipped      → Enviada
delivered    → Entregada
cancelled    → Cancelada
returned     → Devuelta
```

**payment_status:**

```
pending      → Esperando pago
partial      → Pago parcial recibido
paid         → Pagada completamente
overdue      → Retrasada
refunded     → Reembolsada
```

**segment:**

```
premium      → Clientes premium/VIP
standard     → Clientes estándar
trial        → En período de prueba
vip          → VIP especiales
inactive     → Inactivos
```

**company_size:**

```
startup      → Menos de 10 empleados
small        → 10-50 empleados
medium       → 50-500 empleados
large        → 500-5000 empleados
enterprise   → Más de 5000 empleados
```

---

## Vistas Analíticas

### Vistas Regulares (Real-time)

#### v_daily_sales_summary

Resumen diario de ventas con KPIs principales.

**Columns:**

- sales_date
- orders_count, unique_customers, salespeople_involved
- total_revenue, avg_order_value, min_order, max_order
- delivered_orders, cancelled_orders, paid_orders

**Uso en Power BI:**

```sql
SELECT * FROM v_daily_sales_summary
WHERE sales_date >= DATE_TRUNC('month', CURRENT_DATE)
ORDER BY sales_date DESC;
```

#### v_sales_by_category

Performance por categoría y subcategoría de productos.

**Columns:**

- category, subcategory
- orders_count, items_sold, total_quantity
- total_revenue, profit_margin_percent
- returned_items

#### v_salesperson_performance

KPIs individuales de vendedores.

**Columns:**

- name, team, territory
- total_orders, unique_customers, total_sales
- month_sales, quota_achievement_percent
- last_sale_date, days_since_last_sale

#### v_customer_segmentation

Análisis de clientes por segmento.

**Columns:**

- segment, industry, company_size
- lifetime_value, avg_order_value
- last_purchase_date, days_since_last_purchase
- orders_per_month, unpaid_orders

#### v_payment_analysis

Análisis de flujos de pago.

**Columns:**

- payment_date, payment_method
- payments_count, total_collected
- successful_payments, failed_payments
- late_payments_30, late_payments_60

#### v_returns_analysis

Análisis de devoluciones por categoría.

**Columns:**

- return_date, category
- returns_count, total_refunded
- return_rate_percent
- approved_returns, pending_returns

#### v_campaign_performance

Métricas de campañas de marketing.

**Columns:**

- name, campaign_type, channel
- budget, actual_spend, roi
- ctr_percent, conversion_rate_percent
- cost_per_conversion

### Vistas Materializadas (Optimizadas)

#### mv_monthly_sales_trend

Tendencia mensual de ventas (debe refrescarse periódicamente).

```sql
SELECT * FROM mv_monthly_sales_trend
WHERE year >= EXTRACT(YEAR FROM CURRENT_DATE) - 1;
```

#### mv_top_products_by_category

Top 10 productos por categoría.

```sql
SELECT * FROM mv_top_products_by_category
WHERE category_rank <= 10;
```

---

## Funciones de Generación

### 🚀 Función Principal: generate_all_test_data()

Genera todo el dataset de prueba de una sola vez.

**Sintaxis:**

```sql
SELECT * FROM generate_all_test_data(
    p_customers := 500,      -- Número de clientes
    p_products := 200,       -- Número de productos
    p_salespeople := 50,     -- Número de vendedores
    p_orders := 5000,        -- Número de órdenes
    p_days_back := 365       -- Datos de últimos N días
);
```

**Resultado:**

```
step          | records_created | execution_time_seconds
-------------|-----------------|----------------------
CUSTOMERS    | 500             | 0.5
PRODUCTS     | 200             | 0.3
SALESPEOPLE  | 50              | 0.1
ORDERS & ITEMS | 7500          | 12.5
PAYMENTS     | 3800            | 2.1
```

### Funciones Individuales

#### generate_customers(p_count INT, p_clean BOOLEAN)

Genera clientes con información realista.

```sql
SELECT * FROM generate_customers(1000, TRUE);
```

#### generate_products(p_count INT, p_clean BOOLEAN)

Genera productos con categorización.

```sql
SELECT * FROM generate_products(500, TRUE);
```

#### generate_salespeople(p_count INT, p_clean BOOLEAN)

Genera vendedores con asignaciones.

```sql
SELECT * FROM generate_salespeople(100, TRUE);
```

#### generate_orders(p_orders_count, p_days_back, p_clean)

Genera órdenes con items, pagos y devoluciones realistas.

```sql
SELECT * FROM generate_orders(10000, 365, TRUE);
```

---

## Guía de Uso

### 1️⃣ Instalación Inicial

```sql
-- En orden:
\i 01-schema.sql              -- Crear tablas
\i 02-views-and-functions.sql -- Vistas y funciones analíticas
\i 03-data-generation.sql     -- Funciones de generación
```

### 2️⃣ Generar Datos de Prueba

```sql
-- Opción A: Todo automático
SELECT * FROM generate_all_test_data(500, 200, 50, 5000, 365);

-- Opción B: Paso a paso (más control)
SELECT * FROM generate_customers(500, TRUE);
SELECT * FROM generate_products(200, TRUE);
SELECT * FROM generate_salespeople(50, TRUE);
SELECT * FROM generate_orders(5000, 365, TRUE);
SELECT * FROM generate_payments(TRUE);

-- Actualizar vistas materializadas
SELECT * FROM refresh_all_materialized_views();
```

### 3️⃣ Consultas Básicas

```sql
-- Ventas totales del mes
SELECT SUM(total_amount) FROM v_daily_sales_summary
WHERE sales_date >= DATE_TRUNC('month', CURRENT_DATE);

-- Top 10 vendedores
SELECT name, total_sales, quota_achievement_percent FROM v_salesperson_performance
ORDER BY total_sales DESC LIMIT 10;

-- Clientes con más valor
SELECT name, lifetime_value, segment FROM v_customer_segmentation
WHERE is_active = TRUE
ORDER BY lifetime_value DESC LIMIT 20;

-- Productos más rentables
SELECT category, name, profit_margin_percent, total_revenue
FROM v_sales_by_category
ORDER BY profit_margin_percent DESC;

-- ROI de campañas
SELECT name, roi, channel FROM v_campaign_performance
WHERE end_date >= CURRENT_DATE - INTERVAL '3 months'
ORDER BY roi DESC;
```

### 4️⃣ Reset/Limpiar

```sql
-- Opción A: Limpiar y regenerar
SELECT * FROM generate_all_test_data(500, 200, 50, 5000, 365);

-- Opción B: Limpiar tabla específica
DELETE FROM orders; -- Cascade elimina items y relacionados
DELETE FROM customers;

-- Opción C: Soft delete (mantener histórico)
UPDATE customers SET is_active = FALSE WHERE acquisition_date < CURRENT_DATE - INTERVAL '6 months';
```

---

## Optimizaciones

### Índices Recomendados

Ya incluidos en el schema:

```sql
-- Dimensiones
CREATE INDEX idx_customers_segment ON customers(segment);
CREATE INDEX idx_customers_is_active ON customers(is_active);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_salespeople_team ON salespeople(team);

-- Hechos
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
```

### Índices Adicionales para Analítica

```sql
-- Filtros comunes en dashboards
CREATE INDEX idx_orders_order_date_status ON orders(order_date, status);
CREATE INDEX idx_orders_payment_status_order_date ON orders(payment_status, order_date);

-- Mejora queries de vistas
CREATE INDEX idx_orders_customer_order_date ON orders(customer_id, order_date);
CREATE INDEX idx_order_items_product_fulfilled ON order_items(product_id, fulfilled);

-- Para agregaciones
CREATE INDEX idx_order_items_order_id_line_total ON order_items(order_id, line_total);
```

### Mantenimiento

```sql
-- Analizar tablas después de cargas masivas
ANALYZE customers;
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;

-- Ver tamaño de tablas
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Vaciar (optimizar)
VACUUM ANALYZE;
```

### Performance para Dashboards

```sql
-- Query rápida para dashboard principal
SELECT
    (SELECT COUNT(*) FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '30 days') as orders_30d,
    (SELECT SUM(total_amount) FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '30 days') as revenue_30d,
    (SELECT COUNT(DISTINCT customer_id) FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '30 days') as customers_30d,
    (SELECT AVG(total_amount) FROM orders WHERE order_date >= CURRENT_DATE - INTERVAL '30 days') as avg_order_30d;

-- Cache con CTE (evita cálculos repetidos)
WITH monthly_data AS (
    SELECT DATE_TRUNC('month', order_date)::DATE as month, SUM(total_amount) as revenue
    FROM orders
    GROUP BY month
)
SELECT * FROM monthly_data WHERE month >= CURRENT_DATE - INTERVAL '12 months';
```

---

## 📊 Integración con Power BI / Dashboards

### Conexión PostgreSQL en Power BI

1. **Import Data → PostgreSQL Database**
2. **Server:** localhost (o tu servidor)
3. **Database:** sales_test
4. **Usar DirectQuery para tablas grandes**

### Recomendaciones

- Usar vistas en lugar de tablas directamente
- Vistas materializadas para queries pesadas
- Actualizar MV cada noche (en horario bajo)
- Crear tablas de fecha/hora separadas si es necesario

```sql
-- Tabla de fechas (útil para Power BI)
CREATE TABLE calendar AS
SELECT
    DATE(d) as date,
    EXTRACT(YEAR FROM d) as year,
    EXTRACT(MONTH FROM d) as month,
    EXTRACT(DAY FROM d) as day,
    TO_CHAR(d, 'YYYY-MM') as year_month,
    EXTRACT(ISODOW FROM d) as day_of_week,
    TO_CHAR(d, 'TMDay') as day_name
FROM GENERATE_SERIES(CURRENT_DATE - INTERVAL '3 years', CURRENT_DATE, '1 day'::INTERVAL) d;
```

---

## 🔄 Ciclo de Vida Recomendado

1. **Desarrollo:** Generate_all_test_data() con 500 clientes, 200 productos
2. **Testing:** 5,000-10,000 órdenes para verificar performance
3. **Staging:** 50,000+ órdenes para simular carga real
4. **Producción:** Cargas incrementales, no resets

---

Este schema está listo para producción y soporta análisis complejos, reportería, y machine learning.
