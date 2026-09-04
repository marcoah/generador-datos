-- ============================================================================
-- INICIALIZACIÓN DE BASE DE DATOS ANALÍTICA (STAR SCHEMA)
-- SQL Server 2016+
-- ============================================================================
-- Ejecutar conectado a "master" (u otra base admin), NO dentro de la base
-- que se está creando. Requiere que t-sql/ ya haya sido ejecutado y tenga
-- datos generados en la base "ventas_test" (ver DOCUMENTACION-MODELO.md).
--
-- Uso:
--   sqlcmd -S localhost -U sa -P '<password>' -C -i 00-inicializa-bd.sql
--   sqlcmd -S localhost -U sa -P '<password>' -C -d ventas_bi -i 01-schema.sql
--   sqlcmd -S localhost -U sa -P '<password>' -C -d ventas_bi -i 02-etl-carga.sql
--   sqlcmd -S localhost -U sa -P '<password>' -C -d ventas_bi -i 03-queries-bi-ejemplo.sql
-- ============================================================================

IF DB_ID('ventas_bi') IS NULL
    CREATE DATABASE ventas_bi;
GO
