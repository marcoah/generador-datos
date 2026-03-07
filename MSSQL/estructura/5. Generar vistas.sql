
USE geolocalizacion;
GO

-- 1. Vista base de ventas (detalle técnico)
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

-- 2. Resumen de ventas (sin funciones de fecha)
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

-- 3. Resumen de pagos
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

-- 4. Vista financiera (ventas, pagos y reembolsos)
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

-- 5. Inventario próximo a vencimiento
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

-- 6. Stock por almacén
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

-- 7. FactSales
/*
ºMedidas listas para usar
ºGrossSalesAmount
ºCostAmount
ºGrossMarginAmount
ºQuantity
*/

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

/* Uso en powerBI
Relaciones:
FactSales[OrderDateKey] → DimDate[DateKey]
FactSales[ProductID]   → Products[ProductID]
FactSales[CategoryID]  → Categories[CategoryID]
FactSales[CustomerID]  → Customers[CustomerID]
FactSales[SellerID]    → Sellers[SellerID]

DAX:
Total Sales := SUM(FactSales[GrossSalesAmount])
Total Margin := SUM(FactSales[GrossMarginAmount])
*/

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