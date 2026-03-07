-- ¿Qué ciudad contiene un punto?
DECLARE @p GEOGRAPHY =
geography::Point(-34.603722, -58.381592, 4326); -- Obelisco

SELECT CityName
FROM Cities
WHERE GeoPolygon.STContains(@p) = 1;

-- Distancia entre dos puntos (en metros)
DECLARE @p1 geography = geography::Point(-34.603722, -58.381592, 4326); -- Obelisco
DECLARE @p2 geography = geography::Point(-34.608418, -58.373161, 4326); -- Plaza de Mayo

SELECT @p1.STDistance(@p2) AS DistanciaEnMetros;


--Distancia desde una ciudad a otra (centroides)
SELECT
    c1.CityName AS FromCity,
    c2.CityName AS ToCity,
    c1.GeoPoint.STDistance(c2.GeoPoint)/1000 AS DistanceKm
FROM Cities c1
JOIN Cities c2 ON c2.CityName = 'Córdoba'
WHERE c1.CityName = 'Rosario';

--Ciudades dentro de 300 km de Córdoba
DECLARE @Cordoba GEOGRAPHY =
(SELECT GeoPoint FROM Cities WHERE CityName = 'Córdoba');

SELECT
    CityName,
    GeoPoint.STDistance(@Cordoba)/1000 AS DistanceKm
FROM Cities
WHERE GeoPoint.STDistance(@Cordoba) <= 300000
ORDER BY DistanceKm;


-- Comparar clientes dentro y fuera de ciudades registradas

use geolocalizacion;
GO

SELECT 
    CASE 
        WHEN ci.CityID IS NOT NULL THEN 'Dentro de ciudad'
        ELSE 'Fuera de ciudades'
    END AS Ubicacion,
    COUNT(DISTINCT cu.CustomerID) AS TotalClientes
FROM Customers cu
LEFT JOIN Cities ci ON ci.GeoPolygon.STContains(cu.GeoLocation) = 1
GROUP BY CASE WHEN ci.CityID IS NOT NULL THEN 'Dentro de ciudad' ELSE 'Fuera de ciudades' END;


