-- ============================================================================
-- INICIALIZACIÓN DE BASE DE DATOS
-- SQL Server 2016+
-- ============================================================================
-- Ejecutar este script conectado a "master" (u otra base admin),
-- NO dentro de la base que se está creando.
--
-- Uso:
--   sqlcmd -S .\SQLEXPRESS -i 00-inicializa-bd.sql
--   sqlcmd -S .\SQLEXPRESS -d ventas_test -i 01-schema.sql
--   sqlcmd -S .\SQLEXPRESS -d ventas_test -i 02-vistas-y-funciones.sql
--   sqlcmd -S .\SQLEXPRESS -d ventas_test -i 03-generacion-datos.sql
-- ============================================================================

USE master;
GO

IF DB_ID('ventas_test') IS NOT NULL
BEGIN
    ALTER DATABASE ventas_test SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ventas_test;
END
GO

CREATE DATABASE ventas_test;
GO

ALTER DATABASE ventas_test SET RECOVERY SIMPLE;
GO

USE ventas_test;
GO

EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Base de datos de prueba para generación de datasets de ventas (BI/dashboards)';
GO
