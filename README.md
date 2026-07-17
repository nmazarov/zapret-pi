<p align="center">
  <img src="https://img.shields.io/badge/🛡️-Zapret--Pi-blue?style=for-the-badge&labelColor=0d1117&color=58a6ff&logoColor=white" alt="Zapret-Pi" height="60"/>
</p>

<h1 align="center">🛡️ Zapret-Pi</h1>

<p align="center">
  <strong>Обход DPI-блокировок на Raspberry Pi</strong><br/>
  Один скрипт — и все устройства в сети работают без ограничений
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License MIT"/>
  <img src="https://img.shields.io/badge/platform-Raspberry%20Pi-c51a4a?style=flat-square&logo=raspberry-pi" alt="Platform"/>
  <img src="https://img.shields.io/badge/language-Bash%20%7C%20Python-blue?style=flat-square" alt="Language"/>
  <img src="https://img.shields.io/badge/status-active-brightgreen?style=flat-square" alt="Status"/>
</p>

---

## 📋 Что это?

**Zapret-Pi** превращает Raspberry Pi в сетевой шлюз, который:

- 🔓 **Обходит DPI-блокировки** — YouTube, Discord, Instagram, Twitter, EA серверы и другие

- 🎮 **Работает для всех устройств** — PS5, ПК, Smart TV, телефоны
- ⚡ **Без VPN** — нативная скорость, минимальный пинг
- 🖥️ **Веб-панель** — управление через браузер

---

## 🚀 Быстрый старт

### Требования

- Raspberry Pi (2+ ГБ RAM) с Raspberry Pi OS / Debian / Ubuntu
- Ethernet-подключение к роутеру
- SSH-доступ

### Установка

```bash
git clone https://github.com/nmazarov/zapret-pi.git
cd zapret-pi
sudo bash install.sh
```

**Всё.** Скрипт автоматически:
- Определит сеть (IP, роутер, интерфейс)
- Установит и соберёт Zapret

- Настроит NAT, iptables, NFQUEUE
- Развернёт веб-панель
- Запустит все сервисы
- Покажет инструкции для подключения устройств

### Удаление

```bash
cd zapret-pi
sudo bash uninstall.sh
```

---

## 🏗️ Архитектура

```
  PS5 / ПК / TV / Телефон
         │
         │  шлюз + DNS = IP малинки
         ▼
  ┌─────────────────────────┐
  │     Raspberry Pi        │
  │                         │

  │  ┌────────▼──────────┐  │
  │  │  iptables/NFQUEUE │  │  NAT + перехват пакетов
  │  └────────┬──────────┘  │
  │           │              │
  │  ┌────────▼──────────┐  │
  │  │   nfqws (Zapret)  │  │  DPI bypass
  │  └────────┬──────────┘  │
  │           │              │
  │  ┌────────▼──────────┐  │
  │  │    Веб-панель     │  │  :8080 → управление
  │  └──────────────────┘  │
  └────────────┬────────────┘
               │
               ▼
       Роутер → Интернет
```

---

## 🎮 Настройка устройств

После установки скрипт покажет IP малинки. Укажите его как **шлюз** на устройствах (DNS можно указать `8.8.8.8` или IP вашего роутера):

| Устройство | Где настроить | Шлюз | DNS |
|------------|--------------|------|-----|
| **PS5 / PS4** | Настройки → Сеть → Вручную | IP малинки | 8.8.8.8 |
| **Windows** | Сетевые настройки → IPv4 | IP малинки | 8.8.8.8 |
| **Smart TV** | Настройки сети → Ручной IP | IP малинки | 8.8.8.8 |
| **Android** | Wi-Fi → Статический IP | IP малинки | 8.8.8.8 |
| **iPhone** | Wi-Fi → Настройка IP → Вручную | IP малинки | 8.8.8.8 |

> 💡 **Совет:** Настройте шлюз на роутере (DHCP → Gateway = IP малинки) — тогда все устройства будут использовать Zapret-Pi автоматически.

---

## 🌐 Панели управления

| Панель | Адрес | Назначение |
|--------|-------|------------|
| **Zapret веб-панель** | `http://IP_МАЛИНКИ:8080` | Стратегии, логи, мониторинг |

---

## 🎯 Стратегии обхода DPI

5 предустановленных стратегий, переключаются через веб-панель:

| Стратегия | Описание | Когда использовать |
|-----------|----------|-------------------|
| **Универсальная (md5sig)** | Fake + FakedSplit + MD5Sig | По умолчанию, подходит большинству |
| **TTL-based** | Fake + MultiDisorder + TTL | Если md5sig не помогает |
| **FakedDisorder** | Перемешивание фейков | Сложные DPI (ТСПУ v2) |
| **HostFakeSplit** | Минимальная модификация | Минимальный пинг для игр |
| **MultiSplit + SeqOvl** | Множественная нарезка | Самые жёсткие DPI |

### Подбор стратегии

```bash
# Автоматический подбор рабочей стратегии для вашего провайдера
cd /opt/zapret
sudo ./blockcheck.sh
```

---

## 📂 Структура проекта

```
zapret-pi/
├── install.sh              # Автоустановщик (sudo bash install.sh)
├── uninstall.sh            # Удаление (sudo bash uninstall.sh)
├── config/
│   ├── default.conf        # Конфиг Zapret (nfqws)
│   ├── strategies.json     # 5 стратегий DPI bypass
│   ├── hosts-blocked.txt   # Заблокированные домены РФ
│   └── sysctl.conf         # Параметры ядра
├── scripts/
│   ├── gateway-setup.sh    # NAT / iptables / NFQUEUE
│   ├── test-connection.sh  # Диагностика
│   └── detect-network.sh   # Автоопределение сети
├── web/
│   ├── app.py              # Flask API (backend)
│   └── static/
│       └── index.html      # Веб-панель (frontend)
└── systemd/
    ├── zapret-gateway.service
    └── zapret-web.service
```

---

## 🔧 Полезные команды

```bash
# Статус всех сервисов
sudo systemctl status zapret zapret-gateway zapret-web

# Перезапуск
sudo systemctl restart zapret zapret-gateway

# Логи nfqws
sudo journalctl -u zapret -f

# Диагностика
sudo bash /opt/zapret-pi/test-connection.sh

# Проверка iptables
sudo iptables -t mangle -L -n
sudo iptables -t nat -L -n
```

---

## 🔧 Troubleshooting

| Проблема | Решение |
|----------|---------|
| YouTube не открывается | Смени стратегию через веб-панель |
| Нет интернета после настройки | Проверь: `sudo iptables -t nat -L` и `sysctl net.ipv4.ip_forward` |
| nfqws не запущен | `sudo systemctl restart zapret && journalctl -u zapret -e` |
| Высокий пинг в играх | Используй стратегию «HostFakeSplit» (минимальная) |
| PS5 не подключается | Убедись что шлюз = IP малинки |

| Веб-панель не открывается | `sudo systemctl restart zapret-web` |

---

## ❓ FAQ

**Q: Это VPN?**
Нет. Zapret работает локально — модифицирует пакеты так, чтобы DPI провайдера не мог их распознать. Трафик идёт напрямую, без серверов-посредников. Пинг не увеличивается.

**Q: Замедляет ли интернет?**
Нет. Zapret обрабатывает только первые 6-12 пакетов каждого соединения (хэндшейк). Остальной трафик проходит без обработки.

**Q: Работает с любым провайдером?**
У каждого провайдера свой DPI. Поэтому нужно подобрать стратегию — используй `blockcheck.sh` или переключай стратегии в веб-панели.

**Q: Можно использовать без Raspberry Pi?**
Да, скрипт работает на любом Debian/Ubuntu. Можно использовать VPS, старый ПК, или любой ARM SBC.

---

## 🤝 Contributing

1. Fork репозитория
2. Создай ветку: `git checkout -b feature/my-feature`
3. Commit: `git commit -m 'Add my feature'`
4. Push: `git push origin feature/my-feature`
5. Открой Pull Request

Нашёл рабочую стратегию для своего провайдера? Поделись в [Issues](https://github.com/nmazarov/zapret-pi/issues)!

---

## 📄 Лицензия

MIT License — см. [LICENSE](LICENSE)

---

## 🙏 Credits

- [Zapret](https://github.com/bol-van/zapret) by bol-van — ядро DPI bypass

---

> ⚠️ **Дисклеймер:** Проект предоставлен в образовательных целях. Использование может нарушать условия вашего провайдера.
