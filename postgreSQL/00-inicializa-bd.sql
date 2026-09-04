-- ============================================================================
-- INICIALIZACIÓN DE BASE DE DATOS
-- PostgreSQL 14+
-- ============================================================================
-- Ejecutar este script conectado a la base "postgres" (u otra base admin),
-- NO dentro de la base que se está creando.
--
-- Uso:
--   psql -U postgres -f 00-inicializa-bd.sql
--   psql -U postgres -d ventas_test -f 01-schema.sql
--   psql -U postgres -d ventas_test -f 02-vistas-y-funciones.sql
--   psql -U postgres -d ventas_test -f 03-generacion-datos.sql
-- ============================================================================

CREATE DATABASE ventas_test
    ENCODING 'UTF8'
    TEMPLATE template0;

COMMENT ON DATABASE ventas_test IS 'Base de datos de prueba para generación de datasets de ventas (BI/dashboards)';
