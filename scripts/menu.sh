#!/bin/bash

# Защита от запуска не от рута
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31m✖ Этот скрипт нужно запускать от root!\033[0m"
    echo -e "  Используй: sudo zapret-pi"
    exit 1
fi

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

while true; do
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ══════════════════════════════════════════════════════"
    echo "  ║                ZAPRET-PI МЕНЮ                      ║"
    echo "  ══════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo "  1) 🟢 Показать статус сервисов"
    echo "  2) 🔄 Перезапустить сервисы"
    echo "  3) 🔍 Запустить тест подключения (диагностика)"
    echo "  4) 📋 Показать логи Zapret (nfqws)"
    echo "  5) ⚙️  Авто-подбор стратегии (blockcheck)"
    echo "  6) 🗑️  Полное удаление проекта"
    echo "  0) ❌ Выход"
    echo ""
    read -rp "  Выберите действие [0-6]: " choice

    echo ""
    case $choice in
        1)
            echo -e "${CYAN}Статус сервисов...${NC}"
            systemctl status zapret zapret-gateway zapret-web | grep -E "Active:|Loaded:|service"
            ;;
        2)
            echo -e "${CYAN}Перезапуск сервисов...${NC}"
            systemctl restart zapret zapret-gateway zapret-web
            echo -e "${GREEN}Сервисы перезапущены.${NC}"
            ;;
        3)
            echo -e "${CYAN}Запуск диагностики...${NC}"
            bash /opt/zapret-pi/test-connection.sh
            ;;
        4)
            echo -e "${CYAN}Логи zapret (последние 50 строк)...${NC}"
            journalctl -u zapret -n 50 --no-pager
            ;;
        5)
            echo -e "${CYAN}Запуск blockcheck (это займет время)...${NC}"
            cd /opt/zapret && sudo ./blockcheck.sh
            ;;
        6)
            echo -e "${RED}Для полного удаления проекта перейдите в папку, куда вы клонировали zapret-pi, и выполните:${NC}"
            echo -e "  sudo bash uninstall.sh"
            ;;
        0)
            echo -e "${GREEN}Выход.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор.${NC}"
            ;;
    esac
    
    echo ""
    read -rp "Нажмите Enter, чтобы продолжить..."
done
