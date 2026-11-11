-- ============================================================
-- PREGUNTA 3. EVOLUCIÓN COMERCIAL POR REGIÓN
-- CTE + funciones de ventana (LAG, RANK)
-- ============================================================
USE db_superstore_jhaelguevara;

SET hive.cli.print.header = true;
SET hive.resultset.use.unique.column.names = false;

-- Ejecución local para datasets pequeños (2 MB)
SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;
SET hive.exec.mode.local.auto.inputbytes.max = 134217728;
SET hive.exec.mode.local.auto.input.files.max = 8;

-- 3.1 Ventas, ganancia, margen y variación año a año por región
WITH regional_year AS (
    SELECT
        region,
        order_year AS anio,
        SUM(sales)  AS ventas,
        SUM(profit) AS ganancia
    FROM superstore
    GROUP BY region, order_year
),
con_variacion AS (
    SELECT
        region,
        anio,
        ROUND(ventas, 2)   AS ventas,
        ROUND(ganancia, 2) AS ganancia,
        ROUND(ganancia / ventas * 100, 2) AS margen_pct,
        ROUND(LAG(ventas) OVER (PARTITION BY region ORDER BY anio), 2) AS ventas_anio_anterior,
        ROUND(
            (ventas - LAG(ventas) OVER (PARTITION BY region ORDER BY anio))
            / LAG(ventas) OVER (PARTITION BY region ORDER BY anio) * 100,
        2) AS variacion_ventas_pct,
        ROUND(
            (ganancia - LAG(ganancia) OVER (PARTITION BY region ORDER BY anio))
            / LAG(ganancia) OVER (PARTITION BY region ORDER BY anio) * 100,
        2) AS variacion_ganancia_pct
    FROM regional_year
)
SELECT *
FROM con_variacion
ORDER BY region, anio;

-- 3.2 Ranking de regiones por desempeño total (mejor y peor)
WITH total_region AS (
    SELECT
        region,
        SUM(sales)  AS ventas,
        SUM(profit) AS ganancia
    FROM superstore
    GROUP BY region
)
SELECT
    region,
    ROUND(ventas, 2)  AS ventas_totales,
    ROUND(ganancia, 2) AS ganancia_total,
    ROUND(ganancia / ventas * 100, 2) AS margen_pct,
    RANK() OVER (ORDER BY ventas DESC)   AS rank_ventas,
    RANK() OVER (ORDER BY ganancia DESC) AS rank_ganancia,
    RANK() OVER (ORDER BY ganancia / ventas DESC) AS rank_margen
FROM total_region
ORDER BY rank_ganancia;

-- 3.3 Participación de cada región en ventas y ganancia totales
SELECT
    region,
    ROUND(SUM(sales), 2)  AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(sales)  / SUM(SUM(sales))  OVER () * 100, 2) AS pct_ventas,
    ROUND(SUM(profit) / SUM(SUM(profit)) OVER () * 100, 2) AS pct_ganancia
FROM superstore
GROUP BY region
ORDER BY ventas DESC;
