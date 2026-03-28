/* ============================================================
   PROYECTO: Geolocalización
   AUTOR: Marco Hernández
   FECHA: Diciembre 2025
   MOTOR  : SQL Server
   OBJETIVO:
     - Modelo tipo DW / OLTP híbrido
     - Dimensiones + Hechos
     - Customers derivados desde fuente geoespacial (salud)
     - Preparado para Power BI y análisis geográfico
============================================================ */

/* ============================================================
   CREACION DE BASE DE DATOS Y TABLAS
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

/* ============================================================
   CREAR SERVICIO DE GEOCODIFICACION
============================================================ */

/* ============================================================
   BORRAR TABLA SALUD SI EXISTE
============================================================ */

IF OBJECT_ID('dbo.salud', 'U') IS NOT NULL
    DROP TABLE dbo.salud;
GO

/* ============================================================
   CREAR TABLA SLAUD (origen de datos para Customers)
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
   CREAR TABLAS DE GEOGRAFIA
   Insertar provincias y ciudades
============================================================ */


/* ============================================================
   LIMPIEZA
   (orden inverso de dependencias)
============================================================ */

DROP TABLE IF EXISTS Cities;
DROP TABLE IF EXISTS Provinces;
DROP TABLE IF EXISTS Countries;
GO

-- Pais
CREATE TABLE Countries (
    CountryID INT PRIMARY KEY,
    CountryName NVARCHAR(100) NOT NULL
);
PRINT 'Tabla Countries creada correctamente';

-- Provincias
CREATE TABLE Provinces (
    ProvinceID INT PRIMARY KEY,
    ProvinceName NVARCHAR(100) NOT NULL,
    CountryID INT NOT NULL,

    FOREIGN KEY (CountryID) REFERENCES Countries(CountryID)
);
PRINT 'Tabla Provinces creada correctamente';

-- Ciudades
CREATE TABLE Cities (
    CityID INT IDENTITY PRIMARY KEY,
    CityName NVARCHAR(150) NOT NULL,
    ProvinceID INT NOT NULL,
    CountryID INT NOT NULL,

    -- Centroide urbano (rápido, ideal BI)
    GeoPoint GEOGRAPHY,

    -- Área urbana aproximada
    GeoPolygon GEOGRAPHY,

    FOREIGN KEY (CountryID) REFERENCES Countries(CountryID),
    FOREIGN KEY (ProvinceID) REFERENCES Provinces(ProvinceID)
);
PRINT 'Tabla Cities creada correctamente';

/* ============================================================
   CREAR INDICES ESPACIALES
============================================================ */

CREATE SPATIAL INDEX IX_salud_ubicacion
ON dbo.salud(ubicacion);

CREATE SPATIAL INDEX IX_Cities_GeoPoint
ON Cities(GeoPoint);

CREATE SPATIAL INDEX IX_Cities_GeoPolygon
ON Cities(GeoPolygon);


/* ============================================================
   CARGAR VALORES DE DIMENSIONES ESPACIALES
============================================================ */

-- Paises
INSERT INTO Countries (CountryID, CountryName)
VALUES
(1,'Argentina');

-- Provincias
INSERT INTO Provinces (ProvinceID, ProvinceName, CountryID)
VALUES
(1,'Buenos Aires',1),
(2,'Catamarca',1),
(3,'Chaco',1),
(4,'Chubut',1),
(5,'Córdoba',1),
(6,'Corrientes',1),
(7,'Entre Ríos',1),
(8,'Formosa',1),
(9,'Jujuy',1),
(10,'La Pampa',1),
(11,'La Rioja',1),
(12,'Mendoza',1),
(13,'Misiones',1),
(14,'Neuquén',1),
(15,'Río Negro',1),
(16,'Salta',1),
(17,'San Juan',1),
(18,'San Luis',1),
(19,'Santa Cruz',1),
(20,'Santa Fe',1),
(21,'Santiago del Estero',1),
(22,'Tierra del Fuego',1),
(23,'Tucumán',1),
(24,'Ciudad Autónoma de Buenos Aires',1);

-- Ciudades
INSERT INTO Cities (CityName, ProvinceID, CountryID, GeoPoint, GeoPolygon)
VALUES
-- 1 CABA
(
    'Ciudad Autónoma de Buenos Aires',
    24,
    1,
    geography::Point(-34.6037, -58.3816, 4326),
    geography::STGeomFromText(
        'POLYGON((
            -58.5310 -34.5265,
            -58.3350 -34.5265,
            -58.3350 -34.7050,
            -58.5310 -34.7050,
            -58.5310 -34.5265
        ))', 4326
    )
),

-- 2 Cordoba
(
    'Córdoba',
    5,
    1,
    geography::Point(-31.4201, -64.1888, 4326),
    geography::STGeomFromText(
        'POLYGON((
            -64.2800 -31.3600,
            -64.1200 -31.3600,
            -64.1200 -31.5000,
            -64.2800 -31.5000,
            -64.2800 -31.3600
        ))', 4326)
),

--3 Rosario
(
    'Rosario',
    20,
    1,
    geography::Point(-32.9442, -60.6393, 4326),
    geography::STGeomFromText('POLYGON((
        -60.7200 -32.8800,
        -60.5600 -32.8800,
        -60.5600 -33.0200,
        -60.7200 -33.0200,
        -60.7200 -32.8800
    ))', 4326)
 ),

-- 4 La Plata
(
    'La Plata',
    1,
    1,
    geography::Point(-34.9205, -57.9536, 4326),
    geography::STGeomFromText('POLYGON((
        -58.05 -34.85,
        -57.85 -34.85,
        -57.85 -35.00,
        -58.05 -35.00,
        -58.05 -34.85
    ))',
    4326)
),

-- 5 Mar del Plata
(
    'Mar del Plata',
    1,
    1,
    geography::Point(-38.0055, -57.5426, 4326),
    geography::STGeomFromText('POLYGON((
        -57.65 -37.90,
        -57.40 -37.90,
        -57.40 -38.10,
        -57.65 -38.10,
        -57.65 -37.90
    ))',
    4326)
),

-- 6 Mendoza
(
    'Mendoza',
    12,
    1,
    geography::Point(-32.8895, -68.8458, 4326),
    geography::STGeomFromText('POLYGON((
        -68.95 -32.80,
        -68.75 -32.80,
        -68.75 -33.00,
        -68.95 -33.00,
        -68.95 -32.80
    ))',4326)
 ),

-- 7 San Miguel de Tucumán
(
    'San Miguel de Tucumán',
    23,
    1,
    geography::Point(-26.8083, -65.2226, 4326),
    geography::STGeomFromText('POLYGON((
        -65.35 -26.70,
        -65.10 -26.70,
        -65.10 -26.90,
        -65.35 -26.90,
        -65.35 -26.70
    ))',4326)
 ),

-- 8 Salta
(
    'Salta',
    16,
    1,
    geography::Point(-24.7821, -65.4232, 4326),
    geography::STGeomFromText('POLYGON((
        -65.55 -24.70,
        -65.30 -24.70,
        -65.30 -24.90,
        -65.55 -24.90,
        -65.55 -24.70
    ))',4326)
 ),

-- 9 Santa Fe
(
    'Santa Fe',
    20,
    1,
    geography::Point(-31.6333, -60.7000, 4326),
    geography::STGeomFromText('POLYGON((
        -60.80 -31.55,
        -60.60 -31.55,
        -60.60 -31.70,
        -60.80 -31.70,
        -60.80 -31.55
    ))',4326)
 ),

-- 10 San Juan
(
    'San Juan',
    17,
    1,
    geography::Point(-31.5375, -68.5364, 4326),
    geography::STGeomFromText('POLYGON((
        -68.65 -31.45,
        -68.40 -31.45,
        -68.40 -31.65,
        -68.65 -31.65,
        -68.65 -31.45
    ))',4326)
 ),

-- 11 Neuquén
(
    'Neuquén',
    14,
    1,
    geography::Point(-38.9516, -68.0591, 4326),
    geography::STGeomFromText('POLYGON((
        -68.15 -38.85,
        -67.95 -38.85,
        -67.95 -39.05,
        -68.15 -39.05,
        -68.15 -38.85
    ))',4326)
 ),

-- 12 Resistencia
(
    'Resistencia',
    3,
    1,
    geography::Point(-27.4514, -58.9867, 4326),
    geography::STGeomFromText('POLYGON((
        -59.10 -27.35,
        -58.85 -27.35,
        -58.85 -27.55,
        -59.10 -27.55,
        -59.10 -27.35
    ))',4326)
 ),

-- 13 Posadas
(
    'Posadas',
    13,
    1,
    geography::Point(-27.3671, -55.8961, 4326),
    geography::STGeomFromText('POLYGON((
        -56.00 -27.30,
        -55.75 -27.30,
        -55.75 -27.45,
        -56.00 -27.45,
        -56.00 -27.30
    ))',4326)
 ),

-- 14 Corrientes
(
    'Corrientes',
    6,
    1,
    geography::Point(-27.4692, -58.8341, 4326),
    geography::STGeomFromText('POLYGON((
        -58.95 -27.35,
        -58.70 -27.35,
        -58.70 -27.55,
        -58.95 -27.55,
        -58.95 -27.35
    ))',4326)
 ),

-- 15 Santiago del Estero
(
    'Santiago del Estero',
    21,
    1,
    geography::Point(-27.7951, -64.2615, 4326),
    geography::STGeomFromText('POLYGON((
    -64.40 -27.70,
    -64.15 -27.70,
    -64.15 -27.90,
    -64.40 -27.90,
    -64.40 -27.70
    ))',4326)
 ),

-- 16 San Salvador de Jujuy
(
    'San Salvador de Jujuy',
    9,
    1,
    geography::Point(-24.1858, -65.2971, 4326),
    geography::STGeomFromText('POLYGON((
        -65.40 -24.10,
        -65.20 -24.10,
        -65.20 -24.30,
        -65.40 -24.30,
        -65.40 -24.10
    ))',4326)
 ),

-- 17 Formosa
(
    'Formosa',
    8,
    1,
    geography::Point(-26.1775, -58.1781, 4326),
    geography::STGeomFromText('POLYGON((
        -58.30 -26.05,
        -58.05 -26.05,
        -58.05 -26.30,
        -58.30 -26.30,
        -58.30 -26.05
    ))',4326)
 ),

-- 18 San Luis
('San Luis', 18, 1,
 geography::Point(-33.3017, -66.3356, 4326),
 geography::STGeomFromText('POLYGON((
    -66.45 -33.20,
    -66.20 -33.20,
    -66.20 -33.40,
    -66.45 -33.40,
    -66.45 -33.20
 ))',4326)),

-- 19 Río Gallegos
('Río Gallegos', 19, 1,
 geography::Point(-51.6230, -69.2181, 4326),
 geography::STGeomFromText('POLYGON((
    -69.35 -51.55,
    -69.10 -51.55,
    -69.10 -51.70,
    -69.35 -51.70,
    -69.35 -51.55
 ))',4326)),

-- 20 Ushuaia
(
    'Ushuaia',
    22,
    1,
    geography::Point(-54.8019, -68.3030, 4326),
    geography::STGeomFromText('POLYGON((
        -68.45 -54.70,
        -68.10 -54.70,
        -68.10 -54.90,
        -68.45 -54.90,
        -68.45 -54.70
    ))',4326)
 ),

-- 21 Paraná
(
    'Paraná',
    7,
    1,
    geography::Point(-31.7319, -60.5238, 4326),
    geography::STGeomFromText('POLYGON((
        -60.65 -31.65,
        -60.40 -31.65,
        -60.40 -31.80,
        -60.65 -31.80,
        -60.65 -31.65
    ))',4326)
 ),

-- 22 Bahía Blanca
(
    'Bahía Blanca',
    1,
    1,
    geography::Point(-38.7196, -62.2724, 4326),
    geography::STGeomFromText('POLYGON((
        -62.40 -38.60,
        -62.15 -38.60,
        -62.15 -38.85,
        -62.40 -38.85,
        -62.40 -38.60
    ))',4326)
 ),

-- 23 Comodoro Rivadavia
(
    'Comodoro Rivadavia',
    4,
    1,
    geography::Point(-45.8641, -67.4966, 4326),
    geography::STGeomFromText('POLYGON((
        -67.65 -45.75,
        -67.30 -45.75,
        -67.30 -45.95,
        -67.65 -45.95,
        -67.65 -45.75
    ))',4326)
 ),

 -- 24 Zarate 
 (
    'Zarate',
    1,
    1,
    geography::Point(-34.08330, -59.0333, 4326),
    geography::STGeomFromText('POLYGON((
        -59.0550 -34.0750,
        -59.0050 -34.0850,
        -59.0150 -34.1150,
        -59.0600 -34.1050,
        -59.0550 -34.0750
    ))',4326)
 );

 ALTER TABLE Cities ADD Weight INT;
    UPDATE Cities
    SET Weight = CASE 
        WHEN CityName IN ('Ciudad Autónoma de Buenos Aires') THEN 20
        WHEN CityName IN ('Córdoba', 'Rosario') THEN 10
        WHEN CityName IN ('Mendoza', 'San Juan', 'San Luis') THEN 8
        ELSE 5
    END;


/* ============================================================
   Resolucion del problema del anillo invertido (ver Documentacion)
============================================================ */

UPDATE Cities
SET GeoPolygon = GeoPolygon.ReorientObject();
GO

/* ============================================================
   LIMPIEZA
   (orden inverso de dependencias)
============================================================ */

DROP TABLE IF EXISTS Refunds;
DROP TABLE IF EXISTS Payments;
DROP TABLE IF EXISTS OrderDetails;
DROP TABLE IF EXISTS Orders;
DROP TABLE IF EXISTS Inventory;

DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS Categories;
DROP TABLE IF EXISTS Sellers;
DROP TABLE IF EXISTS Warehouses;
DROP TABLE IF EXISTS PaymentMethods;
DROP TABLE IF EXISTS DimDate;
DROP TABLE IF EXISTS Customers;
GO

/* ============================================================
   DIMENSIONES
============================================================ */

-- ========================
-- Categorías
-- ========================
CREATE TABLE Categories (
    CategoryID INT IDENTITY PRIMARY KEY,
    CategoryName NVARCHAR(100) NOT NULL
);
GO

-- ========================
-- Productos
-- ========================
CREATE TABLE Products (
    ProductID INT IDENTITY PRIMARY KEY,
    ProductName NVARCHAR(150) NOT NULL,
    CategoryID INT NOT NULL,
    RequiresPrescription BIT,
    UnitPrice DECIMAL(10,2),
    CostPrice DECIMAL(12,2),
    CONSTRAINT FK_Products_Categories
        FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID)
);
GO

/* ============================================================
   Customers (desde tabla Salud)
============================================================ */
/**/
SELECT
    id                AS CustomerID,
    longitude,
    latitude,
    healthcare,
    name              AS CustomerName,
    addr_full         AS CustomerAddress,
    addr_street       AS CustomerStreet,
    addr_housenumber  AS CustomerHousenumber,
    addr_postcode     AS CustomerPostcode,
    addr_city         AS CustomerCity,
    addr_province     AS CustomerProvince,
    addr_country      AS CustomerCountry
INTO Customers
FROM salud
WHERE latitude  IS NOT NULL
  AND longitude IS NOT NULL;
GO

DECLARE @TotalCities INT;

SELECT @TotalCities = COUNT(*)
FROM Cities
WHERE GeoPoint IS NOT NULL;

;WITH WeightedCities AS (
    SELECT 
        CityID,
        CityName,
        GeoPoint,
        SUM(Weight) OVER () AS TotalWeight,
        SUM(Weight) OVER (ORDER BY CityID ROWS UNBOUNDED PRECEDING) AS RunningTotal
    FROM Cities
),
RandomCustomers AS (
    SELECT 
        CustomerID,
        ABS(CHECKSUM(NEWID())) % (SELECT MAX(TotalWeight) FROM WeightedCities) AS rnd
    FROM Customers
)
UPDATE c
SET
    c.CustomerCity = wc.CityName,
    c.Latitude     = wc.GeoPoint.Lat,
    c.Longitude    = wc.GeoPoint.Long
FROM Customers c
JOIN RandomCustomers rc ON c.CustomerID = rc.CustomerID
JOIN WeightedCities wc 
    ON rc.rnd < wc.RunningTotal;

-- Clave primaria
ALTER TABLE Customers
ADD CONSTRAINT PK_Customers
PRIMARY KEY CLUSTERED (CustomerID);
GO

-- Columna geográfica
ALTER TABLE Customers
ADD GeoLocation GEOGRAPHY;
GO

-- Población de geolocalización
UPDATE Customers
SET GeoLocation = geography::Point(latitude, longitude, 4326);
GO

-- Índice espacial
CREATE SPATIAL INDEX IX_Customers_GeoLocation
ON Customers(GeoLocation);
GO

-- 1493 Nulos
UPDATE c
SET 
    c.CustomerCity = NULL
FROM Customers c
JOIN (
    SELECT TOP 493 CustomerID
    FROM Customers
    ORDER BY NEWID()
) x
ON c.CustomerID = x.CustomerID;

/* ============================================================
   Vendedores
============================================================ */
CREATE TABLE Sellers (
    SellerID INT IDENTITY PRIMARY KEY,
    SellerName NVARCHAR(150) NOT NULL,
    Region NVARCHAR(100)
);
GO

/* ============================================================
   Almacenes
============================================================ */
CREATE TABLE Warehouses (
    WarehouseID INT IDENTITY PRIMARY KEY,
    WarehouseName NVARCHAR(100) NOT NULL,
    City NVARCHAR(100),
    CityID INT NOT NULL,
    Region NVARCHAR(100),
    IsActive BIT DEFAULT 1
    CONSTRAINT FK_City
        FOREIGN KEY (CityID) REFERENCES Cities(CityID),
);
GO

/* ============================================================
   Métodos de Pago
============================================================ */
CREATE TABLE PaymentMethods (
    PaymentMethodID INT IDENTITY PRIMARY KEY,
    MethodName NVARCHAR(50) NOT NULL,
    IsActive BIT DEFAULT 1
);
GO

/* ============================================================
   Dimensión Fecha
============================================================ */
CREATE TABLE DimDate (
    DateKey INT PRIMARY KEY,       -- YYYYMMDD
    FullDate DATE NOT NULL,
    Year INT,
    Quarter INT,
    Month INT,
    MonthName NVARCHAR(20),
    Day INT,
    DayOfWeek INT,
    DayName NVARCHAR(20),
    WeekOfYear INT,
    IsWeekend BIT
);
GO

/* ============================================================
   HECHOS
============================================================ */

/* ============================================================
   Inventario
============================================================ */
CREATE TABLE Inventory (
    InventoryID INT IDENTITY PRIMARY KEY,
    ProductID INT NOT NULL,
    WarehouseID INT NOT NULL,
    BatchNumber NVARCHAR(50) NOT NULL,
    ExpirationDate DATE NOT NULL,
    QuantityOnHand INT NOT NULL,
    LastUpdated DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Inventory_Product
        FOREIGN KEY (ProductID) REFERENCES Products(ProductID),
    CONSTRAINT FK_Inventory_Warehouse
        FOREIGN KEY (WarehouseID) REFERENCES Warehouses(WarehouseID),
    CONSTRAINT CK_Inventory_Quantity
        CHECK (QuantityOnHand >= 0)
);
GO

/* ============================================================
   Órdenes (Encabezado)
============================================================ */
CREATE TABLE Orders (
    OrderID INT IDENTITY PRIMARY KEY,
    CustomerID INT NOT NULL,
    SellerID INT NOT NULL,
    OrderDate DATE,
    OrderDateKey INT,   -- FK lógica a DimDate
    CONSTRAINT FK_Orders_Customers
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    CONSTRAINT FK_Orders_Sellers
        FOREIGN KEY (SellerID) REFERENCES Sellers(SellerID)
);
GO

/* ============================================================
   Órdenes (Detalle)
============================================================ */
CREATE TABLE OrderDetails (
    OrderDetailID INT IDENTITY PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT,
    UnitPrice DECIMAL(10,2),
    CONSTRAINT FK_OrderDetails_Order
        FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    CONSTRAINT FK_OrderDetails_Product
        FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
GO

/* ============================================================
   Pagos
============================================================ */
CREATE TABLE Payments (
    PaymentID INT IDENTITY PRIMARY KEY,
    OrderID INT NOT NULL,
    PaymentMethodID INT NOT NULL,
    PaymentDate DATETIME NOT NULL DEFAULT GETDATE(),
    Amount DECIMAL(12,2) NOT NULL,
    TransactionReference NVARCHAR(100),
    Status NVARCHAR(30) DEFAULT 'Approved',
    CONSTRAINT FK_Payments_Order
        FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    CONSTRAINT FK_Payments_Method
        FOREIGN KEY (PaymentMethodID) REFERENCES PaymentMethods(PaymentMethodID)
);
GO

/* ============================================================
   Reintegros
============================================================ */
CREATE TABLE Refunds (
    RefundID INT IDENTITY PRIMARY KEY,
    OrderID INT NOT NULL,
    PaymentID INT NULL,
    RefundDate DATETIME DEFAULT GETDATE(),
    Amount DECIMAL(12,2) NOT NULL,
    Reason NVARCHAR(200),
    CONSTRAINT FK_Refunds_Order
        FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    CONSTRAINT FK_Refunds_Payment
        FOREIGN KEY (PaymentID) REFERENCES Payments(PaymentID)
);
GO

/* ============================================================
   ÍNDICES DE PERFORMANCE
============================================================ */

CREATE INDEX IX_Orders_Customer
ON Orders(CustomerID);
GO

CREATE INDEX IX_OrderDetails_Order
ON OrderDetails(OrderID);
GO

CREATE INDEX IX_Payments_Order
ON Payments(OrderID);
GO

/* ============================================================
   GENERAR DATOS ALEATORIOS
============================================================ */

/* ============================================================
   TABLA DIMDATE
   Para Power BI
   Orders.OrderDate → DimDate.FullDate
   Cardinalidad: Many-to-One
   Dirección de filtro: Single
============================================================ */

DECLARE @StartDate DATE = '2023-01-01';
DECLARE @EndDate DATE = '2026-12-31';

WITH Dates AS (
    SELECT @StartDate AS DateValue
    UNION ALL
    SELECT DATEADD(DAY, 1, DateValue)
    FROM Dates
    WHERE DateValue < @EndDate
)
INSERT INTO DimDate
SELECT
    CONVERT(INT, FORMAT(DateValue,'yyyyMMdd')),
    DateValue,
    YEAR(DateValue),
    DATEPART(QUARTER, DateValue),
    MONTH(DateValue),
    DATENAME(MONTH, DateValue),
    DAY(DateValue),
    DATEPART(WEEKDAY, DateValue),
    DATENAME(WEEKDAY, DateValue),
    DATEPART(WEEK, DateValue),
    CASE WHEN DATEPART(WEEKDAY, DateValue) IN (1,7) THEN 1 ELSE 0 END
FROM Dates
OPTION (MAXRECURSION 0);

/* ============================================================
   Categorias
============================================================ */
INSERT INTO Categories (CategoryName)
VALUES 
('Medicamentos Recetados'),
('Medicamentos OTC'),
('Vitaminas y Suplementos'),
('Cuidado Personal'),
('Equipamiento Médico'),
('Higiene y Protección'),
('Salud Infantil'),
('Salud Cardiovascular');

/* ============================================================
   Metodos de pago
============================================================ */
INSERT INTO PaymentMethods (MethodName)
VALUES
('Tarjeta Crédito'),
('Tarjeta Débito'),
('Transferencia'),
('Efectivo'),
('Obra Social'),
('MercadoPago');

/* ============================================================
   Almacenes
============================================================ */
INSERT INTO Warehouses (WarehouseName, City, CityID, Region)
VALUES
('Depósito Central', 'Buenos Aires', 1, 'Centro'),
('Sucursal Córdoba', 'Córdoba', 2, 'Centro'),
('Sucursal Rosario', 'Rosario', 3, 'Litoral'),
('Sucursal Mendoza', 'Mendoza', 6,  'Cuyo'),
('Sucursal Salta', 'Salta', 8, 'Norte');


/* ============================================================
   Productos
   Para cada Drugname genero 10 productos con formas
   y dosis aleatorias
============================================================ */

DECLARE @DrugNames TABLE (Name NVARCHAR(100));
INSERT INTO @DrugNames VALUES
-- Analgésicos / Antiinflamatorios
('Paracetamol'), ('Ibuprofeno'), ('Aspirina'), ('Diclofenac'),
('Naproxeno'), ('Ketorolaco'), ('Meloxicam'), ('Tramadol'),
('Celecoxib'), ('Nimesulida'),

-- Antibióticos
('Amoxicilina'), ('Azitromicina'), ('Ciprofloxacina'), ('Claritromicina'),
('Doxiciclina'), ('Metronidazol'), ('Ampicilina'), ('Cefalexina'),
('Trimetoprima'), ('Levofloxacina'),

-- Cardiovascular / Hipertensión
('Enalapril'), ('Losartan'), ('Atorvastatina'), ('Amlodipino'),
('Metoprolol'), ('Furosemida'), ('Hidroclorotiazida'), ('Valsartan'),
('Simvastatina'), ('Bisoprolol'), ('Espironolactona'), ('Carvedilol'),

-- Diabetes / Metabolismo
('Metformina'), ('Insulina'), ('Glibenclamida'), ('Sitagliptina'),
('Empagliflozina'), ('Pioglitazona'),

-- Respiratorio
('Salbutamol'), ('Budesonida'), ('Montelukast'), ('Bromuro de Ipratropio'),
('Fluticasona'), ('Salmeterol'), ('Acetilcisteína'), ('Ambroxol'),

-- Gastrointestinal
('Omeprazol'), ('Pantoprazol'), ('Ranitidina'), ('Domperidona'),
('Metoclopramida'), ('Loperamida'), ('Bismuto'), ('Lactulosa'),
('Simeticona'), ('Esomeprazol'),

-- Antihistamínicos / Alérgicos
('Loratadina'), ('Cetirizina'), ('Desloratadina'), ('Fexofenadina'),
('Difenhidramina'), ('Hidroxizina'),

-- Sistema Nervioso / Psiquiatría
('Clonazepam'), ('Sertralina'), ('Alprazolam'), ('Fluoxetina'),
('Escitalopram'), ('Amitriptilina'), ('Haloperidol'), ('Risperidona'),
('Paroxetina'), ('Diazepam'), ('Topiramato'), ('Carbamazepina'),
('Valproato'), ('Levetiracetam'),

-- Vitaminas / Suplementos
('Vitamina C'), ('Vitamina D'), ('Zinc'), ('Melatonina'),
('Vitamina B12'), ('Ácido Fólico'), ('Hierro'), ('Calcio'),
('Magnesio'), ('Omega 3'), ('Vitamina E'), ('Vitamina B6'),

-- Hormonas / Tiroides
('Levotiroxina'), ('Metilprednisolona'), ('Prednisona'), ('Dexametasona'),
('Hidrocortisona'), ('Betametasona'),

-- Anticoagulantes / Hematología
('Warfarina'), ('Enoxaparina'), ('Clopidogrel'), ('Rivaroxaban'),
('Ácido Tranexámico'),

-- Oftalmológicos / Dermatológicos
('Gentamicina'), ('Tobramicina'), ('Eritromicina'), ('Ketoconazol'),
('Clotrimazol'), ('Terbinafina'), ('Aciclovir'), ('Mupirocina'),

-- Urológicos / Otros
('Tamsulosina'), ('Finasteride'), ('Sildenafil'), ('Ondansetron'),
('Dexametasona'), ('Colistina');

DECLARE @Forms TABLE (Form NVARCHAR(50));
INSERT INTO @Forms VALUES
-- Dosis (sólidos)
('100mg'), ('200mg'), ('250mg'), ('400mg'), ('500mg'),
('750mg'), ('1000mg'), ('875mg'), ('625mg'), ('850mg'),

-- Dosis (líquidos / pequeñas)
('5mg'), ('10mg'), ('20mg'), ('25mg'), ('40mg'),
('50mg'), ('75mg'), ('80mg'),

-- Formas farmacéuticas sólidas
('Comprimidos'), ('Capsulas'), ('Capsulas Blandas'),
('Grageas'), ('Comprimidos Masticables'), ('Comprimidos Bucodispersables'),
('Polvo para Solución'), ('Granulado'),

-- Formas farmacéuticas líquidas
('Jarabe'), ('Suspensión'), ('Solución Oral'), ('Gotas Orales'),
('Elixir'), ('Emulsión'),

-- Formas inyectables
('Ampollas'), ('Vial'), ('Solución Inyectable'), ('Polvo Liofilizado'),
('Jeringa Prellenada'),

-- Formas tópicas
('Crema'), ('Ungüento'), ('Gel'), ('Loción'), ('Parche Transdérmico'),
('Espuma'), ('Solución Tópica'), ('Pomada'),

-- Formas especiales
('Gotas Oftálmicas'), ('Gotas Óticas'), ('Spray Nasal'),
('Inhalador'), ('Aerosol'), ('Nebulización'),
('Óvulos'), ('Supositorio'), ('Colirio');

/* ============================================================
   Genero productos combinando nombres de drogas con formas
   farmacéuticas y precios ente 1000 y 40000 ARS
============================================================ */
WITH DrugFormCombinations AS (
    SELECT 
        d.Name,
        f.Form,
        ROW_NUMBER() OVER (PARTITION BY d.Name ORDER BY NEWID()) AS rn
    FROM @DrugNames d
    CROSS JOIN @Forms f
)
INSERT INTO Products (ProductName, CategoryID, UnitPrice)
SELECT 
    CONCAT(Name, ' ', Form),
    ABS(CHECKSUM(NEWID())) % 8 + 1,
    ROUND(RAND(CHECKSUM(NEWID())) * 40000 + 1000, 2)
FROM DrugFormCombinations
WHERE rn <= 20;

/* ============================================================
   Agregemos un flag de receta médica para los productos de
   la categoría 1 (Medicamentos Recetados)
============================================================ */
UPDATE Products
SET RequiresPrescription = 
    CASE 
        WHEN CategoryID IN (1) THEN 1
        ELSE 0
    END;

/* ============================================================
   Agregemos el costo del producto como un porcentaje aleatorio
   del precio de venta
============================================================ */
UPDATE Products
SET CostPrice = UnitPrice * (0.5 + RAND(CHECKSUM(NEWID())) * 0.3);

/* ============================================================
   Vendedores
============================================================ */
INSERT INTO Sellers (SellerName, Region)
SELECT
    CONCAT('Seller ', n),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1, 'Norte','Sur','Centro','Patagonia')
FROM (SELECT TOP 20 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) n FROM sys.objects) t;

/* ============================================================
   Carga de inventario por depósito (3 lotes por producto)
============================================================ */

INSERT INTO Inventory (
    ProductID,
    WarehouseID,
    BatchNumber,
    ExpirationDate,
    QuantityOnHand
)
SELECT
    p.ProductID,
    ABS(CHECKSUM(NEWID())) % 5 + 1            AS WarehouseID,
    CONCAT('LOT-', ABS(CHECKSUM(NEWID())) % 100000) AS BatchNumber,
    DATEADD(
        DAY,
        ABS(CHECKSUM(NEWID())) % 900 + 90,
        GETDATE()
    ) AS ExpirationDate,
    ABS(CHECKSUM(NEWID())) % 500 + 50         AS QuantityOnHand
FROM Products p
CROSS APPLY (
    SELECT TOP 3 1 AS n
    FROM sys.objects
) t;

/* ============================================================
   Llenamos órdenes con datos aleatorios para los 12761 clientes
============================================================ */
INSERT INTO Orders (CustomerID, SellerID, OrderDate, OrderDateKey)
SELECT
    ABS(CHECKSUM(NEWID())) % 12761 + 1,
    ABS(CHECKSUM(NEWID())) % 20 + 1,
    dt.FullDate,
    dt.DateKey
FROM (
    SELECT TOP 10000
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 730, GETDATE()) AS OrderDate
    FROM sys.objects a
    CROSS JOIN sys.objects b
) x
JOIN DimDate dt
  ON CAST(x.OrderDate AS DATE) = dt.FullDate;

/* ============================================================
   Cada orden tendrá entre 2 y 5 productos aleatorios
============================================================ */

INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
SELECT
    o.OrderID,
    ABS(CHECKSUM(NEWID())) % 100 + 1,
    ABS(CHECKSUM(NEWID())) % 5 + 1,
    p.UnitPrice
FROM Orders o
CROSS APPLY (
    SELECT TOP (ABS(CHECKSUM(NEWID())) % 4 + 2) * FROM Products
) p;

/* ============================================================
   Generamos pagos para cada orden sumando el total de los
   productos y asignando un método de pago aleatorio
============================================================ */
INSERT INTO Payments (OrderID, PaymentMethodID, Amount, TransactionReference)
SELECT
    o.OrderID,
    ABS(CHECKSUM(NEWID())) % 6 + 1,
    SUM(od.Quantity * od.UnitPrice),
    CONCAT('TX-', ABS(CHECKSUM(NEWID())))
FROM Orders o
JOIN OrderDetails od ON o.OrderID = od.OrderID
GROUP BY o.OrderID;

/* ============================================================
    Generamos reembolsos para el 10% de las órdenes, con montos
    aleatorios entre el 20% y el 70% del total pagado, y una
    razón genérica de "Producto defectuoso"
============================================================ */
INSERT INTO Refunds (OrderID, PaymentID, Amount, Reason)
SELECT TOP (10) PERCENT
    p.OrderID,
    p.PaymentID,
    p.Amount * (RAND(CHECKSUM(NEWID())) * 0.5),
    'Producto defectuoso'
FROM Payments p;

PRINT 'Finalizado proceso de generación de datos aleatorios.';


/* ============================================================
    CREACION DE VISTAS
     Para facilitar el análisis y la creación de reportes en
     Power BI sin necesidad de escribir joins complejos o lógica
     de negocio en cada consulta.
============================================================ */

USE geolocalizacion;
GO

/* ============================================================
   Vistas de ventas y finanzas
   1. Vista base de ventas (detalle técnico)
============================================================ */
CREATE OR ALTER VIEW vw_sales_detail
AS
SELECT
    o.OrderID,
    o.OrderDate,
    o.OrderDateKey,

    c.CustomerID,
    c.CustomerName,
    c.CustomerCity,
    c.CustomerProvince,

    s.SellerID,
    s.SellerName,
    s.Region,

    p.ProductID,
    p.ProductName,

    cat.CategoryID,
    cat.CategoryName,

    od.OrderDetailID,
    od.Quantity,
    od.UnitPrice,
    od.Quantity * od.UnitPrice AS LineTotal
FROM Orders o
JOIN Customers c      ON o.CustomerID = c.CustomerID
JOIN Sellers s        ON o.SellerID   = s.SellerID
JOIN OrderDetails od  ON o.OrderID    = od.OrderID
JOIN Products p       ON od.ProductID = p.ProductID
JOIN Categories cat   ON p.CategoryID = cat.CategoryID;
GO

/* ============================================================
   2. Resumen de ventas (sin funciones de fecha)
============================================================ */
CREATE OR ALTER VIEW vw_sales_summary
AS
SELECT
    OrderDateKey,
    CategoryID,
    CategoryName,
    Region,

    SUM(LineTotal) AS TotalSales,
    SUM(Quantity)  AS UnitsSold,
    AVG(UnitPrice) AS AvgUnitPrice
FROM vw_sales_detail
GROUP BY
    OrderDateKey,
    CategoryID,
    CategoryName,
    Region;
GO

/* ============================================================
   3. Resumen de pagos
============================================================ */

CREATE OR ALTER VIEW vw_payments_summary
AS
SELECT
    p.PaymentID,
    p.PaymentDate,
    pm.PaymentMethodID,
    pm.MethodName,

    p.Amount,
    p.Status,

    o.OrderID,
    o.OrderDateKey,

    c.CustomerID,
    c.CustomerName,

    s.SellerID,
    s.SellerName,
    s.Region
FROM Payments p
JOIN PaymentMethods pm ON p.PaymentMethodID = pm.PaymentMethodID
JOIN Orders o          ON p.OrderID = o.OrderID
JOIN Customers c       ON o.CustomerID = c.CustomerID
JOIN Sellers s         ON o.SellerID = s.SellerID;
GO

/* ============================================================
   4. Vista financiera (ventas, pagos y reembolsos)
============================================================ */

CREATE OR ALTER VIEW vw_sales_financial_summary
AS
SELECT
    o.OrderID,
    o.OrderDateKey,

    SUM(od.Quantity * od.UnitPrice)          AS OrderTotal,
    ISNULL(SUM(DISTINCT p.Amount), 0)        AS PaidAmount,
    ISNULL(SUM(DISTINCT r.Amount), 0)        AS RefundedAmount,

    SUM(od.Quantity * od.UnitPrice)
      - ISNULL(SUM(DISTINCT r.Amount), 0)    AS NetSales
FROM Orders o
LEFT JOIN OrderDetails od ON o.OrderID = od.OrderID
LEFT JOIN Payments p      ON o.OrderID = p.OrderID
LEFT JOIN Refunds r       ON o.OrderID = r.OrderID
GROUP BY
    o.OrderID,
    o.OrderDateKey;
GO

/* ============================================================
   5. Inventario próximo a vencimiento
============================================================ */

CREATE OR ALTER VIEW vw_inventory_expiring
AS
SELECT
    p.ProductID,
    p.ProductName,

    c.CategoryID,
    c.CategoryName,

    i.WarehouseID,
    i.BatchNumber,
    i.ExpirationDate,
    i.QuantityOnHand,

    DATEDIFF(DAY, GETDATE(), i.ExpirationDate) AS DaysToExpire
FROM Inventory i
JOIN Products p  ON i.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
WHERE i.ExpirationDate <= DATEADD(DAY, 180, GETDATE());
GO

/* ============================================================
   6. Stock por almacén
============================================================ */

CREATE OR ALTER VIEW vw_inventory_by_warehouse
AS
SELECT
    w.WarehouseID,
    w.WarehouseName,
    w.City,

    p.ProductID,
    p.ProductName,

    c.CategoryID,
    c.CategoryName,

    SUM(i.QuantityOnHand) AS StockTotal,
    MIN(i.ExpirationDate) AS NextExpiration
FROM Inventory i
JOIN Warehouses w ON i.WarehouseID = w.WarehouseID
JOIN Products p   ON i.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY
    w.WarehouseID,
    w.WarehouseName,
    w.City,
    p.ProductID,
    p.ProductName,
    c.CategoryID,
    c.CategoryName;
GO

/* ============================================================
   7. FactSales: Vista de hecho de ventas con dimensiones clave y métricas
   Medidas listas para usar:
    - GrossSalesAmount
    - CostAmount
    - GrossMarginAmount
    - Quantity
    
    Uso en powerBI
     Relaciones:
      FactSales[OrderDateKey] → DimDate[DateKey]
      FactSales[ProductID]   → Products[ProductID]
      FactSales[CategoryID]  → Categories[CategoryID]
      FactSales[CustomerID]  → Customers[CustomerID]
      FactSales[SellerID]    → Sellers[SellerID]
     DAX:
      Total Sales := SUM(FactSales[GrossSalesAmount])
      Total Margin := SUM(FactSales[GrossMarginAmount])

============================================================ */

CREATE OR ALTER VIEW FactSales
AS
SELECT
    -- Claves del hecho
    od.OrderDetailID,

    -- Dimensiones
    o.OrderID,
    o.OrderDateKey,
    o.OrderDate,

    o.CustomerID,
    c.CustomerCity,
    c.CustomerProvince,
    c.CustomerCountry,

    o.SellerID,
    p.ProductID,
    p.CategoryID,

    -- Métricas
    od.Quantity,
    od.UnitPrice,
    od.Quantity * od.UnitPrice        AS GrossSalesAmount,

    p.CostPrice,
    od.Quantity * p.CostPrice         AS CostAmount,

    (od.Quantity * od.UnitPrice)
      - (od.Quantity * p.CostPrice)   AS GrossMarginAmount,

    -- Flags útiles
    p.RequiresPrescription

FROM OrderDetails od
INNER JOIN Orders o
    ON od.OrderID = o.OrderID
INNER JOIN Products p
    ON od.ProductID = p.ProductID
INNER JOIN Customers c
    ON o.CustomerID = c.CustomerID;
GO

-- 8. Vista DimGeografia

CREATE OR ALTER VIEW DimGeografia
AS 
SELECT
    ci.CityName,
    p.ProvinceName,
    c.CountryName
FROM Cities ci
JOIN Provinces p ON ci.ProvinceID = p.ProvinceID
JOIN Countries c ON ci.CountryID = c.CountryID;
GO
