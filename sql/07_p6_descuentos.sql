-- ============================================================
-- PREGUNTA 6. ANÁLISIS DEL IMPACTO DE LOS DESCUENTOS
-- ============================================================
USE db_superstore_jhaelguevara;

SET hive.cli.print.header = true;
SET hive.resultset.use.unique.column.names = false;

-- Ejecución local para datasets pequeños (2 MB)
SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;
SET hive.exec.mode.local.auto.inputbytes.max = 134217728;
SET hive.exec.mode.local.auto.input.files.max = 8;

-- 6.1 Métricas por rango de descuento
WITH base AS (
    SELECT
        *,
        CASE
            WHEN discount = 0                     THEN '1. Sin descuento (0%)'
            WHEN discount > 0  AND discount <= 0.2 THEN '2. Bajo (0% - 20%]'
            WHEN discount > 0.2 AND discount <= 0.5 THEN '3. Medio (20% - 50%]'
            ELSE '4. Alto (> 50%)'
        END AS rango_descuento
    FROM superstore
)
SELECT
    rango_descuento,
    COUNT(*)                                                     AS registros,
    ROUND(SUM(sales), 2)                                         AS ventas,
    ROUND(SUM(profit), 2)                                        AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)                     AS margen_pct,
    SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END)                  AS registros_con_perdida,
    ROUND(SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_no_rentables,
    ROUND(AVG(discount) * 100, 2)                                AS descuento_promedio_pct,
    ROUND(AVG(profit), 2)                                        AS ganancia_promedio_registro
FROM base
GROUP BY rango_descuento
ORDER BY rango_descuento;

-- 6.2 Categorías más afectadas por rango de descuento
WITH base AS (
    SELECT
        *,
        CASE
            WHEN discount = 0                     THEN 'Sin descuento'
            WHEN discount > 0  AND discount <= 0.2 THEN 'Bajo'
            WHEN discount > 0.2 AND discount <= 0.5 THEN 'Medio'
            ELSE 'Alto'
        END AS rango_descuento
    FROM superstore
)
SELECT
    rango_descuento,
    category,
    COUNT(*)                                        AS registros,
    ROUND(SUM(sales), 2)                            AS ventas,
    ROUND(SUM(profit), 2)                           AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2)        AS margen_pct,
    ROUND(SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_no_rentables
FROM base
GROUP BY rango_descuento, category
ORDER BY rango_descuento, pct_no_rentables DESC;

-- 6.3 Subcategorías más afectadas en descuentos altos (>50%)
WITH alta AS (
    SELECT *
    FROM superstore
    WHERE discount > 0.5
)
SELECT
    sub_category,
    category,
    COUNT(*)                                 AS registros,
    ROUND(SUM(sales), 2)                     AS ventas,
    ROUND(SUM(profit), 2)                    AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct,
    ROUND(AVG(discount) * 100, 2)            AS descuento_promedio_pct,
    ROUND(SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_perdida
FROM alta
GROUP BY sub_category, category
ORDER BY pct_perdida DESC, ventas DESC;

-- 6.4 Contraste: operaciones rentables vs. no rentables según descuento
SELECT
    CASE WHEN profit < 0 THEN 'No rentable (perdida)' ELSE 'Rentable' END AS resultado,
    COUNT(*)                         AS registros,
    ROUND(AVG(discount) * 100, 2)    AS descuento_promedio_pct,
    ROUND(AVG(sales), 2)             AS venta_promedio,
    ROUND(AVG(profit), 2)            AS ganancia_promedio
FROM superstore
GROUP BY CASE WHEN profit < 0 THEN 'No rentable (perdida)' ELSE 'Rentable' END;

-- 6.5 Distribución por descuento exacto
SELECT
    ROUND(discount * 100, 0) AS descuento_pct,
    COUNT(*)                 AS registros,
    ROUND(SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_no_rentables,
    ROUND(SUM(profit), 2)    AS ganancia_total
FROM superstore
GROUP BY ROUND(discount * 100, 0)
ORDER BY descuento_pct;
