#!/usr/bin/env python3
"""Build iNiR's sound packs from code.

Every sound here is synthesised (no samples, no recordings), so the packs are ours to ship and to change. Run
`python3 assets/sounds/generate.py [pack...]` from the repo to rewrite assets/sounds/<pack>/<event>.oga.
Needs numpy and ffmpeg built with libvorbis.

Packs: lounge (warm mallets and felt, a living-room console), orbit (air, sub and wide chords, a dashboard),
crystal (glass bells and sparkle), arcade (8-bit pulse and triangle).
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 48000
OUT = Path(__file__).resolve().parent
RNG = np.random.default_rng(7)

# Loudness of the loudest 50 ms, in dBFS RMS, per event: interface ticks sit low, alerts and the boot carry.
TARGET = {
    "navigate": -31, "volume": -27, "toggleOn": -27, "toggleOff": -28, "select": -26, "open": -27, "close": -28,
    "screenshot": -24, "error": -23, "deviceAdded": -24, "deviceRemoved": -25,
    "notification": -20, "notificationCritical": -18, "batteryLow": -20, "batteryCritical": -18, "batteryFull": -21,
    "powerPlug": -22, "powerUnplug": -23, "timerDone": -19, "pomodoroDone": -19,
    "boot": -17, "login": -19, "lock": -21,
}
EVENTS = list(TARGET)


# --- Primitives -------------------------------------------------------------------------------------------------
def note(n) -> float:
    if isinstance(n, (int, float)):
        return float(n)
    off = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}[n[0]]
    i = 1
    while i < len(n) and n[i] in "#b":
        off += 1 if n[i] == "#" else -1
        i += 1
    return 440.0 * 2 ** ((off + (int(n[i:]) - 4) * 12) / 12)


def T(d: float) -> np.ndarray:
    return np.arange(int(d * SR)) / SR


def fade(x: np.ndarray, a: float = 0.001, r: float = 0.006) -> np.ndarray:
    x = x.copy()
    na, nr = min(len(x), int(a * SR)), min(len(x), int(r * SR))
    if na:
        x[:na] *= np.linspace(0, 1, na)[:, None] if x.ndim == 2 else np.linspace(0, 1, na)
    if nr:
        x[-nr:] *= np.linspace(1, 0, nr)[:, None] if x.ndim == 2 else np.linspace(1, 0, nr)
    return x


def env(d: float, a: float = 0.003, decay: float = 0.2, hold: float = 0.0) -> np.ndarray:
    t = T(d)
    e = np.minimum(1.0, t / max(a, 1e-4)) * np.exp(-np.maximum(0.0, t - a - hold) / decay)
    return fade(e, 0, 0.004)


def swell(d: float, a: float, r: float) -> np.ndarray:
    """Rises over a, holds, falls over the last r seconds (raised cosine both ways)."""
    t = T(d)
    up = 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(a, 1e-4), 0, 1))
    down = 0.5 - 0.5 * np.cos(np.pi * np.clip((d - t) / max(r, 1e-4), 0, 1))
    return up * down


def glide(f0, f1, d: float) -> np.ndarray:
    return note(f0) * (note(f1) / note(f0)) ** np.linspace(0, 1, int(d * SR))


def phase(f, d: float) -> np.ndarray:
    """Phase of a pitch, fixed or a curve; a curve shorter than d holds its last pitch."""
    n = int(d * SR)
    if not isinstance(f, np.ndarray):
        return 2 * np.pi * np.cumsum(np.full(n, note(f))) / SR
    f = np.asarray(f, float)[:n]
    if len(f) < n:
        f = np.concatenate([f, np.full(n - len(f), f[-1])])
    return 2 * np.pi * np.cumsum(f) / SR


def sine(f, d: float) -> np.ndarray:
    return np.sin(phase(f, d))


def additive(f, d: float, amp_of_k, ceiling: float | None = None) -> np.ndarray:
    """A band-limited periodic wave: harmonic k at amp_of_k(k), none above Nyquist (of the highest pitch)."""
    p = phase(f, d)
    top = float(np.max(f)) if isinstance(f, np.ndarray) else note(f)
    out = np.zeros_like(p)
    for k in range(1, int((ceiling or SR * 0.45) / top) + 1):
        a = amp_of_k(k)
        if a:
            out += a * np.sin(k * p)
    return out


def saw(f, d: float, bright: float = 1.0) -> np.ndarray:
    return additive(f, d, lambda k: (1 / k) * (bright ** (k - 1)), ceiling=9000)


def pulse(f, d: float, duty: float = 0.5) -> np.ndarray:
    p = phase(f, d)
    top = float(np.max(f)) if isinstance(f, np.ndarray) else note(f)
    out = np.zeros_like(p)
    for k in range(1, int(SR * 0.45 / top) + 1):
        out += (2 / (k * np.pi)) * np.sin(k * np.pi * duty) * np.cos(k * p - k * np.pi * duty)
    return out * 0.8


def tri(f, d: float) -> np.ndarray:
    return additive(f, d, lambda k: 0 if k % 2 == 0 else (8 / np.pi ** 2) * ((-1) ** ((k - 1) // 2)) / k ** 2)


def partials(f, d: float, ratios, amps, decays, a: float = 0.002) -> np.ndarray:
    f, t = note(f), T(d)
    out = np.zeros_like(t)
    for r, am, dc in zip(ratios, amps, decays):
        if f * r < SR * 0.45:
            out += am * np.sin(2 * np.pi * f * r * t + RNG.uniform(0, 2 * np.pi)) * np.exp(-t / dc)
    return fade(out * np.minimum(1, t / a), 0, 0.004)


def fm(f, ratio: float, index: float, d: float, idx_decay: float, amp_decay: float, a: float = 0.002) -> np.ndarray:
    f, t = note(f), T(d)
    mod = index * np.exp(-t / idx_decay) * np.sin(2 * np.pi * f * ratio * t)
    return fade(np.sin(2 * np.pi * f * t + mod) * np.exp(-t / amp_decay) * np.minimum(1, t / a), 0, 0.004)


def noise(d: float) -> np.ndarray:
    return RNG.standard_normal(int(d * SR))


def band(x: np.ndarray, lo: float | None = None, hi: float | None = None, order: int = 2) -> np.ndarray:
    """Butterworth-shaped magnitude in the frequency domain (zero phase)."""
    n = len(x)
    if n == 0:
        return x
    fr = np.fft.rfftfreq(n, 1 / SR)
    h = np.ones_like(fr)
    if hi:
        h /= np.sqrt(1 + (fr / hi) ** (2 * order))
    if lo:
        h /= np.sqrt(1 + (lo / np.maximum(fr, 1e-3)) ** (2 * order))
    if x.ndim == 2:
        return np.stack([np.fft.irfft(np.fft.rfft(x[:, c]) * h, n) for c in range(2)], 1)
    return np.fft.irfft(np.fft.rfft(x) * h, n)


def sweep(d: float, f0: float, f1: float, q: float = 1.4, src: np.ndarray | None = None) -> np.ndarray:
    """Noise through a band that moves from f0 to f1 (overlap-added short spectra)."""
    n = int(d * SR)
    x = noise(d) if src is None else src[:n]
    win, hop = 1024, 256
    w = np.hanning(win)
    out = np.zeros(n + win)
    fr = np.fft.rfftfreq(win, 1 / SR)
    for s in range(0, n, hop):
        seg = np.zeros(win)
        chunk = x[s:s + win]
        seg[:len(chunk)] = chunk
        fc = f0 * (f1 / f0) ** (s / max(1, n))
        h = np.exp(-0.5 * ((fr - fc) / (fc / q)) ** 2)
        out[s:s + win] += np.fft.irfft(np.fft.rfft(seg * w) * h, win) * w
    return out[:n] / 1.5


def click(d: float = 0.008, lo: float = 1500, hi: float = 7000, tau: float = 0.0015) -> np.ndarray:
    return band(noise(d), lo, hi) * np.exp(-T(d) / tau)


def thump(f: float = 80, d: float = 0.12) -> np.ndarray:
    return np.sin(phase(glide(f * 1.8, f, d), d)) * env(d, 0.002, d / 3)


def chorus(f, d: float, cents: float = 7, voices: int = 3, wave=sine) -> np.ndarray:
    f = note(f)
    spread = np.linspace(-cents, cents, voices)
    return sum(wave(f * 2 ** (c / 1200), d) for c in spread) / voices


# --- Space ------------------------------------------------------------------------------------------------------
def stereo(x: np.ndarray, pan: float = 0.0) -> np.ndarray:
    if x.ndim == 2:
        return x
    a = (pan + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], 1) * np.sqrt(2)


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    n = len(x) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]


def reverb(x: np.ndarray, size: float = 1.4, damp: float = 5000, wet: float = 0.25, pre: float = 0.015) -> np.ndarray:
    """A plate of decaying, darkened, decorrelated noise per side."""
    x = stereo(x)
    t = T(size)
    out = []
    for c in range(2):
        ir = RNG.standard_normal(len(t)) * np.exp(-6.9 * t / size)
        ir = band(ir, 150, damp)
        ir = np.concatenate([np.zeros(int(pre * SR)), ir])
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        out.append(convolve(x[:, c], ir))
    wet_sig = np.stack(out, 1)
    dry = np.zeros_like(wet_sig)
    dry[:len(x)] = x
    return dry * (1 - wet * 0.5) + wet_sig * wet


def pingpong(x: np.ndarray, time: float = 0.11, fb: float = 0.45, mix: float = 0.35, taps: int = 6,
             damp: float = 7000) -> np.ndarray:
    x = stereo(x)
    lag = int(time * SR)
    out = np.zeros((len(x) + lag * taps, 2))
    out[:len(x)] += x
    tap = x.mean(1)
    for i in range(1, taps + 1):
        tap = band(tap, None, damp, 1) * fb
        side = i % 2
        out[lag * i:lag * i + len(tap), side] += tap * mix / fb
    return out


# --- Mixing -----------------------------------------------------------------------------------------------------
class Mix:
    def __init__(self) -> None:
        self.buf = np.zeros((0, 2))

    def add(self, x: np.ndarray, at: float = 0.0, pan: float = 0.0, gain: float = 1.0) -> "Mix":
        x = stereo(np.asarray(x, float), pan)
        s = int(at * SR)
        e = s + len(x)
        if e > len(self.buf):
            self.buf = np.concatenate([self.buf, np.zeros((e - len(self.buf), 2))])
        self.buf[s:e] += x * gain
        return self

    def __call__(self) -> np.ndarray:
        return self.buf


def finish(x: np.ndarray, event: str) -> np.ndarray:
    x = stereo(x)
    x = x - x.mean(0)
    # trim the tail once it is out of hearing over a room: interface sounds sooner, so a tick never lingers
    floor = -46 if TARGET[event] <= -24 else -58
    level = np.abs(x).max(1)
    above = np.nonzero(level > level.max() * 10 ** (floor / 20))[0]
    x = x[:above[-1] + 1] if len(above) else x
    x = fade(x, 0.0008, min(0.03, len(x) / SR / 4))
    win = int(0.05 * SR)
    power = np.convolve((x ** 2).mean(1), np.ones(win) / win, mode="same")
    loudest = 10 * np.log10(power.max() + 1e-12)
    x = x * 10 ** ((TARGET[event] - loudest) / 20)
    peak = np.abs(x).max()
    if peak > 0.89:  # -1 dBFS, a soft knee instead of a hard clip
        x = np.tanh(x / peak * 1.2) / np.tanh(1.2) * 0.89
    return x


# --- Lounge: mallets, felt and a warm pad -----------------------------------------------------------------------
def mallet(f, d: float = 0.55, bright: float = 1.0) -> np.ndarray:
    x = partials(f, d, [1, 3.93, 9.1, 0.5], [1, 0.3 * bright, 0.07 * bright, 0.14],
                 [d * 0.34, d * 0.085, d * 0.03, d * 0.22], a=0.0016)
    c = click(0.012, 700, 3800, 0.002) * 0.22 * bright
    x[:len(c)] += c
    return band(x, 60, 5200)


def lounge_pad(notes, d: float, a: float = 0.6, r: float = 1.2) -> np.ndarray:
    x = sum(chorus(n, d, cents=6, voices=3, wave=lambda f, dd: saw(f, dd, 0.82)) for n in notes) / len(notes)
    return band(x, 80, 1500) * swell(d, a, r)


def lounge(e: str) -> np.ndarray:
    m = Mix()
    if e == "navigate":
        m.add(mallet("C6", 0.16, 0.5))
    elif e == "select":
        m.add(mallet("E5", 0.3, 0.8)).add(mallet("B5", 0.34, 0.8), 0.045)
        return reverb(m(), 0.7, 4500, 0.16)
    elif e == "open":
        for i, n in enumerate(["C5", "G5", "E6"]):
            m.add(mallet(n, 0.32, 0.7), i * 0.038, pan=-0.25 + i * 0.25, gain=1 - i * 0.12)
        return reverb(m(), 0.9, 4500, 0.2)
    elif e == "close":
        for i, n in enumerate(["E6", "G5", "C5"]):
            m.add(mallet(n, 0.28, 0.55), i * 0.034, pan=0.25 - i * 0.25, gain=0.8 + i * 0.1)
        return reverb(m(), 0.8, 4000, 0.16)
    elif e == "toggleOn":
        m.add(mallet("A5", 0.22, 0.7)).add(mallet("E6", 0.26, 0.7), 0.035)
    elif e == "toggleOff":
        m.add(mallet("D6", 0.2, 0.6)).add(mallet("G5", 0.24, 0.6), 0.035)
    elif e == "volume":
        m.add(mallet("G5", 0.14, 0.55))
    elif e == "notification":
        m.add(mallet("A5", 0.9)).add(mallet("E6", 1.1), 0.095, pan=0.15)
        return reverb(m(), 1.4, 5000, 0.26)
    elif e == "notificationCritical":
        for i, n in enumerate(["E5", "G5", "E5"]):
            m.add(mallet(n, 0.5, 1.1), i * 0.14)
        m.add(mallet("C4", 0.9, 0.6), 0, gain=0.6)
        return reverb(m(), 1.2, 5000, 0.2)
    elif e == "error":
        m.add(mallet("E4", 0.34, 0.35)).add(mallet("Eb4", 0.5, 0.35), 0.12).add(thump(70, 0.16), 0, gain=0.5)
    elif e == "screenshot":
        m.add(click(0.01, 1800, 6500, 0.002)).add(click(0.012, 1200, 5000, 0.003), 0.055, gain=0.8)
        m.add(mallet("C6", 0.3, 0.5), 0.06, gain=0.5)
        return reverb(m(), 0.5, 6000, 0.12)
    elif e == "boot":
        m.add(lounge_pad(["C3", "G3", "D4", "E4", "B4"], 3.4, 0.9, 1.6), gain=0.55)
        for i, n in enumerate(["C4", "E4", "G4", "B4", "D5", "E5", "G5"]):
            m.add(mallet(n, 1.2, 0.8), 0.22 + i * 0.105, pan=-0.5 + i / 6, gain=0.75 + i * 0.03)
        m.add(mallet("D6", 1.6, 0.6), 1.12, pan=0.3, gain=0.6)
        m.add(mallet("C3", 2.2, 0.4), 0.2, gain=0.5)
        return reverb(m(), 2.4, 4200, 0.36, 0.02)
    elif e == "login":
        m.add(lounge_pad(["F3", "C4", "E4", "A4"], 1.9, 0.35, 1.1), gain=0.5)
        for i, n in enumerate(["F4", "A4", "C5", "E5"]):
            m.add(mallet(n, 0.9, 0.8), i * 0.075, pan=-0.3 + i * 0.2)
        m.add(mallet("G5", 1.0, 0.6), 0.36, pan=0.35, gain=0.6)
        return reverb(m(), 1.8, 4500, 0.3)
    elif e == "lock":
        m.add(mallet("G5", 0.7, 0.7)).add(mallet("C5", 0.9, 0.7), 0.13)
        m.add(lounge_pad(["C4", "G4"], 0.9, 0.1, 0.7), 0.1, gain=0.35)
        return reverb(m(), 1.2, 4000, 0.24)
    elif e == "batteryLow":
        m.add(mallet("A4", 0.6)).add(mallet("F4", 0.8), 0.17)
        return reverb(m(), 1.0, 4500, 0.18)
    elif e == "batteryCritical":
        for i, n in enumerate(["A4", "F4", "D4"]):
            m.add(mallet(n, 0.7, 1.1), i * 0.16)
        m.add(thump(60, 0.3), 0.32, gain=0.4)
        return reverb(m(), 1.1, 4500, 0.18)
    elif e == "batteryFull":
        for i, n in enumerate(["C5", "E5", "G5", "C6"]):
            m.add(mallet(n, 0.7), i * 0.075, pan=-0.3 + i * 0.2)
        return reverb(m(), 1.3, 5000, 0.24)
    elif e == "powerPlug":
        m.add(thump(90, 0.1), gain=0.6).add(mallet("G4", 0.4), 0.02).add(mallet("D5", 0.6), 0.09)
        return reverb(m(), 0.9, 4500, 0.18)
    elif e == "powerUnplug":
        m.add(mallet("D5", 0.4)).add(mallet("G4", 0.6), 0.09).add(thump(80, 0.1), 0.09, gain=0.5)
        return reverb(m(), 0.9, 4500, 0.16)
    elif e == "deviceAdded":
        m.add(mallet("C5", 0.35)).add(mallet("G5", 0.5), 0.065)
        return reverb(m(), 0.9, 4500, 0.18)
    elif e == "deviceRemoved":
        m.add(mallet("G5", 0.35)).add(mallet("C5", 0.5), 0.065)
        return reverb(m(), 0.9, 4500, 0.16)
    elif e == "timerDone":
        for rep in range(2):
            for i, n in enumerate(["G5", "E6", "C6", "G5"]):
                m.add(mallet(n, 0.6), rep * 0.86 + i * 0.16, pan=(-0.2, 0.2)[i % 2])
        return reverb(m(), 1.3, 5000, 0.22)
    elif e == "pomodoroDone":
        for i, n in enumerate(["C5", "E5", "G5", "C6", "E6"]):
            m.add(mallet(n, 1.0), i * 0.09, pan=-0.4 + i * 0.2)
        m.add(lounge_pad(["C4", "G4", "E5"], 1.6, 0.3, 1.0), 0.4, gain=0.35)
        return reverb(m(), 1.8, 5000, 0.28)
    return m()


# --- Orbit: air, sub and wide chords ----------------------------------------------------------------------------
def tone(f, d: float, a: float = 0.008, decay: float = 0.3, body: float = 0.3) -> np.ndarray:
    ph = phase(f, d)
    x = np.sin(ph) + body * np.sin(2 * ph) * 0.5 + 0.08 * np.sin(3 * ph)
    return x * env(d, a, decay)


def air(d: float, f0: float, f1: float, a: float, r: float, q: float = 1.3) -> np.ndarray:
    return sweep(d, f0, f1, q) * swell(d, a, r)


def orbit(e: str) -> np.ndarray:
    m = Mix()
    if e == "navigate":
        m.add(tone(1480, 0.07, 0.0015, 0.018, 0.1)).add(click(0.005, 4000, 9000, 0.0008), gain=0.25)
    elif e == "select":
        m.add(air(0.16, 600, 4200, 0.03, 0.1, 1.6), gain=0.7)
        m.add(tone(glide(880, 1320, 0.14), 0.14, 0.004, 0.06), 0.01)
        return reverb(m(), 0.7, 7000, 0.15)
    elif e == "open":
        m.add(air(0.26, 280, 2600, 0.06, 0.16, 1.2), gain=0.9)
        m.add(tone("E5", 0.36, 0.04, 0.16), 0.05, pan=-0.2, gain=0.5).add(tone("B5", 0.36, 0.04, 0.16), 0.07, pan=0.2, gain=0.4)
        return reverb(m(), 1.2, 6000, 0.24)
    elif e == "close":
        m.add(air(0.22, 2600, 300, 0.03, 0.15, 1.2), gain=0.85)
        m.add(tone("B4", 0.3, 0.02, 0.1), 0.03, gain=0.4)
        return reverb(m(), 1.0, 5500, 0.2)
    elif e == "toggleOn":
        m.add(tone(glide(660, 990, 0.09), 0.09, 0.002, 0.04)).add(click(0.005, 3000, 9000, 0.001), gain=0.2)
        return reverb(m(), 0.5, 7000, 0.12)
    elif e == "toggleOff":
        m.add(tone(glide(990, 660, 0.09), 0.09, 0.002, 0.04)).add(click(0.005, 3000, 9000, 0.001), gain=0.2)
        return reverb(m(), 0.5, 7000, 0.1)
    elif e == "volume":
        m.add(tone(740, 0.07, 0.002, 0.025, 0.2))
    elif e == "notification":
        m.add(air(0.35, 1200, 5200, 0.08, 0.25, 1.6), gain=0.35)
        m.add(tone("D6", 0.8, 0.006, 0.28), 0.02, pan=-0.15).add(tone("A6", 0.9, 0.006, 0.32), 0.12, pan=0.15, gain=0.8)
        return reverb(m(), 1.8, 7000, 0.34)
    elif e == "notificationCritical":
        for i in range(3):
            m.add(tone("A4", 0.3, 0.01, 0.09), i * 0.19).add(tone("E5", 0.3, 0.01, 0.09), i * 0.19, gain=0.7)
        m.add(air(0.6, 400, 2400, 0.05, 0.4, 1.2), 0, gain=0.3)
        return reverb(m(), 1.2, 6000, 0.22)
    elif e == "error":
        m.add(thump(70, 0.18)).add(band(noise(0.08), 150, 600) * env(0.08, 0.002, 0.02), 0, gain=0.4)
        m.add(thump(62, 0.2), 0.13, gain=0.9)
        return reverb(m(), 0.6, 3000, 0.12)
    elif e == "screenshot":
        m.add(air(0.14, 5200, 1200, 0.01, 0.1, 1.8), gain=0.8).add(click(0.008, 2500, 9000, 0.0015), 0.0, gain=0.6)
        return reverb(m(), 0.6, 7000, 0.14)
    elif e == "boot":
        d = 3.9
        sub = np.sin(phase(glide(38, 55, 2.0), 2.0)) * swell(2.0, 1.6, 0.4)
        m.add(sub, 0.0, gain=0.7)
        m.add(air(2.0, 140, 6500, 1.6, 0.25, 1.1), 0.0, gain=0.9)
        chord = ["E3", "B3", "E4", "F#4", "G#4", "B4", "E5"]
        for i, n in enumerate(chord):
            m.add(tone(n, d - 1.6, 0.05, 1.1 + i * 0.08, 0.25), 1.58 + i * 0.012, pan=-0.6 + i * 0.2, gain=0.42)
        for i, n in enumerate(["E6", "B6", "G#6"]):
            sh = chorus(n, 2.4, 9) * swell(2.4, 0.5, 1.8) * (1 + 0.25 * np.sin(2 * np.pi * 5.5 * T(2.4)))
            m.add(sh, 1.7 + i * 0.09, pan=(-0.5, 0.5, 0)[i], gain=0.12)
        m.add(thump(55, 0.5), 1.56, gain=0.6)
        return reverb(m(), 2.1, 6000, 0.38, 0.02)
    elif e == "login":
        m.add(tone(glide(330, 660, 0.42), 0.6, 0.03, 0.4, 0.2), 0, gain=0.5)
        m.add(air(0.5, 300, 4800, 0.35, 0.15, 1.3), 0, gain=0.6)
        for i, n in enumerate(["A4", "C#5", "E5", "A5"]):
            m.add(tone(n, 1.3, 0.02, 0.7), 0.36 + i * 0.02, pan=-0.45 + i * 0.3, gain=0.4)
        return reverb(m(), 2.0, 6500, 0.34)
    elif e == "lock":
        m.add(tone("E5", 0.5, 0.01, 0.25), 0, gain=0.5).add(tone("B4", 0.7, 0.01, 0.35), 0.1, gain=0.5)
        m.add(air(0.5, 3000, 260, 0.04, 0.35, 1.2), 0.05, gain=0.6).add(thump(60, 0.3), 0.1, gain=0.4)
        return reverb(m(), 1.6, 5000, 0.3)
    elif e == "batteryLow":
        m.add(tone("A5", 0.5, 0.01, 0.2)).add(tone("F5", 0.7, 0.01, 0.28), 0.18)
        return reverb(m(), 1.2, 6000, 0.24)
    elif e == "batteryCritical":
        for i, n in enumerate(["A5", "F5", "D5"]):
            m.add(tone(n, 0.5, 0.008, 0.2), i * 0.17)
        m.add(thump(55, 0.4), 0.34, gain=0.5)
        return reverb(m(), 1.2, 6000, 0.22)
    elif e == "batteryFull":
        m.add(air(0.4, 500, 5000, 0.2, 0.2, 1.4), 0, gain=0.4)
        for i, n in enumerate(["C5", "G5", "C6", "E6"]):
            m.add(tone(n, 0.9, 0.01, 0.4), 0.05 + i * 0.07, pan=-0.3 + i * 0.2, gain=0.7)
        return reverb(m(), 1.8, 7000, 0.32)
    elif e == "powerPlug":
        m.add(thump(85, 0.14), gain=0.7).add(tone(glide(392, 587, 0.18), 0.4, 0.01, 0.18), 0.03)
        return reverb(m(), 1.0, 6000, 0.2)
    elif e == "powerUnplug":
        m.add(tone(glide(587, 392, 0.18), 0.4, 0.01, 0.18)).add(thump(75, 0.14), 0.14, gain=0.6)
        return reverb(m(), 1.0, 6000, 0.18)
    elif e == "deviceAdded":
        m.add(air(0.2, 600, 3600, 0.08, 0.1, 1.5), 0, gain=0.5).add(tone("C5", 0.3, 0.005, 0.12), 0.02).add(tone("G5", 0.4, 0.005, 0.16), 0.08)
        return reverb(m(), 1.0, 6500, 0.22)
    elif e == "deviceRemoved":
        m.add(air(0.2, 3600, 600, 0.04, 0.12, 1.5), 0, gain=0.5).add(tone("G5", 0.3, 0.005, 0.12), 0.02).add(tone("C5", 0.4, 0.005, 0.16), 0.08)
        return reverb(m(), 1.0, 6000, 0.2)
    elif e == "timerDone":
        for rep in range(3):
            m.add(tone("E6", 0.4, 0.004, 0.14), rep * 0.6, pan=-0.2).add(tone("B6", 0.4, 0.004, 0.16), rep * 0.6 + 0.12, pan=0.2, gain=0.8)
        return reverb(m(), 1.6, 7000, 0.3)
    elif e == "pomodoroDone":
        m.add(air(0.6, 300, 5000, 0.45, 0.2, 1.2), 0, gain=0.5)
        for i, n in enumerate(["D4", "A4", "D5", "F#5", "A5"]):
            m.add(tone(n, 1.7, 0.03, 0.9), 0.5 + i * 0.015, pan=-0.5 + i * 0.25, gain=0.4)
        return reverb(m(), 1.8, 6500, 0.36)
    return m()


# --- Crystal: glass bells and sparkle ---------------------------------------------------------------------------
def glass(f, d: float = 0.8, bright: float = 1.0) -> np.ndarray:
    x = partials(f, d, [1, 2.0, 2.76, 5.4, 8.93], [1, 0.22, 0.42 * bright, 0.18 * bright, 0.07 * bright],
                 [d * 0.42, d * 0.3, d * 0.22, d * 0.1, d * 0.05], a=0.0009)
    return band(x, 200, 14000)


def bell(f, d: float = 1.6) -> np.ndarray:
    return fm(f, 3.5, 2.2, d, d * 0.2, d * 0.35) * 0.7 + glass(f, d, 0.6) * 0.5


def crystal_pad(notes, d: float, a: float = 1.0, r: float = 1.6) -> np.ndarray:
    x = sum(chorus(n, d, cents=8, voices=3) + 0.2 * chorus(note(n) * 2, d, cents=11, voices=2) for n in notes)
    return x / len(notes) * swell(d, a, r)


def crystal(e: str) -> np.ndarray:
    m = Mix()
    if e == "navigate":
        m.add(glass("E7", 0.09, 0.6))
        return reverb(m(), 0.4, 11000, 0.1)
    elif e == "select":
        m.add(glass("C7", 0.22)).add(glass("G7", 0.26, 0.8), 0.03, pan=0.2)
        return reverb(m(), 0.8, 11000, 0.18)
    elif e == "open":
        for i, n in enumerate(["E6", "G#6", "B6", "E7"]):
            m.add(glass(n, 0.4, 0.8), i * 0.026, pan=-0.45 + i * 0.3, gain=1 - i * 0.1)
        return reverb(pingpong(m(), 0.07, 0.35, 0.25, 3), 1.2, 11000, 0.22)
    elif e == "close":
        for i, n in enumerate(["B6", "G#6", "E6"]):
            m.add(glass(n, 0.32, 0.7), i * 0.026, pan=0.3 - i * 0.3, gain=0.8 + i * 0.1)
        return reverb(m(), 1.0, 10000, 0.18)
    elif e == "toggleOn":
        m.add(glass("B6", 0.2, 0.7)).add(glass("E7", 0.26, 0.7), 0.035)
        return reverb(m(), 0.6, 11000, 0.14)
    elif e == "toggleOff":
        m.add(glass("E7", 0.2, 0.6)).add(glass("B6", 0.24, 0.6), 0.035)
        return reverb(m(), 0.6, 10000, 0.12)
    elif e == "volume":
        m.add(glass("A6", 0.1, 0.5))
        return reverb(m(), 0.4, 11000, 0.08)
    elif e == "notification":
        for i, n in enumerate(["E6", "B6", "E7"]):
            m.add(glass(n, 1.0 - i * 0.2), i * 0.075, pan=(-0.2, 0.2, 0)[i], gain=1 - i * 0.18)
        return reverb(pingpong(m(), 0.12, 0.4, 0.28, 4), 1.8, 12000, 0.3)
    elif e == "notificationCritical":
        for i in range(3):
            m.add(glass("D6", 0.45), i * 0.17).add(glass("A6", 0.45, 0.8), i * 0.17, gain=0.7)
        return reverb(m(), 1.2, 11000, 0.2)
    elif e == "error":
        m.add(glass("E5", 0.4, 0.3)).add(glass("F5", 0.45, 0.3), 0.0, gain=0.7).add(thump(90, 0.12), 0, gain=0.35)
        m.add(glass("Eb5", 0.5, 0.3), 0.12, gain=0.8)
        return reverb(m(), 0.7, 7000, 0.14)
    elif e == "screenshot":
        m.add(click(0.012, 5000, 14000, 0.002), gain=0.9).add(glass("C7", 0.3, 0.7), 0.02, gain=0.6)
        return reverb(m(), 0.7, 12000, 0.16)
    elif e == "boot":
        m.add(crystal_pad(["A2", "E3", "B3", "C#4", "G#4"], 3.7, 1.2, 1.7), gain=0.6)
        for i, n in enumerate(["A4", "C#5", "E5", "B5"]):
            m.add(bell(n, 2.6), 0.78 + i * 0.04, pan=-0.45 + i * 0.3, gain=0.42)
        cascade = ["E7", "C#7", "B6", "A6", "F#6", "E6", "C#6", "B5", "A5", "F#5", "E5", "C#5"]
        for i, n in enumerate(cascade):
            m.add(glass(n, 0.7, 0.8), 1.45 + i * 0.062, pan=np.sin(i * 1.3) * 0.7, gain=0.32 - i * 0.012)
        m.add(bell("A3", 3.0), 0.78, gain=0.25)
        return reverb(pingpong(m(), 0.16, 0.38, 0.18, 4, 9000), 2.2, 11000, 0.4, 0.025)
    elif e == "login":
        m.add(crystal_pad(["A3", "E4", "C#5"], 1.8, 0.3, 1.2), 0.05, gain=0.45)
        for i, n in enumerate(["A5", "C#6", "E6", "A6"]):
            m.add(glass(n, 0.9), i * 0.06, pan=-0.45 + i * 0.3, gain=0.8)
        return reverb(pingpong(m(), 0.12, 0.35, 0.2, 3), 2.0, 11000, 0.32)
    elif e == "lock":
        m.add(glass("E6", 0.7)).add(glass("A5", 0.9), 0.12)
        m.add(crystal_pad(["A3", "E4"], 1.0, 0.1, 0.8), 0.1, gain=0.3)
        return reverb(m(), 1.4, 10000, 0.26)
    elif e == "batteryLow":
        m.add(glass("A6", 0.6)).add(glass("F6", 0.8), 0.16)
        return reverb(m(), 1.2, 11000, 0.22)
    elif e == "batteryCritical":
        for i, n in enumerate(["A6", "F6", "D6"]):
            m.add(glass(n, 0.7, 1.0), i * 0.15)
        m.add(bell("D4", 1.2), 0.3, gain=0.3)
        return reverb(m(), 1.2, 11000, 0.22)
    elif e == "batteryFull":
        for i, n in enumerate(["C6", "E6", "G6", "C7"]):
            m.add(glass(n, 0.8), i * 0.07, pan=-0.3 + i * 0.2)
        return reverb(pingpong(m(), 0.1, 0.35, 0.22, 3), 1.6, 12000, 0.28)
    elif e == "powerPlug":
        m.add(thump(95, 0.1), gain=0.5).add(glass("G5", 0.4), 0.02).add(glass("D6", 0.6), 0.09)
        return reverb(m(), 1.0, 11000, 0.2)
    elif e == "powerUnplug":
        m.add(glass("D6", 0.4)).add(glass("G5", 0.6), 0.09).add(thump(85, 0.1), 0.09, gain=0.4)
        return reverb(m(), 1.0, 10000, 0.18)
    elif e == "deviceAdded":
        m.add(glass("C6", 0.35)).add(glass("G6", 0.5), 0.06)
        return reverb(m(), 1.0, 11000, 0.2)
    elif e == "deviceRemoved":
        m.add(glass("G6", 0.35)).add(glass("C6", 0.5), 0.06)
        return reverb(m(), 1.0, 10000, 0.18)
    elif e == "timerDone":
        for rep in range(2):
            for i, n in enumerate(["E6", "B6", "G#6", "E7"]):
                m.add(glass(n, 0.5), rep * 0.8 + i * 0.13, pan=(-0.25, 0.25)[i % 2])
        return reverb(m(), 1.5, 11000, 0.26)
    elif e == "pomodoroDone":
        m.add(crystal_pad(["D4", "A4", "F#5"], 2.0, 0.3, 1.4), 0.2, gain=0.45)
        for i, n in enumerate(["D6", "F#6", "A6", "D7"]):
            m.add(bell(n, 1.4), i * 0.09, pan=-0.45 + i * 0.3, gain=0.5)
        return reverb(pingpong(m(), 0.14, 0.38, 0.22, 4), 2.2, 11000, 0.34)
    return m()


# --- Arcade: pulse, triangle and noise --------------------------------------------------------------------------
def chip(f, d: float, duty: float = 0.5, sustain: float = 0.7, rel: float = 0.02, vib: float = 0.0) -> np.ndarray:
    n = int(d * SR)
    if isinstance(f, np.ndarray):
        freq = np.concatenate([f[:n], np.full(max(0, n - len(f)), f[-1])])
    else:
        freq = np.full(n, note(f))
    if vib:
        freq = freq * (1 + vib * np.sin(2 * np.pi * 6 * T(d)) * np.clip(T(d) / 0.15, 0, 1))
    x = pulse(freq, d, duty)
    t = T(d)
    e = np.where(t < 0.012, 1.0, sustain + (1 - sustain) * np.exp(-(t - 0.012) / 0.03))
    e *= np.clip((d - t) / rel, 0, 1)
    return band(x * e, 40, 12000)


def chip_noise(d: float, rate: float = 12000, decay: float = 0.03) -> np.ndarray:
    hold = max(1, int(SR / rate))
    steps = RNG.choice([-1.0, 1.0], int(d * SR) // hold + 1)
    return np.repeat(steps, hold)[:int(d * SR)] * env(d, 0.001, decay) * 0.5


def chip_tri(f, d: float) -> np.ndarray:
    return tri(f, d) * np.clip((d - T(d)) / 0.015, 0, 1)


def arcade(e: str) -> np.ndarray:
    m = Mix()
    if e == "navigate":
        m.add(chip(1760, 0.026, 0.25, 0.5, 0.008))
    elif e == "select":
        for i, (n, d) in enumerate([("A5", 0.045), ("D6", 0.045), ("A6", 0.11)]):
            m.add(chip(n, d, 0.5, 0.6), i * 0.045)
    elif e == "open":
        for i, n in enumerate(["C5", "E5", "G5", "C6"]):
            m.add(chip(n, 0.034, 0.25, 0.6, 0.01), i * 0.03)
    elif e == "close":
        for i, n in enumerate(["C6", "G5", "E5", "C5"]):
            m.add(chip(n, 0.032, 0.25, 0.5, 0.01), i * 0.028, gain=0.85)
    elif e == "toggleOn":
        m.add(chip(glide(600, 1200, 0.06), 0.06, 0.5, 0.6))
    elif e == "toggleOff":
        m.add(chip(glide(1200, 600, 0.06), 0.06, 0.5, 0.6))
    elif e == "volume":
        m.add(chip(990, 0.03, 0.25, 0.5, 0.008))
    elif e == "notification":
        for i, (n, d) in enumerate([("E6", 0.07), ("G6", 0.07), ("E7", 0.16)]):
            m.add(chip(n, d, 0.5, 0.65), i * 0.075)
            m.add(chip(n, d, 0.5, 0.65), 0.3 + i * 0.075, gain=0.3)
    elif e == "notificationCritical":
        for i in range(4):
            m.add(chip(("B5", "F6")[i % 2], 0.07, 0.5, 0.7), i * 0.085)
        m.add(chip_tri("B3", 0.36), 0, gain=0.5)
    elif e == "error":
        m.add(chip(glide(220, 98, 0.26), 0.26, 0.5, 0.8, 0.04)).add(chip_noise(0.1, 4000, 0.04), 0, gain=0.5)
    elif e == "screenshot":
        m.add(chip_noise(0.05, 22000, 0.012)).add(chip(2093, 0.04, 0.25, 0.5), 0.04, gain=0.7)
    elif e == "boot":
        step = 0.1
        melody = [("C5", 1), ("E5", 1), ("G5", 1), ("C6", 1), ("B5", 2), ("G5", 2),
                  ("A5", 1), ("F5", 1), ("A5", 1), ("C6", 1), ("D6", 3), ("E6", 6)]
        at = 0.0
        for n, length in melody:
            m.add(chip(n, length * step * 0.94, 0.25 if length < 3 else 0.5, 0.75, 0.02, 0.006 if length >= 3 else 0), at)
            m.add(chip(n, length * step * 0.94, 0.5, 0.6, 0.02), at + 0.012, gain=0.18)
            at += length * step
        for i, (n, length) in enumerate([("C3", 4), ("G3", 4), ("F3", 4), ("G3", 4), ("C4", 6)]):
            m.add(chip_tri(n, length * step * 0.92), sum(b for _, b in [("", 4)] * i) * step, gain=0.8)
        for i in range(0, 22, 2):
            m.add(chip_noise(0.03, 16000, 0.008), i * step, gain=0.35)
        return reverb(m(), 0.5, 6000, 0.08)
    elif e == "login":
        for i, (n, d) in enumerate([("G5", 0.06), ("C6", 0.06), ("E6", 0.06), ("G6", 0.3)]):
            m.add(chip(n, d, 0.5, 0.7, 0.03, 0.006 if d > 0.1 else 0), i * 0.06)
        m.add(chip_tri("C4", 0.5), 0, gain=0.6)
    elif e == "lock":
        for i, (n, d) in enumerate([("G6", 0.06), ("E6", 0.06), ("C6", 0.06), ("G5", 0.22)]):
            m.add(chip(n, d, 0.5, 0.6, 0.03), i * 0.06)
    elif e == "batteryLow":
        m.add(chip("A5", 0.14, 0.5, 0.7, 0.03, 0.01)).add(chip("F5", 0.22, 0.5, 0.7, 0.04, 0.01), 0.16)
    elif e == "batteryCritical":
        for i, n in enumerate(["A5", "F5", "D5"]):
            m.add(chip(n, 0.14, 0.5, 0.8, 0.03, 0.012), i * 0.16)
        m.add(chip_tri("D3", 0.5), 0.32, gain=0.6)
    elif e == "batteryFull":
        for i, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6", "C7"]):
            m.add(chip(n, 0.04, 0.25, 0.7), i * 0.035)
        m.add(chip("C7", 0.2, 0.5, 0.5, 0.06), 7 * 0.035, gain=0.6)
    elif e == "powerPlug":
        m.add(chip(glide(392, 784, 0.1), 0.1, 0.5, 0.7)).add(chip("G6", 0.08, 0.25, 0.6), 0.1)
    elif e == "powerUnplug":
        m.add(chip(glide(784, 392, 0.12), 0.12, 0.5, 0.7))
    elif e == "deviceAdded":
        for i, n in enumerate(["C6", "E6", "G6"]):
            m.add(chip(n, 0.04, 0.25, 0.6), i * 0.04)
    elif e == "deviceRemoved":
        for i, n in enumerate(["G6", "E6", "C6"]):
            m.add(chip(n, 0.04, 0.25, 0.6), i * 0.04)
    elif e == "timerDone":
        for rep in range(3):
            m.add(chip("E6", 0.08, 0.5, 0.7), rep * 0.42).add(chip("C6", 0.08, 0.5, 0.7), rep * 0.42 + 0.1)
            m.add(chip("E6", 0.08, 0.5, 0.7), rep * 0.42 + 0.2)
    elif e == "pomodoroDone":
        for i, (n, d) in enumerate([("G5", 0.08), ("C6", 0.08), ("E6", 0.08), ("G6", 0.16), ("E6", 0.08), ("G6", 0.36)]):
            m.add(chip(n, d * 0.94, 0.5, 0.7, 0.03, 0.006 if d > 0.2 else 0), [0, 0.08, 0.16, 0.24, 0.42, 0.5][i])
        m.add(chip_tri("C4", 0.8), 0, gain=0.6)
    return m()


PACKS = {"lounge": lounge, "orbit": orbit, "crystal": crystal, "arcade": arcade}


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main(names: list[str]) -> int:
    for name in names or list(PACKS):
        voice = PACKS[name]
        folder = OUT / name
        folder.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory() as tmp:
            for event in EVENTS:
                x = finish(voice(event), event)
                wav = Path(tmp) / f"{event}.wav"
                write_wav(wav, x)
                subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5",
                                "-map_metadata", "-1", str(folder / f"{event}.oga")], check=True)
        print(f"{name}: {len(EVENTS)} sounds")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
