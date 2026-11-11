-- ============================================================
-- PREGUNTA 2. AUDITORÍA DE CALIDAD E INTEGRIDAD DE DATOS
-- ============================================================
USE db_superstore_jhaelguevara;

SET hive.cli.print.header = true;
SET hive.resultset.use.unique.column.names = false;

-- Ejecución local para datasets pequeños (2 MB)
SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;
SET hive.exec.mode.local.auto.inputbytes.max = 134217728;
SET hive.exec.mode.local.auto.input.files.max = 8;

-- 2.1 Resumen general de calidad (una fila por indicador)
SELECT metrica, valor
FROM (
    SELECT 1 AS orden, 'Total de registros' AS metrica, CAST(COUNT(*) AS STRING) AS valor FROM superstore
    UNION ALL
    SELECT 2, 'Row ID duplicados',
           CAST(COUNT(*) AS STRING)
    FROM (SELECT row_id FROM superstore GROUP BY row_id HAVING COUNT(*) > 1) d
    UNION ALL
    SELECT 3, 'Ordenes unicas', CAST(COUNT(DISTINCT order_id) AS STRING) FROM superstore
    UNION ALL
    SELECT 4, 'Clientes unicos', CAST(COUNT(DISTINCT customer_id) AS STRING) FROM superstore
    UNION ALL
    SELECT 5, 'Productos unicos', CAST(COUNT(DISTINCT product_id) AS STRING) FROM superstore
    UNION ALL
    SELECT 6, 'Registros con fecha de pedido invalida/NULL',
           CAST(SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS STRING) FROM superstore
    UNION ALL
    SELECT 7, 'Registros con fecha de envio invalida/NULL',
           CAST(SUM(CASE WHEN ship_date IS NULL THEN 1 ELSE 0 END) AS STRING) FROM superstore
    UNION ALL
    SELECT 8, 'Registros con ventas <= 0',
           CAST(SUM(CASE WHEN sales <= 0 THEN 1 ELSE 0 END) AS STRING) FROM superstore
    UNION ALL
    SELECT 9, 'Registros con cantidad <= 0',
           CAST(SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END) AS STRING) FROM superstore
    UNION ALL
    SELECT 10, 'Registros con descuento fuera de [0,1]',
           CAST(SUM(CASE WHEN discount < 0 OR discount > 1 THEN 1 ELSE 0 END) AS STRING) FROM superstore
    UNION ALL
    SELECT 11, 'Registros con envio anterior al pedido',
           CAST(SUM(CASE WHEN ship_date < order_date THEN 1 ELSE 0 END) AS STRING) FROM superstore
    UNION ALL
    SELECT 12, 'Registros con ganancia negativa (perdida)',
           CAST(SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS STRING) FROM superstore
    UNION ALL
    SELECT 13, 'Registros con caracteres corruptos en product_name',
           CAST(SUM(CASE WHEN HEX(product_name) LIKE '%C3AFC2BF%' THEN 1 ELSE 0 END) AS STRING) FROM superstore
) t
ORDER BY orden;

-- 2.2 Conteo de NULL por campo
SELECT
    SUM(CASE WHEN row_id        IS NULL THEN 1 ELSE 0 END) AS null_row_id,
    SUM(CASE WHEN order_id      IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN order_date    IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN ship_date     IS NULL THEN 1 ELSE 0 END) AS null_ship_date,
    SUM(CASE WHEN ship_mode     IS NULL THEN 1 ELSE 0 END) AS null_ship_mode,
    SUM(CASE WHEN customer_id   IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN customer_name IS NULL THEN 1 ELSE 0 END) AS null_customer_name,
    SUM(CASE WHEN segment       IS NULL THEN 1 ELSE 0 END) AS null_segment,
    SUM(CASE WHEN country       IS NULL THEN 1 ELSE 0 END) AS null_country,
    SUM(CASE WHEN city          IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN state         IS NULL THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN postal_code   IS NULL THEN 1 ELSE 0 END) AS null_postal_code,
    SUM(CASE WHEN region        IS NULL THEN 1 ELSE 0 END) AS null_region,
    SUM(CASE WHEN product_id    IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN category      IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN sub_category  IS NULL THEN 1 ELSE 0 END) AS null_sub_category,
    SUM(CASE WHEN product_name  IS NULL THEN 1 ELSE 0 END) AS null_product_name,
    SUM(CASE WHEN sales         IS NULL THEN 1 ELSE 0 END) AS null_sales,
    SUM(CASE WHEN quantity      IS NULL THEN 1 ELSE 0 END) AS null_quantity,
    SUM(CASE WHEN discount      IS NULL THEN 1 ELSE 0 END) AS null_discount,
    SUM(CASE WHEN profit        IS NULL THEN 1 ELSE 0 END) AS null_profit
FROM superstore;

-- 2.3 Rangos de las métricas numéricas y fechas
SELECT
    MIN(order_date) AS fecha_min_pedido,
    MAX(order_date) AS fecha_max_pedido,
    MIN(ship_date)  AS fecha_min_envio,
    MAX(ship_date)  AS fecha_max_envio,
    MIN(sales)      AS venta_min,
    MAX(sales)      AS venta_max,
    MIN(profit)     AS ganancia_min,
    MAX(profit)     AS ganancia_max,
    MIN(discount)   AS descuento_min,
    MAX(discount)   AS descuento_max,
    MIN(quantity)   AS cantidad_min,
    MAX(quantity)   AS cantidad_max
FROM superstore;

-- 2.4 Comparación staging vs tabla analítica (descartes de la carga)
SELECT
    (SELECT COUNT(*) FROM superstore_raw) AS registros_staging,
    (SELECT COUNT(*) FROM superstore)     AS registros_analitica,
    (SELECT COUNT(*) FROM superstore_raw) - (SELECT COUNT(*) FROM superstore) AS diferencia;
