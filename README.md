# Generador de Datos para Pruebas de BI

Scripts SQL para generar datasets realistas de ventas (clientes, productos, vendedores, órdenes, pagos, devoluciones, campañas de marketing) usados para probar dashboards y reportes de BI (Power BI, Vue.js, etc.). Incluye el mismo modelo implementado en cinco motores de base de datos distintos, más un modelo dimensional (star schema) listo para analítica.

## Tabla de contenidos

- [Estructura del repositorio](#estructura-del-repositorio)
- [Motores soportados](#motores-soportados)
- [Modelo de datos](#modelo-de-datos)
- [Requisitos](#requisitos)
- [Instrucciones de uso](#instrucciones-de-uso)
- [Autor](#autor)
- [Licencia](#licencia)

## Estructura del repositorio

```text
generador-datos/
├── mysql/              # MySQL 8.0+
├── postgreSQL/         # PostgreSQL 14+
├── sqlite/             # SQLite 3.35+
├── t-sql/              # SQL Server 2016+
└── modelo-analitico/   # Star schema (BI) construido sobre t-sql/
```

Cada carpeta de motor es autocontenida y sigue la misma numeración de scripts:

1. `00-inicializa-bd.sql` — crea la base de datos (solo donde aplica: PostgreSQL y el modelo analítico)
2. `01-schema.sql` — tablas, índices, triggers y claves foráneas
3. `02-vistas-y-funciones.sql` — vistas analíticas y funciones/procedimientos de reporting
4. `03-generacion-datos.sql` — funciones/procedimientos que generan datos de prueba
5. `04-queries-ejemplo.sql` — consultas de ejemplo para dashboards

## Motores soportados

| Motor                          | Carpeta                                  | Documentación                                                                                     | Notas                                                                                                                            |
| ------------------------------ | ---------------------------------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| MySQL 8.0+                     | [`mysql/`](mysql/)                       | [DOCUMENTACION-SCHEMA.md](mysql/DOCUMENTACION-SCHEMA.md)                                          | Sin funciones de tabla ni vistas materializadas nativas: usa `PROCEDURE` (`CALL`) y tablas de caché `mv_*`                       |
| PostgreSQL 14+                 | [`postgreSQL/`](postgreSQL/)             | [DOCUMENTACION-SCHEMA.md](postgreSQL/DOCUMENTACION-SCHEMA.md)                                     | Implementación de referencia: funciones de tabla (`SELECT * FROM func(...)`) y vistas materializadas nativas                     |
| SQL Server (T-SQL) 2016+       | [`t-sql/`](t-sql/)                       | [DOCUMENTACION-SCHEMA.md](t-sql/DOCUMENTACION-SCHEMA.md) · [uso_funcion.md](t-sql/uso_funcion.md) | El segundo doc explica el uso de la función de generación de nombres aleatorios                                                  |
| SQLite 3.35+                   | [`sqlite/`](sqlite/)                     | [DOCUMENTACION-SCHEMA.md](sqlite/DOCUMENTACION-SCHEMA.md)                                         | Incluye instrucciones de instalación de SQLite (Windows/macOS/Linux). Sin stored procedures: generación y reporting con SQL puro |
| Modelo Analítico (Star Schema) | [`modelo-analitico/`](modelo-analitico/) | [DOCUMENTACION-MODELO.md](modelo-analitico/DOCUMENTACION-MODELO.md)                               | Modelo dimensional (Kimball) para BI, construido vía ETL a partir de los datos generados en `t-sql/`                             |

## Modelo de datos

El modelo transaccional (OLTP), común a `mysql/`, `postgreSQL/`, `sqlite/` y `t-sql/`, gira en torno a estas tablas:

- `clientes`
- `productos`
- `vendedores`
- `orden_encabezado`
- `orden_detalles`
- `pagos`
- `devoluciones`
- `interacciones_clientes`
- `campanas` / `campanas_clientes`

Cada motor puede tener columnas o tablas auxiliares propias (por ejemplo, `cargas_datos` en MySQL) — el detalle completo, tipos de datos y relaciones están en el archivo `DOCUMENTACION-SCHEMA.md` de cada carpeta (ver tabla anterior).

`modelo-analitico/` toma esos datos y los transforma en un star schema (tablas de hechos + dimensiones) pensado para conectarse directamente a Power BI u otra herramienta de BI sin JOINs intermedios.

## Requisitos

- Motor de base de datos correspondiente instalado (MySQL 8.0+, PostgreSQL 14+, SQL Server 2016+ o SQLite 3.35+)
- Cliente de línea de comandos o GUI para ejecutar scripts `.sql` (`mysql`, `psql`, `sqlcmd`, `sqlite3`, Azure Data Studio, DBeaver, etc.)

## Instrucciones de uso

1. Elegí la carpeta del motor que vayas a usar.
2. Ejecutá los scripts en el orden numérico indicado en [Estructura del repositorio](#estructura-del-repositorio).
3. Llamá a la función/procedimiento de generación masiva de datos (por ejemplo `generar_todos_los_datos(...)` en PostgreSQL o `CALL sp_generar_todos_los_datos(...)` en MySQL) — el detalle exacto de sintaxis y parámetros está en la sección "Guía de Uso" de cada `DOCUMENTACION-SCHEMA.md`.
4. Usá `04-queries-ejemplo.sql` como punto de partida para tus propios dashboards.

## Autor

Marco Hernandez

## Licencia

Este proyecto se distribuye bajo la licencia MIT.

Puedes usarlo, copiarlo, modificarlo y distribuirlo libremente, siempre que conserves este aviso de derechos de autor y la licencia.

Más detalles en el archivo [LICENSE](LICENSE).
