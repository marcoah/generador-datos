# Schema de Base de Datos - Sistema de Ventas para Dashboards

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Estructura de Tablas](#estructura-de-tablas)
3. [Relaciones y Claves Foráneas](#relaciones-y-claves-foráneas)
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
├── clientes
├── productos
└── vendedores

HECHOS (Transacciones)
├── ordenes
├── items_orden
├── pagos
└── devoluciones

RELACIÓN (Marketing)
├── campanas
└── campanas_clientes

INTERACCIÓN (CRM)
└── interacciones_clientes
```

---

## Estructura de Tablas

### 📊 CLIENTES

**Propósito:** Información completa de clientes

| Columna             | Tipo          | Descripción                                       |
| ------------------- | ------------- | ------------------------------------------------- |
| id                  | BIGSERIAL     | PK                                                |
| uuid                | UUID          | Identificador único universal                     |
| nombre              | VARCHAR(255)  | Nombre completo del cliente                       |
| email               | VARCHAR(255)  | Email único                                       |
| segmento            | VARCHAR(50)   | premium, estandar, prueba, vip, inactivo          |
| industria           | VARCHAR(100)  | Sector (Tecnología, Finanzas, Salud, etc.)        |
| tamaño_empresa      | VARCHAR(50)   | startup, pequeña, mediana, grande, corporacion    |
| pais                | VARCHAR(100)  | País                                              |
| provincia           | VARCHAR(100)  | Provincia / Estado                                |
| ciudad              | VARCHAR(100)  | Ciudad                                            |
| limite_credito      | NUMERIC(15,2) | Límite de crédito                                 |
| valor_vida_total    | NUMERIC(15,2) | Calculado automáticamente vía trigger             |
| fecha_adquisicion   | TIMESTAMP     | Fecha de alta del cliente                         |
| fecha_ultima_compra | TIMESTAMP     | Última compra (actualizada por trigger)           |
| activo              | BOOLEAN       | Estado activo / inactivo                          |

**Índices Principales:** segmento, pais, activo, fecha_adquisicion

---

### 📦 PRODUCTOS

**Propósito:** Catálogo de productos

| Columna               | Tipo          | Descripción                                      |
| --------------------- | ------------- | ------------------------------------------------ |
| id                    | BIGSERIAL     | PK                                               |
| sku                   | VARCHAR(50)   | Código único de producto (UNIQUE)                |
| nombre                | VARCHAR(255)  | Nombre del producto                              |
| categoria             | VARCHAR(100)  | Categoría (Electrónica, Software, Servicios...)  |
| subcategoria          | VARCHAR(100)  | Subcategoría                                     |
| marca                 | VARCHAR(100)  | Marca                                            |
| precio_lista          | NUMERIC(10,2) | Precio de venta al público                       |
| precio_costo          | NUMERIC(10,2) | Costo de adquisición                             |
| stock_actual          | INT           | Stock disponible                                 |
| activo                | BOOLEAN       | Producto activo                                  |
| fecha_lanzamiento     | DATE          | Fecha de lanzamiento                             |
| fecha_descontinuacion | DATE          | Fecha de discontinuación                         |

**Índices Principales:** sku, categoria, marca, activo

**Cálculo de Margen:**

```sql
margen_pct = (precio_lista - precio_costo) / precio_lista * 100
```

---

### 👤 VENDEDORES

**Propósito:** Datos de vendedores y performance

| Columna            | Tipo          | Descripción                               |
| ------------------ | ------------- | ----------------------------------------- |
| id                 | BIGSERIAL     | PK                                        |
| nombre             | VARCHAR(255)  | Nombre completo                           |
| equipo             | VARCHAR(100)  | Equipo (Empresas, PyMEs, Startups, etc.)  |
| territorio         | VARCHAR(100)  | Territorio (Norte, Sur, Este, etc.)       |
| gerente_id         | BIGINT        | FK a vendedor gerente (autorreferencia)   |
| tasa_comision      | NUMERIC(5,2)  | Porcentaje de comisión                    |
| cuota_mensual      | NUMERIC(15,2) | Cuota de ventas mensual                   |
| activo             | BOOLEAN       | Vendedor activo                           |
| fecha_contratacion | DATE          | Fecha de ingreso                          |

**Índices Principales:** equipo, territorio, activo

---

### 📋 ORDENES (Tabla de Hechos Principal)

**Propósito:** Registro de todas las órdenes de ventas

| Columna                  | Tipo          | Descripción                                                                  |
| ------------------------ | ------------- | ---------------------------------------------------------------------------- |
| id                       | BIGSERIAL     | PK                                                                           |
| cliente_id               | BIGINT        | FK → clientes                                                                |
| vendedor_id              | BIGINT        | FK → vendedores (nullable)                                                   |
| fecha_orden              | TIMESTAMP     | Fecha de la orden                                                            |
| estado                   | VARCHAR(50)   | pendiente, confirmado, procesando, enviado, entregado, cancelado, devuelto   |
| subtotal                 | NUMERIC(15,2) | Suma antes de descuentos                                                     |
| monto_descuento          | NUMERIC(15,2) | Monto de descuento                                                           |
| porcentaje_descuento     | NUMERIC(5,2)  | Porcentaje de descuento                                                      |
| monto_impuesto           | NUMERIC(15,2) | Impuestos                                                                    |
| costo_envio              | NUMERIC(15,2) | Costo de envío                                                               |
| monto_total              | NUMERIC(15,2) | **Total final = subtotal - descuento + impuesto + envío**                    |
| metodo_pago              | VARCHAR(50)   | tarjeta_credito, transferencia_bancaria, efectivo, cheque                    |
| estado_pago              | VARCHAR(50)   | pendiente, parcial, pagado, vencido, reembolsado                             |
| notas                    | TEXT          | Notas visibles al cliente                                                    |
| notas_internas           | TEXT          | Notas internas del equipo                                                    |

**Índices:** cliente_id, vendedor_id, fecha_orden, estado, estado_pago, creado_en

**Triggers Asociados:**

- `actualizar_total_orden()`: Recalcula el total cuando cambian ítems
- `actualizar_valor_vida_cliente()`: Actualiza el valor de vida del cliente

---

### 🔗 ITEMS_ORDEN

**Propósito:** Detalles de cada línea de una orden

| Columna              | Tipo          | Descripción                                                  |
| -------------------- | ------------- | ------------------------------------------------------------ |
| id                   | BIGSERIAL     | PK                                                           |
| orden_id             | BIGINT        | FK → ordenes (CASCADE)                                       |
| producto_id          | BIGINT        | FK → productos                                               |
| cantidad             | INT           | Cantidad pedida                                              |
| precio_unitario      | NUMERIC(10,2) | Precio unitario al momento de la venta                       |
| porcentaje_descuento | NUMERIC(5,2)  | Descuento por línea                                          |
| total_linea          | NUMERIC(15,2) | **GENERADO: cantidad × precio_unitario × (1 - descuento%)**  |
| completado           | BOOLEAN       | ¿Línea despachada?                                           |
| cantidad_devuelta    | INT           | Cantidad devuelta                                            |
| motivo_devolucion    | VARCHAR(255)  | Razón de la devolución                                       |

**Características:**

- `total_linea` es una columna GENERATED (calculada automáticamente por Postgres)
- Índices en orden_id y producto_id para queries rápidas

---

### 💳 PAGOS

**Propósito:** Registro de transacciones de pago

| Columna           | Tipo          | Descripción                           |
| ----------------- | ------------- | ------------------------------------- |
| id                | BIGSERIAL     | PK                                    |
| orden_id          | BIGINT        | FK → ordenes                          |
| monto             | NUMERIC(15,2) | Monto pagado                          |
| fecha_pago        | TIMESTAMP     | Fecha del pago                        |
| metodo_pago       | VARCHAR(50)   | Método utilizado                      |
| estado            | VARCHAR(50)   | completado, fallido, reembolsado      |
| numero_referencia | VARCHAR(100)  | Número de referencia / comprobante    |

**Nota:** Una orden puede tener múltiples pagos (pagos parciales).

---

### 🔙 DEVOLUCIONES

**Propósito:** Registro de devoluciones y reembolsos

| Columna          | Tipo          | Descripción                                          |
| ---------------- | ------------- | ---------------------------------------------------- |
| id               | BIGSERIAL     | PK                                                   |
| orden_id         | BIGINT        | FK → ordenes                                         |
| fecha_devolucion | TIMESTAMP     | Fecha de solicitud                                   |
| motivo           | VARCHAR(255)  | Motivo (defectuoso, producto_incorrecto, etc.)       |
| monto_reembolso  | NUMERIC(15,2) | Monto a reembolsar                                   |
| estado           | VARCHAR(50)   | pendiente, aprobado, rechazado, reembolsado          |
| aprobado_por     | VARCHAR(100)  | Usuario que aprobó la devolución                     |

---

### 📧 INTERACCIONES_CLIENTES

**Propósito:** CRM - Registro de contactos y seguimientos

| Columna                    | Tipo         | Descripción                                      |
| -------------------------- | ------------ | ------------------------------------------------ |
| id                         | BIGSERIAL    | PK                                               |
| cliente_id                 | BIGINT       | FK → clientes                                    |
| vendedor_id                | BIGINT       | FK → vendedores                                  |
| tipo_interaccion           | VARCHAR(50)  | llamada, email, reunion, demo, soporte           |
| asunto                     | VARCHAR(255) | Asunto de la interacción                         |
| resultado                  | VARCHAR(100) | interesado, no_interesado, demo_programada, etc. |
| fecha_proximo_seguimiento  | DATE         | Próximo seguimiento programado                   |
| fecha_interaccion          | TIMESTAMP    | Fecha del contacto                               |
| duracion_minutos           | INT          | Duración en minutos                              |

---

### 📣 CAMPANAS & CAMPANAS_CLIENTES

**Propósito:** Marketing y relación con clientes

**CAMPANAS:**

| Columna             | Descripción                                       |
| ------------------- | ------------------------------------------------- |
| nombre              | Nombre de la campaña                              |
| tipo_campana        | email, webinar, feria, promocion, estacional      |
| canal               | email, redes_sociales, correo_directo, eventos    |
| fecha_inicio/fin    | Período de la campaña                             |
| presupuesto         | Presupuesto asignado                              |
| impresiones/clics   | Métricas de alcance                               |
| conversiones        | Cantidad de conversiones                          |
| ingresos_generados  | Ingresos atribuibles a la campaña                 |

**CAMPANAS_CLIENTES:**

| Columna         | Descripción                          |
| --------------- | ------------------------------------ |
| campana_id      | FK → campanas                        |
| cliente_id      | FK → clientes                        |
| fecha_contacto  | Cuándo se realizó el contacto        |
| abierto         | Si abrió el mensaje                  |
| hizo_clic       | Si hizo clic en el enlace            |
| convirtio       | Si se concretó la conversión         |

---

## Relaciones y Claves Foráneas

### Diagrama de Relaciones

```
clientes ◄──────┬────► ordenes ──► items_orden ◄─── productos
                │        ▲
                │        │
                ├──────────► pagos
                │
                ├──────────► devoluciones
                │
                ├──────────► interacciones_clientes ◄─── vendedores
                │
                └──────────► campanas_clientes ◄──── campanas

vendedores ────────────────────────► ordenes
                ▲
                │
                └─ gerente_id (autorreferencia)
```

### Integridad Referencial

- **ON DELETE RESTRICT:** clientes (no se eliminan si tienen órdenes)
- **ON DELETE CASCADE:** items_orden (se eliminan si se borra la orden)
- **ON DELETE SET NULL:** vendedor_id en ordenes (si se borra vendedor, queda NULL)

---

## Diccionario de Datos

### Enumeraciones

**ordenes.estado:**

```
pendiente    → Pendiente de confirmar
confirmado   → Confirmada por cliente
procesando   → En proceso de preparación
enviado      → Enviada
entregado    → Entregada y recibida
cancelado    → Cancelada
devuelto     → Devuelta
```

**ordenes.estado_pago:**

```
pendiente    → Esperando pago
parcial      → Pago parcial recibido
pagado       → Pagada completamente
vencido      → Fecha de vencimiento superada
reembolsado  → Reembolsada al cliente
```

**clientes.segmento:**

```
premium      → Clientes de alto valor
estandar     → Clientes regulares
prueba       → En período de prueba
vip          → VIP especiales
inactivo     → Sin actividad reciente
```

**clientes.tamaño_empresa:**

```
startup      → Menos de 10 empleados
pequeña      → 10-50 empleados
mediana      → 50-500 empleados
grande       → 500-5000 empleados
corporacion  → Más de 5000 empleados
```

**ordenes.metodo_pago:**

```
tarjeta_credito        → Tarjeta de crédito/débito
transferencia_bancaria → Transferencia bancaria
efectivo               → Pago en efectivo
cheque                 → Pago con cheque
```

---

## Vistas Analíticas

### Vistas Regulares (Tiempo Real)

#### v_resumen_ventas_diario

Resumen diario de ventas con KPIs principales.

**Columnas principales:**
- fecha_venta, cantidad_ordenes, clientes_unicos, vendedores_involucrados
- ingresos_totales, valor_promedio_orden, orden_minima, orden_maxima
- ordenes_entregadas, ordenes_canceladas, ordenes_pagadas

**Uso:**

```sql
SELECT * FROM v_resumen_ventas_diario
WHERE fecha_venta >= DATE_TRUNC('month', CURRENT_DATE)
ORDER BY fecha_venta DESC;
```

#### v_ventas_por_categoria

Performance por categoría y subcategoría de productos.

**Columnas principales:**
- categoria, subcategoria
- cantidad_ordenes, unidades_vendidas, cantidad_total
- ingresos_totales, margen_ganancia_pct
- unidades_devueltas

#### v_performance_vendedores

KPIs individuales de vendedores.

**Columnas principales:**
- nombre, equipo, territorio
- total_ordenes, clientes_unicos, ventas_totales
- ventas_mes_actual, porcentaje_cumplimiento_cuota
- fecha_ultima_venta, dias_desde_ultima_venta

#### v_segmentacion_clientes

Análisis de clientes por segmento.

**Columnas principales:**
- segmento, industria, tamaño_empresa
- valor_vida, valor_promedio_orden
- fecha_ultima_compra, dias_desde_ultima_compra
- ordenes_por_mes, ordenes_sin_pago

#### v_analisis_pagos

Análisis de flujos de pago.

**Columnas principales:**
- fecha_pago, metodo_pago
- cantidad_pagos, total_cobrado
- pagos_exitosos, pagos_fallidos
- pagos_atrasados_30d, pagos_atrasados_60d

#### v_analisis_devoluciones

Análisis de devoluciones por categoría.

**Columnas principales:**
- fecha_devolucion, categoria
- cantidad_devoluciones, total_reembolsado
- tasa_devolucion_pct
- devoluciones_aprobadas, devoluciones_pendientes

#### v_performance_campanas

Métricas de campañas de marketing.

**Columnas principales:**
- nombre, tipo_campana, canal
- presupuesto, gasto_real, roi
- ctr_pct, tasa_conversion_pct
- costo_por_conversion

### Vistas Materializadas (Optimizadas para Performance)

#### mv_tendencia_ventas_mensual

Tendencia mensual de ventas (refrescar periódicamente).

```sql
SELECT * FROM mv_tendencia_ventas_mensual
WHERE anio >= EXTRACT(YEAR FROM CURRENT_DATE) - 1;
```

#### mv_top_productos_por_categoria

Top productos por categoría con ranking.

```sql
SELECT * FROM mv_top_productos_por_categoria
WHERE ranking_categoria <= 10;
```

---

## Funciones de Generación

### 🚀 Función Principal: generar_todos_los_datos()

Genera todo el dataset de prueba de una sola vez.

**Sintaxis:**

```sql
SELECT * FROM generar_todos_los_datos(
    p_clientes    := 500,   -- Número de clientes
    p_productos   := 200,   -- Número de productos
    p_vendedores  := 50,    -- Número de vendedores
    p_ordenes     := 5000,  -- Número de órdenes
    p_dias_atras  := 365    -- Datos de últimos N días
);
```

**Resultado esperado:**

```
paso            | registros_creados | tiempo_ejecucion_segundos
----------------|-------------------|---------------------------
CLIENTES        | 500               | 0.5
PRODUCTOS       | 200               | 0.3
VENDEDORES      | 50                | 0.1
ÓRDENES E ÍTEMS | 7500              | 12.5
PAGOS           | 3800              | 2.1
```

### Funciones Individuales

#### generar_clientes(p_cantidad INT, p_limpiar BOOLEAN)

```sql
SELECT * FROM generar_clientes(1000, TRUE);
```

#### generar_productos(p_cantidad INT, p_limpiar BOOLEAN)

```sql
SELECT * FROM generar_productos(500, TRUE);
```

#### generar_vendedores(p_cantidad INT, p_limpiar BOOLEAN)

```sql
SELECT * FROM generar_vendedores(100, TRUE);
```

#### generar_ordenes(p_cantidad_ordenes, p_dias_atras, p_limpiar)

```sql
SELECT * FROM generar_ordenes(10000, 365, TRUE);
```

#### generar_pagos(p_limpiar BOOLEAN)

```sql
SELECT * FROM generar_pagos(TRUE);
```

### Funciones Analíticas

#### calcular_arr(p_meses_periodo INT)

Calcula el Ingreso Anual Recurrente por segmento.

```sql
SELECT * FROM calcular_arr(12);
```

#### calcular_churn(p_dias_periodo INT)

Calcula la tasa de abandono de clientes por segmento.

```sql
SELECT * FROM calcular_churn(90);
```

#### pronostico_ventas(p_meses_pronostico, p_meses_historico)

Genera un pronóstico de ingresos con tendencia lineal.

```sql
SELECT * FROM pronostico_ventas(3, 12);
```

#### analisis_cohortes(p_metrica VARCHAR)

Análisis de cohortes por mes de primera compra.

```sql
SELECT * FROM analisis_cohortes('ingresos');
-- Métricas: 'ingresos', 'ordenes', 'retencion'
```

---

## Guía de Uso

### 1️⃣ Instalación Inicial

```sql
-- Ejecutar en orden:
\i 01-schema.sql             -- Crear tablas, triggers y funciones base
\i 02-vistas-y-funciones.sql -- Vistas y funciones analíticas
\i 03-generacion-datos.sql   -- Funciones de generación de datos
```

### 2️⃣ Generar Datos de Prueba

```sql
-- Opción A: Todo automático
SELECT * FROM generar_todos_los_datos(500, 200, 50, 5000, 365);

-- Opción B: Paso a paso (más control)
SELECT * FROM generar_clientes(500, TRUE);
SELECT * FROM generar_productos(200, TRUE);
SELECT * FROM generar_vendedores(50, TRUE);
SELECT * FROM generar_ordenes(5000, 365, TRUE);
SELECT * FROM generar_pagos(TRUE);

-- Actualizar vistas materializadas
SELECT * FROM refrescar_vistas_materializadas();
```

### 3️⃣ Consultas Básicas

```sql
-- Ventas totales del mes
SELECT SUM(ingresos_totales) FROM v_resumen_ventas_diario
WHERE fecha_venta >= DATE_TRUNC('month', CURRENT_DATE);

-- Top 10 vendedores
SELECT nombre, ventas_totales, porcentaje_cumplimiento_cuota
FROM v_performance_vendedores
ORDER BY ventas_totales DESC LIMIT 10;

-- Clientes con mayor valor
SELECT nombre, valor_vida, segmento FROM v_segmentacion_clientes
ORDER BY valor_vida DESC LIMIT 20;

-- Productos más rentables por categoría
SELECT categoria, nombre, margen_ganancia_pct, ingresos_totales
FROM v_ventas_por_categoria
ORDER BY margen_ganancia_pct DESC;

-- ROI de campañas recientes
SELECT nombre, roi, canal FROM v_performance_campanas
WHERE fecha_fin >= CURRENT_DATE - INTERVAL '3 months'
ORDER BY roi DESC;
```

### 4️⃣ Reset / Limpiar

```sql
-- Opción A: Limpiar y regenerar completamente
SELECT * FROM generar_todos_los_datos(500, 200, 50, 5000, 365);

-- Opción B: Limpiar tablas específicas
DELETE FROM ordenes;     -- Cascade elimina items_orden y relacionados
DELETE FROM clientes;

-- Opción C: Desactivar clientes (soft delete)
UPDATE clientes
SET activo = FALSE
WHERE fecha_adquisicion < CURRENT_DATE - INTERVAL '6 months';
```

---

## Optimizaciones

### Índices Incluidos en el Schema

```sql
-- Dimensiones
CREATE INDEX idx_clientes_segmento ON clientes(segmento);
CREATE INDEX idx_clientes_activo ON clientes(activo);
CREATE INDEX idx_productos_categoria ON productos(categoria);
CREATE INDEX idx_vendedores_equipo ON vendedores(equipo);

-- Hechos
CREATE INDEX idx_ordenes_cliente_id ON ordenes(cliente_id);
CREATE INDEX idx_ordenes_fecha_orden ON ordenes(fecha_orden);
CREATE INDEX idx_ordenes_estado ON ordenes(estado);
CREATE INDEX idx_items_orden_orden_id ON items_orden(orden_id);
```

### Índices Adicionales Recomendados para Analítica

```sql
-- Filtros compuestos frecuentes en dashboards
CREATE INDEX idx_ordenes_fecha_estado ON ordenes(fecha_orden, estado);
CREATE INDEX idx_ordenes_estado_pago_fecha ON ordenes(estado_pago, fecha_orden);

-- Mejoran queries de vistas
CREATE INDEX idx_ordenes_cliente_fecha ON ordenes(cliente_id, fecha_orden);
CREATE INDEX idx_items_orden_producto_completado ON items_orden(producto_id, completado);

-- Para agregaciones
CREATE INDEX idx_items_orden_orden_total ON items_orden(orden_id, total_linea);
```

### Mantenimiento

```sql
-- Analizar tablas después de cargas masivas
ANALYZE clientes;
ANALYZE productos;
ANALYZE ordenes;
ANALYZE items_orden;

-- Ver tamaño de tablas
SELECT schemaname, tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS tamaño
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Optimizar
VACUUM ANALYZE;
```

### Performance para Dashboards

```sql
-- Query rápida para KPIs del dashboard principal
SELECT
    (SELECT COUNT(*) FROM ordenes WHERE fecha_orden >= CURRENT_DATE - INTERVAL '30 days') AS ordenes_30d,
    (SELECT SUM(monto_total) FROM ordenes WHERE fecha_orden >= CURRENT_DATE - INTERVAL '30 days') AS ingresos_30d,
    (SELECT COUNT(DISTINCT cliente_id) FROM ordenes WHERE fecha_orden >= CURRENT_DATE - INTERVAL '30 days') AS clientes_30d,
    (SELECT AVG(monto_total) FROM ordenes WHERE fecha_orden >= CURRENT_DATE - INTERVAL '30 days') AS promedio_30d;

-- Cache con CTE (evita cálculos repetidos)
WITH datos_mensuales AS (
    SELECT DATE_TRUNC('month', fecha_orden)::DATE AS mes, SUM(monto_total) AS ingresos
    FROM ordenes
    GROUP BY mes
)
SELECT * FROM datos_mensuales WHERE mes >= CURRENT_DATE - INTERVAL '12 months';
```

---

## 📊 Integración con Power BI / Dashboards

### Conexión PostgreSQL en Power BI

1. **Obtener datos → Base de datos PostgreSQL**
2. **Servidor:** localhost (o tu servidor)
3. **Base de datos:** ventas_test
4. **Usar DirectQuery para tablas grandes**

### Recomendaciones

- Usar vistas en lugar de tablas directamente
- Usar vistas materializadas para queries pesadas
- Actualizar MV cada noche en horario de bajo tráfico
- Crear tabla de calendario si se necesita inteligencia de tiempo

```sql
-- Tabla de calendario (útil para Power BI)
CREATE TABLE calendario AS
SELECT
    DATE(d) AS fecha,
    EXTRACT(YEAR FROM d) AS anio,
    EXTRACT(MONTH FROM d) AS mes,
    EXTRACT(DAY FROM d) AS dia,
    TO_CHAR(d, 'YYYY-MM') AS anio_mes,
    EXTRACT(ISODOW FROM d) AS dia_semana_num,
    TO_CHAR(d, 'TMDay') AS nombre_dia,
    TO_CHAR(d, 'TMMonth') AS nombre_mes,
    CASE WHEN EXTRACT(ISODOW FROM d) IN (6, 7) THEN TRUE ELSE FALSE END AS es_fin_semana
FROM GENERATE_SERIES(CURRENT_DATE - INTERVAL '3 years', CURRENT_DATE + INTERVAL '1 year', '1 day'::INTERVAL) d;
```

---

## 🔄 Ciclo de Vida Recomendado

1. **Desarrollo:** `generar_todos_los_datos()` con 500 clientes, 200 productos
2. **Testing:** 5.000-10.000 órdenes para verificar performance
3. **Staging:** 50.000+ órdenes para simular carga real
4. **Producción:** Cargas incrementales, no resets destructivos

---

Este schema está listo para producción y soporta análisis complejos, reportería avanzada y machine learning.
