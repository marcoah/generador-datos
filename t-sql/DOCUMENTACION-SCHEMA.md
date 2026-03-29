# Schema de Base de Datos - Sistema de Ventas para Dashboards

## Versión SQL Server 2016+

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Diferencias Clave vs PostgreSQL](#diferencias-clave-vs-postgresql)
3. [Estructura de Tablas](#estructura-de-tablas)
4. [Relaciones y Claves Foráneas](#relaciones-y-claves-foráneas)
5. [Diccionario de Datos](#diccionario-de-datos)
6. [Vistas Analíticas](#vistas-analíticas)
7. [Funciones y Procedimientos](#funciones-y-procedimientos)
8. [Guía de Uso](#guía-de-uso)
9. [Optimizaciones](#optimizaciones)

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
├── dbo.clientes
├── dbo.productos
└── dbo.vendedores

HECHOS (Transacciones)
├── dbo.ordenes
├── dbo.items_orden
├── dbo.pagos
└── dbo.devoluciones

RELACIÓN (Marketing)
├── dbo.campanas
└── dbo.campanas_clientes

INTERACCIÓN (CRM)
└── dbo.interacciones_clientes

APOYO
└── dbo.numeros         (tabla de enteros 1..10000 para generación)
```

---

## Diferencias Clave vs PostgreSQL

Esta sección documenta todas las adaptaciones realizadas al migrar de PostgreSQL a SQL Server.

### Tipos de Datos

| PostgreSQL           | SQL Server             | Nota                                           |
| -------------------- | ---------------------- | ---------------------------------------------- |
| `BIGSERIAL`          | `BIGINT IDENTITY(1,1)` | Autoincremental                                |
| `UUID`               | `UNIQUEIDENTIFIER`     | Mismo propósito                                |
| `uuid_generate_v4()` | `NEWID()`              | Función nativa equivalente                     |
| `BOOLEAN`            | `BIT`                  | 0 = FALSE, 1 = TRUE                            |
| `TEXT`               | `NVARCHAR(MAX)`        | Soporta Unicode                                |
| `VARCHAR(n)`         | `NVARCHAR(n)`          | Se usa N para soporte de caracteres especiales |
| `NUMERIC(p,s)`       | `DECIMAL(p,s)`         | Equivalentes                                   |
| `TIMESTAMP`          | `DATETIME2`            | Mayor precisión y rango que DATETIME           |
| `DATE`               | `DATE`                 | Igual                                          |

### Sintaxis General

| PostgreSQL                   | SQL Server                                |
| ---------------------------- | ----------------------------------------- |
| `CREATE TABLE IF NOT EXISTS` | `IF OBJECT_ID(...) IS NULL CREATE TABLE`  |
| `CREATE OR REPLACE FUNCTION` | `CREATE OR ALTER FUNCTION / PROCEDURE`    |
| `CURRENT_TIMESTAMP`          | `GETDATE()` o `CURRENT_TIMESTAMP`         |
| `CURRENT_DATE`               | `CAST(GETDATE() AS DATE)`                 |
| `INTERVAL '30 days'`         | `DATEADD(DAY, -30, GETDATE())`            |
| `DATE_TRUNC('month', col)`   | `DATEFROMPARTS(YEAR(col), MONTH(col), 1)` |
| `EXTRACT(YEAR FROM col)`     | `YEAR(col)` o `DATEPART(YEAR, col)`       |
| `COALESCE`                   | `COALESCE` (igual)                        |
| `NULLIF`                     | `NULLIF` (igual)                          |
| `GENERATE_SERIES(1, n)`      | CTE recursivo o tabla `dbo.numeros`       |
| `LIMIT n`                    | `TOP n` (al inicio del SELECT)            |
| `RETURNING id`               | `SCOPE_IDENTITY()` o `OUTPUT`             |
| `RAISE NOTICE '...'`         | `PRINT '...'`                             |

### Columnas Calculadas

```sql
-- PostgreSQL
total_linea NUMERIC(15,2) GENERATED ALWAYS AS
    (cantidad * precio_unitario * (1 - porcentaje_descuento / 100)) STORED

-- SQL Server
total_linea AS (
    CAST(cantidad * precio_unitario * (1 - porcentaje_descuento / 100.0) AS DECIMAL(15,2))
) PERSISTED
```

### Funciones y Procedimientos

| PostgreSQL                       | SQL Server                             |
| -------------------------------- | -------------------------------------- |
| `RETURNS TABLE ... RETURN QUERY` | `RETURNS TABLE AS RETURN (SELECT ...)` |
| `LANGUAGE plpgsql`               | T-SQL (sin declaración de lenguaje)    |
| `$$ ... $$` delimitadores        | `BEGIN ... END`                        |
| `DECLARE v_var TYPE`             | `DECLARE @var TYPE`                    |
| `v_var := valor`                 | `SET @var = valor`                     |
| `FOR row IN SELECT ... LOOP`     | `WHILE` con cursores o INSERT directo  |
| `PERFORM f()`                    | `EXEC f()` o `SELECT f()`              |

### Vistas Materializadas → Tablas de Caché

SQL Server **no tiene vistas materializadas** generales. Las alternativas son:

1. **Tablas físicas + SP de refresco** (elegido en este schema): máxima flexibilidad.
2. **Vistas indexadas**: limitaciones muy estrictas (sin JOINs a múltiples tablas, sin agregaciones con `DISTINCT`, sin subqueries, etc.).

```sql
-- PostgreSQL
CREATE MATERIALIZED VIEW mv_tendencia_ventas_mensual AS SELECT ...;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_tendencia_ventas_mensual;

-- SQL Server
CREATE TABLE dbo.mv_tendencia_ventas_mensual (...);   -- tabla física
-- Refresco via:
EXEC dbo.sp_refrescar_vistas_materializadas;
```

### Regresión Lineal

PostgreSQL tiene `REGR_SLOPE` y `REGR_INTERCEPT` como funciones de ventana. SQL Server no las tiene; se implementan manualmente:

```sql
-- Fórmula pendiente: (n·Σxy - Σx·Σy) / (n·Σx² - (Σx)²)
-- Fórmula intercepto: (Σy - pendiente·Σx) / n
```

Esto está implementado en `dbo.fn_pronostico_ventas`.

### Aleatoriedad en Generación de Datos

| PostgreSQL                   | SQL Server                                              |
| ---------------------------- | ------------------------------------------------------- |
| `RANDOM()`                   | `ABS(CHECKSUM(NEWID())) % n`                            |
| Arrays con índice            | Tablas temporales + `SELECT TOP 1 ... ORDER BY NEWID()` |
| `CROSS JOIN GENERATE_SERIES` | `CROSS APPLY (SELECT TOP n ...)` con `dbo.numeros`      |

### Comentarios de Objetos

```sql
-- PostgreSQL
COMMENT ON TABLE clientes IS 'Descripción';
COMMENT ON COLUMN ordenes.monto_total IS 'Descripción';

-- SQL Server
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description', @value = N'Descripción',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'clientes';
```

---

## Estructura de Tablas

### 📊 CLIENTES

**Propósito:** Información completa de clientes

| Columna             | Tipo             | Descripción                                    |
| ------------------- | ---------------- | ---------------------------------------------- |
| id                  | BIGINT IDENTITY  | PK                                             |
| uuid                | UNIQUEIDENTIFIER | Identificador único universal (NEWID())        |
| nombre              | NVARCHAR(255)    | Nombre completo del cliente                    |
| email               | NVARCHAR(255)    | Email único                                    |
| segmento            | NVARCHAR(50)     | premium, estandar, prueba, vip, inactivo       |
| industria           | NVARCHAR(100)    | Sector (Tecnología, Finanzas, Salud, etc.)     |
| tamaño_empresa      | NVARCHAR(50)     | startup, pequeña, mediana, grande, corporacion |
| pais                | NVARCHAR(100)    | País                                           |
| provincia           | NVARCHAR(100)    | Provincia / Estado                             |
| ciudad              | NVARCHAR(100)    | Ciudad                                         |
| limite_credito      | DECIMAL(15,2)    | Límite de crédito                              |
| valor_vida_total    | DECIMAL(15,2)    | Calculado automáticamente vía trigger          |
| fecha_adquisicion   | DATETIME2        | Fecha de alta del cliente                      |
| fecha_ultima_compra | DATETIME2        | Última compra (actualizada por trigger)        |
| activo              | BIT              | 1 = activo, 0 = inactivo                       |

**Índices:** segmento, pais, activo, fecha_adquisicion

---

### 📦 PRODUCTOS

| Columna               | Tipo            | Descripción              |
| --------------------- | --------------- | ------------------------ |
| id                    | BIGINT IDENTITY | PK                       |
| sku                   | NVARCHAR(50)    | Código único (UNIQUE)    |
| nombre                | NVARCHAR(255)   | Nombre del producto      |
| categoria             | NVARCHAR(100)   | Categoría principal      |
| subcategoria          | NVARCHAR(100)   | Subcategoría             |
| marca                 | NVARCHAR(100)   | Marca                    |
| precio_lista          | DECIMAL(10,2)   | Precio de venta          |
| precio_costo          | DECIMAL(10,2)   | Costo de adquisición     |
| stock_actual          | INT             | Stock disponible         |
| es_digital            | BIT             | 1 si es producto digital |
| fecha_lanzamiento     | DATE            | Fecha de lanzamiento     |
| fecha_descontinuacion | DATE            | Fecha de discontinuación |
| activo                | BIT             | 1 = activo               |

---

### 👤 VENDEDORES

| Columna            | Tipo            | Descripción                            |
| ------------------ | --------------- | -------------------------------------- |
| id                 | BIGINT IDENTITY | PK                                     |
| nombre             | NVARCHAR(255)   | Nombre completo                        |
| equipo             | NVARCHAR(100)   | Empresas, PyMEs, Startups, Estratégico |
| territorio         | NVARCHAR(100)   | Norte, Sur, Este, Oeste, Centro        |
| gerente_id         | BIGINT          | FK autorreferencia a vendedores        |
| tasa_comision      | DECIMAL(5,2)    | Porcentaje de comisión                 |
| cuota_mensual      | DECIMAL(15,2)   | Cuota de ventas mensual                |
| activo             | BIT             | 1 = activo                             |
| fecha_contratacion | DATE            | Fecha de ingreso                       |

---

### 📋 ORDENES (Tabla de Hechos Principal)

| Columna         | Tipo            | Descripción                                                                |
| --------------- | --------------- | -------------------------------------------------------------------------- |
| id              | BIGINT IDENTITY | PK                                                                         |
| cliente_id      | BIGINT          | FK → clientes                                                              |
| vendedor_id     | BIGINT NULL     | FK → vendedores (nullable)                                                 |
| fecha_orden     | DATETIME2       | Fecha de la orden                                                          |
| estado          | NVARCHAR(50)    | pendiente, confirmado, procesando, enviado, entregado, cancelado, devuelto |
| subtotal        | DECIMAL(15,2)   | Suma antes de descuentos                                                   |
| monto_descuento | DECIMAL(15,2)   | Monto de descuento aplicado                                                |
| monto_impuesto  | DECIMAL(15,2)   | Impuestos                                                                  |
| costo_envio     | DECIMAL(15,2)   | Costo de envío                                                             |
| monto_total     | DECIMAL(15,2)   | Total final = subtotal - descuento + impuesto + envío                      |
| metodo_pago     | NVARCHAR(50)    | tarjeta_credito, transferencia_bancaria, efectivo, cheque                  |
| estado_pago     | NVARCHAR(50)    | pendiente, parcial, pagado, vencido, reembolsado                           |

**Triggers:**

- `trg_actualizar_total_orden`: Recalcula monto_total al modificar items_orden
- `trg_actualizar_valor_vida_cliente`: Actualiza valor_vida_total del cliente

---

### 🔗 ITEMS_ORDEN

| Columna              | Tipo            | Descripción                                                 |
| -------------------- | --------------- | ----------------------------------------------------------- |
| id                   | BIGINT IDENTITY | PK                                                          |
| orden_id             | BIGINT          | FK → ordenes (ON DELETE CASCADE)                            |
| producto_id          | BIGINT          | FK → productos                                              |
| cantidad             | INT             | Cantidad pedida                                             |
| precio_unitario      | DECIMAL(10,2)   | Precio al momento de la venta                               |
| porcentaje_descuento | DECIMAL(5,2)    | Descuento por línea                                         |
| total_linea          | DECIMAL(15,2)   | **Columna PERSISTED**: cantidad × precio × (1 - descuento%) |
| completado           | BIT             | 1 si fue despachado                                         |
| cantidad_devuelta    | INT             | Unidades devueltas                                          |

---

### 💳 PAGOS

| Columna           | Tipo          | Descripción                      |
| ----------------- | ------------- | -------------------------------- |
| orden_id          | BIGINT        | FK → ordenes                     |
| monto             | DECIMAL(15,2) | Monto pagado                     |
| fecha_pago        | DATETIME2     | Fecha del pago                   |
| metodo_pago       | NVARCHAR(50)  | Método utilizado                 |
| estado            | NVARCHAR(50)  | completado, fallido, reembolsado |
| numero_referencia | NVARCHAR(100) | Comprobante / referencia         |

**Nota:** Una orden puede tener múltiples pagos (pagos parciales).

---

### 🔙 DEVOLUCIONES

| Columna          | Tipo          | Descripción                                 |
| ---------------- | ------------- | ------------------------------------------- |
| orden_id         | BIGINT        | FK → ordenes                                |
| fecha_devolucion | DATETIME2     | Fecha de solicitud                          |
| motivo           | NVARCHAR(255) | Motivo de la devolución                     |
| monto_reembolso  | DECIMAL(15,2) | Monto a reembolsar                          |
| estado           | NVARCHAR(50)  | pendiente, aprobado, rechazado, reembolsado |

---

## Relaciones y Claves Foráneas

```
clientes ◄──────┬────► ordenes ──► items_orden ◄─── productos
                │        ▲
                ├──────────► pagos
                ├──────────► devoluciones
                ├──────────► interacciones_clientes ◄─── vendedores
                └──────────► campanas_clientes ◄──── campanas

vendedores ────────────► ordenes
     ▲
     └─ gerente_id (autorreferencia)
```

**Integridad referencial:**

- `ON DELETE CASCADE`: items_orden, interacciones_clientes, campanas_clientes
- FK estándar (restrict por defecto): ordenes → clientes, pagos → ordenes, devoluciones → ordenes

---

## Diccionario de Datos

### Valores por Campo

**ordenes.estado:** `pendiente` · `confirmado` · `procesando` · `enviado` · `entregado` · `cancelado` · `devuelto`

**ordenes.estado_pago:** `pendiente` · `parcial` · `pagado` · `vencido` · `reembolsado`

**ordenes.metodo_pago:** `tarjeta_credito` · `transferencia_bancaria` · `efectivo` · `cheque`

**clientes.segmento:** `premium` · `estandar` · `prueba` · `vip` · `inactivo`

**clientes.tamaño_empresa:** `startup` · `pequeña` · `mediana` · `grande` · `corporacion`

**campanas.tipo_campana:** `email` · `webinar` · `feria` · `promocion` · `estacional`

**pagos.estado:** `pendiente` · `completado` · `fallido` · `reembolsado`

---

## Vistas Analíticas

### Vistas Regulares

| Vista                      | Descripción                                  |
| -------------------------- | -------------------------------------------- |
| `v_resumen_ventas_diario`  | KPIs diarios: ingresos, órdenes, estados     |
| `v_ventas_por_categoria`   | Ingresos y margen por categoría/subcategoría |
| `v_performance_vendedores` | KPIs individuales + cumplimiento de cuota    |
| `v_segmentacion_clientes`  | Valor de vida, frecuencia, días inactivo     |
| `v_analisis_devoluciones`  | Tasas y montos de devoluciones               |
| `v_analisis_pagos`         | Flujo de cobros por método y atrasos         |
| `v_performance_campanas`   | ROI, CTR, conversiones de campañas           |

### Tablas de Caché (reemplazo de Materialized Views)

| Tabla                            | Descripción                                   | Refresco                             |
| -------------------------------- | --------------------------------------------- | ------------------------------------ |
| `mv_tendencia_ventas_mensual`    | Tendencia mensual de ventas e ingresos        | `sp_refrescar_vistas_materializadas` |
| `mv_top_productos_por_categoria` | Ranking de productos dentro de cada categoría | `sp_refrescar_vistas_materializadas` |

```sql
-- Refrescar manualmente
EXEC dbo.sp_refrescar_vistas_materializadas;

-- Programar en SQL Server Agent (ejemplo, cada noche a las 2am)
-- Job Step: EXEC dbo.sp_refrescar_vistas_materializadas;
```

---

## Funciones y Procedimientos

### Procedimientos de Generación

| Procedimiento                | Parámetros principales                         |
| ---------------------------- | ---------------------------------------------- |
| `sp_generar_clientes`        | `@cantidad INT`, `@limpiar BIT`                |
| `sp_generar_productos`       | `@cantidad INT`, `@limpiar BIT`                |
| `sp_generar_vendedores`      | `@cantidad INT`, `@limpiar BIT`                |
| `sp_generar_ordenes`         | `@cantidad_ordenes`, `@dias_atras`, `@limpiar` |
| `sp_generar_pagos`           | `@limpiar BIT`                                 |
| `sp_generar_todos_los_datos` | Orquesta todos los anteriores                  |

### Funciones Analíticas (TVF - Table Valued Functions)

| Función                | Parámetros                                       | Retorna                              |
| ---------------------- | ------------------------------------------------ | ------------------------------------ |
| `fn_calcular_arr`      | `@meses_periodo INT = 12`                        | segmento, ingreso_mensual, anual     |
| `fn_calcular_churn`    | `@dias_periodo INT = 90`                         | segmento, clientes, tasa_churn_pct   |
| `fn_pronostico_ventas` | `@meses_pronostico`, `@meses_historico`          | mes_pronostico, ingreso_pronosticado |
| `fn_analisis_cohortes` | `@metrica NVARCHAR (ingresos/ordenes/retencion)` | mes_cohorte, meses, valor, clientes  |

---

## Guía de Uso

### 1️⃣ Instalación Inicial

```sql
-- Ejecutar en orden sobre la base de datos destino:
-- 1. ss-01-schema.sql             → Tablas, triggers, SP de registro
-- 2. ss-02-vistas-y-funciones.sql → Vistas, funciones analíticas, SP de refresco
-- 3. ss-03-generacion-datos.sql   → SP y funciones de generación de datos
```

### 2️⃣ Generar Datos de Prueba

```sql
-- Opción A: Todo automático
EXEC dbo.sp_generar_todos_los_datos
    @clientes   = 500,
    @productos  = 200,
    @vendedores = 50,
    @ordenes    = 5000,
    @dias_atras = 365;

-- Opción B: Paso a paso (más control)
EXEC dbo.sp_generar_clientes   @cantidad = 500,  @limpiar = 1;
EXEC dbo.sp_generar_productos  @cantidad = 200,  @limpiar = 1;
EXEC dbo.sp_generar_vendedores @cantidad = 50,   @limpiar = 1;
EXEC dbo.sp_generar_ordenes    @cantidad_ordenes = 5000, @dias_atras = 365, @limpiar = 1;
EXEC dbo.sp_generar_pagos      @limpiar = 1;

-- Actualizar tablas de caché
EXEC dbo.sp_refrescar_vistas_materializadas;
```

### 3️⃣ Consultas Básicas

```sql
-- Ventas totales del mes
SELECT SUM(ingresos_totales)
FROM dbo.v_resumen_ventas_diario
WHERE fecha_venta >= DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);

-- Top 10 vendedores
SELECT TOP 10 nombre, ventas_totales, porcentaje_cumplimiento_cuota
FROM dbo.v_performance_vendedores
ORDER BY ventas_totales DESC;

-- Clientes con mayor valor de vida
SELECT TOP 20 nombre, valor_vida, segmento
FROM dbo.v_segmentacion_clientes
ORDER BY valor_vida DESC;

-- ARR por segmento
SELECT * FROM dbo.fn_calcular_arr(12) ORDER BY ingreso_anual DESC;

-- Pronóstico próximos 3 meses
SELECT * FROM dbo.fn_pronostico_ventas(3, 12) ORDER BY mes_pronostico;
```

### 4️⃣ Reset / Limpiar

```sql
-- Opción A: Regenerar todo
EXEC dbo.sp_generar_todos_los_datos @clientes=500, @productos=200, @vendedores=50, @ordenes=5000;

-- Opción B: Limpiar tablas en orden (respetar FK)
DELETE FROM dbo.items_orden;
DELETE FROM dbo.pagos;
DELETE FROM dbo.devoluciones;
DELETE FROM dbo.ordenes;
DELETE FROM dbo.clientes;

-- Opción C: Soft delete
UPDATE dbo.clientes
SET activo = 0
WHERE fecha_adquisicion < DATEADD(MONTH, -6, GETDATE());
```

---

## Optimizaciones

### Índices Incluidos

```sql
-- Dimensiones
CREATE INDEX idx_clientes_segmento          ON dbo.clientes  (segmento);
CREATE INDEX idx_clientes_activo            ON dbo.clientes  (activo);
CREATE INDEX idx_productos_categoria        ON dbo.productos (categoria);
CREATE INDEX idx_vendedores_equipo          ON dbo.vendedores (equipo);

-- Hechos
CREATE INDEX idx_ordenes_cliente_id         ON dbo.ordenes (cliente_id);
CREATE INDEX idx_ordenes_fecha_orden        ON dbo.ordenes (fecha_orden);
CREATE INDEX idx_ordenes_estado             ON dbo.ordenes (estado);
CREATE INDEX idx_items_orden_orden_id       ON dbo.items_orden (orden_id);
```

### Índices Adicionales Recomendados

```sql
-- Filtros compuestos frecuentes
CREATE INDEX idx_ordenes_fecha_estado
    ON dbo.ordenes (fecha_orden, estado)
    INCLUDE (monto_total, cliente_id);

CREATE INDEX idx_ordenes_estado_pago_fecha
    ON dbo.ordenes (estado_pago, fecha_orden)
    INCLUDE (monto_total);

-- Mejoran las vistas
CREATE INDEX idx_ordenes_cliente_fecha
    ON dbo.ordenes (cliente_id, fecha_orden)
    INCLUDE (monto_total, estado);

CREATE INDEX idx_items_orden_producto
    ON dbo.items_orden (producto_id)
    INCLUDE (orden_id, cantidad, total_linea, cantidad_devuelta);
```

### Mantenimiento

```sql
-- Actualizar estadísticas después de cargas masivas
UPDATE STATISTICS dbo.clientes;
UPDATE STATISTICS dbo.productos;
UPDATE STATISTICS dbo.ordenes;
UPDATE STATISTICS dbo.items_orden;

-- Rebuild de índices fragmentados
ALTER INDEX ALL ON dbo.ordenes    REBUILD;
ALTER INDEX ALL ON dbo.items_orden REBUILD;

-- Ver tamaño de tablas
SELECT
    t.name AS tabla,
    SUM(a.total_pages) * 8 / 1024.0 AS tamaño_mb,
    SUM(a.used_pages)  * 8 / 1024.0 AS usado_mb,
    SUM(p.rows)                      AS filas
FROM sys.tables t
JOIN sys.indexes      i ON t.object_id = i.object_id
JOIN sys.partitions   p ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.is_ms_shipped = 0 AND i.object_id > 255
GROUP BY t.name
ORDER BY tamaño_mb DESC;
```

### Tabla de Calendario (útil para Power BI)

```sql
-- Crear tabla de fechas para inteligencia temporal en Power BI
IF OBJECT_ID('dbo.calendario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.calendario (
        fecha         DATE PRIMARY KEY,
        anio          INT,
        mes           INT,
        dia           INT,
        anio_mes      NVARCHAR(7),
        nombre_dia    NVARCHAR(20),
        nombre_mes    NVARCHAR(20),
        es_fin_semana BIT
    );

    WITH fechas AS (
        SELECT CAST(DATEADD(YEAR, -3, GETDATE()) AS DATE) AS fecha
        UNION ALL
        SELECT DATEADD(DAY, 1, fecha)
        FROM fechas
        WHERE fecha < DATEADD(YEAR, 1, GETDATE())
    )
    INSERT INTO dbo.calendario
    SELECT
        fecha,
        YEAR(fecha),
        MONTH(fecha),
        DAY(fecha),
        FORMAT(fecha, 'yyyy-MM'),
        DATENAME(WEEKDAY, fecha),
        DATENAME(MONTH, fecha),
        CASE WHEN DATEPART(WEEKDAY, fecha) IN (1, 7) THEN 1 ELSE 0 END
    FROM fechas
    OPTION (MAXRECURSION 2000);
END;
```

---

## 📊 Integración con Power BI

### Conexión a SQL Server

1. **Obtener datos → SQL Server Database**
2. **Servidor:** `.\SQLEXPRESS` o nombre de instancia
3. **Base de datos:** `ventas_test`
4. **Modo:** Import (tablas pequeñas) o DirectQuery (tablas grandes)

### Recomendaciones

- Conectar directamente a las **vistas** en lugar de las tablas base
- Usar las **tablas de caché** (`mv_*`) para queries pesadas, refrescadas con SQL Agent
- Incluir la tabla `dbo.calendario` como dimensión de tiempo
- Para DirectQuery, asegurarse de que los índices cubran los filtros del dashboard

---

## 🔄 Ciclo de Vida Recomendado

| Entorno    | Clientes | Productos | Vendedores | Órdenes     |
| ---------- | -------- | --------- | ---------- | ----------- |
| Desarrollo | 500      | 200       | 50         | 5.000       |
| Testing    | 1.000    | 500       | 100        | 10.000      |
| Staging    | 5.000    | 1.000     | 200        | 50.000      |
| Producción | —        | —         | —          | Incremental |

---

Este schema está listo para producción en SQL Server 2016+ y soporta análisis complejos, reportería avanzada e integración con Power BI.
