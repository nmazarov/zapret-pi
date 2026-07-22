<p align="center">
  <img src="https://img.shields.io/badge/🛡️-Zapret--Pi%202.0-blue?style=for-the-badge&labelColor=0d1117&color=10b981&logoColor=white" alt="Zapret-Pi 2.0" height="60"/>
</p>

<h1 align="center">🛡️ Zapret-Pi 2.0</h1>

<p align="center">
  <strong>Мощный сетевой шлюз обхода DPI и SmartDNS VLESS для Raspberry Pi & Windows</strong><br/>
  Полный доступ к EA Sports, Discord, YouTube 4K, PSN Network, Twitch на PS5, Smart TV, ПК и смартфонах
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License MIT"/>
  <img src="https://img.shields.io/badge/platform-Raspberry%20Pi%20%7C%20Windows-c51a4a?style=flat-square&logo=raspberry-pi" alt="Platform"/>
  <img src="https://img.shields.io/badge/VLESS-SmartDNS-blueviolet?style=flat-square" alt="VLESS SmartDNS"/>
  <img src="https://img.shields.io/badge/status-active-brightgreen?style=flat-square" alt="Status"/>
</p>

---

## 📋 Описание Проекта

**Zapret-Pi 2.0** превращает вашу Raspberry Pi в умный сетевой комбайн, поддерживающий 3 различных режима обхода любых блокировок ТСПУ/провайдеров:

1. ⚡ **Режим Zapret (DPI Bypass):** Локальная подмена пакетов на Raspberry Pi (без задействования сторонних серверов, пинг 0 мс).
2. 🚀 **Режим SmartDNS + VLESS (Нидерланды):** Возможность сменить **ТОЛЬКО DNS на консоли PS5**, направив заблокированные домены через шифрованный VLESS-туннель.
3. 🛡️ **Гибридный Режим (Zapret + SmartDNS VLESS):** Максимальная стабильность, сочетающая нативную скорость DPI bypass и гарантию пропуска через зашифрованный канал.

---

## 🎯 Сравнение Режимов для PS5 & Сети

| Режим | Настройки на PS5 | Игровой пинг | Требует VPS? |
| :--- | :--- | :--- | :--- |
| 🚀 **SmartDNS + VLESS** | **Только DNS (`<IP-Raspberry-Pi>`)** | Прямой (0 мс задержки) | 🟢 Да (Встроен VLESS) |
| ⚡ **Zapret DPI Bypass** | Шлюз + DNS (`<IP-Raspberry-Pi>`) | Нативный (0 мс задержки) | ❌ Нет |
| 🛡️ **Гибридный** | Шлюз + DNS (`<IP-Raspberry-Pi>`) | Нативный (0 мс задержки) | 🟢 Да |

---

## 🚀 Быстрый старт (Raspberry Pi)

### 1. Установка в 1 команду:

Подключитесь по SSH к вашей Raspberry Pi и выполните:

```bash
git clone https://github.com/nmazarov/zapret-pi.git
cd zapret-pi
sudo bash install.sh
```

> **Совет по ускоренной установке:** Если у вас зависает `apt update`, используйте быстрый флаг:  
> `sudo bash install.sh --skip-apt`

### 2. Откройте Веб-панель:

Перейдите со своего компьютера или смартфона по адресу:  
👉 **`http://<IP-Raspberry-Pi>:8080`** *(например, `http://192.168.0.178:8080`)*

В панели доступны:
- ⚡ **Экспресс-тест в 1 клик** (EA Sports, Discord, YouTube, PSN Network).
- 🚀 **Переключение режимов** (Гибридный / SmartDNS VLESS / Zapret).
- ⚙️ **Селектор проверенных стратегий DPI** (Flowseal ALT, MultiSplit, Fake+Disorder).
- 📊 **Мониторинг температуры ЦП, ОЗУ и логов**.

---

## 🎮 Настройка PlayStation 5 (Инструкция)

### Вариант 1: Смена ТОЛЬКО DNS (Режим SmartDNS VLESS)
> *Самый простой способ — IP и Шлюз остаются в автоматическом режиме.*

1. Зайдите в **PS5 ➔ Настройки ⚙️ ➔ Сеть ➔ Установить соединение с Интернетом**.
2. Нажмите `Options` на вашем подключении ➔ **Дополнительные настройки**.
3. Установите:
   - **IP-адрес**: `Автоматически`
   - **Основной DNS (Primary DNS)**: **`<IP-Raspberry-Pi>`** *(например, `192.168.0.178`)*
   - **Дополнительный DNS (Secondary DNS)**: `8.8.8.8`
   - **Основной шлюз**: `Автоматически`
   - **Прокси-сервер**: `Не использовать`

---

### Вариант 2: Полный Шлюз (Режим Zapret DPI Bypass)

1. Зайдите в **PS5 ➔ Настройки ⚙️ ➔ Сеть ➔ Дополнительные настройки**.
2. Установите **IP-адрес ➔ Вручную**:
   - **IP-адрес**: `Автоматически` (или свободный IP в вашей подсети)
   - **Основной шлюз (Gateway)**: **`<IP-Raspberry-Pi>`** *(например, `192.168.0.178`)*
   - **Основной DNS**: **`<IP-Raspberry-Pi>`** *(например, `192.168.0.178`)*
   - **Дополнительный DNS**: `8.8.8.8`

---

## 💻 Windows-версия (Обход DPI прямо на ПК)

Если вам нужен обход DPI локально на Windows без Raspberry Pi:

1. Перейдите в папку `windows/`.
2. Запустите `install.bat` **от имени администратора**.
3. Для управления и смены стратегий используйте интерактивное меню:
   ```cmd
   windows\menu.bat
   ```

---

## ⚙️ Управление Службами в Терминале

```bash
# Статус служб
systemctl status zapret
systemctl status xray
systemctl status zapret-web

# Перезапуск
sudo systemctl restart zapret
sudo systemctl restart xray
```

---

## 📄 Лицензия
Проект распространяется под лицензией MIT. Исходный код открыт и свободен для использования.
