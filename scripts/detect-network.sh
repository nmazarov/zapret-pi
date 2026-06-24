#!/bin/bash
###############################################################################
# zapret-pi — Автоопределение сетевых параметров
#
# Определяет:
# - IP шлюза по умолчанию (роутер)
# - Имя WAN-интерфейса
# - Предлагаемый статический IP для Raspberry Pi
#
# Вывод: KEY=VALUE пары, пригодные для source/eval
# Использование:
#   source <(bash detect-network.sh)
#   echo "Шлюз: $DETECTED_ROUTER_IP"
###############################################################################

set -uo pipefail

# ─── Определение шлюза по умолчанию ─────────────────────────────────────────
# Ищем IP шлюза из таблицы маршрутизации
DETECTED_ROUTER_IP=""

if command -v ip > /dev/null 2>&1; then
    DETECTED_ROUTER_IP=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1) || true
fi

# Запасной вариант через route
if [[ -z "$DETECTED_ROUTER_IP" ]] && command -v route > /dev/null 2>&1; then
    DETECTED_ROUTER_IP=$(route -n 2>/dev/null | awk '/^0\.0\.0\.0/ {print $2}' | head -1) || true
fi

# Ещё один вариант — из /proc
if [[ -z "$DETECTED_ROUTER_IP" ]]; then
    # Парсим /proc/net/route
    DETECTED_ROUTER_IP=$(awk '$2 == "00000000" {
        h=$3;
        printf "%d.%d.%d.%d\n",
            strtonum("0x"substr(h,7,2)),
            strtonum("0x"substr(h,5,2)),
            strtonum("0x"substr(h,3,2)),
            strtonum("0x"substr(h,1,2))
    }' /proc/net/route 2>/dev/null | head -1) || true
fi

# Значение по умолчанию
if [[ -z "$DETECTED_ROUTER_IP" ]]; then
    DETECTED_ROUTER_IP="192.168.1.1"
fi

# ─── Определение WAN-интерфейса ─────────────────────────────────────────────
DETECTED_IFACE_WAN=""

if command -v ip > /dev/null 2>&1; then
    DETECTED_IFACE_WAN=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -1) || true
fi

# Запасной вариант
if [[ -z "$DETECTED_IFACE_WAN" ]] && command -v route > /dev/null 2>&1; then
    DETECTED_IFACE_WAN=$(route -n 2>/dev/null | awk '/^0\.0\.0\.0/ {print $NF}' | head -1) || true
fi

# Ещё вариант — ищем первый активный ethernet интерфейс
if [[ -z "$DETECTED_IFACE_WAN" ]]; then
    DETECTED_IFACE_WAN=$(ip link show 2>/dev/null | awk -F: '/state UP/ && !/lo/ {gsub(/^ +/,"",$2); print $2; exit}') || true
fi

# Значение по умолчанию
if [[ -z "$DETECTED_IFACE_WAN" ]]; then
    DETECTED_IFACE_WAN="eth0"
fi

# Убираем пробелы
DETECTED_IFACE_WAN=$(echo "$DETECTED_IFACE_WAN" | tr -d '[:space:]')

# ─── Предлагаемый IP для Raspberry Pi ───────────────────────────────────────
# Берём подсеть роутера и ставим последний октет = 10
DETECTED_RPI_IP=""

if [[ -n "$DETECTED_ROUTER_IP" ]]; then
    # Извлекаем первые три октета
    subnet=$(echo "$DETECTED_ROUTER_IP" | sed 's/\.[0-9]*$//')
    if [[ -n "$subnet" ]]; then
        DETECTED_RPI_IP="${subnet}.10"
    fi
fi

# Значение по умолчанию
if [[ -z "$DETECTED_RPI_IP" ]]; then
    DETECTED_RPI_IP="192.168.1.10"
fi

# ─── Определение текущего IP устройства ──────────────────────────────────────
DETECTED_CURRENT_IP=""

if [[ -n "$DETECTED_IFACE_WAN" ]]; then
    DETECTED_CURRENT_IP=$(ip -4 addr show "$DETECTED_IFACE_WAN" 2>/dev/null \
        | awk '/inet / {split($2, a, "/"); print a[1]}' | head -1) || true
fi

if [[ -z "$DETECTED_CURRENT_IP" ]]; then
    DETECTED_CURRENT_IP=$(hostname -I 2>/dev/null | awk '{print $1}') || true
fi

# ─── Определение DNS серверов ────────────────────────────────────────────────
DETECTED_DNS=""

if [[ -f /etc/resolv.conf ]]; then
    DETECTED_DNS=$(grep '^nameserver' /etc/resolv.conf 2>/dev/null \
        | awk '{print $2}' | head -2 | tr '\n' ',' | sed 's/,$//') || true
fi

if [[ -z "$DETECTED_DNS" ]]; then
    DETECTED_DNS="8.8.8.8,8.8.4.4"
fi

# ─── Вывод результатов в формате KEY=VALUE ───────────────────────────────────
# Этот вывод можно использовать через: source <(bash detect-network.sh)

cat << EOF
# Автоматически определённые параметры сети
# Сгенерировано: $(date '+%Y-%m-%d %H:%M:%S')

DETECTED_ROUTER_IP="${DETECTED_ROUTER_IP}"
DETECTED_IFACE_WAN="${DETECTED_IFACE_WAN}"
DETECTED_RPI_IP="${DETECTED_RPI_IP}"
DETECTED_CURRENT_IP="${DETECTED_CURRENT_IP}"
DETECTED_DNS="${DETECTED_DNS}"
EOF

# Если запущен интерактивно (не через source), показываем человекочитаемый вывод на stderr
if [[ -t 1 ]]; then
    echo "" >&2
    echo "═══ Обнаруженные параметры сети ═══" >&2
    echo "  Шлюз (роутер):      ${DETECTED_ROUTER_IP}" >&2
    echo "  WAN интерфейс:      ${DETECTED_IFACE_WAN}" >&2
    echo "  Текущий IP:          ${DETECTED_CURRENT_IP}" >&2
    echo "  Предлагаемый IP RPi: ${DETECTED_RPI_IP}" >&2
    echo "  DNS серверы:         ${DETECTED_DNS}" >&2
    echo "" >&2
fi
