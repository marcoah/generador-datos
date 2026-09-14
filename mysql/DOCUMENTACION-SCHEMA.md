# Schema de Base de Datos - Sistema de Ventas para Dashboards (MySQL)

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Estructura de Tablas](#estructura-de-tablas)
3. [Relaciones y Claves Foráneas](#relaciones-y-claves-foráneas)
4. [Diccionario de Datos](#diccionario-de-datos)
5. [Vistas Analíticas](#vistas-analíticas)
6. [Procedimientos de Generación](#procedimientos-de-generación)
7. [Guía de Uso](#guía-de-uso)
8. [Optimizaciones](#optimizaciones)
9. [Diferencias con PostgreSQL / T-SQL](#diferencias-con-postgresql--t-sql)

---

## Visión General

Este schema (MySQL 8.0+) está diseñado para:

- ✅ Generar datos realistas de ventas para testing
- ✅ Soportar análisis complejos en Power BI
- ✅ Facilitar dashboards customizados en código (Vue.js, etc.)
- ✅ Ser escalable y fácil de resetear

Es el equivalente funcional de los schemas de `postgreSQL/` y `t-sql/`, adaptado a las capacidades de MySQL (ver [Diferencias con PostgreSQL / T-SQL](#diferencias-con-postgresql--t-sql)).

### Arquitectura de Datos

```
DIMENSIONES (Contexto)
├── clientes
├── productos
└── vendedores

HECHOS (Transacciones)
├── orden_encabezado
├── orden_detalles
├── pagos
└── devoluciones

RELACIÓN (Marketing)
├── campanas
└── campanas_clientes

INTERACCIÓN (CRM)
└── interacciones_clientes

AUDITORÍA
└── cargas_datos
```

---

## Estructura de Tablas

### 📊 CLIENTES

**Propósito:** Información completa de clientes

| Columna              | Tipo         | Descripción                                    |
| --------------------- | ------------ | ----------------------------------------------- |
| id                    | BIGINT UNSIGNED AUTO_INCREMENT | PK                             |
| uuid                  | CHAR(36)     | Identificador único universal (`DEFAULT (UUID())`) |
| nombre                | VARCHAR(255) | Nombre completo del cliente                    |
| email                 | VARCHAR(255) | Email único                                    |
| telefono              | VARCHAR(20)  | Teléfono de contacto                           |
| segmento              | VARCHAR(50)  | premium, estandar, prueba, vip, inactivo       |
| industria             | VARCHAR(100) | Sector (Tecnología, Finanzas, Salud, etc.)     |
| tamano_empresa        | VARCHAR(50)  | startup, pequeña, mediana, grande, corporacion |
| pais                  | VARCHAR(100) | País                                           |
| provincia             | VARCHAR(100) | Provincia / Estado                             |
| ciudad                | VARCHAR(100) | Ciudad                                         |
| codigo_postal         | VARCHAR(20)  | Código postal                                  |
| limite_credito        | DECIMAL(15,2)| Límite de crédito                              |
| valor_vida_total      | DECIMAL(15,2)| Calculado automáticamente vía triggers         |
| fecha_adquisicion     | DATETIME     | Fecha de alta del cliente                      |
| fecha_ultima_compra   | DATETIME     | Última compra (actualizada por trigger)        |
| activo                | TINYINT(1)   | Estado activo / inactivo                       |

**Índices Principales:** segmento, pais, activo, fecha_adquisicion

---

### 📦 PRODUCTOS

**Propósito:** Catálogo de productos

| Columna                | Tipo          | Descripción                                     |
| ----------------------- | ------------- | ------------------------------------------------ |
| id                      | BIGINT UNSIGNED AUTO_INCREMENT | PK                               |
| sku                     | VARCHAR(50)   | Código único de producto (UNIQUE)               |
| nombre                  | VARCHAR(255)  | Nombre del producto                             |
| categoria               | VARCHAR(100)  | Categoría (Electrónica, Software, Servicios...) |
| subcategoria            | VARCHAR(100)  | Subcategoría                                    |
| marca                   | VARCHAR(100)  | Marca                                           |
| precio_lista            | DECIMAL(10,2) | Precio de venta al público                      |
| precio_costo            | DECIMAL(10,2) | Costo de adquisición                            |
| stock_actual            | INT           | Stock disponible                                |
| stock_minimo            | INT           | Nivel mínimo de reposición                      |
| peso_kg / volumen_m3    | DECIMAL       | Propiedades físicas del producto                |
| es_digital              | TINYINT(1)    | Producto digital / físico                       |
| activo                  | TINYINT(1)    | Producto activo                                 |
| fecha_lanzamiento       | DATE          | Fecha de lanzamiento                            |
| fecha_descontinuacion   | DATE          | Fecha de discontinuación                        |

**Índices Principales:** sku, categoria, marca, activo

**Cálculo de Margen:**

```sql
margen_pct = (precio_lista - precio_costo) / precio_lista * 100
```

---

### 👤 VENDEDORES

**Propósito:** Datos de vendedores y performance

| Columna            | Tipo          | Descripción                              |
| ------------------ | ------------- | ----------------------------------------- |
| id                 | BIGINT UNSIGNED AUTO_INCREMENT | PK                       |
| equipo             | VARCHAR(100)  | Equipo (Empresas, PyMEs, Startups, etc.) |
| territorio         | VARCHAR(100)  | Territorio (Norte, Sur, Este, etc.)      |
| gerente_id         | BIGINT UNSIGNED | FK a vendedor gerente (autorreferencia) |
| tasa_comision      | DECIMAL(5,2)  | Porcentaje de comisión                   |
| cuota_mensual      | DECIMAL(15,2) | Cuota de ventas mensual                  |
| activo             | TINYINT(1)    | Vendedor activo                          |
| fecha_contratacion | DATE          | Fecha de ingreso                         |
| fecha_baja         | DATE          | Fecha de baja                            |

**Índices Principales:** equipo, territorio, activo, gerente_id

---

### 📋 ORDEN_ENCABEZADO (Tabla de Hechos Principal)

**Propósito:** Registro de todas las órdenes de ventas

| Columna              | Tipo          | Descripción                                                                |
| --------------------- | ------------- | ----------------------------------------------------------------------------- |
| id                    | BIGINT UNSIGNED AUTO_INCREMENT | PK                                                       |
| cliente_id            | BIGINT UNSIGNED | FK → clientes                                                          |
| vendedor_id           | BIGINT UNSIGNED | FK → vendedores (nullable)                                             |
| fecha_orden           | DATETIME      | Fecha de la orden                                                          |
| estado                | VARCHAR(50)   | pendiente, confirmado, procesando, enviado, entregado, cancelado, devuelto |
| subtotal              | DECIMAL(15,2) | Suma antes de descuentos                                                   |
| monto_descuento       | DECIMAL(15,2) | Monto de descuento                                                         |
| porcentaje_descuento  | DECIMAL(5,2)  | Porcentaje de descuento                                                    |
| monto_impuesto        | DECIMAL(15,2) | Impuestos                                                                  |
| costo_envio           | DECIMAL(15,2) | Costo de envío                                                             |
| monto_total           | DECIMAL(15,2) | **Total = SUM(total_linea) + impuesto + envío - descuento (vía trigger)**  |
| metodo_pago           | VARCHAR(50)   | tarjeta_credito, transferencia_bancaria, efectivo, cheque, otro           |
| estado_pago           | VARCHAR(50)   | pendiente, parcial, pagado, vencido, reembolsado                          |
| notas                 | TEXT          | Notas visibles al cliente                                                  |
| notas_internas        | TEXT          | Notas internas del equipo                                                  |

**Índices:** cliente_id, vendedor_id, fecha_orden, estado, estado_pago, creado_en

**Triggers Asociados** (MySQL no permite un solo trigger para múltiples eventos, por lo que se implementan por separado):

- `trg_orden_detalles_ai_total` / `_au_total` / `_ad_total`: Recalculan `monto_total` cuando se inserta, actualiza o elimina un ítem
- `trg_orden_encabezado_ai_valor_vida` / `_au_valor_vida`: Actualizan `valor_vida_total` y `fecha_ultima_compra` del cliente

---

### 🔗 ORDEN_DETALLES

**Propósito:** Detalles de cada línea de una orden

| Columna              | Tipo          | Descripción                                                 |
| --------------------- | ------------- | ------------------------------------------------------------- |
| id                    | BIGINT UNSIGNED AUTO_INCREMENT | PK                                           |
| orden_id              | BIGINT UNSIGNED | FK → orden_encabezado (ON DELETE CASCADE)                 |
| producto_id           | BIGINT UNSIGNED | FK → productos                                             |
| cantidad              | INT           | Cantidad pedida (CHECK cantidad > 0)                           |
| precio_unitario       | DECIMAL(10,2) | Precio unitario al momento de la venta                      |
| porcentaje_descuento  | DECIMAL(5,2)  | Descuento por línea                                          |
| total_linea           | DECIMAL(15,2) | **GENERATED ALWAYS AS (cantidad × precio_unitario × (1 − descuento%)) STORED** |
| ubicacion_almacen     | VARCHAR(100)  | Ubicación en almacén                                          |
| completado            | TINYINT(1)    | ¿Línea despachada?                                             |
| cantidad_devuelta     | INT           | Cantidad devuelta                                              |
| motivo_devolucion     | VARCHAR(255)  | Razón de la devolución                                         |

**Características:**

- `total_linea` es una columna `GENERATED ALWAYS AS (...) STORED` (soportado desde MySQL 5.7.6)
- Índices en orden_id, producto_id y completado para queries rápidas

---

### 💳 PAGOS

**Propósito:** Registro de transacciones de pago

| Columna           | Tipo          | Descripción                        |
| ------------------ | ------------- | ------------------------------------ |
| id                 | BIGINT UNSIGNED AUTO_INCREMENT | PK                    |
| orden_id           | BIGINT UNSIGNED | FK → orden_encabezado             |
| monto              | DECIMAL(15,2) | Monto pagado                       |
| fecha_pago         | DATETIME      | Fecha del pago                     |
| metodo_pago        | VARCHAR(50)   | Método utilizado                   |
| estado             | VARCHAR(50)   | pendiente, completado, fallido, reembolsado |
| numero_referencia  | VARCHAR(100)  | Número de referencia / comprobante |

**Nota:** Una orden puede tener múltiples pagos (pagos parciales).

---

### 🔙 DEVOLUCIONES

**Propósito:** Registro de devoluciones y reembolsos

| Columna          | Tipo          | Descripción                                                    |
| ----------------- | ------------- | ------------------------------------------------------------------ |
| id                | BIGINT UNSIGNED AUTO_INCREMENT | PK                                             |
| orden_id          | BIGINT UNSIGNED | FK → orden_encabezado                                          |
| fecha_devolucion  | DATETIME      | Fecha de solicitud                                                 |
| motivo            | VARCHAR(255)  | Motivo (defectuoso, producto_incorrecto, etc.)                    |
| monto_reembolso   | DECIMAL(15,2) | Monto a reembolsar                                                 |
| fecha_reembolso   | DATETIME      | Fecha en que se efectuó el reembolso                               |
| estado            | VARCHAR(50)   | pendiente, aprobado, rechazado, reembolsado, reembolso_parcial    |
| aprobado_por      | VARCHAR(100)  | Usuario que aprobó la devolución                                   |

---

### 📧 INTERACCIONES_CLIENTES

**Propósito:** CRM - Registro de contactos y seguimientos

| Columna                   | Tipo         | Descripción                                      |
| --------------------------- | ------------ | --------------------------------------------------- |
| id                          | BIGINT UNSIGNED AUTO_INCREMENT | PK                                |
| cliente_id                  | BIGINT UNSIGNED | FK → clientes (ON DELETE CASCADE)              |
| vendedor_id                 | BIGINT UNSIGNED | FK → vendedores                                |
| tipo_interaccion            | VARCHAR(50)  | llamada, email, reunion, demo, soporte, seguimiento |
| asunto                      | VARCHAR(255) | Asunto de la interacción                         |
| resultado                   | VARCHAR(100) | interesado, no_interesado, demo_programada, etc. |
| fecha_proximo_seguimiento   | DATE         | Próximo seguimiento programado                   |
| fecha_interaccion           | DATETIME     | Fecha del contacto                               |
| duracion_minutos            | INT          | Duración en minutos                              |

---

### 📣 CAMPANAS & CAMPANAS_CLIENTES

**Propósito:** Marketing y relación con clientes

**CAMPANAS:**

| Columna            | Descripción                                    |
| ------------------- | ------------------------------------------------- |
| nombre              | Nombre de la campaña                              |
| tipo_campana        | email, webinar, feria, promocion, estacional      |
| canal                | email, redes_sociales, correo_directo, eventos, referido, organico |
| fecha_inicio/fin    | Período de la campaña                             |
| presupuesto         | Presupuesto asignado                              |
| gasto_real          | Gasto efectivamente ejecutado                     |
| impresiones/clics   | Métricas de alcance                               |
| conversiones        | Cantidad de conversiones                          |
| ingresos_generados  | Ingresos atribuibles a la campaña                 |
| estado              | planificada, activa, completada, cancelada        |

**CAMPANAS_CLIENTES:**

| Columna         | Descripción                   |
| ---------------- | -------------------------------- |
| campana_id       | FK → campanas (ON DELETE CASCADE) |
| cliente_id       | FK → clientes (ON DELETE CASCADE) |
| fecha_contacto   | Cuándo se realizó el contacto |
| abierto          | Si abrió el mensaje           |
| hizo_clic        | Si hizo clic en el enlace     |
| convirtio        | Si se concretó la conversión  |
| fecha_conversion | Cuándo se concretó la conversión |

---

### 🧾 CARGAS_DATOS (Auditoría)

**Propósito:** Registro de ejecuciones de carga/generación de datos (tabla adicional respecto a PostgreSQL/T-SQL)

| Columna              | Descripción                                  |
| --------------------- | ------------------------------------------------ |
| fecha_carga           | Fecha/hora de la carga                        |
| tipo_carga            | inicial, incremental, refresco, prueba        |
| registros_afectados   | Cantidad de registros procesados               |
| estado                | Resultado de la carga                          |
| notas                 | Observaciones libres                           |

Se inserta mediante el procedimiento `sp_registrar_carga_datos(p_tipo_carga, p_registros_afectados, p_estado, p_notas)`.

---

## Relaciones y Claves Foráneas

### Diagrama de Relaciones

```
clientes ◄──────┬────► orden_encabezado ──► orden_detalles ◄─── productos
                │        ▲
                │        │
                ├──────────► pagos
                │
                ├──────────► devoluciones
                │
                ├──────────► interacciones_clientes ◄─── vendedores
                │
                └──────────► campanas_clientes ◄──── campanas

vendedores ────────────────────────► orden_encabezado
                ▲
                │
                └─ gerente_id (autorreferencia)
```

### Integridad Referencial

- **RESTRICT (default de InnoDB):** clientes, productos (no se eliminan si tienen órdenes)
- **ON DELETE CASCADE:** orden_detalles, interacciones_clientes, campanas_clientes
- **ON DELETE SET NULL:** gerente_id en vendedores (si se borra el gerente, queda NULL)

---

## Diccionario de Datos

### Enumeraciones

**orden_encabezado.estado:**

```
pendiente    → Pendiente de confirmar
confirmado   → Confirmada por cliente
procesando   → En proceso de preparación
enviado      → Enviada
entregado    → Entregada y recibida
cancelado    → Cancelada
devuelto     → Devuelta
```

**orden_encabezado.estado_pago:**

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

**clientes.tamano_empresa:**

```
startup      → Menos de 10 empleados
pequeña      → 10-50 empleados
mediana      → 50-500 empleados
grande       → 500-5000 empleados
corporacion  → Más de 5000 empleados
```

**orden_encabezado.metodo_pago:**

```
tarjeta_credito        → Tarjeta de crédito/débito
transferencia_bancaria → Transferencia bancaria
efectivo               → Pago en efectivo
cheque                 → Pago con cheque
otro                    → Otro método
```

**devoluciones.estado:**

```
pendiente          → Solicitud registrada
aprobado           → Devolución aprobada
rechazado          → Devolución rechazada
reembolsado        → Reembolso completado
reembolso_parcial  → Reembolso parcial efectuado
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
WHERE fecha_venta >= DATE_FORMAT(CURRENT_DATE, '%Y-%m-01')
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

- segmento, industria, tamano_empresa
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

### Tablas de Caché (equivalente a Vistas Materializadas)

MySQL no soporta `MATERIALIZED VIEW`. El mismo patrón usado en `t-sql/` se replica aquí: tablas físicas + procedimiento de refresco.

#### mv_tendencia_ventas_mensual

Tendencia mensual de ventas. Se refresca llamando a `sp_refrescar_vistas_materializadas()`.

```sql
SELECT * FROM mv_tendencia_ventas_mensual
WHERE anio >= YEAR(CURRENT_DATE) - 1;
```

#### mv_top_productos_por_categoria

Top productos por categoría con ranking (`ROW_NUMBER()`).

```sql
SELECT * FROM mv_top_productos_por_categoria
WHERE ranking_categoria <= 10;
```

---

## Procedimientos de Generación

> **Nota:** MySQL no permite operaciones DML (INSERT/UPDATE/DELETE) dentro de `FUNCTION`, ni funciones de tabla. Por eso, a diferencia de PostgreSQL/T-SQL (que exponen `SELECT * FROM generar_...(...)`), en MySQL todo se implementa como `PROCEDURE` y se invoca con `CALL`.

### 🚀 Procedimiento Principal: sp_generar_todos_los_datos()

Genera todo el dataset de prueba de una sola vez.

**Sintaxis:**

```sql
CALL sp_generar_todos_los_datos(
    500,   -- p_clientes
    200,   -- p_productos
    50,    -- p_vendedores
    5000,  -- p_ordenes
    365    -- p_dias_atras
);
```

Internamente encadena `sp_generar_clientes`, `sp_generar_productos`, `sp_generar_vendedores`, `sp_generar_ordenes`, `sp_generar_pagos` y `sp_refrescar_vistas_materializadas`, y devuelve un resumen final:

```
clientes | productos | vendedores | ordenes | items | pagos
---------|-----------|------------|---------|-------|------
500      | 200       | 50         | 5000    | 7500  | 3800
```

### Procedimientos Individuales

#### sp_generar_clientes(p_cantidad INT, p_limpiar TINYINT)

```sql
CALL sp_generar_clientes(1000, 1);
```

#### sp_generar_productos(p_cantidad INT, p_limpiar TINYINT)

```sql
CALL sp_generar_productos(500, 1);
```

#### sp_generar_vendedores(p_cantidad INT, p_limpiar TINYINT)

```sql
CALL sp_generar_vendedores(100, 1);
```

#### sp_generar_ordenes(p_cantidad_ordenes INT, p_dias_atras INT, p_limpiar TINYINT)

```sql
CALL sp_generar_ordenes(10000, 365, 1);
```

#### sp_generar_pagos(p_limpiar TINYINT)

```sql
CALL sp_generar_pagos(1);
```

#### sp_refrescar_vistas_materializadas()

Recalcula las tablas de caché `mv_tendencia_ventas_mensual` y `mv_top_productos_por_categoria`.

```sql
CALL sp_refrescar_vistas_materializadas();
```

#### sp_registrar_carga_datos(p_tipo_carga, p_registros_afectados, p_estado, p_notas)

Inserta un registro de auditoría en `cargas_datos`.

```sql
CALL sp_registrar_carga_datos('inicial', 5000, 'completado', 'Carga de datos de prueba');
```

### Procedimientos Analíticos

#### sp_calcular_arr(p_meses_periodo INT)

Calcula el Ingreso Anual Recurrente por segmento.

```sql
CALL sp_calcular_arr(12);
```

#### sp_calcular_churn(p_dias_periodo INT)

Calcula la tasa de abandono de clientes por segmento.

```sql
CALL sp_calcular_churn(90);
```

#### sp_pronostico_ventas(p_meses_pronostico INT, p_meses_historico INT)

Genera un pronóstico de ingresos con tendencia lineal (regresión calculada manualmente, ya que MySQL no tiene `REGR_SLOPE`/`REGR_INTERCEPT`), usando un CTE recursivo para proyectar los meses futuros.

```sql
CALL sp_pronostico_ventas(3, 12);
```

#### sp_analisis_cohortes(p_metrica VARCHAR(20))

Análisis de cohortes por mes de primera compra.

```sql
CALL sp_analisis_cohortes('ingresos');
-- Métricas: 'ingresos', 'ordenes' (cualquier otro valor cuenta clientes)
```

---

## Guía de Uso

### 1️⃣ Instalación Inicial

```sql
-- Ejecutar en orden (por ejemplo con: mysql -u usuario -p < 01-schema.sql):
SOURCE 01-schema.sql;             -- Crear BD, tablas, triggers y procedimiento de auditoría
SOURCE 02-vistas-y-funciones.sql; -- Vistas, tablas de caché y procedimientos analíticos
SOURCE 03-generacion-datos.sql;   -- Procedimientos de generación de datos
```

### 2️⃣ Generar Datos de Prueba

```sql
-- Opción A: Todo automático
CALL sp_generar_todos_los_datos(500, 200, 50, 5000, 365);

-- Opción B: Paso a paso (más control)
CALL sp_generar_clientes(500, 1);
CALL sp_generar_productos(200, 1);
CALL sp_generar_vendedores(50, 1);
CALL sp_generar_ordenes(5000, 365, 1);
CALL sp_generar_pagos(1);

-- Actualizar tablas de caché
CALL sp_refrescar_vistas_materializadas();
```

### 3️⃣ Consultas Básicas

```sql
-- Ventas totales del mes
SELECT SUM(ingresos_totales) FROM v_resumen_ventas_diario
WHERE fecha_venta >= DATE_FORMAT(CURRENT_DATE, '%Y-%m-01');

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
WHERE fecha_fin >= CURRENT_DATE - INTERVAL 3 MONTH
ORDER BY roi DESC;
```

### 4️⃣ Reset / Limpiar

```sql
-- Opción A: Limpiar y regenerar completamente
CALL sp_generar_todos_los_datos(500, 200, 50, 5000, 365);

-- Opción B: Limpiar tablas específicas
DELETE FROM orden_encabezado;     -- Cascade elimina orden_detalles y relacionados
DELETE FROM clientes;

-- Opción C: Desactivar clientes (soft delete)
UPDATE clientes
SET activo = 0
WHERE fecha_adquisicion < CURRENT_DATE - INTERVAL 6 MONTH;
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
CREATE INDEX idx_orden_encabezado_cliente_id ON orden_encabezado(cliente_id);
CREATE INDEX idx_orden_encabezado_fecha_orden ON orden_encabezado(fecha_orden);
CREATE INDEX idx_orden_encabezado_estado ON orden_encabezado(estado);
CREATE INDEX idx_orden_detalles_orden_id ON orden_detalles(orden_id);
```

### Índices Adicionales Recomendados para Analítica

```sql
-- Filtros compuestos frecuentes en dashboards
CREATE INDEX idx_orden_encabezado_fecha_estado ON orden_encabezado(fecha_orden, estado);
CREATE INDEX idx_orden_encabezado_estado_pago_fecha ON orden_encabezado(estado_pago, fecha_orden);

-- Mejoran queries de vistas
CREATE INDEX idx_orden_encabezado_cliente_fecha ON orden_encabezado(cliente_id, fecha_orden);
CREATE INDEX idx_orden_detalles_producto_completado ON orden_detalles(producto_id, completado);

-- Para agregaciones
CREATE INDEX idx_orden_detalles_orden_total ON orden_detalles(orden_id, total_linea);
```

### Mantenimiento

```sql
-- Analizar tablas después de cargas masivas
ANALYZE TABLE clientes, productos, orden_encabezado, orden_detalles;

-- Ver tamaño de tablas
SELECT table_name AS tabla,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS tamano_mb
FROM information_schema.tables
WHERE table_schema = 'ventas_test'
ORDER BY (data_length + index_length) DESC;

-- Optimizar
OPTIMIZE TABLE orden_encabezado, orden_detalles;
```

### Performance para Dashboards

```sql
-- Query rápida para KPIs del dashboard principal
SELECT
    (SELECT COUNT(*) FROM orden_encabezado WHERE fecha_orden >= CURRENT_DATE - INTERVAL 30 DAY) AS ordenes_30d,
    (SELECT SUM(monto_total) FROM orden_encabezado WHERE fecha_orden >= CURRENT_DATE - INTERVAL 30 DAY) AS ingresos_30d,
    (SELECT COUNT(DISTINCT cliente_id) FROM orden_encabezado WHERE fecha_orden >= CURRENT_DATE - INTERVAL 30 DAY) AS clientes_30d,
    (SELECT AVG(monto_total) FROM orden_encabezado WHERE fecha_orden >= CURRENT_DATE - INTERVAL 30 DAY) AS promedio_30d;

-- Cache con CTE (evita cálculos repetidos)
WITH datos_mensuales AS (
    SELECT DATE_FORMAT(fecha_orden, '%Y-%m-01') AS mes, SUM(monto_total) AS ingresos
    FROM orden_encabezado
    GROUP BY mes
)
SELECT * FROM datos_mensuales WHERE mes >= CURRENT_DATE - INTERVAL 12 MONTH;
```

---

## 📊 Integración con Power BI / Dashboards

### Conexión MySQL en Power BI

1. **Obtener datos → Base de datos MySQL** (requiere el conector MySQL de Power BI / Oracle MySQL Connector .NET)
2. **Servidor:** localhost (o tu servidor), puerto 3306
3. **Base de datos:** ventas_test
4. **Usar DirectQuery para tablas grandes**

### Recomendaciones

- Usar vistas en lugar de tablas directamente
- Usar las tablas de caché (`mv_*`) para queries pesadas y programar `CALL sp_refrescar_vistas_materializadas()` periódicamente (evento/cron)
- Actualizar la caché cada noche en horario de bajo tráfico
- Crear tabla de calendario si se necesita inteligencia de tiempo

```sql
-- Tabla de calendario (útil para Power BI)
CREATE TABLE calendario (
    fecha DATE PRIMARY KEY,
    anio INT,
    mes INT,
    dia INT,
    anio_mes CHAR(7),
    dia_semana_num INT,
    nombre_dia VARCHAR(20),
    nombre_mes VARCHAR(20),
    es_fin_semana TINYINT(1)
);
```

---

## 🔄 Ciclo de Vida Recomendado

1. **Desarrollo:** `sp_generar_todos_los_datos()` con 500 clientes, 200 productos
2. **Testing:** 5.000-10.000 órdenes para verificar performance
3. **Staging:** 50.000+ órdenes para simular carga real
4. **Producción:** Cargas incrementales, no resets destructivos

---

## Diferencias con PostgreSQL / T-SQL

| Aspecto                        | PostgreSQL / T-SQL                       | MySQL                                                        |
| -------------------------------- | ------------------------------------------- | ---------------------------------------------------------------- |
| PK autoincremental                | BIGSERIAL / IDENTITY                        | `BIGINT UNSIGNED AUTO_INCREMENT`                                 |
| UUID                              | Tipo nativo `UUID`                          | `CHAR(36) DEFAULT (UUID())`                                      |
| Decimales                         | `NUMERIC`                                   | `DECIMAL`                                                        |
| Booleanos                         | `BOOLEAN`                                   | `TINYINT(1)` (0/1)                                               |
| Columna calculada                 | `GENERATED ALWAYS AS (...) STORED`          | Igual, soportado desde MySQL 5.7.6                               |
| Funciones de tabla                | `FUNCTION ... RETURNS TABLE`, `SELECT * FROM func(...)` | No soportadas → se usan `PROCEDURE` + `CALL sp_func(...)` |
| Vistas materializadas             | `MATERIALIZED VIEW` / tablas + refresh (T-SQL) | No soportadas → tablas `mv_*` + `sp_refrescar_vistas_materializadas()` |
| Trigger multi-evento              | Un solo trigger para INSERT/UPDATE/DELETE   | Un trigger por evento (`_ai_`, `_au_`, `_ad_`)                   |
| Tabla de auditoría `cargas_datos` | No presente                                 | Incluida, con `sp_registrar_carga_datos(...)`                    |

---

Este schema está listo para producción y soporta análisis complejos, reportería avanzada y machine learning.
