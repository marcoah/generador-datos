/* ============================================================
   CREAR BASE SI NO EXISTE
============================================================ */

USE master;
GO

IF EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = N'geolocalizacion'
)
BEGIN
    ALTER DATABASE geolocalizacion
    SET SINGLE_USER
    WITH ROLLBACK IMMEDIATE;

    DROP DATABASE geolocalizacion;
END
GO

CREATE DATABASE geolocalizacion;
GO

USE geolocalizacion;
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

/*
-- Se ejecutan 1 sola vez
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
*/

-- Importar CSV

USE geolocalizacion;
GO

/* ============================================================
   BORRAR TABLA SI EXISTE
============================================================ */

IF OBJECT_ID('dbo.salud', 'U') IS NOT NULL
    DROP TABLE dbo.salud;
GO


/* ============================================================
   CREAR TABLA
============================================================ */

CREATE TABLE dbo.salud (
    id INT NOT NULL,
    longitude NUMERIC(18,10) NULL,
    latitude  NUMERIC(18,10) NULL,
    healthcare NVARCHAR(255) NULL,
    name NVARCHAR(255) NULL,
    speciality NVARCHAR(255) NULL,
    operator_type NVARCHAR(255) NULL,
    operational_status NVARCHAR(255) NULL,
    addr_full NVARCHAR(255) NULL,
    addr_street NVARCHAR(255) NULL,
    addr_housenumber NVARCHAR(255) NULL,
    addr_postcode NVARCHAR(255) NULL,
    addr_city NVARCHAR(255) NULL,
    addr_province NVARCHAR(255) NULL,
    addr_country NVARCHAR(255) NULL,
    CONSTRAINT PK_salud PRIMARY KEY (id)
);
GO


/* ============================================================
   CARGA DESDE CSV
============================================================ */

BULK INSERT dbo.salud
FROM 'C:\data\datos_salud.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    TABLOCK
);
GO


/* ============================================================
   AGREGAR COLUMNA GEOGRAPHY
============================================================ */

ALTER TABLE dbo.salud
ADD ubicacion GEOGRAPHY;
GO


/* ============================================================
   CARGAR GEOGRAPHY
============================================================ */

UPDATE dbo.salud
SET ubicacion = GEOGRAPHY::Point(latitude, longitude, 4326)
WHERE latitude IS NOT NULL 
  AND longitude IS NOT NULL;
GO


/* ============================================================
   CREAR INDICE ESPACIAL
============================================================ */

CREATE SPATIAL INDEX IX_salud_ubicacion
ON dbo.salud(ubicacion);
GO


