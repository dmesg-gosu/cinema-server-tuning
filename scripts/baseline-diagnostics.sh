#!/bin/bash

# Baseline diagnostics перед оптимизацией
# Результаты сохраним для сравнения

REPORT_DIR="/tmp/cinema-tuning-report"
mkdir -p $REPORT_DIR

echo "====== BASELINE DIAGNOSTICS ======"
echo "Time: $(date)" | tee $REPORT_DIR/baseline.txt
echo ""

# ===== СИСТЕМА =====
echo "====== SYSTEM INFO ======" | tee -a $REPORT_DIR/baseline.txt
uname -a | tee -a $REPORT_DIR/baseline.txt
echo "" | tee -a $REPORT_DIR/baseline.txt

# ===== CPU =====
echo "====== CPU ======" | tee -a $REPORT_DIR/baseline.txt
nproc | tee -a $REPORT_DIR/baseline.txt
cat /proc/cpuinfo | grep "model name" | head -1 | tee -a $REPORT_DIR/baseline.txt
echo "" | tee -a $REPORT_DIR/baseline.txt

# ===== ПАМЯТЬ =====
echo "====== MEMORY ======" | tee -a $REPORT_DIR/baseline.txt
free -h | tee -a $REPORT_DIR/baseline.txt
echo "" | tee -a $REPORT_DIR/baseline.txt

# ===== ДИСКИ =====
echo "====== DISK INFO ======" | tee -a $REPORT_DIR/baseline.txt
lsblk -o NAME,SIZE,TYPE,FSTYPE | tee -a $REPORT_DIR/baseline.txt
echo "" | tee -a $REPORT_DIR/baseline.txt

# ===== ТЕКУЩИЕ SYSCTL ПАРАМЕТРЫ =====
echo "====== CURRENT SYSCTL SETTINGS ======" | tee -a $REPORT_DIR/baseline.txt
sysctl net.core.rmem_max | tee -a $REPORT_DIR/baseline.txt
sysctl net.core.wmem_max | tee -a $REPORT_DIR/baseline.txt
sysctl net.ipv4.tcp_rmem | tee -a $REPORT_DIR/baseline.txt
sysctl net.ipv4.tcp_wmem | tee -a $REPORT_DIR/baseline.txt
sysctl net.ipv4.tcp_congestion_control | tee -a $REPORT_DIR/baseline.txt
sysctl vm.dirty_ratio | tee -a $REPORT_DIR/baseline.txt
sysctl vm.swappiness | tee -a $REPORT_DIR/baseline.txt
echo "" | tee -a $REPORT_DIR/baseline.txt

# ===== I/O SCHEDULER =====
echo "====== I/O SCHEDULER ======" | tee -a $REPORT_DIR/baseline.txt
for disk in /sys/block/sd*/queue/scheduler; do
    echo "$disk:" | tee -a $REPORT_DIR/baseline.txt
    cat "$disk" | tee -a $REPORT_DIR/baseline.txt
done
echo "" | tee -a $REPORT_DIR/baseline.txt

# ===== СЕТЬ =====
echo "====== NETWORK INFO ======" | tee -a $REPORT_DIR/baseline.txt
ip link show | tee -a $REPORT_DIR/baseline.txt
echo "" | tee -a $REPORT_DIR/baseline.txt

# ===== ТЕСТ I/O (базовый) =====
echo "====== BASELINE I/O TEST (10 sec) ======" | tee -a $REPORT_DIR/baseline.txt
echo "Running iostat..." | tee -a $REPORT_DIR/baseline.txt
iostat -x 1 10 | tee -a $REPORT_DIR/baseline-iostat.txt

echo ""
echo "====== BASELINE SAVED ======"
echo "Report saved to: $REPORT_DIR"
ls -lh $REPORT_DIR/
