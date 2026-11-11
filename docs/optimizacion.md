# Análisis de optimización

## 1. Contexto del volumen

| Elemento | Valor |
|---|---:|
| Tamaño del CSV | 2.2 MB |
| Registros | 9,994 |
| Columnas | 21 |
| Particiones | 4 (2014–2017) |
| Productos | 1,862 |
| Clientes | 793 |

Es un dataset pequeño para un clúster Hadoop. Por eso la optimización se diseñó en dos niveles: **decisiones de modelo** que escalan a volúmenes mayores y **decisiones de ejecución** apropiadas para este tamaño.

## 2. Decisiones de modelo

### 2.1 Particionamiento por año

```sql
CREATE TABLE superstore (...) PARTITIONED BY (order_year INT) STORED AS ORC;
```

Las consultas que filtran o agrupan por año (`P3`, `P7`) leen únicamente las particiones necesarias. En un dataset de 4 años el ahorro es moderado; en un histórico de 10–20 años evita escanear la mayor parte de la tabla.

**Partition pruning** esperado:

```sql
SELECT ... FROM superstore WHERE order_year = 2017;
-- Hive lee solo .../order_year=2017/
```

### 2.2 Formato ORC + SNAPPY

- Almacenamiento **columnar**: las consultas que usan 5–8 columnas no leen las 21.
- **Compresión SNAPPY**: buen equilibrio entre compresión y velocidad de descompresión.
- Predicados y proyecciones se aplican a nivel de bloques/columnas.

### 2.3 Tipos de datos

| Dato | Tipo elegido | Razón |
|---|---|---|
| Dinero (`sales`, `profit`, `discount`) | `DECIMAL(12,4)` / `DECIMAL(6,4)` | Evita errores de coma flotante en agregaciones. |
| Fechas | `DATE` | Permite `DATEDIFF`, `YEAR`, `MONTH` sin conversiones repetidas. |
| `postal_code` | `VARCHAR(10)` | Conserva ceros iniciales. |
| Identificadores | `VARCHAR` / `INT` | `row_id` como INT permite ordenar y validar duplicados con bajo costo. |

### 2.4 Estadísticas para el optimizador (CBO)

```sql
ANALYZE TABLE superstore PARTITION (order_year) COMPUTE STATISTICS;
ANALYZE TABLE superstore COMPUTE STATISTICS FOR COLUMNS
  region, category, sub_category, segment;
```

Con estadísticas actualizadas, Hive puede estimar cardinalidades, elegir el orden de los `JOIN` y decidir el número de reductores.

### 2.5 Vista de calidad

`vw_superstore_valida` encapsula los filtros de integridad. Si en el futuro llega una recarga con filas inválidas, las consultas pueden apuntar a la vista sin duplicar reglas de limpieza en cada script.

## 3. Decisiones de ejecución

### 3.1 Modo local para datasets pequeños

Los scripts de consulta incluyen:

```sql
SET hive.exec.mode.local.auto = true;
SET mapreduce.framework.name = local;
SET hive.exec.mode.local.auto.inputbytes.max = 134217728;
SET hive.exec.mode.local.auto.input.files.max = 8;
```

Con 2.2 MB, lanzar un job distribuido en YARN implica más tiempo de coordinación (ApplicationMaster, contenedores, JVM) que de cómputo real. El modo local ejecuta el job dentro del mismo proceso de Hive y reduce el tiempo a segundos.

> **Escalabilidad:** para un volumen de cientos de MB o GB se deben comentar estas líneas y dejar que Hive use YARN. La lógica SQL no cambia.

### 3.2 CTE y funciones de ventana

Las preguntas 3, 4, 5, 7 y 8 usan CTE con `LAG`, `RANK`, `DENSE_RANK`, `NTILE` y `SUM() OVER`. Esto evita:

- autoconsultas repetidas sobre la misma tabla,
- `JOIN` de una tabla consigo misma para calcular el año anterior,
- subconsultas correlacionadas para acumulados.

El motor ordena y procesa cada ventana en una pasada, lo que es más eficiente que resolver el mismo cálculo con múltiples escaneos.

### 3.3 Proyección de columnas

Las consultas seleccionan solo las columnas necesarias. En ORC esto reduce la E/S porque cada columna se lee de forma independiente.

### 3.4 Reducción de resultados en evidencias

Consultas como el ranking completo de productos (1,862 filas) o el Pareto (1,862 filas) se limitaron en la evidencia a las primeras posiciones o al top 10 por categoría. El cálculo se hace sobre todos los productos; el límite es solo de presentación.

## 4. Comparación de enfoques

| Enfoque | Ventaja | Cuándo usarlo |
|---|---|---|
| `mapreduce.framework.name=local` | Arranque inmediato, sin YARN | Dataset pequeño (<128 MB). |
| YARN distribuido | Escala horizontal, tolerancia a fallos | Volúmenes medianos/grandes o múltiples usuarios. |
| Tabla TEXTFILE | Carga simple, sin conversión | Staging y auditoría del archivo original. |
| Tabla ORC particionada | Menos E/S, compresión, poda | Tabla analítica de consulta repetida. |
| Bucketing por `customer_id` | Mejores `JOIN` y muestreo | Si se hicieran joins frecuentes entre tablas grandes por cliente. |

## 5. Mejoras posibles a futuro

1. **Particionar también por `region`** si el negocio consulta siempre por región y el volumen crece.
2. **Bucketing por `customer_id` o `product_id`** para acelerar joins con dimensiones.
3. **Motor Tez** en lugar de MapReduce para consultas con múltiples etapas.
4. **Tabla incremental** con `INSERT INTO ... PARTITION` para cargas mensuales en lugar de recargar todo.
5. **Vista materializada o tabla resumen** para los indicadores mensuales y RFM si se consultan con alta frecuencia.
6. **Normalización del texto** de `product_name` en la etapa de staging para eliminar los 278 registros con caracteres corruptos.

## 6. Conclusión de optimización

El diseño combina lo mejor de ambos mundos: una capa de staging fiel al origen y una capa analítica columnar, tipada y particionada. Para el tamaño actual, el modo local elimina el overhead de YARN; para un crecimiento del volumen, el mismo modelo permite volver al modo distribuido sin reescribir las consultas. Las técnicas aplicadas (particionamiento, ORC, estadísticas, CTE y ventanas) son las mismas que se usan en entornos de Big Data de mayor escala.
