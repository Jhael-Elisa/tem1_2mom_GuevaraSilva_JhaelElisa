-- ============================================================
-- PREGUNTA 8. ANÁLISIS PARETO DE VENTAS Y RENTABILIDAD
-- ============================================================
USE db_superstore_jhaelguevara;

SET hive.cli.print.header = true;
SET hive.resultset.use.unique.column.names = false;

-- Ejecución local para datasets pequeños (2 MB)
SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;
SET hive.exec.mode.local.auto.inputbytes.max = 134217728;
SET hive.exec.mode.local.auto.input.files.max = 8;

-- 8.1 Pareto de VENTAS: acumulado y porcentaje acumulado
WITH producto AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name,
        SUM(sales)        AS ventas,
        SUM(profit)       AS ganancia
    FROM superstore
    GROUP BY product_id
),
ordenado AS (
    SELECT
        product_id,
        product_name,
        ventas,
        ganancia,
        ROW_NUMBER() OVER (ORDER BY ventas DESC) AS posicion,
        SUM(ventas) OVER (ORDER BY ventas DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ventas_acumuladas,
        SUM(ventas) OVER () AS total_ventas
    FROM producto
)
SELECT
    posicion,
    product_id,
    product_name,
    ROUND(ventas, 2)            AS ventas,
    ROUND(ventas / total_ventas * 100, 4) AS pct_participacion,
    ROUND(ventas_acumuladas, 2) AS ventas_acumuladas,
    ROUND(ventas_acumuladas / total_ventas * 100, 2) AS pct_acumulado
FROM ordenado
ORDER BY posicion
LIMIT 30;

-- 8.2 Pareto de GANANCIAS: acumulado y porcentaje acumulado
WITH producto AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name,
        SUM(sales)        AS ventas,
        SUM(profit)       AS ganancia
    FROM superstore
    GROUP BY product_id
),
ordenado AS (
    SELECT
        product_id,
        product_name,
        ventas,
        ganancia,
        ROW_NUMBER() OVER (ORDER BY ganancia DESC) AS posicion,
        SUM(ganancia) OVER (ORDER BY ganancia DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ganancia_acumulada,
        SUM(ganancia) OVER () AS total_ganancia
    FROM producto
)
SELECT
    posicion,
    product_id,
    product_name,
    ROUND(ganancia, 2) AS ganancia,
    ROUND(ganancia / total_ganancia * 100, 4) AS pct_participacion,
    ROUND(ganancia_acumulada, 2) AS ganancia_acumulada,
    ROUND(ganancia_acumulada / total_ganancia * 100, 2) AS pct_acumulado
FROM ordenado
ORDER BY posicion
LIMIT 30;

-- 8.3 Comparación 80/20: cuántos productos concentran el 80% de ventas y ganancias
WITH producto AS (
    SELECT
        product_id,
        SUM(sales)  AS ventas,
        SUM(profit) AS ganancia
    FROM superstore
    GROUP BY product_id
),
pareto_ventas AS (
    SELECT
        SUM(ventas) OVER (ORDER BY ventas DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / SUM(ventas) OVER () * 100 AS pct_acum,
        ROW_NUMBER() OVER (ORDER BY ventas DESC) AS posicion
    FROM producto
),
pareto_ganancia AS (
    SELECT
        SUM(ganancia) OVER (ORDER BY ganancia DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / SUM(ganancia) OVER () * 100 AS pct_acum,
        ROW_NUMBER() OVER (ORDER BY ganancia DESC) AS posicion
    FROM producto
)
SELECT
    'Ventas' AS metrica,
    (SELECT COUNT(*) FROM producto) AS total_productos,
    (SELECT MIN(posicion) FROM pareto_ventas WHERE pct_acum >= 80) AS productos_para_80pct,
    ROUND((SELECT MIN(posicion) FROM pareto_ventas WHERE pct_acum >= 80)
          / (SELECT COUNT(*) FROM producto) * 100, 2) AS pct_catalogo
UNION ALL
SELECT
    'Ganancia' AS metrica,
    (SELECT COUNT(*) FROM producto) AS total_productos,
    (SELECT MIN(posicion) FROM pareto_ganancia WHERE pct_acum >= 80) AS productos_para_80pct,
    ROUND((SELECT MIN(posicion) FROM pareto_ganancia WHERE pct_acum >= 80)
          / (SELECT COUNT(*) FROM producto) * 100, 2) AS pct_catalogo;
