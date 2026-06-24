# 🎮 Zapret на Raspberry Pi 4 для PS5 — Полный гайд

## Содержание
- [Архитектура решения](#архитектура-решения)
- [Часть 1: Подготовка Raspberry Pi](#часть-1-подготовка-raspberry-pi)
- [Часть 2: Установка Zapret](#часть-2-установка-zapret)
- [Часть 3: Настройка как шлюза для PS5](#часть-3-настройка-raspberry-pi-как-шлюза)
- [Часть 4: Стратегии для EA серверов](#часть-4-стратегии-для-ea-серверов)
- [Часть 5: Веб-интерфейс](#часть-5-веб-интерфейс-управления)
- [Часть 6: Настройка PS5](#часть-6-настройка-ps5)
- [Часть 7: Доступ для друзей](#часть-7-доступ-для-друзей)
- [Часть 8: Диагностика](#часть-8-диагностика-и-проверка)
- [План Б](#план-б-альтернативные-решения)

---

## Архитектура решения

```
┌──────────────┐     ┌─────────────────────────┐     ┌──────────┐
│   PS5        │────▶│  Raspberry Pi 4 (шлюз)  │────▶│  Роутер  │──▶ Интернет
│ 192.168.1.50 │     │  192.168.1.10           │     │ .1.1     │
└──────────────┘     │  ├ nfqws (DPI bypass)    │     └──────────┘
                     │  ├ iptables (NAT/forward)│
┌──────────────┐     │  ├ nginx (веб-панель)    │
│ PS5 друга    │────▶│  └ dnsmasq (DHCP/DNS)    │
│ 192.168.1.51 │     └─────────────────────────┘
└──────────────┘
```

> [!IMPORTANT]
> Raspberry Pi 4 подключается к роутеру **по Ethernet** (eth0). PS5 так же подключается к роутеру по Ethernet или WiFi. RPi выступает **шлюзом** (gateway) для PS5 — весь трафик PS5 проходит через RPi, где zapret обрабатывает его.

---

## Часть 1: Подготовка Raspberry Pi

### 1.1 Обновление системы

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

### 1.2 Установка необходимых пакетов

```bash
sudo apt install -y git make gcc libc-dev libnetfilter-queue-dev \
  libcap-dev zlib1g-dev iptables nftables conntrack \
  curl wget dnsutils net-tools nginx fcgiwrap python3 python3-pip \
  jq ethtool procps
```

### 1.3 Назначение статического IP

Отредактируй файл конфигурации сети:

```bash
sudo nano /etc/dhcpcd.conf
```

Добавь в конец файла:

```ini
# Статический IP для Raspberry Pi
interface eth0
static ip_address=192.168.1.10/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4 1.1.1.1
```

> [!NOTE]
> Замени `192.168.1.1` на IP твоего роутера, а `192.168.1.10` на желаемый IP для RPi. Убедись, что этот IP не занят другими устройствами.

```bash
sudo reboot
```

После перезагрузки проверь:

```bash
ip addr show eth0
# Должен показать 192.168.1.10/24
```

### 1.4 Включение IP Forwarding

```bash
# Включить маршрутизацию пакетов
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.d/99-zapret.conf
echo "net.netfilter.nf_conntrack_checksum=0" | sudo tee -a /etc/sysctl.d/99-zapret.conf
echo "net.netfilter.nf_conntrack_tcp_be_liberal=1" | sudo tee -a /etc/sysctl.d/99-zapret.conf

sudo sysctl -p /etc/sysctl.d/99-zapret.conf
```

---

## Часть 2: Установка Zapret

### 2.1 Клонирование и сборка

```bash
cd /opt
sudo git clone https://github.com/bol-van/zapret.git
cd /opt/zapret

# Установка зависимостей
sudo ./install_prereq.sh

# Сборка бинарников для ARM (Raspberry Pi)
sudo make

# Установка бинарников
sudo ./install_bin.sh

# Проверка, что бинарник собрался
ls -la /opt/zapret/nfq/nfqws
# или после install_bin.sh:
which nfqws 2>/dev/null || ls /opt/zapret/nfq/nfqws
```

### 2.2 Создание файла конфигурации

```bash
sudo cp /opt/zapret/config.default /opt/zapret/config
sudo nano /opt/zapret/config
```

Содержимое `/opt/zapret/config`:

```bash
# Zapret Configuration for PS5 / EA Servers DPI Bypass
# ====================================================

# Режим работы: nfqws (netfilter queue)
MODE=nfqws

# Режим фильтрации: не использовать hostlist, обрабатывать весь трафик
MODE_FILTER=none

# Внешний сетевой интерфейс (к роутеру/интернету)
IFACE_WAN=eth0

# Не запускать tpws
TPWS_ENABLE=0

# Включить nfqws
NFQWS_ENABLE=1

# Порты для обработки (443 — HTTPS, 80 — HTTP)
# EA серверы используют преимущественно HTTPS (443)
NFQWS_PORTS_TCP="80,443"
NFQWS_PORTS_UDP="443"

# Номер очереди nfqueue
NFQWS_QUEUE_NUM=200

# Параметры nfqws — основная стратегия для обхода DPI
# Стратегия 1: fake + fakedsplit с md5sig fooling (наиболее универсальная)
NFQWS_OPT="
--filter-tcp=80,443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig \
--dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 \
--dpi-desync-fake-tls-mod=rnd,rndsni,dupsid \
--dpi-desync-ttl=5 --dpi-desync-autottl=2 \
--new \
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 \
--dpi-desync-fake-quic=/opt/zapret/files/fake/quic_initial_www_google_com.bin
"
```

### 2.3 Создание списка доменов EA (опционально)

Если хочешь обрабатывать только трафик к серверам EA:

```bash
sudo mkdir -p /opt/zapret/ipset
sudo nano /opt/zapret/ipset/zapret-hosts-user.txt
```

Содержимое:

```
# EA / Electronic Arts серверы
ea.com
eafc.com
origin.com
accounts.ea.com
signin.ea.com
gateway.ea.com
river.data.ea.com
pin-river.data.ea.com
reports.data.ea.com
telemetry.ea.com
battlefield.com
battlefield.ea.com
frostbite.com
eaassets-a.akamaihd.net
ssl.cdn.ea.com
media.contentapi.ea.com
bfrr-prod-envoy-traffic.ea.com
# PlayStation Network (если нужно)
playstation.net
playstation.com
sonyentertainmentnetwork.com
# Общие CDN которые используют EA
akamaihd.net
cloudfront.net
```

> [!TIP]
> На практике для PS5 лучше работать **без hostlist** (обрабатывать весь трафик), т.к. PS5 часто обращается к серверам по IP напрямую, а не по доменному имени. Hostlist работает только для TLS SNI и HTTP Host.

### 2.4 Запуск через install_easy.sh (установка как сервис)

```bash
cd /opt/zapret
sudo ./install_easy.sh
```

Скрипт задаст вопросы:
1. **Roles** → выбери `roles: nfqws`  
2. **Interface** → выбери `eth0`
3. Остальное — по умолчанию

После установки zapret будет запускаться автоматически при старте системы.

### 2.5 Ручной запуск (для тестирования)

Если хочешь запустить вручную для отладки:

```bash
# Остановить системный сервис (если установлен)
sudo systemctl stop zapret

# Запустить в режиме отладки
sudo /opt/zapret/nfq/nfqws \
  --qnum=200 \
  --debug=1 \
  --dpi-desync=fake,fakedsplit \
  --dpi-desync-fooling=md5sig \
  --dpi-desync-split-pos=1,midsld \
  --dpi-desync-split-seqovl=2 \
  --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid \
  --dpi-desync-ttl=5 \
  --dpi-desync-autottl=2 \
  --dpi-desync-any-protocol
```

---

## Часть 3: Настройка Raspberry Pi как шлюза

Это ключевая часть — нужно сделать так, чтобы трафик PS5 проходил через RPi.

### 3.1 Настройка NAT и маршрутизации

Создай скрипт настройки:

```bash
sudo nano /opt/zapret/gateway-setup.sh
```

Содержимое:

```bash
#!/bin/bash
# ============================================================
# Raspberry Pi 4 Gateway Setup for PS5 + Zapret
# ============================================================

IFACE_WAN="eth0"         # Интерфейс к роутеру/интернету
ROUTER_IP="192.168.1.1"  # IP роутера
RPI_IP="192.168.1.10"    # IP Raspberry Pi
QUEUE_NUM=200

echo "=== Настройка шлюза для PS5 ==="

# 1. Включить IP forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.netfilter.nf_conntrack_checksum=0
sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=1

# 2. Очистить старые правила
iptables -t nat -F
iptables -t mangle -F
iptables -F FORWARD

# 3. NAT (маскарадинг) — позволяет PS5 выходить в интернет через RPi
iptables -t nat -A POSTROUTING -o $IFACE_WAN -j MASQUERADE

# 4. Разрешить forwarding
iptables -A FORWARD -i $IFACE_WAN -o $IFACE_WAN -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $IFACE_WAN -o $IFACE_WAN -j ACCEPT

# 5. NFQUEUE правила для проходящего трафика (FORWARD)
# TCP — первые 12 пакетов каждого соединения на порты 80,443
iptables -t mangle -A POSTROUTING -p tcp -m multiport --dports 80,443 \
  -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:12 \
  -m mark ! --mark 0x40000000/0x40000000 \
  -j NFQUEUE --queue-num $QUEUE_NUM --queue-bypass

# UDP — порт 443 (QUIC)
iptables -t mangle -A POSTROUTING -p udp --dport 443 \
  -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:6 \
  -m mark ! --mark 0x40000000/0x40000000 \
  -j NFQUEUE --queue-num $QUEUE_NUM --queue-bypass

# 6. Входящие ответы (для autottl и autohostlist)
iptables -t mangle -A PREROUTING -p tcp -m multiport --sports 80,443 \
  -m connbytes --connbytes-dir=reply --connbytes-mode=packets --connbytes 1:6 \
  -m mark ! --mark 0x40000000/0x40000000 \
  -j NFQUEUE --queue-num $QUEUE_NUM --queue-bypass

# 7. Дополнительно: порты EA серверов (некоторые EA сервисы используют нестандартные порты)
# TCP порты 3216, 3659, 10000-10100, 17503, 17504, 42127
iptables -t mangle -A POSTROUTING -p tcp -m multiport --dports 3216,3659,17503,17504 \
  -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:12 \
  -m mark ! --mark 0x40000000/0x40000000 \
  -j NFQUEUE --queue-num $QUEUE_NUM --queue-bypass

# UDP порты для EA (Battlefield и FIFA используют UDP для геймплея)
iptables -t mangle -A POSTROUTING -p udp -m multiport --dports 3659,14000:14016 \
  -m connbytes --connbytes-dir=original --connbytes-mode=packets --connbytes 1:6 \
  -m mark ! --mark 0x40000000/0x40000000 \
  -j NFQUEUE --queue-num $QUEUE_NUM --queue-bypass

echo "=== Шлюз настроен ==="
echo "PS5 gateway: $RPI_IP"
echo "Роутер: $ROUTER_IP"
iptables -t nat -L -n -v | head -20
iptables -t mangle -L -n -v | head -30
```

```bash
sudo chmod +x /opt/zapret/gateway-setup.sh
sudo /opt/zapret/gateway-setup.sh
```

### 3.2 Автозапуск шлюза при загрузке

```bash
sudo nano /etc/systemd/system/zapret-gateway.service
```

Содержимое:

```ini
[Unit]
Description=Zapret Gateway Setup for PS5
After=network-online.target zapret.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/opt/zapret/gateway-setup.sh
ExecStop=/sbin/iptables -t nat -F
ExecStop=/sbin/iptables -t mangle -F

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable zapret-gateway
sudo systemctl start zapret-gateway
```

---

## Часть 4: Стратегии для EA серверов

EA серверы (Battlefield, FIFA/EA FC, Apex Legends и др.) используют TLS и иногда собственные протоколы. DPI обычно блокирует по SNI в TLS ClientHello.

### Стратегия 1: Универсальная (рекомендуемая для начала)

```bash
# Основная стратегия: fake + split с md5sig
NFQWS_ARGS="--qnum=200 \
  --dpi-desync=fake,fakedsplit \
  --dpi-desync-fooling=md5sig \
  --dpi-desync-split-pos=1,midsld \
  --dpi-desync-split-seqovl=2 \
  --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid \
  --dpi-desync-any-protocol"
```

### Стратегия 2: С TTL fooling (если md5sig не помогает)

```bash
# TTL fooling - нужно подобрать TTL (обычно от 4 до 12)
NFQWS_ARGS="--qnum=200 \
  --dpi-desync=fake,multidisorder \
  --dpi-desync-fooling=md5sig,badseq \
  --dpi-desync-split-pos=midsld \
  --dpi-desync-split-seqovl=2 \
  --dpi-desync-ttl=6 \
  --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid \
  --dpi-desync-any-protocol"
```

### Стратегия 3: fakeddisorder (продвинутая)

```bash
NFQWS_ARGS="--qnum=200 \
  --dpi-desync=fake,fakeddisorder \
  --dpi-desync-fooling=md5sig \
  --dpi-desync-split-pos=1,midsld \
  --dpi-desync-split-seqovl=3 \
  --dpi-desync-repeats=6 \
  --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid \
  --dpi-desync-any-protocol \
  --dpi-desync-fakedsplit-mod=altorder=1"
```

### Стратегия 4: hostfakesplit (минимальное вмешательство)

```bash
NFQWS_ARGS="--qnum=200 \
  --dpi-desync=fake,hostfakesplit \
  --dpi-desync-fooling=md5sig \
  --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid \
  --dpi-desync-any-protocol"
```

### Как подобрать стратегию с помощью blockcheck

```bash
cd /opt/zapret

# Запусти тест на конкретном домене EA
sudo ./blockcheck.sh

# Скрипт будет перебирать стратегии и покажет,
# какая работает для вашего провайдера
# Укажи домен: accounts.ea.com или gateway.ea.com
```

> [!IMPORTANT]
> Результат `blockcheck.sh` будет содержать рабочие параметры конкретно для вашего провайдера. Скопируй их и вставь в конфиг. Каждый провайдер использует разные DPI, поэтому универсальной стратегии не существует — нужно тестировать.

### Применение выбранной стратегии

После определения рабочей стратегии через `blockcheck.sh`, обнови `/opt/zapret/config`:

```bash
sudo nano /opt/zapret/config
```

Замени параметры `NFQWS_OPT` на найденные через blockcheck, затем:

```bash
sudo systemctl restart zapret
```

---

## Часть 5: Веб-интерфейс управления

### 5.1 Backend API (Python Flask)

```bash
sudo pip3 install flask --break-system-packages 2>/dev/null || sudo pip3 install flask
```

Создай API-сервер:

```bash
sudo mkdir -p /opt/zapret-web
sudo nano /opt/zapret-web/api.py
```

Содержимое `/opt/zapret-web/api.py`:

```python
#!/usr/bin/env python3
"""
Zapret Web Control Panel — Backend API
Manages zapret service, strategies, and status
"""

import subprocess
import json
import os
import re
from datetime import datetime
from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__, static_folder='/opt/zapret-web/static')

ZAPRET_DIR = '/opt/zapret'
CONFIG_FILE = f'{ZAPRET_DIR}/config'
STRATEGIES_FILE = '/opt/zapret-web/strategies.json'
LOG_FILE = '/var/log/zapret-web.log'

# Предустановленные стратегии
DEFAULT_STRATEGIES = {
    "universal_md5sig": {
        "name": "Универсальная (md5sig)",
        "description": "Fake + FakedSplit с MD5 Signature fooling. Работает на большинстве провайдеров.",
        "args": "--dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol"
    },
    "ttl_based": {
        "name": "TTL-based (подбор TTL)",
        "description": "Используй TTL fooling с подбором hop count (4-12).",
        "args": "--dpi-desync=fake,multidisorder --dpi-desync-fooling=md5sig,badseq --dpi-desync-split-pos=midsld --dpi-desync-split-seqovl=2 --dpi-desync-ttl=6 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol"
    },
    "fakeddisorder": {
        "name": "FakedDisorder (продвинутая)",
        "description": "Перемешивание фейков с оригиналами в обратном порядке.",
        "args": "--dpi-desync=fake,fakeddisorder --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=3 --dpi-desync-repeats=6 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol --dpi-desync-fakedsplit-mod=altorder=1"
    },
    "hostfakesplit": {
        "name": "HostFakeSplit (минимальная)",
        "description": "Минимальное вмешательство — фейкование только hostname.",
        "args": "--dpi-desync=fake,hostfakesplit --dpi-desync-fooling=md5sig --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol"
    },
    "multisplit_seqovl": {
        "name": "MultiSplit + SeqOvl",
        "description": "Множественная нарезка с перекрытием sequence numbers.",
        "args": "--dpi-desync=fake,multisplit --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=5 --dpi-desync-split-seqovl-pattern=0x1603030000 --dpi-desync-fake-tls-mod=rnd,rndsni,dupsid --dpi-desync-any-protocol"
    }
}


def log_action(action):
    """Log action to file"""
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(f"[{datetime.now().isoformat()}] {action}\n")
    except:
        pass


def run_cmd(cmd, timeout=10):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout
        )
        return result.stdout.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "Command timed out", 1
    except Exception as e:
        return str(e), 1


def get_zapret_status():
    """Get current zapret service status"""
    stdout, rc = run_cmd("systemctl is-active zapret")
    is_active = stdout == "active"
    
    # Get nfqws process info
    ps_out, _ = run_cmd("ps aux | grep nfqws | grep -v grep")
    
    # Get current strategy from running process
    current_args = ""
    if ps_out:
        match = re.search(r'nfqws\s+(.*)', ps_out)
        if match:
            current_args = match.group(1)
    
    # Get uptime
    uptime_out, _ = run_cmd(
        "systemctl show zapret --property=ActiveEnterTimestamp --value"
    )
    
    return {
        "active": is_active,
        "status": stdout,
        "process": ps_out if ps_out else "Not running",
        "current_args": current_args,
        "uptime_since": uptime_out
    }


def load_strategies():
    """Load saved strategies"""
    if os.path.exists(STRATEGIES_FILE):
        with open(STRATEGIES_FILE, 'r') as f:
            return json.load(f)
    return DEFAULT_STRATEGIES


def save_strategies(strategies):
    """Save strategies to file"""
    with open(STRATEGIES_FILE, 'w') as f:
        json.dump(strategies, f, indent=2, ensure_ascii=False)


# ===================== API Routes =====================

@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')


@app.route('/api/status')
def api_status():
    """Get zapret status + system info"""
    status = get_zapret_status()
    
    # System info
    cpu_out, _ = run_cmd("cat /proc/loadavg")
    mem_out, _ = run_cmd("free -m | awk 'NR==2{printf \"%s/%s MB (%.1f%%)\", $3,$2,$3*100/$2}'")
    temp_out, _ = run_cmd("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null")
    temp = f"{int(temp_out)//1000}°C" if temp_out.isdigit() else "N/A"
    
    # Network stats
    net_out, _ = run_cmd(
        "cat /proc/net/dev | grep eth0 | awk '{printf \"RX: %.1f MB, TX: %.1f MB\", $2/1048576, $10/1048576}'"
    )
    
    # Connected clients (ARP table)
    clients_out, _ = run_cmd("arp -n -i eth0 | grep -v incomplete | tail -n +2")
    clients = []
    if clients_out:
        for line in clients_out.split('\n'):
            parts = line.split()
            if len(parts) >= 3:
                clients.append({"ip": parts[0], "mac": parts[2]})
    
    return jsonify({
        "zapret": status,
        "system": {
            "cpu_load": cpu_out,
            "memory": mem_out,
            "temperature": temp,
            "network": net_out
        },
        "clients": clients
    })


@app.route('/api/start', methods=['POST'])
def api_start():
    """Start zapret service"""
    _, rc = run_cmd("sudo systemctl start zapret")
    log_action("Zapret started via web UI")
    return jsonify({"success": rc == 0, "message": "Zapret started" if rc == 0 else "Failed to start"})


@app.route('/api/stop', methods=['POST'])
def api_stop():
    """Stop zapret service"""
    _, rc = run_cmd("sudo systemctl stop zapret")
    log_action("Zapret stopped via web UI")
    return jsonify({"success": rc == 0, "message": "Zapret stopped" if rc == 0 else "Failed to stop"})


@app.route('/api/restart', methods=['POST'])
def api_restart():
    """Restart zapret service"""
    _, rc = run_cmd("sudo systemctl restart zapret")
    log_action("Zapret restarted via web UI")
    return jsonify({"success": rc == 0, "message": "Zapret restarted" if rc == 0 else "Failed to restart"})


@app.route('/api/strategies')
def api_get_strategies():
    """Get all available strategies"""
    strategies = load_strategies()
    return jsonify(strategies)


@app.route('/api/strategies', methods=['POST'])
def api_save_strategy():
    """Save a new custom strategy"""
    data = request.json
    strategies = load_strategies()
    key = data.get('key', f"custom_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
    strategies[key] = {
        "name": data['name'],
        "description": data.get('description', ''),
        "args": data['args']
    }
    save_strategies(strategies)
    log_action(f"Strategy saved: {data['name']}")
    return jsonify({"success": True, "key": key})


@app.route('/api/strategies/<key>', methods=['DELETE'])
def api_delete_strategy(key):
    """Delete a strategy"""
    strategies = load_strategies()
    if key in strategies:
        del strategies[key]
        save_strategies(strategies)
        log_action(f"Strategy deleted: {key}")
        return jsonify({"success": True})
    return jsonify({"success": False, "message": "Strategy not found"}), 404


@app.route('/api/apply-strategy', methods=['POST'])
def api_apply_strategy():
    """Apply a strategy by updating config and restarting zapret"""
    data = request.json
    args = data.get('args', '')
    
    if not args:
        return jsonify({"success": False, "message": "No strategy args provided"}), 400
    
    # Read current config
    try:
        with open(CONFIG_FILE, 'r') as f:
            config_content = f.read()
    except FileNotFoundError:
        return jsonify({"success": False, "message": "Config file not found"}), 500
    
    # Update NFQWS_OPT in config
    # Simple replacement - find NFQWS_OPT line and replace
    new_opt = f'NFQWS_OPT="\n{args}\n"'
    
    if 'NFQWS_OPT=' in config_content:
        # Replace existing NFQWS_OPT (handle multiline)
        config_content = re.sub(
            r'NFQWS_OPT="[^"]*"',
            new_opt,
            config_content,
            flags=re.DOTALL
        )
    else:
        config_content += f'\n{new_opt}\n'
    
    with open(CONFIG_FILE, 'w') as f:
        f.write(config_content)
    
    # Restart zapret
    _, rc = run_cmd("sudo systemctl restart zapret")
    log_action(f"Strategy applied: {args[:80]}...")
    
    return jsonify({
        "success": rc == 0,
        "message": "Strategy applied and zapret restarted" if rc == 0 else "Strategy saved but restart failed"
    })


@app.route('/api/logs')
def api_logs():
    """Get recent zapret logs"""
    # Try systemd journal first
    stdout, _ = run_cmd("journalctl -u zapret --no-pager -n 100 --output=short-iso")
    if not stdout:
        stdout, _ = run_cmd("tail -100 /var/log/syslog | grep -i nfqws")
    return jsonify({"logs": stdout})


@app.route('/api/blockcheck', methods=['POST'])
def api_blockcheck():
    """Run blockcheck for a domain (async — returns immediately)"""
    data = request.json
    domain = data.get('domain', 'accounts.ea.com')
    
    # Sanitize domain
    domain = re.sub(r'[^a-zA-Z0-9.-]', '', domain)
    
    log_file = '/tmp/blockcheck_result.txt'
    run_cmd(f"nohup /opt/zapret/blockcheck.sh > {log_file} 2>&1 &")
    
    return jsonify({
        "success": True,
        "message": f"Blockcheck started for {domain}. Check results at /api/blockcheck-result"
    })


@app.route('/api/blockcheck-result')
def api_blockcheck_result():
    """Get blockcheck results"""
    log_file = '/tmp/blockcheck_result.txt'
    if os.path.exists(log_file):
        with open(log_file, 'r') as f:
            return jsonify({"result": f.read()})
    return jsonify({"result": "No results yet. Run blockcheck first."})


@app.route('/api/gateway-status')
def api_gateway_status():
    """Get gateway/NAT status"""
    # iptables NAT rules
    nat_out, _ = run_cmd("iptables -t nat -L -n --line-numbers")
    # iptables mangle rules
    mangle_out, _ = run_cmd("iptables -t mangle -L -n --line-numbers")
    # IP forwarding status
    forward_out, _ = run_cmd("sysctl net.ipv4.ip_forward")
    
    return jsonify({
        "nat_rules": nat_out,
        "mangle_rules": mangle_out,
        "ip_forward": forward_out
    })


if __name__ == '__main__':
    # Initialize strategies file
    if not os.path.exists(STRATEGIES_FILE):
        save_strategies(DEFAULT_STRATEGIES)
    
    app.run(host='0.0.0.0', port=8080, debug=False)
```

### 5.2 Frontend (HTML/CSS/JS)

```bash
sudo mkdir -p /opt/zapret-web/static
sudo nano /opt/zapret-web/static/index.html
```

Содержимое `/opt/zapret-web/static/index.html`:

```html
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Zapret Control Panel — PS5 DPI Bypass</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-primary: #0a0e1a;
            --bg-card: rgba(16, 23, 42, 0.85);
            --bg-card-hover: rgba(20, 28, 50, 0.95);
            --accent: #6366f1;
            --accent-glow: rgba(99, 102, 241, 0.3);
            --success: #22c55e;
            --danger: #ef4444;
            --warning: #f59e0b;
            --text-primary: #e2e8f0;
            --text-secondary: #94a3b8;
            --border: rgba(99, 102, 241, 0.15);
            --radius: 16px;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Inter', sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            min-height: 100vh;
            background-image:
                radial-gradient(ellipse at 20% 0%, rgba(99, 102, 241, 0.08) 0%, transparent 50%),
                radial-gradient(ellipse at 80% 100%, rgba(139, 92, 246, 0.06) 0%, transparent 50%);
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 24px;
        }

        header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 20px 0 32px;
        }

        .logo {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .logo-icon {
            width: 42px;
            height: 42px;
            background: linear-gradient(135deg, #6366f1, #8b5cf6);
            border-radius: 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            box-shadow: 0 4px 20px var(--accent-glow);
        }

        .logo h1 {
            font-size: 22px;
            font-weight: 700;
            background: linear-gradient(135deg, #e2e8f0, #a5b4fc);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .logo small {
            font-size: 12px;
            color: var(--text-secondary);
            font-weight: 400;
        }

        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            border-radius: 100px;
            font-size: 13px;
            font-weight: 600;
            backdrop-filter: blur(10px);
        }

        .status-badge.active {
            background: rgba(34, 197, 94, 0.15);
            color: var(--success);
            border: 1px solid rgba(34, 197, 94, 0.3);
        }

        .status-badge.inactive {
            background: rgba(239, 68, 68, 0.15);
            color: var(--danger);
            border: 1px solid rgba(239, 68, 68, 0.3);
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }

        .active .status-dot { background: var(--success); }
        .inactive .status-dot { background: var(--danger); }

        @keyframes pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.5; transform: scale(0.8); }
        }

        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; margin-bottom: 24px; }

        .card {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 24px;
            backdrop-filter: blur(20px);
            transition: all 0.3s ease;
        }

        .card:hover {
            background: var(--bg-card-hover);
            border-color: rgba(99, 102, 241, 0.3);
            transform: translateY(-2px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        }

        .card-title {
            font-size: 13px;
            font-weight: 500;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 12px;
        }

        .card-value {
            font-size: 28px;
            font-weight: 700;
        }

        .card-sub {
            font-size: 12px;
            color: var(--text-secondary);
            margin-top: 4px;
        }

        .controls {
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            margin-bottom: 24px;
        }

        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 12px;
            font-family: 'Inter', sans-serif;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .btn-primary {
            background: linear-gradient(135deg, #6366f1, #8b5cf6);
            color: white;
            box-shadow: 0 4px 16px var(--accent-glow);
        }

        .btn-primary:hover:not(:disabled) {
            box-shadow: 0 6px 24px rgba(99, 102, 241, 0.5);
            transform: translateY(-1px);
        }

        .btn-success {
            background: linear-gradient(135deg, #22c55e, #16a34a);
            color: white;
        }

        .btn-danger {
            background: linear-gradient(135deg, #ef4444, #dc2626);
            color: white;
        }

        .btn-outline {
            background: transparent;
            color: var(--text-primary);
            border: 1px solid var(--border);
        }

        .btn-outline:hover:not(:disabled) {
            background: rgba(99, 102, 241, 0.1);
            border-color: var(--accent);
        }

        .section-title {
            font-size: 18px;
            font-weight: 700;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .strategies-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }

        .strategy-card {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 20px;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }

        .strategy-card:hover {
            border-color: var(--accent);
            box-shadow: 0 4px 24px rgba(99, 102, 241, 0.15);
        }

        .strategy-card.active-strategy {
            border-color: var(--success);
            box-shadow: 0 0 20px rgba(34, 197, 94, 0.1);
        }

        .strategy-card.active-strategy::before {
            content: '✓ АКТИВНА';
            position: absolute;
            top: 12px;
            right: 12px;
            background: rgba(34, 197, 94, 0.2);
            color: var(--success);
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 700;
        }

        .strategy-name {
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 6px;
        }

        .strategy-desc {
            font-size: 13px;
            color: var(--text-secondary);
            margin-bottom: 14px;
            line-height: 1.5;
        }

        .strategy-args {
            background: rgba(0, 0, 0, 0.3);
            padding: 10px 14px;
            border-radius: 8px;
            font-family: 'JetBrains Mono', 'Fira Code', monospace;
            font-size: 11px;
            color: #a5b4fc;
            word-break: break-all;
            max-height: 80px;
            overflow-y: auto;
            margin-bottom: 14px;
        }

        .strategy-actions {
            display: flex;
            gap: 8px;
        }

        .strategy-actions .btn { padding: 8px 16px; font-size: 12px; }

        .logs-container {
            background: rgba(0, 0, 0, 0.4);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 20px;
            max-height: 400px;
            overflow-y: auto;
            margin-bottom: 24px;
        }

        .logs-content {
            font-family: 'JetBrains Mono', 'Fira Code', monospace;
            font-size: 12px;
            line-height: 1.8;
            color: #94a3b8;
            white-space: pre-wrap;
        }

        .clients-table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
        }

        .clients-table th {
            text-align: left;
            padding: 12px 16px;
            font-size: 12px;
            font-weight: 600;
            color: var(--text-secondary);
            text-transform: uppercase;
            border-bottom: 1px solid var(--border);
        }

        .clients-table td {
            padding: 12px 16px;
            font-size: 14px;
            border-bottom: 1px solid rgba(99, 102, 241, 0.05);
        }

        .modal-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0, 0, 0, 0.6);
            backdrop-filter: blur(4px);
            z-index: 1000;
            align-items: center;
            justify-content: center;
        }

        .modal-overlay.show { display: flex; }

        .modal {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: var(--radius);
            padding: 32px;
            width: 90%;
            max-width: 560px;
            backdrop-filter: blur(20px);
        }

        .modal h3 { margin-bottom: 20px; }

        .form-group { margin-bottom: 16px; }

        .form-group label {
            display: block;
            font-size: 13px;
            font-weight: 500;
            color: var(--text-secondary);
            margin-bottom: 6px;
        }

        .form-group input,
        .form-group textarea {
            width: 100%;
            padding: 12px 16px;
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid var(--border);
            border-radius: 10px;
            color: var(--text-primary);
            font-family: 'Inter', sans-serif;
            font-size: 14px;
            outline: none;
            transition: border-color 0.3s;
        }

        .form-group textarea {
            font-family: 'JetBrains Mono', 'Fira Code', monospace;
            font-size: 12px;
            min-height: 100px;
            resize: vertical;
        }

        .form-group input:focus,
        .form-group textarea:focus {
            border-color: var(--accent);
        }

        .modal-actions {
            display: flex;
            justify-content: flex-end;
            gap: 12px;
            margin-top: 24px;
        }

        .tabs { display: flex; gap: 4px; margin-bottom: 24px; background: rgba(0,0,0,0.2); border-radius: 12px; padding: 4px; }

        .tab {
            padding: 10px 20px;
            border: none;
            background: none;
            color: var(--text-secondary);
            font-family: 'Inter', sans-serif;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            border-radius: 8px;
            transition: all 0.3s;
        }

        .tab.active {
            background: var(--accent);
            color: white;
        }

        .tab-content { display: none; }
        .tab-content.active { display: block; }

        .toast {
            position: fixed;
            bottom: 24px;
            right: 24px;
            padding: 14px 24px;
            border-radius: 12px;
            font-size: 14px;
            font-weight: 500;
            z-index: 2000;
            transform: translateY(100px);
            opacity: 0;
            transition: all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
        }

        .toast.show { transform: translateY(0); opacity: 1; }
        .toast.success { background: rgba(34, 197, 94, 0.9); color: white; }
        .toast.error { background: rgba(239, 68, 68, 0.9); color: white; }
        .toast.info { background: rgba(99, 102, 241, 0.9); color: white; }

        @media (max-width: 768px) {
            .container { padding: 16px; }
            .grid { grid-template-columns: 1fr; }
            .strategies-list { grid-template-columns: 1fr; }
            header { flex-direction: column; gap: 16px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="logo">
                <div class="logo-icon">🛡️</div>
                <div>
                    <h1>Zapret Control Panel</h1>
                    <small>PS5 DPI Bypass — Raspberry Pi 4</small>
                </div>
            </div>
            <div id="statusBadge" class="status-badge inactive">
                <span class="status-dot"></span>
                <span id="statusText">Загрузка...</span>
            </div>
        </header>

        <!-- System Info Cards -->
        <div class="grid">
            <div class="card">
                <div class="card-title">🌡️ Температура CPU</div>
                <div class="card-value" id="cpuTemp">--</div>
            </div>
            <div class="card">
                <div class="card-title">💾 Память</div>
                <div class="card-value" id="memUsage">--</div>
            </div>
            <div class="card">
                <div class="card-title">📊 Нагрузка CPU</div>
                <div class="card-value" id="cpuLoad">--</div>
            </div>
            <div class="card">
                <div class="card-title">🌐 Сетевой трафик</div>
                <div class="card-value" id="netTraffic" style="font-size:18px;">--</div>
            </div>
        </div>

        <!-- Controls -->
        <div class="controls">
            <button class="btn btn-success" onclick="zapretAction('start')">▶ Запустить</button>
            <button class="btn btn-danger" onclick="zapretAction('stop')">⏹ Остановить</button>
            <button class="btn btn-primary" onclick="zapretAction('restart')">🔄 Перезапустить</button>
            <button class="btn btn-outline" onclick="refreshStatus()">📡 Обновить статус</button>
        </div>

        <!-- Tabs -->
        <div class="tabs">
            <button class="tab active" onclick="switchTab('strategies')">⚡ Стратегии</button>
            <button class="tab" onclick="switchTab('clients')">📱 Клиенты</button>
            <button class="tab" onclick="switchTab('logs')">📋 Логи</button>
            <button class="tab" onclick="switchTab('network')">🔧 Сеть</button>
        </div>

        <!-- Strategies Tab -->
        <div id="tab-strategies" class="tab-content active">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:16px;">
                <h2 class="section-title" style="margin:0;">⚡ Стратегии обхода DPI</h2>
                <button class="btn btn-outline" onclick="openAddStrategy()">+ Добавить</button>
            </div>
            <div id="strategiesList" class="strategies-list">
                <!-- Strategies loaded dynamically -->
            </div>
        </div>

        <!-- Clients Tab -->
        <div id="tab-clients" class="tab-content">
            <h2 class="section-title">📱 Подключённые устройства</h2>
            <div class="card">
                <table class="clients-table">
                    <thead><tr><th>IP адрес</th><th>MAC адрес</th><th>Устройство</th></tr></thead>
                    <tbody id="clientsTable">
                        <tr><td colspan="3" style="color:var(--text-secondary)">Загрузка...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Logs Tab -->
        <div id="tab-logs" class="tab-content">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:16px;">
                <h2 class="section-title" style="margin:0;">📋 Логи Zapret</h2>
                <button class="btn btn-outline" onclick="loadLogs()">🔄 Обновить</button>
            </div>
            <div class="logs-container">
                <pre class="logs-content" id="logsContent">Загрузка логов...</pre>
            </div>
        </div>

        <!-- Network Tab -->
        <div id="tab-network" class="tab-content">
            <h2 class="section-title">🔧 Сетевые правила</h2>
            <div class="card" style="margin-bottom:16px;">
                <div class="card-title">NAT Правила (iptables)</div>
                <pre id="natRules" style="font-size:12px; color:#a5b4fc; white-space:pre-wrap;">Загрузка...</pre>
            </div>
            <div class="card">
                <div class="card-title">Mangle Правила (NFQUEUE)</div>
                <pre id="mangleRules" style="font-size:12px; color:#a5b4fc; white-space:pre-wrap;">Загрузка...</pre>
            </div>
        </div>
    </div>

    <!-- Add Strategy Modal -->
    <div id="addStrategyModal" class="modal-overlay">
        <div class="modal">
            <h3>Добавить стратегию</h3>
            <div class="form-group">
                <label>Название</label>
                <input type="text" id="stratName" placeholder="Моя стратегия">
            </div>
            <div class="form-group">
                <label>Описание</label>
                <input type="text" id="stratDesc" placeholder="Для провайдера X, работает хорошо">
            </div>
            <div class="form-group">
                <label>Параметры nfqws (без --qnum)</label>
                <textarea id="stratArgs" placeholder="--dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig ..."></textarea>
            </div>
            <div class="modal-actions">
                <button class="btn btn-outline" onclick="closeModal()">Отмена</button>
                <button class="btn btn-primary" onclick="saveStrategy()">Сохранить</button>
            </div>
        </div>
    </div>

    <!-- Toast -->
    <div id="toast" class="toast"></div>

    <script>
        let currentStrategies = {};
        let activeStrategyKey = null;

        // ==================== API Calls ====================
        async function api(endpoint, method = 'GET', body = null) {
            try {
                const opts = { method };
                if (body) {
                    opts.headers = { 'Content-Type': 'application/json' };
                    opts.body = JSON.stringify(body);
                }
                const res = await fetch(`/api/${endpoint}`, opts);
                return await res.json();
            } catch (e) {
                showToast('Ошибка соединения с API', 'error');
                return null;
            }
        }

        // ==================== Status ====================
        async function refreshStatus() {
            const data = await api('status');
            if (!data) return;

            const badge = document.getElementById('statusBadge');
            const text = document.getElementById('statusText');

            if (data.zapret.active) {
                badge.className = 'status-badge active';
                text.textContent = 'Активен';
            } else {
                badge.className = 'status-badge inactive';
                text.textContent = 'Остановлен';
            }

            document.getElementById('cpuTemp').textContent = data.system.temperature;
            document.getElementById('memUsage').textContent = data.system.memory || '--';
            document.getElementById('cpuLoad').textContent = data.system.cpu_load?.split(' ')[0] || '--';
            document.getElementById('netTraffic').textContent = data.system.network || '--';

            // Clients
            const tbody = document.getElementById('clientsTable');
            if (data.clients && data.clients.length > 0) {
                tbody.innerHTML = data.clients.map(c => `
                    <tr>
                        <td>${c.ip}</td>
                        <td style="font-family:monospace;font-size:13px;">${c.mac}</td>
                        <td style="color:var(--text-secondary)">—</td>
                    </tr>
                `).join('');
            } else {
                tbody.innerHTML = '<tr><td colspan="3" style="color:var(--text-secondary)">Нет подключённых устройств</td></tr>';
            }
        }

        // ==================== Zapret Control ====================
        async function zapretAction(action) {
            showToast(`${action === 'start' ? 'Запуск' : action === 'stop' ? 'Остановка' : 'Перезапуск'}...`, 'info');
            const data = await api(action, 'POST');
            if (data?.success) {
                showToast(data.message, 'success');
            } else {
                showToast(data?.message || 'Ошибка', 'error');
            }
            setTimeout(refreshStatus, 1500);
        }

        // ==================== Strategies ====================
        async function loadStrategies() {
            const data = await api('strategies');
            if (!data) return;
            currentStrategies = data;
            renderStrategies();
        }

        function renderStrategies() {
            const container = document.getElementById('strategiesList');
            container.innerHTML = Object.entries(currentStrategies).map(([key, s]) => `
                <div class="strategy-card ${key === activeStrategyKey ? 'active-strategy' : ''}" id="strat-${key}">
                    <div class="strategy-name">${s.name}</div>
                    <div class="strategy-desc">${s.description}</div>
                    <div class="strategy-args">${s.args}</div>
                    <div class="strategy-actions">
                        <button class="btn btn-primary" onclick="applyStrategy('${key}')">Применить</button>
                        <button class="btn btn-outline" onclick="deleteStrategy('${key}')">Удалить</button>
                    </div>
                </div>
            `).join('');
        }

        async function applyStrategy(key) {
            const strategy = currentStrategies[key];
            if (!strategy) return;

            showToast('Применяю стратегию...', 'info');
            const data = await api('apply-strategy', 'POST', { args: strategy.args });
            if (data?.success) {
                activeStrategyKey = key;
                renderStrategies();
                showToast('Стратегия применена!', 'success');
            } else {
                showToast(data?.message || 'Ошибка', 'error');
            }
            setTimeout(refreshStatus, 2000);
        }

        async function deleteStrategy(key) {
            if (!confirm(`Удалить стратегию "${currentStrategies[key]?.name}"?`)) return;
            const data = await api(`strategies/${key}`, 'DELETE');
            if (data?.success) {
                showToast('Стратегия удалена', 'success');
                loadStrategies();
            }
        }

        function openAddStrategy() {
            document.getElementById('addStrategyModal').classList.add('show');
        }

        function closeModal() {
            document.getElementById('addStrategyModal').classList.remove('show');
        }

        async function saveStrategy() {
            const name = document.getElementById('stratName').value;
            const desc = document.getElementById('stratDesc').value;
            const args = document.getElementById('stratArgs').value;

            if (!name || !args) {
                showToast('Заполни название и параметры', 'error');
                return;
            }

            const data = await api('strategies', 'POST', { name, description: desc, args });
            if (data?.success) {
                showToast('Стратегия сохранена!', 'success');
                closeModal();
                loadStrategies();
                document.getElementById('stratName').value = '';
                document.getElementById('stratDesc').value = '';
                document.getElementById('stratArgs').value = '';
            }
        }

        // ==================== Logs ====================
        async function loadLogs() {
            const data = await api('logs');
            if (data) {
                document.getElementById('logsContent').textContent = data.logs || 'Нет логов';
            }
        }

        // ==================== Network ====================
        async function loadNetwork() {
            const data = await api('gateway-status');
            if (data) {
                document.getElementById('natRules').textContent = data.nat_rules || 'Нет правил';
                document.getElementById('mangleRules').textContent = data.mangle_rules || 'Нет правил';
            }
        }

        // ==================== Tabs ====================
        function switchTab(tab) {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
            event.target.classList.add('active');
            document.getElementById(`tab-${tab}`).classList.add('active');

            if (tab === 'logs') loadLogs();
            if (tab === 'network') loadNetwork();
        }

        // ==================== Toast ====================
        function showToast(message, type = 'info') {
            const toast = document.getElementById('toast');
            toast.textContent = message;
            toast.className = `toast ${type} show`;
            setTimeout(() => toast.classList.remove('show'), 3000);
        }

        // ==================== Init ====================
        refreshStatus();
        loadStrategies();
        setInterval(refreshStatus, 15000);
    </script>
</body>
</html>
```

### 5.3 Создание systemd-сервиса для веб-панели

```bash
sudo nano /etc/systemd/system/zapret-web.service
```

Содержимое:

```ini
[Unit]
Description=Zapret Web Control Panel
After=network.target zapret.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/zapret-web
ExecStart=/usr/bin/python3 /opt/zapret-web/api.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable zapret-web
sudo systemctl start zapret-web
```

Веб-панель будет доступна по адресу: **http://192.168.1.10:8080**

---

## Часть 6: Настройка PS5

### 6.1 Настройка сети на PS5

На PS5 перейди в: **Настройки → Сеть → Настроить интернет-соединение**

Выбери свою текущую сеть (Ethernet или Wi-Fi) → **Дополнительные настройки**:

| Параметр | Значение |
|----------|----------|
| **IP-адрес** | Вручную |
| IP-адрес | `192.168.1.50` |
| Маска подсети | `255.255.255.0` |
| Шлюз по умолчанию | `192.168.1.10` ← **IP Raspberry Pi!** |
| **DNS** | Вручную |
| Основной DNS | `8.8.8.8` |
| Дополнительный DNS | `1.1.1.1` |
| **MTU** | Автоматически |
| **Прокси** | Не использовать |

> [!IMPORTANT]
> Ключевой момент — **шлюз (gateway) должен указывать на IP Raspberry Pi** (`192.168.1.10`), а не на роутер. Именно это заставляет весь трафик PS5 идти через RPi, где zapret обработает его.

### 6.2 Проверка соединения

На PS5: **Настройки → Сеть → Проверить соединение с интернетом**

Должно показать:
- ✅ Получить IP-адрес — Успешно
- ✅ Соединение с интернетом — Успешно  
- ✅ Вход в PSN — Успешно

### 6.3 Проверка на RPi, что трафик PS5 проходит

```bash
# Смотри трафик от PS5 (замени на IP твоей PS5)
sudo tcpdump -i eth0 host 192.168.1.50 -n -c 20

# Проверь, что пакеты попадают в NFQUEUE
sudo conntrack -L | grep 192.168.1.50

# Проверь логи nfqws
sudo journalctl -u zapret -f
```

---

## Часть 7: Доступ для друзей

Всё максимально просто — друзьям нужно только указать RPi как шлюз на своих устройствах.

### 7.1 Настройка PS5 друга

Точно так же, как в Части 6, но с другим IP:

| Параметр | Значение |
|----------|----------|
| IP-адрес | `192.168.1.51` (или другой свободный) |
| Маска подсети | `255.255.255.0` |
| **Шлюз** | `192.168.1.10` ← IP Raspberry Pi |
| Основной DNS | `8.8.8.8` |
| Дополнительный DNS | `1.1.1.1` |

### 7.2 Для ПК друга (Windows)

```
Панель управления → Центр управления сетями → Изменение параметров адаптера
→ Правой кнопкой по Ethernet → Свойства → IPv4 → Свойства

IP-адрес: 192.168.1.52
Маска: 255.255.255.0
Шлюз: 192.168.1.10
DNS: 8.8.8.8, 1.1.1.1
```

### 7.3 Для ПК друга (macOS/Linux)

```bash
# Linux (временно)
sudo ip route replace default via 192.168.1.10

# macOS
sudo route change default 192.168.1.10
```

> [!TIP]
> Если много устройств, можно настроить DHCP на роутере так, чтобы определённые MAC-адреса получали `192.168.1.10` как шлюз. Или запустить `dnsmasq` на RPi как DHCP-сервер для конкретных устройств.

---

## Часть 8: Диагностика и проверка

### 8.1 Проверка, что Zapret работает

```bash
# Статус сервиса
sudo systemctl status zapret

# Процесс nfqws запущен?
ps aux | grep nfqws

# Правила iptables на месте?
sudo iptables -t mangle -L -n -v
sudo iptables -t nat -L -n -v

# IP forwarding включён?
sysctl net.ipv4.ip_forward

# Conntrack видит соединения?
sudo conntrack -L 2>/dev/null | head -20
```

### 8.2 Проверка через curl

```bash
# Прямо с RPi проверь доступ к EA:
curl -v https://accounts.ea.com 2>&1 | head -30

# Проверь с использованием конкретного IP:
curl -v --connect-to accounts.ea.com:443:159.153.232.152:443 https://accounts.ea.com 2>&1 | head -20
```

### 8.3 Мониторинг в реальном времени

```bash
# Логи nfqws в реальном времени
sudo journalctl -u zapret -f

# Мониторинг трафика
sudo tcpdump -i eth0 -n port 443 and host 192.168.1.50

# Мониторинг NFQUEUE
sudo conntrack -E -p tcp --dport 443
```

### 8.4 Типичные проблемы и решения

| Проблема | Решение |
|----------|---------|
| PS5 не выходит в интернет | Проверь `sysctl net.ipv4.ip_forward`, iptables NAT правила |
| Zapret не запускается | `journalctl -u zapret -e` — посмотри ошибки |
| Игры лагают (высокий пинг) | Уменьши `connbytes` до `1:6`, проверь нагрузку на CPU |
| blockcheck не показывает рабочую стратегию | Попробуй `--dpi-desync-any-protocol`, смени TTL |
| Веб-панель не открывается | `sudo systemctl status zapret-web`, проверь файрвол |
| Не все сайты EA работают | Добавь нестандартные порты в iptables правила |

---

## План Б: Альтернативные решения

### Вариант Б1: tpws вместо nfqws

Если `nfqws` не помогает (например, провайдер использует более хитрый DPI), можно попробовать `tpws` (transparent proxy):

```bash
# Запуск tpws
sudo /opt/zapret/tpws/tpws \
  --port=988 \
  --bind-addr=0.0.0.0 \
  --split-pos=midsld \
  --disorder \
  --hostcase \
  --tlsrec=midsld

# Перенаправление трафика через tpws
sudo iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j REDIRECT --to-port 988
sudo iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 988
```

### Вариант Б2: WireGuard VPN через VPS

Если DPI обход не работает вообще, можно поднять VPN:

```bash
# На VPS (за границей)
sudo apt install wireguard
wg genkey | tee server-privatekey | wg pubkey > server-publickey

# На Raspberry Pi
sudo apt install wireguard
wg genkey | tee client-privatekey | wg pubkey > client-publickey

# Конфиг на RPi: /etc/wireguard/wg0.conf
# Далее маршрутизируй трафик PS5 через VPN туннель
```

### Вариант Б3: zapret2 (Lua-based)

Если запрет v1 перестал работать с новыми DPI, можно перейти на zapret2 с Lua-скриптами, которые дают более тонкий контроль:

```bash
cd /opt
sudo git clone https://github.com/bol-van/zapret2.git
cd zapret2
sudo make
```

Запуск nfqws2 с Lua:
```bash
sudo /opt/zapret2/nfq2/nfqws2 --qnum=200 --debug \
  --lua-init=@zapret-lib.lua --lua-init=@zapret-antidpi.lua \
  --filter-tcp=80,443 --filter-l7=tls,http \
  --payload=tls_client_hello \
  --lua-desync=fake:blob=fake_default_tls:tcp_md5:tls_mod=rnd,rndsni,dupsid \
  --payload=http_req \
  --lua-desync=fake:blob=fake_default_http:tcp_md5
```

---

## Полезные ссылки

- [Zapret (v1) — GitHub](https://github.com/bol-van/zapret)
- [Zapret2 — GitHub](https://github.com/bol-van/zapret2)
- [Zapret Discussions](https://github.com/bol-van/zapret/discussions) — тут можно найти рабочие стратегии для конкретных провайдеров

---

> [!CAUTION]
> **Дисклеймер**: Этот гайд предоставлен исключительно в образовательных целях. Использование средств обхода DPI может нарушать условия предоставления услуг вашего интернет-провайдера. Автор не несёт ответственности за использование данной информации.
