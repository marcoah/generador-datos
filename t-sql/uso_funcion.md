# Guía de Uso - Funciones, Procedimientos y Vistas T-SQL

Ejemplos prácticos para usar los objetos definidos en `02-vistas-y-funciones.sql` y
`03-generacion-datos.sql`. Para el detalle de columnas y tablas base, ver
[DOCUMENTACION-SCHEMA.md](./DOCUMENTACION-SCHEMA.md).

## Índice

1. [Generación de datos de prueba](#1-generación-de-datos-de-prueba)
2. [Función auxiliar de nombres aleatorios](#2-función-auxiliar-de-nombres-aleatorios)
3. [Funciones analíticas de tabla](#3-funciones-analíticas-de-tabla)
4. [Vistas de análisis](#4-vistas-de-análisis)
5. [Tablas de caché y su refresco](#5-tablas-de-caché-y-su-refresco)

---

## 1. Generación de datos de prueba

Los procedimientos de `03-generacion-datos.sql` pueblan las tablas base con datos
realistas. Se pueden ejecutar por separado o todos juntos con el procedimiento maestro.

### 1.1 Generar todo de una vez (recomendado)

`dbo.sp_generar_todos_los_datos` ejecuta clientes → productos → vendedores → órdenes →
pagos, en ese orden (las órdenes dependen de clientes/productos/vendedores existentes),
y al final refresca las tablas de caché.

```sql
EXEC dbo.sp_generar_todos_los_datos
    @clientes   = 500,
    @productos  = 200,
    @vendedores = 50,
    @ordenes    = 5000,
    @dias_atras = 365;
```

Devuelve una tabla con el resumen de cada paso (registros creados y tiempo en segundos).

### 1.2 Generar tablas individuales

Útil para regenerar solo una parte sin borrar el resto (usar `@limpiar = 0` para
agregar en vez de reemplazar).

```sql
-- Clientes
EXEC dbo.sp_generar_clientes @cantidad = 500, @limpiar = 1;

-- Productos
EXEC dbo.sp_generar_productos @cantidad = 200, @limpiar = 1;

-- Vendedores (asigna gerentes al ~30% automáticamente)
EXEC dbo.sp_generar_vendedores @cantidad = 50, @limpiar = 1;

-- Órdenes + ítems de detalle (requiere clientes/productos/vendedores ya cargados)
EXEC dbo.sp_generar_ordenes @cantidad_ordenes = 5000, @dias_atras = 365, @limpiar = 1;

-- Pagos (requiere órdenes ya cargadas)
EXEC dbo.sp_generar_pagos @limpiar = 1;
```

> ⚠️ Orden de dependencia: `clientes`, `productos` y `vendedores` deben existir
> **antes** de correr `sp_generar_ordenes`, y las órdenes deben existir antes de
> `sp_generar_pagos`.

---

## 2. Función auxiliar de nombres aleatorios

`dbo.fn_nombre_por_indices` es una función de tabla que devuelve un nombre y apellido
a partir de un género (`'M'`/`'F'`) y dos índices (1-10) que seleccionan el nombre y el
apellido de listas fijas. No genera aleatoriedad por sí misma (SQL Server no permite
`NEWID()` dentro de una función escalar), por eso los índices se calculan afuera con
`CROSS APPLY` y `CHECKSUM(NEWID())`.

Así se usa dentro de `sp_generar_clientes` y `sp_generar_vendedores`:

```sql
SELECT nm.nombre_completo
FROM dbo.numeros num
CROSS APPLY (SELECT TOP 1 v FROM (VALUES('M'),('F')) g(v) ORDER BY CHECKSUM(NEWID(), num.n)) gen
CROSS APPLY (SELECT idx_n = (ABS(CHECKSUM(NEWID())) % 10) + 1,
                    idx_a = (ABS(CHECKSUM(NEWID())) % 10) + 1) idx
CROSS APPLY dbo.fn_nombre_por_indices(gen.v, idx.idx_n, idx.idx_a) nm;
```

### Generar N nombres aleatorios sueltos

```sql
SELECT TOP 20
    n.nombre_completo
FROM sys.objects o
CROSS APPLY dbo.fn_nombre_por_indices(
    CASE WHEN RAND(CHECKSUM(NEWID())) > 0.5 THEN 'M' ELSE 'F' END,
    (ABS(CHECKSUM(NEWID())) % 10) + 1,
    (ABS(CHECKSUM(NEWID())) % 10) + 1
) n;
```

`sys.objects` se usa solo como fuente de filas para repetir la generación N veces
(el `TOP 20` limita el resultado); no tiene relación con los nombres en sí.

### Llamar directamente con índices fijos

```sql
-- Nombre masculino, índice de nombre 3, índice de apellido 7
SELECT * FROM dbo.fn_nombre_por_indices('M', 3, 7);
```

---

## 3. Funciones analíticas de tabla

Definidas en `02-vistas-y-funciones.sql`, se consultan como cualquier tabla con
`SELECT * FROM dbo.fn_...(parámetros)`.

### 3.1 `dbo.fn_calcular_arr(@meses_periodo)`

Ingreso mensual y anual (ARR) promedio por segmento de cliente, en base a los últimos
`@meses_periodo` meses (default 12).

```sql
SELECT * FROM dbo.fn_calcular_arr(12)
ORDER BY ingreso_anual DESC;
```

### 3.2 `dbo.fn_calcular_churn(@dias_periodo)`

Tasa de abandono por segmento: clientes que compraron dentro de `@dias_periodo` días
(default 90) pero no volvieron a comprar en los últimos 30 días.

```sql
SELECT * FROM dbo.fn_calcular_churn(90)
ORDER BY tasa_churn_pct DESC;
```

### 3.3 `dbo.fn_pronostico_ventas(@meses_pronostico, @meses_historico)`

Proyecta ingresos futuros usando una regresión lineal simple calculada a mano
(SQL Server no tiene `REGR_SLOPE`/`REGR_INTERCEPT`), con base en `@meses_historico`
meses de histórico (default 12) para pronosticar `@meses_pronostico` meses hacia
adelante (default 3, máximo interno 6).

```sql
SELECT * FROM dbo.fn_pronostico_ventas(3, 12)
ORDER BY mes_pronostico;
```

### 3.4 `dbo.fn_analisis_cohortes(@metrica)`

Agrupa clientes por mes de primera compra ("cohorte") y mide su comportamiento en los
meses siguientes. `@metrica` acepta `'ingresos'`, `'ordenes'` o cualquier otro valor
(cuenta clientes, usado también para `'retencion'`).

```sql
-- Ingresos por cohorte y mes transcurrido
SELECT * FROM dbo.fn_analisis_cohortes('ingresos')
ORDER BY mes_cohorte, meses_transcurridos;

-- Retención de clientes por cohorte
SELECT * FROM dbo.fn_analisis_cohortes('retencion')
ORDER BY mes_cohorte, meses_transcurridos;
```

Tip para armar una matriz de retención tipo pivot (mes cohorte x mes transcurrido):

```sql
SELECT mes_cohorte,
       [0], [1], [2], [3], [4], [5]
FROM dbo.fn_analisis_cohortes('retencion')
PIVOT (
    SUM(cantidad_clientes) FOR meses_transcurridos IN ([0],[1],[2],[3],[4],[5])
) p
ORDER BY mes_cohorte;
```

---

## 4. Vistas de análisis

Se consultan directamente con `SELECT`, sin parámetros. Todas filtran por una ventana
de tiempo razonable (1-2 años) para mantener el rendimiento.

| Vista                         | Contenido                                                             |
| ------------------------------ | ----------------------------------------------------------------------- |
| `dbo.v_resumen_ventas_diario`  | Órdenes, ingresos, descuentos e impuestos agregados por día            |
| `dbo.v_ventas_por_categoria`   | Ingresos, costo, margen y devoluciones por categoría/subcategoría      |
| `dbo.v_performance_vendedores` | Ventas, comisión y cumplimiento de cuota por vendedor activo           |
| `dbo.v_segmentacion_clientes`  | Valor de vida, recencia y frecuencia de compra por cliente activo      |
| `dbo.v_analisis_devoluciones`  | Devoluciones y montos reembolsados por día, categoría y motivo         |
| `dbo.v_analisis_pagos`         | Cobros, pagos fallidos y atrasos (30/60 días) por método de pago       |
| `dbo.v_performance_campanas`   | CTR, conversión, ROI y costo por conversión de campañas de marketing   |

Ejemplos:

```sql
-- Tendencia de ventas de los últimos 30 días
SELECT * FROM dbo.v_resumen_ventas_diario
WHERE fecha_venta >= DATEADD(DAY, -30, GETDATE())
ORDER BY fecha_venta;

-- Ranking de vendedores por cumplimiento de cuota del mes
SELECT nombre, equipo, ventas_mes_actual, porcentaje_cumplimiento_cuota
FROM dbo.v_performance_vendedores
ORDER BY porcentaje_cumplimiento_cuota DESC;

-- Clientes en riesgo (sin compras hace más de 60 días)
SELECT nombre, segmento, valor_vida, dias_desde_ultima_compra
FROM dbo.v_segmentacion_clientes
WHERE dias_desde_ultima_compra > 60
ORDER BY valor_vida DESC;
```

---

## 5. Tablas de caché y su refresco

SQL Server no soporta vistas materializadas de propósito general, así que
`mv_tendencia_ventas_mensual` y `mv_top_productos_por_categoria` son tablas normales
que se recalculan con `dbo.sp_refrescar_vistas_materializadas`.

```sql
EXEC dbo.sp_refrescar_vistas_materializadas;

-- Luego se consultan como tablas normales
SELECT * FROM dbo.mv_tendencia_ventas_mensual ORDER BY mes DESC;
SELECT * FROM dbo.mv_top_productos_por_categoria WHERE ranking_categoria <= 5;
```

Este procedimiento ya se ejecuta automáticamente al final de
`sp_generar_todos_los_datos`. Ejecutarlo manualmente solo es necesario si se cargan o
modifican datos por fuera de ese flujo (por ejemplo, tras `sp_generar_ordenes` suelto).
