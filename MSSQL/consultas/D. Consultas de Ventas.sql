-- Lista de productos
Select * from products;

-- Ventas por Producto
SELECT 
    c.CategoryName,
    p.ProductName,
    SUM(od.Quantity) AS TotalUnidades,
    SUM(od.Quantity * od.UnitPrice) AS TotalVentas,
    AVG(od.UnitPrice) AS PrecioPromedio
FROM OrderDetails od
INNER JOIN Products p ON p.ProductID = od.ProductID
INNER JOIN Categories c ON c.CategoryID = p.CategoryID
GROUP BY c.CategoryName, p.ProductID, p.ProductName
ORDER BY c.CategoryName, TotalVentas DESC;

-- Ventas por cliente
SELECT 
    cu.CustomerID,
    cu.CustomerName AS Cliente,
    COUNT(DISTINCT o.OrderID) AS TotalPedidos,
    SUM(od.Quantity) AS TotalUnidades,
    SUM(od.Quantity * od.UnitPrice) AS TotalVentas
FROM Customers cu
INNER JOIN Orders o ON o.CustomerID = cu.CustomerID
INNER JOIN OrderDetails od ON od.OrderID = o.OrderID
GROUP BY cu.CustomerID, cu.CustomerName
ORDER BY TotalVentas DESC;

-- Ventas por ciudad
SELECT 
    cu.CustomerProvince,
    cu.CustomerCity,
    COUNT(DISTINCT cu.CustomerID) AS TotalClientes,
    COUNT(DISTINCT o.OrderID) AS TotalPedidos,
    SUM(od.Quantity) AS TotalUnidades,
    SUM(od.Quantity * od.UnitPrice) AS TotalVentas
FROM Customers cu
INNER JOIN Orders o ON o.CustomerID = cu.CustomerID
INNER JOIN OrderDetails od ON od.OrderID = o.OrderID
WHERE YEAR(o.OrderDate) = 2025
GROUP BY cu.CustomerProvince, cu.CustomerCity
ORDER BY cu.CustomerProvince, TotalVentas DESC;

-- Ventas por ciudad (unicamente lo que este en cities)
SELECT 
    ci.CityID,
    ci.CityName,
    cu.CustomerCity,    
    COUNT(DISTINCT cu.CustomerID) AS TotalClientes,
    COUNT(DISTINCT o.OrderID) AS TotalPedidos,
    SUM(od.Quantity) AS TotalUnidades,
    SUM(od.Quantity * od.UnitPrice) AS TotalVentas
FROM Customers cu
INNER JOIN Cities ci ON ci.CityName = cu.CustomerCity
INNER JOIN Orders o ON o.CustomerID = cu.CustomerID
INNER JOIN OrderDetails od ON od.OrderID = o.OrderID
WHERE YEAR(o.OrderDate) = 2025
GROUP BY ci.CityID, cu.CustomerCity, ci.CityName
ORDER BY ci.CityName ASC;

-- Ventas por ciudad, pero Geospatial
SELECT 
    ci.CityID,
    ci.CityName,
    COUNT(DISTINCT cu.CustomerID) AS TotalClientes,
    COUNT(DISTINCT o.OrderID) AS TotalPedidos,
    SUM(od.Quantity) AS TotalUnidades,
    SUM(od.Quantity * od.UnitPrice) AS TotalVentas
FROM Cities ci
LEFT JOIN Customers cu ON ci.GeoPolygon.STContains(cu.GeoLocation) = 1
LEFT JOIN Orders o ON o.CustomerID = cu.CustomerID
LEFT JOIN OrderDetails od ON od.OrderID = o.OrderID
WHERE YEAR(o.OrderDate) = 2025
GROUP BY ci.CityID, ci.CityName
ORDER BY ci.CityName ASC;

-- Ventas fuera de las ciudades registradas
SELECT 
    cu.CustomerID,
    cu.CustomerProvince,
    cu.CustomerCity,
    COUNT(DISTINCT o.OrderID) AS TotalPedidos,
    SUM(od.Quantity) AS TotalUnidades,
    SUM(od.Quantity * od.UnitPrice) AS TotalVentas
FROM Customers cu
LEFT JOIN Orders o ON o.CustomerID = cu.CustomerID
LEFT JOIN OrderDetails od ON od.OrderID = o.OrderID
WHERE YEAR(o.OrderDate) = 2025
  AND NOT EXISTS (
      SELECT 1 
      FROM Cities ci 
      WHERE ci.GeoPolygon.STContains(cu.GeoLocation) = 1
  )
GROUP BY cu.CustomerID, cu.CustomerProvince, cu.CustomerCity
ORDER BY TotalVentas DESC;

-- Resumen de ventas fuera de ciudades por provincia/ciudad declarada
SELECT 
    cu.CustomerProvince,
    cu.CustomerCity,
    COUNT(DISTINCT cu.CustomerID) AS TotalClientes,
    COUNT(DISTINCT o.OrderID) AS TotalPedidos,
    SUM(od.Quantity) AS TotalUnidades,
    SUM(od.Quantity * od.UnitPrice) AS TotalVentas
FROM Customers cu
LEFT JOIN Orders o ON o.CustomerID = cu.CustomerID
LEFT JOIN OrderDetails od ON od.OrderID = o.OrderID
WHERE YEAR(o.OrderDate) = 2025
  AND NOT EXISTS (
      SELECT 1 
      FROM Cities ci 
      WHERE ci.GeoPolygon.STContains(cu.GeoLocation) = 1
  )
GROUP BY cu.CustomerProvince, cu.CustomerCity
ORDER BY TotalVentas DESC;

--Consulta 2: Obtener la cantidad de clientes por ciudad (Geoespacial)
SELECT 
    ci.CityID,
    ci.CityName,
    COUNT(DISTINCT cu.CustomerID) AS TotalClientes
FROM Cities ci
LEFT JOIN Customers cu ON ci.GeoPolygon.STContains(geography::STGeomFromWKB(cu.GeoLocation.STAsBinary(), cu.GeoLocation.STSrid)) = 1
GROUP BY ci.CityID, ci.CityName
ORDER BY TotalClientes DESC;