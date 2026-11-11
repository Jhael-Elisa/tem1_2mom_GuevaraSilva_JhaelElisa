-- ============================================================
-- PREGUNTA 7. ANÁLISIS DE TENDENCIAS TEMPORALES
-- LAG(), promedio móvil y agregaciones mensuales
-- ============================================================
USE db_superstore_jhaelguevara;

SET hive.cli.print.header = true;
SET hive.resultset.use.unique.column.names = false;

-- Ejecución local para datasets pequeños (2 MB)
SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;
SET hive.exec.mode.local.auto.inputbytes.max = 134217728;
SET hive.exec.mode.local.auto.input.files.max = 8;

-- 7.1 Evolución mensual con variación MoM, YoY y promedio móvil de 3 meses
WITH mensual AS (
    SELECT
        CONCAT(CAST(YEAR(order_date) AS STRING), '-', LPAD(CAST(MONTH(order_date) AS STRING), 2, '0')) AS mes,
        SUM(sales)  AS ventas,
        SUM(profit) AS ganancia
    FROM superstore
    GROUP BY CONCAT(CAST(YEAR(order_date) AS STRING), '-', LPAD(CAST(MONTH(order_date) AS STRING), 2, '0'))
),
calculado AS (
    SELECT
        mes,
        ROUND(ventas, 2)   AS ventas,
        ROUND(ganancia, 2) AS ganancia,
        ROUND(LAG(ventas) OVER (ORDER BY mes), 2) AS ventas_mes_anterior,
        ROUND(
            (ventas - LAG(ventas) OVER (ORDER BY mes))
            / LAG(ventas) OVER (ORDER BY mes) * 100,
        2) AS variacion_mom_pct,
        ROUND(LAG(ventas, 12) OVER (ORDER BY mes), 2) AS ventas_mismo_mes_anio_anterior,
        ROUND(
            (ventas - LAG(ventas, 12) OVER (ORDER BY mes))
            / LAG(ventas, 12) OVER (ORDER BY mes) * 100,
        2) AS variacion_yoy_pct,
        ROUND(AVG(ventas) OVER (
            ORDER BY mes
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS promedio_movil_3m
    FROM mensual
)
SELECT *
FROM calculado
ORDER BY mes;

-- 7.2 Tres meses con mayor y menor volumen de ventas
WITH mensual AS (
    SELECT
        CONCAT(CAST(YEAR(order_date) AS STRING), '-', LPAD(CAST(MONTH(order_date) AS STRING), 2, '0')) AS mes,
        SUM(sales)  AS ventas,
        SUM(profit) AS ganancia
    FROM superstore
    GROUP BY CONCAT(CAST(YEAR(order_date) AS STRING), '-', LPAD(CAST(MONTH(order_date) AS STRING), 2, '0'))
),
ranked AS (
    SELECT
        mes,
        ROUND(ventas, 2)   AS ventas,
        ROUND(ganancia, 2) AS ganancia,
        RANK() OVER (ORDER BY ventas DESC) AS rank_mayor_venta,
        RANK() OVER (ORDER BY ventas ASC)  AS rank_menor_venta
    FROM mensual
)
SELECT
    'Mayor volumen' AS grupo,
    mes,
    ventas,
    ganancia,
    rank_mayor_venta AS posicion
FROM ranked
WHERE rank_mayor_venta <= 3
UNION ALL
SELECT
    'Menor volumen' AS grupo,
    mes,
    ventas,
    ganancia,
    rank_menor_venta AS posicion
FROM ranked
WHERE rank_menor_venta <= 3
ORDER BY grupo, posicion;

-- 7.3 Totales anuales como contexto
SELECT
    order_year AS anio,
    COUNT(*)             AS registros,
    ROUND(SUM(sales), 2) AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM superstore
GROUP BY order_year
ORDER BY anio;
