-- Generar Datos aleatorios
USE geolocalizacion;
GO

-- DIMDATE
-- Para Power BI
-- Orders.OrderDate → DimDate.FullDate
-- Cardinalidad: Many-to-One
-- Dirección de filtro: Single

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

-- Categorias
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

-- Metodos de pago
INSERT INTO PaymentMethods (MethodName)
VALUES
('Tarjeta Crédito'),
('Tarjeta Débito'),
('Transferencia'),
('Efectivo'),
('Obra Social'),
('MercadoPago');

-- Almacenes
INSERT INTO Warehouses (WarehouseName, City, CityID, Region)
VALUES
('Depósito Central', 'Buenos Aires', 1, 'Centro'),
('Sucursal Córdoba', 'Córdoba', 2, 'Centro'),
('Sucursal Rosario', 'Rosario', 3, 'Litoral'),
('Sucursal Mendoza', 'Mendoza', 6,  'Cuyo'),
('Sucursal Salta', 'Salta', 8, 'Norte');


-- Productos
-- Tomo aleatoriamente los valores desde variables 
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

-- Precios entre 1000 y 40000
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

-- Agregamos algunos productos con restriccion
UPDATE Products
SET RequiresPrescription = 
    CASE 
        WHEN CategoryID IN (1) THEN 1
        ELSE 0
    END;

-- Agregemos costo del producto
UPDATE Products
SET CostPrice = UnitPrice * (0.5 + RAND(CHECKSUM(NEWID())) * 0.3);



-- Vendedores
INSERT INTO Sellers (SellerName, Region)
SELECT
    CONCAT('Seller ', n),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1, 'Norte','Sur','Centro','Patagonia')
FROM (SELECT TOP 20 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) n FROM sys.objects) t;

-- Carga de inventario por depósito (3 lotes por producto)
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

-- Ordenes
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


-- Items en ordenes 3 a 6
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


-- Generar pagos 
INSERT INTO Payments (OrderID, PaymentMethodID, Amount, TransactionReference)
SELECT
    o.OrderID,
    ABS(CHECKSUM(NEWID())) % 6 + 1,
    SUM(od.Quantity * od.UnitPrice),
    CONCAT('TX-', ABS(CHECKSUM(NEWID())))
FROM Orders o
JOIN OrderDetails od ON o.OrderID = od.OrderID
GROUP BY o.OrderID;

-- Generemos unos reembolsos 10%
INSERT INTO Refunds (OrderID, PaymentID, Amount, Reason)
SELECT TOP (10) PERCENT
    p.OrderID,
    p.PaymentID,
    p.Amount * (RAND(CHECKSUM(NEWID())) * 0.5),
    'Producto defectuoso'
FROM Payments p;
