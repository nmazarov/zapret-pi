<p align="center">
  <img src="https://img.shields.io/badge/🛡️-Zapret--Pi-blue?style=for-the-badge&labelColor=0d1117&color=58a6ff&logoColor=white" alt="Zapret-Pi" height="60"/>
</p>

<h1 align="center">🛡️ Zapret-Pi</h1>

<p align="center">
  <strong>Обход DPI + Блокировка рекламы на Raspberry Pi 4</strong><br/>
  Один скрипт — и все устройства в сети работают без ограничений
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License MIT"/>
  <img src="https://img.shields.io/badge/platform-Raspberry%20Pi%204-c51a4a?style=flat-square&logo=raspberry-pi" alt="Platform"/>
  <img src="https://img.shields.io/badge/language-Bash%20%7C%20Python-blue?style=flat-square" alt="Language"/>
  <img src="https://img.shields.io/badge/status-active-brightgreen?style=flat-square" alt="Status"/>
  <img src="https://img.shields.io/badge/zapret-v69+-orange?style=flat-square" alt="Zapret"/>
</p>

---

## 📋 Что это?

**Zapret-Pi** превращает Raspberry Pi 4 в сетевой шлюз, который:

- 🔓 **Обходит DPI-блокировки** (YouTube, Discord, Instagram, Twitter и др.)
- 🚫 **Блокирует рекламу** на всех устройствах через AdGuard Home
- 🌐 **Работает для всей сети** — PS5, ПК, Smart TV, телефоны
- ⚡ **Без VPN** — нативная скорость без потерь

> **Просто подключи устройство к Raspberry Pi и забудь о блокировках.**

---

## ✨ Возможности

| Функция | Описание |
|---------|----------|
| 🔓 Обход DPI | Zapret `nfqws` — фейковые пакеты, нарезка TLS, подмена SNI |
| 🚫 Блокировка рекламы | AdGuard Home — DNS-level фильтрация для всей сети |
| 🎮 PS5 / Xbox | Работает без настройки — достаточно указать DNS |
| 📺 Smart TV | Samsung, LG, Android TV — YouTube без тормозов |
| 🌐 Веб-панель | Управление через браузер на порте `8080` |
| 📊 Мониторинг | Grafana-дашборд с метриками на порте `3000` |
| 🔄 Стратегии | 5 предустановленных стратегий обхода + кастомные |
| 📋 Логирование | Полные логи nfqws, iptables, DNS-запросов |
| 🛡️ Auto-update | Автообновление списков блокировок |

---

## 🏗️ Архитектура

```
┌─────────────────────────────────────────────────────────┐
│                    Домашняя сеть                        │
│                                                         │
│   ┌─────┐  ┌─────┐  ┌──────────┐  ┌──────────────┐    │
│   │ PS5 │  │ PC  │  │ Smart TV │  │ Телефон/Планш│    │
│   └──┬──┘  └──┬──┘  └────┬─────┘  └──────┬───────┘    │
│      │        │           │               │             │
│      └────────┴─────┬─────┴───────────────┘             │
│                     │                                    │
│              ┌──────▼──────┐                            │
│              │   Роутер    │                            │
│              │ 192.168.1.1 │                            │
│              └──────┬──────┘                            │
│                     │                                    │
│           ┌─────────▼──────────┐                        │
│           │   Raspberry Pi 4   │                        │
│           │   192.168.1.10     │                        │
│           │                    │                        │
│           │  ┌──────────────┐  │                        │
│           │  │ AdGuard Home │  │  DNS: порт 53         │
│           │  │  (DNS + Ads) │  │  Веб: порт 8080      │
│           │  └──────┬───────┘  │                        │
│           │         │          │                        │
│           │  ┌──────▼───────┐  │                        │
│           │  │   iptables   │  │  NAT + NFQUEUE        │
│           │  │  (NFQUEUE)   │  │                        │
│           │  └──────┬───────┘  │                        │
│           │         │          │                        │
│           │  ┌──────▼───────┐  │                        │
│           │  │    nfqws     │  │  DPI bypass           │
│           │  │   (zapret)   │  │                        │
│           │  └──────┬───────┘  │                        │
│           │         │          │                        │
│           │  ┌──────▼───────┐  │                        │
│           │  │   Grafana    │  │  Мониторинг: 3000     │
│           │  └──────────────┘  │                        │
│           └────────────────────┘                        │
│                     │                                    │
│              ┌──────▼──────┐                            │
│              │  Интернет   │                            │
│              │   (ISP)     │                            │
│              └─────────────┘                            │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Быстрый старт

### Требования

- Raspberry Pi 4 (2GB+ RAM) с Raspberry Pi OS Lite (64-bit)
- Ethernet-подключение к роутеру
- SSH-доступ к Raspberry Pi

### Установка за 3 команды

```bash
git clone https://github.com/user/zapret-pi.git
cd zapret-pi
sudo ./install.sh
```

> **Установщик автоматически:**
> - Установит Zapret, AdGuard Home, Grafana
> - Настроит NAT, iptables, NFQUEUE
> - Применит оптимальную стратегию обхода
> - Запустит веб-панель управления

После установки откройте в браузере:

| Панель | Адрес | Назначение |
|--------|-------|------------|
| Веб-панель | `http://192.168.1.10:8080` | Управление Zapret-Pi |
| AdGuard Home | `http://192.168.1.10:3000` | DNS и блокировка рекламы |
| Grafana | `http://192.168.1.10:3001` | Мониторинг и метрики |

---

## ⚙️ Как это работает

### Обход DPI (Deep Packet Inspection)

Российские провайдеры используют **ТСПУ** (Технические Средства Противодействия Угрозам) для анализа и блокировки трафика. Zapret обходит это с помощью модификации пакетов на лету:

1. **Fake-пакеты** — отправка фальшивого ClientHello с TTL, который не дойдёт до сервера, но «обманет» DPI
2. **FakedSplit** — нарезка TLS-пакета так, что SNI оказывается разделён между фрагментами
3. **MD5 Signature Fooling** — добавление неверной TCP MD5 Signature Option, которую DPI проверяет, а сервер игнорирует
4. **Sequence Overlap** — перекрытие TCP sequence numbers для запутывания реассемблера DPI

```
Без Zapret:    [ClientHello: youtube.com] ──→ DPI ──✗ BLOCKED
С Zapret:      [Fake SNI] + [Split1][Split2] ──→ DPI ──→ ✓ OK
```

### Блокировка рекламы

AdGuard Home работает как DNS-сервер для всей сети. Все DNS-запросы проходят через него, и рекламные домены блокируются на уровне DNS — ещё до загрузки контента.

---

## 🎮 Настройка устройств

Достаточно указать Raspberry Pi как **DNS-сервер** (и, при необходимости, как **шлюз**) на устройстве:

| Устройство | DNS | Шлюз | Инструкция |
|------------|-----|------|------------|
| **PS5** | `192.168.1.10` | `192.168.1.10` | Настройки → Сеть → Настроить подключение → Вручную |
| **Windows PC** | `192.168.1.10` | `192.168.1.10` | Панель управления → Сетевые подключения → IPv4 |
| **macOS** | `192.168.1.10` | `192.168.1.10` | Системные настройки → Сеть → DNS |
| **Smart TV** | `192.168.1.10` | `192.168.1.10` | Настройки сети → Ручная настройка IP |
| **iPhone/Android** | `192.168.1.10` | — | Wi-Fi → Настройки сети → DNS (вручную) |
| **Роутер (всё)** | — | — | DHCP → DNS-сервер: `192.168.1.10` |

> 💡 **Совет:** Настройте DNS на роутере — тогда все устройства автоматически будут использовать Zapret-Pi.

---

## 🎯 Стратегии обхода

Zapret-Pi поставляется с 5 предустановленными стратегиями. Переключайте их через веб-панель или CLI:

| # | Стратегия | Описание | Для кого |
|---|-----------|----------|----------|
| 1 | **Универсальная (md5sig)** | Fake + FakedSplit + MD5Sig | Большинство провайдеров |
| 2 | **TTL-based** | Fake + MultiDisorder + TTL | Когда md5sig не работает |
| 3 | **FakedDisorder** | Перемешивание фейков в обратном порядке | Сложные DPI (ТСПУ v2) |
| 4 | **HostFakeSplit** | Минимальная — только hostname | Минимальное влияние на скорость |
| 5 | **MultiSplit + SeqOvl** | Множественная нарезка + SeqOvl | Самые жёсткие DPI |

### Переключение через CLI

```bash
# Посмотреть текущую стратегию
sudo zapret-pi status

# Сменить стратегию
sudo zapret-pi strategy universal_md5sig
sudo zapret-pi strategy ttl_based
sudo zapret-pi strategy fakeddisorder

# Тест стратегии на конкретном домене
sudo zapret-pi test youtube.com
```

### Кастомная стратегия

Отредактируйте файл `/opt/zapret-pi/config/default.conf`:

```bash
NFQWS_OPT="--filter-tcp=80,443 --dpi-desync=fake,fakedsplit --dpi-desync-fooling=md5sig ..."
```

---

## 🌐 Веб-панель

Веб-панель доступна на порте **8080** и позволяет:

- 📊 Видеть статус всех сервисов (Zapret, AdGuard, NAT)
- 🔄 Переключать стратегии обхода одним кликом
- 📋 Просматривать логи nfqws в реальном времени
- ✏️ Редактировать список доменов
- 🔧 Управлять настройками без SSH

**Grafana** на порте **3000** предоставляет:

- График DNS-запросов в секунду
- Статистику заблокированной рекламы
- Нагрузку на CPU/RAM Raspberry Pi
- Количество обработанных пакетов nfqws

---

## 🔧 Troubleshooting

| Проблема | Решение |
|----------|---------|
| YouTube не открывается | Проверь DNS: `nslookup youtube.com 192.168.1.10` |
| Видео буферится | Смени стратегию на `ttl_based` или `fakeddisorder` |
| Нет интернета | Проверь NAT: `sudo iptables -t nat -L` |
| nfqws не запускается | Проверь лог: `journalctl -u zapret -f` |
| Высокий пинг | Используй `hostfakesplit` (минимальное вмешательство) |
| PS5 не подключается | Проверь шлюз: должен быть IP Raspberry Pi |
| AdGuard не блокирует | Проверь, что DNS устройства указывает на Pi |
| Веб-панель недоступна | `sudo systemctl status zapret-web` |
| После обновления сломалось | `sudo zapret-pi reset && sudo zapret-pi apply` |
| Работает, но медленно | Проверь `htop` — возможно, мало RAM |

### Полезные команды

```bash
# Статус всех сервисов
sudo zapret-pi status

# Перезапуск всего
sudo zapret-pi restart

# Логи nfqws в реальном времени
sudo journalctl -u zapret -f

# Проверка iptables
sudo iptables -t nat -L -n -v
sudo iptables -t mangle -L -n -v

# Тест обхода
curl -v --resolve youtube.com:443:216.58.209.174 https://youtube.com
```

---

## ❓ FAQ

<details>
<summary><strong>Будет ли работать на Raspberry Pi 3?</strong></summary>

Технически да, но Pi 3 значительно медленнее. Для сети с 1–2 устройствами хватит, для 5+ рекомендуется Pi 4.
</details>

<details>
<summary><strong>Это VPN?</strong></summary>

Нет. Zapret-Pi не шифрует трафик и не туннелирует его через сторонний сервер. Весь трафик идёт напрямую к серверам назначения, но пакеты модифицируются на лету для обхода DPI.
</details>

<details>
<summary><strong>Замедлит ли это интернет?</strong></summary>

Практически нет. nfqws работает на уровне ядра и добавляет ~1-2ms задержки. Пропускная способность остаётся нативной (до 1 Gbps на Pi 4).
</details>

<details>
<summary><strong>Безопасно ли это?</strong></summary>

Zapret модифицирует только TCP/TLS-заголовки для обхода DPI. Содержимое трафика не изменяется. Однако использование инструментов обхода блокировок может противоречить законодательству вашей юрисдикции.
</details>

<details>
<summary><strong>Как добавить новый домен?</strong></summary>

Через веб-панель или вручную:
```bash
echo "newdomain.com" >> /opt/zapret-pi/config/hosts-blocked.txt
sudo zapret-pi reload
```
</details>

<details>
<summary><strong>Как обновить Zapret?</strong></summary>

```bash
cd /opt/zapret-pi
git pull
sudo ./install.sh --update
```
</details>

<details>
<summary><strong>Можно ли использовать с Wi-Fi?</strong></summary>

Можно, но Ethernet надёжнее и быстрее. При использовании Wi-Fi укажите `IFACE_WAN=wlan0` в конфиге.
</details>

---

## 🤝 Contributing

Вклад приветствуется! Вот как можно помочь:

1. 🍴 **Fork** — форкните репозиторий
2. 🌿 **Branch** — создайте ветку для фичи (`git checkout -b feature/my-feature`)
3. ✍️ **Commit** — закоммитьте изменения (`git commit -m 'feat: add my feature'`)
4. 📤 **Push** — запушьте ветку (`git push origin feature/my-feature`)
5. 🔀 **PR** — откройте Pull Request

### Что можно улучшить

- [ ] Поддержка Orange Pi / Banana Pi
- [ ] Автоопределение оптимальной стратегии
- [ ] Интеграция с Telegram-ботом для уведомлений
- [ ] Поддержка IPv6
- [ ] Docker-контейнер

---

## 📄 Лицензия

Этот проект распространяется под лицензией **MIT**. Подробности в файле [LICENSE](LICENSE).

---

## 🙏 Credits

- **[Zapret](https://github.com/bol-van/zapret)** by bol-van — ядро DPI bypass
- **[AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)** — DNS-фильтрация и блокировка рекламы
- **[Grafana](https://grafana.com/)** — мониторинг и визуализация

---

## ⚠️ Disclaimer

> Данный проект предоставляется «как есть» (**as is**) исключительно в образовательных и исследовательских целях.
>
> Авторы **не несут ответственности** за использование данного ПО в целях, противоречащих законодательству вашей страны. Перед использованием убедитесь, что это не нарушает применимые законы и правила.
>
> Проект **не аффилирован** с Zapret, AdGuard или Raspberry Pi Foundation.

---

<p align="center">
  <sub>Сделано с ❤️ для свободного интернета</sub>
</p>
