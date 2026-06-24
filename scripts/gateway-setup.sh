#!/bin/bash
###############################################################################
# zapret-pi — Настройка шлюза (Gateway/NAT)
#
# Этот скрипт настраивает Raspberry Pi как прозрачный шлюз:
# - Включает маршрутизацию IP (forwarding)
# - Настраивает NAT (MASQUERADE)
# - Настраивает правила FORWARD
# - Создаёт правила NFQUEUE для перехвата DPI-трафика
# - Добавляет правила для EA-серверов (PS5)
#
# Конфигурация читается из /opt/zapret-pi/zapret-pi.conf
###############################################################################

set -euo pipefail

# ─── Цвета ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[  OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ─── Загрузка конфигурации ───────────────────────────────────────────────────
CONF_FILE="/opt/zapret-pi/zapret-pi.conf"

if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
    info "Конфигурация загружена из $CONF_FILE"
else
    warn "Файл конфигурации не найден: $CONF_FILE"
    warn "Используются значения по умолчанию"
fi

# Значения по умолчанию (если не заданы в конфиге)
IFACE_WAN="${IFACE_WAN:-eth0}"
ROUTER_IP="${ROUTER_IP:-192.168.1.1}"
RPI_IP="${RPI_IP:-192.168.1.10}"
QUEUE_NUM="${QUEUE_NUM:-200}"

info "Параметры:"
info "  Интерфейс WAN:  $IFACE_WAN"
info "  IP роутера:      $ROUTER_IP"
info "  IP RPi:          $RPI_IP"
info "  NFQUEUE номер:   $QUEUE_NUM"

# ─── Проверка root ───────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    error "Требуются права root! Используйте: sudo $0"
    exit 1
fi

# ─── Шаг 1: Включение IP forwarding ─────────────────────────────────────────
info "Включение IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
ok "IP forwarding включён"

# Настройки conntrack для корректной работы с DPI
sysctl -w net.netfilter.nf_conntrack_checksum=0 > /dev/null 2>&1 || true
sysctl -w net.netfilter.nf_conntrack_tcp_be_liberal=1 > /dev/null 2>&1 || true
ok "conntrack настроен"

# ─── Шаг 2: Очистка старых правил ───────────────────────────────────────────
info "Очистка старых правил iptables..."

# NAT таблица
iptables -t nat -F 2>/dev/null || true
# Mangle таблица
iptables -t mangle -F 2>/dev/null || true
# FORWARD цепочка
iptables -F FORWARD 2>/dev/null || true

ok "Старые правила очищены"

# ─── Шаг 3: Настройка NAT (MASQUERADE) ──────────────────────────────────────
info "Настройка NAT (MASQUERADE)..."

# MASQUERADE — весь исходящий трафик через WAN-интерфейс маскируется под IP RPi
iptables -t nat -A POSTROUTING -o "$IFACE_WAN" -j MASQUERADE

ok "NAT MASQUERADE настроен на $IFACE_WAN"

# ─── Шаг 4: Настройка FORWARD правил ────────────────────────────────────────
info "Настройка правил FORWARD..."

# Разрешаем пересылку установленных соединений
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Разрешаем пересылку с LAN через WAN
iptables -A FORWARD -i "$IFACE_WAN" -o "$IFACE_WAN" -j ACCEPT

# Политика по умолчанию — ACCEPT (для шлюза)
iptables -P FORWARD ACCEPT

ok "FORWARD правила настроены"

# ─── Шаг 5: Правила NFQUEUE для перехвата DPI (mangle) ──────────────────────
info "Настройка NFQUEUE правил для обхода DPI..."

# Перехват исходящего HTTP/HTTPS трафика (TCP 80, 443)
# connbytes 1:12 — только первые 12 пакетов (хэндшейк и начало сессии)
# Это позволяет nfqws модифицировать ClientHello и начальные HTTP-запросы

# TCP порт 80 (HTTP) — исходящий
iptables -t mangle -A POSTROUTING -o "$IFACE_WAN" \
    -p tcp --dport 80 \
    -m connbytes --connbytes 1:12 --connbytes-mode packets --connbytes-dir original \
    -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass

# TCP порт 443 (HTTPS/TLS) — исходящий
iptables -t mangle -A POSTROUTING -o "$IFACE_WAN" \
    -p tcp --dport 443 \
    -m connbytes --connbytes 1:12 --connbytes-mode packets --connbytes-dir original \
    -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass

# UDP порт 443 (QUIC) — исходящий
iptables -t mangle -A POSTROUTING -o "$IFACE_WAN" \
    -p udp --dport 443 \
    -m connbytes --connbytes 1:12 --connbytes-mode packets --connbytes-dir original \
    -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass

ok "NFQUEUE правила для HTTP/HTTPS/QUIC настроены"

# ─── Шаг 6: Входящие NFQUEUE правила для autottl ────────────────────────────
info "Настройка входящих правил для autottl..."

# Перехват входящего трафика для анализа TTL и автокалибровки
QUEUE_NUM_IN=$((QUEUE_NUM + 1))

iptables -t mangle -A PREROUTING -i "$IFACE_WAN" \
    -p tcp --sport 80 \
    -m connbytes --connbytes 1:6 --connbytes-mode packets --connbytes-dir reply \
    -j NFQUEUE --queue-num "$QUEUE_NUM_IN" --queue-bypass

iptables -t mangle -A PREROUTING -i "$IFACE_WAN" \
    -p tcp --sport 443 \
    -m connbytes --connbytes 1:6 --connbytes-mode packets --connbytes-dir reply \
    -j NFQUEUE --queue-num "$QUEUE_NUM_IN" --queue-bypass

ok "autottl правила настроены (очередь $QUEUE_NUM_IN)"

# ─── Шаг 7: EA-специфичные порты (для PS5/Xbox) ─────────────────────────────
info "Настройка EA-специфичных правил (PS5/Xbox)..."

# EA серверы используют нестандартные порты
# TCP: 3216, 3659, 17503, 17504
# UDP: 3659, 14000-14016

# TCP порты EA — исходящий
for port in 3216 3659 17503 17504; do
    iptables -t mangle -A POSTROUTING -o "$IFACE_WAN" \
        -p tcp --dport "$port" \
        -m connbytes --connbytes 1:12 --connbytes-mode packets --connbytes-dir original \
        -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass
done

# UDP порты EA — исходящий
iptables -t mangle -A POSTROUTING -o "$IFACE_WAN" \
    -p udp --dport 3659 \
    -m connbytes --connbytes 1:12 --connbytes-mode packets --connbytes-dir original \
    -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass

iptables -t mangle -A POSTROUTING -o "$IFACE_WAN" \
    -p udp --dport 14000:14016 \
    -m connbytes --connbytes 1:12 --connbytes-mode packets --connbytes-dir original \
    -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass

ok "EA-специфичные правила настроены"

# ─── Итог ────────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  Шлюз настроен успешно!${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════${NC}"
echo -e ""
echo -e "  NAT:        MASQUERADE на ${CYAN}$IFACE_WAN${NC}"
echo -e "  NFQUEUE:    очередь ${CYAN}$QUEUE_NUM${NC} (исходящий), ${CYAN}$QUEUE_NUM_IN${NC} (входящий)"
echo -e "  Порты DPI:  TCP 80, 443 | UDP 443"
echo -e "  Порты EA:   TCP 3216, 3659, 17503, 17504 | UDP 3659, 14000-14016"
echo -e ""

# Показываем текущие правила для справки
info "Текущие правила mangle:"
iptables -t mangle -L -n --line-numbers 2>/dev/null | head -40
echo ""
info "Текущие правила NAT:"
iptables -t nat -L -n --line-numbers 2>/dev/null | head -20
