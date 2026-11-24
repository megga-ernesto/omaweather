"""Aplica blur a una sola capa mientras el panel lo solicita."""

import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import threading

stopped = threading.Event()


def hyprctl(*args):
    return subprocess.run(
        ["hyprctl", *args], check=True, capture_output=True, text=True, timeout=3
    ).stdout.strip()


def evaluate(lua):
    if hyprctl("eval", lua) != "ok":
        raise RuntimeError("Hyprland rejected the layer rule")


def main(namespace):
    if not re.fullmatch(r"omarchy-[a-z][a-z0-9-]{0,63}", namespace):
        raise ValueError("Invalid panel namespace")
    signal.signal(signal.SIGTERM, lambda *_: stopped.set())
    signal.signal(signal.SIGINT, lambda *_: stopped.set())
    lock_name = Path(os.environ["XDG_RUNTIME_DIR"]) / f"{namespace}-material.lock"
    fd = os.open(lock_name, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as lock:
        while not stopped.is_set():
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                stopped.wait(0.075)
        if stopped.is_set():
            return
        if not json.loads(hyprctl("-j", "getoption", "decoration:blur:enabled"))["bool"]:
            raise RuntimeError("Compositor blur disabled")
        # Tabla Lua en memoria del compositor. Una regla reutilizable por capa.
        slot = f'omaMaterialRules["{namespace}"]'
        try:
            evaluate(
                f'omaMaterialRules = omaMaterialRules or {{}}; if not {slot} then '
                f'{slot}=hl.layer_rule({{name="{namespace}-material",'
                f'match={{namespace="^{namespace}$"}},blur=true,ignore_alpha=0.3}}) end; '
                f'{slot}:set_enabled(true)'
            )
            stopped.wait()
        finally:
            evaluate(f'if omaMaterialRules and {slot} then {slot}:set_enabled(false) end')


if __name__ == "__main__":
    try:
        main(sys.argv[1])
    except (IndexError, OSError, KeyError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Panel blur: {error}", file=sys.stderr)
        sys.exit(1)
