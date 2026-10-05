#!/usr/bin/env python3
"""inir-audio-bridge - persistent EasyEffects IPC bridge for the iNiR audio panel.

Why this exists
---------------
The previous transport (``scripts/audio/easyeffects-eq.sh``) spawned
``bash`` + ``socat`` per EasyEffects verb: 75-347 OS processes per command and
~0.37 s for a single band change. A panel with up to 32 bands and 5 modules
cannot work that way.

This daemon keeps the EasyEffects connection handling, the state cache and the
write coalescing in one long-lived process, so a band change costs
ZERO child processes and one batched round trip.

Protocol notes (all verified against EasyEffects 8.3.0 on this machine)
----------------------------------------------------------------------
* Wire format is plain text, one verb per line, every verb newline-terminated.
* ``get_property`` replies are newline-terminated and can be batched: send
  ``"\\n".join(cmds) + "\\n"``, ``shutdown(SHUT_WR)``, read to EOF, and split.
* EXCEPTION: ``get_global_bypass`` replies WITHOUT a trailing newline, so
  batching it corrupts neighbouring replies. It is always sent alone.
* ``set_property`` returns nothing, so every write is confirmed by a readback.
* The module name on the wire REQUIRES the instance suffix (``equalizer:0``).
  Without it the reply is empty, which is indistinguishable from success.
* Error tokens: ``error_plugin_not_found`` (module not in the chain),
  ``error_property_not_found`` (bad key), ``error_generic``.
* Preset JSON key casing differs per module: ``equalizer`` uses kebab-case
  (``input-gain``), every other verified module uses the same camelCase names
  as its KConfig ``.rc`` file (``floorActive``, ``stereoLink``).
* A preset block that is MISSING a required key does not produce an error:
  EasyEffects aborts on a nlohmann/json ``operator[]`` assertion. Extra keys are
  ignored. Hence blocks are generated complete, never partially.

Only the Python 3 standard library is used.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import selectors
import shutil
import signal
import socket
import sys
import tempfile
import threading
import time

VERSION = "1.0.0"
PROG = "inir-audio-bridge"

# --------------------------------------------------------------------------
# Locations
# --------------------------------------------------------------------------

def runtime_dir() -> str:
    d = os.environ.get("XDG_RUNTIME_DIR")
    if d and os.path.isdir(d):
        return d
    return "/tmp"


def default_socket_path() -> str:
    return os.path.join(runtime_dir(), "inir-audio.sock")


def easyeffects_socket_path() -> str:
    env = os.environ.get("EASYEFFECTS_SERVER_SOCKET")
    if env:
        return env
    return os.path.join(runtime_dir(), "EasyEffectsServer")


def default_preset_dir() -> str:
    xdg = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(xdg, "easyeffects", "output")


BACKUP_DIRNAME = ".inir-backup"
# Used when EasyEffects' lastLoadedOutputPreset is missing or unusable.
FALLBACK_PRESET = "iNiR Equalizer"
CONFIG_FILE = os.path.join(
    os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"),
    "easyeffects", "db", "easyeffectsrc")

# --------------------------------------------------------------------------
# Verified module schema
# --------------------------------------------------------------------------
# Every entry was verified on EasyEffects 8.3.0 by installing the module in the
# output chain and reading each key back over IPC. `json_keys` are the keys used
# inside a preset file, `ipc_keys` the keys accepted by get/set_property.
#
# value_kind drives the wire encoding:
#   float -> plain decimal ("-2.5")
#   int   -> integer, enums MUST be integers
#   bool  -> "true"/"false"
#   pct   -> float 0..100

# The equalizer is the one module with a mixed naming history: most of its
# preset keys are kebab-case, but "viewLeftChannel" has no kebab spelling in
# the binary, so it stays camelCase. Public key -> IPC key.
MAX_BANDS = 32
# EasyEffects instance ids are small monotonic integers; probe this many.
MAX_INSTANCES = 8
# EasyEffects clamps num-bands to 1..32.
ALLOWED_BAND_COUNTS = (10, 15, 32)

# EQ_PARAMS: public key -> spec.
#
# Most equalizer keys are the kebab-case preset spelling, but the panel's
# contract puts the master gains on a separate camelCase path
# ("inputGain"/"outputGain"). That is the public key; "preset" records the
# spelling that actually goes into the preset file, so the two can differ.
# Both spellings are accepted on input, but only the public one is advertised.
EQ_PARAMS = {
    "balance": {"ipc": "balance", "type": "float", "default": 0.0,
                "min": -100.0, "max": 100.0, "unit": "%"},
    "inputGain": {"ipc": "inputGain", "preset": "input-gain", "type": "float",
                  "default": 0.0, "min": -36.0, "max": 36.0, "unit": "dB"},
    "outputGain": {"ipc": "outputGain", "preset": "output-gain",
                   "type": "float", "default": 0.0, "min": -36.0, "max": 36.0,
                   "unit": "dB"},
    "num-bands": {"ipc": "numBands", "type": "int", "default": 10,
                  "min": 1, "max": MAX_BANDS, "unit": None},
    "split-channels": {"ipc": "splitChannels", "type": "bool", "default": False},
    "bypass": {"ipc": "bypass", "type": "bool", "default": False},
    "pitch-left": {"ipc": "pitchLeft", "type": "float", "default": 0.0,
                   "min": -1200.0, "max": 1200.0, "unit": "cents"},
    "pitch-right": {"ipc": "pitchRight", "type": "float", "default": 0.0,
                    "min": -1200.0, "max": 1200.0, "unit": "cents"},
    "decramp": {"ipc": "decramp", "type": "float", "default": 0.0,
                "min": None, "max": None, "unit": None},
    # no kebab spelling exists in the binary for this one
    "viewLeftChannel": {"ipc": "viewLeftChannel", "type": "bool",
                        "default": True},
    "mode": {"ipc": "mode", "type": "enum", "default": "IIR",
             "enum": ["IIR", "FIR", "FFT", "SPM"], "min": 0, "max": 3},
}

# Per-band equalizer parameters (measured clamp bounds).
EQ_BAND_PARAMS = {
    "Frequency": {"type": "float", "default": None, "min": 10.0,
                  "max": 24000.0, "unit": "Hz"},
    "Gain": {"type": "float", "default": 0.0, "min": -36.0, "max": 36.0,
             "unit": "dB"},
    "Q": {"type": "float", "default": 4.36, "min": 0.0, "max": 100.0,
          "unit": None},
    "Width": {"type": "float", "default": 4.0, "min": 0.0, "max": 12.0,
              "unit": None},
    # Verified against the live EasyEffects 8.3 binary and engine.
    #
    # These are kcfg EnumChoice labels; the IPC carries an INTEGER INDEX, so
    # the ORDER is what actually matters and a wrong order silently
    # misreports every band. Three independent sources agree on it:
    #   1. `strings /usr/bin/easyeffects` yields the ten band-type labels as
    #      one CONTIGUOUS run: Hi-pass, Hi-shelf, Lo-pass, Lo-shelf, Notch,
    #      Resonance, Allpass, Bandpass, Ladder-pass, Ladder-rej.
    #   2. The live engine reads a default band as Type index '1', and
    #      Bell is the default -> Bell is index 1, not 0.
    #   3. The manual lists Off immediately before Bell -> Off is index 0.
    # So the run of ten occupies 2..11. "Off" and "Bell" are separate
    # literals in the pool, adjacent in first-use order, consistent with
    # indices 0 and 1.
    #
    # NOTE the spelling: EasyEffects' Equalizer says "Hi-pass"/"Lo-shelf"/
    # "Allpass" (no space, short prefixes). The manual renders them
    # "High Pass"/"Low Shelf"/"All Pass", and the *Filter* plugin uses yet
    # another set ("Low-pass"/"High-pass"/"All-pass" - all present in the
    # same binary, a separate run). Do not cross-contaminate the three.
    "Type": {"type": "enum", "default": "Bell", "min": 0, "max": 11,
             "enum": ["Off", "Bell", "Hi-pass", "Hi-shelf", "Lo-pass",
                      "Lo-shelf", "Notch", "Resonance", "Allpass", "Bandpass",
                      "Ladder-pass", "Ladder-rej"]},
    # All six documented modes are real labels, present as one contiguous run
    # in the binary in exactly this order; index 0 ("RLC (BT)") is confirmed
    # by the live default band reading '0'. The seventh label is "APO (DR)".
    # There is NO "APO (PS)": the string occurs zero times in the binary, and
    # a live write of index 7 was still accepted, which is exactly why
    # acceptance proves nothing here.
    "Mode": {"type": "enum", "default": "RLC (BT)", "min": 0, "max": 6,
             "enum": ["RLC (BT)", "RLC (MT)", "BWC (BT)", "BWC (MT)",
                      "LRX (BT)", "LRX (MT)", "APO (DR)"]},
    "Slope": {"type": "enum", "default": "x1", "min": 0, "max": 5,
              "enum": ["x1", "x2", "x3", "x4", "x6", "x12"]},
    "Solo": {"type": "bool", "default": False},
    "Mute": {"type": "bool", "default": False},
}

# enum label -> IPC integer, for the equalizer
EQ_MODES = {"IIR": 0, "FIR": 1, "FFT": 2, "SPM": 3}
# Label -> IPC index, for the equalizer. Derived from the "enum" list in
# EQ_BAND_PARAMS, which is the authoritative source; these are a convenience
# mirror, so they are derived rather than hand-written.
EQ_BAND_TYPES = {label: i for i, label in
                 enumerate(EQ_BAND_PARAMS["Type"]["enum"])}
EQ_BAND_MODES = {label: i for i, label in
                 enumerate(EQ_BAND_PARAMS["Mode"]["enum"])}
EQ_BAND_SLOPES = {"x1": 0, "x2": 1, "x3": 2, "x4": 3, "x6": 4, "x12": 5}

# --------------------------------------------------------------------------
# Module parameter schema
# --------------------------------------------------------------------------
# PUBLIC KEY = the PRESET-JSON key (kebab-case). That is the name QML and the
# panel see; they never see EasyEffects' camelCase IPC spelling. The bridge
# translates public -> IPC internally.
#
# This was verified key by key on EasyEffects 8.3.0: for every multi-word
# parameter the kebab-case preset key is the one that is honoured, and the
# camelCase spelling is silently ignored (unknown preset keys are ignored, so a
# wrong spelling never errors - it just quietly does nothing).
#
# Per-parameter fields:
#   ipc      - key accepted by get_property / set_property (camelCase)
#   type     - "float" | "int" | "bool" | "enum"
#   min,max  - measured clamp bounds (None when not measurable)
#   default  - neutral value, and the value written into a generated preset
#   unit     - "dB" | "Hz" | "ms" | "%" | "LUFS" | None
#   enum     - label list indexed by the IPC integer; the preset stores the
#              LABEL string, the IPC wire carries the integer
#
# The min/max values below were measured by driving each parameter to +-1e9
# over IPC and reading back what EasyEffects clamped it to.

# Limiter labelled enums. The indices were confirmed against the binary's own
# label pool (Full x8/24 bit -> 20, True Peak/24 bit -> 22, 8bit -> 2,
# 16bit -> 6, 24bit -> 8), so these lists are index-accurate.
LIMITER_OVERSAMPLING = [
    "None",
    "Half x2/16 bit", "Half x2/24 bit", "Half x3/16 bit", "Half x3/24 bit",
    "Half x4/16 bit", "Half x4/24 bit", "Half x6/16 bit", "Half x6/24 bit",
    "Half x8/16 bit", "Half x8/24 bit",
    "Full x2/16 bit", "Full x2/24 bit", "Full x3/16 bit", "Full x3/24 bit",
    "Full x4/16 bit", "Full x4/24 bit", "Full x6/16 bit", "Full x6/24 bit",
    "Full x8/16 bit", "Full x8/24 bit",
    "True Peak/16 bit", "True Peak/24 bit",
]
LIMITER_DITHERING = ["None", "7bit", "8bit", "11bit", "12bit", "15bit",
                     "16bit", "23bit", "24bit"]

MODULE_SCHEMA = {
    "autogain": {
        "verified": True,
        "params": {
            "bypass": {"ipc": "bypass", "type": "bool", "default": True},
            "target": {"ipc": "target", "type": "float", "default": -23.0,
                       "min": -100.0, "max": 0.0, "unit": "LUFS"},
            "silence-threshold": {"ipc": "silenceThreshold", "type": "float",
                                  "default": -70.0, "min": -100.0, "max": 0.0,
                                  "unit": "dB"},
            "maximum-history": {"ipc": "maximumHistory", "type": "int",
                                "default": 15, "min": 6, "max": 3600,
                                "unit": None},
            "force-silence": {"ipc": "forceSilence", "type": "bool",
                              "default": False},
        },
    },
    "bass_enhancer": {
        "verified": True,
        "params": {
            "bypass": {"ipc": "bypass", "type": "bool", "default": True},
            "amount": {"ipc": "amount", "type": "float", "default": 1.0,
                       "min": -100.0, "max": 36.0, "unit": "dB"},
            "floor": {"ipc": "floor", "type": "float", "default": 40.0,
                      "min": 10.0, "max": 120.0, "unit": "Hz"},
            "floor-active": {"ipc": "floorActive", "type": "bool",
                             "default": True},
        },
    },
    "exciter": {
        "verified": True,
        "params": {
            "bypass": {"ipc": "bypass", "type": "bool", "default": True},
            "amount": {"ipc": "amount", "type": "float", "default": -6.5,
                       "min": -100.0, "max": 36.0, "unit": "dB"},
            "ceil": {"ipc": "ceil", "type": "float", "default": 10000.0,
                     "min": 10000.0, "max": 20000.0, "unit": "Hz"},
            "ceil-active": {"ipc": "ceilActive", "type": "bool",
                            "default": False},
            # measured as a float: EasyEffects clamps it to 0.1..10
            "harmonics": {"ipc": "harmonics", "type": "float", "default": 4.0,
                          "min": 0.1, "max": 10.0, "unit": None},
            "scope": {"ipc": "scope", "type": "float", "default": 8000.0,
                      "min": 2000.0, "max": 12000.0, "unit": "Hz"},
        },
    },
    "limiter": {
        "verified": True,
        "params": {
            "bypass": {"ipc": "bypass", "type": "bool", "default": True},
            "threshold": {"ipc": "threshold", "type": "float", "default": 0.0,
                          "min": -48.0, "max": 0.0, "unit": "dB"},
            "lookahead": {"ipc": "lookahead", "type": "float", "default": 4.0,
                          "min": 0.1, "max": 20.0, "unit": "ms"},
            "attack": {"ipc": "attack", "type": "float", "default": 0.25,
                       "min": 0.25, "max": 20.0, "unit": "ms"},
            "release": {"ipc": "release", "type": "float", "default": 0.25,
                        "min": 0.25, "max": 20.0, "unit": "ms"},
            "gain-boost": {"ipc": "gainBoost", "type": "bool", "default": False},
            "stereo-link": {"ipc": "stereoLink", "type": "float",
                            "default": 100.0, "min": 0.0, "max": 100.0,
                            "unit": "%"},
            "input-gain": {"ipc": "inputGain", "type": "float", "default": 0.0,
                           "min": -36.0, "max": 36.0, "unit": "dB"},
            "output-gain": {"ipc": "outputGain", "type": "float",
                            "default": 0.0, "min": -36.0, "max": 36.0,
                            "unit": "dB"},
            "oversampling": {"ipc": "oversampling", "type": "enum",
                             "default": "None", "enum": LIMITER_OVERSAMPLING,
                             "min": 0, "max": len(LIMITER_OVERSAMPLING) - 1},
            "dithering": {"ipc": "dithering", "type": "enum",
                          "default": "None", "enum": LIMITER_DITHERING,
                          "min": 0, "max": len(LIMITER_DITHERING) - 1},
            # NOTE: the limiter's "mode" is deliberately absent. The loader
            # reads it as a string, so a wrong type is a hard parse error, but
            # no label was found that changes the value (Peak/RMS/"peak" all
            # left a pre-set value untouched). Emitting a guess would be
            # strictly worse than omitting it.
        },
    },
    "crystalizer": {
        "verified": True,
        "params": {
            "bypass": {"ipc": "bypass", "type": "bool", "default": True},
            "input-gain": {"ipc": "inputGain", "type": "float", "default": 0.0,
                           "min": -36.0, "max": 36.0, "unit": "dB"},
            "output-gain": {"ipc": "outputGain", "type": "float",
                            "default": 0.0, "min": -36.0, "max": 36.0,
                            "unit": "dB"},
            "adaptive-intensity": {"ipc": "adaptiveIntensity", "type": "bool",
                                   "default": False},
            "oversampling": {"ipc": "oversampling", "type": "bool",
                             "default": False},
            "oversampling-quality": {"ipc": "oversamplingQuality",
                                     "type": "int", "default": 3, "min": 0,
                                     "max": 10, "unit": None},
            "fixed-quantum": {"ipc": "useFixedQuantum", "type": "bool",
                              "default": False},
            # Accepted, but the value is not applied in 8.3.0 (0 -> 10,
            # 7 -> 10, absent -> 120). Kept for completeness.
            "transition-band": {"ipc": "transitionBand", "type": "int",
                                "default": 10, "min": 10, "max": 1000},
        },
        # The bands are NOT flat scalars: the preset stores 13 nested objects
        # "band0".."band12", each {intensity, mute, bypass}. Verified: this
        # section is REQUIRED - omitting it aborts EasyEffects, and wrapping it
        # in an extra "bands"/"band" object also aborts.
        #
        # The panel addresses a band with a DOTTED PATH, "band<N>.<field>", so
        # that is the public key. The flat camelCase IPC name is never exposed.
        "json_bands": {
            "prefix": "band",
            "count": 13,
            "ipc": {"intensity": "intensityBand%d",
                    "mute": "muteBand%d",
                    "bypass": "bypassBand%d"},
            "public": {"intensity": "band%d.intensity",
                       "mute": "band%d.mute",
                       "bypass": "band%d.bypass"},
            "fields": {"intensity": {"ipc": "intensityBand%d", "type": "float",
                                     "default": 1.0, "min": -40.0,
                                     "max": 32.0, "unit": "dB"},
                       "mute": {"ipc": "muteBand%d", "type": "bool",
                                "default": False},
                       "bypass": {"ipc": "bypassBand%d", "type": "bool",
                                  "default": True}},
        },
    },
}

# Modules whose preset block could not be verified. Anything listed here is
# REFUSED by set_chain / save_preset: a wrong block aborts EasyEffects rather
# than reporting an error, so a guess is never worth the risk. Empty today -
# all five panel modules are verified - but the guard stays.
UNVERIFIED_MODULES: dict[str, str] = {}

KNOWN_MODULES = sorted(set(MODULE_SCHEMA) | set(UNVERIFIED_MODULES)) + ["equalizer"]

# Default band frequencies. Bands 0..9 are the classic ISO octave centres; a
# 10-band curve must be exactly those. Bands 10..31 are the EXACT values
# EasyEffects 8.3.0 generates itself for the extra bands (read back from the
# live equalizer, not guessed), in ascending order. EasyEffects stores those
# extras after a 16 kHz band 9 rather than merging them into the octave grid;
# keeping them at the tail preserves both properties (octaves first, extras
# ascending among themselves).
ISO_BAND_FREQS = [
    32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
]
EXTRA_BAND_FREQS = [
    194.06, 240.81, 298.834, 370.834, 460.182, 571.057, 708.647, 879.387,
    1091.26, 1354.19, 1680.47, 2085.35, 2587.79, 3211.29, 3985.01, 4945.15,
    6135.63, 7615.17, 9449.96, 11726.8, 14552.2, 18058.4,
]
DEFAULT_BAND_FREQS = ISO_BAND_FREQS + EXTRA_BAND_FREQS


def default_band_freq(index: int) -> float:
    if index < len(ISO_BAND_FREQS):
        return ISO_BAND_FREQS[index]
    return EXTRA_BAND_FREQS[(index - len(ISO_BAND_FREQS))
                            % len(EXTRA_BAND_FREQS)]
DEFAULT_BAND_Q = 4.36
DEFAULT_BAND_WIDTH = 4.0
DEFAULT_BAND_TYPE = "Bell"
DEFAULT_BAND_MODE = "RLC (BT)"
DEFAULT_BAND_SLOPE = "x1"

# Float readback tolerance measured on this machine (~0.051 dB).
GAIN_TOLERANCE = 0.06
FREQ_TOLERANCE = 0.51

COALESCE_SECONDS = 0.040
IO_TIMEOUT = 5.0
RECONNECT_BACKOFF = (0.05, 0.1, 0.25, 0.5, 1.0)

ERR_UNAVAILABLE = "easyeffects_unavailable"
ERR_NOT_FOUND = "error_plugin_not_found"
ERR_BAD_PROP = "error_property_not_found"


def log(msg: str) -> None:
    """Log to stderr only. stdout is the protocol channel in --stdin mode."""
    sys.stderr.write("[%s] %s\n" % (PROG, msg))
    sys.stderr.flush()


# --------------------------------------------------------------------------
# EasyEffects client
# --------------------------------------------------------------------------

class EasyEffects:
    """One AF_UNIX connection per batched round trip.

    EasyEffects 8.3.0 closes the connection when it sees write-side EOF, so a
    truly persistent socket is not achievable with this protocol; what matters
    is that a batch of N verbs costs ONE round trip and ZERO child processes,
    instead of N x (bash + socat).
    """

    def __init__(self, socket_path: str | None = None, timeout: float = IO_TIMEOUT):
        self.socket_path = socket_path or easyeffects_socket_path()
        self.timeout = timeout
        self._backoff_idx = 0
        self.stats = {"rounds": 0, "verbs": 0, "connects": 0}

    # -- low level ---------------------------------------------------------
    def _round_trip(self, cmds: list[str]) -> list[str]:
        if not cmds:
            return []
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(self.timeout)
        try:
            s.connect(self.socket_path)
        except OSError as exc:
            s.close()
            self._backoff_idx = min(self._backoff_idx + 1, len(RECONNECT_BACKOFF))
            raise BridgeUnavailable(str(exc))
        self.stats["connects"] += 1
        try:
            s.sendall(("\n".join(cmds) + "\n").encode())
            # EasyEffects processes the batch on write-side EOF and closes.
            try:
                s.shutdown(socket.SHUT_WR)
            except OSError:
                pass
            buf = b""
            while True:
                try:
                    chunk = s.recv(65536)
                except socket.timeout:
                    break
                if not chunk:
                    break
                buf += chunk
        except OSError as exc:
            raise BridgeUnavailable(str(exc))
        finally:
            s.close()
        self._backoff_idx = 0
        self.stats["rounds"] += 1
        self.stats["verbs"] += len(cmds)
        text = buf.decode("utf-8", errors="replace")
        return text.split("\n")[:-1] if text.endswith("\n") else text.split("\n")

    # -- public ------------------------------------------------------------
    def available(self) -> bool:
        if not os.path.exists(self.socket_path):
            return False
        try:
            self._round_trip(["get_last_loaded_preset:output"])
            return True
        except BridgeUnavailable:
            return False

    def get(self, stream: str, module: str, key: str) -> str:
        """Single get. Returns the raw reply (may be an error token)."""
        return self.get_many(stream, module, [key])[0]

    def get_many(self, stream: str, module: str, keys: list[str]) -> list[str]:
        cmds = ["get_property:%s:%s:%s" % (stream, module, k) for k in keys]
        replies = self._round_trip(cmds)
        if len(replies) < len(cmds):
            replies += [""] * (len(cmds) - len(replies))
        return replies[:len(cmds)]

    def get_props(self, stream: str, targets: list[tuple[str, str]]) -> list[str]:
        """Batched get across DIFFERENT modules in a single round trip."""
        if not targets:
            return []
        cmds = ["get_property:%s:%s:%s" % (stream, m, k) for m, k in targets]
        replies = self._round_trip(cmds)
        if len(replies) < len(cmds):
            replies += [""] * (len(cmds) - len(replies))
        return replies[:len(cmds)]

    def set_many(self, stream: str, writes: list[tuple[str, str, str]]) -> None:
        """writes = [(module, key, wire_value), ...]. Returns nothing on the
        wire, so callers must read back to confirm."""
        if not writes:
            return
        cmds = ["set_property:%s:%s:%s:%s" % (stream, m, k, v)
                for m, k, v in writes]
        self._round_trip(cmds)

    def get_global_bypass(self) -> str:
        """Sent alone: its reply carries no trailing newline."""
        replies = self._round_trip(["get_global_bypass"])
        return replies[0] if replies else ""

    def set_global_bypass(self, value: int) -> None:
        self._round_trip(["global_bypass:%d" % (1 if value else 0)])

    def last_loaded_preset(self, stream: str = "output") -> str:
        replies = self._round_trip(["get_last_loaded_preset:%s" % stream])
        return replies[0] if replies else ""

    def load_preset(self, name: str, stream: str = "output") -> str:
        replies = self._round_trip(["load_preset:%s:%s" % (stream, name)])
        return replies[0] if replies else ""

    def show_window(self) -> None:
        self._round_trip(["show_window"])

    def hide_window(self) -> None:
        self._round_trip(["hide_window"])


class BridgeUnavailable(Exception):
    """EasyEffects is not running / not reachable."""


# --------------------------------------------------------------------------
# Wire value encoding
# --------------------------------------------------------------------------

def encode_value(value, kind: str) -> str:
    if kind == "bool":
        if isinstance(value, str):
            return "true" if value.strip().lower() in ("1", "true", "on", "yes") else "false"
        return "true" if bool(value) else "false"
    if kind == "int":
        return str(int(round(float(value))))
    if kind == "pct":
        f = float(value)
        return str(int(round(f)))
    f = float(value)
    if f == int(f) and abs(f) < 1e15:
        return str(int(f))
    return repr(f)


def parse_value(raw: str, kind: str):
    """Parse an IPC reply. Returns None on error tokens / empty replies."""
    if raw is None:
        return None
    raw = raw.strip()
    if raw == "" or raw.startswith("error_"):
        return None
    try:
        if kind == "bool":
            return raw.lower() in ("true", "1", "on", "yes")
        if kind == "int":
            return int(float(raw))
        if kind == "pct":
            return float(raw)
        return float(raw)
    except ValueError:
        return None


def camel_to_kebab(name: str) -> str:
    """camelCase -> kebab-case, including a dash before a trailing digit group
    ("intensityBand3" -> "intensity-band-3").

    NOTE: a naming utility for callers/tests. The bridge does NOT derive preset
    keys with it: the schema below states the verified public (preset) key and
    its IPC key explicitly, because the two are not always mechanically related.
    """
    out = re.sub(r"(?<!^)(?=[A-Z])", "-", name)
    out = re.sub(r"(?<=[A-Za-z])(?=\d)", "-", out)
    return out.lower()


# --------------------------------------------------------------------------
# Public (preset) key  <->  IPC key/value translation
# --------------------------------------------------------------------------

def _build_key_index():
    """accepted-input -> (canonical_public_key, ipc_key, spec).

    Three input spellings resolve to the same parameter:
      * the canonical public key (the one `spec` advertises),
      * the preset-JSON spelling when it differs (equalizer master gains),
      * for crystalizer bands, the dotted path "band<N>.<field>".

    Accepting the preset spelling as an alias keeps older callers working,
    while only the canonical public key is ever reported back.
    """
    index: dict[tuple[str, str], tuple[str, str, dict]] = {}

    def add(module, public, ipc, spec):
        index[(module, public)] = (public, ipc, spec)
        preset_key = spec.get("preset")
        if preset_key:
            index[(module, preset_key)] = (public, ipc, spec)

    for key, spec in EQ_PARAMS.items():
        add("equalizer", key, spec["ipc"], spec)
    for module, schema in MODULE_SCHEMA.items():
        for key, spec in schema["params"].items():
            add(module, key, spec["ipc"], spec)
        bands_spec = schema.get("json_bands")
        if bands_spec:
            for i in range(bands_spec["count"]):
                for field, spec in bands_spec["fields"].items():
                    add(module, bands_spec["public"][field] % i,
                        bands_spec["ipc"][field] % i, spec)
    return index


_KEY_INDEX = _build_key_index()

# (module, ipc_key) -> canonical public key, for folding readbacks into the cache
_IPC_INDEX: dict[tuple[str, str], str] = {}
for (_mod, _input), (_pub, _ipc, _spec) in _KEY_INDEX.items():
    _IPC_INDEX[(_mod, _ipc)] = _pub


def ipc_key_for(module: str, public_key: str):
    """Public key -> (ipc_key, spec). Accepts the canonical public key, the
    preset spelling, and the dotted "band<N>.<field>" band path."""
    hit = _KEY_INDEX.get((module, public_key))
    if hit is None:
        return None, None
    return hit[1], hit[2]


def canonical_key_for(module: str, public_key: str):
    """The canonical public key for any accepted spelling."""
    hit = _KEY_INDEX.get((module, public_key))
    return hit[0] if hit else None


def public_keys_for(module: str) -> list[str]:
    if module == "equalizer":
        return list(EQ_PARAMS.keys())
    schema = MODULE_SCHEMA.get(module)
    if not schema:
        return []
    keys = list(schema["params"].keys())
    bands_spec = schema.get("json_bands")
    if bands_spec:
        for i in range(bands_spec["count"]):
            keys += [bands_spec["public"][f] % i for f in bands_spec["fields"]]
    return keys


def encode_public(spec: dict, value):
    """Public value -> IPC wire string.

    Enums are the interesting case and follow the panel contract: the value
    arrives as the UNTRANSLATED kcfg label, verbatim, and this label->index
    table is what turns it into the integer that set_property expects. An
    integer index is also accepted so a caller that already holds one (e.g. a
    value decoded from status) round-trips without a lookup failure.
    """
    kind = spec["type"]
    if kind == "bool":
        if isinstance(value, str):
            return "true" if value.strip().lower() in (
                "1", "true", "on", "yes") else "false"
        return "true" if bool(value) else "false"
    if kind == "enum":
        labels = spec.get("enum") or []
        if isinstance(value, str):
            if value not in labels:
                raise ValueError("%r is not one of %s"
                                 % (value, labels))
            return str(labels.index(value))
        idx = int(value)
        if not 0 <= idx < len(labels):
            raise ValueError("enum index %d out of range 0..%d"
                             % (idx, len(labels) - 1))
        return str(idx)
    if kind == "int":
        return str(int(round(float(value))))
    f = float(value)
    return str(int(f)) if f == int(f) and abs(f) < 1e15 else repr(f)


def decode_public(spec: dict, raw):
    """IPC reply -> public value (enum indices become labels)."""
    if raw is None:
        return None
    raw = raw.strip()
    if raw == "" or raw.startswith("error_"):
        return None
    kind = spec["type"]
    if kind == "bool":
        return raw.lower() in ("true", "1", "on", "yes")
    if kind == "enum":
        labels = spec.get("enum") or []
        try:
            idx = int(float(raw))
        except ValueError:
            return raw
        return labels[idx] if 0 <= idx < len(labels) else raw
    if kind == "int":
        try:
            return int(float(raw))
        except ValueError:
            return None
    try:
        return float(raw)
    except ValueError:
        return None


def kebab_to_camel(name: str) -> str:
    head, *rest = name.split("-")
    return head + "".join(p.capitalize() for p in rest)


# --------------------------------------------------------------------------
# Preset files
# --------------------------------------------------------------------------

PRESET_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._+\-]{0,99}$")


class PresetError(Exception):
    pass


def safe_preset_path(preset_dir: str, name: str) -> str:
    """Resolve a preset name inside preset_dir, rejecting any traversal."""
    if not name or not PRESET_NAME_RE.match(name):
        raise PresetError("invalid preset name: %r" % name)
    if "/" in name or "\\" in name or ".." in name:
        raise PresetError("path traversal rejected: %r" % name)
    path = os.path.join(preset_dir, name + ".json")
    base = os.path.realpath(preset_dir)
    real = os.path.realpath(path)
    if os.path.dirname(real) != base:
        raise PresetError("path traversal rejected: %r" % name)
    return path


def _band_side(freqs: int, gains: dict[int, float] | None = None) -> dict:
    gains = gains or {}
    out = {}
    for i in range(freqs):
        out["band%d" % i] = {
            "frequency": float(default_band_freq(i)),
            "gain": float(gains.get(i, 0.0)),
            "mode": DEFAULT_BAND_MODE,
            "mute": False,
            "q": DEFAULT_BAND_Q,
            "slope": DEFAULT_BAND_SLOPE,
            "solo": False,
            "type": DEFAULT_BAND_TYPE,
            "width": DEFAULT_BAND_WIDTH,
        }
    return out


def build_equalizer_block(count: int, gains: dict[int, float] | None = None,
                          bypass: bool | None = None) -> dict:
    """Complete equalizer block, kebab-case (verified preset spelling)."""
    count = max(1, min(MAX_BANDS, int(count)))
    return {
        "balance": 0.0,
        "bypass": bool(bypass) if bypass is not None else False,
        "input-gain": 0.0,
        "left": _band_side(count, gains),
        "mode": "IIR",
        "num-bands": count,
        "output-gain": 0.0,
        "pitch-left": 0.0,
        "pitch-right": 0.0,
        "right": _band_side(count, gains),
        "split-channels": False,
    }


def build_module_block(module: str, live: dict | None = None) -> dict:
    """Complete, neutral (all bypassed) block for a verified module.

    Keys are emitted in the module's own verified casing: kebab-case for
    autogain, camelCase (identical to the KConfig ``.rc`` keys) for
    bass_enhancer / exciter / limiter. The kebab spellings of the camelCase
    modules were verified to return error_property_not_found.

    `live` carries the values currently set in the running chain. They are
    carried over so that adding a module to a chain never resets the settings
    of the modules that were already there. String-enum params keep their
    neutral default because the IPC enum has no verified reverse mapping.
    """
    schema = MODULE_SCHEMA.get(module)
    if not schema or not schema.get("verified"):
        raise PresetError(
            "module %r is not verified for preset generation (%s); refusing to "
            "write a guessed block because a missing key aborts EasyEffects"
            % (module, UNVERIFIED_MODULES.get(module, "unknown")))
    live = live or {}
    block = {}
    for key, spec in schema["params"].items():
        # `live` is keyed by PUBLIC key (same as the preset), so a module that
        # is already in the chain keeps its settings through a rewrite.
        val = live.get(key)
        block[key] = spec["default"] if val is None else val
    bands = schema.get("json_bands")
    if bands:
        for i in range(bands["count"]):
            obj = {}
            for field, spec in bands["fields"].items():
                val = live.get(bands["public"][field] % i)
                obj[field] = spec["default"] if val is None else val
            block["%s%d" % (bands["prefix"], i)] = obj
    return block


# --------------------------------------------------------------------------
# The bridge
# --------------------------------------------------------------------------

class Bridge:
    def __init__(self, socket_path: str | None = None,
                 preset_dir: str | None = None,
                 ee: EasyEffects | None = None,
                 coalesce_seconds: float = COALESCE_SECONDS,
                 stream: str = "output"):
        self.socket_path = socket_path or default_socket_path()
        self.preset_dir = preset_dir or default_preset_dir()
        self.stream = stream
        self.coalesce = coalesce_seconds
        self.ee = ee if ee is not None else EasyEffects()
        self._lock = threading.RLock()
        self._pending: dict[tuple[str, str], object] = {}
        self._pending_readback: dict[tuple[str, str], str] = {}
        self._stop = threading.Event()
        self._flusher = None
        self._backup_hashes: set[str] = set()
        self.state: dict = {}
        self.last_result: dict = {}

    # -- chain discovery ---------------------------------------------------
    def config_chain(self) -> list[str]:
        """Ordered chain from EasyEffects' own KConfig file (authoritative)."""
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            return []
        section = ""
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("["):
                section = line
                continue
            if section == "[StreamOutputs]" and line.startswith("plugins="):
                return [t.strip() for t in line[len("plugins="):].split(",")
                        if t.strip()]
        return []

    @staticmethod
    def split_instance(token: str):
        """'equalizer#0' -> ('equalizer', '0')."""
        if "#" in token:
            mod, _, inst = token.partition("#")
            return mod, inst
        return token, "0"

    def probe_key_for(self, module: str) -> str:
        """Cheap IPC key used to test whether a module is in the chain.

        MUST be an IPC (camelCase) key, not the public one.
        """
        if module == "equalizer":
            return EQ_PARAMS["num-bands"]["ipc"]
        schema = MODULE_SCHEMA.get(module)
        if schema:
            for key, spec in schema["params"].items():
                if key != "bypass":
                    return spec["ipc"]
            return "bypass"
        return "bypass"

    def discover_chain(self) -> list[str]:
        """Live chain, ordered, as base module names.

        The KConfig ``plugins=`` list is only a HINT: EasyEffects flushes that
        file lazily, so right after a preset load it can still name the
        previous chain while IPC already serves the new one. The chain is
        therefore enumerated over IPC, which is authoritative, and the
        config file is used solely for ordering.
        """
        hint = [self.split_instance(t)[0] for t in self.config_chain()]
        ordered, seen = [], set()
        for module in list(hint) + list(KNOWN_MODULES):
            if module not in seen:
                seen.add(module)
                ordered.append(module)
        targets = []
        for module in ordered:
            key = self.probe_key_for(module)
            for inst in range(MAX_INSTANCES):
                targets.append(("%s:%d" % (module, inst), key))
        replies = self.ee.get_props(self.stream, targets)
        chain = []
        for module in ordered:
            found = False
            for inst in range(MAX_INSTANCES):
                idx = ordered.index(module) * MAX_INSTANCES + inst
                raw = replies[idx] if idx < len(replies) else ""
                if raw and not raw.startswith("error_"):
                    found = True
                    break
            if found:
                chain.append(module)
        return chain

    # -- state -------------------------------------------------------------
    def refresh(self, force: bool = False) -> dict:
        """Fetch the full state in as few round trips as possible."""
        with self._lock:
            if self.state and not force:
                return self.state
            eq_wire = "equalizer:0"
            # One round trip for the equalizer top level, one for all bands.
            top_pub = list(EQ_PARAMS.keys())
            top_ipc = [EQ_PARAMS[k]["ipc"] for k in top_pub]
            top = self.ee.get_many(self.stream, eq_wire, top_ipc)
            state = {"equalizer": {"params": {}, "bands": []}}
            for pub, spec, raw in zip(top_pub, EQ_PARAMS.values(), top):
                state["equalizer"]["params"][pub] = decode_public(spec, raw)
            num = state["equalizer"]["params"].get("num-bands") or 10
            num = max(1, min(MAX_BANDS, int(num)))

            band_keys, sides = [], []
            for side in ("left", "right"):
                for i in range(num):
                    for field in EQ_BAND_PARAMS:
                        band_keys.append("%s:band%d%s" % (side, i, field))
                        sides.append((side, i, field))
            replies = self.ee.get_many(self.stream, eq_wire, band_keys)
            left, right = {}, {}
            for (side, i, field), raw in zip(sides, replies):
                val = decode_public(EQ_BAND_PARAMS[field], raw)
                (left if side == "left" else right).setdefault(i, {})[field] = val
            bands = []
            for i in range(num):
                l, r = left.get(i, {}), right.get(i, {})
                bands.append({
                    "index": i,
                    "frequency": l.get("Frequency"),
                    "gain": l.get("Gain"),
                    "q": l.get("Q"),
                    "type": l.get("Type"),
                    "mode": l.get("Mode"),
                    "width": l.get("Width"),
                    "slope": l.get("Slope"),
                    "solo": l.get("Solo"),
                    "mute": l.get("Mute"),
                    "rightFrequency": r.get("Frequency"),
                    "rightGain": r.get("Gain"),
                    "rightQ": r.get("Q"),
                })
            state["equalizer"]["numBands"] = num
            state["equalizer"]["bands"] = bands

            chain = self.discover_chain()
            state["chain"] = chain
            state["preset"] = self.ee.last_loaded_preset(self.stream)
            modules = {}
            for module in chain:
                inst = self._instance_for(module)
                wire = "%s:%s" % (module, inst)
                if module == "equalizer":
                    modules[module] = {"bypass": state["equalizer"]["params"].get("bypass")}
                    continue
                schema = MODULE_SCHEMA.get(module)
                if not schema:
                    modules[module] = {"present": True, "bypass": None}
                    continue
                # values are reported under the PUBLIC (preset) key so QML
                # never sees EasyEffects' camelCase IPC spelling
                pub = list(schema["params"].keys())
                ipc = [schema["params"][k]["ipc"] for k in pub]
                replies = self.ee.get_many(self.stream, wire, ipc)
                vals = {}
                for key, spec, raw in zip(pub, schema["params"].values(),
                                          replies):
                    vals[key] = decode_public(spec, raw)
                bands_spec = schema.get("json_bands")
                if bands_spec:
                    band_pub, band_ipc = [], []
                    for i in range(bands_spec["count"]):
                        for field in bands_spec["fields"]:
                            band_pub.append(bands_spec["public"][field] % i)
                            band_ipc.append(bands_spec["ipc"][field] % i)
                    band_replies = self.ee.get_many(self.stream, wire,
                                                    band_ipc)
                    for pub, raw in zip(band_pub, band_replies):
                        field = pub.split(".")[-1]
                        vals[pub] = decode_public(bands_spec["fields"][field],
                                                  raw)
                modules[module] = vals
            state["modules"] = modules
            state["available"] = True
            state["snapshot"] = self._snapshot_hash(state)
            self.state = state
            return state

    def _instance_for(self, module: str) -> str:
        for token in self.config_chain():
            mod, inst = self.split_instance(token)
            if mod == module:
                return inst
        return "0"

    @staticmethod
    def _snapshot_hash(state: dict) -> str:
        payload = json.dumps(
            {k: state.get(k) for k in ("chain", "preset", "modules", "equalizer")},
            sort_keys=True, default=str)
        return hashlib.sha256(payload.encode()).hexdigest()[:16]

    # -- coalesced writes --------------------------------------------------
    def queue(self, wire: str, ipc_key: str, value, spec: dict) -> None:
        """Queue one coalesced write. `wire` is module:instance, `ipc_key` is the
        camelCase IPC key; `spec` drives encoding and readback verification."""
        with self._lock:
            self._pending[(wire, ipc_key)] = (value, spec)

    def pending_count(self) -> int:
        with self._lock:
            return len(self._pending)

    def flush(self) -> dict:
        """Write every coalesced change in ONE batch, then verify with ONE
        batched readback using the measured float tolerance."""
        with self._lock:
            if not self._pending:
                return {"written": 0, "verified": [], "mismatched": [],
                        "snapshot": self.state.get("snapshot") if self.state else None}
            pending, self._pending = self._pending, {}
        writes, readback = [], []
        for (wire, ipc_key), (value, spec) in sorted(pending.items()):
            writes.append((wire, ipc_key, encode_public(spec, value)))
            readback.append((wire, ipc_key, spec, value))
        try:
            self.ee.set_many(self.stream, writes)
        except BridgeUnavailable as exc:
            # Put the work back so a later flush can retry.
            with self._lock:
                for item in pending.items():
                    self._pending.setdefault(item[0], item[1])
            return {"written": 0, "error": ERR_UNAVAILABLE, "detail": str(exc),
                    "mismatched": []}

        # One batched readback for the whole window.
        by_module: dict[str, list[str]] = {}
        for wire, ipc_key, _spec, _want in readback:
            by_module.setdefault(wire, []).append(ipc_key)
        actual: dict[tuple[str, str], str] = {}
        for wire, keys in by_module.items():
            try:
                replies = self.ee.get_many(self.stream, wire, keys)
            except BridgeUnavailable as exc:
                return {"written": len(writes), "error": ERR_UNAVAILABLE,
                        "detail": str(exc), "mismatched": []}
            for ipc_key, raw in zip(keys, replies):
                actual[(wire, ipc_key)] = raw

        verified, mismatched = [], []
        for wire, ipc_key, spec, want in readback:
            raw = actual.get((wire, ipc_key), "")
            got = decode_public(spec, raw)
            tol = 0.0
            if spec["type"] == "float":
                # EasyEffects clamps and quantises: gains read back within
                # ~0.051 dB, frequencies within ~0.51 Hz.
                tol = FREQ_TOLERANCE if "Frequency" in ipc_key else GAIN_TOLERANCE
            if got is None:
                mismatched.append({"module": wire, "key": ipc_key, "want": want,
                                   "got": raw or None})
            elif isinstance(want, float) and isinstance(got, float) \
                    and abs(got - want) > tol:
                mismatched.append({"module": wire, "key": ipc_key, "want": want,
                                   "got": got})
            elif not isinstance(want, float) and got != want:
                mismatched.append({"module": wire, "key": ipc_key, "want": want,
                                   "got": got})
            else:
                verified.append({"module": wire, "key": ipc_key, "value": got})

        # Fold the readback into the cache. No extra round trip: the readback we
        # just did IS the fresh state for everything we wrote.
        with self._lock:
            for wire, ipc_key, spec, _want in readback:
                base = wire.split(":")[0]
                raw = actual.get((wire, ipc_key))
                val = decode_public(spec, raw) if raw is not None else None
                if base == "equalizer":
                    if ipc_key.startswith(("left:", "right:")):
                        self._fold_equalizer(ipc_key, val)
                    else:
                        pub = _IPC_INDEX.get((base, ipc_key), ipc_key)
                        self.state.get("equalizer", {}).get(
                            "params", {})[pub] = val
                else:
                    mod_state = self.state.get("modules", {}).get(base)
                    if isinstance(mod_state, dict):
                        mod_state[_IPC_INDEX.get((base, ipc_key),
                                                 ipc_key)] = val
            if self.state:
                self.state["snapshot"] = self._snapshot_hash(self.state)
        result = {"written": len(writes), "verified": verified,
                  "mismatched": mismatched,
                  "snapshot": self.state.get("snapshot") if self.state else None}
        self.last_result = result
        return result

    def _fold_equalizer(self, key: str, value) -> None:
        """Apply a verified band readback to the cached equalizer state.

        The IPC field is capitalised ("band0Gain") while the cache stores
        lower-case keys ("gain", "rightGain"), so the name has to be mapped -
        assigning band["Gain"] would silently create a dead key and leave
        status() reporting the previous value forever.
        """
        if not key.startswith(("left:", "right:")):
            return
        side, _, rest = key.partition(":")
        m = re.match(r"^band(\d+)(\w+)$", rest)
        if not m or value is None:
            return
        idx, field = int(m.group(1)), m.group(2)
        target = field[0].lower() + field[1:]
        if side != "left":
            target = "right" + field[0].upper() + field[1:]
        for band in self.state.get("equalizer", {}).get("bands", []):
            if band.get("index") == idx and target in band:
                band[target] = value

    def _sync_flush(self) -> dict:
        """Flush and turn an unconfirmed write into an explicit failure."""
        out = self.flush()
        if out.get("mismatched"):
            out["ok"] = False
            out["error"] = "write_not_confirmed"
        return out

    def start_flusher(self) -> None:
        if self._flusher is not None:
            return

        def loop():
            while not self._stop.wait(self.coalesce):
                if self.pending_count():
                    try:
                        self.flush()
                    except Exception as exc:  # never kill the daemon
                        log("flush failed: %r" % (exc,))

        self._flusher = threading.Thread(target=loop, name="inir-flush",
                                          daemon=True)
        self._flusher.start()

    def stop(self) -> None:
        self._stop.set()
        if self._flusher is not None:
            self._flusher.join(timeout=2.0)
            self._flusher = None

    # -- presets -----------------------------------------------------------
    def preset_path(self, name: str) -> str:
        return safe_preset_path(self.preset_dir, name)

    def list_presets(self) -> list[str]:
        try:
            names = os.listdir(self.preset_dir)
        except OSError:
            return []
        out = []
        for n in sorted(names):
            if n.endswith(".json") and not n.startswith("."):
                out.append(n[:-5])
        return out

    def read_preset(self, name: str) -> dict:
        with open(self.preset_path(name), "r", encoding="utf-8") as fh:
            return json.load(fh)

    def backup_preset(self, name: str) -> str | None:
        """Copy the preset to .inir-backup/<name>-<utc>.json, at most once per
        distinct file content. Backups are never deleted."""
        path = self.preset_path(name)
        if not os.path.exists(path):
            return None
        with open(path, "rb") as fh:
            data = fh.read()
        digest = hashlib.sha256(data).hexdigest()
        if digest in self._backup_hashes:
            return None
        backup_dir = os.path.join(self.preset_dir, BACKUP_DIRNAME)
        os.makedirs(backup_dir, exist_ok=True)
        stamp = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
        safe = re.sub(r"[^A-Za-z0-9._+ -]", "_", name)
        dest = os.path.join(backup_dir, "%s-%s.json" % (safe, stamp))
        n = 1
        while os.path.exists(dest):
            dest = os.path.join(backup_dir, "%s-%s-%d.json" % (safe, stamp, n))
            n += 1
        fd, tmp = tempfile.mkstemp(dir=backup_dir, prefix=".tmp-backup-")
        try:
            with os.fdopen(fd, "wb") as fh:
                fh.write(data)
            shutil.copymode(path, tmp)
            os.replace(tmp, dest)
        except BaseException:
            if os.path.exists(tmp):
                os.unlink(tmp)
            raise
        self._backup_hashes.add(digest)
        log("backed up preset %r -> %s" % (name, dest))
        return dest

    def _stream_root(self) -> dict:
        # blocklist and plugins_order are both mandatory in an EasyEffects
        # preset: a missing blocklist makes the loader throw and abort.
        return {self.stream: {"blocklist": [], "plugins_order": []}}

    def build_preset(self, modules: list[str], base: dict | None,
                     num_bands: int | None = None,
                     gains: dict[int, float] | None = None,
                     live_values: dict | None = None,
                     activate: set | None = None) -> dict:
        """Build a preset whose plugins_order is exactly `modules`.

        Existing blocks are preserved verbatim so unknown/user keys survive; a
        module that is new to the chain gets a complete neutral block.

        SAFETY: a module that is NOT already in the chain is installed BYPASSED
        (silent) unless it is named in `activate`. Presence in `live_values` is
        what distinguishes "new" from "already running", so a module the user
        already enabled keeps its live bypass state even when it is also listed
        in `activate`.
        """
        preset = base if isinstance(base, dict) else self._stream_root()
        live_values = live_values or {}
        activate = set(activate or ())
        root = preset.setdefault(self.stream, {"blocklist": [], "plugins_order": []})
        root.setdefault("blocklist", [])
        order = []
        for module in modules:
            if module not in KNOWN_MODULES:
                raise PresetError("unknown module %r" % module)
            if module in UNVERIFIED_MODULES:
                raise PresetError(
                    "module %r cannot be installed safely (%s)"
                    % (module, UNVERIFIED_MODULES[module]))
            instance = 0
            key = "%s#%d" % (module, instance)
            if key not in root:
                # Try to reuse an existing block for this module at any instance.
                reused = None
                for k in list(root.keys()):
                    if "#" in k and k.split("#")[0] == module:
                        reused = k
                        break
                if reused is not None and module != "equalizer":
                    root[key] = root.pop(reused)
                elif reused is not None:
                    # equalizer block is regenerated below (band count is structural)
                    pass
            if module == "equalizer":
                existing = root.get(key)
                merged = existing if isinstance(existing, dict) else {}
                count = num_bands if num_bands is not None else int(
                    merged.get("num-bands") or 10)
                # Keep the user's curve: explicit gains win, else the live
                # equalizer curve, else whatever the existing block holds.
                band_gains = gains
                if band_gains is None:
                    band_gains = live_values.get("equalizerBands")
                if band_gains is None and isinstance(merged.get("left"), dict):
                    band_gains = {i: v.get("gain")
                                  for i, v in merged["left"].items()}
                # The live bypass state wins: the preset file often disagrees
                # with what is actually running.
                live_eq = live_values.get("equalizer") or {}
                live_eq_bypass = live_eq.get("bypass")
                if live_eq_bypass is None:
                    live_eq_bypass = merged.get("bypass")
                block = build_equalizer_block(count, band_gains,
                                              live_eq_bypass)
                # A newly installed equalizer must be silent too, exactly like
                # every other module: installing a chain must not change what
                # the user hears until they deliberately ask for it.
                if not live_values.get("equalizer"):
                    block["bypass"] = module not in activate
                # carry the live master gains / balance / pitch across, mapping
                # the public key to the preset spelling
                for pub, val in (live_values.get("equalizerParams")
                                 or {}).items():
                    if val is None or pub == "num-bands":
                        continue
                    preset_key = EQ_PARAMS.get(pub, {}).get("preset", pub)
                    if preset_key in block:
                        block[preset_key] = val
                # Preserve any extra user keys we do not manage.
                for k, v in merged.items():
                    if k not in block:
                        block[k] = v
                root[key] = block
            else:
                existing = root.get(key)
                if not isinstance(existing, dict):
                    existing = {}
                # Every required key must be present or EasyEffects aborts.
                # The LIVE chain is the source of truth for the keys we manage:
                # the preset file is often stale, and letting it win here would
                # silently reset the user's settings. Keys we do not manage are
                # carried over untouched.
                managed = set(MODULE_SCHEMA[module]["params"].keys())
                bands_spec = MODULE_SCHEMA[module].get("json_bands")
                if bands_spec:
                    managed |= {"%s%d" % (bands_spec["prefix"], i)
                               for i in range(bands_spec["count"])}
                block = build_module_block(module, live_values.get(module))
                for k, v in existing.items():
                    if k not in managed:
                        block[k] = v
                # New to the chain -> installed bypassed, unless the caller
                # deliberately asked for this one to come up active. Already in
                # the chain -> leave the live bypass state alone.
                if not live_values.get(module):
                    block["bypass"] = module not in activate
                root[key] = block
            order.append(key)
        root["plugins_order"] = order
        return preset

    def write_preset(self, name: str, preset: dict) -> str:
        path = self.preset_path(name)
        # Back up BEFORE the first write, never after.
        self.backup_preset(name)
        payload = json.dumps(preset, indent=2) + "\n"
        fd, tmp = tempfile.mkstemp(dir=self.preset_dir, prefix=".inir-preset-")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(payload)
            os.chmod(tmp, 0o600)
            os.replace(tmp, path)
        except BaseException:
            if os.path.exists(tmp):
                os.unlink(tmp)
            raise
        return path

    def ipc_keys_for(self, module: str) -> list[str]:
        """Every IPC key accepted for a module (debugging aid; the public API
        is public_keys_for)."""
        schema = MODULE_SCHEMA.get(module)
        if not schema:
            return [EQ_PARAMS[k]["ipc"] for k in EQ_PARAMS]
        keys = [spec["ipc"] for spec in schema["params"].values()]
        bands_spec = schema.get("json_bands")
        if bands_spec:
            for i in range(bands_spec["count"]):
                keys += [tmpl % i for tmpl in bands_spec["ipc"].values()]
        return keys

    def _target_preset(self) -> str:
        """Preset file to rewrite. Prefer the one EasyEffects has loaded, but
        fall back to a writable default when that name is unusable (EasyEffects
        keeps a stale lastLoadedOutputPreset if the file was deleted)."""
        name = self.ee.last_loaded_preset(self.stream)
        if name:
            try:
                self.preset_path(name)
                return name
            except PresetError:
                log("last loaded preset %r is not a usable preset name; "
                    "falling back" % name)
        return FALLBACK_PRESET

    def _live_preset_values(self) -> dict:
        """Values currently live in the chain, so a preset rewrite performed to
        add a module never silently resets the modules already there."""
        try:
            st = self.refresh(force=True)
        except BridgeUnavailable:
            return {}
        out = {m: dict(v) for m, v in st.get("modules", {}).items()
               if isinstance(v, dict)}
        bands = {}
        for b in st.get("equalizer", {}).get("bands", []):
            if b.get("gain") is not None:
                bands[b["index"]] = b["gain"]
        if bands:
            out["equalizerBands"] = bands
        # the equalizer's top-level params (master gains, balance, pitch) live
        # outside "modules"; without them a chain rewrite would regenerate them
        # at their defaults and silently discard the user's values
        eq_params = st.get("equalizer", {}).get("params") or {}
        if eq_params:
            out["equalizerParams"] = dict(eq_params)
        return out

    def ensure_chain(self, desired: list[str], num_bands: int | None = None,
                     gains: dict[int, float] | None = None,
                     activate: list | None = None) -> dict:
        """Idempotent: does nothing at all when the chain already matches.

        `activate` names modules that must come out of the install BYPASSED=false.
        It only ever applies to a module that is NOT already in the chain: a
        module the user already set keeps its live bypass state, so `activate`
        can never silently re-bypass or un-bypass running audio.

        Verified limitation of EasyEffects 8.3.0: ``load_preset`` only APPENDS
        plugins. It cannot remove one and it cannot reorder, so a chain that is
        not a pure extension of the live one is refused rather than written.
        To drop modules, remove them in the EasyEffects window (or restart it,
        which rebuilds the chain from its KConfig ``plugins=`` list).
        Growing a chain, and any band-count change, work immediately.
        """
        desired = list(desired)
        activate = [str(m) for m in (activate or [])]
        for m in desired:
            if m in UNVERIFIED_MODULES:
                raise PresetError("module %r cannot be installed safely (%s)"
                                  % (m, UNVERIFIED_MODULES[m]))
            if m not in KNOWN_MODULES:
                raise PresetError("unknown module %r" % m)
        for m in activate:
            if m in UNVERIFIED_MODULES:
                raise PresetError(
                    "module %r cannot be activated safely (%s)"
                    % (m, UNVERIFIED_MODULES[m]))
            if m not in KNOWN_MODULES:
                raise PresetError("unknown module %r in activate" % m)

        current = self.discover_chain()
        target_preset = self._target_preset()
        need_bands = None
        if num_bands is not None:
            st = self.refresh(force=True)
            if st["equalizer"].get("numBands") != num_bands:
                need_bands = num_bands

        cur_set, des_set = set(current), set(desired)
        if cur_set == des_set and need_bands is None:
            # Nothing to install, so `activate` has nothing to act on. Say so
            # rather than pretending: a module named in `activate` that is
            # already in the chain keeps its live bypass state by design, and the
            # caller (the panel) must use set_module to toggle it.
            return {"changed": False, "chain": current, "preset": target_preset,
                    "reloaded": False,
                    "installed": [], "activated": [],
                    "activateIgnored": [m for m in activate if m in cur_set]}

        # Verified limitation of EasyEffects 8.3.0: load_preset only APPENDS
        # plugins. It cannot remove one, so a chain that needs a module
        # dropped would silently do nothing. Refuse BEFORE writing, otherwise
        # the preset is overwritten and the operation then fails verification.
        # Comparison is by SET: the true processing order is only knowable from
        # the KConfig plugins= list, which EasyEffects flushes lazily, so
        # immediately after a load the reported order is not reliable.
        # An identical module set is always allowed: it is either a no-op or a
        # band-count change, and a reorder cannot be expressed over IPC anyway.
        if cur_set != des_set and not cur_set < des_set:
            raise PresetError(
                "EasyEffects 8.3.0 can only append plugins: load_preset cannot "
                "remove one (verified). Live chain is %s and the requested chain "
                "%s is not a strict extension of it, so nothing was written; drop "
                "the extra modules in the EasyEffects window (or restart it, "
                "which rebuilds the chain from its plugins= list) first."
                % (current, desired))

        base = None
        try:
            base = self.read_preset(target_preset)
        except (OSError, ValueError, PresetError):
            base = None
        live_values = self._live_preset_values()
        added = [m for m in desired if m not in set(current)]
        preset = self.build_preset(desired, base, num_bands, gains,
                                   live_values, activate)
        self.write_preset(target_preset, preset)
        reply = self.ee.load_preset(target_preset, self.stream)
        if reply.startswith("error_"):
            raise PresetError("load_preset failed: %s" % reply)
        # Verify by reading the chain back (by set: see the note above).
        after = []
        for _ in range(20):
            after = self.discover_chain()
            if set(after) == des_set:
                break
            time.sleep(0.05)
        self.refresh(force=True)
        if set(after) != des_set:
            raise PresetError("chain verification failed: wanted %s, got %s"
                              % (desired, after))
        return {"changed": True, "chain": after, "preset": target_preset,
                "reloaded": True, "bands": num_bands,
                # observability for the panel: what went in, and what came up
                # un-bypassed. `activateIgnored` names modules the caller asked
                # to activate that were already running, so their live bypass
                # state was left alone on purpose.
                "installed": added,
                "activated": [m for m in activate if m in added],
                "activateIgnored": [m for m in activate if m not in added]}

    # -- command dispatch --------------------------------------------------
    def handle(self, req: dict) -> dict:
        cmd = req.get("cmd")
        fn = getattr(self, "cmd_" + cmd, None) if isinstance(cmd, str) else None
        if fn is None:
            return {"ok": False, "error": "unknown_command",
                    "detail": "unknown command %r" % (cmd,)}
        try:
            return fn(req)
        except PresetError as exc:
            return {"ok": False, "error": "preset_error", "detail": str(exc)}
        except BridgeUnavailable as exc:
            return {"ok": False, "error": ERR_UNAVAILABLE, "detail": str(exc)}
        except (KeyError, TypeError, ValueError) as exc:
            return {"ok": False, "error": "bad_request", "detail": repr(exc)}
        except Exception as exc:  # pragma: no cover - defensive
            log("command %r failed: %r" % (cmd, exc))
            return {"ok": False, "error": "internal_error", "detail": repr(exc)}

    # commands -------------------------------------------------------------
    def cmd_ping(self, req):
        return {"ok": True, "pong": True, "version": VERSION,
                "pid": os.getpid(), "pending": self.pending_count()}

    def cmd_status(self, req):
        try:
            # Engine LIVENESS must never be served from the cache: a stale
            # snapshot would keep answering available:True after EasyEffects
            # died and the panel would never learn it had to offer opening it.
            # Cached parameter VALUES are fine; only the liveness read is
            # forced. This is not a hot path - every other caller of refresh()
            # passes force=True already, and the panel asks for status on open,
            # on the refresh button and on a failed reconnect, not in a loop.
            st = self.refresh(force=True)
        except BridgeUnavailable as exc:
            return {"ok": False, "error": ERR_UNAVAILABLE, "detail": str(exc),
                    "available": False}
        eq = st["equalizer"]
        p = eq["params"]
        return {
            "ok": True,
            "available": True,
            "preset": st["preset"],
            "chain": st["chain"],
            "modules": st["modules"],
            "equalizer": {
                "numBands": eq["numBands"],
                "bands": [{k: b[k] for k in
                           ("index", "frequency", "gain", "q", "type", "mode")}
                          for b in eq["bands"]],
                # master gains are reported on the camelCase path the panel uses
                "inputGain": p.get("inputGain"),
                "outputGain": p.get("outputGain"),
                "balance": p.get("balance"),
                "splitChannels": p.get("split-channels"),
                "bypass": p.get("bypass"),
            },
            "spec": self.module_spec(),
            "snapshot": st["snapshot"],
            "eeStats": dict(self.ee.stats),
        }

    @staticmethod
    def module_spec() -> dict:
        """Per-module parameter spec for the panel.

        Keys are PUBLIC (preset-JSON) names. Each entry is
        {key, min, max, default, unit, type} - and, when the parameter is a
        labelled enum, a "values" list of the accepted labels. The camelCase
        IPC spelling is deliberately NOT exposed.
        """
        out = {}
        for module in sorted({"equalizer"} | set(MODULE_SCHEMA)):
            entries = []
            if module == "equalizer":
                src = [("equalizer", k, v) for k, v in EQ_PARAMS.items()]
            else:
                schema = MODULE_SCHEMA[module]
                src = [(module, k, v) for k, v in schema["params"].items()]
                bands_spec = schema.get("json_bands")
                if bands_spec:
                    for i in range(bands_spec["count"]):
                        for field, fspec in bands_spec["fields"].items():
                            src.append((module,
                                        bands_spec["public"][field] % i,
                                        fspec))
            for _mod, key, spec in src:
                entry = {
                    "key": key,
                    "min": spec.get("min"),
                    "max": spec.get("max"),
                    "default": spec.get("default"),
                    "unit": spec.get("unit"),
                    "type": spec["type"],
                }
                if spec.get("enum"):
                    entry["values"] = list(spec["enum"])
                entries.append(entry)
            out[module] = entries
        return out

    def cmd_refresh(self, req):
        try:
            st = self.refresh(force=True)
        except BridgeUnavailable as exc:
            return {"ok": False, "error": ERR_UNAVAILABLE, "detail": str(exc)}
        return {"ok": True, "snapshot": st["snapshot"], "chain": st["chain"]}

    def _band_writes(self, bands) -> list[tuple[str, str, object, dict]]:
        """Translate public band requests into (wire, ipc_key, value, spec)
        writes.

        `type` and `mode` are enums and travel the same path as the numeric
        fields, but they are validated HERE rather than at flush time: an
        unknown label must be an explicit error and must write NOTHING, so a
        bad label can never half-apply a batch. `encode_public` performs the
        label check (it is the only place that knows the label set), and the
        ValueError it raises is what the command layer turns into an error
        reply - the whole entry is rejected, not just the offending field.
        """
        out = []
        for entry in bands:
            idx = int(entry["index"])
            if not 0 <= idx < MAX_BANDS:
                raise ValueError("band index %d out of range 0..%d"
                                 % (idx, MAX_BANDS - 1))
            for field in ("gain", "frequency", "q", "type", "mode"):
                if entry.get(field) is not None:
                    fieldname = field[0].upper() + field[1:]
                    spec = EQ_BAND_PARAMS[fieldname]
                    value = entry[field]
                    # Fail before queueing anything for this band. Also
                    # normalises an integer index that a caller read back out
                    # of status() into the label the public key space uses.
                    value = encode_public(spec, value)
                    if spec["type"] == "enum":
                        # Keep the canonical LABEL as the queued value so the
                        # readback compares label-to-label.
                        value = spec["enum"][int(value)]
                    else:
                        value = entry[field]
                    out.append(("equalizer:0",
                                "left:band%d%s" % (idx, fieldname),
                                value, spec))
                    out.append(("equalizer:0",
                                "right:band%d%s" % (idx, fieldname),
                                value, spec))
        return out

    def cmd_set_band(self, req):
        writes = self._band_writes([req])
        for wire, key, value, kind in writes:
            self.queue(wire, key, value, kind)
        out = {"ok": True, "queued": len(writes)}
        if req.get("sync"):
            out.update(self._sync_flush())
        return out

    def cmd_set_bands(self, req):
        bands = req.get("bands")
        if not isinstance(bands, list):
            raise ValueError("bands must be a list")
        writes = self._band_writes(bands)
        for wire, key, value, spec in writes:
            self.queue(wire, key, value, spec)
        out = {"ok": True, "queued": len(writes)}
        if req.get("sync"):
            out.update(self._sync_flush())
        return out

    def cmd_set_module(self, req):
        module = str(req["module"])
        active = bool(req["active"])
        if module not in KNOWN_MODULES:
            raise ValueError("unknown module %r" % module)
        wire = "%s:%s" % (module, self._instance_for(module))
        self.queue(wire, "bypass", not active, {"type": "bool"})
        out = {"ok": True, "queued": 1, "module": module,
               "bypass": not active, "reloaded": False}
        if req.get("sync"):
            out.update(self._sync_flush())
        return out

    def _param_write(self, module: str, key: str, value) -> tuple:
        """Public (module, key, value) -> a queueable write, validated HERE.

        `key` is the PUBLIC preset key (kebab-case); the IPC spelling is
        resolved here and never leaves the bridge. Every value is encoded
        eagerly so an unknown key, a bad number or an unknown enum label is
        reported by the command layer - i.e. BEFORE anything is queued - rather
        than at flush time, where a half-applied batch is already on the wire.

        Shared by set_param and apply_bundle so there is exactly one translator
        from the public key space to the wire.
        """
        if module not in KNOWN_MODULES:
            raise ValueError("unknown module %r" % module)
        if module != "equalizer" and module not in MODULE_SCHEMA:
            raise ValueError("module %r has no verified params" % module)
        ipc_key, spec = ipc_key_for(module, key)
        if spec is None:
            raise ValueError(
                "%r is not a public key of %r; known keys: %s"
                % (key, module, public_keys_for(module)))
        wire = "%s:%s" % (module, self._instance_for(module))
        encode_public(spec, value)
        return wire, ipc_key, value, spec

    def cmd_set_param(self, req):
        """`key` is the PUBLIC preset key (kebab-case); the IPC spelling is
        resolved here and never leaves the bridge."""
        module = str(req["module"])
        key = str(req["key"])
        wire, ipc_key, value, spec = self._param_write(module, key,
                                                      req["value"])
        self.queue(wire, ipc_key, value, spec)
        out = {"ok": True, "queued": 1, "key": canonical_key_for(module, key)}
        if req.get("sync"):
            out.update(self._sync_flush())
        return out

    def cmd_apply_bundle(self, req):
        """Apply a bundle of writes - the backend for a coherent "profile":
        a loudness target, a curve and module states - in ONE round trip.

        Optional sections, all of them independent and all optional:
          target   number, autogain's loudness target in LUFS, through the
                   normal public-key param path (`autogain.target`)
          bands    one gain per CURRENT band. An entry is either a bare number
                   (that band's gain) or an object {gain, frequency, q, type,
                   mode, index}, the long form sharing _band_writes' validation
          modules  [[id, activeBool], ...] -> each module's `bypass`

        Reply: ok, `applied` (what was really written) and `skipped` (what could
        not be). Nothing is reported as applied unless the readback confirmed it,
        so a failed write is never reported as a success.

        THE RULE: a module that is not in the live chain is SKIPPED, never
        installed. Installing is the separate, already-tested lazy path
        (set_chain with `activate`), and doing it here would turn one tap into a
        preset reload - a brief audio interruption - for something the caller
        only asked to apply. An absent or unknown module is therefore NOT an
        error: the rest of the bundle still applies.

        Every value is translated by the same helpers the single setters use
        (`_param_write`, `_band_writes`, `encode_public`), so enum labels are
        validated by label and booleans reach the wire as true/false. All of it
        is validated BEFORE anything is queued, and everything queued goes out
        in exactly ONE set_many via _sync_flush.
        """
        target = req.get("target")
        bands = req.get("bands")
        modules = req.get("modules")

        writes: list[tuple[str, str, object, dict]] = []
        # the module bypass writes, kept apart from the band writes so the reply
        # can report "applied.modules" per module id
        module_writes: list[tuple[str, str]] = []
        skipped: list[dict] = []
        # writes that were already queued by an earlier command ride along in
        # the same batch; recorded so the reply is not read as "the bundle was
        # the only thing written".
        carried_over = self.pending_count()
        # chain lookup is one round trip, so it is done at most once and only
        # when a section that needs it is present
        chain = None
        if target is not None or modules is not None:
            chain = self.discover_chain()

        if target is not None:
            # the target only means something on an installed autogain; writing
            # to an absent module would come back unconfirmed
            if "autogain" not in chain:
                skipped.append({"module": "autogain",
                                "reason": "not_in_chain"})
            else:
                writes.append(self._param_write("autogain", "target", target))

        if bands is not None:
            if not isinstance(bands, list):
                raise ValueError("bands must be a list")
            entries = []
            for i, item in enumerate(bands):
                if isinstance(item, dict):
                    entry = dict(item)
                    entry.setdefault("index", i)
                else:
                    entry = {"index": i, "gain": item}
                entries.append(entry)
            # One gain per CURRENT band: a wrong count would write bands that do
            # not exist, which EasyEffects accepts and silently discards, so it
            # is refused up front instead. Only checked when the count is known.
            expected = (self.state.get("equalizer") or {}).get("numBands")
            if expected is not None and len(entries) != int(expected):
                raise ValueError(
                    "bands must hold exactly %d gains, one per current band, "
                    "but %d were given" % (int(expected), len(entries)))
            writes.extend(self._band_writes(entries))

        if modules is not None:
            if not isinstance(modules, list):
                raise ValueError("modules must be a list of [id, active] pairs")
            for pair in modules:
                if not isinstance(pair, (list, tuple)) or len(pair) != 2:
                    raise ValueError("each module must be an [id, active] pair")
                module, active = str(pair[0]), pair[1]
                # A real JSON bool is required. `active: "false"` is a truthy
                # string, so accepting it would silently install the opposite
                # state, and the wire must carry true/false, never 1/0.
                if not isinstance(active, bool):
                    raise ValueError(
                        "active for %r must be a JSON bool, got %r"
                        % (module, active))
                if module not in KNOWN_MODULES:
                    skipped.append({"module": module,
                                    "reason": "unknown_module"})
                    continue
                if module not in chain:
                    # SKIP, never install: see the docstring.
                    skipped.append({"module": module,
                                    "reason": "not_in_chain"})
                    continue
                wire = "%s:%s" % (module, self._instance_for(module))
                module_writes.append((wire, "bypass"))
                writes.append((wire, "bypass", not active, {"type": "bool"}))

        # Validate-everything-then-queue: a request rejected above has queued
        # NOTHING, so it cannot half-apply.
        for wire, ipc_key, value, spec in writes:
            self.queue(wire, ipc_key, value, spec)

        intended = {(wire, ipc_key) for wire, ipc_key, _v, _s in writes}
        out = {"ok": True, "applied": {}, "skipped": skipped,
               "queued": len(writes), "carriedOver": carried_over}
        out.update(self._sync_flush())
        verified = {}
        for entry in out.get("verified", []):
            verified[(entry["module"], entry["key"])] = entry["value"]

        # `applied` is derived from the READBACK, never from the request: a
        # write that did not land must not be reported as having landed, so
        # anything queued but unconfirmed is named in `skipped` instead.
        def _queued_for(module):
            return [k for k in intended if k[0].split(":")[0] == module]

        def _confirmed(module):
            return [k for k in _queued_for(module) if k in verified]

        # Only a write that WAS queued can come back unconfirmed. A section
        # skipped before queueing already has its own reason and must not get a
        # second, contradictory one.
        if target is not None and _queued_for("autogain"):
            landed = _confirmed("autogain")
            if landed:
                out["applied"]["target"] = verified[landed[0]]
            else:
                skipped.append({"module": "autogain",
                                "reason": "write_not_confirmed"})
        if bands is not None:
            landed = _confirmed("equalizer")
            if landed:
                out["applied"]["bands"] = len(landed)
            if len(landed) < len(_queued_for("equalizer")):
                skipped.append({"module": "equalizer",
                                "reason": "band_write_not_confirmed"})
        confirmed_modules = {}
        for wire, ipc_key in module_writes:
            base = wire.split(":")[0]
            if (wire, ipc_key) in verified:
                # `applied.modules` reports the state asked for (active), which
                # is the inverse of the bypass the wire carries.
                confirmed_modules[base] = not verified[(wire, ipc_key)]
            else:
                skipped.append({"module": base,
                                "reason": "write_not_confirmed"})
        if confirmed_modules:
            out["applied"]["modules"] = confirmed_modules
        out["skipped"] = skipped
        return out

    def cmd_set_band_count(self, req):
        count = int(req["count"])
        if count not in ALLOWED_BAND_COUNTS:
            raise ValueError("count must be one of %s" % (ALLOWED_BAND_COUNTS,))
        # num-bands and the band list are structural -> preset rewrite + reload.
        current = self.discover_chain()
        if "equalizer" not in current:
            current = current + ["equalizer"]
        res = self.ensure_chain(current, num_bands=count)
        res["ok"] = True
        res["numBands"] = count
        return res

    def cmd_set_chain(self, req):
        """Install/reconcile the chain.

        Optional `activate`: module ids that must come out of the install with
        bypass=false. Every other module newly added comes out bypassed, so
        installing a chain is silent until the user deliberately enables
        something. A module already in the chain keeps its live bypass state.
        """
        modules = req.get("modules")
        if not isinstance(modules, list) or not modules:
            raise ValueError("modules must be a non-empty list")
        modules = [str(m) for m in modules]
        activate = req.get("activate")
        if activate is None:
            activate = []
        if not isinstance(activate, list):
            raise ValueError("activate must be a list of module ids")
        num_bands = req.get("numBands")
        res = self.ensure_chain(modules, num_bands=num_bands,
                                activate=activate)
        res["ok"] = True
        return res

    def cmd_apply_preset(self, req):
        name = str(req["name"])
        self.preset_path(name)  # validates / rejects traversal
        if not os.path.exists(self.preset_path(name)):
            raise PresetError("no such preset: %r" % name)
        reply = self.ee.load_preset(name, self.stream)
        if reply.startswith("error_"):
            raise PresetError("load_preset failed: %s" % reply)
        st = self.refresh(force=True)
        return {"ok": True, "applied": name, "chain": st["chain"],
                "snapshot": st["snapshot"]}

    # How close two frequencies must be for a live band and a preset entry to
    # be "the same band". Bands are authored on an octave grid, so an exact
    # float equality would be needlessly brittle and a loose one would happily
    # pair two neighbouring bands.
    BAND_MATCH_REL_TOL = 1e-4

    def _base_preset_for_save(self) -> tuple:
        """The on-disk preset a no-payload save overlays the live state onto.

        Normally the preset EasyEffects has loaded. When that name is empty
        (fresh install) or points at a file that is gone (EasyEffects keeps a
        stale lastLoadedOutputPreset after a delete) fall back to the most
        recently modified preset in the directory. Any real file is a better
        base than none, because a preset rebuilt from scratch is missing keys
        EasyEffects insists on -- the equalizer's "input-gain" among them --
        and the loader aborts on those.
        """
        name = self.ee.last_loaded_preset(self.stream)
        if name:
            try:
                # read_preset() takes the NAME, not a path: passing an already
                # resolved path makes safe_preset_path reject it (it appends
                # ".json" and re-checks for traversal).
                return self.read_preset(name), name
            except (PresetError, OSError, ValueError) as exc:
                log("last loaded preset %r is unusable as a save base (%s); "
                    "falling back to the newest preset" % (name, exc))
        cands = []
        for other in self.list_presets():
            try:
                cands.append((os.path.getmtime(self.preset_path(other)), other))
            except (PresetError, OSError):
                continue
        if not cands:
            raise PresetError(
                "nothing to save from: no preset is loaded and %s holds none"
                % self.preset_dir)
        newest = max(cands)[1]
        log("no usable last-loaded preset; saving from %r" % newest)
        return self.read_preset(newest), newest

    @classmethod
    def _band_values(cls, band: dict, right: bool) -> dict:
        """The live values that go into one preset band entry, by preset key.

        The preset spellings were read out of output/Default.json, not assumed:
        the band block is frequency/gain/q/type/mode/mute/solo/slope/width, and
        the first five names are identical to the IPC snapshot's. Kept as an
        explicit map so a future spelling change cannot silently drop a value.
        """
        if right:
            return {"frequency": band.get("rightFrequency"),
                    "gain": band.get("rightGain"),
                    "q": band.get("rightQ")}
        return {"frequency": band.get("frequency"),
                "gain": band.get("gain"),
                "q": band.get("q"),
                "type": band.get("type"),
                "mode": band.get("mode")}

    @classmethod
    def _match_bands(cls, side: dict, bands: list, right: bool) -> dict:
        """live band index -> the preset entry that band belongs to.

        Matched BY FREQUENCY, never by array position or by assuming index ==
        position: EasyEffects APPENDS bands at the end when the band count
        grows, so a curve that was extended in the panel has its engine order
        out of step with the display order the preset was written in.

        A live band whose frequency matches nothing is deliberately left
        unmatched: guessing a neighbour would move the user's curve rather than
        save it, so that entry keeps the value the file already had.
        """
        out = {}
        for band in bands:
            want = band.get("rightFrequency" if right else "frequency")
            if want is None:
                continue
            for entry in side.values():
                if not isinstance(entry, dict):
                    continue
                have = entry.get("frequency")
                if have is None:
                    continue
                tol = max(0.01, abs(float(have)) * cls.BAND_MATCH_REL_TOL)
                if abs(float(have) - float(want)) <= tol:
                    out[band["index"]] = entry
                    break
        return out

    def _overlay_module(self, module: str, block: dict, live: dict) -> int:
        """Write a module's whole live parameter map over its preset block.

        EVERY parameter is overlaid, not just `bypass`: the base file is a
        snapshot of whenever the preset was last rewritten, so a module the
        user has been adjusting in the panel had all of its settings - the
        bass enhancer's amount and floor, autogain's target, the limiter's
        threshold and lookahead - read back from that stale file.

        A `None` means "the engine would not tell us" (an out-of-range read, a
        module that is not in the chain); the base value is kept for those,
        because writing a guessed value over a known-good one is strictly
        worse than leaving it.
        """
        written = 0
        for pkey, value in live.items():
            if value is None or pkey == "present":
                continue
            head, _, field = pkey.partition(".")
            if not field:
                # a JSON bool for bypass, never 0/1: the loader reads them
                # differently. Everything else is already the preset spelling,
                # because the live map is keyed by the PUBLIC (preset) name.
                block[pkey] = value
                written += 1
                continue
            # A dotted public key ("band0.intensity") is how the panel
            # addresses a band, but the PRESET stores that band as a nested
            # object. Confirmed on disk in output/Default.json: the
            # crystalizer has "band0" .. "band12", each a dict of
            # intensity/mute/bypass, and no key anywhere contains a dot.
            # Writing the dotted form verbatim would put a "band0.intensity"
            # key in the preset that EasyEffects cannot read.
            sub = block.get(head)
            if sub is None:
                sub = {}
                block[head] = sub
            elif not isinstance(sub, dict):
                # Never clobber an unknown scalar with a dict: the shape on
                # disk is not what we expect, so leave it alone.
                log("%s: %r is not an object; refusing to expand %r into it"
                    % (module, head, pkey))
                continue
            sub[field] = value
            written += 1
        return written

    def _overlay_live_state(self, preset: dict, st: dict) -> dict:
        """Copy the base preset and write the live engine state over it.

        Every module parameter and every equalizer band. The base is left
        alone everywhere else, so its "#0" instance names, its blocklist, its
        plugins_order and the keys this build never reports all stay exactly as
        EasyEffects wrote them. Nothing here loads a preset or sets a value the
        user did not choose.
        """
        root = preset.get(self.stream)
        if not isinstance(root, dict):
            raise PresetError("preset base carries no %r object" % self.stream)
        modules = st.get("modules") or {}
        written = 0
        for key, block in root.items():
            if "#" not in key or not isinstance(block, dict):
                continue
            module = self.split_instance(key)[0]
            live = modules.get(module)
            if not isinstance(live, dict):
                continue
            if module == "equalizer":
                # its live entry carries ONLY bypass; the bands arrive in
                # eq["bands"] and are written below. Handling it here on its
                # own keeps the two paths from ever overlapping.
                if live.get("bypass") is not None:
                    block["bypass"] = bool(live["bypass"])
                    written += 1
                continue
            written += self._overlay_module(module, block, live)
        eq = st.get("equalizer") or {}
        bands = eq.get("bands") or []
        block = None
        for token in list(root.get("plugins_order") or []) + list(root.keys()):
            if "#" in str(token) and self.split_instance(str(token))[0] == \
                    "equalizer":
                block = root.get(str(token))
                if isinstance(block, dict):
                    break
                block = None
        if block is None:
            log("overlaid live state onto the save base: %d values (no "
                "equalizer block in the base)" % written)
            return preset
        left = block.get("left") if isinstance(block.get("left"), dict) else {}
        right = block.get("right") if isinstance(block.get("right"), dict) else {}
        for side, is_right in ((left, False), (right, True)):
            matches = self._match_bands(side, bands, is_right)
            for band in bands:
                entry = matches.get(band["index"])
                if entry is None:
                    continue
                for pkey, value in self._band_values(band, is_right).items():
                    if value is not None:
                        entry[pkey] = value
                        written += 1
        num = eq.get("numBands")
        if num is not None:
            # Only when the base really has that many bands. A count the file
            # cannot back would leave the loader reading band entries that do
            # not exist, and growing the chain is cmd_set_band_count's job
            # anyway -- it rewrites this file properly before reloading.
            if not left or int(num) <= len(left):
                block["num-bands"] = int(num)
            else:
                log("live band count %s exceeds the %d bands in the save "
                    "base; leaving the file's count alone" % (num, len(left)))
        log("overlaid live state onto the save base: %d values" % written)
        return preset

    def _promote_pending_writes(self) -> None:
        """Land the coalescing window's writes BEFORE reading the state back.

        set_param queues, so a toggle made a few milliseconds before the save
        can still be sitting in `self._pending`: the engine does not have it yet
        and reading the engine would store the value before it. That is exactly
        the "I toggled it and the save did not keep it" report.

        This does not change what the user is hearing. It writes only what is
        ALREADY queued there - every entry is a (wire, key, value) triple the
        user set through this same bridge, validated by the same spec on the
        way in. Nothing is invented, defaulted or adjusted: the background
        flusher (see start_flusher) would have written these milliseconds
        later anyway, so the only difference is that the save can see them.
        flush() also verifies each write with a batched readback, so a value
        the engine rejected is not silently recorded as saved - the read below
        picks up whatever the engine actually holds.

        A failure here is not fatal to the save: refresh() decides whether the
        engine is reachable, and if it is, the state it reports is the truth.
        """
        if not self.pending_count():
            return
        res = self.flush()
        if res.get("error"):
            log("could not promote %d pending write(s) before saving (%s); "
                "saving the state the engine actually holds"
                % (len(self._pending), res.get("detail")))
        elif res.get("mismatched"):
            log("%d pending write(s) did not verify before saving; the engine "
                "kept its own value" % len(res["mismatched"]))

    def _preset_from_live_state(self) -> dict:
        """Build what a no-payload save_preset writes.

        The panel sends only a name, so the payload has to be assembled here or
        every change made in the panel is thrown away: the last-loaded preset
        FILE is stale (band moves, module settings and module bypasses live in
        the engine until something rewrites it), so saving it back stored what
        the user was NOT hearing.
        """
        base, _name = self._base_preset_for_save()
        self._promote_pending_writes()
        try:
            st = self.refresh(force=True)
        except BridgeUnavailable as exc:
            raise PresetError("cannot save: the engine is unreachable (%s)"
                              % exc)
        return self._overlay_live_state(base, st)

    def cmd_save_preset(self, req):
        name = str(req["name"])
        self.preset_path(name)  # validates
        payload = req.get("payload")
        if payload is None:
            preset = self._preset_from_live_state()
        else:
            if not isinstance(payload, dict):
                raise ValueError("payload must be an object")
            preset = payload
            root = preset.get(self.stream)
            if not isinstance(root, dict):
                raise ValueError("payload must contain an %r object"
                                 % self.stream)
            # Both keys are mandatory: EasyEffects THROWS and aborts the whole
            # preset load when "blocklist" is missing, so refuse to write a
            # payload that would later take the audio daemon down.
            for required in ("blocklist", "plugins_order"):
                if required not in root:
                    raise ValueError(
                        "payload %r is missing the required %r key; EasyEffects "
                        "aborts loading such a preset" % (self.stream, required))
            if not isinstance(root["blocklist"], list):
                raise ValueError("blocklist must be a list")
            order = root["plugins_order"]
            if not isinstance(order, list):
                raise ValueError("plugins_order must be a list")
            for token in order:
                mod = self.split_instance(str(token))[0]
                if mod in UNVERIFIED_MODULES:
                    raise PresetError("refusing to save preset containing %r (%s)"
                                      % (mod, UNVERIFIED_MODULES[mod]))
        path = self.write_preset(name, preset)
        return {"ok": True, "saved": name, "path": path}

    def cmd_list_presets(self, req):
        return {"ok": True, "presets": self.list_presets(),
                "stream": self.stream, "dir": self.preset_dir}

    def cmd_delete_preset(self, req):
        name = str(req["name"])
        path = self.preset_path(name)
        if not os.path.exists(path):
            raise PresetError("no such preset: %r" % name)
        self.backup_preset(name)  # back up before deleting
        os.unlink(path)
        return {"ok": True, "deleted": name}

    def cmd_flush(self, req):
        return dict(self.flush(), ok=True)

    def cmd_show_window(self, req):
        self.ee.show_window()
        return {"ok": True}

    def cmd_hide_window(self, req):
        self.ee.hide_window()
        return {"ok": True}

    def cmd_global_bypass(self, req):
        try:
            # Write FIRST, then read. Same rule as every other write
            # here: `set_property` returns nothing, so the readback is the only
            # confirmation. Reading first would just echo the state the caller
            # already had and the switch would snap back.
            if "value" in req:
                self.ee.set_global_bypass(int(bool(req["value"])))
            cur = self.ee.get_global_bypass()
        except BridgeUnavailable as exc:
            return {"ok": False, "error": ERR_UNAVAILABLE, "detail": str(exc)}
        return {"ok": True, "globalBypass": cur}

    def cmd_keys(self, req):
        """Introspection: the public (preset-JSON) key table, so the panel never
        guesses and never needs EasyEffects' camelCase IPC spelling."""
        return {"ok": True, "keys": self.module_spec(),
                "unverified": dict(UNVERIFIED_MODULES),
                "bandCounts": list(ALLOWED_BAND_COUNTS)}


# --------------------------------------------------------------------------
# Servers
# --------------------------------------------------------------------------

def _recv_lines(read_chunk, on_line):
    """Read newline-delimited messages using `read_chunk`, calling on_line per
    message. `read_chunk` returns b"" at EOF."""
    buf = b""
    while True:
        chunk = read_chunk()
        if not chunk:
            break
        buf += chunk
        while b"\n" in buf:
            raw, _, buf = buf.partition(b"\n")
            if not raw.strip():
                continue
            on_line(raw)
    if buf.strip():
        on_line(buf)


def serve_stream(read_chunk, write_line, bridge: Bridge) -> None:
    """Shared request loop: one JSON object per line, pipelined."""

    def on_line(raw: bytes):
        try:
            req = json.loads(raw.decode("utf-8"))
        except (ValueError, UnicodeDecodeError) as exc:
            write_line(json.dumps({"id": None, "ok": False, "error": "bad_json",
                                   "detail": str(exc)}))
            return
        if not isinstance(req, dict):
            write_line(json.dumps({"id": None, "ok": False,
                                   "error": "bad_request"}))
            return
        resp = bridge.handle(req)
        out = {"id": req.get("id")}
        out.update(resp)
        write_line(json.dumps(out, default=str))

    _recv_lines(read_chunk, on_line)


def socket_is_live(path: str) -> bool:
    if not os.path.exists(path):
        return False
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(0.5)
    try:
        s.connect(path)
        return True
    except OSError:
        return False
    finally:
        s.close()


def acquire_lock(lock_path: str):
    """Exclusive lock so a second daemon never steals a live socket."""
    fd = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(fd)
        return None
    os.ftruncate(fd, 0)
    os.write(fd, ("%d\n" % os.getpid()).encode())
    return fd


def run_socket_server(bridge: Bridge, socket_path: str, lock_path: str,
                      verbose: bool = False) -> int:
    lock_fd = acquire_lock(lock_path)
    if lock_fd is None:
        if socket_is_live(socket_path):
            log("another %s already serves %s; exiting cleanly"
                % (PROG, socket_path))
            return 0
        log("stale lock but no live socket on %s; taking over" % socket_path)
        lock_fd = acquire_lock(lock_path)
        if lock_fd is None:
            log("could not acquire lock %s; exiting" % lock_path)
            return 1

    if os.path.exists(socket_path):
        if socket_is_live(socket_path):
            log("socket %s is already served; exiting cleanly" % socket_path)
            return 0
        log("removing stale socket %s" % socket_path)
        try:
            os.unlink(socket_path)
        except OSError as exc:
            log("could not remove stale socket: %r" % exc)
            return 1

    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(socket_path)
    os.chmod(socket_path, 0o600)
    srv.listen(16)
    srv.settimeout(0.5)
    stopping = threading.Event()

    def on_signal(_sig, _frm):
        stopping.set()

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    log("listening on %s (version %s)" % (socket_path, VERSION))
    if verbose:
        try:
            st = bridge.refresh(force=True)
            log("chain=%s preset=%r" % (st["chain"], st["preset"]))
        except BridgeUnavailable:
            log("EasyEffects not reachable yet (%s); will retry per request"
                % ERR_UNAVAILABLE)

    sel = selectors.DefaultSelector()
    sel.register(srv, selectors.EVENT_READ)
    try:
        while not stopping.is_set():
            for _key, _mask in sel.select(timeout=0.5):
                try:
                    conn, _addr = srv.accept()
                except OSError:
                    continue
                threading.Thread(target=_serve_client, args=(bridge, conn),
                                 daemon=True).start()
    finally:
        sel.close()
        srv.close()
        bridge.stop()
        try:
            os.unlink(socket_path)
        except OSError:
            pass
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
        except OSError:
            pass
        log("stopped")
    return 0


def _serve_client(bridge: Bridge, conn) -> None:
    conn.settimeout(None)

    def read_chunk():
        try:
            return conn.recv(65536)
        except OSError:
            return b""

    def write_line(payload: str):
        try:
            conn.sendall(payload.encode() + b"\n")
        except OSError as exc:
            log("client write error: %r" % exc)

    try:
        serve_stream(read_chunk, write_line, bridge)
    except OSError as exc:
        log("client error: %r" % exc)
    finally:
        try:
            conn.close()
        except OSError:
            pass


def run_stdin_mode(bridge: Bridge) -> int:
    log("%s %s (stdin mode)" % (PROG, VERSION))
    stdin = sys.stdin.buffer
    stdout = sys.stdout.buffer

    def read_chunk():
        try:
            return stdin.read1(65536) or b""
        except (AttributeError, ValueError):
            return stdin.read(1) or b""

    def write_line(payload: str):
        stdout.write(payload.encode() + b"\n")
        stdout.flush()

    try:
        serve_stream(read_chunk, write_line, bridge)
    except KeyboardInterrupt:
        pass
    finally:
        bridge.stop()
    return 0


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog=PROG,
        description="Persistent EasyEffects IPC bridge for the iNiR audio panel.")
    p.add_argument("--socket", default=None,
                   help="unix socket path (default: $XDG_RUNTIME_DIR/inir-audio.sock)")
    p.add_argument("--stdin", action="store_true",
                   help="speak the JSON protocol over stdin/stdout instead of a socket")
    p.add_argument("--preset-dir", default=None,
                   help="override the EasyEffects output preset directory")
    p.add_argument("--ee-socket", default=None,
                   help="override the EasyEffects server socket path")
    p.add_argument("--coalesce-ms", type=float, default=COALESCE_SECONDS * 1000,
                   help="write coalescing window in ms (default: 40)")
    p.add_argument("--version", action="version",
                   version="%s %s" % (PROG, VERSION))
    p.add_argument("--verbose", "-v", action="store_true",
                   help="verbose logging on stderr")
    p.add_argument("--no-warmup", action="store_true",
                   help="do not prefetch state at startup")
    return p


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    socket_path = args.socket or default_socket_path()
    preset_dir = args.preset_dir or default_preset_dir()
    ee = EasyEffects(socket_path=args.ee_socket) if args.ee_socket else EasyEffects()
    bridge = Bridge(socket_path=socket_path, preset_dir=preset_dir, ee=ee,
                    coalesce_seconds=max(0.001, args.coalesce_ms / 1000.0))
    bridge.start_flusher()

    if args.stdin:
        if args.verbose:
            log("preset dir: %s" % preset_dir)
        return run_stdin_mode(bridge)

    if not args.no_warmup:
        try:
            st = bridge.refresh(force=True)
            log("EasyEffects ready: chain=%s preset=%r"
                % (st["chain"], st["preset"]))
        except BridgeUnavailable:
            log("EasyEffects not reachable at %s yet; the daemon stays up and "
                "answers %r per request" % (ee.socket_path, ERR_UNAVAILABLE))

    lock_path = socket_path + ".lock"
    try:
        return run_socket_server(bridge, socket_path, lock_path, args.verbose)
    finally:
        bridge.stop()


if __name__ == "__main__":
    sys.exit(main())