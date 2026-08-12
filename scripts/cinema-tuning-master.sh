#!/bin/bash

# ============ CINEMA SERVER TUNING - INTERACTIVE MASTER SCRIPT ============
# Интерактивный оркестратор со следующими возможностями:
# 1. Анализ системы и рекомендации по профилям
# 2. Сохранение старых значений для отката
# 3. Выбор профиля оптимизации (minimal, standard, maximum)
# 4. Сохранение результатов в текущую директорию
# 5. Организация тестовых файлов в отдельную папку

set -e

# ============ CONFIGURATION ============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/tuning-reports/$(date +%Y%m%d-%H%M%S)"
BACKUPS_DIR="$PROJECT_ROOT/backups"
TESTS_DIR="$REPORT_DIR/tests"
SUMMARY_FILE="$REPORT_DIR/SUMMARY.txt"
FULL_LOG="$REPORT_DIR/FULL.log"
BACKUP_FILE="$BACKUPS_DIR/sysctl-backup-$(date +%Y%m%d-%H%M%S).conf"
RESTORE_SCRIPT="$BACKUPS_DIR/restore-$(date +%Y%m%d-%H%M%S).sh"
SYSTEM_INFO_FILE="$REPORT_DIR/system-info.txt"

# Colors для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============ HELPER FUNCTIONS ============

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
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

print_info() {
    echo -e "${MAGENTA}ℹ $1${NC}"
}

log_to_summary() {
    echo "$@" | tee -a "$SUMMARY_FILE"
}

log_to_full() {
    echo "$@" >> "$FULL_LOG"
}

# Функция для интерактивного выбора
select_option() {
    local prompt=$1
    shift
    local options=("$@")
    local selected=0
    
    while true; do
        echo -e "\n${CYAN}$prompt${NC}"
        for i in "${!options[@]}"; do
            echo "  $((i+1))) ${options[$i]}"
        done
        echo -n "Выбери номер (1-${#options[@]}): "
        read -r choice
        
        if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            selected=$((choice-1))
            echo -e "${GREEN}Выбрано: ${options[$selected]}${NC}"
            break
        else
            print_error "Неверный выбор. Попробуй ещё раз."
        fi
    done
    
    echo $selected
}

# ============ INITIALIZATION ============

mkdir -p "$REPORT_DIR" "$BACKUPS_DIR" "$TESTS_DIR"

# Инициализируем файлы
cat > "$SUMMARY_FILE" <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║   CINEMA SERVER TUNING - COMPREHENSIVE REPORT                 ║
║   High-Performance Linux Configuration for Streaming          ║
╚════════════════════════════════════════════════════════════════╝
EOF

cat > "$FULL_LOG" <<'EOF'
CINEMA SERVER TUNING - FULL DIAGNOSTIC LOG
EOF

print_header "CINEMA SERVER TUNING - INTERACTIVE MASTER SUITE"
echo "Report directory: $REPORT_DIR"
echo "Backups directory: $BACKUPS_DIR"
echo "Timestamp: $(date)"
echo ""

# ============ PHASE 1: SYSTEM ANALYSIS ============

print_header "Phase 1: System Analysis & Profile Recommendation"

# Проверяем root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (sudo)"
    exit 1
fi
print_success "Running as root"

# Собираем информацию о системе (ПЕРЕД определением переменных профиля!)
CPU_COUNT=$(nproc 2>/dev/null || echo "4")
CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "Unknown")
TOTAL_MEM=$(free -h 2>/dev/null | grep Mem | awk '{print $2}' || echo "N/A")
AVAIL_MEM=$(free -h 2>/dev/null | grep Mem | awk '{print $7}' || echo "N/A")
DISK_COUNT=$(lsblk -d 2>/dev/null | grep -E "^sd|^nvme" | wc -l || echo "1")

{
    echo "Timestamp: $(date)"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo ""
    
    echo "📊 CPU Information:"
    echo "  Cores: $CPU_COUNT"
    echo "  Model: $CPU_MODEL"
    echo ""
    
    echo "💾 Memory:"
    echo "  Total: $TOTAL_MEM"
    echo "  Available: $AVAIL_MEM"
    echo ""
    
    echo "💿 Disk Information:"
    echo "  Number of disks: $DISK_COUNT"
    lsblk -d -o NAME,SIZE,TYPE 2>/dev/null | head -10
    echo ""
    
    echo "🌐 Network:"
    ip link show 2>/dev/null | grep -E "^\d+:|mtu"
    echo ""
    
    echo "📈 Current System Settings:"
    echo "  TCP rmem_max: $(sysctl -n net.core.rmem_max 2>/dev/null || echo 'N/A') bytes"
    echo "  TCP wmem_max: $(sysctl -n net.core.wmem_max 2>/dev/null || echo 'N/A') bytes"
    echo "  Congestion control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'N/A')"
    echo "  Swappiness: $(sysctl -n vm.swappiness 2>/dev/null || echo 'N/A')"
    
} | tee "$SYSTEM_INFO_FILE" | tee -a "$SUMMARY_FILE"

print_success "System information collected"

# ============ PHASE 2: PROFILE RECOMMENDATION ============

print_header "Phase 2: Profile Recommendation"

# Определяем рекомендуемый профиль
RECOMMENDED_PROFILE=0

# Правильно парсим переменные
CPU_COUNT=$(nproc 2>/dev/null || echo "4")
TOTAL_MEM_VALUE=$(free -h 2>/dev/null | grep Mem | awk '{print $2}' | sed 's/Gi//' | sed 's/Mi//')
TOTAL_MEM_UNIT=$(free -h 2>/dev/null | grep Mem | awk '{print $2}' | grep -o '[A-Z]i$')
DISK_COUNT=$(lsblk -d 2>/dev/null | grep -E "^sd|^nvme" | wc -l || echo "1")

# Конвертируем в числа для сравнения
if [[ $TOTAL_MEM_UNIT == "Gi" ]]; then
    TOTAL_MEM_NUM=$((${TOTAL_MEM_VALUE%.*}))
else
    TOTAL_MEM_NUM=0
fi

# Рекомендация профиля
if [ "$CPU_COUNT" -lt 4 ] || [ "$TOTAL_MEM_NUM" -lt 8 ] || [ "$DISK_COUNT" -lt 2 ]; then
    RECOMMENDED_PROFILE=0  # minimal
    PROFILE_REASON="Система имеет ограниченные ресурсы"
elif [ "$CPU_COUNT" -lt 8 ] || [ "$TOTAL_MEM_NUM" -lt 16 ]; then
    RECOMMENDED_PROFILE=1  # standard
    PROFILE_REASON="Система среднего размера"
else
    RECOMMENDED_PROFILE=2  # maximum
    PROFILE_REASON="Мощная система с хорошими ресурсами"
fi

{
    echo ""
    echo "╔═ PROFILE RECOMMENDATIONS ═╗"
    echo ""
    echo "Анализ системы:"
    echo "  CPU: $CPU_COUNT cores"
    echo "  RAM: $TOTAL_MEM"
    echo "  Disks: $DISK_COUNT"
    echo ""
    echo "Рекомендация: $PROFILE_REASON"
    echo ""
    
} | tee -a "$SUMMARY_FILE"

# Описания профилей
PROFILES=(
    "MINIMAL - Консервативная оптимизация для слабых систем (2-4 CPU, <8GB RAM)"
    "STANDARD - Сбалансированная оптимизация для стандартных серверов (4-8 CPU, 8-32GB RAM)"
    "MAXIMUM - Агрессивная оптимизация для высоконагруженных систем (8+ CPU, 32GB+ RAM)"
)

# Выводим опции профилей
echo -e "${CYAN}Доступные профили оптимизации:${NC}"
for i in "${!PROFILES[@]}"; do
    if [ "$i" -eq "$RECOMMENDED_PROFILE" ]; then
        echo -e "  ${GREEN}$((i+1))) ${PROFILES[$i]}${NC} ${GREEN}← РЕКОМЕНДУЕТСЯ${NC}"
    else
        echo "  $((i+1))) ${PROFILES[$i]}"
    fi
done

echo ""
echo -n "Выбери профиль (1-3) [Enter для рекомендуемого]: "
read -r profile_choice

if [ -z "$profile_choice" ]; then
    PROFILE=$RECOMMENDED_PROFILE
else
    PROFILE=$((profile_choice-1))
fi

if [ "$PROFILE" -lt 0 ] || [ "$PROFILE" -gt 2 ]; then
    print_error "Неверный выбор. Используем рекомендуемый профиль."
    PROFILE=$RECOMMENDED_PROFILE
fi

PROFILE_NAME="${PROFILES[$PROFILE]}"
echo -e "\n${GREEN}Выбран профиль: $PROFILE_NAME${NC}\n"

log_to_summary "Выбранный профиль: $PROFILE_NAME"

# ============ PHASE 3: BACKUP OLD VALUES ============

print_header "Phase 3: Backing Up Current System Configuration"

print_step "Saving current sysctl parameters..."

# Сохраняем текущие значения в файл
{
    echo "# BACKUP OF SYSTEM SYSCTL PARAMETERS"
    echo "# Created: $(date)"
    echo "# This file can be used to restore original settings"
    echo ""
    
    sysctl -a 2>/dev/null | grep -E "net\.(core|ipv4)|vm\.(dirty|swappiness)" || true
    
} > "$BACKUP_FILE"

print_success "Backup saved to: $BACKUP_FILE"

# Создаём скрипт восстановления
{
    echo "#!/bin/bash"
    echo "# RESTORE SCRIPT - Restore original sysctl values"
    echo "# Created: $(date)"
    echo "# Usage: sudo $RESTORE_SCRIPT"
    echo ""
    echo "echo 'Restoring original sysctl values...'"
    echo ""
    echo "# Apply backup values"
    echo "sysctl -p \"$BACKUP_FILE\" || true"
    echo ""
    echo "echo 'System restored to previous state'"
    echo ""
    
} > "$RESTORE_SCRIPT"

chmod +x "$RESTORE_SCRIPT"

print_success "Restore script created: $RESTORE_SCRIPT"

log_to_summary "✓ Backup created: $BACKUP_FILE"
log_to_summary "✓ Restore script: $RESTORE_SCRIPT"

echo ""

# ============ PHASE 4: PROFILE PARAMETERS ============

print_header "Phase 4: Applying Profile Parameters"

# Определяем параметры для каждого профиля
case $PROFILE in
    0)  # MINIMAL
        TCP_RMEM="67108864"      # 64MB
        TCP_WMEM="67108864"      # 64MB
        DIRTY_RATIO=25
        SWAPPINESS=20
        PROFILE_DESC="MINIMAL (Conservative)"
        ;;
    1)  # STANDARD
        TCP_RMEM="134217728"     # 128MB
        TCP_WMEM="134217728"     # 128MB
        DIRTY_RATIO=30
        SWAPPINESS=10
        PROFILE_DESC="STANDARD (Balanced)"
        ;;
    2)  # MAXIMUM
        TCP_RMEM="268435456"     # 256MB
        TCP_WMEM="268435456"     # 256MB
        DIRTY_RATIO=40
        SWAPPINESS=5
        PROFILE_DESC="MAXIMUM (Aggressive)"
        ;;
esac

print_step "Creating sysctl configuration for $PROFILE_DESC..."

# Создаём конфиг на основе выбранного профиля
cat > "/tmp/cinema-tuning-profile-$PROFILE.conf" <<SYSCTL
# Cinema Server Tuning - $PROFILE_DESC Profile
# Generated: $(date)

# TCP BUFFERS
net.core.rmem_max = $TCP_RMEM
net.core.wmem_max = $TCP_WMEM
net.ipv4.tcp_rmem = 4096 87380 $TCP_RMEM
net.ipv4.tcp_wmem = 4096 65536 $TCP_WMEM
net.core.rmem_default = 131072
net.core.wmem_default = 131072

# TCP OPTIMIZATION
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300

# CONNECTION LIMITS
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# DISK I/O
vm.dirty_ratio = $DIRTY_RATIO
vm.dirty_background_ratio = 10
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
vm.swappiness = $SWAPPINESS

# FILE SYSTEM
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.pipe-max-size = 1048576

# KERNEL
kernel.pid_max = 4194304
kernel.sysrq = 1

# RAID
dev.raid.speed_limit_min = 100000
dev.raid.speed_limit_max = 200000
SYSCTL

print_success "Profile configuration created"

print_step "Applying sysctl parameters..."
sysctl -p "/tmp/cinema-tuning-profile-$PROFILE.conf" > /dev/null 2>&1 || true

print_success "Parameters applied"

echo ""

# ============ PHASE 5: RUN TESTS ============

print_header "Phase 5: Running Advanced Performance Tests"

print_warning "Performance tests will take 30-40 minutes..."
print_step "FIO tests will write to: $TESTS_DIR"

echo ""

# Перемещаем тесты в отдельную папку
cd "$TESTS_DIR"

if [ -f "$SCRIPT_DIR/cinema-test-suite-advanced.sh" ]; then
    print_step "Executing cinema-test-suite-advanced.sh..."
    
    # Запускаем тесты с перенаправлением вывода
    bash "$SCRIPT_DIR/cinema-test-suite-advanced.sh" 2>&1 | tee -a "$FULL_LOG" | grep -E "✓|✗|====|Running|completed|fps"
    
    print_success "Advanced tests completed"
else
    print_warning "cinema-test-suite-advanced.sh not found"
fi

# Возвращаемся в исходную папку
cd "$REPORT_DIR"

echo ""

# ============ PHASE 6: FINAL REPORT ============

print_header "Phase 6: Generating Final Report"

{
    echo ""
    echo "╔═ OPTIMIZATION SUMMARY ═╗"
    echo ""
    echo "Profile Applied: $PROFILE_DESC"
    echo ""
    echo "Sysctl Parameters:"
    echo "  TCP rmem_max: $TCP_RMEM bytes ($((TCP_RMEM/1024/1024))MB)"
    echo "  TCP wmem_max: $TCP_WMEM bytes ($((TCP_WMEM/1024/1024))MB)"
    echo "  Dirty ratio: $DIRTY_RATIO%"
    echo "  Swappiness: $SWAPPINESS"
    echo ""
    echo "File Locations:"
    echo "  Backup: $BACKUP_FILE"
    echo "  Restore script: $RESTORE_SCRIPT"
    echo "  Test files: $TESTS_DIR"
    echo "  Full report: $REPORT_DIR"
    echo ""
    
} | tee -a "$SUMMARY_FILE"

# Создаём финальный отчёт
cat >> "$SUMMARY_FILE" <<EOF

╔═════════════════════════════════════════════════════════════════╗
║                    HOW TO USE RESULTS                           ║
╚═════════════════════════════════════════════════════════════════╝

1. View Summary Report:
   cat $SUMMARY_FILE

2. View Full Diagnostics Log:
   less $FULL_LOG

3. Check Test Results:
   ls $TESTS_DIR/

4. Restore Original Settings (if needed):
   sudo bash $RESTORE_SCRIPT

5. Monitor Performance:
   watch -n 1 'iostat -x | grep sda'
   dstat -tcs --disk --net 5

════════════════════════════════════════════════════════════════════
Report generated: $(date)
Report directory: $REPORT_DIR
════════════════════════════════════════════════════════════════════

EOF

print_success "Report generated"

# ============ DISPLAY RESULTS ============

print_header "FINAL SUMMARY"

cat "$SUMMARY_FILE"

print_header "TEST COMPLETED"

{
    echo ""
    echo "✓ All tests completed successfully!"
    echo ""
    echo "Report saved to: $REPORT_DIR"
    echo ""
    echo "Important Files:"
    echo "  Summary:        $SUMMARY_FILE"
    echo "  Full Log:       $FULL_LOG"
    echo "  System Info:    $SYSTEM_INFO_FILE"
    echo "  Backup:         $BACKUP_FILE"
    echo "  Restore Script: $RESTORE_SCRIPT"
    echo "  Test Results:   $TESTS_DIR/"
    echo ""
    echo "Quick Commands:"
    echo "  View summary:      cat $SUMMARY_FILE"
    echo "  View full log:     less $FULL_LOG"
    echo "  Restore settings:  sudo bash $RESTORE_SCRIPT"
    echo "  List test files:   ls -lh $TESTS_DIR/"
    echo ""
    
} | tee -a "$FULL_LOG"

print_success "Complete!"

exit 0
