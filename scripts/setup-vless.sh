#!/bin/bash
###############################################################################
#  ZAPRET-PI — Автоматическая настройка VLESS SmartDNS
#  Использование:
#    sudo bash scripts/setup-vless.sh "vless://uuid@host:port?..."
###############################################################################

set -euo pipefail

VLESS_URL="${1:-}"

if [[ -z "$VLESS_URL" ]]; then
    echo "ОШИБКА: Укажите VLESS ссылку!"
    echo "Использование: sudo bash scripts/setup-vless.sh 'vless://...'"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER_PY="$SCRIPT_DIR/vless_parser.py"

if [[ ! -f "$PARSER_PY" ]]; then
    echo "ОШИБКА: Парсер $PARSER_PY не найден!"
    exit 1
fi

# Убедимся, что Xray установлен
if ! command -v xray &>/dev/null; then
    echo "-> Xray не найден. Устанавливаем Xray-core..."
    curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s -- install
fi

echo "-> Парсинг VLESS ссылки и генерация SmartDNS конфигурации..."
python3 "$PARSER_PY" "$VLESS_URL" /usr/local/etc/xray/config.json

echo "-> Перезапуск службы Xray..."
systemctl restart xray
systemctl enable xray

echo ""
echo "================================================================="
echo " [OK] VLESS сервер успешно подключен!"
echo " Xray активирован и работает в режиме SmartDNS (порт 53)."
echo " На консоли PS5 вы можете сменить ТОЛЬКО DNS на IP Raspberry Pi!"
echo "================================================================="
