#!/bin/bash

# Диагностика узких мест в Linux для высоконагруженных серверов
# Использование: ./diagnose-server.sh > report.txt

echo "====== SERVER DIAGNOSTICS REPORT ======"
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo ""

echo "====== CPU ======"
nproc
cat /proc/cpuinfo | grep "model name" | head -1
uptime
echo ""

echo "====== MEMORY ======"
free -h
echo "Buffers/Cached:"
grep -E "Buffers|Cached|MemAvailable" /proc/meminfo
echo ""

echo "====== DISK I/O ======"
echo "Current I/O load (iostat):"
iostat -x 1 3 | tail -20
echo ""
echo "Top I/O processes (iotop 5 sec):"
iotop -b -n 1 2>/dev/null || echo "iotop not installed"
echo ""

echo "====== DISK SCHEDULER ======"
for disk in /sys/block/sd*/queue/scheduler; do
    echo "$disk:"
    cat "$disk"
done
echo ""

echo "====== RAID STATUS ======"
cat /proc/mdstat 2>/dev/null || echo "No RAID detected"
echo ""

echo "====== NETWORK ======"
echo "Interface stats:"
netstat -i
echo ""
echo "TCP states:"
ss -s | grep -E "TCP|LISTEN|ESTAB|TIME-WAIT"
echo ""
echo "Errors/Dropped:"
ethtool -S eth0 2>/dev/null | grep -i -E "error|drop" || echo "ethtool not available"
echo ""

echo "====== MEMORY PRESSURE (if available) ======"
[ -f /proc/pressure/memory ] && cat /proc/pressure/memory || echo "PSI not available"
echo ""

echo "====== SYSCTL KEY PARAMETERS ======"
sysctl -a 2>/dev/null | grep -E "net.core.rmem|net.core.wmem|net.ipv4.tcp_rmem|net.ipv4.tcp_wmem|vm.dirty|vm.swappiness|net.ipv4.tcp_congestion_control" | sort
echo ""

echo "====== RUNNING SERVICES ======"
systemctl list-units --type=service --state=running | head -20
echo ""

echo "====== FILESYSTEM INFO ======"
df -h
echo ""
lsblk -o NAME,SIZE,TYPE,FSTYPE
