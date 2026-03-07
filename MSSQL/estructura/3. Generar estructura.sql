/* ============================================================
   PROYECTO: Geolocalización
   MOTOR  : SQL Server
   OBJETIVO:
     - Modelo tipo DW / OLTP híbrido
     - Dimensiones + Hechos
     - Customers derivados desde fuente geoespacial (salud)
     - Preparado para Power BI y análisis geográfico
============================================================ */

/* ============================================================
   BASE DE DATOS
============================================================ */
/*
CREATE DATABASE DemoGeolocalizacionDW;
GO
USE DemoGeolocalizacionDW;
GO
*/

USE geolocalizacion;
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

-- ========================
-- Customers (desde fuente SALUD)
-- ========================
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

-- Clave primaria (requisito para índice espacial)
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

-- ========================
-- Vendedores
-- ========================
CREATE TABLE Sellers (
    SellerID INT IDENTITY PRIMARY KEY,
    SellerName NVARCHAR(150) NOT NULL,
    Region NVARCHAR(100)
);
GO

-- ========================
-- Almacenes
-- ========================
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

-- ========================
-- Métodos de Pago
-- ========================
CREATE TABLE PaymentMethods (
    PaymentMethodID INT IDENTITY PRIMARY KEY,
    MethodName NVARCHAR(50) NOT NULL,
    IsActive BIT DEFAULT 1
);
GO

-- ========================
-- Dimensión Fecha
-- ========================
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

-- ========================
-- Inventario
-- ========================
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

-- ========================
-- Órdenes (Header)
-- ========================
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

-- ========================
-- Órdenes (Detalle)
-- ========================
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

-- ========================
-- Pagos
-- ========================
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

-- ========================
-- Reintegros
-- ========================
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
