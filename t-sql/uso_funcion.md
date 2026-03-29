# Cómo usarla (modo elegante)

## 1. Generar múltiples registros

-- Generar 20 nombres aleatorios

´´´sql
SELECT TOP 20
n.nombre_completo
FROM sys.objects o
CROSS APPLY dbo.fn_nombre_por_indices(
CASE WHEN RAND(CHECKSUM(NEWID())) > 0.5 THEN 'M' ELSE 'F' END,
(ABS(CHECKSUM(NEWID())) % 10) + 1,
(ABS(CHECKSUM(NEWID())) % 10) + 1
) n;
´´´
