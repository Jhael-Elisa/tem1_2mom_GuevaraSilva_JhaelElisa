#!/bin/bash
# Ejecuta los scripts HiveQL con Hive CLI en modo local y guarda evidencias
set -u
cd /tmp/sql
mkdir -p /tmp/evidencias /tmp/evidencias_err

for f in 02_carga 03_p2_calidad 04_p3_region 05_p4_rfm 06_p5_productos 07_p6_descuentos 08_p7_tendencias 09_p8_pareto; do
    hive -S -f "$f.sql" > "/tmp/evidencias/$f.txt" 2> "/tmp/evidencias_err/$f.err"
    code=$?
    size=$(stat -c %s "/tmp/evidencias/$f.txt")
    echo "$f exit=$code size=$size"
done
