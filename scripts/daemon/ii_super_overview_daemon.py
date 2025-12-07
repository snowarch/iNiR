#!/usr/bin/env python3

import asyncio
import os
import subprocess
import time

from evdev import InputDevice, categorize, ecodes, list_devices

SUPER_CODES = {ecodes.KEY_LEFTMETA, ecodes.KEY_RIGHTMETA}

POINTER_BUTTON_CODES = {
    ecodes.BTN_LEFT,
    ecodes.BTN_RIGHT,
    ecodes.BTN_MIDDLE,
    ecodes.BTN_SIDE,
    ecodes.BTN_EXTRA,
    ecodes.BTN_FORWARD,
    ecodes.BTN_BACK,
}

# Debounce window (seconds) to coalesce multiple duplicate events from
# several devices (physical + virtual keyboards).
DEBOUNCE_SEC = 0.25
last_toggle_time = 0.0

super_down_global = False
interaction_since_super_down = False
tap_handled = False

# Cache of ii's environment so we don't hit /proc on every tap.
II_ENV_CACHE = {}
II_ENV_PID = None


def _find_ii_pid():
    """Locate the PID of the `qs -c ii` process by inspecting /proc."""
    proc_root = "/proc"
    for entry in os.listdir(proc_root):
        if not entry.isdigit():
            continue
        pid = int(entry)
        cmdline_path = f"{proc_root}/{entry}/cmdline"
        try:
            with open(cmdline_path, "rb") as f:
                raw = f.read().decode("utf-8", errors="ignore")
        except FileNotFoundError:
            continue
        if not raw:
            continue
        args = [a for a in raw.split("\0") if a]
        if len(args) < 3:
            continue
        exe = os.path.basename(args[0])
        if exe != "qs":
            continue
        if args[1] == "-c" and args[2] == "ii":
            return pid
    return None


def get_ii_env():
    """Get relevant environment variables from the running `qs -c ii`
    session to reuse them when calling IPC.

    Caches the environment while the PID stays the same to reduce
    perceived latency for Super taps.
    """
    global II_ENV_CACHE, II_ENV_PID
    try:
        pid = _find_ii_pid()
        if pid is None:
            print("[ii-super-daemon] ii not running, cannot import env", flush=True)
            II_ENV_CACHE = {}
            II_ENV_PID = None
            return {}

        if II_ENV_PID == pid and II_ENV_CACHE:
            return II_ENV_CACHE

        print(f"[ii-super-daemon] Found ii pid={pid}", flush=True)
        environ_path = f"/proc/{pid}/environ"
        with open(environ_path, "rb") as f:
            raw = f.read().decode("utf-8", errors="ignore")
        env_vars = {}
        for entry in raw.split("\0"):
            if not entry or "=" not in entry:
                continue
            k, v = entry.split("=", 1)
            # Only keep what matters for Wayland / Qt
            if k in ("WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "QT_QPA_PLATFORM", "NIRI_SOCKET"):
                env_vars[k] = v
        II_ENV_CACHE = env_vars
        II_ENV_PID = pid
        print(f"[ii-super-daemon] Imported env from ii: {env_vars}", flush=True)
        return II_ENV_CACHE
    except Exception as e:
        print(f"[ii-super-daemon] Error reading ii env: {e}", flush=True)
        return {}


def find_keyboard_devices():
    keyboards = []
    pointers = []
    for path in list_devices():
        try:
            dev = InputDevice(path)
            caps = dev.capabilities().get(ecodes.EV_KEY, [])
        except Exception as e:
            print(f"[ii-super-daemon] Error inspecting {path}: {e}", flush=True)
            continue

        name = (dev.name or "").lower()

        # Ignore clearly virtual devices (ydotoold, etc.) to avoid echo.
        if "ydotool" in name or "virtual" in name:
            continue

        has_super = any(code in SUPER_CODES for code in caps)
        has_pointer_button = any(code in POINTER_BUTTON_CODES for code in caps)

        if has_super:
            print(f"[ii-super-daemon] Using keyboard device {path} ({dev.name}), has_super={has_super}", flush=True)
            keyboards.append(path)

        if has_pointer_button:
            print(f"[ii-super-daemon] Using pointer device {path} ({dev.name}), has_pointer_button={has_pointer_button}", flush=True)
            pointers.append(path)

    if not keyboards:
        print("[ii-super-daemon] No suitable keyboard devices found", flush=True)

    return keyboards, pointers


async def monitor_device(path):
    global super_down_global, interaction_since_super_down, last_toggle_time, tap_handled
    dev = InputDevice(path)
    super_down = False
    chord = False

    async for event in dev.async_read_loop():
        if event.type != ecodes.EV_KEY:
            continue

        key_event = categorize(event)
        code = key_event.scancode
        value = key_event.keystate  # 1=down, 2=hold, 0=up

        if code in SUPER_CODES:
            if value == key_event.key_down:
                super_down = True
                chord = False
                super_down_global = True
                interaction_since_super_down = False
                tap_handled = False
            elif value == key_event.key_up:
                if super_down and not chord and not interaction_since_super_down and not tap_handled:
                    # Tap of Super with no other keys or clicks: toggle ii overview
                    # with a global debounce so multiple devices don't double-trigger.
                    now = time.monotonic()
                    if now - last_toggle_time >= DEBOUNCE_SEC:
                        last_toggle_time = now
                        tap_handled = True
                        print("[ii-super-daemon] Super tap detected, toggling ii overview", flush=True)
                        try:
                            ii_env = get_ii_env()
                            if not ii_env:
                                print("[ii-super-daemon] No ii env available, skipping toggle", flush=True)
                                super_down = False
                                super_down_global = False
                                interaction_since_super_down = False
                                continue

                            env = os.environ.copy()
                            env.update(ii_env)

                            subprocess.Popen(
                                [
                                    "qs",
                                    "-c",
                                    "ii",
                                    "ipc",
                                    "call",
                                    "overview",
                                    "toggle",
                                ],
                                env=env,
                                stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL,
                            )
                        except Exception as e:
                            print(f"[ii-super-daemon] Error running toggle command: {e}", flush=True)
                super_down = False
                chord = False
                super_down_global = False
                interaction_since_super_down = False
            continue

        # Any other key while Super is down marks this as a chord.
        if super_down and value == key_event.key_down:
            chord = True
        if super_down_global and value == key_event.key_down:
            interaction_since_super_down = True


async def monitor_pointer_device(path):
    dev = InputDevice(path)

    async for event in dev.async_read_loop():
        if event.type != ecodes.EV_KEY:
            continue

        key_event = categorize(event)
        code = key_event.scancode
        value = key_event.keystate

        if code in POINTER_BUTTON_CODES and value == key_event.key_down:
            global interaction_since_super_down
            if super_down_global:
                interaction_since_super_down = True


async def main():
    # Retry keyboard detection until we have at least one device with Super,
    # so the service still works if it starts before the session is fully up.
    keyboard_paths = []
    pointer_paths = []
    while not keyboard_paths:
        keyboard_paths, pointer_paths = find_keyboard_devices()
        if keyboard_paths:
            break
        print("[ii-super-daemon] No keyboards with Super yet, retrying in 5s", flush=True)
        await asyncio.sleep(5)

    tasks = [asyncio.create_task(monitor_device(p)) for p in keyboard_paths]
    tasks.extend(asyncio.create_task(monitor_pointer_device(p)) for p in pointer_paths)
    await asyncio.gather(*tasks)


if __name__ == "__main__":
    asyncio.run(main())
