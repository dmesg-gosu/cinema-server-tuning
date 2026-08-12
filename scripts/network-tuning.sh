#!/bin/bash

# ============ ОПТИМИЗАЦИЯ СЕТЕВОГО СТЕКА LINUX ============
# Для скачивания больших файлов (фильмы 50GB+) с высокой скоростью

# ============ 1. ETHTOOL - БАЗОВАЯ ДИАГНОСТИКА И ОПТИМИЗАЦИЯ ============

# Проверяем текущие параметры NIC
ethtool -c eth0                    # Текущий coalescing
ethtool -g eth0                    # Ring buffer sizes
ethtool -i eth0                    # Информация о драйвере
ethtool -S eth0 | head -20         # Статистика (errors, drops)

# ============ 2. RING BUFFERS - РАЗМЕР ОЧЕРЕДЕЙ ============
# Большие очереди = больше пакетов в буфере = меньше потерь при всплесках

# Проверяем максимальные размеры
ethtool -G eth0 rx 4096 tx 4096    # Увеличиваем RX и TX ring buffers

# Для 10Gbps интерфейса - ещё больше
# ethtool -G eth0 rx 8192 tx 8192

# ============ 3. INTERRUPT COALESCING - СНИЖЕНИЕ КОЛИЧЕСТВА ПРЕРЫВАНИЙ ============
# По умолчанию каждый пакет = прерывание = CPU overhead
# Coalescing = группируем пакеты перед прерыванием

ethtool -C eth0 \
    rx-usecs 100 \              # Жди 100 микросекунд перед прерыванием
    rx-frames 64 \              # ИЛИ дождись 64 пакетов
    tx-usecs 100 \              # То же для TX
    tx-frames 64

# ============ 4. OFFLOADING - РАЗГРУЗКА НА NIC ============
# Включаем что-то, выключаем что-то

ethtool -K eth0 \
    gro on \                    # Generic Receive Offload - объединяет пакеты в одном
    gso on \                    # Generic Segmentation Offload
    tso on \                    # TCP Segmentation Offload
    lro off \                   # Large Receive Offload - может снизить latency для TCP

# Проверяем результат
ethtool -k eth0

# ============ 5. ЧИСЛО IRQ HANDLERS ============
# Распределяем прерывания между CPU для параллелизма

# Включаем RSS (Receive Side Scaling) если поддерживает NIC
ethtool -X eth0 equal 4            # Распределяем между 4 CPU

# Илиручной affinity через irqbalance
# systemctl enable irqbalance
# systemctl start irqbalance

# ============ 6. MTU (MAXIMUM TRANSMISSION UNIT) ============
# По умолчанию 1500 байт (Ethernet)
# Jumbo frames (9000) = меньше пакетов, меньше overhead

# Проверяем текущий MTU
ip link show eth0

# Увеличиваем MTU (если сеть поддерживает - часто в data center)
ip link set dev eth0 mtu 9000

# Постоянно в /etc/netplan/01-netcfg.yaml (для Ubuntu 20+)
# Or /etc/network/interfaces для старых систем

# ============ NETPLAN КОНФИГ (Ubuntu 20+) ============
cat > /etc/netplan/01-netcfg.yaml <<'EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      mtu: 9000
      # Включаем offloading
      # (на разных ОС работает по-разному)
EOF

# ============ FIREWALL - УБЕДИСЬ ЧТО НЕ БЛОКИРУЕТ ============

# Проверяем UFW (если включен)
ufw status

# Открываем порт для скачивания (например 8080 для HTTP)
# ufw allow 8080/tcp

# ============ SYSCTL ПАРАМЕТРЫ ДЛЯ СЕТЕВОГО СТЕКА ============
# Это в /etc/sysctl.d/99-network.conf

cat > /etc/sysctl.d/99-network.conf <<'EOFNET'
# ========== TCP БУФЕРЫ И THROUGHPUT ==========

# Максимальные размеры буферов (уже описывали, повторяем)
net.core.rmem_max = 134217728           # 128MB
net.core.wmem_max = 134217728           # 128MB
net.ipv4.tcp_rmem = 4096 87380 67108864  # 4K:85K:64M
net.ipv4.tcp_wmem = 4096 65536 67108864  # 4K:64K:64M

# Очередь приложений
net.core.somaxconn = 65535

# ========== TCP WINDOW SCALING И TIMESTAMPS ==========
# Window scaling = большие TCP окна (до 1GB)
net.ipv4.tcp_window_scaling = 1

# Timestamps помогают при потерях
net.ipv4.tcp_timestamps = 1

# ========== CONGESTION CONTROL ==========
# BBR хороший для high-bandwidth, high-latency каналов
net.ipv4.tcp_congestion_control = bbr

# Если нет BBR - используем cubic (по умолчанию)
# net.ipv4.tcp_congestion_control = cubic

# ========== FAST OPEN ==========
net.ipv4.tcp_fastopen = 3          # 1=client, 2=server, 3=both

# ========== PIPE BUFFERS ==========
# Размер pipe буфера для системных операций
fs.pipe-max-size = 1048576         # 1MB

# ========== CONNECTION REUSE ==========
# Переиспользуем TIME_WAIT соединения
net.ipv4.tcp_tw_reuse = 1

# Таймауты
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300

# ========== UDP (если используется) ==========
net.core.udp_mem = 1048576 2097152 4194304  # 1M:2M:4M

EOFNET

# Применяем
sysctl -p /etc/sysctl.d/99-network.conf

# ============ ТЕСТИРОВАНИЕ СЕТИ ============

# Проверяем пропускную способность между серверами
# На receiver:
# iperf3 -s -p 5001

# На sender:
# iperf3 -c 192.168.1.50 -p 5001 -t 30 -P 4 -R

# Проверяем задержку (latency)
ping -c 100 <target> | tail -1

# Проверяем потери пакетов
mtr -c 100 <target>

# ============ МОНИТОРИНГ СЕТЕВОГО СТЕКА ============

# Смотрим TCP соединения и их статусы
ss -s
ss -tan | grep ESTAB | wc -l

# Подробнее про TCP:
# ss -tonp | head -30

# Ошибки и retransmits
netstat -s | grep -i "retrans\|lost\|drop"

# ============ ПРИМЕР: СКРИПТ ДЛЯ ОПТИМИЗАЦИИ СЕТИ ============

cat > /usr/local/bin/network-tuning.sh <<'EOFNETSCRIPT'
#!/bin/bash

# Применяем все сетевые оптимизации для больших файлов

IFACE=${1:-eth0}

echo "Optimizing network for $IFACE..."

# sysctl параметры (через отдельный конфиг)
sysctl -p /etc/sysctl.d/99-network.conf > /dev/null

# ethtool оптимизации
ethtool -K $IFACE gro on gso on tso on lro off 2>/dev/null || true
ethtool -C $IFACE rx-usecs 100 rx-frames 64 tx-usecs 100 tx-frames 64 2>/dev/null || true
ethtool -G $IFACE rx 4096 tx 4096 2>/dev/null || true

# MTU jumbo frames (если поддерживает)
ip link set dev $IFACE mtu 9000 2>/dev/null || true

# RSS distribution
if ethtool -X $IFACE equal 4 2>/dev/null; then
    echo "RSS enabled for 4 CPUs"
else
    echo "RSS not supported"
fi

# Проверяем результат
echo "Current settings for $IFACE:"
echo "Offloads:"
ethtool -k $IFACE 2>/dev/null | grep -E "generic|tcp|large"
echo ""
echo "Coalescing:"
ethtool -c $IFACE 2>/dev/null | grep -E "rx-usecs|rx-frames"
echo ""
echo "Ring buffers:"
ethtool -g $IFACE 2>/dev/null | grep -E "RX|TX"

EOFNETSCRIPT

chmod +x /usr/local/bin/network-tuning.sh

# Использование:
# ./network-tuning.sh eth0

echo "Network tuning guide completed"
