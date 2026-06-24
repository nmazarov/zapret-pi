# 🖥️ Raspberry Pi: обход блокировок для ПК + блокировка рекламы

> Дополнение к основному гайду zapret_ps5_guide.md

---

## Краткий ответ

**Да**, тот же Raspberry Pi будет работать для ПК, телефонов, планшетов — любого устройства. Достаточно указать RPi как шлюз. При этом:

| Что | Как работает |
|-----|-------------|
| **Обход блокировок** (YouTube, Discord, Instagram...) | Zapret (`nfqws`) — уже настроен, работает для всего трафика через шлюз |
| **Блокировка рекламы** | AdGuard Home — DNS-фильтр на том же RPi |

> [!IMPORTANT]  
> Zapret — это **не DNS-сервер** и не VPN. Он работает на уровне пакетов (DPI bypass). Для блокировки рекламы нужен отдельный инструмент — **AdGuard Home** (или Pi-hole). Оба ставятся на тот же Raspberry Pi.

---

## Часть 1: Расширение Zapret для YouTube и других сайтов

Zapret с параметром `--dpi-desync-any-protocol` уже обрабатывает **весь трафик**, проходящий через шлюз. Но если ты используешь `hostlist`, добавь туда заблокированные домены.

### 1.1 Расширенный hostlist

```bash
sudo nano /opt/zapret/ipset/zapret-hosts-user.txt
```

Добавь:

```
# === YouTube ===
youtube.com
youtu.be
googlevideo.com
ytimg.com
ggpht.com
googleapis.com
gstatic.com
youtube-nocookie.com
youtube-ui.l.google.com
wide-youtube.l.google.com

# === Google ===
google.com
google.ru
goog
gstatic.com
googleapis.com
googleusercontent.com

# === Discord ===
discord.com
discord.gg
discordapp.com
discord.media
discordcdn.com
discord-attachments-uploads-prd.storage.googleapis.com

# === Instagram / Facebook / Meta ===
instagram.com
cdninstagram.com
facebook.com
fbcdn.net
meta.com
threads.net
whatsapp.com

# === Twitter / X ===
twitter.com
x.com
twimg.com
t.co
abs.twimg.com

# === Spotify ===
spotify.com
spotifycdn.com
scdn.co
audio-sp-tyo.spotify.com

# === LinkedIn ===
linkedin.com
licdn.com

# === Другие ===
medium.com
archive.org
soundcloud.com
patreon.com
viber.com
telegra.ph

# === Игровые (EA, Steam и др.) ===
ea.com
origin.com
battlefield.com
eafc.com
steampowered.com
steamcommunity.com
epicgames.com

# === CDN (через них раздаётся контент) ===
akamaihd.net
akamai.net
cloudfront.net
fastly.net
cloudflare.com
```

```bash
# Перезапусти zapret, чтобы подхватил новый список
sudo systemctl restart zapret
```

> [!TIP]
> Если в конфиге стоит `--dpi-desync-any-protocol` без hostlist, zapret обрабатывает **весь** трафик и hostlist не обязателен. Но с hostlist-ом нагрузка на CPU будет ниже.

---

## Часть 2: Установка AdGuard Home (блокировка рекламы)

AdGuard Home — это DNS-сервер с фильтрацией рекламы, трекеров, malware. Работает на уровне DNS, поэтому блокирует рекламу **во всех приложениях** (не только в браузере).

### 2.1 Установка

```bash
# Скачай и запусти установщик
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
```

Или вручную:

```bash
cd /tmp
wget https://static.adguard.com/adguardhome/release/AdGuardHome_linux_armv7.tar.gz
tar -xzf AdGuardHome_linux_armv7.tar.gz
sudo mv AdGuardHome /opt/AdGuardHome
sudo /opt/AdGuardHome/AdGuardHome -s install
```

### 2.2 Первоначальная настройка

1. Открой в браузере: **http://192.168.1.10:3000**
2. Пройди мастер настройки:
   - **Веб-интерфейс**: порт `3000`
   - **DNS-сервер**: порт `53`, адрес `0.0.0.0`
   - Создай логин/пароль администратора

### 2.3 Настройка DNS-фильтров

После установки зайди в веб-панель AdGuard Home и добавь списки фильтров:

**Настройки → Фильтры → Списки фильтров DNS → Добавить:**

| Название | URL |
|----------|-----|
| AdGuard DNS filter | `https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt` |
| AdAway | `https://adaway.org/hosts.txt` |
| Peter Lowe's List | `https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus&showintro=1&mimetype=plaintext` |
| OISD Full | `https://big.oisd.nl` |
| RU AdList | `https://easylist-downloads.adblockplus.org/ruadlist+easylist.txt` |

### 2.4 Upstream DNS (куда перенаправлять нефильтрованные запросы)

**Настройки → DNS → Upstream DNS:**

```
# Encrypted DNS для приватности
https://dns.google/dns-query
https://cloudflare-dns.com/dns-query
tls://dns.google
tls://one.one.one.one
```

### 2.5 Проверка

```bash
# Статус сервиса
sudo systemctl status AdGuardHome

# Проверка DNS
dig @192.168.1.10 youtube.com
nslookup youtube.com 192.168.1.10

# Проверка блокировки рекламы (должен вернуть 0.0.0.0)
nslookup ad.doubleclick.net 192.168.1.10
```

---

## Часть 3: Настройка ПК (Windows)

### 3.1 Через «Параметры сети»

1. **Win + I** → Сеть и Интернет → Ethernet (или Wi-Fi)
2. Нажми на своё подключение → **Редактировать** (рядом с «Назначение IP»)
3. Выбери **Вручную**, включи **IPv4**:

| Параметр | Значение |
|----------|----------|
| IP-адрес | `192.168.1.100` (любой свободный) |
| Маска подсети | `255.255.255.0` (`24`) |
| Шлюз | **`192.168.1.10`** ← Raspberry Pi |
| Предпочитаемый DNS | **`192.168.1.10`** ← AdGuard Home |
| Дополнительный DNS | `8.8.8.8` |

4. Сохрани

### 3.2 Через PowerShell (от админа)

```powershell
# Узнай имя адаптера
Get-NetAdapter

# Настрой (замени "Ethernet" на имя своего адаптера)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.1.100 -PrefixLength 24 -DefaultGateway 192.168.1.10
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.1.10, 8.8.8.8
```

### 3.3 Проверка

```powershell
# Проверь шлюз
ipconfig

# Проверь маршрут (первый хоп = 192.168.1.10)
tracert youtube.com

# Проверь DNS — реклама блокируется?
nslookup ad.doubleclick.net
# Должен вернуть 0.0.0.0
```

---

## Часть 4: Настройка телефона (по Wi-Fi)

### Android

**Настройки → Wi-Fi → Долгое нажатие на сеть → Изменить → Дополнительно:**
- IP: Статический
- Шлюз: `192.168.1.10`
- DNS 1: `192.168.1.10`

### iPhone

**Настройки → Wi-Fi → (i) рядом с сетью:**
- Настройка IP: Вручную
- Маршрутизатор: `192.168.1.10`
- DNS: Вручную → `192.168.1.10`

---

## Часть 5: Итоговая архитектура

```
                                  Raspberry Pi 4
                              ┌────────────────────┐
  PS5 ─────────────────────▶  │                    │
  (шлюз: 192.168.1.10)       │  Zapret (nfqws)    │──── Обход DPI
                              │  порт NFQUEUE 200  │
  ПК  ─────────────────────▶  │                    │
  (шлюз: 192.168.1.10)       │  AdGuard Home      │──── Блокировка рекламы
  (DNS:  192.168.1.10)        │  DNS порт 53       │
                              │                    │
  Телефон ─────────────────▶  │  Веб-панель        │──── Управление
  (шлюз: 192.168.1.10)       │  порт 8080         │     http://192.168.1.10:8080
  (DNS:  192.168.1.10)        │                    │
                              │  AdGuard UI        │──── Статистика рекламы
                              │  порт 3000         │     http://192.168.1.10:3000
                              └────────┬───────────┘
                                       │
                                       ▼
                                   Роутер (192.168.1.1) → Интернет
```

### Что получает каждое устройство

| Устройство | Шлюз | DNS | Обход DPI | Блок рекламы |
|------------|-------|-----|-----------|-------------|
| PS5 | RPi ✅ | Google (8.8.8.8) | ✅ Zapret | ❌ нет |
| PS5 (с DNS RPi) | RPi ✅ | RPi (AdGuard) ✅ | ✅ Zapret | ✅ AdGuard |
| ПК | RPi ✅ | RPi (AdGuard) ✅ | ✅ Zapret | ✅ AdGuard |
| Телефон | RPi ✅ | RPi (AdGuard) ✅ | ✅ Zapret | ✅ AdGuard |

> [!TIP]
> Для PS5 тоже можно включить блокировку рекламы — просто измени DNS в настройках PS5 на `192.168.1.10` вместо `8.8.8.8`. Это уберёт рекламу в бесплатных играх и браузере PS5.

---

## FAQ

**Q: Это как VPN?**  
A: Нет. VPN шифрует и перенаправляет трафик через сервер за границей. Zapret работает **локально** — он модифицирует пакеты так, чтобы DPI провайдера не мог их правильно проанализировать. Трафик идёт напрямую, без третьих серверов. Поэтому **пинг не увеличивается** (важно для игр).

**Q: Будет ли замедление интернета?**  
A: Практически нет. RPi 4 на Gigabit Ethernet обрабатывает ~700-900 Мбит/с в режиме маршрутизации. Zapret обрабатывает только первые 6-12 пакетов каждого соединения, поэтому нагрузка минимальна.

**Q: YouTube рекламу тоже заблокирует?**  
A: AdGuard Home блокирует большую часть рекламы, но рекламу **внутри YouTube видео** полностью на уровне DNS заблокировать нельзя (Google отдаёт её с тех же серверов, что и видео). Для полной блокировки рекламы в YouTube на ПК используй расширение **uBlock Origin** в браузере.

**Q: Можно ли вернуть всё обратно?**  
A: Да, просто измени шлюз и DNS обратно на IP роутера (`192.168.1.1`) — и устройство снова работает напрямую через роутер.
