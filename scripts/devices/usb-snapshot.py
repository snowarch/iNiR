#!/usr/bin/env python3
"""Print the USB devices plugged in right now as JSON, with a readable name and a kind.

Read from sysfs, so it needs no daemon. Hubs, root hubs and mass storage are left out:
storage is announced as a drive, with its label and size.
"""
import json
import os
import re

ROOT = "/sys/bus/usb/devices"
GENERIC = re.compile(r"^(usb|gaming|wireless|2\.4g|generic|hid)\b|receiver|device|composite", re.I)
JUNK = re.compile(r"demo|^uac\d*\b|^usb(\s*(device|audio|composite device))?$|^[0-9a-f]{4}$", re.I)
MODEL_CODE = re.compile(r"^(?=.*\d)(?=.*[a-z])[a-z0-9-]{4,14}$", re.I)
PAD = re.compile(r"pad|controller|joystick|dualsense|dualshock|xbox|8bitdo|joy-?con", re.I)
WEARABLE = re.compile(r"head(set|phone)|buds|earphone|airpods", re.I)
VENDOR_NOISE = re.compile(r"[,.]?\s*(co\.?|ltd\.?|inc\.?|corp(oration)?\.?|llc|gmbh|technology|technologies|electronics?|semiconductor|international|computer|limited)\b", re.I)


def read(path, name):
    try:
        with open(os.path.join(path, name), encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return ""


def short_vendor(vendor):
    cleaned = vendor
    for _ in range(3):
        cleaned = VENDOR_NOISE.sub("", cleaned).strip(" ,.-")
    return cleaned or vendor


def kind_of(interfaces, device_class, name):
    classes = [i[:2] for i in interfaces] or [device_class]
    if "09" in classes and len(set(classes)) == 1:
        return None
    for i in interfaces:
        if i.startswith("03") and i.endswith("02"):
            return "mouse"
        if i.startswith("03") and i.endswith("01"):
            return "keyboard"
    if any(i[:4] in ("ff5d", "ff47", "ff58") for i in interfaces) or ("03" in classes and PAD.search(name)):
        return "controller"
    if "08" in classes:
        return None
    if "0e" in classes:
        return "webcam"
    if "01" in classes:
        return "headset" if WEARABLE.search(name) else "audio"
    if "06" in classes or any(i.startswith("ff42") for i in interfaces):
        return "phone"
    if "e0" in classes and ("0a" in classes or "02" in classes):
        return "phone"
    if "e0" in classes:
        return "bluetooth"
    if "07" in classes:
        return "printer"
    if "0b" in classes:
        return "smartcard"
    if "02" in classes or "0a" in classes:
        return "serial"
    if "03" in classes:
        return "controller" if PAD.search(name) else "input"
    return "device"


def main():
    devices = []
    try:
        entries = sorted(os.listdir(ROOT))
    except OSError:
        entries = []
    for entry in entries:
        if ":" in entry or entry.startswith("usb"):
            continue
        path = os.path.join(ROOT, entry)
        vendor_id, product_id = read(path, "idVendor"), read(path, "idProduct")
        if not vendor_id:
            continue
        interfaces = []
        for sub in sorted(os.listdir(path)):
            if sub.startswith(entry + ":"):
                sub_path = os.path.join(path, sub)
                interfaces.append(read(sub_path, "bInterfaceClass") + read(sub_path, "bInterfaceSubClass") + read(sub_path, "bInterfaceProtocol"))
        manufacturer, product = read(path, "manufacturer"), read(path, "product")
        kind = kind_of([i.lower() for i in interfaces if len(i) == 6], read(path, "bDeviceClass").lower(), product)
        if kind is None:
            continue
        vendor = short_vendor(manufacturer)
        if not product or (vendor and JUNK.search(product)):
            name = vendor or product
        elif vendor and (GENERIC.search(product) or MODEL_CODE.match(product)) and vendor.lower() not in product.lower():
            name = f"{vendor} {product}"
        else:
            name = product
        devices.append({
            "id": f"{entry}/{vendor_id}:{product_id}",
            "name": " ".join(name.split()),
            "kind": kind,
        })
    print(json.dumps({"devices": devices}))


if __name__ == "__main__":
    main()
