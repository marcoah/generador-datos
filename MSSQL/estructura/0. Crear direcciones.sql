/* ============================================================
   CREAR BASE SI NO EXISTE
============================================================ */

USE master;
GO

IF EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = N'direcciones'
)
BEGIN
    ALTER DATABASE direcciones
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    DROP DATABASE direcciones;
END
GO

CREATE DATABASE direcciones;
GO

USE direcciones;
GO

/* ============================================================
   BORRAR TABLA SI EXISTE
============================================================ */

IF EXISTS (
    SELECT 1 
    FROM sys.tables 
    WHERE name = 'direcciones_csv' 
      AND schema_id = SCHEMA_ID('dbo')
)
BEGIN
    DROP TABLE dbo.direcciones_csv;
END
GO

/* ============================================================
   CREAR TABLA
============================================================ */

CREATE TABLE dbo.direcciones_csv (
    id INT IDENTITY(1,1) PRIMARY KEY,
    direccion_original VARCHAR(255) NOT NULL,
    direccion_corregida VARCHAR(255) NULL, -- mejor permitir NULL si viene vac�a
    latitud DECIMAL(14,8) NOT NULL,
    longitud DECIMAL(14,8) NOT NULL
);
PRINT 'Tabla direcciones_csv creada correctamente';
GO
