USE geolocalizacion;
GO

--Validaciones
SELECT COUNT(*) AS TotalCustomers FROM Customers;

SELECT COUNT(*) AS WithNullCity 
FROM Customers
WHERE CustomerCity IS NULL
   --OR CustomerProvince IS NULL
   --OR CustomerCountry IS NULL;

--Consulta 1: Obtener la cantidad de clientes por ciudad (Geoespacial)
SELECT 
    CustomerCity,
    COUNT(CustomerID) AS TotalClientes
FROM Customers
GROUP BY CustomerCity
ORDER BY CustomerCity, TotalClientes DESC;

USE geolocalizacion;
GO
-- Consulta 2: Obtener clientes que tienen ciiudad null pero tienen su geolocalizacion dentro de un polígono de ciudad
SELECT
    c.CustomerID,
    c.CustomerCity AS CiudadActual,
    c.GeoLocation.STAsText() AS Coordenadas,
    expected.CityName AS CiudadEsperada
FROM Customers c
OUTER APPLY (
    SELECT TOP 1 ci.CityName
    FROM Cities ci
    WHERE ci.GeoPolygon IS NOT NULL
      AND ci.GeoPolygon.STContains(
            geography::Point(c.Latitude, c.Longitude, 4326)
          ) = 1
) expected
WHERE c.CustomerCity IS NULL
  AND c.Latitude  IS NOT NULL
  AND c.Longitude IS NOT NULL;

-- Ejecutar el UPDATE para la correccion
UPDATE cu
SET cu.CustomerCity = ci.CityName
FROM Customers cu
INNER JOIN Cities ci ON ci.GeoPolygon.STContains(geography::STGeomFromWKB(cu.GeoLocation.STAsBinary(), cu.GeoLocation.STSrid)) = 1
WHERE cu.CustomerCity != ci.CityName OR cu.CustomerCity IS NULL;
