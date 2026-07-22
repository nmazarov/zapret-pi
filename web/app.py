#!/opt/zapret-web/venv/bin/python3
"""
Zapret Web Management API
Flask backend for managing zapret DPI bypass service on Raspberry Pi.
"""

import json
import logging
import os
import re
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ZAPRET_CONFIG = "/opt/zapret/config"
STRATEGIES_FILE = "/opt/zapret-web/strategies.json"
BLOCKCHECK_SCRIPT = "/opt/zapret/blockcheck.sh"
DIAGNOSTICS_SCRIPT = "/opt/zapret-web/test-connection.sh"
LOG_FILE = "/var/log/zapret-web.log"
BLOCKCHECK_RESULT_FILE = "/tmp/blockcheck_result.txt"

app = Flask(__name__, static_folder="static", static_url_path="")

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("zapret-web")

# ---------------------------------------------------------------------------
# Default strategies
# ---------------------------------------------------------------------------
DEFAULT_STRATEGIES = {
    "universal_md5sig": {
        "name": "Universal MD5Sig",
        "description": "Универсальная стратегия с использованием MD5 подписей TCP. Хорошо работает с большинством провайдеров.",
        "args": "--dpi-desync=fake,split2 --dpi-desync-ttl=3 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1",
    },
    "ttl_based": {
        "name": "TTL Based",
        "description": "Стратегия на основе TTL. Подходит когда DPI расположен близко к клиенту.",
        "args": "--dpi-desync=fake,split2 --dpi-desync-ttl=2 --dpi-desync-autottl=2:64:3 --dpi-desync-split-pos=1",
    },
    "fakeddisorder": {
        "name": "Fake + Disorder",
        "description": "Fake-пакет с нарушением порядка сегментов. Эффективно против продвинутых DPI.",
        "args": "--dpi-desync=fake,disorder2 --dpi-desync-ttl=3 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1",
    },
    "hostfakesplit": {
        "name": "Host Fake Split",
        "description": "Разделение по заголовку Host с fake-пакетом. Классическая стратегия обхода.",
        "args": "--dpi-desync=fake,split2 --dpi-desync-ttl=4 --dpi-desync-fooling=md5sig --dpi-desync-split-http-req=host --dpi-desync-split-pos=1",
    },
    "multisplit_seqovl": {
        "name": "MultiSplit + SeqOvl",
        "description": "Множественное разделение с перекрытием sequence-номеров. Максимальная совместимость.",
        "args": "--dpi-desync=multisplit --dpi-desync-split-seqovl=2 --dpi-desync-ttl=3 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1,host+2",
    },
    "flowseal": {
        "name": "Flowseal (Discord + YouTube)",
        "description": "Комплексная стратегия Flowseal. Требует скачанные списки доменов.",
        "args": "--filter-udp=443 --hostlist=\"/opt/zapret-pi/lists/list-general.txt\" --hostlist=\"/opt/zapret-pi/lists/list-general-user.txt\" --hostlist-exclude=\"/opt/zapret-pi/lists/list-exclude.txt\" --hostlist-exclude=\"/opt/zapret-pi/lists/list-exclude-user.txt\" --ipset-exclude=\"/opt/zapret-pi/lists/ipset-exclude.txt\" --ipset-exclude=\"/opt/zapret-pi/lists/ipset-exclude-user.txt\" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic=\"/opt/zapret/files/fake/quic_initial_www_google_com.bin\" --new --filter-udp=19294-19344,50000-50100 --filter-l7=discord,stun --dpi-desync=fake --dpi-desync-fake-discord=\"/opt/zapret/files/fake/quic_initial_dbankcloud_ru.bin\" --dpi-desync-fake-stun=\"/opt/zapret/files/fake/quic_initial_dbankcloud_ru.bin\" --dpi-desync-repeats=6 --new --filter-tcp=2053,2083,2087,2096,8443 --hostlist-domains=discord.media --dpi-desync=multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-split-seqovl-pattern=\"/opt/zapret/files/fake/tls_clienthello_www_google_com.bin\" --new --filter-tcp=443 --hostlist=\"/opt/zapret-pi/lists/list-google.txt\" --ip-id=zero --dpi-desync=multisplit --dpi-desync-split-seqovl=681 --dpi-desync-split-pos=1 --dpi-desync-split-seqovl-pattern=\"/opt/zapret/files/fake/tls_clienthello_www_google_com.bin\" --new --filter-tcp=80,443 --hostlist=\"/opt/zapret-pi/lists/list-general.txt\" --hostlist=\"/opt/zapret-pi/lists/list-general-user.txt\" --hostlist-exclude=\"/opt/zapret-pi/lists/list-exclude.txt\" --hostlist-exclude=\"/opt/zapret-pi/lists/list-exclude-user.txt\" --ipset-exclude=\"/opt/zapret-pi/lists/ipset-exclude.txt\" --ipset-exclude=\"/opt/zapret-pi/lists/ipset-exclude-user.txt\" --dpi-desync=multisplit --dpi-desync-split-seqovl=568 --dpi-desync-split-pos=1 --dpi-desync-split-seqovl-pattern=\"/opt/zapret/files/fake/tls_clienthello_4pda_to.bin\" --new --filter-udp=443 --ipset=\"/opt/zapret-pi/lists/ipset-all.txt\" --hostlist-exclude=\"/opt/zapret-pi/lists/list-exclude.txt\" --hostlist-exclude=\"/opt/zapret-pi/lists/list-exclude-user.txt\" --ipset-exclude=\"/opt/zapret-pi/lists/ipset-exclude.txt\" --ipset-exclude=\"/opt/zapret-pi/lists/ipset-exclude-user.txt\" --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fake-quic=\"/opt/zapret/files/fake/quic_initial_www_google_com.bin\" --new --filter-tcp=80,443,8443 --ipset=\"/opt/zapret-pi/lists/ipset-all.txt\" --hostlist-exclude=\"/opt/zapret-pi/lists/list-exclude.txt\" --hostlist-exclude=\"/opt/zapret-pi/lists/list-exclude-user.txt\" --ipset-exclude=\"/opt/zapret-pi/lists/ipset-exclude.txt\" --ipset-exclude=\"/opt/zapret-pi/lists/ipset-exclude-user.txt\" --dpi-desync=multisplit --dpi-desync-split-seqovl=568 --dpi-desync-split-pos=1 --dpi-desync-split-seqovl-pattern=\"/opt/zapret/files/fake/tls_clienthello_4pda_to.bin\"",
    },
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _run(cmd: str, timeout: int = 15, shell: bool = True) -> tuple[int, str, str]:
    """Run a shell command and return (returncode, stdout, stderr)."""
    try:
        proc = subprocess.run(
            cmd,
            shell=shell,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except Exception as exc:
        return -1, "", str(exc)


def _load_strategies() -> dict:
    """Load strategies from JSON file, initialising with defaults if needed."""
    if os.path.exists(STRATEGIES_FILE):
        try:
            with open(STRATEGIES_FILE, "r", encoding="utf-8") as fh:
                data = json.load(fh)
                if data:
                    return data
        except (json.JSONDecodeError, OSError):
            pass
    # First run – seed with defaults
    _save_strategies(DEFAULT_STRATEGIES)
    return dict(DEFAULT_STRATEGIES)


def _save_strategies(strategies: dict) -> None:
    os.makedirs(os.path.dirname(STRATEGIES_FILE), exist_ok=True)
    with open(STRATEGIES_FILE, "w", encoding="utf-8") as fh:
        json.dump(strategies, fh, ensure_ascii=False, indent=2)


def _get_active_strategy_args() -> str:
    """Read current NFQWS_OPT from zapret config."""
    try:
        with open(ZAPRET_CONFIG, "r") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("NFQWS_OPT="):
                    val = line.split("=", 1)[1].strip().strip('"').strip("'")
                    return val
    except FileNotFoundError:
        pass
    return ""


def _get_cpu_temp() -> str:
    rc, out, _ = _run("cat /sys/class/thermal/thermal_zone0/temp", timeout=5)
    if rc == 0 and out.isdigit():
        return f"{int(out) / 1000:.1f}"
    return "N/A"


def _get_memory_info() -> dict:
    rc, out, _ = _run("free -m | awk '/Mem:/{print $2,$3,$4}'", timeout=5)
    if rc == 0 and out:
        parts = out.split()
        if len(parts) >= 3:
            total, used, free = int(parts[0]), int(parts[1]), int(parts[2])
            return {"total": total, "used": used, "free": free, "percent": round(used / total * 100, 1) if total else 0}
    return {"total": 0, "used": 0, "free": 0, "percent": 0}


def _get_load() -> str:
    rc, out, _ = _run("cat /proc/loadavg", timeout=5)
    if rc == 0 and out:
        return " ".join(out.split()[:3])
    return "N/A"


def _get_uptime() -> str:
    rc, out, _ = _run("uptime -p", timeout=5)
    return out if rc == 0 else "N/A"


def _get_network_stats() -> dict:
    """Return RX/TX bytes for default interface."""
    rc, iface, _ = _run("ip route | awk '/default/{print $5}' | head -1", timeout=5)
    if rc != 0 or not iface:
        iface = "eth0"
    stats = {"interface": iface, "rx_bytes": 0, "tx_bytes": 0}
    try:
        rx_path = f"/sys/class/net/{iface}/statistics/rx_bytes"
        tx_path = f"/sys/class/net/{iface}/statistics/tx_bytes"
        if os.path.exists(rx_path):
            with open(rx_path) as f:
                stats["rx_bytes"] = int(f.read().strip())
        if os.path.exists(tx_path):
            with open(tx_path) as f:
                stats["tx_bytes"] = int(f.read().strip())
    except (OSError, ValueError):
        pass
    return stats


def _get_connected_clients() -> list[dict]:
    """Parse ARP table for connected devices."""
    rc, out, _ = _run("arp -an", timeout=5)
    clients = []
    if rc == 0 and out:
        for line in out.splitlines():
            match = re.search(r"\((\d+\.\d+\.\d+\.\d+)\)\s+at\s+([\da-fA-F:]+)", line)
            if match:
                clients.append({"ip": match.group(1), "mac": match.group(2)})
    return clients


def _get_local_ip() -> str:
    rc, out, _ = _run("hostname -I | awk '{print $1}'", timeout=5)
    return out if rc == 0 and out else "192.168.1.1"


# ---------------------------------------------------------------------------
# Static file serving
# ---------------------------------------------------------------------------

@app.route("/")
def serve_index():
    return send_from_directory(app.static_folder, "index.html")


# ---------------------------------------------------------------------------
# API: Status
# ---------------------------------------------------------------------------

@app.route("/api/status")
def api_status():
    rc, out, _ = _run("systemctl is-active zapret", timeout=5)
    is_active = out == "active"

    return jsonify({
        "status": "active" if is_active else "stopped",
        "cpu_temp": _get_cpu_temp(),
        "memory": _get_memory_info(),
        "load": _get_load(),
        "uptime": _get_uptime(),
        "network": _get_network_stats(),
        "clients": _get_connected_clients(),
        "active_strategy_args": _get_active_strategy_args(),
        "local_ip": _get_local_ip(),
        "timestamp": datetime.now().isoformat(),
    })


# ---------------------------------------------------------------------------
# API: Service control
# ---------------------------------------------------------------------------

@app.route("/api/start", methods=["POST"])
def api_start():
    log.info("Starting zapret service")
    rc, out, err = _run("systemctl start zapret", timeout=30)
    ok = rc == 0
    if ok:
        log.info("zapret started successfully")
    else:
        log.error("Failed to start zapret: %s", err)
    return jsonify({"success": ok, "message": out or err})


@app.route("/api/stop", methods=["POST"])
def api_stop():
    log.info("Stopping zapret service")
    rc, out, err = _run("systemctl stop zapret", timeout=30)
    ok = rc == 0
    if ok:
        log.info("zapret stopped successfully")
    else:
        log.error("Failed to stop zapret: %s", err)
    return jsonify({"success": ok, "message": out or err})


@app.route("/api/restart", methods=["POST"])
def api_restart():
    log.info("Restarting zapret service")
    rc, out, err = _run("systemctl restart zapret", timeout=30)
    ok = rc == 0
    if ok:
        log.info("zapret restarted successfully")
    else:
        log.error("Failed to restart zapret: %s", err)
    return jsonify({"success": ok, "message": out or err})


# ---------------------------------------------------------------------------
# API: Strategies
# ---------------------------------------------------------------------------

@app.route("/api/strategies")
def api_strategies_list():
    strategies = _load_strategies()
    active_args = _get_active_strategy_args()
    return jsonify({"strategies": strategies, "active_args": active_args})


@app.route("/api/strategies", methods=["POST"])
def api_strategies_save():
    data = request.get_json(silent=True) or {}
    key = data.get("key", "").strip()
    name = data.get("name", "").strip()
    description = data.get("description", "").strip()
    args = data.get("args", "").strip()

    if not key or not name or not args:
        return jsonify({"success": False, "message": "key, name и args обязательны"}), 400

    # Sanitise key
    key = re.sub(r"[^a-zA-Z0-9_-]", "_", key)

    strategies = _load_strategies()
    strategies[key] = {"name": name, "description": description, "args": args}
    _save_strategies(strategies)
    log.info("Strategy saved: %s", key)
    return jsonify({"success": True, "message": f"Стратегия '{name}' сохранена"})


@app.route("/api/strategies/<key>", methods=["DELETE"])
def api_strategies_delete(key: str):
    strategies = _load_strategies()
    if key not in strategies:
        return jsonify({"success": False, "message": "Стратегия не найдена"}), 404
    del strategies[key]
    _save_strategies(strategies)
    log.info("Strategy deleted: %s", key)
    return jsonify({"success": True, "message": "Стратегия удалена"})


@app.route("/api/apply-strategy", methods=["POST"])
def api_apply_strategy():
    data = request.get_json(silent=True) or {}
    args = data.get("args", "").strip()
    if not args:
        return jsonify({"success": False, "message": "args обязательны"}), 400

    log.info("Applying strategy args: %s", args)

    # Clean single-line formatting for NFQWS_OPT
    clean_args = " ".join(args.split())
    
    # Safely replace NFQWS_OPT block in /opt/zapret/config
    config_path = ZAPRET_CONFIG
    new_lines = []
    in_opt_block = False
    opt_written = False

    if os.path.exists(config_path):
        try:
            with open(config_path, "r") as fh:
                for line in fh:
                    stripped = line.strip()
                    if stripped.startswith("NFQWS_OPT="):
                        new_lines.append(f'NFQWS_OPT="{clean_args}"\n')
                        opt_written = True
                        if line.rstrip().endswith('\\') or (stripped.startswith('NFQWS_OPT="') and not stripped.endswith('"')):
                            in_opt_block = True
                        continue

                    if in_opt_block:
                        if stripped.endswith('"') or stripped.endswith("'") or not line.rstrip().endswith('\\'):
                            in_opt_block = False
                        continue

                    new_lines.append(line)
        except OSError as exc:
            log.error("Failed to read config: %s", exc)

    if not opt_written:
        new_lines.append(f'NFQWS_OPT="{clean_args}"\n')

    try:
        with open(config_path, "w") as fh:
            fh.writelines(new_lines)
    except OSError as exc:
        log.error("Failed to write config: %s", exc)
        return jsonify({"success": False, "message": str(exc)}), 500

    # Restart zapret to apply changes
    rc, out, err = _run("systemctl restart zapret", timeout=30)
    ok = rc == 0
    if ok:
        log.info("Strategy applied and zapret restarted successfully")
    else:
        log.error("Failed to restart zapret after applying strategy: %s", err)
    return jsonify({"success": ok, "message": "Стратегия успешно применена и запущен zapret" if ok else f"Ошибка при перезапуске zapret: {err}"})


# ---------------------------------------------------------------------------
# API: Logs
# ---------------------------------------------------------------------------

@app.route("/api/logs")
def api_logs():
    rc, out, _ = _run("journalctl -u zapret --no-pager -n 200", timeout=10)
    return jsonify({"logs": out if rc == 0 else "Не удалось получить логи"})


# ---------------------------------------------------------------------------
# API: Gateway / Network status
# ---------------------------------------------------------------------------

@app.route("/api/gateway-status")
def api_gateway_status():
    _, nat, _ = _run("iptables -t nat -L -n -v 2>/dev/null", timeout=10)
    _, mangle, _ = _run("iptables -t mangle -L -n -v 2>/dev/null", timeout=10)
    _, fwd, _ = _run("cat /proc/sys/net/ipv4/ip_forward", timeout=5)
    return jsonify({
        "nat_rules": nat,
        "mangle_rules": mangle,
        "ip_forward": fwd.strip() == "1" if fwd else False,
    })


# ---------------------------------------------------------------------------
# API: Blockcheck
# ---------------------------------------------------------------------------
_blockcheck_lock = threading.Lock()
_blockcheck_running = False


def _run_blockcheck():
    global _blockcheck_running
    try:
        log.info("Starting blockcheck")
        proc = subprocess.run(
            ["bash", BLOCKCHECK_SCRIPT],
            capture_output=True,
            text=True,
            timeout=300,
        )
        with open(BLOCKCHECK_RESULT_FILE, "w") as fh:
            fh.write(proc.stdout)
            if proc.stderr:
                fh.write("\n--- STDERR ---\n")
                fh.write(proc.stderr)
        log.info("Blockcheck finished (rc=%d)", proc.returncode)
    except subprocess.TimeoutExpired:
        with open(BLOCKCHECK_RESULT_FILE, "w") as fh:
            fh.write("Blockcheck timed out after 5 minutes")
        log.error("Blockcheck timed out")
    except Exception as exc:
        with open(BLOCKCHECK_RESULT_FILE, "w") as fh:
            fh.write(f"Error: {exc}")
        log.error("Blockcheck error: %s", exc)
    finally:
        with _blockcheck_lock:
            _blockcheck_running = False


@app.route("/api/blockcheck", methods=["POST"])
def api_blockcheck():
    global _blockcheck_running
    with _blockcheck_lock:
        if _blockcheck_running:
            return jsonify({"success": False, "message": "Blockcheck уже запущен"})
        _blockcheck_running = True
    threading.Thread(target=_run_blockcheck, daemon=True).start()
    return jsonify({"success": True, "message": "Blockcheck запущен в фоне"})


@app.route("/api/blockcheck-result")
def api_blockcheck_result():
    with _blockcheck_lock:
        running = _blockcheck_running
    result = ""
    if os.path.exists(BLOCKCHECK_RESULT_FILE):
        with open(BLOCKCHECK_RESULT_FILE, "r") as fh:
            result = fh.read()
    return jsonify({"running": running, "result": result})



# ---------------------------------------------------------------------------
# API: Diagnostics & Target Tests
# ---------------------------------------------------------------------------

@app.route("/api/test-targets", methods=["GET", "POST"])
def api_test_targets():
    """Quick real-time connectivity test for key target services."""
    targets = {
        "discord": "https://discord.com",
        "youtube": "https://www.youtube.com",
        "ea_sports": "https://accounts.ea.com",
        "psn": "https://auth.api.sonycontain.com"
    }
    results = {}
    for name, url in targets.items():
        rc, out, _ = _run(f"curl -s -I --connect-timeout 3 -m 3 {url}", timeout=5)
        results[name] = (rc == 0 and "HTTP/" in out)
    
    # Calculate simple ping to 8.8.8.8
    rc_ping, out_ping, _ = _run("ping -c 1 -w 2 8.8.8.8 | awk -F'/' 'END{print $5}'", timeout=3)
    ping_val = out_ping.strip() if rc_ping == 0 and out_ping.strip() else "15"

    return jsonify({
        "success": True,
        "targets": results,
        "ping_ms": ping_val,
        "timestamp": datetime.now().isoformat()
    })


@app.route("/api/run-diagnostics", methods=["POST"])
def api_run_diagnostics():
    log.info("Running diagnostics")
    if not os.path.exists(DIAGNOSTICS_SCRIPT):
        return jsonify({"success": False, "result": "Скрипт диагностики не найден"})
    rc, out, err = _run(f"bash {DIAGNOSTICS_SCRIPT}", timeout=60)
    result = out if out else err
    return jsonify({"success": rc == 0, "result": result})


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    log.info("Zapret Web UI starting on 0.0.0.0:8080")
    app.run(host="0.0.0.0", port=8080, debug=False)
