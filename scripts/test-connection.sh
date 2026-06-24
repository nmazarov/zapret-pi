#!/bin/bash
###############################################################################
# zapret-pi — Диагностический скрипт
# Проверяет работоспособность всех компонентов системы:
# - IP forwarding, nfqws, iptables, NAT, AdGuard, веб-панель
# - Подключение к заблокированным сайтам
# - DNS-фильтрацию рекламы
###############################################################################

set -uo pipefail

# ─── Цвета ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Счётчики
PASS=0
FAIL=0
WARN=0

# ─── Функции вывода результатов ──────────────────────────────────────────────
test_ok() {
    echo -e "  ${GREEN}[  OK]${NC} $*"
    ((PASS++))
}

test_fail() {
    echo -e "  ${RED}[FAIL]${NC} $*"
    ((FAIL++))
}

test_warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $*"
    ((WARN++))
}

test_info() {
    echo -e "  ${BLUE}[INFO]${NC} $*"
}

section() {
    echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}"
}

# ─── Баннер ──────────────────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}"
echo "  ══════════════════════════════════════════════════════"
echo "  ║  ZAPRET-PI — ДИАГНОСТИКА СИСТЕМЫ                 ║"
echo "  ══════════════════════════════════════════════════════"
echo -e "${NC}"
echo -e "  Дата: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  Хост: $(hostname)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 1. СИСТЕМНЫЕ ПРОВЕРКИ
# ═══════════════════════════════════════════════════════════════════════════════
section "Системные проверки"

# Проверка IP forwarding
if [[ $(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null) == "1" ]]; then
    test_ok "IP forwarding включён"
else
    test_fail "IP forwarding выключен! Выполните: echo 1 > /proc/sys/net/ipv4/ip_forward"
fi

# Проверка conntrack
if [[ $(sysctl -n net.netfilter.nf_conntrack_tcp_be_liberal 2>/dev/null) == "1" ]]; then
    test_ok "conntrack tcp_be_liberal = 1"
else
    test_warn "conntrack tcp_be_liberal != 1 (может вызвать проблемы)"
fi

# Проверка конфигурации
if [[ -f /opt/zapret-pi/zapret-pi.conf ]]; then
    test_ok "Конфигурация найдена: /opt/zapret-pi/zapret-pi.conf"
    source /opt/zapret-pi/zapret-pi.conf
    test_info "  IFACE_WAN=$IFACE_WAN, ROUTER_IP=$ROUTER_IP, RPI_IP=$RPI_IP"
else
    test_warn "Конфигурация /opt/zapret-pi/zapret-pi.conf не найдена"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 2. ПРОЦЕССЫ И СЕРВИСЫ
# ═══════════════════════════════════════════════════════════════════════════════
section "Процессы и сервисы"

# Проверка nfqws
if pgrep -x nfqws > /dev/null 2>&1; then
    local_pid=$(pgrep -x nfqws | head -1)
    test_ok "nfqws запущен (PID: $local_pid)"
else
    test_fail "nfqws НЕ запущен!"
fi

# Проверка zapret сервиса
if systemctl is-active zapret.service > /dev/null 2>&1; then
    test_ok "Сервис zapret активен"
elif [[ -f /etc/init.d/zapret ]] && /etc/init.d/zapret status > /dev/null 2>&1; then
    test_ok "Сервис zapret активен (init.d)"
else
    test_fail "Сервис zapret НЕ активен"
fi

# Проверка zapret-gateway
if systemctl is-active zapret-gateway.service > /dev/null 2>&1; then
    test_ok "Сервис zapret-gateway активен"
else
    test_fail "Сервис zapret-gateway НЕ активен"
fi

# Проверка AdGuard Home
if systemctl is-active AdGuardHome.service > /dev/null 2>&1; then
    test_ok "AdGuard Home запущен"
elif pgrep -x AdGuardHome > /dev/null 2>&1; then
    test_ok "AdGuard Home запущен (не через systemd)"
else
    test_fail "AdGuard Home НЕ запущен"
fi

# Проверка веб-панели
if systemctl is-active zapret-web.service > /dev/null 2>&1; then
    test_ok "Веб-панель zapret-web активна"
else
    test_fail "Веб-панель zapret-web НЕ активна"
fi

# Проверка портов
if ss -tlnp 2>/dev/null | grep -q ':8080'; then
    test_ok "Порт 8080 (веб-панель) слушает"
else
    test_warn "Порт 8080 (веб-панель) не слушает"
fi

if ss -tlnp 2>/dev/null | grep -q ':53'; then
    test_ok "Порт 53 (DNS) слушает"
else
    test_warn "Порт 53 (DNS) не слушает"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 3. ПРАВИЛА IPTABLES
# ═══════════════════════════════════════════════════════════════════════════════
section "Правила iptables"

# Проверка NAT правил
nat_rules=$(iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -c "MASQUERADE" || echo "0")
if [[ "$nat_rules" -gt 0 ]]; then
    test_ok "NAT MASQUERADE правила найдены ($nat_rules)"
else
    test_fail "NAT MASQUERADE правила НЕ найдены!"
fi

# Проверка NFQUEUE правил в mangle
nfqueue_rules=$(iptables -t mangle -L -n 2>/dev/null | grep -c "NFQUEUE" || echo "0")
if [[ "$nfqueue_rules" -gt 0 ]]; then
    test_ok "NFQUEUE правила найдены ($nfqueue_rules)"
else
    test_fail "NFQUEUE правила НЕ найдены!"
fi

# Проверка FORWARD правил
forward_rules=$(iptables -L FORWARD -n 2>/dev/null | grep -c "ACCEPT" || echo "0")
if [[ "$forward_rules" -gt 0 ]]; then
    test_ok "FORWARD ACCEPT правила найдены ($forward_rules)"
else
    test_warn "FORWARD ACCEPT правила не найдены (может быть OK если политика ACCEPT)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 4. ТЕСТЫ ПОДКЛЮЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════════
section "Тесты подключения к сайтам"

# Функция проверки HTTP-подключения
test_site() {
    local url="$1"
    local name="$2"
    local timeout=10

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" --connect-timeout 5 "$url" 2>/dev/null) || true

    if [[ -n "$http_code" && "$http_code" -ge 200 && "$http_code" -lt 400 ]]; then
        test_ok "$name ($url) — HTTP $http_code"
    elif [[ -n "$http_code" && "$http_code" -ge 400 ]]; then
        test_warn "$name ($url) — HTTP $http_code (сайт ответил, но с ошибкой)"
    else
        test_fail "$name ($url) — нет ответа (timeout или блокировка)"
    fi
}

test_site "https://youtube.com" "YouTube"
test_site "https://discord.com" "Discord"
test_site "https://accounts.ea.com" "EA Accounts"

# Дополнительные проверки базового интернета
test_site "https://google.com" "Google (базовый тест)"

# ═══════════════════════════════════════════════════════════════════════════════
# 5. DNS ТЕСТЫ
# ═══════════════════════════════════════════════════════════════════════════════
section "DNS тесты (блокировка рекламы)"

# Проверка, что рекламные домены блокируются
if command -v dig > /dev/null 2>&1; then
    # Тест: ad.doubleclick.net должен резолвиться в 0.0.0.0 (если AdGuard настроен)
    ad_result=$(dig +short ad.doubleclick.net @127.0.0.1 2>/dev/null | head -1) || true

    if [[ "$ad_result" == "0.0.0.0" || "$ad_result" == "127.0.0.1" || "$ad_result" == "::" ]]; then
        test_ok "ad.doubleclick.net заблокирован ($ad_result) — реклама блокируется"
    elif [[ -z "$ad_result" ]]; then
        test_warn "ad.doubleclick.net — нет ответа DNS (AdGuard может быть не настроен)"
    else
        test_warn "ad.doubleclick.net = $ad_result (реклама может НЕ блокироваться)"
    fi

    # Тест обычного домена — должен резолвиться нормально
    normal_result=$(dig +short google.com @127.0.0.1 2>/dev/null | head -1) || true
    if [[ -n "$normal_result" ]]; then
        test_ok "google.com резолвится через локальный DNS ($normal_result)"
    else
        test_warn "google.com не резолвится через 127.0.0.1 (DNS может не работать)"
    fi
elif command -v nslookup > /dev/null 2>&1; then
    ad_result=$(nslookup ad.doubleclick.net 127.0.0.1 2>/dev/null | grep -i "address" | tail -1 | awk '{print $2}') || true
    if [[ "$ad_result" == "0.0.0.0" || "$ad_result" == "127.0.0.1" ]]; then
        test_ok "ad.doubleclick.net заблокирован ($ad_result)"
    else
        test_warn "Не удалось проверить блокировку рекламы через nslookup"
    fi
else
    test_warn "dig/nslookup не найдены, пропуск DNS-тестов"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# ИТОГ
# ═══════════════════════════════════════════════════════════════════════════════
echo -e ""
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  ИТОГ ДИАГНОСТИКИ${NC}"
echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e ""
echo -e "  ${GREEN}Пройдено:${NC}     $PASS"
echo -e "  ${RED}Ошибок:${NC}       $FAIL"
echo -e "  ${YELLOW}Предупреждений:${NC} $WARN"
echo -e ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✓ Все основные проверки пройдены!${NC}"
elif [[ $FAIL -le 2 ]]; then
    echo -e "  ${YELLOW}${BOLD}⚠ Есть незначительные проблемы, система может работать.${NC}"
else
    echo -e "  ${RED}${BOLD}✗ Обнаружены серьёзные проблемы! Проверьте настройку.${NC}"
fi

echo -e ""
echo -e "  ${BLUE}Для подробных логов:${NC}"
echo -e "    sudo journalctl -u zapret -n 50"
echo -e "    sudo journalctl -u zapret-gateway -n 50"
echo -e "    sudo journalctl -u AdGuardHome -n 50"
echo -e ""

exit $FAIL
