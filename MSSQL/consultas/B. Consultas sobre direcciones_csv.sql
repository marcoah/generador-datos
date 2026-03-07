USE geolocalizacion;
GO

-- Agregar una nueva columna de tipo GEOGRAPHY
ALTER TABLE direcciones_csv
ADD ubicacion GEOGRAPHY;


-- 2. Poblar la columna con los valores existentes
UPDATE direcciones_csv
SET ubicacion = GEOGRAPHY::Point(latitud, longitud, 4326) WHERE latitud IS NOT NULL AND longitud IS NOT NULL;
-- 4326 = SRID para WGS 84, el sistema de referencia usado por GPS


-- Ver puntos en WKT (Well Known Text)
SELECT
    latitud, longitud, ubicacion.ToString() AS ubicacion_wkt
FROM geolocalizacion.dbo.direcciones_csv;



USE geolocalizacion;
GO

-- Distancia entre dos puntos (ejemplo con dos filas específicas)
SELECT
    d1.id AS id1, d2.id AS id2,
    d1.ubicacion.STDistance(d2.ubicacion) AS distancia_metros
FROM geolocalizacion.dbo.direcciones_csv d1
CROSS JOIN geolocalizacion.dbo.direcciones_csv d2
WHERE d1.id = 1 AND d2.id = 7; -- Reemplaza con los IDs de las filas que quieras comparar

-- Ver puntos en Spatial Results
SELECT
    ubicacion
FROM geolocalizacion.dbo.direcciones_csv
WHERE ubicacion IS NOT NULL;
