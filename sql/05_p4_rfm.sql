-- ============================================================
-- PREGUNTA 4. SEGMENTACIÓN DE CLIENTES MEDIANTE RFM
-- Recency / Frequency / Monetary + puntuaciones NTILE(5)
-- ============================================================
USE db_superstore_jhaelguevara;

SET hive.cli.print.header = true;
SET hive.resultset.use.unique.column.names = false;

-- Ejecución local para datasets pequeños (2 MB)
SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;
SET hive.exec.mode.local.auto.inputbytes.max = 134217728;
SET hive.exec.mode.local.auto.input.files.max = 8;

-- 4.1 Cálculo base RFM por cliente
WITH referencia AS (
    SELECT MAX(order_date) AS fecha_max
    FROM superstore
),
cliente AS (
    SELECT
        s.customer_id,
        MAX(s.customer_name) AS customer_name,
        MAX(s.segment)       AS segment,
        DATEDIFF(r.fecha_max, MAX(s.order_date)) AS recency_dias,
        COUNT(DISTINCT s.order_id)                AS frequency_ordenes,
        SUM(s.sales)                              AS monetary_ventas,
        SUM(s.profit)                             AS ganancia_total
    FROM superstore s
    CROSS JOIN referencia r
    GROUP BY s.customer_id, r.fecha_max
),
puntuado AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_dias DESC)       AS r_score,
        NTILE(5) OVER (ORDER BY frequency_ordenes ASC)   AS f_score,
        NTILE(5) OVER (ORDER BY monetary_ventas ASC)     AS m_score
    FROM cliente
),
rfm AS (
    SELECT
        *,
        CONCAT(r_score, f_score, m_score) AS rfm_codigo,
        r_score + f_score + m_score       AS rfm_total,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Alto valor'
            WHEN r_score <= 2 AND m_score >= 4                  THEN 'En riesgo de abandono'
            WHEN f_score >= 4 AND m_score >= 3                  THEN 'Recurrente'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'Nuevo / prometedor'
            ELSE 'Ocasional'
        END AS segmento_rfm
    FROM puntuado
)
SELECT
    customer_id,
    customer_name,
    segment,
    recency_dias,
    frequency_ordenes,
    ROUND(monetary_ventas, 2) AS monetary_ventas,
    ROUND(ganancia_total, 2)  AS ganancia_total,
    r_score, f_score, m_score,
    rfm_codigo,
    rfm_total,
    segmento_rfm
FROM rfm
ORDER BY monetary_ventas DESC
LIMIT 25;

-- 4.2 Resumen por segmento RFM
WITH referencia AS (
    SELECT MAX(order_date) AS fecha_max FROM superstore
),
cliente AS (
    SELECT
        s.customer_id,
        DATEDIFF(r.fecha_max, MAX(s.order_date)) AS recency_dias,
        COUNT(DISTINCT s.order_id)                AS frequency_ordenes,
        SUM(s.sales)                              AS monetary_ventas
    FROM superstore s
    CROSS JOIN referencia r
    GROUP BY s.customer_id, r.fecha_max
),
puntuado AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_dias DESC)     AS r_score,
        NTILE(5) OVER (ORDER BY frequency_ordenes ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_ventas ASC)   AS m_score
    FROM cliente
),
rfm AS (
    SELECT
        *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Alto valor'
            WHEN r_score <= 2 AND m_score >= 4                  THEN 'En riesgo de abandono'
            WHEN f_score >= 4 AND m_score >= 3                  THEN 'Recurrente'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'Nuevo / prometedor'
            ELSE 'Ocasional'
        END AS segmento_rfm
    FROM puntuado
)
SELECT
    segmento_rfm,
    COUNT(*)                                    AS clientes,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct_clientes,
    ROUND(AVG(recency_dias), 1)                 AS recency_prom_dias,
    ROUND(AVG(frequency_ordenes), 1)            AS frequency_prom,
    ROUND(AVG(monetary_ventas), 2)              AS monetary_prom,
    ROUND(SUM(monetary_ventas), 2)              AS ventas_totales,
    ROUND(SUM(monetary_ventas) / SUM(SUM(monetary_ventas)) OVER () * 100, 2) AS pct_ventas
FROM rfm
GROUP BY segmento_rfm
ORDER BY ventas_totales DESC;

-- 4.3 Distribución de puntuaciones RFM
WITH referencia AS (
    SELECT MAX(order_date) AS fecha_max FROM superstore
),
cliente AS (
    SELECT
        s.customer_id,
        DATEDIFF(r.fecha_max, MAX(s.order_date)) AS recency_dias,
        COUNT(DISTINCT s.order_id)                AS frequency_ordenes,
        SUM(s.sales)                              AS monetary_ventas
    FROM superstore s
    CROSS JOIN referencia r
    GROUP BY s.customer_id, r.fecha_max
),
puntuado AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_dias DESC)     AS r_score,
        NTILE(5) OVER (ORDER BY frequency_ordenes ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_ventas ASC)   AS m_score
    FROM cliente
)
SELECT
    r_score,
    f_score,
    COUNT(*) AS clientes,
    ROUND(SUM(monetary_ventas), 2) AS ventas
FROM puntuado
GROUP BY r_score, f_score
ORDER BY r_score DESC, f_score DESC;
