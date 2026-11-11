-- ============================================================
-- EXAMEN PRÁCTICO - SUPERSTORE SALES DATASET
-- Apache Hive 3.1.3
-- Autor: Jhael Guevara
-- Descripción: creación de la base de datos y parámetros de sesión
-- ============================================================

CREATE DATABASE IF NOT EXISTS db_superstore_jhaelguevara
COMMENT 'Base de datos del examen práctico - Sample Superstore'
LOCATION '/user/hive/warehouse/db_superstore_jhaelguevara.db';

USE db_superstore_jhaelguevara;

-- Optimizaciones de sesión para la carga particionada
SET hive.exec.dynamic.partition = true;
SET hive.exec.dynamic.partition.mode = nonstrict;
SET hive.exec.max.dynamic.partitions = 1000;
SET hive.exec.max.dynamic.partitions.pernode = 1000;
SET hive.optimize.sort.dynamic.partition = true;

-- Compresión y ejecución paralela en consultas analíticas
SET hive.exec.parallel = true;
SET hive.exec.compress.intermediate = true;
SET mapreduce.job.reduces = 2;
