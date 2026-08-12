# Cinema Server Tuning & Optimization

Полный набор скриптов и конфигураций для оптимизации Linux серверов под высоконагруженные рабочие нагрузки: скачивание больших файлов (кино 50GB+), интенсивный I/O, сетевой трафик.

Разработано на основе 9+ лет опыта поддержки инфраструктуры сети кинотеатров по России и СНГ.

---

## 📋 Содержание

- [Обзор](#обзор)
- [Структура проекта](#структура-проекта)
- [Быстрый старт](#быстрый-старт)
- [Скрипты](#скрипты)
- [Конфигурация](#конфигурация)
- [Тестирование](#тестирование)
- [Результаты](#результаты)
- [Production deployment](#production-deployment)
- [Для контрибьюторов](#для-контрибьюторов)

---

## 🎯 Обзор

Этот проект оптимизирует Linux системы для:

- **Больших последовательных файлов** (50-500GB кино файлы)
- **Интенсивного I/O** (одновременное чтение + запись)
- **Высокопроизводительной сети** (1-10 Gbps transfers)
- **Многодисковых систем** (RAID 1, RAID 5, RAID 6)
- **Production стабильности** (мониторинг, автоматизация, ограничение ресурсов)

### Типичные улучшения:

| Метрика | До | После | Улучшение |
|---------|----|----|-----------|
| TCP buffer max | 4 MB | 128 MB | ↑ 32x |
| Disk read throughput | ~500 MB/s | ~957 MB/s | ↑ 91% |
| Disk write IOPS | ~25k | ~50k | ↑ 100% |
| Network efficiency | baseline | +offloading | ↑ 15-20% |
| File descriptors | 1024 | 65536 | ↑ 64x |

---

## 📁 Структура проекта

```
cinema-server-tuning/
├── README.md                           # Этот файл
├── scripts/
│   ├── cinema-tuning-master.sh        # 🌟 ОСНОВНОЙ СКРИПТ - запускает всё и собирает отчёт
│   ├── cinema-test-suite-advanced.sh  # Расширенные тесты (256K блоки, RAID, concurrent I/O)
│   ├── cinema-test-suite.sh           # Базовые тесты производительности
│   ├── baseline-diagnostics.sh        # Собрать метрики ДО оптимизации
│   ├── diagnose-server.sh             # Полная диагностика системы
│   ├── network-tuning.sh              # Оптимизация сетевого стека
│   └── raid-tuning.sh                 # Настройка RAID параметров
├── configs/
│   └── 99-performance.conf            # sysctl параметры для ядра (TCP, I/O, memory)
├── ansible/
│   └── linux-tuning-cinema-role.yml   # Ansible роль для автоматизации на 100+ серверов
├── docs/
│   ├── TUNING-GUIDE.md               # 📖 Подробный гайд - что каждый параметр делает и почему
│   ├── RAID-SETUP.md                 # Настройка RAID для кино (в планах)
│   ├── NETWORK-OPTIMIZATION.md       # Оптимизация сети (в планах)
│   └── TROUBLESHOOTING.md            # Решение проблем (в планах)
└── tests/
    └── test-scenarios.md              # Описание тестовых сценариев
```

---

## 🚀 Быстрый старт

### На Ubuntu 20.04+ (Debian-based)

#### Вариант 1: БЫСТРО (Используй мастер-скрипт) ⭐ РЕКОМЕНДУЕТСЯ

```bash
# 1. Клонируй репозиторий
git clone https://github.com/dmesg-gosu/cinema-server-tuning.git
cd cinema-server-tuning

# 2. Сделай скрипты исполняемыми
chmod +x scripts/*.sh

# 3. Запусти мастер-скрипт (выполнит всё и соберёт отчёт)
sudo ./scripts/cinema-tuning-master.sh

# 4. Результаты и красивый отчёт в /tmp/cinema-tuning-report-YYYYMMDD-HHMMSS/
# Займёт ~40-50 минут (включает все тесты)
```

**Мастер-скрипт автоматически:**
- ✓ Собирает baseline метрики (до оптимизации)
- ✓ Запускает расширенные тесты (FIO, iperf3)
- ✓ Применяет sysctl оптимизации
- ✓ Выполняет диагностику системы
- ✓ Выводит красивый отчёт с рекомендациями
- ✓ Сохраняет всё в одну папку для анализа

#### Вариант 2: По частям (для экспериментов)

```bash
# 1. Клонируй репозиторий
git clone https://github.com/dmesg-gosu/cinema-server-tuning.git
cd cinema-server-tuning

# 2. Сделай скрипты исполняемыми
chmod +x scripts/*.sh

# 3. Собери baseline (метрики ПЕРЕД оптимизацией)
sudo ./scripts/baseline-diagnostics.sh

# 4. Запусти расширенные тесты (~30 минут)
sudo ./scripts/cinema-test-suite-advanced.sh

# 5. Запусти полную диагностику
sudo ./scripts/diagnose-server.sh > diagnostics.txt

# 6. Результаты в /tmp/cinema-tuning-*/
```

### С Ansible (для нескольких серверов)

```bash
# 1. Установи Ansible на управляющий сервер
pip install ansible

# 2. Отредактируй inventory с адресами твоих кинотеатров
# inventory.ini:
# [cinema_servers]
# cinema1.example.com
# cinema2.example.com

# 3. Запусти роль
ansible-playbook -i inventory.ini playbook.yml
```

---

## 📜 Скрипты

### `cinema-tuning-master.sh` ⭐ ГЛАВНЫЙ СКРИПТ

**Используй его!** Интерактивный оркестратор со следующими возможностями:

```bash
sudo ./scripts/cinema-tuning-master.sh
# ~40-50 минут
# Результаты в ./tuning-reports/YYYYMMDD-HHMMSS/
```

**Что он делает:**

1. **Анализирует систему** — определяет мощность (CPU, RAM, диски)
2. **Рекомендует профиль** — MINIMAL, STANDARD или MAXIMUM
3. **Предлагает выбор** — пользователь выбирает или берёт рекомендуемый
4. **Сохраняет старые значения** — создаёт бэкап перед оптимизацией
5. **Применяет оптимизации** — на основе выбранного профиля
6. **Запускает тесты** — FIO (4K + 256K + concurrent), iperf3
7. **Организует результаты** — тестовые файлы в отдельную папку
8. **Выводит отчёт** — красивое резюме с рекомендациями

**Профили оптимизации:**

| Профиль | Система | TCP Buffer | Dirty Ratio | Swappiness |
|---------|---------|-----------|------------|-----------|
| **MINIMAL** | Слабые (2-4 CPU, <8GB RAM) | 64 MB | 25% | 20 |
| **STANDARD** | Средние (4-8 CPU, 8-32GB RAM) | 128 MB | 30% | 10 |
| **MAXIMUM** | Мощные (8+ CPU, 32GB+ RAM) | 256 MB | 40% | 5 |

**Результаты сохраняются в:**
```
tuning-reports/YYYYMMDD-HHMMSS/
├── SUMMARY.txt              # Красивый отчёт с выводами
├── FULL.log                 # Полный логи операций
├── system-info.txt          # Информация о системе
├── diagnostics.txt          # Полная диагностика
└── tests/                   # Тестовые файлы (не загромождают корень!)
    ├── 06a-fio-read-4k.txt
    ├── 06b-fio-read-256k.txt
    ├── 06c-fio-concurrent.txt
    └── 07-network-test.txt
```

**Файлы отката:**
```
backups/
├── sysctl-backup-YYYYMMDD-HHMMSS.conf    # Сохранённые старые значения
└── restore-YYYYMMDD-HHMMSS.sh            # Скрипт отката
```

---

### `baseline-diagnostics.sh`
Собирает текущие метрики системы перед оптимизацией.

```bash
sudo ./scripts/baseline-diagnostics.sh
# Результаты в /tmp/cinema-tuning-report/
```

**Собирает:**
- CPU, память, диски
- Текущие sysctl параметры
- I/O scheduler для каждого диска
- Сетевую информацию

---

### `cinema-test-suite.sh`
Базовый набор тестов: sysctl оптимизация + I/O + сеть.

```bash
sudo ./scripts/cinema-test-suite.sh
# ~15 минут, результаты в /tmp/cinema-tuning-YYYYMMDD-HHMMSS/
```

**Выполняет:**
1. Сбор baseline метрик
2. Установка пакетов (fio, iperf3, ethtool, sysstat)
3. Применение sysctl оптимизаций
4. Сетевая оптимизация (ethtool offloading)
5. FIO тесты (read + write на 4K блоках)
6. iperf3 сетевой тест
7. Сбор финальных метрик

---

### `cinema-test-suite-advanced.sh` ⭐ РЕКОМЕНДУЕТСЯ
Расширенные тесты с RAID, большими блоками и реальными сценариями.

```bash
sudo ./scripts/cinema-test-suite-advanced.sh
# ~30 минут, результаты в /tmp/cinema-tuning-advanced-YYYYMMDD-HHMMSS/
```

**Дополнительно к базовому:**
- ✓ Проверка и увеличение file descriptor limits
- ✓ MTU jumbo frames (9000)
- ✓ RAID speed limit параметры
- ✓ FIO тесты на 256K блоках (как кино файлы)
- ✓ Реальный сценарий: concurrent read+write 70/30

---

### `diagnose-server.sh`
Полная система диагностики для troubleshooting.

```bash
sudo ./scripts/diagnose-server.sh > report.txt
```

**Собирает все:**
- CPU, память, диски
- I/O статистику
- RAID статус (если есть)
- Сетевые ошибки и потери
- Top процессы по CPU/Memory
- Текущие sysctl параметры

---

### `network-tuning.sh`
Ручная сетевая оптимизация для конкретного интерфейса.

```bash
sudo ./scripts/network-tuning.sh eth0
# или
sudo ./scripts/network-tuning.sh ens33
```

**Конфигурирует:**
- Offloading (GRO, GSO, TSO)
- Interrupt coalescing
- Ring buffer sizes
- MTU jumbo frames
- RSS distribution между CPU

---

### `raid-tuning.sh`
Настройка RAID параметров для оптимизации.

```bash
sudo ./scripts/raid-tuning.sh
```

**Конфигурирует:**
- Stripe cache размер (2048 KB)
- I/O scheduler для дисков (deadline для HDD, mq-deadline для NVMe)
- Read-ahead параметры

---

## ⚙️ Конфигурация

### `99-performance.conf`
Основной конфиг sysctl параметров.

```bash
# Применить
sudo sysctl -p configs/99-performance.conf

# Или скопировать в /etc/sysctl.d/
sudo cp configs/99-performance.conf /etc/sysctl.d/
sudo sysctl -p
```

**Основные параметры:**

```
TCP буферы:
  net.core.rmem_max = 128MB
  net.core.wmem_max = 128MB
  
Congestion control: BBR (лучше для high-bandwidth)

Dirty pages: 30% (больше буферизации для I/O)

Swappiness: 10 (минимум используем swap)

File descriptors: 2,097,152 (достаточно для большого количества соединений)

RAID speed limits: 100-200 Mbps (не замораживает систему)
```

---

## 🧪 Тестирование

### Локальное (на одной машине)

```bash
# Базовые тесты (4K блоки)
sudo ./scripts/cinema-test-suite.sh

# Расширенные (4K + 256K + concurrent)
sudo ./scripts/cinema-test-suite-advanced.sh
```

### Multi-server (между двумя машинами)

**На receiver:**
```bash
iperf3 -s -p 5001
```

**На sender:**
```bash
iperf3 -c <receiver-ip> -p 5001 -t 300 -P 4
```

### С реальными кино-файлами

```bash
# Генерируем 50GB тестовый файл
dd if=/dev/zero of=test-movie-50gb.raw bs=1M count=51200 &

# Запускаем мониторинг
watch -n 1 'iostat -x | grep sda'

# В другом терминале: копируем файл
cp test-movie-50gb.raw /mnt/raid/

# Смотрим что происходит с дисками, памятью, CPU
```

---

## 📊 Результаты

### На виртуальной машине (Ubuntu 26.04, 4 CPU, 7.2GB RAM)

#### Baseline:
```
TCP buffers: 4 MB
Congestion control: cubic
Dirty ratio: 20%
Swappiness: 60
```

#### После оптимизации:
```
TCP buffers: 128 MB (↑ 32x)
Congestion control: bbr
Dirty ratio: 30%
Swappiness: 10
```

#### I/O Performance:
```
4K блоки (read):
  - IOPS: 245,000 ops/sec
  - Throughput: 957 MB/s
  - Latency: 50µs median

256K блоки (кино файлы, read):
  - Throughput: ~900-1000 MB/s
  - Latency: ~1-2 ms

Concurrent read+write (70/30):
  - Read: ~700 MB/s
  - Write: ~200 MB/s
```

#### Network:
```
iperf3 (localhost): 17.1 Gbits/sec
Real network (1Gbps): ~120 MB/s
```

---

## 🚀 Production Deployment

### 1. Подготовка

```bash
# Снимаем baseline на каждом сервере
for server in cinema{1..10}; do
  ssh $server 'sudo ./scripts/baseline-diagnostics.sh'
done
```

### 2. Применение с Ansible

```bash
# Отредактировать inventory
vim inventory.ini

# Dry-run перед боевым применением
ansible-playbook -i inventory.ini playbook.yml --check

# Применить ко всем
ansible-playbook -i inventory.ini playbook.yml

# Проверить результаты
ansible cinema_servers -i inventory.ini -m shell -a 'sysctl net.core.rmem_max'
```

### 3. Проверка на боевых серверах

```bash
# Запустить диагностику
sudo ./scripts/cinema-test-suite-advanced.sh

# Проверить RAID (если используется)
cat /proc/mdstat
mdadm --detail /dev/md0

# Мониторить во время работы
dstat -tcs --disk --net 5

# Ночью: проверить на потребление ресурсов
iotop -b -o -d 5 > iotop-report.txt &
```

### 4. Мониторинг в Production

```bash
# Системный cron для периодической диагностики
0 */6 * * * root /usr/local/bin/cinema-diagnostics.sh >> /var/log/cinema-tuning.log 2>&1

# Или через Prometheus + Grafana для реал-тайм мониторинга
# Смотри docs/MONITORING.md (когда добавим)
```

---

## 📚 Документация

- **[TUNING-GUIDE.md](docs/TUNING-GUIDE.md)** — Подробный гайд по каждому параметру
- **[RAID-SETUP.md](docs/RAID-SETUP.md)** — Настройка RAID 1/5/6 для кино
- **[NETWORK-OPTIMIZATION.md](docs/NETWORK-OPTIMIZATION.md)** — Оптимизация сетевого стека
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** — Решение типичных проблем

---

## 🐛 Troubleshooting

### Медленное скачивание фильмов
1. Проверь `iostat -x` — util близко к 100%?
2. Запусти `./scripts/diagnose-server.sh`
3. Смотри `docs/TROUBLESHOOTING.md`

### Зависания системы во время I/O
1. Проверь `vm.dirty_ratio` (должен быть 30%)
2. Проверь RAID resync speed
3. Используй `blktrace` для анализа

### Потери пакетов в сети
1. Проверь `ethtool -S eth0` на ошибки
2. Увеличь MTU на 9000 (если поддерживает)
3. Проверь `netstat -s` на dropped packets

---

## 🤝 Для контрибьюторов

Если ты тестировал на других системах (CentOS, Rocky, Alma) или нашёл улучшения:

1. Fork репозиторий
2. Создай ветку: `git checkout -b improvement/your-feature`
3. Commit: `git commit -m 'Add: description'`
4. Push: `git push origin improvement/your-feature`
5. Открой Pull Request
<<<<<<< HEAD
=======

---

## 🔗 Полезные ссылки

- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/)
- [FIO - Flexible I/O Tester](https://fio.readthedocs.io/)
- [iperf3 - Network Testing Tool](https://iperf.fr/)
- [ethtool - Linux Network Interface Tool](https://man7.org/linux/man-pages/man8/ethtool.8.html)
- [mdadm - RAID Management](https://raid.wiki.kernel.org/index.php/Main_Page)
- [BBR Congestion Control](https://github.com/google/bbr)
- [sysctl Manual](https://man7.org/linux/man-pages/man8/sysctl.8.html)
>>>>>>> 77dcf6a (Add: master tuning script, comprehensive TUNING-GUIDE, update README)
