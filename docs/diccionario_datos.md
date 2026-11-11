# Diccionario de datos — Sample Superstore

Base de datos: `db_superstore_jhaelguevara`
Tabla analítica: `superstore` (ORC, particionada por `order_year`)
Tabla de staging: `superstore_raw` (TEXTFILE, OpenCSVSerde)

| # | Campo original | Campo Hive | Tipo Hive | Descripción | Restricciones / observaciones |
|---|---|---|---|---|---|
| 1 | Row ID | `row_id` | `INT` | Identificador único de la fila del archivo original. | Clave primaria lógica. Único y no nulo (9,994 valores distintos). |
| 2 | Order ID | `order_id` | `VARCHAR(30)` | Identificador de la orden. Varias filas pueden pertenecer a la misma orden. | No nulo. 5,009 órdenes únicas. Formato `XX-YYYY-NNNNNN`. |
| 3 | Order Date | `order_date` | `DATE` | Fecha en que se realizó el pedido. | No nula. Debe ser ≤ `ship_date`. Formato origen `M/d/yyyy`. |
| 4 | Ship Date | `ship_date` | `DATE` | Fecha de envío del pedido. | No nula. Debe ser ≥ `order_date`. |
| 5 | Ship Mode | `ship_mode` | `VARCHAR(30)` | Modalidad de envío. | Valores: Standard Class, Second Class, First Class, Same Day. |
| 6 | Customer ID | `customer_id` | `VARCHAR(20)` | Identificador único del cliente. | No nulo. 793 clientes únicos. Formato `XX-NNNNN`. |
| 7 | Customer Name | `customer_name` | `VARCHAR(80)` | Nombre del cliente. | Descriptivo; un mismo ID debe tener un solo nombre. |
| 8 | Segment | `segment` | `VARCHAR(30)` | Segmento comercial del cliente. | Valores: Consumer, Corporate, Home Office. |
| 9 | Country | `country` | `VARCHAR(40)` | País del pedido. | En el dataset siempre `United States`. |
| 10 | City | `city` | `VARCHAR(60)` | Ciudad de entrega. | Descriptivo. |
| 11 | State | `state` | `VARCHAR(60)` | Estado de entrega. | Descriptivo. |
| 12 | Postal Code | `postal_code` | `VARCHAR(10)` | Código postal. | Se modela como texto para conservar ceros iniciales. |
| 13 | Region | `region` | `VARCHAR(20)` | Región comercial. | Valores: Central, East, South, West. |
| 14 | Product ID | `product_id` | `VARCHAR(30)` | Identificador único del producto. | No nulo. 1,862 productos únicos. |
| 15 | Category | `category` | `VARCHAR(40)` | Categoría del producto. | Valores: Furniture, Office Supplies, Technology. |
| 16 | Sub-Category | `sub_category` | `VARCHAR(40)` | Subcategoría del producto. | 17 valores distintos. |
| 17 | Product Name | `product_name` | `VARCHAR(300)` | Nombre descriptivo del producto. | 278 registros contienen caracteres corruptos (`ï¿½`) provenientes del archivo fuente; no afecta el análisis porque `product_id` es la clave. |
| 18 | Sales | `sales` | `DECIMAL(12,4)` | Importe de venta de la línea. | > 0. Rango observado: 0.4440 – 22,638.4800. |
| 19 | Quantity | `quantity` | `INT` | Unidades vendidas. | > 0. Rango observado: 1 – 14. |
| 20 | Discount | `discount` | `DECIMAL(6,4)` | Descuento aplicado, expresado como fracción (0.20 = 20%). | Intervalo esperado [0, 1]. Rango observado: 0.0000 – 0.8000. |
| 21 | Profit | `profit` | `DECIMAL(12,4)` | Ganancia o pérdida de la línea. | Puede ser negativo. Rango observado: -6,599.9780 – 8,399.9760. |
| 22 | — | `order_year` | `INT` | Año del pedido. Columna de partición. | Derivada de `order_date`. Valores: 2014, 2015, 2016, 2017. |

## Decisiones de modelado

- **`row_id` como INT**: permite validar duplicados y ordenar el archivo sin ambigüedad.
- **Fechas como `DATE`**: habilita `DATEDIFF`, `YEAR`, `MONTH` y comparaciones directas, en lugar de tratar las fechas como texto.
- **Métricas monetarias como `DECIMAL`**: evita errores de redondeo de `FLOAT`/`DOUBLE` en sumas de ventas y ganancias.
- **`postal_code` como texto**: algunos códigos postales pueden iniciar con cero; convertirlos a INT perdería información.
- **Partición `order_year`**: las consultas de evolución anual y comparativas por año leen solo las particiones necesarias (partition pruning).
- **Formato ORC con compresión SNAPPY**: almacenamiento columnar, lectura selectiva de columnas y buena compresión para un dataset pequeño.
- **Tabla de staging separada**: conserva el dato crudo como texto para auditoría y permite reprocesar sin volver a subir el archivo.
