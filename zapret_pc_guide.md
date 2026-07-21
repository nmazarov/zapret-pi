# 🖥️ Raspberry Pi: обход блокировок для ПК и других устройств

> Дополнение к основному гайду zapret_ps5_guide.md

---

## Краткий ответ

**Да**, тот же Raspberry Pi будет работать для ПК, телефонов, планшетов — любого устройства. Достаточно указать RPi как шлюз:

| Что | Как работает |
|-----|-------------|
| **Обход блокировок** (YouTube, Discord, Instagram...) | Zapret (`nfqws`) — уже настроен, работает для всего трафика через шлюз |

> [!IMPORTANT]  
> Zapret — это **не DNS-сервер** и не VPN. Он работает на уровне пакетов (DPI bypass). Достаточно указать Raspberry Pi как шлюз на устройстве — и весь трафик будет проходить через Zapret.

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

## Часть 2: Настройка ПК (Windows)

### 2.1 Через «Параметры сети»

1. **Win + I** → Сеть и Интернет → Ethernet (или Wi-Fi)
2. Нажми на своё подключение → **Редактировать** (рядом с «Назначение IP»)
3. Выбери **Вручную**, включи **IPv4**:

| Параметр | Значение |
|----------|----------|
| IP-адрес | `192.168.1.100` (любой свободный) |
| Маска подсети | `255.255.255.0` (`24`) |
| Шлюз | **`192.168.1.10`** ← Raspberry Pi |
| Предпочитаемый DNS | `8.8.8.8` |
| Дополнительный DNS | `8.8.4.4` |

4. Сохрани

### 2.2 Через PowerShell (от админа)

```powershell
# Узнай имя адаптера
Get-NetAdapter

# Настрой (замени "Ethernet" на имя своего адаптера)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.1.100 -PrefixLength 24 -DefaultGateway 192.168.1.10
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 8.8.8.8, 8.8.4.4
```

### 2.3 Проверка

```powershell
# Проверь шлюз
ipconfig

# Проверь маршрут (первый хоп = 192.168.1.10)
tracert youtube.com
```

> [!TIP]
> Если не хочешь настраивать каждое устройство вручную, измени настройки DHCP на роутере: **DHCP → Gateway = IP малинки**. Тогда все устройства в сети будут автоматически использовать Zapret.

---

## Часть 3: Настройка телефона (по Wi-Fi)

### Android

**Настройки → Wi-Fi → Долгое нажатие на сеть → Изменить → Дополнительно:**
- IP: Статический
- Шлюз: `192.168.1.10`
- DNS 1: `8.8.8.8`

### iPhone

**Настройки → Wi-Fi → (i) рядом с сетью:**
- Настройка IP: Вручную
- Маршрутизатор: `192.168.1.10`
- DNS: Вручную → `8.8.8.8`

---

## Часть 4: Итоговая архитектура

```
                                  Raspberry Pi 4
                              ┌────────────────────┐
  PS5 ─────────────────────▶  │                    │
  (шлюз: 192.168.1.10)       │  Zapret (nfqws)    │──── Обход DPI
                              │  порт NFQUEUE 200  │
  ПК  ─────────────────────▶  │                    │
  (шлюз: 192.168.1.10)       │  Веб-панель        │──── Управление
                              │  порт 8080         │     http://192.168.1.10:8080
  Телефон ─────────────────▶  │                    │
  (шлюз: 192.168.1.10)       └────────┬───────────┘
                                       │
                                       ▼
                                   Роутер (192.168.1.1) → Интернет
```

### Что получает каждое устройство

| Устройство | Шлюз | DNS | Обход DPI |
|------------|-------|-----|-----------|
| PS5 | RPi ✅ | Google (8.8.8.8) | ✅ Zapret |
| ПК | RPi ✅ | Google (8.8.8.8) | ✅ Zapret |
| Телефон | RPi ✅ | Google (8.8.8.8) | ✅ Zapret |

---

## FAQ

**Q: Это как VPN?**  
A: Нет. VPN шифрует и перенаправляет трафик через сервер за границей. Zapret работает **локально** — он модифицирует пакеты так, чтобы DPI провайдера не мог их правильно проанализировать. Трафик идёт напрямую, без третьих серверов. Поэтому **пинг не увеличивается** (важно для игр).

**Q: Будет ли замедление интернета?**  
A: Практически нет. RPi 4 на Gigabit Ethernet обрабатывает ~700-900 Мбит/с в режиме маршрутизации. Zapret обрабатывает только первые 6-12 пакетов каждого соединения, поэтому нагрузка минимальна.

**Q: Можно ли вернуть всё обратно?**  
A: Да, просто измени шлюз и DNS обратно на IP роутера (`192.168.1.1`) — и устройство снова работает напрямую через роутер.
