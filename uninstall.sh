#!/bin/bash
###############################################################################
#  ZAPRET-PI — Деинсталлятор
#  Полностью удаляет все компоненты zapret-pi
###############################################################################

set -uo pipefail

# ─── Цвета ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "  ${CYAN}▸${NC} $*"; }
ok()    { echo -e "  ${GREEN}✔${NC} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail()  { echo -e "  ${RED}✖${NC} $*"; }

# ─── Проверка root ──────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    fail "Нужны права root! Используй: sudo bash uninstall.sh"
    exit 1
fi

echo ""
echo -e "${RED}${BOLD}"
echo '   ╔══════════════════════════════════════════════════════════╗'
echo '   ║                                                        ║'
echo '   ║          🗑️  УДАЛЕНИЕ ZAPRET-PI                        ║'
echo '   ║                                                        ║'
echo '   ╚══════════════════════════════════════════════════════════╝'
echo -e "${NC}"
echo ""

echo -e "  ${YELLOW}Будут удалены:${NC}"
echo "    • Сервисы: zapret-gateway, zapret-web"
echo "    • Веб-панель: /opt/zapret-web/"
echo "    • Конфиг шлюза: /opt/zapret-pi/"
echo "    • Правила iptables (NAT, mangle)"
echo "    • Настройки sysctl"
echo ""
echo -e "  ${DIM}Zapret (/opt/zapret) будет удалён только если ты подтвердишь.${NC}"
echo ""

read -rp "  Продолжить удаление? [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "\n  ${DIM}Отменено.${NC}\n"
    exit 0
fi

echo ""

# ─── 1. Остановка сервисов ──────────────────────────────────────────────────
info "Остановка сервисов..."

for svc in zapret-web zapret-gateway; do
    if systemctl is-active "${svc}.service" > /dev/null 2>&1; then
        systemctl stop "${svc}.service" 2>/dev/null
        ok "Остановлен: $svc"
    fi
    if systemctl is-enabled "${svc}.service" > /dev/null 2>&1; then
        systemctl disable "${svc}.service" > /dev/null 2>&1
    fi
    rm -f "/etc/systemd/system/${svc}.service"
done

systemctl daemon-reload 2>/dev/null
ok "Systemd сервисы удалены"

# ─── 2. Удаление zapret-web ────────────────────────────────────────────────
if [[ -d /opt/zapret-web ]]; then
    rm -rf /opt/zapret-web
    ok "Удалено: /opt/zapret-web/"
fi

# ─── 3. Удаление zapret-pi ─────────────────────────────────────────────────
if [[ -d /opt/zapret-pi ]]; then
    rm -rf /opt/zapret-pi
    ok "Удалено: /opt/zapret-pi/"
fi

# ─── 4. Очистка iptables ───────────────────────────────────────────────────
info "Очистка iptables..."
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true
ok "Правила iptables очищены"

# ─── 5. Удаление sysctl ───────────────────────────────────────────────────
if [[ -f /etc/sysctl.d/99-zapret-pi.conf ]]; then
    rm -f /etc/sysctl.d/99-zapret-pi.conf
    sysctl --system > /dev/null 2>&1
    ok "Настройки sysctl удалены"
fi

# ─── 6. Восстановление dhcpcd.conf ─────────────────────────────────────────
if [[ -f /etc/dhcpcd.conf.zapret-backup ]]; then
    echo ""
    read -rp "  Восстановить оригинальный dhcpcd.conf? [y/N]: " restore
    if [[ "$restore" == "y" || "$restore" == "Y" ]]; then
        cp /etc/dhcpcd.conf.zapret-backup /etc/dhcpcd.conf
        ok "dhcpcd.conf восстановлен из бэкапа"
    fi
elif [[ -f /etc/dhcpcd.conf ]]; then
    # Удаляем только наш блок
    local marker="# === zapret-pi ==="
    if grep -q "$marker" /etc/dhcpcd.conf 2>/dev/null; then
        sed -i "/${marker}/,/^$/d" /etc/dhcpcd.conf
        ok "Блок zapret-pi удалён из dhcpcd.conf"
    fi
fi

# ─── 7. Zapret (опционально) ───────────────────────────────────────────────
echo ""
if [[ -d /opt/zapret ]]; then
    read -rp "  Удалить Zapret (/opt/zapret)? [y/N]: " del_zapret
    if [[ "$del_zapret" == "y" || "$del_zapret" == "Y" ]]; then
        # Останавливаем сервис
        systemctl stop zapret.service 2>/dev/null || true
        systemctl disable zapret.service 2>/dev/null || true
        /etc/init.d/zapret stop 2>/dev/null || true
        rm -f /etc/init.d/zapret 2>/dev/null || true
        rm -f /usr/lib/systemd/system/zapret.service 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null
        rm -rf /opt/zapret
        ok "Zapret удалён"
    else
        info "Zapret оставлен в /opt/zapret"
    fi
fi


# ─── Итог ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo '   ╔══════════════════════════════════════════════════════════╗'
echo '   ║                                                        ║'
echo '   ║        ✅  ZAPRET-PI ПОЛНОСТЬЮ УДАЛЁН                  ║'
echo '   ║                                                        ║'
echo '   ╚══════════════════════════════════════════════════════════╝'
echo -e "${NC}"
echo -e "  ${DIM}Не забудь вернуть настройки сети на устройствах${NC}"
echo -e "  ${DIM}(шлюз и DNS обратно на IP роутера).${NC}"
echo ""
