-- ============================================================
-- PREGUNTA 5. RANKING DE PRODUCTOS SEGÚN RENTABILIDAD
-- RANK(), DENSE_RANK() y agregación acumulativa
-- ============================================================
USE db_superstore_jhaelguevara;

SET hive.cli.print.header = true;
SET hive.resultset.use.unique.column.names = false;

-- Ejecución local para datasets pequeños (2 MB)
SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;
SET hive.exec.mode.local.auto.inputbytes.max = 134217728;
SET hive.exec.mode.local.auto.input.files.max = 8;

-- 5.1 Top 5 productos con mayor ganancia acumulada por categoría
WITH producto AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name,
        MAX(category)     AS category,
        MAX(sub_category) AS sub_category,
        SUM(sales)        AS ventas,
        SUM(profit)       AS ganancia,
        SUM(quantity)     AS unidades,
        COUNT(DISTINCT order_id) AS ordenes
    FROM superstore
    GROUP BY product_id
),
ranked AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY category ORDER BY ganancia DESC) AS rk,
        ROUND(SUM(ganancia) OVER (
            PARTITION BY category
            ORDER BY ganancia DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS ganancia_acumulada_categoria
    FROM producto
)
SELECT
    category,
    rk AS posicion,
    product_id,
    product_name,
    ROUND(ganancia, 2) AS ganancia,
    ganancia_acumulada_categoria,
    ROUND(ventas, 2)   AS ventas,
    ROUND(ganancia / ventas * 100, 2) AS margen_pct
FROM ranked
WHERE rk <= 5
ORDER BY category, rk;

-- 5.2 Top 5 productos con mayor volumen de ventas
WITH producto AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name,
        MAX(category)     AS category,
        SUM(sales)        AS ventas,
        SUM(profit)       AS ganancia
    FROM superstore
    GROUP BY product_id
),
ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (ORDER BY ventas DESC) AS posicion,
        ROUND(SUM(ventas) OVER (
            ORDER BY ventas DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS ventas_acumuladas
    FROM producto
)
SELECT
    posicion,
    product_id,
    product_name,
    category,
    ROUND(ventas, 2)   AS ventas,
    ventas_acumuladas,
    ROUND(ganancia, 2) AS ganancia
FROM ranked
WHERE posicion <= 5
ORDER BY posicion;

-- 5.3 Top 5 productos con menor rentabilidad (margen más bajo)
WITH producto AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name,
        MAX(category)     AS category,
        MAX(sub_category) AS sub_category,
        SUM(sales)        AS ventas,
        SUM(profit)       AS ganancia,
        ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
    FROM superstore
    GROUP BY product_id
),
ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY margen_pct ASC) AS posicion_menor_margen
    FROM producto
)
SELECT
    posicion_menor_margen AS posicion,
    product_id,
    product_name,
    category,
    sub_category,
    ROUND(ventas, 2)   AS ventas,
    ROUND(ganancia, 2) AS ganancia,
    margen_pct
FROM ranked
WHERE posicion_menor_margen <= 5
ORDER BY posicion_menor_margen;

-- 5.4 Posición de cada producto dentro de su categoría (top 10 por categoría)
WITH producto AS (
    SELECT
        product_id,
        MAX(product_name) AS product_name,
        MAX(category)     AS category,
        SUM(sales)        AS ventas,
        SUM(profit)       AS ganancia
    FROM superstore
    GROUP BY product_id
),
ranked AS (
    SELECT
        *,
        RANK()       OVER (PARTITION BY category ORDER BY ganancia DESC) AS rank_ganancia,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY ventas DESC)   AS dense_rank_ventas,
        ROUND(ganancia / ventas * 100, 2) AS margen_pct
    FROM producto
)
SELECT
    category,
    rank_ganancia,
    dense_rank_ventas,
    product_id,
    product_name,
    ROUND(ventas, 2)   AS ventas,
    ROUND(ganancia, 2) AS ganancia,
    margen_pct
FROM ranked
WHERE rank_ganancia <= 10
ORDER BY category, rank_ganancia;
