#!/bin/bash

# ============ RAID SETUP ДЛЯ КИНОТЕАТРОВ ============
# Для больших файлов (фильмы 50GB+) и интенсивного I/O
# Сценарий: Скачивание фильмов + одновременное воспроизведение

# ============ ВЫБОР RAID УРОВНЯ ============
# RAID 1 (Mirror)   - 2 диска, 50% ёмкости, отличная скорость чтения, хороша для SSD
# RAID 5 (Striping+Parity) - 3+ диска, 66-80% ёмкости, хороша для больших данных
# RAID 6 (Dual-parity) - 4+ диска, лучше при восстановлении крупных массивов
# RAID 10 (1+0) - 4+ диска (чётное), отличная скорость, 50% ёмкости

# Рекомендация для кинотеатров:
# - SSD (для текущих фильмов): RAID 1 или RAID 10
# - HDD (для архива): RAID 5 или RAID 6

# ============ СОЗДАНИЕ RAID 5 (3x HDD для архива) ============
# sudo mdadm --create /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd

# ============ СОЗДАНИЕ RAID 1 (2x SSD для активных фильмов) ============
# sudo mdadm --create /dev/md1 --level=1 --raid-devices=2 /dev/nvme0n1 /dev/nvme1n1

# ============ ПАРАМЕТРЫ RAID ДЛЯ ОПТИМИЗАЦИИ ============

# После создания RAID, оптимизируем параметры:

configure_raid() {
    local raid_dev=$1  # например /dev/md0
    local stripe_cache=$2  # размер stripe cache в KB (256-8192)
    
    echo "Configuring $raid_dev..."
    
    # Stripe cache - размер буфера для операций RAID 5/6
    # Больше = лучше для sequential I/O, но жрёт память
    # Для больших файлов: 1024-4096 KB разумно
    echo $stripe_cache > /sys/block/${raid_dev##/dev/}/md/stripe_cache_size
    
    # Check if stripe cache was set
    cat /sys/block/${raid_dev##/dev/}/md/stripe_cache_size
}

# Пример вызова:
# configure_raid /dev/md0 2048

# ============ CHUNK SIZE ДЛЯ RAID ============
# При создании RAID важно установить правильный chunk size
# По умолчанию: 512KB
# Для больших последовательных файлов (фильмы):
#   - Chunk size 1-2MB лучше
#   - stripe width (chunk_size * devices) должна быть 4-16MB

# Пример: для RAID 5 с 3 дисками
# mdadm --create /dev/md0 --level=5 --raid-devices=3 --chunk=2048 /dev/sdb /dev/sdc /dev/sdd
# Результат: stripe width = 2048KB * 2 (devices-1) = 4096KB = 4MB

# ============ ОПТИМИЗАЦИЯ I/O SCHEDULER ДЛЯ RAID ============
# Выбираем правильный I/O scheduler для каждого диска

set_io_scheduler() {
    local device=$1
    local scheduler=$2  # deadline, noop, cfq, mq-deadline, bfq
    
    # deadline - хорош для I/O чувствительных приложений (БД, файлообмен)
    # noop - минимум обработки, хорош когда RAID controller делает планирование
    # bfq - справедливое распределение для multi-user систем
    # mq-deadline - современный, для NVMe
    
    echo $scheduler > /sys/block/$device/queue/scheduler
    echo "Set $device to $scheduler"
    cat /sys/block/$device/queue/scheduler
}

# Примеры:
# set_io_scheduler sdb deadline      # для HDD в RAID 5
# set_io_scheduler nvme0n1 mq-deadline  # для NVMe SSD

# ============ АВТОМАТИЗАЦИЯ В /etc/rc.local или systemd service ============
cat > /etc/systemd/system/raid-tuning.service <<'EOF'
[Unit]
Description=RAID Performance Tuning
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/raid-tuning.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Создаём скрипт
cat > /usr/local/bin/raid-tuning.sh <<'EOFSCRIPT'
#!/bin/bash
# Тюнинг RAID при загрузке

# Stripe cache для RAID массивов
echo 2048 > /sys/block/md0/md/stripe_cache_size
echo 2048 > /sys/block/md1/md/stripe_cache_size

# I/O scheduler для дисков
echo deadline > /sys/block/sdb/queue/scheduler
echo deadline > /sys/block/sdc/queue/scheduler
echo deadline > /sys/block/sdd/queue/scheduler

echo mq-deadline > /sys/block/nvme0n1/queue/scheduler
echo mq-deadline > /sys/block/nvme1n1/queue/scheduler

# Read-ahead (количество блоков для предварительного чтения)
# Больше = лучше для sequential, меньше = лучше для random
blockdev --setra 4096 /dev/md0    # 4MB read-ahead для HDD массива
blockdev --setra 2048 /dev/md1    # 2MB для SSD массива

echo "RAID tuning applied"
EOFSCRIPT

chmod +x /usr/local/bin/raid-tuning.sh

# ============ МОНИТОРИНГ RAID ============

# Статус RAID
# cat /proc/mdstat

# Детали RAID
# mdadm --detail /dev/md0

# Проверка синхронизации (resync progress)
# cat /proc/mdstat | grep -i resync

# Скорость resync (чтобы не замораживать систему)
# echo 100000 > /proc/sys/dev/raid/speed_limit_min
# echo 200000 > /proc/sys/dev/raid/speed_limit_max

# ============ ПРОВЕРКА ЦЕЛОСТНОСТИ RAID (ПЕРИОДИЧЕСКИ) ============

# Запуск check (не блокирует систему, работает параллельно)
# echo check > /sys/block/md0/md/sync_action

# Запуск repair (если найдены ошибки)
# echo repair > /sys/block/md0/md/sync_action

# ============ RESIZE RAID МАССИВА (если добавляешь диск) ============

# 1. Добавляем диск к RAID
# mdadm --add /dev/md0 /dev/sde

# 2. Расширяем массив
# mdadm --grow /dev/md0 --raid-devices=4

# 3. Расширяем файловую систему
# resize2fs /dev/md0  (для ext4)
# or
# lvextend -l +100%FREE /dev/vg0/lv_data && resize2fs /dev/vg0/lv_data

echo "RAID configuration guide completed"
