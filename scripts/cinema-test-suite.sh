#!/bin/bash

# ============ CINEMA TUNING TEST SUITE ============
# Полный набор тестов для Ubuntu 26.04 VM
# Использование: ./cinema-test-suite.sh

set -e

REPORT_DIR="/tmp/cinema-tuning-$(date +%Y%m%d-%H%M%S)"
mkdir -p $REPORT_DIR

echo "====== CINEMA SERVER TUNING TEST SUITE ======"
echo "Report directory: $REPORT_DIR"
echo ""

# ============ PHASE 1: BASELINE ============

echo "[1/6] Collecting baseline metrics..."

cat > $REPORT_DIR/01-baseline-before.txt <<'EOF'
====== BASELINE BEFORE OPTIMIZATION ======
EOF

{
    echo "Time: $(date)"
    echo "Kernel: $(uname -r)"
    echo ""
    
    echo "====== CPU & MEMORY ======"
    nproc
    free -h
    echo ""
    
    echo "====== SYSCTL PARAMETERS ======"
    echo "TCP buffers:"
    sysctl net.core.rmem_max net.core.wmem_max
    echo "TCP congestion control:"
    sysctl net.ipv4.tcp_congestion_control
    echo "Dirty pages:"
    sysctl vm.dirty_ratio vm.dirty_background_ratio
    echo "Swappiness:"
    sysctl vm.swappiness
    echo ""
    
    echo "====== I/O SCHEDULER ======"
    for disk in /sys/block/vd*/queue/scheduler /sys/block/sd*/queue/scheduler; do
        [ -f "$disk" ] && cat "$disk"
    done
    echo ""
    
    echo "====== NETWORK ======"
    ip link show | head -20
    echo ""
    
} | tee -a $REPORT_DIR/01-baseline-before.txt

echo "✓ Baseline collected"
echo ""

# ============ PHASE 2: INSTALL TOOLS ============

echo "[2/6] Installing required packages..."

sudo apt-get update -qq > /dev/null 2>&1 || true
sudo apt-get install -y -qq \
    ethtool \
    iperf3 \
    sysstat \
    fio \
    mdadm \
    lvm2 \
    build-essential \
    linux-tools-generic \
    > /dev/null 2>&1

echo "✓ Packages installed"
echo ""

# ============ PHASE 3: APPLY SYSCTL TUNING ============

echo "[3/6] Applying sysctl optimizations..."

sudo tee /etc/sysctl.d/99-cinema-tuning.conf > /dev/null <<'SYSCTL'
# Cinema server performance tuning

# ========== TCP BUFFERS ==========
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_default = 131072
net.core.wmem_default = 131072

# ========== TCP OPTIMIZATION ==========
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300

# ========== CONNECTION LIMITS ==========
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# ========== DISK I/O ==========
vm.dirty_ratio = 30
vm.dirty_background_ratio = 10
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
vm.swappiness = 10

# ========== FILE SYSTEM ==========
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.pipe-max-size = 1048576

# ========== KERNEL ==========
kernel.pid_max = 4194304
kernel.sysrq = 1
SYSCTL

sudo sysctl -p /etc/sysctl.d/99-cinema-tuning.conf > /dev/null 2>&1

echo "✓ Sysctl applied"
echo ""

# ============ PHASE 4: NETWORK TUNING ============

echo "[4/6] Optimizing network stack..."

IFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -n "$IFACE" ]; then
    sudo ethtool -K $IFACE gro on gso on tso on lro off 2>/dev/null || true
    sudo ethtool -C $IFACE rx-usecs 100 rx-frames 64 tx-usecs 100 tx-frames 64 2>/dev/null || true
    sudo ethtool -G $IFACE rx 4096 tx 4096 2>/dev/null || true
    
    echo "✓ Network optimized ($IFACE)"
else
    echo "⚠ Could not detect network interface"
fi
echo ""

# ============ PHASE 5: PERFORMANCE TESTS ============

echo "[5/6] Running performance tests..."

# Disk I/O test
echo "Running disk I/O test (fio)..."
fio --name=read_test \
    --ioengine=libaio \
    --iodepth=32 \
    --rw=read \
    --bs=4k \
    --numjobs=4 \
    --size=1G \
    --runtime=30 \
    --group_reporting \
    --output=$REPORT_DIR/05-fio-read-after.txt \
    > /dev/null 2>&1

fio --name=write_test \
    --ioengine=libaio \
    --iodepth=32 \
    --rw=write \
    --bs=4k \
    --numjobs=4 \
    --size=1G \
    --runtime=30 \
    --group_reporting \
    --output=$REPORT_DIR/05-fio-write-after.txt \
    > /dev/null 2>&1

echo "✓ FIO tests completed"

# Network throughput test (if second server available)
echo "Network test (local loopback):"
iperf3 -s -D -p 5201 > /dev/null 2>&1
sleep 1
iperf3 -c 127.0.0.1 -p 5201 -t 10 -R 2>/dev/null | tee -a $REPORT_DIR/05-network-test.txt
sleep 1
pkill -f "iperf3 -s" 2>/dev/null || true

echo "✓ Network test completed"
echo ""

# ============ PHASE 6: FINAL DIAGNOSTICS ============

echo "[6/6] Collecting final metrics..."

cat > $REPORT_DIR/06-baseline-after.txt <<'EOF'
====== BASELINE AFTER OPTIMIZATION ======
EOF

{
    echo "Time: $(date)"
    echo ""
    
    echo "====== SYSCTL PARAMETERS (after) ======"
    echo "TCP buffers:"
    sysctl net.core.rmem_max net.core.wmem_max
    echo "TCP congestion control:"
    sysctl net.ipv4.tcp_congestion_control
    echo "Dirty pages:"
    sysctl vm.dirty_ratio vm.dirty_background_ratio
    echo "Swappiness:"
    sysctl vm.swappiness
    echo ""
    
    echo "====== I/O PERFORMANCE ======"
    echo "Reading I/O test results from fio..."
    tail -20 $REPORT_DIR/05-fio-read-after.txt 2>/dev/null || echo "FIO results not available"
    echo ""
    
} | tee -a $REPORT_DIR/06-baseline-after.txt

echo "✓ Final metrics collected"
echo ""

# ============ REPORT SUMMARY ============

echo "====== TEST SUITE COMPLETED ======"
echo ""
echo "Report location: $REPORT_DIR"
echo ""
echo "Generated files:"
ls -1 $REPORT_DIR/
echo ""
echo "Key metrics:"
echo "1. Before/After sysctl: $REPORT_DIR/01-baseline-before.txt vs $REPORT_DIR/06-baseline-after.txt"
echo "2. Disk I/O read:  grep -i 'iops\|bw' $REPORT_DIR/05-fio-read-after.txt"
echo "3. Disk I/O write: grep -i 'iops\|bw' $REPORT_DIR/05-fio-write-after.txt"
echo "4. Network:        $REPORT_DIR/05-network-test.txt"
echo ""
echo "Next steps:"
echo "- Compare baseline-before.txt vs baseline-after.txt"
echo "- Run: cat $REPORT_DIR/05-fio-read-after.txt | tail -30"
echo "- For multi-server test: iperf3 -s (on another machine)"
echo "                         iperf3 -c <IP> -t 30 (from this machine)"
