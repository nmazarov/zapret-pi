#!/bin/bash
###############################################################################
# zapret-pi — Деинсталлятор
# Полностью удаляет zapret-pi: останавливает сервисы, удаляет файлы,
# восстанавливает конфигурацию сети.
###############################################################################

set -euo pipefail

# ─── Цвета для вывода ───────────────────────────────────────────────────────
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
step()  { echo -e "\n${CYAN}${BOLD}>>> $*${NC}"; }

# ─── Проверка root ───────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    error "Этот скрипт должен быть запущен от root!"
    error "Используйте: sudo $0"
    exit 1
fi

echo -e "${RED}${BOLD}"
cat << 'EOF'
  ══════════════════════════════════════════════════════
  ║  ДЕИНСТАЛЛЯЦИЯ ZAPRET-PI                          ║
  ║  Будут удалены все компоненты zapret-pi            ║
  ══════════════════════════════════════════════════════
EOF
echo -e "${NC}"

# ─── Подтверждение ───────────────────────────────────────────────────────────
if [[ "${NON_INTERACTIVE:-0}" != "1" ]]; then
    echo -e "${YELLOW}Вы уверены, что хотите удалить zapret-pi? [y/N]${NC}"
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        info "Отменено."
        exit 0
    fi
fi

# ─── Шаг 1: Остановка и отключение сервисов ─────────────────────────────────
step "Шаг 1: Остановка сервисов..."

SERVICES=("zapret" "zapret-gateway" "zapret-web")

for svc in "${SERVICES[@]}"; do
    if systemctl is-active "${svc}.service" 2>/dev/null; then
        systemctl stop "${svc}.service" && ok "Остановлен: $svc" || warn "Не удалось остановить $svc"
    else
        info "$svc не запущен"
    fi

    if systemctl is-enabled "${svc}.service" 2>/dev/null; then
        systemctl disable "${svc}.service" && ok "Отключён: $svc" || warn "Не удалось отключить $svc"
    fi
done

# AdGuard Home
if systemctl is-active AdGuardHome.service 2>/dev/null; then
    systemctl stop AdGuardHome.service && ok "Остановлен: AdGuardHome" || warn "Не удалось остановить AdGuardHome"
fi
if systemctl is-enabled AdGuardHome.service 2>/dev/null; then
    systemctl disable AdGuardHome.service && ok "Отключён: AdGuardHome" || warn "Не удалось отключить AdGuardHome"
fi

# ─── Шаг 2: Удаление systemd сервисов ───────────────────────────────────────
step "Шаг 2: Удаление файлов systemd..."

for svc in "${SERVICES[@]}"; do
    if [[ -f "/etc/systemd/system/${svc}.service" ]]; then
        rm -f "/etc/systemd/system/${svc}.service"
        ok "Удалён: /etc/systemd/system/${svc}.service"
    fi
done

systemctl daemon-reload
ok "systemd перезагружен"

# ─── Шаг 3: Удаление zapret-pi и веб-панели ─────────────────────────────────
step "Шаг 3: Удаление директорий zapret-pi..."

if [[ -d /opt/zapret-pi ]]; then
    rm -rf /opt/zapret-pi
    ok "Удалён: /opt/zapret-pi"
fi

if [[ -d /opt/zapret-web ]]; then
    rm -rf /opt/zapret-web
    ok "Удалён: /opt/zapret-web"
fi

# ─── Шаг 4: Опционально — удаление zapret и AdGuard Home ────────────────────
step "Шаг 4: Удаление zapret и AdGuard Home (опционально)..."

if [[ "${NON_INTERACTIVE:-0}" != "1" ]]; then
    # zapret
    if [[ -d /opt/zapret ]]; then
        echo -e "${YELLOW}Удалить /opt/zapret (ядро zapret)? [y/N]${NC}"
        read -r del_zapret
        if [[ "$del_zapret" == "y" || "$del_zapret" == "Y" ]]; then
            rm -rf /opt/zapret
            ok "Удалён: /opt/zapret"
        else
            info "Оставлен: /opt/zapret"
        fi
    fi

    # AdGuard Home
    if [[ -d /opt/AdGuardHome ]]; then
        echo -e "${YELLOW}Удалить /opt/AdGuardHome (AdGuard Home)? [y/N]${NC}"
        read -r del_adguard
        if [[ "$del_adguard" == "y" || "$del_adguard" == "Y" ]]; then
            # Используем встроенный деинсталлятор если есть
            if [[ -f /opt/AdGuardHome/AdGuardHome ]]; then
                /opt/AdGuardHome/AdGuardHome -s uninstall 2>/dev/null || true
            fi
            rm -rf /opt/AdGuardHome
            ok "Удалён: /opt/AdGuardHome"
        else
            info "Оставлен: /opt/AdGuardHome"
        fi
    fi
else
    info "Неинтерактивный режим: /opt/zapret и /opt/AdGuardHome оставлены"
fi

# ─── Шаг 5: Восстановление dhcpcd.conf ──────────────────────────────────────
step "Шаг 5: Восстановление сетевой конфигурации..."

if [[ -f /etc/dhcpcd.conf.zapret-backup ]]; then
    cp /etc/dhcpcd.conf.zapret-backup /etc/dhcpcd.conf
    ok "Восстановлен: /etc/dhcpcd.conf из бэкапа"
else
    # Попробуем удалить наш блок вручную
    if [[ -f /etc/dhcpcd.conf ]] && grep -q "zapret-pi static config" /etc/dhcpcd.conf; then
        sed -i '/# === zapret-pi static config ===/,/^$/d' /etc/dhcpcd.conf
        ok "Блок zapret-pi удалён из dhcpcd.conf"
    else
        info "Бэкап dhcpcd.conf не найден, изменений не было"
    fi
fi

# ─── Шаг 6: Удаление sysctl конфигурации ────────────────────────────────────
step "Шаг 6: Удаление sysctl конфигурации..."

if [[ -f /etc/sysctl.d/99-zapret-pi.conf ]]; then
    rm -f /etc/sysctl.d/99-zapret-pi.conf
    sysctl --system > /dev/null 2>&1
    ok "Удалён: /etc/sysctl.d/99-zapret-pi.conf"
else
    info "sysctl конфигурация не найдена"
fi

# ─── Шаг 7: Очистка iptables ────────────────────────────────────────────────
step "Шаг 7: Очистка правил iptables..."

# Сбрасываем все цепочки
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true
iptables -F INPUT 2>/dev/null || true

# Политики по умолчанию
iptables -P FORWARD ACCEPT 2>/dev/null || true
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -P OUTPUT ACCEPT 2>/dev/null || true

ok "Правила iptables сброшены"

# ─── Удаление init.d скрипта если есть ───────────────────────────────────────
if [[ -f /etc/init.d/zapret ]]; then
    rm -f /etc/init.d/zapret
    ok "Удалён: /etc/init.d/zapret"
fi

# ─── Готово ──────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ДЕИНСТАЛЛЯЦИЯ ZAPRET-PI ЗАВЕРШЕНА${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e ""
echo -e "${YELLOW}Рекомендации:${NC}"
echo -e "  • Верните настройки сети на устройствах (PS5, ПК и т.д.)"
echo -e "  • Перезагрузите Raspberry Pi: ${CYAN}sudo reboot${NC}"
echo -e ""
