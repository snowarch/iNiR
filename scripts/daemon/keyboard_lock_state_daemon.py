#!/usr/bin/env python3

import argparse
import asyncio
import json
import sys

from evdev import InputDevice, ecodes, list_devices

IGNORED_NAME_PARTS = ("ydotool", "virtual")
RELEVANT_KEY_CODES = {ecodes.KEY_CAPSLOCK, ecodes.KEY_NUMLOCK}
RELEVANT_LED_CODES = {ecodes.LED_CAPSL, ecodes.LED_NUML}


class KeyboardLockMonitor:
    def __init__(self):
        self.devices = {}
        self.tasks = {}
        self.last_state = None

    def _is_candidate(self, dev):
        name = (dev.name or "").lower()
        if any(part in name for part in IGNORED_NAME_PARTS):
            return False

        caps = dev.capabilities()
        key_caps = set(caps.get(ecodes.EV_KEY, []))
        led_caps = set(caps.get(ecodes.EV_LED, []))
        return bool(key_caps & RELEVANT_KEY_CODES) and bool(led_caps & RELEVANT_LED_CODES)

    def _aggregate(self, values, previous):
        if not values:
            return previous if previous is not None else False

        true_count = sum(1 for value in values if value)
        false_count = len(values) - true_count
        if true_count == false_count:
            return previous if previous is not None else False
        return true_count > false_count

    def _snapshot(self):
        caps_values = []
        num_values = []

        for dev in self.devices.values():
            try:
                active_leds = set(dev.leds())
            except OSError:
                continue

            caps_values.append(ecodes.LED_CAPSL in active_leds)
            num_values.append(ecodes.LED_NUML in active_leds)

        if not caps_values and not num_values:
            return None

        previous_caps = self.last_state["caps"] if self.last_state is not None else None
        previous_num = self.last_state["num"] if self.last_state is not None else None
        return {
            "caps": self._aggregate(caps_values, previous_caps),
            "num": self._aggregate(num_values, previous_num),
            "devices": len(self.devices),
        }

    async def emit_state(self, force=False):
        state = self._snapshot()
        if state is None:
            return

        next_state = {"caps": state["caps"], "num": state["num"]}
        if force or next_state != self.last_state:
            print(json.dumps({"type": "state", **state}), flush=True)
        self.last_state = next_state

    async def refresh_devices(self):
        discovered = {}
        for path in list_devices():
            try:
                dev = InputDevice(path)
            except OSError:
                continue

            try:
                if not self._is_candidate(dev):
                    dev.close()
                    continue
            except OSError:
                dev.close()
                continue

            discovered[path] = dev

        removed_paths = [path for path in self.devices.keys() if path not in discovered]
        for path in removed_paths:
            task = self.tasks.pop(path, None)
            if task is not None:
                task.cancel()
            try:
                self.devices[path].close()
            except OSError:
                pass
            self.devices.pop(path, None)

        for path, dev in discovered.items():
            if path in self.devices:
                dev.close()
                continue

            self.devices[path] = dev
            self.tasks[path] = asyncio.create_task(self.monitor_device(path))

    async def monitor_device(self, path):
        dev = self.devices[path]
        try:
            async for event in dev.async_read_loop():
                if event.type == ecodes.EV_LED and event.code in RELEVANT_LED_CODES:
                    await self.emit_state()
                    continue

                if event.type == ecodes.EV_KEY and event.code in RELEVANT_KEY_CODES and event.value == 0:
                    await asyncio.sleep(0.03)
                    await self.emit_state()
        except asyncio.CancelledError:
            return
        except OSError:
            return

    async def run(self):
        await self.refresh_devices()
        if not self.devices:
            return 1

        await self.emit_state(force=True)

        while True:
            await asyncio.sleep(5)
            await self.refresh_devices()
            if self.devices:
                await self.emit_state()

    async def run_once(self):
        await self.refresh_devices()
        if not self.devices:
            return 1

        await self.emit_state(force=True)
        return 0

    async def close(self):
        for task in self.tasks.values():
            task.cancel()
        for task in list(self.tasks.values()):
            try:
                await task
            except asyncio.CancelledError:
                pass
        for dev in self.devices.values():
            try:
                dev.close()
            except OSError:
                pass


async def async_main(run_once):
    monitor = KeyboardLockMonitor()
    try:
        return await (monitor.run_once() if run_once else monitor.run())
    finally:
        await monitor.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()

    try:
        code = asyncio.run(async_main(args.once))
    except KeyboardInterrupt:
        code = 0
    except Exception as exc:
        print(json.dumps({"type": "error", "message": str(exc)}), file=sys.stderr, flush=True)
        code = 1

    raise SystemExit(code)


if __name__ == "__main__":
    main()
