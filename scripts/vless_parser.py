#!/usr/bin/env python3
"""
VLESS Link Parser & Xray SmartDNS Generator for Zapret-Pi.
Converts any vless:// URL into a complete /usr/local/etc/xray/config.json with KeepAlive & SmartDNS.
"""

import json
import os
import sys
import urllib.parse


def parse_vless_url(vless_url: str) -> dict:
    vless_url = vless_url.strip()
    if not vless_url.startswith("vless://"):
        raise ValueError("Ссылка должна начинаться с vless://")

    raw = vless_url[8:]
    if "#" in raw:
        main_part, remark = raw.split("#", 1)
        remark = urllib.parse.unquote(remark)
    else:
        main_part, remark = raw, "VLESS-Server"

    if "?" in main_part:
        user_host_part, query_part = main_part.split("?", 1)
        params = dict(urllib.parse.parse_qsl(query_part))
    else:
        user_host_part, params = main_part, {}

    if "@" not in user_host_part:
        raise ValueError("В VLESS ссылке отсутствует UUID (формат: uuid@host:port)")

    uuid, host_port = user_host_part.split("@", 1)

    if ":" in host_port:
        server_addr, server_port_str = host_port.rsplit(":", 1)
        server_port = int(server_port_str)
    else:
        server_addr = host_port
        server_port = 443

    net_type = params.get("type", "tcp")
    security = params.get("security", "none")
    sni = params.get("sni") or params.get("host") or server_addr
    path = urllib.parse.unquote(params.get("path", "/"))
    pbk = params.get("pbk", "")
    fp = params.get("fp", "chrome")
    sid = params.get("sid", "")
    flow = params.get("flow", "")

    outbound = {
        "tag": "VLESS-OUT",
        "protocol": "vless",
        "settings": {
            "vnext": [{
                "address": server_addr,
                "port": server_port,
                "users": [{
                    "id": uuid,
                    "encryption": "none",
                    "flow": flow
                }]
            }]
        },
        "streamSettings": {
            "network": net_type,
            "security": security,
            "sockopt": {
                "tcpKeepAliveIdle": 15,
                "tcpKeepAliveInterval": 5,
                "tcpUserTimeout": 10000
            }
        }
    }

    if net_type == "ws":
        outbound["streamSettings"]["wsSettings"] = {
            "path": path,
            "headers": {"Host": sni}
        }
    elif net_type == "grpc":
        outbound["streamSettings"]["grpcSettings"] = {
            "serviceName": params.get("serviceName", "")
        }

    if security == "tls":
        outbound["streamSettings"]["tlsSettings"] = {
            "serverName": sni,
            "allowInsecure": False,
            "fingerprint": fp
        }
    elif security == "reality":
        outbound["streamSettings"]["realitySettings"] = {
            "serverName": sni,
            "publicKey": pbk,
            "shortId": sid,
            "fingerprint": fp,
            "spiderX": params.get("spx", "")
        }

    config = {
        "log": {"loglevel": "warning"},
        "dns": {"servers": ["8.8.8.8", "1.1.1.1"]},
        "inbounds": [
            {
                "tag": "dns-in",
                "port": 53,
                "listen": "0.0.0.0",
                "protocol": "dokodemo-door",
                "settings": {
                    "address": "8.8.8.8",
                    "port": 53,
                    "network": "tcp,udp"
                }
            },
            {
                "tag": "socks-in",
                "port": 10808,
                "listen": "0.0.0.0",
                "protocol": "socks",
                "settings": {
                    "auth": "noauth",
                    "udp": True
                }
            },
            {
                "tag": "http-in",
                "port": 10809,
                "listen": "0.0.0.0",
                "protocol": "http"
            }
        ],
        "outbounds": [
            outbound,
            {"tag": "direct", "protocol": "freedom"}
        ],
        "routing": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [
                {
                    "type": "field",
                    "inboundTag": ["dns-in"],
                    "outboundTag": "VLESS-OUT"
                }
            ]
        }
    }

    return config


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Использование: python3 vless_parser.py 'vless://...' [/path/to/output/config.json]")
        sys.exit(1)

    url = sys.argv[1]
    out_file = sys.argv[2] if len(sys.argv) > 2 else "/usr/local/etc/xray/config.json"

    try:
        cfg = parse_vless_url(url)
        os.makedirs(os.path.dirname(out_file), exist_ok=True)
        with open(out_file, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
        print(f"[OK] Конфигурация VLESS успешно сохранена в {out_file}")
    except Exception as err:
        print(f"[ОШИБКА] Не удалось обработать VLESS ссылку: {err}")
        sys.exit(1)
