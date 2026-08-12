#!/bin/bash

# ============ CINEMA SERVER TUNING - MASTER SCRIPT ============
# Единый оркестратор для всех оптимизаций и тестов
# Запускает все скрипты по очереди и собирает результаты в единый отчёт
# Использование: sudo ./cinema-tuning-master.sh

set -e

# ============ CONFIGURATION ============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="/tmp/cinema-tuning-report-$(date +%Y%m%d-%H%M%S)"
SUMMARY_FILE="$REPORT_DIR/SUMMARY.txt"
FULL_LOG="$REPORT_DIR/FULL.log"

# Colors для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============ HELPER FUNCTIONS ============

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_to_summary() {
    echo "$@" | tee -a "$SUMMARY_FILE"
}

log_to_full() {
    echo "$@" >> "$FULL_LOG"
}

# ============ INITIALIZATION ============

mkdir -p "$REPORT_DIR"

# Инициализируем файлы
cat > "$SUMMARY_FILE" <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║   CINEMA SERVER TUNING - COMPREHENSIVE REPORT                 ║
║   High-Performance Linux Configuration for Streaming          ║
╚════════════════════════════════════════════════════════════════╝
EOF

cat > "$FULL_LOG" <<'EOF'
CINEMA SERVER TUNING - FULL DIAGNOSTIC LOG
Generated: $(date)
EOF

print_header "CINEMA SERVER TUNING MASTER SUITE"
echo "Report directory: $REPORT_DIR"
echo "Timestamp: $(date)"
echo ""

# ============ PHASE 1: PRE-CHECK ============

print_header "Phase 1: System Pre-Check"

# Проверяем что скрипты существуют
REQUIRED_SCRIPTS=(
    "baseline-diagnostics.sh"
    "cinema-test-suite-advanced.sh"
    "diagnose-server.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        print_success "Found: $script"
        log_to_summary "✓ $script"
    else
        print_warning "Missing: $script (optional)"
        log_to_summary "⚠ $script (not found)"
    fi
done

# Проверяем root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (sudo)"
    exit 1
fi
print_success "Running as root"

# Проверяем Ubuntu/Debian
if ! grep -q "Ubuntu\|Debian" /etc/os-release 2>/dev/null; then
    print_warning "This script is tested on Ubuntu/Debian. Other distros may not work fully."
fi

OS_INFO=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
print_success "OS: $OS_INFO"
log_to_summary "OS: $OS_INFO"

echo ""

# ============ PHASE 2: BASELINE BEFORE ============

print_header "Phase 2: Collecting Baseline (BEFORE Optimization)"

print_step "Gathering system metrics..."

{
    echo ""
    echo "╔═ BASELINE BEFORE OPTIMIZATION ═╗"
    echo ""
    echo "Timestamp: $(date)"
    echo "Kernel: $(uname -r)"
    echo "Hostname: $(hostname)"
    echo ""
    
    echo "📊 CPU Information:"
    echo "  Cores: $(nproc)"
    echo "  Model: $(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)"
    echo ""
    
    echo "💾 Memory:"
    free -h | grep Mem
    echo "  Available: $(free -h | grep Mem | awk '{print $7}')"
    echo ""
    
    echo "📈 Current System Settings:"
    echo "  TCP rmem_max: $(sysctl -n net.core.rmem_max 2>/dev/null || echo 'N/A') bytes"
    echo "  TCP wmem_max: $(sysctl -n net.core.wmem_max 2>/dev/null || echo 'N/A') bytes"
    echo "  Congestion control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'N/A')"
    echo "  Dirty ratio: $(sysctl -n vm.dirty_ratio 2>/dev/null || echo 'N/A')%"
    echo "  Swappiness: $(sysctl -n vm.swappiness 2>/dev/null || echo 'N/A')"
    echo "  File descriptor limit: $(ulimit -n)"
    echo ""
    
    echo "💿 Disk Information:"
    lsblk -d -o NAME,SIZE,TYPE | head -10
    echo ""
    
    echo "🌐 Network Interfaces:"
    ip link show | grep -E "^\d+:|mtu"
    echo ""
    
} | tee -a "$SUMMARY_FILE" | tee -a "$FULL_LOG"

print_success "Baseline collected"
echo ""

# ============ PHASE 3: RUN TESTS ============

print_header "Phase 3: Running Advanced Performance Tests"

print_step "Executing cinema-test-suite-advanced.sh..."
print_warning "This will take approximately 30-40 minutes..."
echo ""

if [ -f "$SCRIPT_DIR/cinema-test-suite-advanced.sh" ]; then
    # Запускаем advanced тесты, перенаправляя вывод
    bash "$SCRIPT_DIR/cinema-test-suite-advanced.sh" 2>&1 | tee -a "$FULL_LOG" | grep -E "✓|✗|====|Running|completed"
    
    ADVANCED_REPORT=$(find /tmp/cinema-tuning-advanced-* -type d -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    
    if [ -d "$ADVANCED_REPORT" ]; then
        print_success "Advanced tests completed"
        print_step "Collecting advanced test results..."
        
        # Копируем результаты
        cp "$ADVANCED_REPORT"/*.txt "$REPORT_DIR/" 2>/dev/null || true
        
        # Извлекаем ключевые метрики
        {
            echo ""
            echo "╔═ PERFORMANCE TEST RESULTS ═╗"
            echo ""
            
            if [ -f "$ADVANCED_REPORT/06b-fio-read-256k.txt" ]; then
                echo "📊 Large Block Read Performance (256K - Cinema Files):"
                grep "READ:" "$ADVANCED_REPORT/06b-fio-read-256k.txt" | head -1
                grep "iops" "$ADVANCED_REPORT/06b-fio-read-256k.txt" | head -1
                echo ""
            fi
            
            if [ -f "$ADVANCED_REPORT/06c-fio-concurrent-readwrite.txt" ]; then
                echo "📊 Concurrent Read/Write (Realistic Scenario - 70% read/30% write):"
                grep -E "READ:|WRITE:" "$ADVANCED_REPORT/06c-fio-concurrent-readwrite.txt" | head -2
                echo ""
            fi
            
            if [ -f "$ADVANCED_REPORT/07-network-loopback.txt" ]; then
                echo "🌐 Network Performance:"
                tail -3 "$ADVANCED_REPORT/07-network-loopback.txt" | head -1
                echo ""
            fi
            
        } | tee -a "$SUMMARY_FILE" | tee -a "$FULL_LOG"
    else
        print_error "Could not find advanced test results"
    fi
else
    print_warning "cinema-test-suite-advanced.sh not found, skipping advanced tests"
fi

echo ""

# ============ PHASE 4: SYSTEM DIAGNOSTICS ============

print_header "Phase 4: Full System Diagnostics"

print_step "Running comprehensive diagnostics..."

if [ -f "$SCRIPT_DIR/diagnose-server.sh" ]; then
    bash "$SCRIPT_DIR/diagnose-server.sh" 2>&1 | tee "$REPORT_DIR/diagnostics.txt" | tee -a "$FULL_LOG" | head -50
    print_success "Diagnostics completed"
else
    print_warning "diagnose-server.sh not found"
fi

echo ""

# ============ PHASE 5: SUMMARY & RECOMMENDATIONS ============

print_header "Phase 5: Summary & Recommendations"

{
    echo ""
    echo "╔═ OPTIMIZATION RECOMMENDATIONS ═╗"
    echo ""
    
    # Проверяем текущие параметры и даём рекомендации
    RMEM_MAX=$(sysctl -n net.core.rmem_max 2>/dev/null || echo 0)
    if [ "$RMEM_MAX" -lt 134217728 ]; then
        echo "⚠ TCP Read Buffer: Currently $((RMEM_MAX/1024/1024))MB, recommended 128MB"
        echo "  Action: Apply sysctl optimization"
    else
        echo "✓ TCP Read Buffer: Optimized ($((RMEM_MAX/1024/1024))MB)"
    fi
    echo ""
    
    CONGESTION=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    if [ "$CONGESTION" != "bbr" ]; then
        echo "⚠ Congestion Control: Currently $CONGESTION, recommended BBR"
        echo "  Action: Apply sysctl optimization"
    else
        echo "✓ Congestion Control: Optimized (BBR)"
    fi
    echo ""
    
    DIRTY=$(sysctl -n vm.dirty_ratio 2>/dev/null || echo 0)
    if [ "$DIRTY" -lt 30 ]; then
        echo "⚠ Dirty Page Ratio: Currently $DIRTY%, recommended 30%"
        echo "  Action: Apply sysctl optimization"
    else
        echo "✓ Dirty Page Ratio: Optimized ($DIRTY%)"
    fi
    echo ""
    
    FD_LIMIT=$(ulimit -n)
    if [ "$FD_LIMIT" -lt 65536 ]; then
        echo "⚠ File Descriptor Limit: Currently $FD_LIMIT, recommended 65536"
        echo "  Action: Increase in /etc/security/limits.conf and reboot"
    else
        echo "✓ File Descriptor Limit: Optimized ($FD_LIMIT)"
    fi
    echo ""
    
    echo "╔═ NEXT STEPS ═╗"
    echo ""
    echo "1. Review Performance Results:"
    echo "   - Check disk I/O throughput (should be >500 MB/s for reads)"
    echo "   - Verify concurrent read/write performance"
    echo "   - Confirm network efficiency"
    echo ""
    echo "2. Apply Optimization (if not already done):"
    echo "   sudo sysctl -p configs/99-performance.conf"
    echo ""
    echo "3. For Multi-Server Deployment:"
    echo "   ansible-playbook -i inventory.ini playbook.yml"
    echo ""
    echo "4. Monitor in Production:"
    echo "   dstat -tcs --disk --net 5"
    echo "   iotop -b -o"
    echo ""
    
} | tee -a "$SUMMARY_FILE" | tee -a "$FULL_LOG"

echo ""

# ============ FINAL REPORT ============

print_header "REPORT GENERATION"

print_step "Compiling final report..."

# Создаём финальный отчёт
cat >> "$SUMMARY_FILE" <<EOF

╔═════════════════════════════════════════════════════════════════╗
║                    REPORT DETAILS                               ║
╚═════════════════════════════════════════════════════════════════╝

Generated: $(date)
Report Location: $REPORT_DIR

Files Generated:
EOF

ls -1 "$REPORT_DIR"/*.txt 2>/dev/null | sed 's|.*/||' | sed 's/^/  - /' >> "$SUMMARY_FILE"

cat >> "$SUMMARY_FILE" <<EOF

Useful Commands to Review Results:

1. View this summary:
   cat $SUMMARY_FILE

2. View full diagnostic log:
   less $FULL_LOG

3. Check specific test results:
   grep -i "iops\|bw\|throughput" $REPORT_DIR/*.txt

4. Compare before/after sysctl:
   diff $REPORT_DIR/*baseline*.txt

5. Monitor real-time performance:
   watch -n 1 'iostat -x | grep sda'

════════════════════════════════════════════════════════════════════

For more information, see:
  - README.md (overview)
  - docs/TUNING-GUIDE.md (detailed parameter explanations)
  - docs/TROUBLESHOOTING.md (solutions for common issues)

EOF

print_success "Report compiled"

# ============ DISPLAY SUMMARY ============

print_header "FINAL SUMMARY"

# Выводим SUMMARY на экран
cat "$SUMMARY_FILE"

echo ""
print_header "TEST SUITE COMPLETED"

{
    echo ""
    echo "Report saved to: $REPORT_DIR"
    echo ""
    echo "Quick access:"
    echo "  Summary:   cat $SUMMARY_FILE"
    echo "  Full log:  less $FULL_LOG"
    echo ""
    echo "Next steps:"
    echo "  1. Review performance results"
    echo "  2. Apply optimizations if needed"
    echo "  3. Deploy to production servers"
    echo ""
    
} | tee -a "$FULL_LOG"

print_success "All tests completed successfully!"
print_success "Report directory: $REPORT_DIR"

exit 0
