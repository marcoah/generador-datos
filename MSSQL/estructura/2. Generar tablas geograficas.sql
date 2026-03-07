-- Insertar provincias y ciudades
USE geolocalizacion;
GO

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
    GeoPoint GEOGRAPHY NOT NULL,

    -- Área urbana aproximada
    GeoPolygon GEOGRAPHY NOT NULL,

    FOREIGN KEY (CountryID) REFERENCES Countries(CountryID),
    FOREIGN KEY (ProvinceID) REFERENCES Provinces(ProvinceID)
);
PRINT 'Tabla Cities creada correctamente';

-- Indices
CREATE SPATIAL INDEX IX_Cities_GeoPoint
ON Cities(GeoPoint);

CREATE SPATIAL INDEX IX_Cities_GeoPolygon
ON Cities(GeoPolygon);

-- Cargar Paises
INSERT INTO Countries (CountryID, CountryName)
VALUES
(1,'Argentina');

-- Cargar Provincias
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

-- Cargar ciudades

INSERT INTO Cities (CityName, ProvinceID, CountryID, GeoPoint, GeoPolygon)
VALUES
-- 1 CABA
(
    'Buenos Aires',
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

--Resolucion del problema del anillo invertido.
UPDATE Cities
SET GeoPolygon = GeoPolygon.ReorientObject();
