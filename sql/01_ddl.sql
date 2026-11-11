-- ============================================================
-- PREGUNTA 1. DISEÑO E IMPLEMENTACIÓN DEL MODELO DE DATOS
-- ============================================================
USE db_superstore_jhaelguevara;

-- ------------------------------------------------------------
-- 1) TABLA DE STAGING (datos crudos, todos los campos STRING)
--    Permite auditar el archivo original sin perder información
--    y detectar valores inválidos antes de tipar.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS superstore_raw;

CREATE EXTERNAL TABLE superstore_raw (
    row_id        STRING,
    order_id      STRING,
    order_date    STRING,
    ship_date     STRING,
    ship_mode     STRING,
    customer_id   STRING,
    customer_name STRING,
    segment       STRING,
    country       STRING,
    city          STRING,
    state         STRING,
    postal_code   STRING,
    region        STRING,
    product_id    STRING,
    category      STRING,
    sub_category  STRING,
    product_name  STRING,
    sales         STRING,
    quantity      STRING,
    discount      STRING,
    profit        STRING
)
COMMENT 'Staging: copia fiel del CSV original (Sample Superstore)'
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar"     = "\"",
    "escapeChar"    = "\\"
)
STORED AS TEXTFILE
LOCATION '/user/root/superstore/raw'
TBLPROPERTIES ("skip.header.line.count" = "1");

-- ------------------------------------------------------------
-- 2) TABLA ANALÍTICA (tipada, ORC y particionada por año)
--    - DATE para fechas
--    - DECIMAL para dinero (evita errores de punto flotante)
--    - INT para cantidades y año
--    - VARCHAR para atributos descriptivos
--    - Partición order_year: poda de particiones en consultas
--      por año y mejor compresión/lectura con ORC.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS superstore;

CREATE TABLE superstore (
    row_id        INT,
    order_id      VARCHAR(30),
    order_date    DATE,
    ship_date     DATE,
    ship_mode     VARCHAR(30),
    customer_id   VARCHAR(20),
    customer_name VARCHAR(80),
    segment       VARCHAR(30),
    country       VARCHAR(40),
    city          VARCHAR(60),
    state         VARCHAR(60),
    postal_code   VARCHAR(10),
    region        VARCHAR(20),
    product_id    VARCHAR(30),
    category      VARCHAR(40),
    sub_category  VARCHAR(40),
    product_name  VARCHAR(300),
    sales         DECIMAL(12,4),
    quantity      INT,
    discount      DECIMAL(6,4),
    profit        DECIMAL(12,4)
)
COMMENT 'Tabla analítica del dataset Superstore'
PARTITIONED BY (order_year INT)
STORED AS ORC
TBLPROPERTIES ("orc.compress" = "SNAPPY");

-- ------------------------------------------------------------
-- 3) VISTA DE DATOS VÁLIDOS (criterios de tratamiento P2)
--    Se conservan todos los registros del dataset porque la
--    auditoría no encontró nulos, duplicados ni rangos inválidos;
--    la vista deja explícito el filtro de calidad para futuras
--    recargas.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS vw_superstore_valida;

CREATE VIEW vw_superstore_valida AS
SELECT *
FROM superstore
WHERE row_id IS NOT NULL
  AND order_id IS NOT NULL
  AND customer_id IS NOT NULL
  AND product_id IS NOT NULL
  AND order_date IS NOT NULL
  AND ship_date IS NOT NULL
  AND order_date <= ship_date
  AND sales > 0
  AND quantity > 0
  AND discount BETWEEN 0 AND 1;
