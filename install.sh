#!/bin/bash
###############################################################################
#  ╔═══════════════════════════════════════════════════════════════╗
#  ║           ZAPRET-PI — Автоматический установщик              ║
#  ║     Обход блокировок + Веб-панель                            ║
#  ║           github.com/nmazarov/zapret-pi                      ║
#  ╚═══════════════════════════════════════════════════════════════╝
#
#  Использование:
#    sudo bash install.sh            — полная автоматическая установка
#    sudo bash install.sh --help     — справка
#
#  Переменные окружения (опционально, для ручной настройки):
#    RPI_IP=X.X.X.X       — статический IP для Raspberry Pi
#    ROUTER_IP=X.X.X.X    — IP роутера
#    IFACE_WAN=ethX       — сетевой интерфейс
###############################################################################

set -uo pipefail

# ─── Директория проекта ─────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Цвета ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Функции вывода ─────────────────────────────────────────────────────────
info()    { echo -e "  ${BLUE}▸${NC} $*"; }
ok()      { echo -e "  ${GREEN}✔${NC} $*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC} $*"; }
fail()    { echo -e "  ${RED}✖${NC} $*"; }
step()    { echo -e "\n${CYAN}${BOLD}━━━ $* ━━━${NC}"; }
substep() { echo -e "  ${DIM}→${NC} $*"; }

ERRORS=0

# ─── Баннер ─────────────────────────────────────────────────────────────────
banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo '   ╔══════════════════════════════════════════════════════════╗'
    echo '   ║             🛡️ ZAPRET-PI · БЫСТРЫЙ СТАРТ                  ║'
    echo '   ║         Обход блокировок для PS5 / PC / TV           ║'
    echo '   ╚══════════════════════════════════════════════════════════╝'
    echo -e "${NC}"
}

# ─── Справка ────────────────────────────────────────────────────────────────
show_help() {
    banner
    echo "  Использование: sudo bash install.sh [ОПЦИИ]"
    echo ""
    echo "  Опции:"
    echo "    --help          Показать эту справку"
    echo "    --skip-web      Не устанавливать веб-панель"
    echo "    --skip-apt      Пропустить обновление пакетов apt"
    echo "    --fast          Быстрый запуск без повторной компиляции"
    echo ""
    echo "  Переменные окружения:"
    echo "    RPI_IP=X.X.X.X       Статический IP для Raspberry Pi"
    echo "    ROUTER_IP=X.X.X.X    IP роутера"
    echo "    IFACE_WAN=ethX       Сетевой интерфейс"
    echo ""
    exit 0
}

# ─── Парсинг аргументов ─────────────────────────────────────────────────────
SKIP_WEB=0
SKIP_APT=0

for arg in "$@"; do
    case "$arg" in
        --help|-h)      show_help ;;
        --skip-web)     SKIP_WEB=1 ;;
        --skip-apt)     SKIP_APT=1 ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
#  ПРОВЕРКИ
# ═══════════════════════════════════════════════════════════════════════════════

check_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "Этот скрипт нужно запускать от root!"
        echo -e "  Используй: ${CYAN}sudo bash install.sh${NC}"
        exit 1
    fi
    ok "Запущен от root"
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        fail "Не удалось определить ОС"
        exit 1
    fi
    source /etc/os-release
    if [[ "$ID" != "raspbian" && "$ID" != "debian" && "$ID" != "ubuntu" && "${ID_LIKE:-}" != *"debian"* ]]; then
        fail "Нужна Raspberry Pi OS / Debian / Ubuntu. Обнаружено: $PRETTY_NAME"
        exit 1
    fi
    ok "ОС: $PRETTY_NAME"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  АВТООПРЕДЕЛЕНИЕ СЕТИ
# ═══════════════════════════════════════════════════════════════════════════════

detect_network() {
    step "🔍 Определение сети"

    # Интерфейс WAN — берём тот, через который идёт default route
    if [[ -z "${IFACE_WAN:-}" ]]; then
        IFACE_WAN=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -1) || true
        if [[ -z "$IFACE_WAN" ]]; then
            # Пробуем найти первый ethernet-интерфейс с IP
            IFACE_WAN=$(ip -o link show | awk -F': ' '/^[0-9]+: (eth|en)/{print $2}' | head -1) || true
            IFACE_WAN="${IFACE_WAN:-eth0}"
        fi
    fi

    # IP роутера — шлюз по умолчанию
    if [[ -z "${ROUTER_IP:-}" ]]; then
        ROUTER_IP=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1) || true
        ROUTER_IP="${ROUTER_IP:-192.168.1.1}"
    fi

    # IP Raspberry Pi — текущий IP на WAN-интерфейсе
    if [[ -z "${RPI_IP:-}" ]]; then
        RPI_IP=$(ip -4 addr show "$IFACE_WAN" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -1) || true
        RPI_IP="${RPI_IP:-192.168.1.10}"
    fi

    # Подсеть
    SUBNET=$(echo "$RPI_IP" | sed 's/\.[0-9]*$//')

    # NFQUEUE номер
    QUEUE_NUM="${QUEUE_NUM:-200}"

    echo ""
    echo -e "  ${BOLD}┌─────────────────────────────────────────┐${NC}"
    echo -e "  ${BOLD}│${NC}  Интерфейс:      ${CYAN}${IFACE_WAN}${NC}$(printf '%*s' $((23 - ${#IFACE_WAN})) '')${BOLD}│${NC}"
    echo -e "  ${BOLD}│${NC}  IP Raspberry Pi: ${CYAN}${RPI_IP}${NC}$(printf '%*s' $((23 - ${#RPI_IP})) '')${BOLD}│${NC}"
    echo -e "  ${BOLD}│${NC}  IP Роутера:      ${CYAN}${ROUTER_IP}${NC}$(printf '%*s' $((23 - ${#ROUTER_IP})) '')${BOLD}│${NC}"
    echo -e "  ${BOLD}│${NC}  Подсеть:         ${CYAN}${SUBNET}.0/24${NC}$(printf '%*s' $((19 - ${#SUBNET})) '')${BOLD}│${NC}"
    echo -e "  ${BOLD}└─────────────────────────────────────────┘${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 1: ЗАВИСИМОСТИ
# ═══════════════════════════════════════════════════════════════════════════════

install_deps() {
    step "📦 Шаг 1/9 — Установка зависимостей"

    export DEBIAN_FRONTEND=noninteractive

    if [[ "${SKIP_APT:-0}" -eq 1 ]]; then
        warn "Пропуск обновления пакетов по флагу --skip-apt"
    else
        substep "Обновление списка пакетов (с таймаутом 15 сек)..."
        timeout 15 apt-get update -qq -y > /dev/null 2>&1 || warn "Обновление apt было пропущено по таймауту, продолжаем..."
    fi

    local deps=(
        git make gcc libc-dev
        libnetfilter-queue-dev libcap-dev zlib1g-dev libmnl-dev
        iptables nftables conntrack
        curl wget dnsutils net-tools
        python3 python3-pip python3-venv
        jq ethtool procps tcpdump
    )

    if [[ "${SKIP_APT:-0}" -eq 1 ]]; then
        ok "Пропущена установка через apt (--skip-apt)"
    else
        substep "Установка ${#deps[@]} пакетов..."
        timeout 60 apt-get install -qq -y "${deps[@]}" > /dev/null 2>&1 || warn "Часть пакетов уже установлена или пропущена"
        ok "Все зависимости проверены"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 2: ZAPRET
# ═══════════════════════════════════════════════════════════════════════════════

install_zapret() {
    step "⚡ Шаг 2/9 — Установка Zapret"

    # Копирование встроенной версии
    if [[ ! -d "/opt/zapret" ]]; then
        substep "Копирование файлов Zapret..."
        if [[ -d "$PROJECT_DIR/linux/zapret" ]]; then
            cp -r "$PROJECT_DIR/linux/zapret" /opt/zapret
        else
            fail "Встроенная папка linux/zapret не найдена!"
            exit 1
        fi
        ok "Файлы Zapret скопированы"
    fi

    # Сборка nfqws, tpws
    if [[ -f "/opt/zapret/bin/nfqws" ]]; then
        ok "Бинарники nfqws уже собраны"
    else
        substep "Компиляция nfqws, tpws (компиляция ~20 сек)..."
        cd /opt/zapret
        make -j$(nproc 2>/dev/null || echo 2) > /dev/null 2>&1 || make > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            fail "Ошибка сборки! Попробуй: cd /opt/zapret && make"
            ((ERRORS++))
            return
        fi
        ok "Zapret успешно собран"
    fi

    # Установка бинарников
    if [[ -f /opt/zapret/install_bin.sh ]]; then
        substep "Установка бинарников..."
        cd /opt/zapret && bash install_bin.sh > /dev/null 2>&1
        ok "Бинарники установлены"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 2.5: СПИСКИ FLOWSEAL
# ═══════════════════════════════════════════════════════════════════════════════

download_flowseal_lists() {
    step "📥 Шаг 2.5/9 — Загрузка списков Flowseal"
    
    local lists_dir="/opt/zapret-pi/lists"
    mkdir -p "$lists_dir"
    
    substep "Проверка и загрузка списков доменов..."
    local raw_url="https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists"
    local mirror_url="https://ghproxy.net/https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists"

    for list in list-general.txt list-google.txt list-exclude.txt ipset-exclude.txt ipset-all.txt; do
        if [[ -f "$PROJECT_DIR/windows/zapret/lists/$list" ]]; then
            cp "$PROJECT_DIR/windows/zapret/lists/$list" "$lists_dir/$list"
        else
            curl -sL --connect-timeout 4 -m 6 "$raw_url/$list" -o "$lists_dir/$list" 2>/dev/null || \
            curl -sL --connect-timeout 4 -m 6 "$mirror_url/$list" -o "$lists_dir/$list" 2>/dev/null || true
        fi
    done

    # Создаем пустые user-листы
    touch "$lists_dir/list-general-user.txt"
    touch "$lists_dir/list-exclude-user.txt"
    touch "$lists_dir/ipset-exclude-user.txt"
    
    ok "Списки Flowseal подгружены"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 3: КОНФИГУРАЦИЯ ZAPRET
# ═══════════════════════════════════════════════════════════════════════════════

configure_zapret() {
    step "⚙️  Шаг 3/9 — Конфигурация Zapret"

    mkdir -p /opt/zapret/ipset

    # ВАЖНО: /opt/zapret/config должен быть ФАЙЛОМ, не папкой!
    if [[ -d /opt/zapret/config ]]; then
        rm -rf /opt/zapret/config
    fi

    if [[ -f "$PROJECT_DIR/config/default.conf" ]]; then
        cp "$PROJECT_DIR/config/default.conf" /opt/zapret/config
        ok "Конфиг zapret установлен"
    else
        warn "default.conf не найден, создаю базовый..."
        cat > /opt/zapret/config << 'CONF'
MODE=nfqws
MODE_FILTER=none
IFACE_WAN=eth0
TPWS_ENABLE=0
NFQWS_ENABLE=1
NFQWS_PORTS_TCP="80,443"
NFQWS_PORTS_UDP="443"
NFQWS_QUEUE_NUM=200
NFQWS_OPT="
--filter-tcp=80,443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig \
--dpi-desync-split-pos=1,midsld --dpi-desync-split-seqovl=2 \
--dpi-desync-fake-tls-mod=rnd,rndsni,dupsid \
--dpi-desync-any-protocol \
--new \
--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6
"
CONF
        ok "Базовый конфиг создан"
    fi

    # Список заблокированных хостов
    if [[ -f "$PROJECT_DIR/config/hosts-blocked.txt" ]]; then
        cp "$PROJECT_DIR/config/hosts-blocked.txt" /opt/zapret/ipset/zapret-hosts-user.txt
        local count
        count=$(grep -c '^[^#]' /opt/zapret/ipset/zapret-hosts-user.txt 2>/dev/null || echo "0")
        ok "Список хостов скопирован ($count доменов)"
    fi

    # Настройка zapret как системный сервис
    substep "Настройка сервиса zapret..."
    if [[ -f /opt/zapret/install_easy.sh ]]; then
        cd /opt/zapret
        echo -e "Y\n" | bash install_easy.sh > /dev/null 2>&1 || true
    fi
    ok "Сервис zapret настроен"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 4: SYSCTL (IP FORWARDING)
# ═══════════════════════════════════════════════════════════════════════════════

configure_sysctl() {
    step "🔧 Шаг 4/9 — Настройка маршрутизации"

    cat > /etc/sysctl.d/99-zapret-pi.conf << 'EOF'
# zapret-pi: маршрутизация и conntrack
net.ipv4.ip_forward=1
net.netfilter.nf_conntrack_checksum=0
net.netfilter.nf_conntrack_tcp_be_liberal=1
EOF

    sysctl --system > /dev/null 2>&1
    ok "IP forwarding включён"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 5: GATEWAY (NAT + NFQUEUE)
# ═══════════════════════════════════════════════════════════════════════════════

install_gateway() {
    step "🌐 Шаг 5/9 — Настройка шлюза (NAT)"

    mkdir -p /opt/zapret-pi

    # Сохраняем конфиг сети
    cat > /opt/zapret-pi/zapret-pi.conf << EOF
# Конфигурация zapret-pi (создано $(date '+%Y-%m-%d %H:%M'))
IFACE_WAN="${IFACE_WAN}"
ROUTER_IP="${ROUTER_IP}"
RPI_IP="${RPI_IP}"
DNS_SERVERS="127.0.0.1"
QUEUE_NUM="${QUEUE_NUM}"
EOF
    ok "Конфиг сети сохранён"

    # Копируем gateway-setup.sh
    if [[ -f "$PROJECT_DIR/scripts/gateway-setup.sh" ]]; then
        cp "$PROJECT_DIR/scripts/gateway-setup.sh" /opt/zapret-pi/gateway-setup.sh
        chmod +x /opt/zapret-pi/gateway-setup.sh
        ok "Скрипт шлюза установлен"
    fi

    # Копируем вспомогательные скрипты
    for script in test-connection.sh detect-network.sh menu.sh; do
        if [[ -f "$PROJECT_DIR/scripts/$script" ]]; then
            cp "$PROJECT_DIR/scripts/$script" /opt/zapret-pi/"$script"
            chmod +x /opt/zapret-pi/"$script"
        fi
    done
    
    # Создаем симлинк для удобного вызова меню
    if [[ -f /opt/zapret-pi/menu.sh ]]; then
        ln -sf /opt/zapret-pi/menu.sh /usr/local/bin/zapret-pi
        ok "Симлинк меню установлен (sudo zapret-pi)"
    fi
}



# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 6: ВЕБ-ПАНЕЛЬ
# ═══════════════════════════════════════════════════════════════════════════════

install_web_panel() {
    if [[ "$SKIP_WEB" == "1" ]]; then
        step "🚫 Шаг 6/9 — Веб-панель (пропущен)"
        return
    fi

    step "🖥️  Шаг 6/9 — Веб-панель управления"

    mkdir -p /opt/zapret-web/static

    # Копируем файлы
    if [[ -f "$PROJECT_DIR/web/app.py" ]]; then
        cp "$PROJECT_DIR/web/app.py" /opt/zapret-web/app.py
        ok "Backend API скопирован"
    fi

    if [[ -f "$PROJECT_DIR/web/static/index.html" ]]; then
        cp "$PROJECT_DIR/web/static/index.html" /opt/zapret-web/static/index.html
        ok "Frontend скопирован"
    fi

    # Стратегии
    if [[ -f "$PROJECT_DIR/config/strategies.json" ]]; then
        cp "$PROJECT_DIR/config/strategies.json" /opt/zapret-web/strategies.json
        ok "Стратегии скопированы"
    fi

    # Python venv + Flask
    substep "Настройка Python окружения..."
    if [[ ! -d /opt/zapret-web/venv ]]; then
        python3 -m venv /opt/zapret-web/venv
    fi
    /opt/zapret-web/venv/bin/pip install --quiet --upgrade pip > /dev/null 2>&1
    /opt/zapret-web/venv/bin/pip install --quiet flask > /dev/null 2>&1

    ok "Веб-панель установлена"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 7: SYSTEMD СЕРВИСЫ
# ═══════════════════════════════════════════════════════════════════════════════

install_services() {
    step "🔄 Шаг 7/9 — Systemd сервисы"

    local installed=0

    for svc_file in "$PROJECT_DIR"/systemd/*.service; do
        if [[ -f "$svc_file" ]]; then
            local name
            name=$(basename "$svc_file")
            cp "$svc_file" /etc/systemd/system/"$name"
            ((installed++))
        fi
    done

    systemctl daemon-reload

    # Включаем сервисы
    for svc_file in "$PROJECT_DIR"/systemd/*.service; do
        if [[ -f "$svc_file" ]]; then
            local name
            name=$(basename "$svc_file" .service)
            systemctl enable "${name}.service" > /dev/null 2>&1 || true
            substep "Включён: ${name}"
        fi
    done

    ok "Установлено сервисов: $installed"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 8: СТАТИЧЕСКИЙ IP
# ═══════════════════════════════════════════════════════════════════════════════

configure_static_ip() {
    step "📡 Шаг 8/9 — Статический IP"

    local dhcpcd="/etc/dhcpcd.conf"
    local marker="# === zapret-pi ==="

    # Проверяем, используется ли dhcpcd
    if [[ ! -f "$dhcpcd" ]]; then
        warn "dhcpcd.conf не найден (используется NetworkManager?)"
        info "Текущий IP ($RPI_IP) будет использован"
        return
    fi

    # Проверяем, уже настроен ли статический IP
    local current_ip
    current_ip=$(ip -4 addr show "$IFACE_WAN" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)

    # Бэкап
    if [[ ! -f "${dhcpcd}.zapret-backup" ]]; then
        cp "$dhcpcd" "${dhcpcd}.zapret-backup"
    fi

    # Удаляем старый блок
    if grep -q "$marker" "$dhcpcd" 2>/dev/null; then
        sed -i "/${marker}/,/^$/d" "$dhcpcd"
    fi

    # Добавляем конфигурацию
    cat >> "$dhcpcd" << EOF

${marker}
interface ${IFACE_WAN}
static ip_address=${RPI_IP}/24
static routers=${ROUTER_IP}
# static domain_name_servers=${ROUTER_IP} 8.8.8.8

EOF

    ok "Статический IP: $RPI_IP (применится после перезагрузки)"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ШАГ 9: ЗАПУСК ВСЕГО
# ═══════════════════════════════════════════════════════════════════════════════

start_everything() {
    step "🚀 Шаг 9/9 — Запуск сервисов"

    # Zapret (nfqws)
    if systemctl is-enabled zapret.service > /dev/null 2>&1; then
        systemctl restart zapret.service 2>/dev/null && ok "Zapret (nfqws) запущен" || warn "Не удалось запустить zapret"
    elif [[ -f /etc/init.d/zapret ]]; then
        /etc/init.d/zapret restart > /dev/null 2>&1 && ok "Zapret (init.d) запущен" || warn "Не удалось запустить zapret"
    fi

    # Gateway
    systemctl restart zapret-gateway.service 2>/dev/null && ok "Gateway (NAT/NFQUEUE) запущен" || warn "Не удалось запустить gateway"

    # Веб-панель
    if [[ "$SKIP_WEB" != "1" ]]; then
        systemctl restart zapret-web.service 2>/dev/null && ok "Веб-панель запущена" || warn "Не удалось запустить веб-панель"
    fi



    # Проверяем nfqws
    sleep 3
    if pgrep -x nfqws > /dev/null 2>&1; then
        ok "nfqws процесс активен ✓"
    else
        warn "nfqws не обнаружен! Проверь: sudo systemctl status zapret"
        ((ERRORS++))
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ФИНАЛЬНАЯ СВОДКА
# ═══════════════════════════════════════════════════════════════════════════════

print_summary() {
    local subnet
    subnet=$(echo "$RPI_IP" | sed 's/\.[0-9]*$//')

    echo ""
    echo ""
    if [[ $ERRORS -eq 0 ]]; then
        echo -e "${GREEN}"
        echo '   ╔══════════════════════════════════════════════════════════╗'
        echo '   ║                                                        ║'
        echo '   ║        ✅  УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!                ║'
        echo '   ║                                                        ║'
        echo '   ╚══════════════════════════════════════════════════════════╝'
        echo -e "${NC}"
    else
        echo -e "${YELLOW}"
        echo '   ╔══════════════════════════════════════════════════════════╗'
        echo '   ║                                                        ║'
        echo -e "   ║    ⚠️  Установка завершена с ${ERRORS} предупреждением(ями)    ║"
        echo '   ║                                                        ║'
        echo '   ╚══════════════════════════════════════════════════════════╝'
        echo -e "${NC}"
    fi

    echo -e "   ${BOLD}🌐 Панели управления:${NC}"
    echo ""
    echo -e "   ${CYAN}┌──────────────────────────────────────────────────────┐${NC}"
    echo -e "   ${CYAN}│${NC}                                                      ${CYAN}│${NC}"
    echo -e "   ${CYAN}│${NC}  🎛️  Zapret веб-панель:  ${BOLD}http://${RPI_IP}:8080${NC}$(printf '%*s' $((13 - ${#RPI_IP})) '')${CYAN}│${NC}"
    echo -e "   ${CYAN}│${NC}                                                      ${CYAN}│${NC}"
    echo -e "   ${CYAN}└──────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "   ${BOLD}📺 Настройка устройств${NC} (укажи шлюз → ${CYAN}${RPI_IP}${NC}):"
    echo ""
    echo -e "   ┌──────────┬─────────────────────────────────────────────┐"
    echo -e "   │ ${BOLD}PS5/PS4${NC}  │ Настройки → Сеть → Шлюз: ${CYAN}${RPI_IP}${NC}$(printf '%*s' $((14 - ${#RPI_IP})) '')│"
    echo -e "   │          │ DNS: ${CYAN}8.8.8.8${NC} / IP роутера                   │"
    echo -e "   ├──────────┼─────────────────────────────────────────────┤"
    echo -e "   │ ${BOLD}ПК${NC}       │ Сетевые настройки → IPv4 → Шлюз: ${CYAN}${RPI_IP}${NC}$(printf '%*s' $((8 - ${#RPI_IP})) '')│"
    echo -e "   │          │ DNS: ${CYAN}8.8.8.8${NC} / IP роутера                   │"
    echo -e "   ├──────────┼─────────────────────────────────────────────┤"
    echo -e "   │ ${BOLD}Smart TV${NC} │ Настройки сети → Шлюз: ${CYAN}${RPI_IP}${NC}$(printf '%*s' $((17 - ${#RPI_IP})) '')│"
    echo -e "   │          │ DNS: ${CYAN}8.8.8.8${NC} / IP роутера                   │"
    echo -e "   ├──────────┼─────────────────────────────────────────────┤"
    echo -e "   │ ${BOLD}Телефон${NC}  │ Wi-Fi → Статический IP → Шлюз: ${CYAN}${RPI_IP}${NC}$(printf '%*s' $((9 - ${#RPI_IP})) '')│"
    echo -e "   │          │ DNS: ${CYAN}8.8.8.8${NC} / IP роутера                   │"
    echo -e "   └──────────┴─────────────────────────────────────────────┘"
    echo ""

    echo -e "   ${BOLD}🔧 Полезные команды:${NC}"
    echo -e "   ${DIM}Меню:${NC}         sudo zapret-pi"
    echo -e "   ${DIM}Статус:${NC}       sudo systemctl status zapret zapret-gateway zapret-web"
    echo -e "   ${DIM}Перезапуск:${NC}   sudo systemctl restart zapret zapret-gateway"
    echo -e "   ${DIM}Логи:${NC}         sudo journalctl -u zapret -f"
    echo -e "   ${DIM}Диагностика:${NC}  sudo bash /opt/zapret-pi/test-connection.sh"
    echo -e "   ${DIM}Удаление:${NC}     sudo bash $(pwd)/uninstall.sh"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  ГЛАВНАЯ ФУНКЦИЯ
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    banner

    step "🔐 Проверки"
    check_root
    check_os

    detect_network

    install_deps
    install_zapret
    download_flowseal_lists
    configure_zapret
    configure_sysctl
    install_gateway
    
    install_web_panel
    install_services
    configure_static_ip
    start_everything

    print_summary
}

main "$@"
