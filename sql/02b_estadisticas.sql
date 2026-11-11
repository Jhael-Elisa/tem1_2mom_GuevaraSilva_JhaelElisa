-- ============================================================
-- ESTADÍSTICAS DEL OPTIMIZADOR (CBO) - ejecutar después de la carga
-- ============================================================
USE db_superstore_jhaelguevara;

SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;

ANALYZE TABLE superstore PARTITION (order_year) COMPUTE STATISTICS;
ANALYZE TABLE superstore COMPUTE STATISTICS FOR COLUMNS
    region, category, sub_category, segment;
