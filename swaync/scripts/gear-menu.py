#!/usr/bin/env python3
"""Rofi settings menu for the SwayNC gear button."""

from __future__ import annotations

import json
import subprocess
import sys


def run(cmd: list[str], input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, input=input_text, capture_output=True, text=True)


def mullvad_connected() -> bool:
    result = run(["mullvad", "status", "-j"])
    try:
        state = json.loads(result.stdout).get("state", "")
    except json.JSONDecodeError:
        return False
    return state in ("connected", "connecting")


def main() -> int:
    subprocess.run(["swaync-client", "-cp"], check=False)

    vpn_on = mullvad_connected()
    vpn_label = "󰖂  Mullvad disconnect" if vpn_on else "󰖂  Mullvad connect"

    choices = [
        "󰖩  Wi-Fi networks",
        "󰲝  Advanced network",
        vpn_label,
        "󰏖  Mullvad app",
        "  Lock",
    ]
    pick = run(["rofi", "-dmenu", "-i", "-p", "Settings"], input_text="\n".join(choices))
    if pick.returncode != 0:
        return 0
    choice = pick.stdout.rstrip("\n")
    if not choice:
        return 0

    if choice.endswith("Wi-Fi networks"):
        subprocess.run(["/home/vegapunk/.config/swaync/scripts/wifi-menu.py"], check=False)
    elif choice.endswith("Advanced network"):
        subprocess.run(["ghostty", "--class=org.nmtui.nmtui", "-e", "nmtui"], check=False)
    elif "Mullvad disconnect" in choice:
        subprocess.run(["mullvad", "disconnect"], check=False)
    elif "Mullvad connect" in choice:
        subprocess.run(["mullvad", "connect"], check=False)
    elif choice.endswith("Mullvad app"):
        subprocess.run(["mullvad-vpn"], check=False)
    elif choice.endswith("Lock"):
        subprocess.run(["swaylock"], check=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
