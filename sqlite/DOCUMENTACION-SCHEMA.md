# Schema de Base de Datos - Sistema de Ventas para Dashboards (SQLite)

## 📋 Tabla de Contenidos

1. [Visión General](#visión-general)
2. [Instalación de SQLite](#instalación-de-sqlite)
3. [Estructura de Tablas](#estructura-de-tablas)
4. [Relaciones y Claves Foráneas](#relaciones-y-claves-foráneas)
5. [Diccionario de Datos](#diccionario-de-datos)
6. [Vistas Analíticas](#vistas-analíticas)
7. [Generación de Datos](#generación-de-datos)
8. [Guía de Uso](#guía-de-uso)
9. [Optimizaciones](#optimizaciones)
10. [Diferencias con PostgreSQL / T-SQL / MySQL](#diferencias-con-postgresql--t-sql--mysql)

---

## Visión General

Este schema (SQLite 3.35+, algunas queries de `04-queries-ejemplo.sql` requieren 3.39+ por `FULL OUTER JOIN`) está diseñado para:

- ✅ Generar datos realistas de ventas para testing
- ✅ Soportar análisis complejos en Power BI
- ✅ Facilitar dashboards customizados en código (Vue.js, etc.)
- ✅ Correr sin servidor: todo vive en un único archivo `.db`

Es el equivalente funcional de los schemas de `postgreSQL/`, `mysql/` y `t-sql/`, adaptado a las limitaciones de SQLite (ver [Diferencias con PostgreSQL / T-SQL / MySQL](#diferencias-con-postgresql--t-sql--mysql)).

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

## Instalación de SQLite

SQLite no requiere un servidor: el binario `sqlite3` (CLI) crea y abre el archivo de base de datos directamente. Elegí tu sistema operativo:

### Windows

1. Descargá el paquete **`sqlite-tools-win-x64-*.zip`** desde [sqlite.org/download.html](https://sqlite.org/download.html) (sección "Precompiled Binaries for Windows").
2. Descomprimilo en una carpeta, por ejemplo `C:\sqlite`.
3. Agregá esa carpeta al `PATH` del sistema (Panel de control → Sistema → Configuración avanzada → Variables de entorno) o simplemente ejecutá `sqlite3.exe` con la ruta completa.
4. Verificá la instalación:

   ```powershell
   sqlite3 --version
   ```

   Alternativa rápida sin instalar nada: si tenés **Git Bash** o **WSL**, en muchas distros Linux `sqlite3` ya viene instalado o se agrega con `sudo apt install sqlite3`.

### macOS

SQLite viene preinstalado en macOS. Para tener la última versión (recomendado, por las columnas `GENERATED` y `FULL OUTER JOIN`):

```bash
brew install sqlite3
```

### Linux (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install sqlite3
```

Para otras distros: `sudo dnf install sqlite` (Fedora) o `sudo pacman -S sqlite` (Arch).

### Herramienta gráfica (opcional)

Si preferís una GUI en vez de la línea de comandos, [DB Browser for SQLite](https://sqlitebrowser.org/) permite abrir el `.db`, ejecutar los scripts `.sql` (pestaña "Execute SQL") y explorar las tablas/vistas visualmente. También podés usar la extensión **SQLite** de VS Code o DBeaver.

---

## Estructura de Tablas

### 📊 CLIENTES

**Propósito:** Información completa de clientes

| Columna              | Tipo    | Descripción                                    |
| --------------------- | ------- | ----------------------------------------------- |
| id                    | INTEGER | PK (`AUTOINCREMENT`)                            |
| uuid                  | TEXT    | UUID v4 generado por `DEFAULT` con `randomblob`  |
| nombre                | VARCHAR(255) | Nombre completo del cliente                |
| email                 | VARCHAR(255) | Email único                                |
| telefono              | VARCHAR(20)  | Teléfono de contacto                       |
| segmento              | VARCHAR(50)  | premium, estandar, prueba, vip, inactivo   |
| industria             | VARCHAR(100) | Sector (Tecnología, Finanzas, Salud, etc.) |
| tamano_empresa        | VARCHAR(50)  | startup, pequeña, mediana, grande, corporacion |
| pais                  | VARCHAR(100) | País                                       |
| provincia             | VARCHAR(100) | Provincia / Estado                         |
| ciudad                | VARCHAR(100) | Ciudad                                     |
| codigo_postal         | VARCHAR(20)  | Código postal                              |
| limite_credito        | DECIMAL(15,2)| Límite de crédito                          |
| valor_vida_total      | DECIMAL(15,2)| Calculado automáticamente vía triggers     |
| fecha_adquisicion     | TEXT (ISO-8601) | Fecha de alta del cliente               |
| fecha_ultima_compra   | TEXT (ISO-8601) | Última compra (actualizada por trigger) |
| activo                | INTEGER (0/1) | Estado activo / inactivo (`CHECK`)       |

**Índices Principales:** segmento, pais, activo, fecha_adquisicion

---

### 📦 PRODUCTOS

**Propósito:** Catálogo de productos

| Columna                | Tipo          | Descripción                                     |
| ----------------------- | ------------- | ------------------------------------------------ |
| id                      | INTEGER       | PK (`AUTOINCREMENT`)                             |
| sku                     | VARCHAR(50)   | Código único de producto (UNIQUE)                |
| nombre                  | VARCHAR(255)  | Nombre del producto                              |
| categoria               | VARCHAR(100)  | Categoría (Electrónica, Software, Servicios...)  |
| subcategoria            | VARCHAR(100)  | Subcategoría                                     |
| marca                   | VARCHAR(100)  | Marca                                            |
| precio_lista            | DECIMAL(10,2) | Precio de venta al público                       |
| precio_costo            | DECIMAL(10,2) | Costo de adquisición                             |
| stock_actual            | INTEGER       | Stock disponible                                 |
| stock_minimo            | INTEGER       | Nivel mínimo de reposición                       |
| peso_kg / volumen_m3    | DECIMAL       | Propiedades físicas del producto                 |
| es_digital              | INTEGER (0/1) | Producto digital / físico                        |
| activo                  | INTEGER (0/1) | Producto activo                                  |
| fecha_lanzamiento       | TEXT (ISO-8601) | Fecha de lanzamiento                           |
| fecha_descontinuacion   | TEXT (ISO-8601) | Fecha de discontinuación                       |

**Índices Principales:** sku, categoria, marca, activo

**Cálculo de Margen:**

```sql
margen_pct = (precio_lista - precio_costo) / precio_lista * 100
```

---

### 👤 VENDEDORES

**Propósito:** Datos de vendedores y performance

| Columna            | Tipo          | Descripción                              |
| ------------------ | ------------- | ------------------------------------------ |
| id                 | INTEGER       | PK (`AUTOINCREMENT`)                       |
| equipo             | VARCHAR(100)  | Equipo (Empresas, PyMEs, Startups, etc.)  |
| territorio         | VARCHAR(100)  | Territorio (Norte, Sur, Este, etc.)       |
| gerente_id         | INTEGER       | FK a vendedor gerente (autorreferencia)   |
| tasa_comision      | DECIMAL(5,2)  | Porcentaje de comisión                    |
| cuota_mensual      | DECIMAL(15,2) | Cuota de ventas mensual                   |
| activo             | INTEGER (0/1) | Vendedor activo                           |
| fecha_contratacion | TEXT (ISO-8601) | Fecha de ingreso                        |
| fecha_baja         | TEXT (ISO-8601) | Fecha de baja                            |

**Índices Principales:** equipo, territorio, activo, gerente_id

---

### 📋 ORDEN_ENCABEZADO (Tabla de Hechos Principal)

**Propósito:** Registro de todas las órdenes de ventas

| Columna              | Tipo          | Descripción                                                                |
| --------------------- | ------------- | ----------------------------------------------------------------------------- |
| id                    | INTEGER       | PK (`AUTOINCREMENT`)                                                          |
| cliente_id            | INTEGER       | FK → clientes (`ON DELETE RESTRICT`)                                          |
| vendedor_id           | INTEGER       | FK → vendedores (`ON DELETE SET NULL`)                                        |
| fecha_orden           | TEXT (ISO-8601) | Fecha de la orden                                                           |
| estado                | VARCHAR(50)   | pendiente, confirmado, procesando, enviado, entregado, cancelado, devuelto    |
| subtotal              | DECIMAL(15,2) | Suma antes de descuentos                                                      |
| monto_descuento       | DECIMAL(15,2) | Monto de descuento                                                            |
| porcentaje_descuento  | DECIMAL(5,2)  | Porcentaje de descuento                                                       |
| monto_impuesto        | DECIMAL(15,2) | Impuestos                                                                     |
| costo_envio           | DECIMAL(15,2) | Costo de envío                                                                |
| monto_total           | DECIMAL(15,2) | **Total = SUM(total_linea) + impuesto + envío - descuento (vía trigger)**     |
| metodo_pago           | VARCHAR(50)   | tarjeta_credito, transferencia_bancaria, efectivo, cheque, otro              |
| estado_pago           | VARCHAR(50)   | pendiente, parcial, pagado, vencido, reembolsado                             |
| notas                 | TEXT          | Notas visibles al cliente                                                     |
| notas_internas        | TEXT          | Notas internas del equipo                                                     |

**Índices:** cliente_id, vendedor_id, fecha_orden, estado, estado_pago, creado_en

**Triggers Asociados** (SQLite requiere un trigger por evento, no admite múltiples eventos en uno solo):

- `trg_orden_detalles_ai_total` / `_au_total` / `_ad_total`: Recalculan `monto_total` al insertar, actualizar o eliminar un ítem
- `trg_orden_encabezado_ai_valor_vida` / `_au_valor_vida`: Actualizan `valor_vida_total` y `fecha_ultima_compra` del cliente

---

### 🔗 ORDEN_DETALLES

**Propósito:** Detalles de cada línea de una orden

| Columna              | Tipo          | Descripción                                                 |
| --------------------- | ------------- | ------------------------------------------------------------- |
| id                    | INTEGER       | PK (`AUTOINCREMENT`)                                          |
| orden_id              | INTEGER       | FK → orden_encabezado (`ON DELETE CASCADE`)                   |
| producto_id           | INTEGER       | FK → productos (`ON DELETE RESTRICT`)                         |
| cantidad              | INTEGER       | Cantidad pedida (`CHECK cantidad > 0`)                        |
| precio_unitario       | DECIMAL(10,2) | Precio unitario al momento de la venta                        |
| porcentaje_descuento  | DECIMAL(5,2)  | Descuento por línea                                            |
| total_linea           | DECIMAL(15,2) | **GENERATED ALWAYS AS (cantidad × precio_unitario × (1 − descuento%)) STORED** |
| ubicacion_almacen     | VARCHAR(100)  | Ubicación en almacén                                           |
| completado            | INTEGER (0/1) | ¿Línea despachada?                                             |
| cantidad_devuelta     | INTEGER       | Cantidad devuelta                                              |
| motivo_devolucion     | VARCHAR(255)  | Razón de la devolución                                         |

**Características:**

- `total_linea` es una columna `GENERATED ALWAYS AS (...) STORED` (soportado desde SQLite 3.31.0)
- Índices en orden_id, producto_id y completado para queries rápidas

---

### 💳 PAGOS

**Propósito:** Registro de transacciones de pago

| Columna           | Tipo          | Descripción                        |
| ------------------ | ------------- | ------------------------------------ |
| id                 | INTEGER       | PK (`AUTOINCREMENT`)                 |
| orden_id           | INTEGER       | FK → orden_encabezado (`ON DELETE RESTRICT`) |
| monto              | DECIMAL(15,2) | Monto pagado                       |
| fecha_pago         | TEXT (ISO-8601) | Fecha del pago                    |
| metodo_pago        | VARCHAR(50)   | Método utilizado                   |
| estado             | VARCHAR(50)   | pendiente, completado, fallido, reembolsado |
| numero_referencia  | VARCHAR(100)  | Número de referencia / comprobante |

**Nota:** Una orden puede tener múltiples pagos (pagos parciales).

---

### 🔙 DEVOLUCIONES

**Propósito:** Registro de devoluciones y reembolsos

| Columna          | Tipo          | Descripción                                                    |
| ----------------- | ------------- | ------------------------------------------------------------------ |
| id                | INTEGER       | PK (`AUTOINCREMENT`)                                               |
| orden_id          | INTEGER       | FK → orden_encabezado (`ON DELETE RESTRICT`)                       |
| fecha_devolucion  | TEXT (ISO-8601) | Fecha de solicitud                                                |
| motivo            | VARCHAR(255)  | Motivo (defectuoso, producto_incorrecto, etc.)                    |
| monto_reembolso   | DECIMAL(15,2) | Monto a reembolsar                                                 |
| fecha_reembolso   | TEXT (ISO-8601) | Fecha en que se efectuó el reembolso                              |
| estado            | VARCHAR(50)   | pendiente, aprobado, rechazado, reembolsado, reembolso_parcial    |
| aprobado_por      | VARCHAR(100)  | Usuario que aprobó la devolución                                   |

---

### 📧 INTERACCIONES_CLIENTES

**Propósito:** CRM - Registro de contactos y seguimientos

| Columna                   | Tipo         | Descripción                                      |
| --------------------------- | ------------ | --------------------------------------------------- |
| id                          | INTEGER      | PK (`AUTOINCREMENT`)                                |
| cliente_id                  | INTEGER      | FK → clientes (`ON DELETE CASCADE`)                 |
| vendedor_id                 | INTEGER      | FK → vendedores (`ON DELETE SET NULL`)              |
| tipo_interaccion            | VARCHAR(50)  | llamada, email, reunion, demo, soporte, seguimiento |
| asunto                      | VARCHAR(255) | Asunto de la interacción                            |
| resultado                   | VARCHAR(100) | interesado, no_interesado, demo_programada, etc.    |
| fecha_proximo_seguimiento   | TEXT (ISO-8601) | Próximo seguimiento programado                   |
| fecha_interaccion           | TEXT (ISO-8601) | Fecha del contacto                                |
| duracion_minutos            | INTEGER      | Duración en minutos                                 |

> Esta tabla existe en el schema pero **no se puebla** en `03-generacion-datos.sql` (ver [Diferencias](#diferencias-con-postgresql--t-sql--mysql)).

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
| campana_id       | FK → campanas (`ON DELETE CASCADE`) |
| cliente_id       | FK → clientes (`ON DELETE CASCADE`) |
| fecha_contacto   | Cuándo se realizó el contacto |
| abierto          | Si abrió el mensaje           |
| hizo_clic        | Si hizo clic en el enlace     |
| convirtio        | Si se concretó la conversión  |
| fecha_conversion | Cuándo se concretó la conversión |

> Al igual que `interacciones_clientes`, estas tablas existen en el schema pero **no se pueblan** en `03-generacion-datos.sql`.

---

### 🧾 CARGAS_DATOS (Auditoría)

**Propósito:** Registro de ejecuciones de carga/generación de datos

| Columna              | Descripción                                  |
| --------------------- | ------------------------------------------------ |
| fecha_carga           | Fecha/hora de la carga                        |
| tipo_carga            | inicial, incremental, refresco, prueba        |
| registros_afectados   | Cantidad de registros procesados               |
| estado                | Resultado de la carga                          |
| notas                 | Observaciones libres                           |

Al no haber stored procedures, se inserta manualmente con `INSERT INTO cargas_datos (...) VALUES (...);` cuando se quiera dejar registro de una corrida.

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

⚠️ **SQLite no aplica `FOREIGN KEY` por defecto en cada conexión.** Hay que ejecutar `PRAGMA foreign_keys = ON;` al abrir la base (los tres scripts ya lo incluyen, pero si te conectás desde una app/driver propio también tenés que activarlo ahí).

- **ON DELETE RESTRICT:** clientes, productos (no se eliminan si tienen órdenes)
- **ON DELETE CASCADE:** orden_detalles, interacciones_clientes, campanas_clientes
- **ON DELETE SET NULL:** vendedor_id en orden_encabezado, gerente_id en vendedores

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

**Columnas principales:** fecha_venta, cantidad_ordenes, clientes_unicos, vendedores_involucrados, ingresos_totales, valor_promedio_orden, orden_minima, orden_maxima, ordenes_entregadas, ordenes_canceladas, ordenes_pagadas

**Uso:**

```sql
SELECT * FROM v_resumen_ventas_diario
WHERE fecha_venta >= date('now', 'start of month')
ORDER BY fecha_venta DESC;
```

#### v_ventas_por_categoria

Performance por categoría y subcategoría de productos: cantidad_ordenes, unidades_vendidas, ingresos_totales, margen_ganancia_pct, unidades_devueltas.

#### v_performance_vendedores

KPIs individuales de vendedores: total_ordenes, clientes_unicos, ventas_totales, ventas_mes_actual, porcentaje_cumplimiento_cuota, fecha_ultima_venta, dias_desde_ultima_venta.

#### v_segmentacion_clientes

Análisis de clientes por segmento: valor_vida, valor_promedio_orden, fecha_ultima_compra, dias_desde_ultima_compra, ordenes_por_mes, ordenes_sin_pago.

#### v_analisis_pagos

Análisis de flujos de pago: cantidad_pagos, total_cobrado, pagos_exitosos, pagos_fallidos, pagos_atrasados_30d, pagos_atrasados_60d.

#### v_analisis_devoluciones

Análisis de devoluciones por categoría: cantidad_devoluciones, total_reembolsado, tasa_devolucion_pct, devoluciones_aprobadas, devoluciones_pendientes.

#### v_performance_campanas

Métricas de campañas de marketing: presupuesto, gasto_real, roi, ctr_pct, tasa_conversion_pct, costo_por_conversion.

### Tablas de Caché (equivalente a Vistas Materializadas)

SQLite no soporta `MATERIALIZED VIEW`. Se usan tablas normales (`mv_tendencia_ventas_mensual`, `mv_top_productos_por_categoria`) que se recalculan re-ejecutando el bloque **"REFRESCAR TABLAS DE CACHÉ"** al final de `02-vistas-y-funciones.sql` (un `DELETE` + `INSERT ... SELECT`, sin procedimiento).

```sql
-- Volver a poblar después de generar/cambiar datos:
-- (copiar y pegar el bloque "REFRESCAR TABLAS DE CACHÉ" de 02-vistas-y-funciones.sql)

SELECT * FROM mv_tendencia_ventas_mensual WHERE anio >= CAST(strftime('%Y','now') AS INTEGER) - 1;
SELECT * FROM mv_top_productos_por_categoria WHERE ranking_categoria <= 10;
```

---

## Generación de Datos

> **Nota:** SQLite no tiene stored procedures ni funciones de tabla. `03-generacion-datos.sql` es un script plano: genera cantidades **fijas** de registros usando CTEs recursivos (`WITH RECURSIVE numeros(n) AS (...)`), no funciones parametrizables por `CALL`/`SELECT * FROM func(...)`.

Cantidades por defecto (buscar el comentario `AJUSTAR CANTIDAD AQUÍ` en cada bloque para cambiarlas, editando el límite `n < N` del CTE):

| Bloque         | Cantidad por defecto | Cómo cambiarla |
| --------------- | --------------------- | ---------------- |
| Clientes         | 500                    | `WITH RECURSIVE numeros(n) AS (... WHERE n < 499)` → cambiar `499` |
| Productos        | 200                    | idem, bloque "GENERAR PRODUCTOS" |
| Vendedores       | 50                     | idem, bloque "GENERAR VENDEDORES" |
| Órdenes          | 5000                   | idem, bloque "GENERAR ÓRDENES" |
| Ítems por orden  | 1 a 8 (aleatorio)      | bloque "GENERAR ÍTEMS DE ÓRDENES" |
| Pagos            | Automático según `estado_pago` de cada orden | no requiere ajuste |

`campanas`, `campanas_clientes` e `interacciones_clientes` **no se generan** en este script (a diferencia de PostgreSQL/MySQL): quedan como tablas vacías, listas para poblar manualmente o extender el script si tu caso de prueba las necesita.

Las "funciones" analíticas de PostgreSQL/T-SQL/MySQL (ARR, churn, pronóstico de ventas, cohortes) se resuelven como **plantillas de consulta** al final de `04-queries-ejemplo.sql`, con los parámetros como literales editables directamente en el SQL (por ejemplo, cambiar el `12` de meses de período o el `90` de días de churn).

---

## Guía de Uso

### 1️⃣ Instalación Inicial

Con el CLI `sqlite3` instalado (ver [Instalación de SQLite](#instalación-de-sqlite)), parado en la carpeta `sqlite/`:

```bash
sqlite3 ventas_test.db < 01-schema.sql
sqlite3 ventas_test.db < 02-vistas-y-funciones.sql
sqlite3 ventas_test.db < 03-generacion-datos.sql
```

Esto crea el archivo `ventas_test.db` en la carpeta actual. También podés abrir el archivo interactivamente y usar `.read`:

```bash
sqlite3 ventas_test.db
sqlite> .read 01-schema.sql
sqlite> .read 02-vistas-y-funciones.sql
sqlite> .read 03-generacion-datos.sql
sqlite> .quit
```

En Windows PowerShell, `<` no funciona igual que en bash; usá `.read` desde la sesión interactiva de `sqlite3.exe`, o:

```powershell
Get-Content 01-schema.sql | sqlite3 ventas_test.db
```

### 2️⃣ Generar Datos de Prueba

```bash
sqlite3 ventas_test.db < 03-generacion-datos.sql
```

Para regenerar con otra cantidad de registros, editá los literales `n < N` en `03-generacion-datos.sql` (ver [Generación de Datos](#generación-de-datos)) antes de correrlo — el script empieza borrando las tablas dependientes, así que se puede re-ejecutar tantas veces como se quiera.

Después de generar o cambiar datos, actualizá las tablas de caché volviendo a ejecutar el bloque **"REFRESCAR TABLAS DE CACHÉ"** (al final de `02-vistas-y-funciones.sql`):

```bash
sqlite3 ventas_test.db < 02-vistas-y-funciones.sql
```

### 3️⃣ Consultas Básicas

```sql
-- Ventas totales del mes
SELECT SUM(ingresos_totales) FROM v_resumen_ventas_diario
WHERE fecha_venta >= date('now', 'start of month');

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
```

Más ejemplos (KPIs, comparativas, cohortes, exportación para Power BI) en [`04-queries-ejemplo.sql`](04-queries-ejemplo.sql).

### 4️⃣ Reset / Limpiar

```sql
-- Opción A: Volver a correr el script de generación (limpia y regenera)
-- sqlite3 ventas_test.db < 03-generacion-datos.sql

-- Opción B: Limpiar tablas específicas
DELETE FROM orden_encabezado;     -- Cascade elimina orden_detalles y relacionados
DELETE FROM clientes;

-- Opción C: Desactivar clientes (soft delete)
UPDATE clientes
SET activo = 0
WHERE fecha_adquisicion < datetime('now', '-6 months');

-- Opción D: Empezar de cero por completo
-- (fuera de sqlite3) borrar el archivo ventas_test.db y volver a correr 01/02/03
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

### Mantenimiento

```sql
-- Recalcular estadísticas para el planificador de consultas
ANALYZE;

-- Ver tamaño de la base
-- (desde el shell de sqlite3)
.dbinfo

-- Compactar el archivo después de borrados masivos
VACUUM;
```

### Performance para Dashboards

```sql
-- Query rápida para KPIs del dashboard principal
SELECT
    (SELECT COUNT(*) FROM orden_encabezado WHERE fecha_orden >= datetime('now', '-30 days')) AS ordenes_30d,
    (SELECT SUM(monto_total) FROM orden_encabezado WHERE fecha_orden >= datetime('now', '-30 days')) AS ingresos_30d,
    (SELECT COUNT(DISTINCT cliente_id) FROM orden_encabezado WHERE fecha_orden >= datetime('now', '-30 days')) AS clientes_30d,
    (SELECT AVG(monto_total) FROM orden_encabezado WHERE fecha_orden >= datetime('now', '-30 days')) AS promedio_30d;
```

---

## 📊 Integración con Power BI / Dashboards

### Conexión SQLite en Power BI

Power BI no tiene conector nativo para SQLite. Opciones habituales:

1. **Driver ODBC** (por ejemplo [sqliteodbc](http://www.ch-werner.de/sqliteodbc/)): instalarlo y conectar Power BI vía "Obtener datos → ODBC".
2. **Exportar a CSV/Parquet** con el CLI (`.mode csv`, `.output archivo.csv`, `SELECT ...`) y cargar el archivo en Power BI.
3. Para prototipos rápidos, usar la query 23 de `04-queries-ejemplo.sql` ("Export para Power BI - Tabla de Hechos") como base de exportación.

### Recomendaciones

- Usar vistas en lugar de tablas directamente
- Usar las tablas de caché (`mv_*`) para queries pesadas y recordar refrescarlas tras cada carga de datos
- Si el dataset crece mucho, considerar migrar a PostgreSQL/MySQL (SQLite es ideal para desarrollo y pruebas locales, no para cargas concurrentes grandes)

---

## Diferencias con PostgreSQL / T-SQL / MySQL

| Aspecto                        | PostgreSQL / T-SQL / MySQL                  | SQLite                                                            |
| -------------------------------- | ---------------------------------------------- | --------------------------------------------------------------------- |
| Servidor                          | Requiere proceso de servidor                    | Sin servidor: un único archivo `.db`                                   |
| PK autoincremental                | BIGSERIAL / IDENTITY / AUTO_INCREMENT           | `INTEGER PRIMARY KEY AUTOINCREMENT`                                    |
| UUID                              | Tipo nativo o `UUID()`                          | `TEXT` con `DEFAULT` que arma un UUID v4 desde `randomblob`/`hex`      |
| Fechas                            | `TIMESTAMP`/`DATETIME` nativo                   | `TEXT` en formato ISO-8601 (`datetime('now')`)                        |
| Decimales                         | `NUMERIC` / `DECIMAL`                           | `DECIMAL` (SQLite usa *type affinity*, no impone precisión real)       |
| Booleanos                         | `BOOLEAN` / `TINYINT(1)`                        | `INTEGER` con `CHECK (col IN (0,1))`                                   |
| Columna calculada                 | `GENERATED ALWAYS AS (...) STORED`              | Igual, soportado desde SQLite 3.31.0                                   |
| Funciones de tabla / procedimientos | `FUNCTION`/`PROCEDURE`, `CALL`/`SELECT * FROM func(...)` | No soportadas → scripts SQL planos con parámetros como literales editables |
| Vistas materializadas             | Nativas o tablas + refresh                      | Tablas `mv_*` + bloque `DELETE`/`INSERT` para refrescar manualmente    |
| Trigger multi-evento              | Uno para INSERT/UPDATE/DELETE (Postgres/MySQL) o para varios eventos (T-SQL) | Un trigger por evento (`_ai_`, `_au_`, `_ad_`)      |
| Generación de cantidad de datos   | Parámetros de función/procedimiento (`p_cantidad`) | Editar literales `n < N` directamente en el script                   |
| `campanas`/`campanas_clientes`/`interacciones_clientes` | Se generan con datos de prueba | Tablas creadas pero **vacías** tras `03-generacion-datos.sql`         |

---

Este schema es ideal para desarrollo local, prototipado rápido y pruebas de dashboards sin necesidad de levantar un servidor de base de datos.
