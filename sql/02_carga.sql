-- ============================================================
-- PREGUNTA 1. PROCEDIMIENTO DE CARGA (STAGING -> ANALÍTICA)
-- ============================================================
USE db_superstore_jhaelguevara;

SET hive.resultset.use.unique.column.names = false;

-- Ejecución local para datasets pequeños (2 MB)
SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;
SET hive.exec.mode.local.auto.inputbytes.max = 134217728;
SET hive.exec.mode.local.auto.input.files.max = 8;

SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;
SET hive.optimize.sort.dynamic.partition = true;

-- Conversión de fechas MM/dd/yyyy -> DATE y casteo de métricas.
-- La partición order_year se genera a partir de la fecha de pedido.
INSERT OVERWRITE TABLE superstore PARTITION (order_year)
SELECT
    CAST(TRIM(row_id)        AS INT),
    TRIM(order_id),
    TO_DATE(FROM_UNIXTIME(UNIX_TIMESTAMP(TRIM(order_date), 'MM/dd/yyyy'))),
    TO_DATE(FROM_UNIXTIME(UNIX_TIMESTAMP(TRIM(ship_date),  'MM/dd/yyyy'))),
    TRIM(ship_mode),
    TRIM(customer_id),
    TRIM(customer_name),
    TRIM(segment),
    TRIM(country),
    TRIM(city),
    TRIM(state),
    TRIM(postal_code),
    TRIM(region),
    TRIM(product_id),
    TRIM(category),
    TRIM(sub_category),
    TRIM(product_name),
    CAST(TRIM(sales)    AS DECIMAL(12,4)),
    CAST(TRIM(quantity) AS INT),
    CAST(TRIM(discount) AS DECIMAL(6,4)),
    CAST(TRIM(profit)   AS DECIMAL(12,4)),
    YEAR(TO_DATE(FROM_UNIXTIME(UNIX_TIMESTAMP(TRIM(order_date), 'MM/dd/yyyy'))))
FROM superstore_raw;

SET hive.cli.print.header = true;

-- Evidencia de registros importados
SELECT COUNT(*) AS total_registros FROM superstore;
SELECT order_year, COUNT(*) AS registros FROM superstore GROUP BY order_year ORDER BY order_year;
SELECT * FROM superstore LIMIT 5;
