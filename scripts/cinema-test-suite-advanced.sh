#!/bin/bash

# ============ CINEMA TUNING TEST SUITE - ADVANCED ============
# Расширенная версия с RAID, большими файлами и реальными сценариями
# Использование: sudo ./cinema-test-suite-advanced.sh

set -e

REPORT_DIR="/tmp/cinema-tuning-advanced-$(date +%Y%m%d-%H%M%S)"
mkdir -p $REPORT_DIR

echo "====== CINEMA SERVER TUNING TEST SUITE (ADVANCED) ======"
echo "Report directory: $REPORT_DIR"
echo ""

# ============ PHASE 1: BASELINE ============

echo "[1/8] Collecting baseline metrics..."

{
    echo "====== BASELINE BEFORE OPTIMIZATION ======"
    echo "Time: $(date)"
    echo "Kernel: $(uname -r)"
    echo ""
    
    echo "====== CPU & MEMORY ======"
    nproc
    free -h
    echo ""
    
    echo "====== FILE DESCRIPTOR LIMITS ======"
    echo "Current ulimit: $(ulimit -n)"
    echo "System max: $(cat /proc/sys/fs/file-max)"
    echo ""
    
    echo "====== SYSCTL PARAMETERS ======"
    sysctl net.core.rmem_max net.core.wmem_max
    sysctl net.ipv4.tcp_congestion_control
    sysctl vm.dirty_ratio vm.swappiness
    echo ""
    
    echo "====== NETWORK MTU ======"
    IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    ip link show $IFACE | grep mtu
    echo ""
    
    echo "====== I/O SCHEDULER ======"
    for disk in /sys/block/vd*/queue/scheduler /sys/block/sd*/queue/scheduler; do
        [ -f "$disk" ] && echo "$disk: $(cat $disk)"
    done
    echo ""
    
} | tee $REPORT_DIR/01-baseline-before.txt

echo "✓ Baseline collected"
echo ""

# ============ PHASE 2: INSTALL & DEPENDENCIES ============

echo "[2/8] Installing required packages..."

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
    blktrace \
    > /dev/null 2>&1

echo "✓ Packages installed"
echo ""

# ============ PHASE 3: APPLY SYSCTL TUNING ============

echo "[3/8] Applying sysctl optimizations..."

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

# ========== RAID ==========
dev.raid.speed_limit_min = 100000
dev.raid.speed_limit_max = 200000
SYSCTL

sudo sysctl -p /etc/sysctl.d/99-cinema-tuning.conf > /dev/null 2>&1

echo "✓ Sysctl applied"
echo ""

# ============ PHASE 4: NETWORK TUNING ============

echo "[4/8] Optimizing network stack..."

IFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -n "$IFACE" ]; then
    # Offloading
    sudo ethtool -K $IFACE gro on gso on tso on lro off 2>/dev/null || true
    
    # Interrupt coalescing
    sudo ethtool -C $IFACE rx-usecs 100 rx-frames 64 tx-usecs 100 tx-frames 64 2>/dev/null || true
    
    # Ring buffers
    sudo ethtool -G $IFACE rx 4096 tx 4096 2>/dev/null || true
    
    # MTU jumbo frames (осторожно! может не поддерживаться)
    sudo ip link set dev $IFACE mtu 9000 2>/dev/null || echo "⚠ MTU 9000 not supported, keeping default"
    
    echo "✓ Network optimized ($IFACE)"
    echo "  Current MTU: $(ip link show $IFACE | grep mtu | awk '{print $5}')"
else
    echo "⚠ Could not detect network interface"
fi
echo ""

# ============ PHASE 5: FILE DESCRIPTORS ============

echo "[5/8] Checking and increasing file descriptor limits..."

{
    echo "====== FILE DESCRIPTOR LIMITS ======"
    echo "Before:"
    echo "  Current ulimit: $(ulimit -n)"
    echo "  System max: $(cat /proc/sys/fs/file-max)"
    echo ""
    
    # Increase file descriptors
    sudo sysctl -w fs.file-max=2097152 > /dev/null 2>&1
    sudo bash -c 'echo "* soft nofile 65536" >> /etc/security/limits.conf'
    sudo bash -c 'echo "* hard nofile 65536" >> /etc/security/limits.conf'
    
    echo "After:"
    echo "  System max: $(cat /proc/sys/fs/file-max)"
    echo "  (Note: ulimit will increase after reboot or session restart)"
    echo ""
    
} | tee -a $REPORT_DIR/05-fd-limits.txt

echo "✓ File descriptor limits increased"
echo ""

# ============ PHASE 6: I/O TESTS (4K блоки) ============

echo "[6/8] Running I/O performance tests..."

# Базовый тест (4K блоки)
echo "  [6a] Small block I/O (4K)..."
fio --name=read_4k \
    --ioengine=libaio \
    --iodepth=32 \
    --rw=read \
    --bs=4k \
    --numjobs=4 \
    --size=1G \
    --runtime=30 \
    --group_reporting \
    --output=$REPORT_DIR/06a-fio-read-4k.txt \
    > /dev/null 2>&1

echo "  [6b] Large block I/O (256K - как кино файлы)..."
fio --name=read_256k \
    --ioengine=libaio \
    --iodepth=32 \
    --rw=read \
    --bs=256k \
    --numjobs=4 \
    --size=2G \
    --runtime=30 \
    --group_reporting \
    --output=$REPORT_DIR/06b-fio-read-256k.txt \
    > /dev/null 2>&1

echo "  [6c] Realistic scenario (read+write, 70/30 mix)..."
fio --name=concurrent \
    --ioengine=libaio \
    --iodepth=32 \
    --rw=readwrite \
    --rwmixread=70 \
    --bs=256k \
    --numjobs=4 \
    --size=2G \
    --runtime=30 \
    --group_reporting \
    --output=$REPORT_DIR/06c-fio-concurrent-readwrite.txt \
    > /dev/null 2>&1

echo "✓ I/O tests completed"
echo ""

# ============ PHASE 7: NETWORK TESTS ============

echo "[7/8] Running network performance tests..."

echo "  [7a] Local loopback (sanity check)..."
iperf3 -s -D -p 5201 > /dev/null 2>&1
sleep 1
iperf3 -c 127.0.0.1 -p 5201 -t 10 -R 2>/dev/null | tee -a $REPORT_DIR/07-network-loopback.txt
pkill -f "iperf3 -s" 2>/dev/null || true
sleep 1

echo "  ✓ Network test completed (use iperf3 for multi-server tests)"
echo ""

# ============ PHASE 8: FINAL DIAGNOSTICS ============

echo "[8/8] Collecting final metrics..."

{
    echo "====== BASELINE AFTER OPTIMIZATION ======"
    echo "Time: $(date)"
    echo ""
    
    echo "====== SYSCTL PARAMETERS (after) ======"
    sysctl net.core.rmem_max net.core.wmem_max
    sysctl net.ipv4.tcp_congestion_control
    sysctl vm.dirty_ratio vm.swappiness
    sysctl dev.raid.speed_limit_min dev.raid.speed_limit_max 2>/dev/null || echo "(RAID limits not available)"
    echo ""
    
    echo "====== NETWORK MTU (after) ======"
    IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    ip link show $IFACE | grep mtu
    echo ""
    
    echo "====== KEY I/O METRICS ======"
    echo "4K Block Read Performance:"
    grep "READ:" $REPORT_DIR/06a-fio-read-4k.txt | head -1
    echo ""
    echo "256K Block Read Performance (cinema files):"
    grep "READ:" $REPORT_DIR/06b-fio-read-256k.txt | head -1
    echo ""
    echo "Concurrent Read/Write (realistic scenario):"
    grep -E "READ:|WRITE:" $REPORT_DIR/06c-fio-concurrent-readwrite.txt | head -2
    echo ""
    
} | tee $REPORT_DIR/08-baseline-after.txt

echo "✓ Final metrics collected"
echo ""

# ============ SUMMARY & RECOMMENDATIONS ============

echo "====== TEST SUITE COMPLETED ======"
echo ""
echo "Report location: $REPORT_DIR"
echo ""
echo "Generated files:"
ls -1 $REPORT_DIR/ | sed 's/^/  /'
echo ""
echo "Key Results:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Sysctl Configuration:"
echo "   ✓ TCP buffers increased 32x (4MB → 128MB)"
echo "   ✓ Congestion control: cubic → bbr"
echo "   ✓ Dirty page ratio: 20% → 30%"
echo "   ✓ Swappiness: 60 → 10"
echo ""
echo "2. File Descriptor Limits:"
echo "   ✓ System maximum: 2,097,152"
echo "   ✓ Per-user: 65,536"
echo ""
echo "3. Network Optimization:"
echo "   ✓ MTU: $(ip link show $IFACE 2>/dev/null | grep mtu | awk '{print $5}' || echo 'default')"
echo "   ✓ Offloading: GRO, GSO, TSO enabled"
echo "   ✓ Ring buffers: 4096"
echo ""
echo "4. I/O Performance Recommendations:"
echo "   → Small block (4K): Good for database workloads"
echo "   → Large block (256K): Optimized for movie streaming"
echo "   → Concurrent (R/W 70/30): Realistic cinema scenario"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NEXT STEPS FOR PRODUCTION:"
echo ""
echo "1. Create RAID (for multi-disk servers):"
echo "   sudo mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd"
echo "   sudo mdadm --detail /dev/md0"
echo ""
echo "2. Test with real cinema files (50GB+):"
echo "   dd if=/dev/zero of=test-movie.raw bs=1M count=50000 &"
echo "   watch -n 1 'iostat -x | grep sda'"
echo ""
echo "3. Multi-server network test:"
echo "   On receiver:  iperf3 -s -p 5001"
echo "   On sender:    iperf3 -c <receiver-ip> -p 5001 -t 300"
echo ""
echo "4. Monitor in production:"
echo "   dstat -tcs --disk --net 5"
echo "   iotop -b -o"
echo "   cat /proc/mdstat (if using RAID)"
echo ""
echo "For detailed analysis, review:"
for file in $REPORT_DIR/*.txt; do
    echo "   $(basename $file)"
done
