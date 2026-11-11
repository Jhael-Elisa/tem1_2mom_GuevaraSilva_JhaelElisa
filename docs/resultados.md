# Informe de resultados — Examen práctico Superstore

**Autor:** Jhael Guevara
**Motor:** Apache Hive 3.1.3 sobre Hadoop 3.3.5 (clúster Docker)
**Base de datos:** `db_superstore_jhaelguevara`
**Dataset:** Sample Superstore — 9,994 registros, 21 columnas, años 2014–2017

> Las salidas completas de cada consulta se encuentran en `evidencias/`. En este documento se resume el resultado y se interpreta.

---

## Pregunta 1. Diseño e implementación del modelo de datos

### Estrategia
Se separaron dos capas:

1. **Staging (`superstore_raw`)**: tabla externa sobre HDFS con todos los campos como `STRING` y `OpenCSVSerde` para respetar las comas dentro de nombres de producto entre comillas. Conserva el archivo original y permite auditar sin pérdida de información.
2. **Analítica (`superstore`)**: tabla ORC particionada por `order_year`. Aplica tipos definitivos (`DATE`, `DECIMAL`, `INT`) y sirve para todas las consultas del examen.

La carga se hace con `INSERT OVERWRITE ... PARTITION (order_year)` y particionamiento dinámico, convirtiendo las fechas `M/d/yyyy` a `DATE` y generando el año a partir de `order_date`.

### Evidencia
`evidencias/02_carga.txt`

| Partición | Registros |
|---|---:|
| 2014 | 1,993 |
| 2015 | 2,102 |
| 2016 | 2,587 |
| 2017 | 3,312 |
| **Total** | **9,994** |

`superstore_raw` y `superstore` tienen 9,994 registros: no se descartó ninguna fila en la carga.

### Conclusión
El modelo reproduce íntegramente el archivo original, aplica tipos adecuados para análisis y deja una tabla optimizada (columnar + particionada) para las consultas. El diccionario completo está en `docs/diccionario_datos.md`.

---

## Pregunta 2. Auditoría de calidad e integridad

### Estrategia
Se construyó una consulta con `UNION ALL` que devuelve una fila por indicador, más consultas complementarias de nulos, rangos y comparación staging vs. analítica.

### Evidencia
`evidencias/03_p2_calidad.txt`

| Indicador | Valor |
|---|---:|
| Total de registros | 9,994 |
| Row ID duplicados | 0 |
| Órdenes únicas | 5,009 |
| Clientes únicos | 793 |
| Productos únicos | 1,862 |
| Registros con fecha de pedido inválida/NULL | 0 |
| Registros con fecha de envío inválida/NULL | 0 |
| Registros con ventas ≤ 0 | 0 |
| Registros con cantidad ≤ 0 | 0 |
| Registros con descuento fuera de [0,1] | 0 |
| Registros con envío anterior al pedido | 0 |
| Registros con ganancia negativa | 1,871 |
| Registros con caracteres corruptos en `product_name` | 278 |
| Nulos en cualquier campo | 0 |

Rangos observados: fechas de pedido 2014-01-03 a 2017-12-30; ventas 0.4440 a 22,638.4800; ganancia -6,599.9780 a 8,399.9760; descuento 0 a 0.8; cantidad 1 a 14.

### Interpretación y tratamiento propuesto
- **Duplicados, nulos y rangos**: el dataset es consistente. No se requiere eliminar filas.
- **Ganancia negativa (1,871 filas)**: no es un error de calidad; es un resultado comercial válido asociado a descuentos altos (se analiza en la Pregunta 6). Se conserva.
- **Caracteres corruptos en `product_name` (278 filas)**: provienen del archivo fuente (`ï¿½` en lugar de símbolos como ®). Como `product_id` es la clave estable, no afecta agregaciones; se recomienda normalizar el texto en una etapa de limpieza si se usa el nombre para presentación.
- **Criterio de tratamiento**: se conservan todos los registros y se crea la vista `vw_superstore_valida` con los filtros de integridad explícitos, de modo que una futura recarga pueda validarse con la misma regla.

### Conclusión
La calidad estructural del dataset es alta: 0 duplicados, 0 nulos y 0 inconsistencias de fechas o rangos. La única incidencia relevante es de codificación de texto, sin impacto en los indicadores numéricos.

---

## Pregunta 3. Evolución comercial por región

### Estrategia
CTE `regional_year` para agregar ventas y ganancia por región/año; funciones de ventana `LAG` para la variación año a año y `RANK` para identificar la mejor y la peor región. Se calcula el margen como `ganancia / ventas * 100`.

### Evidencia
`evidencias/04_p3_region.txt`

| Región | Ventas totales | Ganancia total | Margen | Rank ventas | Rank ganancia | Rank margen |
|---|---:|---:|---:|---:|---:|---:|
| West | 725,457.82 | 108,418.45 | 14.94% | 1 | 1 | 1 |
| East | 678,781.24 | 91,522.78 | 13.48% | 2 | 2 | 2 |
| South | 391,721.91 | 46,749.43 | 11.93% | 4 | 3 | 3 |
| Central | 501,239.89 | 39,706.36 | 7.92% | 3 | 4 | 4 |

Hitos anuales:
- West creció de 147,883.03 (2014) a 250,128.37 (2017), con +33.42% en 2017 y el mejor margen del último año (17.51%).
- South cayó -31.28% en ventas en 2015 (71,359.98) y se recuperó +31.18% y +31.30% en 2016 y 2017, pero su margen cayó a 7.20% en 2017.
- Central tuvo el peor margen global (7.92%) y una caída de ganancia de -62.05% en 2017.

### Interpretación
West es la región con mejor desempeño comercial: lidera ventas, ganancia y margen. Central es la de peor desempeño relativo: vende más que South pero convierte mucho menos en ganancia (margen 7.92% frente a 11.93% de South). La concentración es alta: West y East representan 61.13% de las ventas y 69.82% de la ganancia.

### Conclusión
El desempeño no depende solo del volumen: Central vende un 28% más que South, pero genera menos ganancia. La prioridad de negocio está en revisar precios, descuentos y mezcla de productos en Central, y en replicar las prácticas comerciales de West y East.

---

## Pregunta 4. Segmentación de clientes mediante RFM

### Estrategia
- **Recency**: `DATEDIFF(fecha_max_dataset, última_compra)`; la fecha de referencia es 2017-12-30.
- **Frequency**: `COUNT(DISTINCT order_id)` por cliente.
- **Monetary**: `SUM(sales)` por cliente.

Cada dimensión se puntuó con `NTILE(5)` (1 = peor, 5 = mejor). Segmentación aplicada:

| Segmento | Regla |
|---|---|
| Alto valor | R ≥ 4 y F ≥ 4 y M ≥ 4 |
| En riesgo de abandono | R ≤ 2 y M ≥ 4 |
| Recurrente | F ≥ 4 y M ≥ 3 |
| Nuevo / prometedor | R ≥ 4 y F ≤ 2 |
| Ocasional | Resto |

### Evidencia
`evidencias/05_p4_rfm.txt`

| Segmento | Clientes | % clientes | Recency prom. (días) | Frequency prom. | Monetary prom. | Ventas totales | % ventas |
|---|---:|---:|---:|---:|---:|---:|---:|
| Ocasional | 402 | 50.69% | 199.9 | 5.2 | 1,856.32 | 746,240.77 | 32.48% |
| Alto valor | 105 | 13.24% | 24.8 | 9.3 | 5,269.17 | 553,262.35 | 24.08% |
| En riesgo de abandono | 97 | 12.23% | 253.3 | 7.2 | 5,279.86 | 512,145.98 | 22.29% |
| Recurrente | 102 | 12.86% | 65.7 | 8.7 | 3,215.52 | 327,983.48 | 14.28% |
| Nuevo / prometedor | 87 | 10.97% | 25.1 | 4.1 | 1,811.13 | 157,568.28 | 6.86% |

El cliente de mayor valor monetario es Sean Miller (25,043.05 en ventas), aunque con ganancia acumulada negativa (-1,980.74), lo que indica que no todo cliente de alto volumen es rentable.

### Interpretación
El grupo **Alto valor** (13.24% de clientes) aporta 24.08% de las ventas y compra recientemente (24.8 días en promedio). El grupo **En riesgo** (12.23%) aporta 22.29% de las ventas, pero su última compra promedio fue hace 253 días: es el segmento con mayor urgencia de retención. Juntos, alto valor y en riesgo concentran 46.37% de las ventas.

### Conclusión
La segmentación permite priorizar acciones: programa de fidelización para alto valor, campañas de reactivación para el 12.23% en riesgo y estrategias de frecuencia para el 50.69% ocasional. El análisis RFM demuestra que retener clientes de alto valor y recuperar los que están en riesgo protege casi la mitad de la facturación.

---

## Pregunta 5. Ranking de productos según rentabilidad

### Estrategia
Se agregó por `product_id` y se aplicaron `RANK()`, `DENSE_RANK()` y `SUM() OVER` para la ganancia acumulada por categoría y las ventas acumuladas. Se calcularon margen individual y posición dentro de cada categoría.

### Evidencia
`evidencias/06_p5_productos.txt`

**Top 5 por ganancia en cada categoría**

| Categoría | Producto | Ganancia | Margen |
|---|---|---:|---:|
| Furniture | Hon Deluxe Fabric Upholstered Stacking Chairs | 1,927.44 | 18.12% |
| Office Supplies | Fellowes PB500 Electric Punch Binding Machine | 7,753.04 | 28.24% |
| Technology | Canon imageCLASS 2200 Advanced Copier | 25,199.93 | 40.91% |

**Top 5 por volumen de ventas**

| # | Producto | Ventas | Ganancia |
|---|---|---:|---:|
| 1 | Canon imageCLASS 2200 Advanced Copier | 61,599.82 | 25,199.93 |
| 2 | Fellowes PB500 Electric Punch Binding Machine | 27,453.38 | 7,753.04 |
| 3 | Cisco TelePresence System EX90 | 22,638.48 | **-1,811.08** |
| 4 | HON 5400 Series Task Chairs for Big and Tall | 21,870.58 | **0.00** |
| 5 | GBC DocuBind TL300 Electric Binding System | 19,823.48 | 2,233.51 |

**Top 5 con menor rentabilidad**

| # | Producto | Margen |
|---|---|---:|
| 1 | Eureka Disposable Bags for Sanitaire Vibra Groomer | -275.00% |
| 2 | Bush Westfield Collection Bookcases | -210.00% |
| 3 | Euro Pro Shark Stick Mini Vacuum | -190.71% |
| 4 | Okidata B401 Printer | -140.00% |
| 5 | Zebra GK420t Direct Thermal Printer | -133.33% |

### Interpretación
El producto más vendido (Canon imageCLASS 2200) también es el más rentable, pero la relación no es general: el tercer producto por ventas (Cisco TelePresence) pierde 1,811.08 y el cuarto (HON 5400) tiene ganancia cero. Los productos de menor rentabilidad pertenecen a Appliances, Bookcases y Machines, categorías donde los descuentos altos destruyen el margen.

### Conclusión
El ranking por ventas no debe usarse como único criterio de desempeño. La empresa debe proteger los productos de alta rotación y alto margen (copiadoras Canon, binding machines Fellowes) y revisar precios/descuentos de los productos que venden mucho pero no generan ganancia.

---

## Pregunta 6. Impacto de los descuentos

### Estrategia
Clasificación con `CASE` en cuatro rangos: sin descuento (0), bajo (0–20%], medio (20–50%] y alto (>50%). Se agregaron ventas, ganancia, margen, pérdidas, porcentaje no rentable y descuento promedio; luego se desagregó por categoría y subcategoría.

### Evidencia
`evidencias/07_p6_descuentos.txt`

| Rango | Registros | Ventas | Ganancia | Margen | Pérdidas | % no rentable | Descuento prom. |
|---|---:|---:|---:|---:|---:|---:|---:|
| Sin descuento | 4,798 | 1,087,908.47 | 320,987.60 | 29.51% | 0 | 0.00% | 0.00% |
| Bajo (0–20%] | 3,803 | 846,522.24 | 100,785.47 | 11.91% | 523 | 13.75% | 19.68% |
| Medio (20–50%] | 537 | 298,541.41 | -58,817.00 | -19.70% | 492 | 91.62% | 36.70% |
| Alto (>50%) | 856 | 64,228.74 | -76,559.05 | -119.20% | 856 | 100.00% | 71.89% |

Contraste global: las operaciones con pérdida tienen un descuento promedio de **48.09%**, frente a **8.14%** en las rentables.

Subcategorías más afectadas con descuento alto: Binders (-38,510.50), Machines (-19,579.32), Furnishings (-5,944.66), Appliances (-8,629.64) y Bookcases (-3,894.94).

### Interpretación
Existe una relación inversa y muy marcada entre descuento y rentabilidad. Hasta 20% el negocio sigue siendo rentable (margen 11.91%), pero a partir de 20% el margen se vuelve negativo y con descuentos >50% **todas** las operaciones pierden dinero. Los descuentos altos no compensan con volumen: generan solo 64,228.74 en ventas (2.8% del total) y destruyen 76,559.05 de ganancia.

### Conclusión
Los descuentos elevados están claramente asociados con una mayor proporción de operaciones no rentables. Se recomienda fijar un límite operativo de descuento (idealmente ≤20%), exigir aprobación para descuentos superiores y revisar las políticas de Binders, Machines, Furnishings, Appliances y Bookcases.

---

## Pregunta 7. Tendencias temporales

### Estrategia
Agregación mensual con `CONCAT(YEAR, MONTH)`, `LAG` para variación mes a mes, `LAG(..., 12)` para comparación con el mismo mes del año anterior, `AVG` con ventana de 3 filas para promedio móvil y `RANK` para los tres meses de mayor/menor venta.

### Evidencia
`evidencias/08_p7_tendencias.txt`

| Grupo | Mes | Ventas | Ganancia |
|---|---|---:|---:|
| Mayor volumen | 2017-11 | 118,447.83 | 9,690.10 |
| Mayor volumen | 2016-12 | 96,999.04 | 17,885.31 |
| Mayor volumen | 2017-09 | 87,866.65 | 10,991.56 |
| Menor volumen | 2014-02 | 4,519.89 | 862.31 |
| Menor volumen | 2015-02 | 11,951.41 | 2,813.85 |
| Menor volumen | 2014-01 | 14,236.90 | 2,450.19 |

Totales anuales:

| Año | Registros | Ventas | Ganancia | Margen |
|---|---:|---:|---:|---:|
| 2014 | 1,993 | 484,247.50 | 49,543.97 | 10.23% |
| 2015 | 2,102 | 470,532.51 | 61,618.60 | 13.10% |
| 2016 | 2,587 | 609,205.60 | 81,795.17 | 13.43% |
| 2017 | 3,312 | 733,215.26 | 93,439.27 | 12.74% |

La serie mensual muestra un patrón estacional: los picos se concentran en noviembre y diciembre, y los valles en enero y febrero. Ejemplo: noviembre 2017 creció +52.29% frente a octubre 2017 y +49.16% frente a noviembre 2016; febrero 2014 fue el mes más bajo con 4,519.89.

### Interpretación
Las ventas crecieron 51.4% entre 2014 y 2017 (484,247.50 → 733,215.26), impulsadas principalmente por 2016 y 2017. La ganancia creció aún más (88.6%), aunque el margen de 2017 bajó a 12.74% frente a 13.43% de 2016, señal de que el crecimiento reciente se está comprando con mayor costo comercial (descuentos). El promedio móvil de 3 meses suaviza la estacionalidad y confirma la tendencia ascendente.

### Conclusión
El negocio tiene una tendencia anual creciente con fuerte estacionalidad de cierre de año. La planeación de inventario, personal y presupuesto de marketing debe concentrarse en septiembre–diciembre, y debe vigilarse la caída de margen de 2017.

---

## Pregunta 8. Análisis Pareto de ventas y rentabilidad

### Estrategia
Se agregó por producto y se calculó, con `SUM() OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`, la contribución acumulada y su porcentaje sobre el total. Se identificó la posición mínima en la que el acumulado alcanza el 80%.

### Evidencia
`evidencias/09_p8_pareto.txt`

| Métrica | Total productos | Productos para 80% | % del catálogo |
|---|---:|---:|---:|
| Ventas | 1,862 | 414 | 22.23% |
| Ganancia | 1,862 | 164 | 8.81% |

Productos líderes:
- **Ventas**: Canon imageCLASS 2200 Advanced Copier, 61,599.82 (2.68% del total).
- **Ganancia**: Canon imageCLASS 2200 Advanced Copier, 25,199.93 (8.80% del total).

### Interpretación
La concentración es fuerte, pero más intensa en la ganancia que en las ventas: se necesitan **414 productos (22.23%)** para explicar el 80% de las ventas, mientras que solo **164 productos (8.81%)** explican el 80% de la ganancia. Esto significa que una parte importante del catálogo vende pero no aporta ganancia proporcional. Las diferencias se explican por productos de alto volumen con margen bajo o negativo (Cisco TelePresence, HON 5400, descuentos altos).

### Conclusión
El principio de Pareto se cumple con fuerza en la rentabilidad: menos del 9% del catálogo sostiene el 80% de la ganancia. La gestión comercial debe enfocarse en proteger y replicar esos 164 productos, y en revisar o descontinuar los productos de alto volumen con margen nulo o negativo.

---

## Conclusión general

1. El dataset es estructuralmente limpio y puede analizarse sin descartes, aunque presenta una incidencia de codificación en nombres de producto que no afecta las métricas.
2. El modelo ORC particionado por año es adecuado para el volumen y deja preparado el dataset para consultas analíticas eficientes.
3. West y East son las regiones más rentables; Central requiere una revisión urgente de su política comercial.
4. El análisis RFM identifica un núcleo de clientes de alto valor y un grupo relevante en riesgo que concentra casi la mitad de las ventas.
5. Los descuentos superiores al 20% destruyen margen; por encima del 50% todas las operaciones son deficitarias.
6. La ganancia está mucho más concentrada que las ventas: 164 productos generan el 80% de la rentabilidad.
7. La tendencia anual es creciente con estacionalidad marcada en el cierre de año, pero el margen de 2017 muestra una alerta que debe monitorearse.
