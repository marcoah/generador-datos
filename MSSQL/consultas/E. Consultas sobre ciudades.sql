-- Informacion de ciudades con puntos geográficos
SELECT 
    ci.CityID,
    ci.CityName,
    ci.GeoPoint AS PuntoGrafico,
    ci.GeoPoint.ToString() AS Punto
FROM Cities ci
ORDER BY ci.CityID;

-- Informacion de ciudades con polígonos geográficos
SELECT 
    ci.CityID,
    ci.CityName,
    ci.GeoPolygon AS PoligonoGrafico,
    ci.GeoPolygon.ToString() AS Poligono,
    ci.GeoPolygon.STArea() AS AreaM2,
    ci.GeoPolygon.STNumPoints() AS TotalPuntos
FROM Cities ci
ORDER BY ci.CityID;

-- Ver el tipo de dato de GeoPolygon
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Cities' 
  AND COLUMN_NAME = 'GeoPolygon';

  -- Corregir la orientación de todos los polígonos
UPDATE Cities
SET GeoPolygon = GeoPolygon.ReorientObject();

-- Ver si los polígonos son válidos
SELECT 
    CityName,
    GeoPolygon.STIsValid() AS EsValido,
    GeoPolygon.STAsText() AS PoligonoWKT
FROM Cities;

-- Informacion de ciudades con polígonos geográficos
SELECT 
    ci.CityID,
    ci.CityName,
    ci.GeoPolygon AS PoligonoGrafico,
    ci.GeoPolygon.ToString() AS Poligono,
    ci.GeoPolygon.STArea() AS AreaM2,
    ci.GeoPolygon.STNumPoints() AS TotalPuntos
FROM Cities ci
ORDER BY ci.CityID;


