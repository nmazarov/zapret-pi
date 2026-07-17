#!/bin/bash
###############################################################################
# zapret-pi — Автоматический установщик для Raspberry Pi
# Один скрипт для полной настройки обхода блокировок + AdGuard Home + веб-панель
#
# Поддерживаемые переменные окружения (для неинтерактивного режима):
#   NON_INTERACTIVE=1  — не задавать вопросов
#   RPI_IP=X.X.X.X     — статический IP для Raspberry Pi
#   ROUTER_IP=X.X.X.X  — IP роутера (шлюз по умолчанию)
#   IFACE_WAN=ethX      — сетевой интерфейс (WAN)
#   DNS_SERVERS=X.X.X.X — DNS серверы (через запятую)
###############################################################################

set -euo pipefail

# ─── Определяем директорию проекта ──────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Цвета для вывода ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # Без цвета

# ─── Функции вывода ─────────────────────────────────────────────────────────
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[  OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
step()  { echo -e "\n${CYAN}${BOLD}>>> $*${NC}"; }

# ─── Баннер ──────────────────────────────────────────────────────────────────
banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
  ══════════════════════════════════════════════════════════════
  ╔═══╗           ╔═══╗  ╔═══╗
  ╚══╗║  ╔══╗ ╔══╗║   ║  ║   ║ ╔══╗ ╔══╗ ╔══╗ ╔══╗ ╔══╗
  ╔══╝║  ╠══╣ ║  ║╠═╦═╝  ╠═══╝ ╠═╗║ ║    ║    ╠═╗║ ║
  ║   ║  ║  ║ ╠══╝║ ║    ║     ║ ║║ ╚══╝ ╚══╝ ║ ║║ ╚══╝
  ╚═══╝  ╚══╝ ║   ╚═╝    ╚═╝   ╚══╝            ╚══╝
               ╚═╝
  ─── Автоматический установщик для Raspberry Pi ───
  ─── Обход блокировок + AdGuard Home + Веб-панель ───
  ══════════════════════════════════════════════════════════════
EOF
    echo -e "${NC}"
}

# ─── Проверка root ───────────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Этот скрипт должен быть запущен от root!"
        error "Используйте: sudo $0"
        exit 1
    fi
    ok "Запущен от root"
}

# ─── Проверка ОС ────────────────────────────────────────────────────────────
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Не удалось определить ОС. Файл /etc/os-release не найден."
        exit 1
    fi

    source /etc/os-release

    if [[ "$ID" != "raspbian" && "$ID" != "debian" && "$ID" != "ubuntu" && "$ID_LIKE" != *"debian"* ]]; then
        error "Этот скрипт предназначен для Raspberry Pi OS / Debian / Ubuntu."
        error "Обнаружена ОС: $PRETTY_NAME"
        exit 1
    fi

    ok "ОС: $PRETTY_NAME"
}

# ─── Автоопределение сети ────────────────────────────────────────────────────
detect_network() {
    step "Определение сетевых параметров..."

    # Загружаем скрипт автоопределения если есть
    if [[ -f "$PROJECT_DIR/scripts/detect-network.sh" ]]; then
        source <(bash "$PROJECT_DIR/scripts/detect-network.sh")
    fi

    # Шлюз по умолчанию
    if [[ -z "${ROUTER_IP:-}" ]]; then
        ROUTER_IP=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1) || true
        if [[ -z "$ROUTER_IP" ]]; then
            ROUTER_IP="192.168.1.1"
            warn "Не удалось определить шлюз. Используется значение по умолчанию: $ROUTER_IP"
        fi
    fi

    # WAN-интерфейс
    if [[ -z "${IFACE_WAN:-}" ]]; then
        IFACE_WAN=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -1) || true
        if [[ -z "$IFACE_WAN" ]]; then
            IFACE_WAN="eth0"
            warn "Не удалось определить интерфейс. Используется значение по умолчанию: $IFACE_WAN"
        fi
    fi

    # IP адрес RPi
    if [[ -z "${RPI_IP:-}" ]]; then
        # Предлагаем .10 в подсети роутера
        local subnet
        subnet=$(echo "$ROUTER_IP" | sed 's/\.[0-9]*$/.10/')
        RPI_IP="$subnet"
    fi

    # DNS серверы
    if [[ -z "${DNS_SERVERS:-}" ]]; then
        DNS_SERVERS="127.0.0.1"
    fi

    # Номер очереди NFQUEUE
    QUEUE_NUM="${QUEUE_NUM:-200}"

    info "Обнаружены/заданы параметры сети:"
    info "  Шлюз (роутер):    $ROUTER_IP"
    info "  Интерфейс WAN:    $IFACE_WAN"
    info "  IP Raspberry Pi:  $RPI_IP"
    info "  DNS серверы:       $DNS_SERVERS"
    info "  NFQUEUE номер:     $QUEUE_NUM"
}

# ─── Подтверждение пользователем ─────────────────────────────────────────────
confirm_settings() {
    if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
        info "Неинтерактивный режим — используем текущие настройки."
        return
    fi

    echo ""
    echo -e "${YELLOW}Всё верно? Продолжить установку? [Y/n/c]${NC}"
    echo -e "  Y — продолжить, n — отменить, c — изменить настройки"
    read -r answer
    case "$answer" in
        [nN])
            info "Установка отменена."
            exit 0
            ;;
        [cC])
            read -rp "  IP Raspberry Pi [$RPI_IP]: " new_rpi
            [[ -n "$new_rpi" ]] && RPI_IP="$new_rpi"

            read -rp "  IP роутера (шлюз) [$ROUTER_IP]: " new_gw
            [[ -n "$new_gw" ]] && ROUTER_IP="$new_gw"

            read -rp "  Интерфейс WAN [$IFACE_WAN]: " new_iface
            [[ -n "$new_iface" ]] && IFACE_WAN="$new_iface"

            read -rp "  DNS серверы [$DNS_SERVERS]: " new_dns
            [[ -n "$new_dns" ]] && DNS_SERVERS="$new_dns"

            info "Обновлённые параметры:"
            info "  Шлюз: $ROUTER_IP | Интерфейс: $IFACE_WAN | IP RPi: $RPI_IP | DNS: $DNS_SERVERS"
            ;;
        *)
            ;;
    esac
}

# ─── Шаг 1: Обновление системы и установка зависимостей ─────────────────────
install_deps() {
    step "Шаг 1: Обновление системы и установка зависимостей..."

    apt-get update -y
    apt-get upgrade -y

    local deps=(
        git make gcc libc-dev
        libnetfilter-queue-dev libcap-dev zlib1g-dev libmnl-dev
        iptables nftables conntrack
        curl wget dnsutils net-tools
        python3 python3-pip python3-venv
        jq ethtool procps tcpdump
    )

    apt-get install -y "${deps[@]}"
    ok "Зависимости установлены"
}

# ─── Шаг 2: Клонирование zapret ─────────────────────────────────────────────
clone_zapret() {
    step "Шаг 2: Клонирование zapret..."

    if [[ -d /opt/zapret/.git ]]; then
        warn "zapret уже клонирован в /opt/zapret, обновляем..."
        cd /opt/zapret
        git pull || warn "Не удалось обновить (возможно, нет интернета)"
    else
        rm -rf /opt/zapret
        git clone --depth=1 https://github.com/bol-van/zapret.git /opt/zapret
    fi

    ok "zapret готов в /opt/zapret"
}

# ─── Шаг 3: Сборка zapret ───────────────────────────────────────────────────
build_zapret() {
    step "Шаг 3: Сборка zapret..."

    cd /opt/zapret
    make clean || true
    make

    ok "zapret собран"
}

# ─── Шаг 4: Установка бинарников zapret ─────────────────────────────────────
install_zapret_bins() {
    step "Шаг 4: Установка бинарников zapret..."

    if [[ -f /opt/zapret/install_bin.sh ]]; then
        cd /opt/zapret
        bash install_bin.sh
        ok "Бинарники установлены"
    else
        warn "install_bin.sh не найден, пропуск"
    fi
}

# ─── Шаг 5: Копирование конфигурации ────────────────────────────────────────
copy_config() {
    step "Шаг 5: Копирование конфигурации zapret..."

    # Создаём директории если нет
    mkdir -p /opt/zapret/config
    mkdir -p /opt/zapret/ipset

    if [[ -f "$PROJECT_DIR/config/default.conf" ]]; then
        cp -v "$PROJECT_DIR/config/default.conf" /opt/zapret/config/
        ok "Конфигурация скопирована"
    else
        warn "config/default.conf не найден в проекте, пропуск"
    fi
}

# ─── Шаг 6: Копирование списка блокировок ───────────────────────────────────
copy_hosts() {
    step "Шаг 6: Копирование списка заблокированных хостов..."

    if [[ -f "$PROJECT_DIR/config/hosts-blocked.txt" ]]; then
        cp -v "$PROJECT_DIR/config/hosts-blocked.txt" /opt/zapret/ipset/zapret-hosts-user.txt
        ok "Список хостов скопирован"
    else
        warn "config/hosts-blocked.txt не найден, пропуск"
    fi
}

# ─── Шаг 7: Настройка статического IP ───────────────────────────────────────
configure_static_ip() {
    step "Шаг 7: Настройка статического IP ($RPI_IP)..."

    local dhcpcd_conf="/etc/dhcpcd.conf"
    local marker="# === zapret-pi static config ==="

    if [[ ! -f "$dhcpcd_conf" ]]; then
        warn "/etc/dhcpcd.conf не найден (возможно, используется NetworkManager). Пропуск."
        return
    fi

    # Бэкап
    if [[ ! -f "${dhcpcd_conf}.zapret-backup" ]]; then
        cp "$dhcpcd_conf" "${dhcpcd_conf}.zapret-backup"
        ok "Бэкап dhcpcd.conf создан"
    fi

    # Удаляем старый блок если есть
    if grep -q "$marker" "$dhcpcd_conf"; then
        sed -i "/$marker/,/^$/d" "$dhcpcd_conf"
    fi

    # Определяем маску подсети (по умолчанию /24)
    local cidr="24"

    # Добавляем конфигурацию
    cat >> "$dhcpcd_conf" << EOF

$marker
interface $IFACE_WAN
static ip_address=${RPI_IP}/${cidr}
static routers=${ROUTER_IP}
static domain_name_servers=${DNS_SERVERS}

EOF

    ok "Статический IP настроен: $RPI_IP"
}

# ─── Шаг 8: Настройка sysctl ────────────────────────────────────────────────
configure_sysctl() {
    step "Шаг 8: Настройка sysctl (IP forwarding, conntrack)..."

    cat > /etc/sysctl.d/99-zapret-pi.conf << 'EOF'
# zapret-pi: включаем маршрутизацию и настройки conntrack
net.ipv4.ip_forward=1
net.netfilter.nf_conntrack_checksum=0
net.netfilter.nf_conntrack_tcp_be_liberal=1
EOF

    sysctl --system > /dev/null 2>&1
    ok "sysctl настроен"
}

# ─── Шаг 9: Установка gateway-setup.sh ──────────────────────────────────────
install_gateway_script() {
    step "Шаг 9: Установка скрипта шлюза..."

    mkdir -p /opt/zapret-pi

    # Создаём конфигурационный файл с параметрами сети
    cat > /opt/zapret-pi/zapret-pi.conf << EOF
# Конфигурация zapret-pi
# Автоматически создано установщиком $(date '+%Y-%m-%d %H:%M:%S')
IFACE_WAN="${IFACE_WAN}"
ROUTER_IP="${ROUTER_IP}"
RPI_IP="${RPI_IP}"
DNS_SERVERS="${DNS_SERVERS}"
QUEUE_NUM="${QUEUE_NUM}"
EOF

    if [[ -f "$PROJECT_DIR/scripts/gateway-setup.sh" ]]; then
        cp -v "$PROJECT_DIR/scripts/gateway-setup.sh" /opt/zapret-pi/gateway-setup.sh
        chmod +x /opt/zapret-pi/gateway-setup.sh

        # Подставляем переменные по умолчанию (скрипт сам читает .conf, но на всякий)
        sed -i "s|__IFACE_WAN__|${IFACE_WAN}|g" /opt/zapret-pi/gateway-setup.sh 2>/dev/null || true
        sed -i "s|__ROUTER_IP__|${ROUTER_IP}|g" /opt/zapret-pi/gateway-setup.sh 2>/dev/null || true
        sed -i "s|__RPI_IP__|${RPI_IP}|g" /opt/zapret-pi/gateway-setup.sh 2>/dev/null || true
        sed -i "s|__QUEUE_NUM__|${QUEUE_NUM}|g" /opt/zapret-pi/gateway-setup.sh 2>/dev/null || true

        ok "Скрипт шлюза установлен"
    else
        warn "scripts/gateway-setup.sh не найден в проекте"
    fi
}

# ─── Шаг 10: Установка AdGuard Home ─────────────────────────────────────────
install_adguard() {
    step "Шаг 10: Установка AdGuard Home..."

    if [[ -d /opt/AdGuardHome ]] && [[ -f /opt/AdGuardHome/AdGuardHome ]]; then
        ok "AdGuard Home уже установлен, пропуск"
        return
    fi

    info "Скачивание и установка AdGuard Home..."
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

    if [[ -f /opt/AdGuardHome/AdGuardHome ]]; then
        ok "AdGuard Home установлен"
    else
        warn "Не удалось подтвердить установку AdGuard Home"
    fi
}

# ─── Шаг 11: Установка веб-панели ───────────────────────────────────────────
install_web_panel() {
    step "Шаг 11: Установка веб-панели управления..."

    mkdir -p /opt/zapret-web/static

    # Копируем файлы веб-панели
    if [[ -f "$PROJECT_DIR/web/app.py" ]]; then
        cp -v "$PROJECT_DIR/web/app.py" /opt/zapret-web/app.py
        ok "app.py скопирован"
    else
        warn "web/app.py не найден"
    fi

    if [[ -f "$PROJECT_DIR/web/static/index.html" ]]; then
        cp -v "$PROJECT_DIR/web/static/index.html" /opt/zapret-web/static/index.html
        ok "index.html скопирован"
    else
        warn "web/static/index.html не найден"
    fi

    # Создаём Python venv
    if [[ ! -d /opt/zapret-web/venv ]]; then
        info "Создание Python virtual environment..."
        python3 -m venv /opt/zapret-web/venv
    fi

    # Устанавливаем Flask
    /opt/zapret-web/venv/bin/pip install --upgrade pip
    /opt/zapret-web/venv/bin/pip install flask

    ok "Веб-панель установлена"
}

# ─── Шаг 12: Копирование strategies.json ────────────────────────────────────
copy_strategies() {
    step "Шаг 12: Копирование strategies.json..."

    if [[ -f "$PROJECT_DIR/config/strategies.json" ]]; then
        cp -v "$PROJECT_DIR/config/strategies.json" /opt/zapret-web/strategies.json
        ok "strategies.json скопирован"
    else
        warn "strategies.json не найден в проекте, пропуск"
    fi
}

# ─── Шаг 13: Установка systemd сервисов ─────────────────────────────────────
install_services() {
    step "Шаг 13: Установка systemd сервисов..."

    local service_dir="$PROJECT_DIR/systemd"

    if [[ ! -d "$service_dir" ]]; then
        warn "Директория systemd/ не найдена, пропуск"
        return
    fi

    local count=0
    for svc_file in "$service_dir"/*.service; do
        if [[ -f "$svc_file" ]]; then
            local svc_name
            svc_name=$(basename "$svc_file")
            cp -v "$svc_file" /etc/systemd/system/"$svc_name"
            ((count++))
        fi
    done

    if [[ $count -gt 0 ]]; then
        systemctl daemon-reload

        # Включаем все наши сервисы
        for svc_file in "$service_dir"/*.service; do
            if [[ -f "$svc_file" ]]; then
                local svc_name
                svc_name=$(basename "$svc_file")
                systemctl enable "$svc_name" || warn "Не удалось включить $svc_name"
            fi
        done

        ok "Установлено сервисов: $count"
    else
        warn "Файлы .service не найдены"
    fi
}

# ─── Шаг 14: Настройка zapret сервиса ───────────────────────────────────────
setup_zapret_service() {
    step "Шаг 14: Настройка сервиса zapret..."

    if [[ -f /opt/zapret/install_easy.sh ]]; then
        info "Запуск install_easy.sh в неинтерактивном режиме..."
        cd /opt/zapret
        # Пробуем запустить в неинтерактивном режиме
        echo -e "Y\n" | bash install_easy.sh 2>/dev/null || {
            warn "install_easy.sh завершился с ошибкой, настраиваем вручную"
            # Ручная настройка сервиса zapret если install_easy не сработал
            if [[ -f /opt/zapret/init.d/sysv/zapret ]]; then
                cp /opt/zapret/init.d/sysv/zapret /etc/init.d/zapret 2>/dev/null || true
                chmod +x /etc/init.d/zapret 2>/dev/null || true
            fi
        }
    else
        warn "install_easy.sh не найден"
    fi

    ok "Сервис zapret настроен"
}

# ─── Шаг 15: Запуск всех сервисов ───────────────────────────────────────────
start_services() {
    step "Шаг 15: Запуск сервисов..."

    local services=("zapret-gateway" "zapret-web")

    # zapret (может быть через init.d или systemd)
    if systemctl is-enabled zapret.service 2>/dev/null; then
        systemctl restart zapret.service && ok "zapret запущен" || warn "Не удалось запустить zapret"
    elif [[ -f /etc/init.d/zapret ]]; then
        /etc/init.d/zapret restart && ok "zapret запущен (init.d)" || warn "Не удалось запустить zapret"
    fi

    for svc in "${services[@]}"; do
        if systemctl is-enabled "${svc}.service" 2>/dev/null; then
            systemctl restart "${svc}.service" && ok "$svc запущен" || warn "Не удалось запустить $svc"
        fi
    done

    # AdGuard Home
    if systemctl is-enabled AdGuardHome.service 2>/dev/null; then
        systemctl restart AdGuardHome.service && ok "AdGuard Home запущен" || warn "Не удалось запустить AdGuard Home"
    fi
}

# ─── Шаг 16: Итоговая сводка ────────────────────────────────────────────────
print_summary() {
    step "Установка завершена!"

    local subnet
    subnet=$(echo "$RPI_IP" | sed 's/\.[0-9]*$//')

    echo -e ""
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  УСТАНОВКА ZAPRET-PI ЗАВЕРШЕНА УСПЕШНО!${NC}"
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e ""
    echo -e "${BOLD}Сетевые параметры:${NC}"
    echo -e "  IP Raspberry Pi:     ${CYAN}${RPI_IP}${NC}"
    echo -e "  IP роутера:          ${CYAN}${ROUTER_IP}${NC}"
    echo -e "  Интерфейс:           ${CYAN}${IFACE_WAN}${NC}"
    echo -e ""
    echo -e "${BOLD}Панели управления:${NC}"
    echo -e "  Веб-панель zapret:   ${CYAN}http://${RPI_IP}:8080${NC}"
    echo -e "  AdGuard Home:        ${CYAN}http://${RPI_IP}:3000${NC} (первоначальная настройка)"
    echo -e "  AdGuard Home:        ${CYAN}http://${RPI_IP}:80${NC}   (после настройки)"
    echo -e ""
    echo -e "${BOLD}═══ Настройка устройств ═══${NC}"
    echo -e ""
    echo -e "${YELLOW}📺 PS5 / PS4:${NC}"
    echo -e "  Настройки → Сеть → Настроить интернет-соединение"
    echo -e "  Шлюз по умолчанию:  ${CYAN}${RPI_IP}${NC}"
    echo -e "  DNS основной:        ${CYAN}${RPI_IP}${NC}"
    echo -e "  DNS дополнительный:  ${CYAN}8.8.8.8${NC}"
    echo -e ""
    echo -e "${YELLOW}🖥️  ПК (Windows):${NC}"
    echo -e "  Панель управления → Сеть → Свойства адаптера → IPv4"
    echo -e "  Шлюз:               ${CYAN}${RPI_IP}${NC}"
    echo -e "  DNS:                 ${CYAN}${RPI_IP}${NC}"
    echo -e ""
    echo -e "${YELLOW}📱 Телефон (Android/iOS):${NC}"
    echo -e "  Настройки Wi-Fi → Дополнительно → Статический IP"
    echo -e "  Шлюз:               ${CYAN}${RPI_IP}${NC}"
    echo -e "  DNS:                 ${CYAN}${RPI_IP}${NC}"
    echo -e ""
    echo -e "${YELLOW}📺 Smart TV:${NC}"
    echo -e "  Настройки сети → Ручная настройка IP"
    echo -e "  Шлюз:               ${CYAN}${RPI_IP}${NC}"
    echo -e "  DNS:                 ${CYAN}${RPI_IP}${NC}"
    echo -e ""
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Полезные команды:${NC}"
    echo -e "  Проверка:            ${CYAN}sudo bash $PROJECT_DIR/scripts/test-connection.sh${NC}"
    echo -e "  Перезапуск:          ${CYAN}sudo systemctl restart zapret zapret-gateway${NC}"
    echo -e "  Логи:                ${CYAN}sudo journalctl -u zapret-gateway -f${NC}"
    echo -e "  Статус:              ${CYAN}sudo systemctl status zapret zapret-gateway zapret-web${NC}"
    echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ГЛАВНАЯ ФУНКЦИЯ
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    banner
    check_root
    check_os
    detect_network
    confirm_settings

    install_deps
    clone_zapret
    build_zapret
    install_zapret_bins
    copy_config
    copy_hosts
    configure_static_ip
    configure_sysctl
    install_gateway_script
    install_adguard
    install_web_panel
    copy_strategies
    install_services
    setup_zapret_service
    start_services
    print_summary
}

main "$@"
