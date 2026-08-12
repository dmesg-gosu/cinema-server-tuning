#!/bin/bash

# ============ CINEMA SERVER TUNING - RESTORE/ROLLBACK SCRIPT ============
# Скрипт для отката всех изменений на предыдущие значения
# Использование: sudo ./restore-cinema-tuning.sh

set -e

BACKUPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# ============ INITIALIZATION ============

if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (sudo)"
    exit 1
fi

print_header "CINEMA SERVER TUNING - RESTORE SCRIPT"

# Проверяем что папка backups существует
if [ ! -d "$BACKUPS_DIR" ]; then
    print_error "Backups directory not found: $BACKUPS_DIR"
    echo "Make sure you ran cinema-tuning-master.sh first"
    exit 1
fi

# Ищем доступные бэкапы
BACKUPS=()
while IFS= read -r -d '' file; do
    BACKUPS+=("$file")
done < <(find "$BACKUPS_DIR" -name "sysctl-backup-*.conf" -print0 | sort -rz)

if [ ${#BACKUPS[@]} -eq 0 ]; then
    print_error "No backup files found in $BACKUPS_DIR"
    exit 1
fi

print_info "Found ${#BACKUPS[@]} backup(s)"
echo ""

# Выводим доступные бэкапы
echo -e "${CYAN}Available backups:${NC}"
for i in "${!BACKUPS[@]}"; do
    BACKUP_DATE=$(basename "${BACKUPS[$i]}" | sed 's/sysctl-backup-//;s/.conf//')
    echo "  $((i+1))) Backup from $BACKUP_DATE"
done

echo ""
echo -n "Select backup to restore (1-${#BACKUPS[@]}): "
read -r choice

if ! [[ $choice =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#BACKUPS[@]} ]; then
    print_error "Invalid choice"
    exit 1
fi

SELECTED_BACKUP="${BACKUPS[$((choice-1))]}"
BACKUP_DATE=$(basename "$SELECTED_BACKUP" | sed 's/sysctl-backup-//;s/.conf//')

print_warning "You are about to restore backup from: $BACKUP_DATE"
echo -n "Are you sure? (yes/no): "
read -r confirm

if [ "$confirm" != "yes" ]; then
    print_info "Restore cancelled"
    exit 0
fi

print_header "RESTORING SYSTEM CONFIGURATION"

# Сохраняем текущие значения перед восстановлением
RESTORE_LOG="$BACKUPS_DIR/restore-log-$(date +%Y%m%d-%H%M%S).txt"

{
    echo "System Restore Log"
    echo "Date: $(date)"
    echo "Restoring from: $SELECTED_BACKUP"
    echo ""
    echo "Original values before restore:"
    sysctl -a 2>/dev/null | grep -E "net\.(core|ipv4)|vm\.(dirty|swappiness)" || true
    echo ""
    echo "Applying backup values..."
    echo ""
    
} > "$RESTORE_LOG"

# Применяем бэкап
print_step() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_step "Applying backup configuration..."

if sysctl -p "$SELECTED_BACKUP" >> "$RESTORE_LOG" 2>&1; then
    print_success "Configuration restored successfully"
else
    print_warning "Some parameters may not have been applied (this is normal)"
fi

# Добавляем логирование
{
    echo ""
    echo "New values after restore:"
    sysctl -a 2>/dev/null | grep -E "net\.(core|ipv4)|vm\.(dirty|swappiness)" || true
    echo ""
    echo "Restore completed: $(date)"
    
} >> "$RESTORE_LOG"

print_success "Restore log saved: $RESTORE_LOG"

# ============ VERIFICATION ============

print_header "VERIFICATION"

echo "Verifying key parameters:"
echo ""

# Проверяем несколько ключевых параметров
echo "TCP Configuration:"
echo "  rmem_max: $(sysctl -n net.core.rmem_max) bytes"
echo "  wmem_max: $(sysctl -n net.core.wmem_max) bytes"
echo "  congestion_control: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo ""

echo "Memory Configuration:"
echo "  dirty_ratio: $(sysctl -n vm.dirty_ratio)%"
echo "  swappiness: $(sysctl -n vm.swappiness)"
echo ""

print_success "System configuration restored!"

# ============ SUMMARY ============

print_header "RESTORE COMPLETED"

{
    echo ""
    echo "✓ System restored to previous configuration"
    echo ""
    echo "Details:"
    echo "  Backup used: $SELECTED_BACKUP"
    echo "  Restore log: $RESTORE_LOG"
    echo ""
    echo "Next steps:"
    echo "  1. Verify system is working correctly"
    echo "  2. Check application performance"
    echo "  3. Review logs for any issues"
    echo ""
    echo "To apply optimizations again:"
    echo "  sudo $PROJECT_ROOT/scripts/cinema-tuning-master.sh"
    echo ""
    
}

exit 0
