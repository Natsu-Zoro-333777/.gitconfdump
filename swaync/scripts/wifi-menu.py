#!/usr/bin/env python3
"""Rofi Wi-Fi picker for SwayNC. Scans, lists unique SSIDs, connects."""

from __future__ import annotations

import subprocess
import sys


def run(cmd: list[str], input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        input=input_text,
        capture_output=True,
        text=True,
    )


def notify(title: str, body: str = "") -> None:
    subprocess.run(["notify-send", "-a", "Wi-Fi", title, body], check=False)


def unescape_nmcli(line: str) -> list[str]:
    parts: list[str] = []
    buf: list[str] = []
    escaped = False
    for ch in line:
        if escaped:
            buf.append(ch)
            escaped = False
        elif ch == "\\":
            escaped = True
        elif ch == ":":
            parts.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    parts.append("".join(buf))
    return parts


def wifi_scan() -> dict[str, dict[str, object]]:
    result = run(
        [
            "nmcli",
            "-t",
            "-f",
            "IN-USE,SIGNAL,SECURITY,SSID",
            "device",
            "wifi",
            "list",
            "--rescan",
            "yes",
        ]
    )
    best: dict[str, dict[str, object]] = {}
    for raw in result.stdout.splitlines():
        parts = unescape_nmcli(raw)
        if len(parts) < 4:
            continue
        in_use, signal, security, ssid = (
            parts[0],
            parts[1],
            parts[2],
            ":".join(parts[3:]),
        )
        if not ssid:
            continue
        try:
            sig = int(signal)
        except ValueError:
            sig = 0
        current = best.get(ssid)
        if current is None or sig > int(current["sig"]):
            best[ssid] = {
                "sig": sig,
                "sec": security,
                "in_use": in_use == "*",
            }
    return best


def saved_connections() -> set[str]:
    result = run(["nmcli", "-t", "-f", "NAME", "connection", "show"])
    return {line for line in result.stdout.splitlines() if line}


def rofi_pick(prompt: str, lines: str, password: bool = False) -> str | None:
    cmd = ["rofi", "-dmenu", "-i", "-p", prompt]
    if password:
        cmd.append("-password")
    result = run(cmd, input_text=lines)
    if result.returncode != 0:
        return None
    choice = result.stdout.rstrip("\n")
    return choice if choice else None


def connect(ssid: str, info: dict[str, object]) -> subprocess.CompletedProcess[str]:
    if ssid in saved_connections():
        result = run(["nmcli", "connection", "up", "id", ssid])
        if result.returncode == 0:
            return result
    result = run(["nmcli", "device", "wifi", "connect", ssid])
    if result.returncode == 0:
        return result
    if info["sec"] in ("", "--"):
        return result
    password = rofi_pick(f"Password for {ssid}", "")
    if password is None:
        sys.exit(0)
    return run(["nmcli", "device", "wifi", "connect", ssid, "password", password])


def main() -> int:
    subprocess.run(["swaync-client", "-cp"], check=False)

    networks = wifi_scan()
    if not networks:
        notify("No Wi-Fi networks found")
        return 0

    rows: list[tuple[str, str, dict[str, object]]] = []
    for ssid, info in sorted(networks.items(), key=lambda item: -int(item[1]["sig"])):
        security = str(info["sec"])
        sec_label = "open" if security in ("", "--") else security
        mark = "  ●" if info["in_use"] else ""
        display = f"{int(info['sig']):3d}%   {ssid}   ({sec_label}){mark}"
        rows.append((display, ssid, info))

    choice = rofi_pick("Wi-Fi", "\n".join(display for display, _, _ in rows))
    if choice is None:
        return 0

    match = next(((ssid, info) for display, ssid, info in rows if display == choice), None)
    if match is None:
        return 0

    ssid, info = match
    result = connect(ssid, info)
    if result.returncode == 0:
        notify("Connected", ssid)
        return 0

    err = (result.stderr or result.stdout).strip() or ssid
    notify("Failed to connect", err)
    return 1


if __name__ == "__main__":
    sys.exit(main())
