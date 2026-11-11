# tem1_2mom_guevara-jhael — Examen práctico Apache Hive

Proyecto individual de procesamiento y análisis del dataset **Sample Superstore** con Apache Hive: modelado, ingesta, auditoría de calidad, consultas analíticas avanzadas, optimización e interpretación de resultados.

- **Autor:** Jhael Guevara
- **Asignatura:** Emergentes 1 — 2do momento
- **Motor:** Apache Hive 3.1.3 sobre Hadoop 3.3.5 (clúster Docker)
- **Dataset:** [Sample Superstore (Kaggle)](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)
- **Registros:** 9,994 | **Años:** 2014–2017 | **Órdenes:** 5,009 | **Clientes:** 793 | **Productos:** 1,862

> Repositorio: `tem1_2mom_GuevaraSilva_JhaelElisa`. Contiene únicamente los entregables de este examen práctico.

---

## 1. Objetivos

1. Diseñar e implementar un modelo de almacenamiento en Hive con tipos de datos apropiados.
2. Cargar el dataset desde HDFS y validar la integridad de los datos.
3. Resolver consultas analíticas avanzadas con CTE, funciones de ventana, `RANK`, `DENSE_RANK`, `LAG`, `NTILE` y agregaciones acumulativas.
4. Documentar cada resultado con su interpretación técnica y conclusión de negocio.
5. Aplicar y justificar decisiones de optimización (particionamiento, ORC, estadísticas, modo local).

## 2. Estructura del repositorio

```
.
├── README.md
├── datos/
│   └── Sample - Superstore.csv          # copia canónica con encabezado
├── docs/
│   ├── diccionario_datos.md             # diccionario completo (21 campos)
│   ├── resultados.md                    # informe pregunta por pregunta
│   └── optimizacion.md                  # decisiones y análisis de optimización
├── evidencias/
│   ├── 02_carga.txt
│   ├── 03_p2_calidad.txt
│   ├── 04_p3_region.txt
│   ├── 05_p4_rfm.txt
│   ├── 06_p5_productos.txt
│   ├── 07_p6_descuentos.txt
│   ├── 08_p7_tendencias.txt
│   └── 09_p8_pareto.txt
├── scripts/
│   ├── run_queries.sh                   # ejecuta todos los scripts en el contenedor
│   └── ejecutar_todo.ps1                # automatización desde Windows
└── sql/
    ├── 00_setup.sql                     # base de datos y parámetros
    ├── 01_ddl.sql                       # staging + tabla analítica + vista
    ├── 02_carga.sql                     # carga con partición dinámica
    ├── 02b_estadisticas.sql             # estadísticas CBO después de la carga
    ├── 03_p2_calidad.sql                # Pregunta 2
    ├── 04_p3_region.sql                 # Pregunta 3
    ├── 05_p4_rfm.sql                    # Pregunta 4
    ├── 06_p5_productos.sql              # Pregunta 5
    ├── 07_p6_descuentos.sql             # Pregunta 6
    ├── 08_p7_tendencias.sql             # Pregunta 7
    └── 09_p8_pareto.sql                 # Pregunta 8
```

## 3. Requisitos

- Docker Desktop con el clúster levantado (`docker compose up -d`).
- Contenedores `hive-server`, `hive-metastore` y servicios HDFS/YARN en ejecución.
- Cliente `hdfs` y Hive dentro del contenedor `hive-server` (ya incluidos en la imagen del curso).
- ~2.2 MB libres para el dataset.

Verificar el entorno:

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}"
docker exec hive-server beeline -u "jdbc:hive2://localhost:10000/default" -e "SHOW DATABASES;"
```

## 4. Procedimiento de ejecución

### 4.1 Subir el CSV a HDFS

```powershell
docker cp "datos\Sample - Superstore.csv" hive-server:/tmp/superstore.csv
docker exec hive-server bash -lc "hdfs dfs -mkdir -p /user/root/superstore/raw && hdfs dfs -put -f /tmp/superstore.csv /user/root/superstore/raw/"
```

### 4.2 Crear base de datos y tablas

```powershell
docker cp "sql\." hive-server:/tmp/sql/
docker exec hive-server bash -lc "beeline -u 'jdbc:hive2://localhost:10000/default' -f /tmp/sql/00_setup.sql"
docker exec hive-server bash -lc "beeline -u 'jdbc:hive2://localhost:10000/default' -f /tmp/sql/01_ddl.sql"
```

### 4.3 Cargar la tabla analítica

```powershell
docker exec hive-server bash -lc "beeline -u 'jdbc:hive2://localhost:10000/default' -f /tmp/sql/02_carga.sql"
```

Resultado esperado: 9,994 registros distribuidos en 4 particiones (2014–2017).

### 4.4 Ejecutar las consultas y generar evidencias

Opción automática (Linux/bash dentro del contenedor):

```powershell
docker cp "scripts\run_queries.sh" hive-server:/tmp/run_queries.sh
docker exec -e HADOOP_CLIENT_OPTS="-Xmx2048m" hive-server bash /tmp/run_queries.sh
docker cp hive-server:/tmp/evidencias/. "evidencias\"
```

Opción manual (una consulta a la vez):

```powershell
docker exec hive-server bash -lc "beeline -u 'jdbc:hive2://localhost:10000/default' -f /tmp/sql/04_p3_region.sql"
```

> **Nota técnica:** los scripts incluyen `SET mapreduce.framework.name = local` y `SET hive.exec.mode.local.auto = true` porque el dataset pesa ~2 MB. Con ese tamaño, la ejecución local evita el overhead de YARN y produce resultados en segundos. Para volúmenes mayores basta con comentar esas dos líneas para volver al modo distribuido.

## 5. Resumen de resultados

| Pregunta | Hallazgo principal |
|---|---|
| P1. Modelo | Tabla ORC particionada por año; 9,994 registros cargados sin pérdidas. |
| P2. Calidad | 0 duplicados, 0 nulos, 0 fechas inválidas; 1,871 pérdidas válidas y 278 nombres con codificación corrupta del origen. |
| P3. Regiones | West lidera ventas, ganancia y margen (14.94%); Central tiene el peor margen (7.92%). |
| P4. RFM | 105 clientes de alto valor (24.08% de ventas) y 97 en riesgo (22.29% de ventas). |
| P5. Productos | Canon imageCLASS 2200 lidera ventas y ganancia; varios productos de alto volumen tienen margen nulo o negativo. |
| P6. Descuentos | >50% de descuento implica 100% de operaciones con pérdida; margen global -119.20%. |
| P7. Tendencias | Ventas crecen 51.4% (2014→2017), con picos en noviembre/diciembre y valles en enero/febrero. |
| P8. Pareto | 414 productos (22.23%) generan el 80% de ventas; solo 164 (8.81%) generan el 80% de la ganancia. |

Detalle completo, interpretación y conclusión por pregunta en [`docs/resultados.md`](docs/resultados.md).

## 6. Optimización aplicada

| Técnica | Implementación | Beneficio |
|---|---|---|
| Particionamiento | `PARTITIONED BY (order_year)` | Poda de particiones en consultas por año. |
| Formato columnar | `STORED AS ORC` + SNAPPY | Menor lectura de columnas y mejor compresión. |
| Tipos eficientes | `DECIMAL` para dinero, `DATE` para fechas | Precisión y comparaciones nativas. |
| Estadísticas CBO | `ANALYZE TABLE ... COMPUTE STATISTICS` | Mejores planes de ejecución. |
| Modo local | `hive.exec.mode.local.auto` | Evita overhead de YARN con datasets pequeños. |
| CTE y ventanas | `LAG`, `RANK`, `SUM() OVER` | Una sola pasada por los datos en lugar de autoconsultas. |
| Evitar `SELECT *` en producción | Columnas explícitas en las consultas | Menos E/S en formato columnar. |

Análisis ampliado en [`docs/optimizacion.md`](docs/optimizacion.md).

## 7. Evidencias

Cada archivo de `evidencias/` corresponde a la salida real de Hive para la pregunta indicada. Fueron generados con:

```bash
hive -S -f <script>.sql > evidencias/<script>.txt 2> evidencias/<script>.err
```

Los archivos incluyen encabezados de columna y los resultados completos (con límites de presentación en listados extensos, por ejemplo el top 30 del Pareto).

## 8. Conclusiones generales

- El dataset es adecuado para análisis analítico: su calidad estructural es alta y no requiere descartes.
- La rentabilidad está más concentrada que las ventas: menos del 9% del catálogo sostiene el 80% de la ganancia.
- La política de descuentos es el principal riesgo: por encima del 20% el margen se vuelve negativo.
- West y East deben ser la referencia comercial; Central requiere revisión de precios, descuentos y mezcla de productos.
- La retención de clientes de alto valor y la reactivación de clientes en riesgo protegen cerca de la mitad de la facturación.
- El crecimiento anual es positivo, pero el margen de 2017 exige seguimiento.

## 9. Autoría y uso de herramientas

Trabajo individual de Jhael Guevara. Las consultas, el modelado, la ejecución y la interpretación fueron revisados y validados sobre el clúster propio. Se deja constancia del uso de asistentes de IA como apoyo en la redacción y estructuración de la documentación, conforme a la política académica del docente; el estudiante asume la responsabilidad del contenido y debe poder explicar cada consulta.
