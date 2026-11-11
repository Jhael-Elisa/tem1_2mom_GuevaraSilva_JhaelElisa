# ============================================================
# Ejecución automática del examen Superstore en el clúster Docker
# Uso:  powershell -ExecutionPolicy Bypass -File scripts\ejecutar_todo.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$container = "hive-server"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$csv = Join-Path $root "datos\Sample - Superstore.csv"
$sqlDir = Join-Path $root "sql"
$scriptsDir = Join-Path $root "scripts"
$evidenciasDir = Join-Path $root "evidencias"

if (-not (Test-Path $csv)) { throw "No se encontró el dataset: $csv" }

Write-Host "[1/6] Copiando dataset y scripts al contenedor..." -ForegroundColor Cyan
docker cp $csv "${container}:/tmp/superstore.csv"
docker cp "$sqlDir\." "${container}:/tmp/sql/"
docker cp "$scriptsDir\run_queries.sh" "${container}:/tmp/run_queries.sh"

Write-Host "[2/6] Subiendo el CSV a HDFS..." -ForegroundColor Cyan
docker exec $container bash -lc "hdfs dfs -mkdir -p /user/root/superstore/raw && hdfs dfs -put -f /tmp/superstore.csv /user/root/superstore/raw/"

Write-Host "[3/6] Creando base de datos, staging y tabla analítica..." -ForegroundColor Cyan
docker exec $container bash -lc "beeline -u 'jdbc:hive2://localhost:10000/default' -f /tmp/sql/00_setup.sql"
if ($LASTEXITCODE -ne 0) { throw "Falló 00_setup.sql" }
docker exec $container bash -lc "beeline -u 'jdbc:hive2://localhost:10000/default' -f /tmp/sql/01_ddl.sql"
if ($LASTEXITCODE -ne 0) { throw "Falló 01_ddl.sql" }

Write-Host "[4/6] Cargando datos y ejecutando todas las consultas..." -ForegroundColor Cyan
docker exec $container bash -lc "rm -f /tmp/evidencias/*.txt"
docker exec -e HADOOP_CLIENT_OPTS="-Xmx2048m" $container bash /tmp/run_queries.sh
if ($LASTEXITCODE -ne 0) { throw "Falló la ejecución de las consultas" }

Write-Host "[4b/6] Calculando estadísticas del optimizador..." -ForegroundColor Cyan
docker exec -e HADOOP_CLIENT_OPTS="-Xmx2048m" $container bash -lc "hive -S -f /tmp/sql/02b_estadisticas.sql > /tmp/evidencias_err/estadisticas.log 2>&1"

Write-Host "[5/6] Copiando evidencias al proyecto..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $evidenciasDir -Force | Out-Null
Remove-Item "$evidenciasDir\*.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "$evidenciasDir\*.err" -Force -ErrorAction SilentlyContinue
docker cp "${container}:/tmp/evidencias/." $evidenciasDir
Remove-Item "$evidenciasDir\*.err" -Force -ErrorAction SilentlyContinue

Write-Host "[6/6] Validando registros cargados..." -ForegroundColor Cyan
docker exec -e HADOOP_CLIENT_OPTS="-Xmx1024m" $container bash -lc "hive -S -e 'USE db_superstore_jhaelguevara; SELECT COUNT(*) AS total FROM superstore;'"

Write-Host "Proceso completado. Evidencias en: $evidenciasDir" -ForegroundColor Green
