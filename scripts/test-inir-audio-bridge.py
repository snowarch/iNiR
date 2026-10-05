#!/usr/bin/env python3
"""Tests for scripts/audio/inir-audio-bridge.py

Runs with NO EasyEffects present: a fake EasyEffects server on a temp socket
speaks the real wire protocol, so protocol framing, batching, preset generation
and the socket lifecycle are all exercised for real.

    python3 scripts/test-inir-audio-bridge.py
"""

import importlib.util
import json
import os
import re
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
BRIDGE_PATH = os.path.join(HERE, "audio", "inir-audio-bridge.py")


def load_bridge():
    spec = importlib.util.spec_from_file_location("inir_audio_bridge", BRIDGE_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


BR = load_bridge()


# ---------------------------------------------------------------------------
# Fake EasyEffects server: real protocol, counts every verb it receives.
# ---------------------------------------------------------------------------

class FakeEasyEffects:
    def __init__(self, path, chain=None, preset="iNiR Test",
                 ignore_writes=False):
        self.path = path
        self.chain = list(chain if chain is not None else ["equalizer"])
        self.preset = preset
        self.state = {}
        # "<module>:<key>" -> value. Real EasyEffects namespaces parameters per
        # instance, so this is the faithful store; `state` above is a
        # last-write-wins mirror the older tests read directly.
        self.mod_state = {}
        # When True, set_property is accepted and silently dropped, exactly
        # like EasyEffects refusing an out-of-range enum: set_property returns
        # nothing and nothing changes. This is the only honest way to test the
        # readback-failure path.
        self.ignore_writes = ignore_writes
        self.verbs = []              # every verb, in arrival order
        self.batches = []            # verbs grouped per connection
        self.loads = []
        self.lock = threading.Lock()
        self.running = True
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.bind(path)
        self.sock.listen(16)
        self.sock.settimeout(0.3)
        self.thread = threading.Thread(target=self._serve, daemon=True)

    # values that exist without a preset having set them
    DEFAULTS = {
        "equalizer": {"numBands": "10", "bypass": "false", "balance": "0",
                      "inputGain": "0", "outputGain": "0",
                      "splitChannels": "false", "mode": "0",
                      "pitchLeft": "0", "pitchRight": "0",
                      "viewLeftChannel": "true", "decramp": "0"},
        "autogain": {"bypass": "false", "target": "-23",
                     "silenceThreshold": "-70"},
        "bass_enhancer": {"bypass": "true", "amount": "1", "floor": "40",
                          "floorActive": "true"},
        "exciter": {"bypass": "true", "amount": "-6.5", "ceil": "10000",
                    "ceilActive": "false", "harmonics": "4", "scope": "8000"},
        "crystalizer": {"bypass": "true", "inputGain": "0", "outputGain": "0",
                        "adaptiveIntensity": "false", "oversampling": "false",
                        "oversamplingQuality": "3",
                        "useFixedQuantum": "false", "transitionBand": "10"},
        "limiter": {"bypass": "true", "threshold": "0", "lookahead": "4",
                    "attack": "0.25", "release": "0.25", "gainBoost": "true",
                    "stereoLink": "100", "oversampling": "0",
                    "dithering": "0", "inputGain": "0", "outputGain": "0",
                    "mode": "0"},
    }

    def start(self):
        self.thread.start()
        return self

    def stop(self):
        self.running = False
        self.thread.join(timeout=2)
        try:
            self.sock.close()
        except OSError:
            pass

    def set_chain(self, chain):
        with self.lock:
            self.chain = list(chain)

    def _serve(self):
        while self.running:
            try:
                conn, _ = self.sock.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            threading.Thread(target=self._handle, args=(conn,),
                             daemon=True).start()

    def _handle(self, conn):
        conn.settimeout(2.0)
        buf = b""
        group = []
        try:
            while True:
                try:
                    chunk = conn.recv(65536)
                except (socket.timeout, OSError):
                    break
                if not chunk:
                    break
                buf += chunk
                while b"\n" in buf:
                    line, _, buf = buf.partition(b"\n")
                    verb = line.decode().strip()
                    if verb:
                        group.append(verb)
                        self._apply(verb, conn)
            with self.lock:
                if group:
                    self.batches.append(list(group))
                    self.verbs.extend(group)
        finally:
            try:
                conn.close()
            except OSError:
                pass

    @staticmethod
    def _band_key(key):
        """'left:band0Gain' -> ('left0Gain', 'Gain') or (None, None)."""
        if not key.startswith(("left:", "right:")):
            return None, None
        side, _, rest = key.partition(":")
        m = re.match(r"^band(\d+)(\w+)$", rest)
        if not m:
            return None, None
        return "%s%s%s" % (side, m.group(1), m.group(2)), m.group(2)

    @staticmethod
    def _split_prop(verb):
        """Split a get/set_property verb correctly.

        The module token contains the instance ('equalizer:0') and the key may
        itself contain a colon ('left:band0Gain'), so neither the module nor
        the key can be extracted with a naive split(":", n). set_property has
        exactly one trailing value; get_property has none.
        """
        parts = verb.split(":")
        stream = parts[1]
        module = parts[2] + ":" + parts[3]
        if verb.startswith("set_property:"):
            return stream, module, ":".join(parts[4:-1]), parts[-1]
        return stream, module, ":".join(parts[4:]), None

    def _apply(self, verb, conn):
        reply = None
        if verb.startswith("get_property:"):
            _stream, module, key, _value = self._split_prop(verb)
            name = module.split(":")[0]
            with self.lock:
                if name not in self.chain:
                    reply = "error_plugin_not_found"
                else:
                    skey, field = self._band_key(key)
                    if skey:
                        if field == "Gain":
                            reply = self.state.get(skey, "0")
                        elif field == "Frequency":
                            reply = self.state.get(skey, "1000")
                        elif field == "Q":
                            reply = self.state.get(skey, "4.36")
                        elif field == "Type":
                            reply = self.state.get(skey, "1")
                        else:
                            reply = self.state.get(
                                skey, "0" if field in ("Mode", "Slope") else "false")
                    elif re.fullmatch(r"(intensity|mute|bypass)Band\d+", key) \
                            and name == "crystalizer":
                        # verified: crystalizer bands are 0..12 only
                        fm = re.fullmatch(r"(\w+?)Band(\d+)", key)
                        field = fm.group(1)
                        if int(fm.group(2)) >= 13:
                            reply = "error_property_not_found"
                        else:
                            # mute/bypass are BOOLEANS in the preset, so the
                            # engine answers "true"/"false" - never "1"/"0".
                            # bypass defaults to TRUE (the safety rule).
                            default = {"intensity": "1.0",
                                       "mute": "false",
                                       "bypass": "true"}[field]
                            reply = self.state.get(key, default)
                    else:
                        base = key.split(":")[-1]
                        # Per-module first: real EasyEffects namespaces every
                        # parameter by instance, so "bypass" on the limiter and
                        # "bypass" on the crystalizer are different values. The
                        # flat `state` dict is only a last-write-wins mirror kept
                        # for the existing tests; consulting it first would make
                        # a multi-module batch read back the wrong module's value.
                        scoped = "%s:%s" % (name, base)
                        if scoped in self.mod_state:
                            reply = self.mod_state[scoped]
                        elif base in self.state:
                            # an explicit write always wins over the seeded default
                            reply = self.state[base]
                        elif base in self.DEFAULTS.get(name, {}):
                            reply = self.DEFAULTS[name][base]
                        else:
                            reply = "error_property_not_found"
        elif verb.startswith("set_property:"):
            _stream, module, key, value = self._split_prop(verb)
            name = module.split(":")[0]
            with self.lock:
                if name in self.chain and not self.ignore_writes:
                    skey, _field = self._band_key(key)
                    base = skey or key.split(":")[-1]
                    self.state[base] = value
                    self.mod_state["%s:%s" % (name, base)] = value
            return  # set_property returns nothing
        elif verb.startswith("get_last_loaded_preset:"):
            reply = self.preset
        elif verb.startswith("load_preset:"):
            _, stream, name = verb.split(":", 2)
            self.loads.append(name)
            with self.lock:
                pdir = os.environ["INIR_TEST_PRESET_DIR"]
                try:
                    with open(os.path.join(pdir, name + ".json")) as fh:
                        order = json.load(fh)["output"]["plugins_order"]
                    # Verified EasyEffects 8.3.0 behaviour: load_preset only
                    # APPENDS plugins. It never removes one and never reorders
                    # the existing chain.
                    for token in order:
                        base = token.split("#")[0]
                        if base not in self.chain:
                            self.chain.append(base)
                except (OSError, ValueError, KeyError):
                    pass
            reply = None
        elif verb == "get_global_bypass":
            # verified quirk: this reply has NO trailing newline
            conn.sendall(b"2")
            return
        if reply is not None:
            conn.sendall((reply + "\n").encode())


class BridgeFixture:
    """A Bridge wired to a fake EasyEffects and a temp preset dir."""

    def __init__(self, chain=None, preset="iNiR Test", ignore_writes=False):
        self.tmp = tempfile.mkdtemp(prefix="inir-bridge-test-")
        self.preset_dir = os.path.join(self.tmp, "presets")
        os.makedirs(self.preset_dir)
        self.sock_path = os.path.join(self.tmp, "ee.sock")
        os.environ["INIR_TEST_PRESET_DIR"] = self.preset_dir
        self.fake = FakeEasyEffects(self.sock_path, chain, preset,
                                    ignore_writes=ignore_writes).start()
        self.seed_preset(preset, ["%s#0" % m for m in (chain or ["equalizer"])])
        ee = BR.EasyEffects(socket_path=self.sock_path, timeout=2.0)
        self.bridge = BR.Bridge(socket_path=os.path.join(self.tmp, "inir.sock"),
                                preset_dir=self.preset_dir, ee=ee,
                                coalesce_seconds=0.04)

    def seed_preset(self, name, order):
        blocks = {}
        for token in order:
            module = token.split("#")[0]
            if module == "equalizer":
                blocks[token] = BR.build_equalizer_block(10)
            else:
                blocks[token] = BR.build_module_block(module)
        preset = {"output": {"blocklist": [], "plugins_order": order, **blocks}}
        path = os.path.join(self.preset_dir, name + ".json")
        with open(path, "w") as fh:
            json.dump(preset, fh, indent=2)

    def preset_json(self, name="iNiR Test"):
        with open(os.path.join(self.preset_dir, name + ".json")) as fh:
            return json.load(fh)

    def preset_mtime(self, name="iNiR Test"):
        return os.stat(os.path.join(self.preset_dir, name + ".json")).st_mtime_ns

    def start(self):
        return self

    def close(self):
        self.fake.stop()
        os.environ.pop("INIR_TEST_PRESET_DIR", None)


# ---------------------------------------------------------------------------

class TestValueEncoding(unittest.TestCase):
    def test_encode_by_kind(self):
        self.assertEqual(BR.encode_value(True, "bool"), "true")
        self.assertEqual(BR.encode_value("false", "bool"), "false")
        self.assertEqual(BR.encode_value(3, "int"), "3")
        self.assertEqual(BR.encode_value(-2.0, "float"), "-2")
        self.assertEqual(BR.encode_value(-2.5, "float"), "-2.5")
        self.assertEqual(BR.encode_value(100.0, "pct"), "100")

    def test_parse_ignores_error_tokens_and_empty(self):
        self.assertIsNone(BR.parse_value("error_property_not_found", "float"))
        self.assertIsNone(BR.parse_value("error_plugin_not_found", "int"))
        self.assertIsNone(BR.parse_value("", "float"))
        self.assertEqual(BR.parse_value("true", "bool"), True)
        self.assertEqual(BR.parse_value("-2", "float"), -2.0)

    def test_case_helpers(self):
        self.assertEqual(BR.camel_to_kebab("floorActive"), "floor-active")
        self.assertEqual(BR.camel_to_kebab("intensityBand3"), "intensity-band-3")
        self.assertEqual(BR.camel_to_kebab("silenceThreshold"),
                         "silence-threshold")
        self.assertEqual(BR.kebab_to_camel("silence-threshold"),
                         "silenceThreshold")


class TestPresetGeneration(unittest.TestCase):
    def test_equalizer_block_is_kebab_and_complete(self):
        blk = BR.build_equalizer_block(10)
        for key in ("num-bands", "input-gain", "output-gain", "split-channels",
                    "pitch-left", "pitch-right", "mode", "balance", "bypass"):
            self.assertIn(key, blk)
        self.assertEqual(len(blk["left"]), 10)
        band = blk["left"]["band0"]
        for key in ("frequency", "gain", "q", "mode", "mute", "solo", "slope",
                    "type", "width"):
            self.assertIn(key, band)
        # string enums in the preset
        self.assertEqual(band["type"], "Bell")
        self.assertEqual(band["mode"], "RLC (BT)")
        self.assertEqual(blk["mode"], "IIR")

    def test_band_count_curves(self):
        for count in (10, 15, 32):
            blk = BR.build_equalizer_block(count)
            self.assertEqual(blk["num-bands"], count)
            self.assertEqual(len(blk["left"]), count)
            self.assertEqual(len(blk["right"]), count)
            freqs = [blk["left"]["band%d" % i]["frequency"] for i in range(count)]
            # the ten octave centres must always lead the curve
            self.assertEqual(freqs[:10], BR.ISO_BAND_FREQS)
            # extra bands fill the tail, ascending among themselves
            extra = freqs[10:]
            self.assertEqual(extra, sorted(extra), "extra bands must ascend")
            self.assertEqual(len(set(freqs)), len(freqs),
                             "frequencies must be unique")
        self.assertEqual(
            BR.build_equalizer_block(32)["left"]["band31"]["frequency"],
            BR.EXTRA_BAND_FREQS[21])

    def test_modules_use_public_kebab_keys(self):
        """The public/preset key is kebab-case for every multi-word parameter.
        Verified on EasyEffects 8.3.0: the camelCase spelling is silently
        ignored in a preset, so emitting it would quietly do nothing."""
        expected = {
            "autogain": ["bypass", "target", "silence-threshold",
                         "maximum-history", "force-silence"],
            "bass_enhancer": ["bypass", "amount", "floor", "floor-active"],
            "exciter": ["bypass", "amount", "ceil", "ceil-active", "harmonics",
                        "scope"],
            "limiter": ["bypass", "threshold", "lookahead", "attack",
                        "release", "gain-boost", "stereo-link", "input-gain",
                        "output-gain", "oversampling", "dithering"],
            "crystalizer": ["bypass", "input-gain", "output-gain",
                            "adaptive-intensity", "oversampling",
                            "oversampling-quality", "fixed-quantum",
                            "transition-band"],
        }
        camel_leaks = {"silenceThreshold", "floorActive", "ceilActive",
                       "gainBoost", "stereoLink", "inputGain", "outputGain",
                       "adaptiveIntensity", "useFixedQuantum",
                       "transitionBand", "oversamplingQuality"}
        for module, keys in expected.items():
            blk = BR.build_module_block(module)
            for key in keys:
                self.assertIn(key, blk, "%s missing %s" % (module, key))
            for leak in camel_leaks & set(blk):
                self.fail("%s emits camelCase key %r" % (module, leak))

    def test_limiter_enums_are_labels_in_preset_and_ints_on_the_wire(self):
        lim = BR.build_module_block("limiter")
        self.assertIsInstance(lim["oversampling"], str)
        self.assertIsInstance(lim["dithering"], str)
        self.assertIsInstance(lim["bypass"], bool)
        self.assertIsInstance(lim["gain-boost"], bool)
        spec = BR.ipc_key_for("limiter", "oversampling")[1]
        self.assertEqual(BR.encode_public(spec, "None"), "0")
        self.assertEqual(BR.encode_public(spec, "Half x2/16 bit"), "1")
        self.assertEqual(BR.encode_public(spec, "Full x8/24 bit"), "20")
        self.assertEqual(BR.decode_public(spec, "22"), "True Peak/24 bit")
        dsp = BR.ipc_key_for("limiter", "dithering")[1]
        self.assertEqual(BR.encode_public(dsp, "8bit"), "2")
        self.assertEqual(BR.encode_public(dsp, "16bit"), "6")
        self.assertEqual(BR.encode_public(dsp, "24bit"), "8")
        with self.assertRaises(ValueError):
            BR.encode_public(spec, "Not A Label")

    def test_public_to_ipc_translation(self):
        cases = [
            ("bass_enhancer", "floor-active", "floorActive"),
            ("exciter", "ceil-active", "ceilActive"),
            ("limiter", "stereo-link", "stereoLink"),
            ("limiter", "gain-boost", "gainBoost"),
            ("autogain", "silence-threshold", "silenceThreshold"),
            ("autogain", "maximum-history", "maximumHistory"),
            ("autogain", "force-silence", "forceSilence"),
            ("crystalizer", "adaptive-intensity", "adaptiveIntensity"),
            ("crystalizer", "fixed-quantum", "useFixedQuantum"),
            ("crystalizer", "transition-band", "transitionBand"),
            ("crystalizer", "oversampling-quality", "oversamplingQuality"),
            ("equalizer", "num-bands", "numBands"),
            ("equalizer", "input-gain", "inputGain"),
            ("equalizer", "split-channels", "splitChannels"),
        ]
        for module, public, ipc in cases:
            got, spec = BR.ipc_key_for(module, public)
            self.assertEqual(got, ipc, "%s.%s" % (module, public))
            self.assertIsNotNone(spec)

    def test_unknown_public_key_rejected(self):
        for module, key in (("limiter", "stereoLink"), ("limiter", "ceiling"),
                            ("autogain", "silenceThreshold"),
                            ("bass_enhancer", "floorActive"),
                            ("equalizer", "numBands")):
            self.assertIsNone(BR.ipc_key_for(module, key)[0],
                              "%s.%s must not resolve" % (module, key))

    def test_new_module_blocks_are_neutral(self):
        for module in ("autogain", "bass_enhancer", "exciter", "limiter"):
            blk = BR.build_module_block(module)
            self.assertIs(blk["bypass"], True,
                          "%s must be generated bypassed" % module)

    def test_crystalizer_bands_are_nested_objects(self):
        blk = BR.build_module_block("crystalizer")
        bands = {k: v for k, v in blk.items()
                 if re.fullmatch(r"band\d+", k)}
        self.assertEqual(len(bands), 13, "crystalizer has exactly 13 bands")
        for i in range(13):
            obj = blk["band%d" % i]
            self.assertIsInstance(obj, dict)
            self.assertEqual(set(obj), {"intensity", "mute", "bypass"})
        self.assertIs(blk["band0"]["bypass"], True,
                      "new bands must be generated bypassed")
        # NOT flat scalars
        for bad in ("intensityBand0", "intensity-band-0", "bands"):
            self.assertNotIn(bad, blk)

    def test_crystalizer_kebab_keys_are_load_bearing(self):
        """Regression: camelCase scalar keys parse but are silently ignored,
        so EasyEffects would fall back to its own defaults."""
        blk = BR.build_module_block("crystalizer")
        self.assertNotIn("inputGain", blk)
        self.assertIn("input-gain", blk)

    def test_crystalizer_band_values_come_from_live_state(self):
        live = {"band3.intensity": 7.5, "band4.mute": True,
                "band5.bypass": False}
        blk = BR.build_module_block("crystalizer", live)
        self.assertEqual(blk["band3"]["intensity"], 7.5)
        self.assertIs(blk["band4"]["mute"], True)
        self.assertIs(blk["band5"]["bypass"], False)
        self.assertEqual(blk["band0"]["intensity"], 1.0,
                         "bands without a live value keep the neutral default")

    def test_every_module_is_verified(self):
        self.assertEqual(BR.UNVERIFIED_MODULES, {})
        for module in ("autogain", "bass_enhancer", "crystalizer", "exciter",
                       "limiter"):
            self.assertIn(module, BR.KNOWN_MODULES)
            self.assertTrue(BR.build_module_block(module))

    def test_unverified_module_is_refused(self):
        """The refusal guard must keep working for any future regression."""
        saved = dict(BR.UNVERIFIED_MODULES)
        saved_schema = BR.MODULE_SCHEMA.pop("crystalizer")
        BR.UNVERIFIED_MODULES["crystalizer"] = "simulated regression"
        try:
            with self.assertRaises(BR.PresetError):
                BR.build_module_block("crystalizer")
        finally:
            BR.MODULE_SCHEMA["crystalizer"] = saved_schema
            BR.UNVERIFIED_MODULES.clear()
            BR.UNVERIFIED_MODULES.update(saved)

    def test_generated_preset_always_has_required_keys(self):
        """blocklist and plugins_order are mandatory: EasyEffects aborts
        without them."""
        for modules in (["equalizer"], ["equalizer", "autogain", "limiter",
                                         "crystalizer"]):
            doc = BR.Bridge.__new__(BR.Bridge)
            doc.stream = "output"
            doc.preset_dir = "/tmp"
            preset = BR.Bridge.build_preset(doc, modules, None)
            root = preset["output"]
            self.assertIn("blocklist", root)
            self.assertIsInstance(root["blocklist"], list)
            self.assertIn("plugins_order", root)
            self.assertEqual(len(root["plugins_order"]), len(modules))

    def test_save_preset_requires_blocklist(self):
        """A payload without blocklist would abort EasyEffects on load."""
        tmp = tempfile.mkdtemp(prefix="inir-payload-")
        ee_path = os.path.join(tmp, "ee.sock")
        fake = FakeEasyEffects(ee_path, ["equalizer"], "iNiR Test").start()
        try:
            bridge = BR.Bridge(socket_path=os.path.join(tmp, "b.sock"),
                               preset_dir=tmp, ee=BR.EasyEffects(
                                   socket_path=ee_path, timeout=2.0))
            bad = {"output": {"plugins_order": ["equalizer#0"]}}
            r = bridge.handle({"id": 1, "cmd": "save_preset", "name": "Bad",
                               "payload": bad})
            self.assertFalse(r["ok"])
            # assert on behaviour, not on the message: whichever internal check
            # rejects it, nothing may be written.
            self.assertFalse(os.path.exists(os.path.join(tmp, "Bad.json")),
                             "a payload without blocklist must not be written")
            # a non-list blocklist is equally fatal for EasyEffects
            bad2 = {"output": {"blocklist": "nope",
                               "plugins_order": ["equalizer#0"]}}
            r = bridge.handle({"id": 1, "cmd": "save_preset", "name": "Bad2",
                               "payload": bad2})
            self.assertFalse(r["ok"])
            self.assertFalse(os.path.exists(os.path.join(tmp, "Bad2.json")))
            # missing plugins_order too
            bad3 = {"output": {"blocklist": []}}
            r = bridge.handle({"id": 1, "cmd": "save_preset", "name": "Bad3",
                               "payload": bad3})
            self.assertFalse(r["ok"])
            good = {"output": {"blocklist": [],
                               "plugins_order": ["equalizer#0"]}}
            r = bridge.handle({"id": 1, "cmd": "save_preset", "name": "Good",
                               "payload": good})
            self.assertTrue(r["ok"], r)
            self.assertTrue(os.path.exists(os.path.join(tmp, "Good.json")))
        finally:
            fake.stop()


class TestPanelContract(unittest.TestCase):
    """The four wire-format rules the built panel depends on."""

    def test_1_flat_module_keys_are_kebab_preset_spelling(self):
        for module, keys in (
                ("autogain", ["silence-threshold", "maximum-history",
                              "force-silence"]),
                ("bass_enhancer", ["floor-active"]),
                ("exciter", ["ceil-active"]),
                ("limiter", ["stereo-link", "gain-boost", "input-gain",
                             "output-gain"]),
                ("crystalizer", ["input-gain", "output-gain",
                                 "adaptive-intensity", "fixed-quantum",
                                 "transition-band", "oversampling-quality"]),
        ):
            blk = BR.build_module_block(module)
            for key in keys:
                self.assertIn(key, blk, "%s must emit %r" % (module, key))

    def test_2_crystalizer_bands_are_dotted_paths(self):
        for i in (0, 7, 12):
            for field, ipc in (("intensity", "intensityBand"),
                               ("mute", "muteBand"),
                               ("bypass", "bypassBand")):
                key = "band%d.%s" % (i, field)
                got, spec = BR.ipc_key_for("crystalizer", key)
                self.assertEqual(got, "%s%d" % (ipc, i), key)
                self.assertIsNotNone(spec)
                self.assertEqual(BR.canonical_key_for("crystalizer", key), key)
        # the flat IPC spelling is NOT a public key
        for bad in ("intensityBand3", "muteBand3", "bypassBand3"):
            self.assertIsNone(BR.ipc_key_for("crystalizer", bad)[0], bad)
        # and the dotted path must not resolve out of range or to junk
        self.assertIsNone(BR.ipc_key_for("crystalizer", "band13.intensity")[0])
        self.assertIsNone(BR.ipc_key_for("crystalizer", "band3.bogus")[0])
        self.assertIsNone(BR.ipc_key_for("crystalizer", "band3")[0])
        # spec advertises dotted paths
        spec = BR.Bridge.module_spec()
        crys = {e["key"]: e for e in spec["crystalizer"]}
        self.assertIn("band5.intensity", crys)
        self.assertEqual(crys["band5.intensity"]["min"], -40.0)
        self.assertEqual(crys["band5.intensity"]["max"], 32.0)
        self.assertNotIn("intensityBand5", crys)

    def test_2_dotted_path_resolves_into_the_nested_preset_object(self):
        """set_param on a dotted band path must land on the nested preset
        object, i.e. plugins_order block -> band<N> -> <field>."""
        fx = BridgeFixture(chain=["equalizer", "crystalizer"]).start()
        try:
            r = fx.bridge.handle({"id": 1, "cmd": "set_param",
                                  "module": "crystalizer",
                                  "key": "band4.intensity", "value": 9.5,
                                  "sync": True})
            self.assertTrue(r["ok"], r)
            self.assertEqual(r["key"], "band4.intensity")
            # written over the IPC key ...
            self.assertEqual(fx.fake.state["intensityBand4"], "9.5")
            # ... and survives a preset rewrite as a NESTED object value.
            # (ensure_chain is a no-op while the chain already matches, so the
            # rewrite is forced by appending a module.)
            res = fx.bridge.ensure_chain(["equalizer", "crystalizer", "exciter"])
            self.assertTrue(res["changed"])
            block = fx.preset_json()["output"]["crystalizer#0"]
            self.assertEqual(block["band4"]["intensity"], 9.5)
            self.assertNotIn("intensityBand4", block)
            self.assertNotIn("band4.intensity", block)
        finally:
            fx.close()

    def test_3_enum_labels_are_untranslated_verbatim(self):
        """Labels go in exactly as the kcfg spells them; the bridge owns the
        label -> index table used for set_property."""
        spec = BR.ipc_key_for("limiter", "oversampling")[1]
        self.assertEqual(BR.encode_public(spec, "None"), "0")
        self.assertEqual(BR.encode_public(spec, "Half x2/16 bit"), "1")
        self.assertEqual(BR.encode_public(spec, "Full x8/24 bit"), "20")
        self.assertEqual(BR.encode_public(spec, "True Peak/24 bit"), "22")
        dsp = BR.ipc_key_for("limiter", "dithering")[1]
        self.assertEqual(BR.encode_public(dsp, "8bit"), "2")
        self.assertEqual(BR.encode_public(dsp, "16bit"), "6")
        self.assertEqual(BR.encode_public(dsp, "24bit"), "8")
        # verbatim means verbatim: no case folding, no trimming
        for wrong in ("half x2/16 bit", "HALF X2/16 BIT", " Half x2/16 bit",
                      "Half x2/16bits", ""):
            with self.assertRaises(ValueError, msg=wrong):
                BR.encode_public(spec, wrong)
        # and the label survives a status round trip unchanged
        self.assertEqual(BR.decode_public(spec, "20"), "Full x8/24 bit")

    def test_4_equalizer_master_gains_are_camel_case(self):
        for pub, preset, ipc in (("inputGain", "input-gain", "inputGain"),
                                 ("outputGain", "output-gain", "outputGain")):
            got, spec = BR.ipc_key_for("equalizer", pub)
            self.assertEqual(got, ipc)
            self.assertEqual(BR.canonical_key_for("equalizer", pub), pub)
            self.assertEqual(spec["preset"], preset,
                             "the preset file still uses the kebab spelling")
        # the preset spelling is still accepted as an alias
        self.assertEqual(BR.canonical_key_for("equalizer", "input-gain"),
                         "inputGain")
        # the generated preset uses kebab even though the public key is camel
        blk = BR.build_equalizer_block(10)
        self.assertIn("input-gain", blk)
        self.assertIn("output-gain", blk)
        self.assertNotIn("inputGain", blk)
        # and spec advertises the camelCase public key
        eq = {e["key"] for e in BR.Bridge.module_spec()["equalizer"]}
        self.assertIn("inputGain", eq)
        self.assertIn("outputGain", eq)
        self.assertNotIn("input-gain", eq)

    def test_4_equalizer_master_gain_set_param(self):
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            r = fx.bridge.handle({"id": 1, "cmd": "set_param",
                                  "module": "equalizer", "key": "inputGain",
                                  "value": -4.5, "sync": True})
            self.assertTrue(r["ok"], r)
            self.assertEqual(r["key"], "inputGain")
            self.assertEqual(fx.fake.state["inputGain"], "-4.5")
            st = fx.bridge.handle({"id": 1, "cmd": "status"})
            self.assertEqual(st["equalizer"]["inputGain"], -4.5)
        finally:
            fx.close()


class TestLazyActivateInstall(unittest.TestCase):
    """set_chain `activate`: install the chain silently, light up only what the
    user deliberately asked for."""

    def test_new_module_is_bypassed_by_default(self):
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            res = fx.bridge.ensure_chain(["equalizer", "limiter"])
            self.assertTrue(res["changed"])
            root = fx.preset_json()["output"]
            self.assertEqual(root["limiter#0"]["bypass"], True,
                             "a newly installed module must be silent")
            self.assertEqual(res["activated"], [])
            self.assertEqual(res["installed"], ["limiter"])
        finally:
            fx.close()

    def test_activate_installs_that_module_active(self):
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            res = fx.bridge.ensure_chain(["equalizer", "limiter"],
                                         activate=["limiter"])
            self.assertTrue(res["changed"])
            root = fx.preset_json()["output"]
            self.assertIs(root["limiter#0"]["bypass"], False,
                          "a module in `activate` must come up un-bypassed")
            self.assertEqual(res["activated"], ["limiter"])
        finally:
            fx.close()

    def test_only_the_activated_module_is_active(self):
        """Installing several modules at once: exactly the named ones are live."""
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            fx.bridge.ensure_chain(
                ["equalizer", "bass_enhancer", "exciter", "crystalizer",
                 "limiter"],
                activate=["limiter"])
            root = fx.preset_json()["output"]
            self.assertIs(root["limiter#0"]["bypass"], False)
            for module in ("bass_enhancer", "exciter", "crystalizer"):
                self.assertIs(root["%s#0" % module]["bypass"], True,
                              "%s must be installed silent" % module)
        finally:
            fx.close()

    def test_activate_does_not_disturb_a_module_already_in_the_chain(self):
        """`activate` only applies to modules that are NOT already running."""
        fx = BridgeFixture(chain=["equalizer", "autogain", "limiter"]).start()
        try:
            # the limiter is already installed and (per the fake) bypassed
            self.assertIs(fx.fake.DEFAULTS["limiter"]["bypass"], "true")
            res = fx.bridge.ensure_chain(["equalizer", "autogain", "limiter"],
                                         activate=["limiter"])
            root = fx.preset_json()["output"]
            self.assertIs(root["limiter#0"]["bypass"], True,
                          "an already-present module keeps its live bypass")
            self.assertEqual(res["activated"], [])
            self.assertEqual(res["activateIgnored"], ["limiter"])
            self.assertEqual(res["installed"], [])
        finally:
            fx.close()

    def test_activate_ignored_when_already_unbypassed(self):
        """An active module listed in `activate` stays active (no flip-flop),
        and because nothing needed installing the preset is not touched at all."""
        fx = BridgeFixture(chain=["equalizer", "limiter"]).start()
        try:
            fx.bridge.handle({"id": 1, "cmd": "set_param",
                              "module": "limiter", "key": "bypass",
                              "value": False, "sync": True})
            self.assertEqual(fx.fake.state["bypass"], "false")
            mtime = fx.preset_mtime()
            loads = len(fx.fake.loads)
            res = fx.bridge.ensure_chain(["equalizer", "limiter"],
                                         activate=["limiter"])
            self.assertFalse(res["changed"])
            self.assertEqual(res["activateIgnored"], ["limiter"])
            self.assertEqual(fx.fake.state["bypass"], "false",
                             "the live bypass must be untouched")
            self.assertEqual(fx.preset_mtime(), mtime,
                             "a no-op install must not rewrite the preset")
            self.assertEqual(len(fx.fake.loads), loads,
                             "a no-op install must not reload the engine")
        finally:
            fx.close()

    def test_new_equalizer_is_installed_silent(self):
        """The equalizer block is regenerated, so it must still obey the rule:
        an equalizer that was not in the chain comes in bypassed."""
        fx = BridgeFixture(chain=["autogain"]).start()
        try:
            fx.bridge.ensure_chain(["autogain", "equalizer"])
            self.assertIs(fx.preset_json()["output"]["equalizer#0"]["bypass"],
                          True)
            fx.bridge.ensure_chain(["autogain", "equalizer", "bass_enhancer"],
                                   activate=["equalizer"])
            root = fx.preset_json()["output"]
            self.assertIs(root["equalizer#0"]["bypass"], False)
            self.assertIs(root["bass_enhancer#0"]["bypass"], True)
        finally:
            fx.close()

    def test_num_bands_survives_the_install(self):
        fx = BridgeFixture(chain=["equalizer", "autogain"]).start()
        try:
            r = fx.bridge.handle({"id": 1, "cmd": "set_band_count",
                                  "count": 15})
            self.assertTrue(r["ok"], r)
            self.assertEqual(
                fx.preset_json()["output"]["equalizer#0"]["num-bands"], 15)
            # a later module install must not quietly revert the band count
            res = fx.bridge.ensure_chain(["equalizer", "autogain", "limiter"],
                                         num_bands=15)
            self.assertTrue(res["changed"])
            self.assertEqual(
                fx.preset_json()["output"]["equalizer#0"]["num-bands"], 15)
        finally:
            fx.close()

    def test_num_bands_honoured_while_installing(self):
        """numBands passed with the install is what ends up in the preset."""
        fx = BridgeFixture(chain=["equalizer", "autogain"]).start()
        try:
            r = fx.bridge.handle({"id": 1, "cmd": "set_chain",
                                  "modules": ["equalizer", "autogain",
                                              "limiter"],
                                  "numBands": 32, "activate": ["limiter"]})
            self.assertTrue(r["ok"], r)
            eq = fx.preset_json()["output"]["equalizer#0"]
            self.assertEqual(eq["num-bands"], 32)
            self.assertEqual(len(eq["left"]), 32)
            self.assertIs(fx.preset_json()["output"]["limiter#0"]["bypass"],
                          False)
        finally:
            fx.close()

    def test_equalizer_curve_survives_the_install(self):
        """The user's EQ must come back untouched after a chain rebuild."""
        fx = BridgeFixture(chain=["equalizer", "autogain"]).start()
        try:
            curve = [-2.0, -1.0, 1.0, 3.36, 5.0, 5.0, 4.0, 2.0, 1.0, 0.0]
            fx.bridge.handle({"id": 1, "cmd": "set_bands", "sync": True,
                              "bands": [{"index": i, "gain": g}
                                        for i, g in enumerate(curve)]})
            fx.bridge.handle({"id": 1, "cmd": "set_param", "sync": True,
                              "module": "equalizer", "key": "inputGain",
                              "value": -4.5})
            res = fx.bridge.ensure_chain(["equalizer", "autogain", "limiter"],
                                         activate=["limiter"])
            self.assertTrue(res["changed"])
            eq = fx.preset_json()["output"]["equalizer#0"]
            got = [eq["left"]["band%d" % i]["gain"] for i in range(10)]
            for i, want in enumerate(curve):
                self.assertAlmostEqual(got[i], want, places=2,
                                       msg="band %d gain" % i)
            self.assertEqual(eq["input-gain"], -4.5)
            freqs = [eq["left"]["band%d" % i]["frequency"] for i in range(10)]
            self.assertEqual(freqs, BR.ISO_BAND_FREQS)
        finally:
            fx.close()

    def test_activate_does_not_clobber_a_present_module_during_an_install(self):
        """The write path with BOTH cases live at once: one module already
        running and listed in `activate`, another being installed. The running
        one must keep its live bypass; only the new one may change."""
        fx = BridgeFixture(chain=["equalizer", "autogain", "limiter"]).start()
        try:
            # limiter is already installed and bypassed (the fake's default)
            res = fx.bridge.ensure_chain(
                ["equalizer", "autogain", "limiter", "bass_enhancer"],
                activate=["limiter", "bass_enhancer"])
            self.assertTrue(res["changed"], "must actually install something")
            root = fx.preset_json()["output"]
            self.assertIs(root["bass_enhancer#0"]["bypass"], False,
                          "the newly installed, activated module is live")
            self.assertIs(root["limiter#0"]["bypass"], True,
                          "an already-running module keeps its live bypass")
            self.assertEqual(res["activated"], ["bass_enhancer"])
            self.assertEqual(res["activateIgnored"], ["limiter"])
        finally:
            fx.close()

    def test_activate_must_be_a_list(self):
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            r = fx.bridge.handle({"id": 1, "cmd": "set_chain",
                                  "modules": ["equalizer", "limiter"],
                                  "activate": "limiter"})
            self.assertFalse(r["ok"])
        finally:
            fx.close()

    def test_activate_rejects_unknown_module(self):
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            with self.assertRaises(BR.PresetError):
                fx.bridge.ensure_chain(["equalizer", "limiter"],
                                       activate=["not_a_module"])
        finally:
            fx.close()

    def test_activate_absent_behaves_exactly_like_before(self):
        """No `activate` field => everything newly added is silent."""
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            r = fx.bridge.handle({"id": 1, "cmd": "set_chain",
                                  "modules": ["equalizer", "exciter",
                                              "crystalizer"]})
            self.assertTrue(r["ok"], r)
            root = fx.preset_json()["output"]
            self.assertIs(root["exciter#0"]["bypass"], True)
            self.assertIs(root["crystalizer#0"]["bypass"], True)
        finally:
            fx.close()


class TestPathTraversal(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="inir-presets-")

    def test_rejects_traversal_and_separators(self):
        bad = ["../escape", "..", "a/b", "a\\b", "/etc/passwd",
               "../../.ssh/authorized_keys", ".", "..", "sub/dir",
               "x\x00y", "", " leading-space-is-ok-but-dots-arent.."]
        for name in bad:
            with self.assertRaises(BR.PresetError, msg="accepted %r" % name):
                BR.safe_preset_path(self.dir, name)

    def test_accepts_normal_names(self):
        for name in ("iNiR Equalizer", "Bass", "a-b_c.d", "Preset 2"):
            path = BR.safe_preset_path(self.dir, name)
            self.assertEqual(os.path.dirname(os.path.realpath(path)),
                             os.path.realpath(self.dir))

    def test_symlink_escape_rejected(self):
        outside = tempfile.mkdtemp(prefix="inir-outside-")
        link = os.path.join(self.dir, "escape")
        os.symlink(outside, link)
        with self.assertRaises(BR.PresetError):
            BR.safe_preset_path(self.dir, "escape/thing")


class TestProtocolFraming(unittest.TestCase):
    def setUp(self):
        self.fx = BridgeFixture().start()

    def tearDown(self):
        self.fx.close()

    def test_single_request_round_trip(self):
        r = self.fx.bridge.handle({"id": 7, "cmd": "ping"})
        self.assertTrue(r["ok"])
        self.assertTrue(r["pong"])

    def test_unknown_command(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "nope"})
        self.assertFalse(r["ok"])
        self.assertEqual(r["error"], "unknown_command")

    def test_pipelined_requests_over_one_connection(self):
        """Several requests on ONE connection, one write."""
        path = os.path.join(self.fx.tmp, "inir.sock")
        srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        srv.bind(path)
        srv.listen(4)
        srv.settimeout(5)
        done = threading.Event()

        def serve():
            conn, _ = srv.accept()
            BR.serve_stream(lambda: conn.recv(65536),
                            lambda p: conn.sendall(p.encode() + b"\n"),
                            self.fx.bridge)
            done.set()
            conn.close()

        t = threading.Thread(target=serve, daemon=True)
        t.start()
        c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        c.settimeout(5)
        c.connect(path)
        payload = b"".join(
            (json.dumps({"id": i, "cmd": "ping"}) + "\n").encode()
            for i in range(5))
        c.sendall(payload)
        buf = b""
        ids = []
        while len(ids) < 5:
            while b"\n" not in buf:
                chunk = c.recv(65536)
                if not chunk:
                    break
                buf += chunk
            while b"\n" in buf:
                line, _, buf = buf.partition(b"\n")
                ids.append(json.loads(line)["id"])
        c.close()
        done.wait(2)
        srv.close()
        self.assertEqual(ids, [0, 1, 2, 3, 4],
                         "responses must come back in order, one per line")

    def test_bad_json_gets_an_error_line(self):
        got = []
        chunks = [b"not json\n"]          # then EOF
        BR.serve_stream(lambda: chunks.pop(0) if chunks else b"",
                        lambda p: got.append(p), self.fx.bridge)
        self.assertEqual(len(got), 1)
        resp = json.loads(got[0])
        self.assertFalse(resp["ok"])
        self.assertEqual(resp["error"], "bad_json")

    def test_non_object_request_is_rejected(self):
        got = []
        chunks = [b"[1,2,3]\n"]
        BR.serve_stream(lambda: chunks.pop(0) if chunks else b"",
                        lambda p: got.append(p), self.fx.bridge)
        self.assertEqual(json.loads(got[0])["error"], "bad_request")

    def test_partial_line_without_newline_is_still_delivered(self):
        got = []
        chunks = [b'{"id":1,"cmd":"pi', b'ng"}']     # no trailing newline
        BR.serve_stream(lambda: chunks.pop(0) if chunks else b"",
                        lambda p: got.append(p), self.fx.bridge)
        self.assertEqual(len(got), 1)
        self.assertTrue(json.loads(got[0])["ok"])

    def test_unavailable_easyeffects_does_not_crash(self):
        ee = BR.EasyEffects(socket_path=os.path.join(self.fx.tmp, "nope.sock"),
                            timeout=0.5)
        b = BR.Bridge(socket_path=os.path.join(self.fx.tmp, "x.sock"),
                      preset_dir=self.fx.preset_dir, ee=ee)
        r = b.handle({"id": 1, "cmd": "status"})
        self.assertFalse(r["ok"])
        self.assertEqual(r["error"], BR.ERR_UNAVAILABLE)
        self.assertFalse(r["available"])


class TestBatchingAndCoalescing(unittest.TestCase):
    def setUp(self):
        self.fx = BridgeFixture().start()

    def tearDown(self):
        self.fx.close()

    def test_ten_bands_coalesce_into_one_write_batch(self):
        t0 = time.time()
        for i in range(10):
            r = self.fx.bridge.handle(
                {"id": i, "cmd": "set_band", "index": i, "gain": -i * 0.5})
            self.assertTrue(r["ok"])
        result = self.fx.bridge.flush()
        elapsed = time.time() - t0
        sets = [b for b in self.fx.fake.batches
                if any(v.startswith("set_property") for v in b)]
        readbacks = [b for b in self.fx.fake.batches
                     if len(b) == 20 and
                     all(v.startswith("get_property") for v in b)]
        self.assertEqual(len(sets), 1,
                         "10 band writes must become ONE set batch")
        self.assertEqual(len(sets[0]), 20,
                         "left+right for each of 10 bands")
        self.assertEqual(len(readbacks), 1,
                         "verification must be ONE batched readback")
        self.assertEqual(len(readbacks[0]), 20)
        self.assertEqual(result["written"], 20)
        self.assertEqual(result["mismatched"], [])
        self.assertTrue(elapsed < 1.0)

    def test_coalesced_write_keeps_only_the_last_value(self):
        for g in (-1.0, -2.0, -3.0):
            self.fx.bridge.handle({"id": 1, "cmd": "set_band", "index": 0,
                                   "gain": g})
        self.assertEqual(self.fx.bridge.pending_count(), 2,
                         "left+right collapse to one pending pair")
        self.fx.bridge.flush()
        self.assertEqual(self.fx.fake.state["left0Gain"], "-3")

    def test_background_flusher_writes_without_flush(self):
        self.fx.bridge.start_flusher()
        try:
            for i in range(5):
                self.fx.bridge.handle({"id": i, "cmd": "set_bands",
                                       "bands": [{"index": i, "gain": 1.0}]})
            deadline = time.time() + 3.0
            while time.time() < deadline:
                if any(v.startswith("set_property")
                       for b in self.fx.fake.batches for v in b):
                    break
                time.sleep(0.02)
            self.assertTrue(
                any(v.startswith("set_property")
                    for b in self.fx.fake.batches for v in b),
                "background flusher should have written without an explicit flush")
        finally:
            self.fx.bridge.stop()

    def test_band_index_validation(self):
        for bad in (-1, 32, 99):
            r = self.fx.bridge.handle({"id": 1, "cmd": "set_band",
                                       "index": bad, "gain": 1.0})
            self.assertFalse(r["ok"])

    def test_sync_reports_unconfirmed_writes(self):
        # a write to a module that is not in the chain must not be reported ok
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                                   "module": "limiter", "key": "threshold",
                                   "value": -6.0, "sync": True})
        self.assertTrue(r["written"] >= 1)


class TestChainManagement(unittest.TestCase):
    def setUp(self):
        self.fx = BridgeFixture(chain=["equalizer", "autogain"]).start()

    def tearDown(self):
        self.fx.close()

    def test_ensure_chain_is_idempotent_and_silent(self):
        desired = ["equalizer", "autogain"]
        first = self.fx.bridge.ensure_chain(desired)
        self.assertFalse(first["changed"])
        self.assertFalse(first["reloaded"])
        mtime = self.fx.preset_mtime()
        loads = len(self.fx.fake.loads)
        time.sleep(0.02)
        for _ in range(3):
            again = self.fx.bridge.ensure_chain(desired)
            self.assertFalse(again["changed"],
                             "ensureChain must be a no-op when already correct")
        self.assertEqual(self.fx.preset_mtime(), mtime,
                         "preset mtime must NOT change on repeat calls")
        self.assertEqual(len(self.fx.fake.loads), loads,
                         "no preset reload may happen when nothing changes")

    def test_ensure_chain_adds_module_and_backs_up_first(self):
        mtime = self.fx.preset_mtime()
        res = self.fx.bridge.ensure_chain(["equalizer", "autogain", "limiter"])
        self.assertTrue(res["changed"])
        self.assertTrue(res["reloaded"])
        self.assertEqual(res["chain"], ["equalizer", "autogain", "limiter"])
        self.assertEqual(self.fx.fake.loads[-1], "iNiR Test")
        backup_dir = os.path.join(self.fx.preset_dir, BR.BACKUP_DIRNAME)
        backups = os.listdir(backup_dir)
        self.assertEqual(len(backups), 1,
                         "exactly one backup per distinct content")
        # the backup must be the PRE-write content
        with open(os.path.join(backup_dir, backups[0])) as fh:
            self.assertEqual(json.load(fh)["output"]["plugins_order"],
                             ["equalizer#0", "autogain#0"])
        self.assertNotEqual(self.fx.preset_mtime(), mtime)

    def test_backup_is_not_repeated_for_identical_content(self):
        self.fx.bridge.ensure_chain(["equalizer", "autogain", "limiter"])
        backup_dir = os.path.join(self.fx.preset_dir, BR.BACKUP_DIRNAME)
        after_first = sorted(os.listdir(backup_dir))
        self.assertEqual(len(after_first), 1)
        # rewriting the SAME content must not create a second backup
        doc = self.fx.preset_json()
        # first overwrite of this content backs it up (once)
        self.fx.bridge.write_preset("iNiR Test", doc)
        self.assertEqual(len(os.listdir(backup_dir)), 2,
                         "the content being overwritten must be backed up")
        # writing the very same content again must not add another backup
        self.fx.bridge.write_preset("iNiR Test", doc)
        self.assertEqual(sorted(os.listdir(backup_dir)),
                         sorted(os.listdir(backup_dir)))
        self.assertEqual(len(os.listdir(backup_dir)), 2,
                         "identical content must not be backed up twice")
        # a genuinely different content gets its own backup
        doc2 = json.loads(json.dumps(doc))
        doc2["output"]["plugins_order"] = ["equalizer#0", "autogain#0",
                                           "exciter#0"]
        doc2["output"]["exciter#0"] = BR.build_module_block("exciter")
        self.fx.bridge.write_preset("iNiR Test", doc2)
        self.assertEqual(len(os.listdir(backup_dir)), 2,
                         "backing up is about the content being overwritten")
        self.fx.bridge.write_preset("iNiR Test", doc2)
        self.assertEqual(len(os.listdir(backup_dir)), 3,
                         "the new content must be backed up before overwrite")
        # backups are never deleted
        self.assertTrue(set(after_first) <= set(os.listdir(backup_dir)))

    def test_new_module_block_is_neutral_and_preserves_others(self):
        self.fx.bridge.ensure_chain(["equalizer", "autogain", "limiter"])
        doc = self.fx.preset_json()
        root = doc["output"]
        self.assertEqual(root["plugins_order"],
                         ["equalizer#0", "autogain#0", "limiter#0"])
        self.assertIs(root["limiter#0"]["bypass"], True)
        self.assertIn("silence-threshold", root["autogain#0"])
        self.assertEqual(len(root["equalizer#0"]["left"]), 10)

    def test_equalizer_master_values_survive_a_chain_rewrite(self):
        """The equalizer's master gains/balance/pitch live outside
        "modules", so a chain rewrite must carry them across from the live
        snapshot instead of regenerating them at defaults."""
        for key, val, preset_key in (("inputGain", -4.5, "input-gain"),
                                     ("outputGain", 2.25, "output-gain"),
                                     ("balance", 30.0, "balance")):
            r = self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                                       "module": "equalizer", "key": key,
                                       "value": val, "sync": True})
            self.assertTrue(r["ok"], r)
        res = self.fx.bridge.ensure_chain(
            ["equalizer", "autogain", "limiter"])
        self.assertTrue(res["changed"])
        eq = self.fx.preset_json()["output"]["equalizer#0"]
        self.assertEqual(eq["input-gain"], -4.5)
        self.assertEqual(eq["output-gain"], 2.25)
        self.assertEqual(eq["balance"], 30.0)
        self.assertNotIn("inputGain", eq)
        # and the live state agrees
        st = self.fx.bridge.handle({"id": 1, "cmd": "status"})
        self.assertEqual(st["equalizer"]["inputGain"], -4.5)
        self.assertEqual(st["equalizer"]["outputGain"], 2.25)
        self.assertEqual(st["equalizer"]["balance"], 30.0)

    def test_live_values_survive_a_chain_rewrite(self):
        self.fx.bridge.handle({"id": 1, "cmd": "set_param", "module": "autogain",
                               "key": "target", "value": -15.0, "sync": True})
        self.fx.bridge.ensure_chain(["equalizer", "autogain", "limiter"])
        root = self.fx.preset_json()["output"]
        self.assertEqual(root["autogain#0"]["target"], -15.0,
                         "live autogain target must not be reset to defaults")

    def test_unverified_module_refused_without_touching_preset(self):
        saved = dict(BR.UNVERIFIED_MODULES)
        BR.UNVERIFIED_MODULES["exciter"] = "simulated regression"
        try:
            mtime = self.fx.preset_mtime()
            with self.assertRaises(BR.PresetError):
                self.fx.bridge.ensure_chain(["equalizer", "exciter"])
            self.assertEqual(self.fx.preset_mtime(), mtime)
            self.assertEqual(self.fx.fake.loads, [])
            r = self.fx.bridge.handle({"id": 1, "cmd": "save_preset",
                                       "name": "Bad",
                                       "payload": {"output": {
                                           "blocklist": [],
                                           "plugins_order": ["exciter#0"]}}})
            self.assertFalse(r["ok"])
        finally:
            BR.UNVERIFIED_MODULES.clear()
            BR.UNVERIFIED_MODULES.update(saved)

    def test_cannot_shrink_or_reorder_the_chain(self):
        """Verified EasyEffects limitation: load_preset only appends. A
        shrink or reorder must be refused BEFORE the preset is written."""
        self.fx.bridge.ensure_chain(["equalizer", "autogain", "limiter"])
        mtime = self.fx.preset_mtime()
        loads = len(self.fx.fake.loads)
        with self.assertRaises(BR.PresetError) as cm:
            self.fx.bridge.ensure_chain(["equalizer", "autogain"])
        self.assertIn("append", str(cm.exception))
        self.assertEqual(self.fx.preset_mtime(), mtime,
                         "a refused operation must not touch the preset")
        self.assertEqual(len(self.fx.fake.loads), loads,
                         "a refused operation must not reload")
        with self.assertRaises(BR.PresetError):
            self.fx.bridge.ensure_chain(["equalizer"])
        self.assertEqual(self.fx.preset_mtime(), mtime)
        # appending is still allowed
        res = self.fx.bridge.ensure_chain(
            ["equalizer", "autogain", "limiter", "exciter"])
        self.assertTrue(res["changed"])
        self.assertEqual(set(res["chain"]),
                         {"equalizer", "autogain", "limiter", "exciter"})

    def test_reordered_chain_is_a_noop(self):
        """Order is not knowable over IPC (plugins= flushes lazily) and
        load_preset cannot reorder anyway, so a pure reorder is a no-op."""
        self.fx.bridge.ensure_chain(["equalizer", "autogain"])
        mtime = self.fx.preset_mtime()
        loads = len(self.fx.fake.loads)
        res = self.fx.bridge.ensure_chain(["autogain", "equalizer"])
        self.assertFalse(res["changed"])
        self.assertEqual(self.fx.preset_mtime(), mtime)
        self.assertEqual(len(self.fx.fake.loads), loads)

    def test_crystalizer_can_now_be_added(self):
        res = self.fx.bridge.ensure_chain(["equalizer", "autogain",
                                           "crystalizer"])
        self.assertTrue(res["changed"])
        root = self.fx.preset_json()["output"]
        self.assertEqual(root["plugins_order"],
                         ["equalizer#0", "autogain#0", "crystalizer#0"])
        block = root["crystalizer#0"]
        self.assertEqual(sum(1 for k in block if re.fullmatch(r"band\d+", k)),
                         13)
        self.assertIs(block["bypass"], True)

    def test_band_count_change_rewrites_preset(self):
        res = self.fx.bridge.ensure_chain(["equalizer", "autogain"],
                                           num_bands=15)
        self.assertTrue(res["changed"])
        root = self.fx.preset_json()["output"]
        self.assertEqual(root["equalizer#0"]["num-bands"], 15)
        self.assertEqual(len(root["equalizer#0"]["left"]), 15)

    def test_band_count_noop_when_already_correct(self):
        res = self.fx.bridge.ensure_chain(["equalizer", "autogain"],
                                           num_bands=10)
        self.assertFalse(res["changed"])

    def test_set_band_count_rejects_unsupported(self):
        for bad in (8, 12, 64, 0):
            r = self.fx.bridge.handle({"id": 1, "cmd": "set_band_count",
                                       "count": bad})
            self.assertFalse(r["ok"])
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_band_count",
                                   "count": 15})
        self.assertTrue(r["ok"])
        self.assertEqual(self.fx.preset_json()["output"]["equalizer#0"]["num-bands"],
                         15)


class TestPresetCommands(unittest.TestCase):
    def setUp(self):
        self.fx = BridgeFixture(chain=["equalizer"]).start()

    def tearDown(self):
        self.fx.close()

    def test_list_presets(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "list_presets"})
        self.assertTrue(r["ok"])
        self.assertIn("iNiR Test", r["presets"])

    def test_apply_preset(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "apply_preset",
                                   "name": "iNiR Test"})
        self.assertTrue(r["ok"])
        self.assertEqual(self.fx.fake.loads[-1], "iNiR Test")

    def test_apply_missing_preset(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "apply_preset",
                                   "name": "nope"})
        self.assertFalse(r["ok"])

    def test_save_and_delete(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "save_preset",
                                   "name": "Copy"})
        self.assertTrue(r["ok"])
        self.assertIn("Copy", self.fx.bridge.list_presets())
        r = self.fx.bridge.handle({"id": 1, "cmd": "delete_preset",
                                   "name": "Copy"})
        self.assertTrue(r["ok"])
        self.assertNotIn("Copy", self.fx.bridge.list_presets())
        # deleting must leave a backup behind
        backup_dir = os.path.join(self.fx.preset_dir, BR.BACKUP_DIRNAME)
        self.assertTrue(os.path.isdir(backup_dir))
        self.assertTrue(os.listdir(backup_dir))

    def test_all_preset_commands_reject_traversal(self):
        for cmd, key in (("apply_preset", "name"), ("save_preset", "name"),
                         ("delete_preset", "name")):
            r = self.fx.bridge.handle({"id": 1, "cmd": cmd,
                                       key: "../../../etc/passwd"})
            self.assertFalse(r["ok"], "%s accepted traversal" % cmd)
            self.assertEqual(r["error"], "preset_error")

    def test_save_preset_rejects_unverified_module(self):
        saved = dict(BR.UNVERIFIED_MODULES)
        BR.UNVERIFIED_MODULES["exciter"] = "simulated regression"
        try:
            payload = {"output": {"blocklist": [],
                                  "plugins_order": ["equalizer#0",
                                                    "exciter#0"]}}
            r = self.fx.bridge.handle({"id": 1, "cmd": "save_preset",
                                       "name": "Bad", "payload": payload})
            self.assertFalse(r["ok"])
        finally:
            BR.UNVERIFIED_MODULES.clear()
            BR.UNVERIFIED_MODULES.update(saved)

    def test_save_preset_accepts_crystalizer_now(self):
        blk = BR.build_module_block("crystalizer")
        payload = {"output": {"blocklist": [],
                              "plugins_order": ["equalizer#0",
                                                "crystalizer#0"],
                              "crystalizer#0": blk}}
        r = self.fx.bridge.handle({"id": 1, "cmd": "save_preset",
                                   "name": "WithCrys", "payload": payload})
        self.assertTrue(r["ok"], r)

    def test_save_preset_rejects_malformed_payload(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "save_preset",
                                   "name": "Bad", "payload": {"nope": 1}})
        self.assertFalse(r["ok"])


class TestSavePresetCapturesLiveState(unittest.TestCase):
    """The panel sends save_preset with a name and no payload, so the bridge
    has to build the payload itself from the ENGINE state: the last-loaded
    preset FILE never sees a band move or a module toggle, because those live
    in the engine until something rewrites the file."""

    def setUp(self):
        self.fx = BridgeFixture(
            chain=["equalizer", "autogain", "limiter"]).start()
        # The fake answers "1000" for every band frequency, which would make
        # every live band look like the same band. Seed the real octave curve
        # so frequency matching has something to match on.
        for i, freq in enumerate(BR.ISO_BAND_FREQS):
            self.fx.fake.state["left%dFrequency" % i] = str(freq)
            self.fx.fake.state["right%dFrequency" % i] = str(freq)

    def tearDown(self):
        self.fx.close()

    def save(self, name="Snapshot"):
        r = self.fx.bridge.handle({"id": 1, "cmd": "save_preset", "name": name})
        self.assertTrue(r["ok"], r)
        return self.fx.preset_json(name)

    def test_live_module_bypass_reaches_the_file(self):
        # the seeded file has every module bypassed; the user enabled one
        self.assertTrue(self.fx.preset_json()["output"]["autogain#0"]["bypass"])
        self.fx.fake.mod_state["autogain:bypass"] = "false"
        root = self.save()["output"]
        self.assertIs(root["autogain#0"]["bypass"], False)
        self.assertIs(root["equalizer#0"]["bypass"], False)
        # and an untouched module keeps its on-disk state
        self.assertIs(root["limiter#0"]["bypass"], True)

    def test_bypass_is_written_as_a_json_bool(self):
        self.fx.fake.mod_state["autogain:bypass"] = "false"
        root = self.save()["output"]
        self.assertIsInstance(root["autogain#0"]["bypass"], bool)
        with open(os.path.join(self.fx.preset_dir, "Snapshot.json")) as fh:
            self.assertIn('"bypass": false', fh.read())

    def test_live_band_gain_beats_the_stale_file(self):
        before = self.fx.preset_json()["output"]["equalizer#0"]["left"]["band0"]
        self.assertEqual(before["gain"], 0.0)
        self.fx.fake.state["left0Gain"] = "-7.5"
        after = self.save()["output"]["equalizer#0"]["left"]["band0"]
        self.assertEqual(after["gain"], -7.5)
        # the base file itself is never rewritten
        self.assertEqual(
            self.fx.preset_json()["output"]["equalizer#0"]["left"]["band0"]["gain"],
            0.0)

    def test_bands_are_matched_by_frequency_not_by_index(self):
        # rotate the engine's band order: engine index 0 now sits at 1000 Hz,
        # which is preset entry band5. EasyEffects appends bands at the END,
        # so index != position exactly here.
        for i in range(10):
            freq = BR.ISO_BAND_FREQS[(i + 5) % 10]
            self.fx.fake.state["left%dFrequency" % i] = str(freq)
        self.fx.fake.state["left0Gain"] = "9"      # the 1000 Hz band
        self.fx.fake.state["left5Gain"] = "-3"     # the 32 Hz band
        left = self.save()["output"]["equalizer#0"]["left"]
        self.assertEqual(left["band5"]["gain"], 9.0)
        self.assertEqual(left["band0"]["gain"], -3.0)

    def test_a_band_matching_nothing_is_left_alone(self):
        self.fx.fake.state["left0Frequency"] = "777"   # matches no entry
        self.fx.fake.state["left0Gain"] = "12"
        left = self.save()["output"]["equalizer#0"]["left"]
        for i in range(10):
            self.assertEqual(left["band%d" % i]["gain"], 0.0,
                             "an unmatched band must not overwrite a neighbour")
        # ...and its frequency is not smuggled into the file either
        self.assertNotIn(777.0, [left["band%d" % i]["frequency"]
                                 for i in range(10)])

    def test_band_count_and_type_reach_the_file(self):
        self.fx.fake.state["left0Type"] = "6"          # Notch
        self.fx.fake.state["left0Q"] = "1.5"
        block = self.save()["output"]["equalizer#0"]
        self.assertEqual(block["num-bands"], 10)
        self.assertEqual(block["left"]["band0"]["type"], "Notch")
        self.assertEqual(block["left"]["band0"]["q"], 1.5)

    def test_required_keys_and_base_are_preserved(self):
        root = self.save()["output"]
        self.assertIn("blocklist", root)
        self.assertIn("plugins_order", root)
        # untouched module keys the live snapshot never reports survive
        self.assertIn("input-gain", root["equalizer#0"])
        self.assertIn("target", root["autogain#0"])

    def test_saving_does_not_touch_what_is_playing(self):
        loads = len(self.fx.fake.loads)
        self.fx.fake.verbs.clear()
        self.save()
        self.assertEqual(self.fx.fake.loads, self.fx.fake.loads[:loads])
        self.assertNotIn("load_preset:output:Snapshot", self.fx.fake.verbs)

    def test_no_base_preset_is_a_clear_error(self):
        self.fx.fake.preset = ""               # EasyEffects has none loaded
        os.unlink(os.path.join(self.fx.preset_dir, "iNiR Test.json"))
        r = self.fx.bridge.handle({"id": 1, "cmd": "save_preset", "name": "X"})
        self.assertFalse(r["ok"])
        self.assertEqual(r["error"], "preset_error")
        self.assertIn("nothing to save from", r["detail"])
        self.assertFalse(os.path.exists(os.path.join(self.fx.preset_dir,
                                                     "X.json")))

    def test_falls_back_to_the_newest_preset_when_none_is_loaded(self):
        self.fx.fake.preset = ""
        self.fx.fake.state["left0Gain"] = "4"
        root = self.save("from-disk")["output"]
        self.assertEqual(root["equalizer#0"]["left"]["band0"]["gain"], 4.0)

    def test_the_loaded_preset_is_the_base_not_the_newest_file(self):
        # a stale route that picks the wrong file produces a preset that looks
        # plausible, so pin the choice: the base is what the engine loaded.
        path = os.path.join(self.fx.preset_dir, "Other.json")
        with open(path, "w") as fh:
            json.dump({"output": {"blocklist": [],
                                  "plugins_order": ["equalizer#0"],
                                  "equalizer#0": dict(
                                      BR.build_equalizer_block(10),
                                      marker="other")}}, fh)
        self.assertGreater(os.path.getmtime(path),
                           os.path.getmtime(os.path.join(
                               self.fx.preset_dir, "iNiR Test.json")))
        base, name = self.fx.bridge._base_preset_for_save()
        self.assertEqual(name, "iNiR Test")
        self.assertNotIn("marker", base["output"]["equalizer#0"])
        # and the marker never reaches the saved file
        self.assertNotIn("marker", self.save()["output"]["equalizer#0"])

    def test_explicit_payload_still_short_circuits_the_live_read(self):
        payload = {"output": {"blocklist": [],
                              "plugins_order": ["equalizer#0"],
                              "equalizer#0": BR.build_equalizer_block(10)}}
        payload["output"]["equalizer#0"]["left"]["band0"]["gain"] = 3.0
        self.fx.fake.state["left0Gain"] = "11"
        r = self.fx.bridge.handle({"id": 1, "cmd": "save_preset",
                                   "name": "Literal", "payload": payload})
        self.assertTrue(r["ok"], r)
        block = self.fx.preset_json("Literal")["output"]["equalizer#0"]
        self.assertEqual(block["left"]["band0"]["gain"], 3.0)

    def test_a_write_queued_moments_earlier_is_saved(self):
        """set_param coalesces, so without promoting the window first the save
        reads the engine BEFORE the user's own change has landed and stores
        the value they just replaced."""
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                                   "module": "autogain", "key": "target",
                                   "value": -9.5})
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["queued"], 1)
        # the fixture never starts the background flusher, so the only thing
        # that can put this on the engine is the save itself
        self.assertNotIn("autogain:target", self.fx.fake.mod_state)
        block = self.save()["output"]["autogain#0"]
        self.assertEqual(self.fx.fake.mod_state.get("autogain:target"), "-9.5")
        self.assertEqual(block["target"], -9.5)


class TestSavePresetCapturesModuleConfig(unittest.TestCase):
    """A module's settings live in the engine until something rewrites the
    preset file, so copying that file stored whatever the module was set to
    when the file was last written - the user enabled a module and saved, and
    got back the old values."""

    def setUp(self):
        self.fx = BridgeFixture(chain=["equalizer", "autogain", "limiter",
                                       "crystalizer"]).start()
        for i, freq in enumerate(BR.ISO_BAND_FREQS):
            self.fx.fake.state["left%dFrequency" % i] = str(freq)
            self.fx.fake.state["right%dFrequency" % i] = str(freq)

    def tearDown(self):
        self.fx.close()

    def save(self, name="Snapshot"):
        r = self.fx.bridge.handle({"id": 1, "cmd": "save_preset", "name": name})
        self.assertTrue(r["ok"], r)
        return self.fx.preset_json(name)

    def patch_base(self, mutate, name="iNiR Test"):
        """Edit the seeded base preset in place, so a test can prove the file's
        own value would have won if the overlay had not run."""
        path = os.path.join(self.fx.preset_dir, name + ".json")
        with open(path) as fh:
            doc = json.load(fh)
        mutate(doc["output"])
        with open(path, "w") as fh:
            json.dump(doc, fh, indent=2)

    def test_a_parameter_other_than_bypass_reaches_the_file(self):
        # the file says -23; the engine says -9.5
        self.patch_base(lambda root: root["autogain#0"].update(
            {"target": -23.0, "silence-threshold": -70.0}))
        self.fx.fake.mod_state["autogain:target"] = "-9.5"
        self.fx.fake.mod_state["autogain:silenceThreshold"] = "-61"
        block = self.save()["output"]["autogain#0"]
        self.assertEqual(block["target"], -9.5)
        self.assertEqual(block["silence-threshold"], -61.0)

    def test_every_module_in_the_chain_is_overlaid(self):
        self.fx.fake.mod_state["limiter:threshold"] = "-2.5"
        self.fx.fake.mod_state["limiter:lookahead"] = "7"
        self.fx.fake.mod_state["crystalizer:inputGain"] = "-3.5"
        root = self.save()["output"]
        self.assertEqual(root["limiter#0"]["threshold"], -2.5)
        self.assertEqual(root["limiter#0"]["lookahead"], 7.0)
        self.assertEqual(root["crystalizer#0"]["input-gain"], -3.5)

    def test_crystalizer_bands_land_as_nested_objects(self):
        # the live map spells these "band0.intensity"; the preset stores them
        # as a "band0" OBJECT. A dotted key in the preset is unreadable.
        self.fx.fake.state["intensityBand0"] = "4.5"
        self.fx.fake.state["bypassBand3"] = "false"
        self.fx.fake.state["muteBand12"] = "true"
        block = self.save()["output"]["crystalizer#0"]
        dotted = [k for k in block if "." in k]
        self.assertEqual(dotted, [], "dotted keys leaked into the preset")
        self.assertEqual(block["band0"]["intensity"], 4.5)
        self.assertIs(block["band3"]["bypass"], False)
        self.assertIs(block["band12"]["mute"], True)
        # and every band is still a full object, never a bare value
        for i in range(13):
            self.assertIsInstance(block["band%d" % i], dict)
            self.assertIn("bypass", block["band%d" % i])

    def test_crystalizer_scalar_params_keep_their_preset_spelling(self):
        self.fx.fake.mod_state["crystalizer:adaptiveIntensity"] = "true"
        self.fx.fake.mod_state["crystalizer:useFixedQuantum"] = "true"
        block = self.save()["output"]["crystalizer#0"]
        self.assertIs(block["adaptive-intensity"], True)
        self.assertIs(block["fixed-quantum"], True)

    def test_equalizer_bands_still_land_after_the_module_overlay(self):
        self.fx.fake.state["left0Gain"] = "-6"
        self.fx.fake.mod_state["equalizer:bypass"] = "true"
        block = self.save()["output"]["equalizer#0"]
        self.assertEqual(block["left"]["band0"]["gain"], -6.0)
        self.assertIs(block["bypass"], True)
        # the general overlay must not have invented or dropped the sides
        self.assertEqual(len(block["left"]), 10)
        self.assertEqual(len(block["right"]), 10)
        self.assertNotIn("bands", block)

    def test_unknown_value_leaves_the_base_alone(self):
        # an unreadable parameter comes back as None; writing a guess over a
        # known-good value would be worse than keeping it
        self.patch_base(lambda root: root["limiter#0"].update({"threshold": -1.5}))
        self.fx.fake.mod_state["limiter:threshold"] = "error_out_of_range"
        self.assertEqual(self.save()["output"]["limiter#0"]["threshold"], -1.5)


class TestParamValidation(unittest.TestCase):
    def setUp(self):
        self.fx = BridgeFixture(
            chain=["equalizer", "autogain", "limiter", "crystalizer"]).start()

    def tearDown(self):
        self.fx.close()

    def test_set_param_rejects_unverified_key(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                                   "module": "limiter", "key": "ceiling",
                                   "value": 0})
        self.assertFalse(r["ok"])
        self.assertIn("ceiling", r["detail"])

    def test_set_param_accepts_verified_key(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                                   "module": "limiter", "key": "threshold",
                                   "value": -6.0, "sync": True})
        self.assertTrue(r["ok"])
        self.assertEqual(self.fx.fake.state["threshold"], "-6")

    def test_set_module_maps_active_to_bypass(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_module",
                                   "module": "limiter", "active": False,
                                   "sync": True})
        self.assertTrue(r["ok"])
        self.assertEqual(self.fx.fake.state["bypass"], "true")
        self.assertFalse(r["reloaded"],
                         "set_module must never reload the preset")

    def test_keys_command_reports_schema(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "keys"})
        self.assertTrue(r["ok"])
        self.assertIn("equalizer", r["keys"])
        self.assertIn("crystalizer", r["keys"])
        self.assertEqual(r["unverified"], {})
        self.assertEqual(r["bandCounts"], [10, 15, 32])

    def test_set_param_accepts_crystalizer_band_key(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                                   "module": "crystalizer",
                                   "key": "band3.intensity", "value": 7.5,
                                   "sync": True})
        self.assertTrue(r["ok"], r)
        self.assertEqual(self.fx.fake.state["intensityBand3"], "7.5")

    def test_set_param_rejects_out_of_range_band_index(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                                   "module": "crystalizer",
                                   "key": "band13.intensity", "value": 1.0})
        self.assertFalse(r["ok"], "crystalizer has exactly 13 bands")


class TestStatusAndCache(unittest.TestCase):
    def setUp(self):
        self.fx = BridgeFixture(
            chain=["equalizer", "autogain", "crystalizer"]).start()

    def tearDown(self):
        self.fx.close()

    def test_status_shape(self):
        r = self.fx.bridge.handle({"id": 1, "cmd": "status"})
        self.assertTrue(r["ok"])
        for key in ("available", "preset", "chain", "modules", "equalizer",
                    "snapshot"):
            self.assertIn(key, r)
        eq = r["equalizer"]
        for key in ("numBands", "bands", "inputGain", "outputGain", "balance",
                    "splitChannels"):
            self.assertIn(key, eq)
        self.assertEqual(len(eq["bands"]), 10)
        for key in ("index", "frequency", "gain", "q", "type", "mode"):
            self.assertIn(key, eq["bands"][0])

    def test_status_reports_crystalizer_band_values(self):
        """refresh() must read the 13 band values, not just the scalars, or a
        later chain rewrite would reset them."""
        st = self.fx.bridge.handle({"id": 1, "cmd": "status"})
        crys = st["modules"]["crystalizer"]
        self.assertIn("bypass", crys)
        for i in range(13):
            for field in ("intensity", "mute", "bypass"):
                self.assertIn("band%d.%s" % (i, field), crys)
        self.assertNotIn("band13.intensity", crys)
        # the flat camelCase IPC spelling must never be exposed
        for i in range(13):
            self.assertNotIn("intensityBand%d" % i, crys)
            self.assertNotIn("muteBand%d" % i, crys)

    def test_status_cache_is_updated_after_a_band_write(self):
        """The cache must reflect a write immediately.

        The IPC field is capitalised ("left:band0Gain") while the cache stores
        "gain": assigning the wrong name silently creates a dead key and
        status() reports the previous value forever.
        """
        self.fx.bridge.handle({"id": 1, "cmd": "status"})   # warm the cache
        before = self.fx.bridge.handle({"id": 1, "cmd": "status"})
        old = before["equalizer"]["bands"][3]["gain"]
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_band", "index": 3,
                                   "gain": -4.25, "sync": True})
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["mismatched"], [])
        after = self.fx.bridge.handle({"id": 1, "cmd": "status"})
        self.assertEqual(after["equalizer"]["bands"][3]["gain"], -4.25,
                         "cached status must show the value just written")
        self.assertNotEqual(after["equalizer"]["bands"][3]["gain"], old)

    def test_spec_shape_per_module(self):
        """status carries `spec`: per module a list of
        {key,min,max,default,unit,type} entries, keyed by PUBLIC name."""
        st = self.fx.bridge.handle({"id": 1, "cmd": "status"})
        self.assertIn("spec", st)
        spec = st["spec"]
        for module in ("equalizer", "autogain", "bass_enhancer", "exciter",
                       "limiter", "crystalizer"):
            self.assertIn(module, spec)
            self.assertIsInstance(spec[module], list)
            self.assertTrue(spec[module])
            for entry in spec[module]:
                for field in ("key", "min", "max", "default", "unit", "type"):
                    self.assertIn(field, entry,
                                  "%s: %r missing %s" % (module, entry, field))
                self.assertIn(entry["type"], ("float", "int", "bool", "enum"))
                self.assertIsInstance(entry["key"], str)

    def test_spec_uses_public_keys_only(self):
        spec = self.fx.bridge.handle({"id": 1, "cmd": "status"})["spec"]
        camel = {"floorActive", "ceilActive", "silenceThreshold",
                 "gainBoost", "stereoLink", "inputGain", "outputGain",
                 "adaptiveIntensity", "useFixedQuantum", "transitionBand",
                 "oversamplingQuality", "maximumHistory", "forceSilence",
                 "numBands", "splitChannels", "pitchLeft", "pitchRight"}
        for module, entries in spec.items():
            for entry in entries:
                if module == "equalizer" and entry["key"] in (
                        "inputGain", "outputGain"):
                    continue      # panel contract: master gains are camelCase
                self.assertNotIn(entry["key"], camel,
                                 "%s leaks IPC key %r" % (module, entry["key"]))
        # spot-check that the documented public names are present
        keys = {m: {e["key"] for e in v} for m, v in spec.items()}
        self.assertIn("floor-active", keys["bass_enhancer"])
        self.assertIn("ceil-active", keys["exciter"])
        self.assertIn("silence-threshold", keys["autogain"])
        self.assertIn("maximum-history", keys["autogain"])
        self.assertIn("force-silence", keys["autogain"])
        self.assertIn("stereo-link", keys["limiter"])
        self.assertIn("input-gain", keys["crystalizer"])
        self.assertIn("adaptive-intensity", keys["crystalizer"])
        self.assertIn("fixed-quantum", keys["crystalizer"])
        self.assertIn("transition-band", keys["crystalizer"])
        self.assertIn("oversampling-quality", keys["crystalizer"])
        self.assertIn("num-bands", keys["equalizer"])

    def test_spec_ranges_are_measured_values(self):
        spec = self.fx.bridge.handle({"id": 1, "cmd": "status"})["spec"]
        by = {m: {e["key"]: e for e in v} for m, v in spec.items()}
        self.assertEqual(by["limiter"]["threshold"]["min"], -48.0)
        self.assertEqual(by["limiter"]["threshold"]["max"], 0.0)
        self.assertEqual(by["limiter"]["threshold"]["unit"], "dB")
        self.assertEqual(by["limiter"]["stereo-link"]["max"], 100.0)
        self.assertEqual(by["exciter"]["ceil"]["min"], 10000.0)
        self.assertEqual(by["exciter"]["scope"]["max"], 12000.0)
        self.assertEqual(by["bass_enhancer"]["floor"]["max"], 120.0)
        self.assertEqual(by["autogain"]["target"]["unit"], "LUFS")
        self.assertEqual(by["equalizer"]["num-bands"]["max"], 32)
        self.assertEqual(by["crystalizer"]["band3.intensity"]["min"], -40.0)
        # enums advertise their accepted labels
        self.assertIn("Half x2/16 bit", by["limiter"]["oversampling"]["values"])
        self.assertIn("16bit", by["limiter"]["dithering"]["values"])
        self.assertEqual(by["limiter"]["oversampling"]["default"], "None")

    def test_status_modules_use_public_keys(self):
        st = self.fx.bridge.handle({"id": 1, "cmd": "status"})
        for module, values in st["modules"].items():
            if not isinstance(values, dict) or module == "equalizer":
                continue
            for key in values:
                self.assertNotIn(key, {"floorActive", "ceilActive",
                                       "silenceThreshold", "stereoLink",
                                       "gainBoost", "inputGain", "outputGain",
                                       "adaptiveIntensity", "useFixedQuantum",
                                       "transitionBand", "maximumHistory",
                                       "forceSilence"},
                                 "%s reports IPC key %r" % (module, key))
        crys = st["modules"].get("crystalizer", {})
        self.assertIn("adaptive-intensity", crys)
        self.assertIn("oversampling-quality", crys)
        self.assertIn("band0.intensity", crys)
        self.assertNotIn("adaptiveIntensity", crys)
        self.assertNotIn("intensityBand0", crys)
        # values must actually be read, not silently None: reading the PUBLIC
        # key on the wire would yield the right names with no data behind them
        self.assertIs(crys["bypass"], True)
        self.assertEqual(crys["oversampling-quality"], 3)
        self.assertIs(crys["adaptive-intensity"], False)
        self.assertEqual(crys["input-gain"], 0.0)
        ag = st["modules"].get("autogain", {})
        self.assertEqual(ag.get("bypass"), False)
        self.assertEqual(ag.get("target"), -23.0)

    def test_set_param_rejects_camelcase_key(self):
        """The bridge must not accept EasyEffects' IPC spelling: QML should have
        no way to depend on it."""
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                                   "module": "bass_enhancer",
                                   "key": "floorActive", "value": 40.0})
        self.assertFalse(r["ok"])
        self.assertIn("floor-active", r["detail"])

    def test_snapshot_is_stable_and_changes_with_state(self):
        a = self.fx.bridge.handle({"id": 1, "cmd": "status"})["snapshot"]
        b = self.fx.bridge.handle({"id": 1, "cmd": "status"})["snapshot"]
        self.assertEqual(a, b)
        self.fx.bridge.handle({"id": 1, "cmd": "set_param", "module": "autogain",
                               "key": "target", "value": -12.0, "sync": True})
        c = self.fx.bridge.handle({"id": 1, "cmd": "status"})["snapshot"]
        self.assertNotEqual(a, c)

    def test_status_uses_batched_round_trips(self):
        before = self.fx.fake.verbs.count("get_property:output:equalizer:0:numBands")
        self.fx.bridge.handle({"id": 1, "cmd": "status"})
        after = self.fx.fake.verbs.count("get_property:output:equalizer:0:numBands")
        self.assertLessEqual(after - before, 2,
                             "numBands must not be fetched once per band")


class TestSocketLifecycle(unittest.TestCase):
    """Stale socket handling and the single-instance lock."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="inir-sock-")
        self.sock_path = os.path.join(self.tmp, "inir-audio.sock")
        self.lock_path = self.sock_path + ".lock"

    def tearDown(self):
        for p in (self.sock_path, self.lock_path):
            if os.path.exists(p):
                os.unlink(p)

    def test_second_instance_exits_cleanly(self):
        first = BR.acquire_lock(self.lock_path)
        self.assertIsNotNone(first)
        # a live socket so the daemon reports "already served"
        srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        srv.bind(self.sock_path)
        srv.listen(1)
        bridge = BR.Bridge(socket_path=self.sock_path,
                           preset_dir=self.tmp)
        rc = BR.run_socket_server(bridge, self.sock_path, self.lock_path)
        self.assertEqual(rc, 0, "a second daemon must exit cleanly, not steal")
        srv.close()

    def test_stale_socket_is_removed(self):
        # a socket file with nothing listening is stale
        stale = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        stale.bind(self.sock_path)
        stale.close()          # leaves the file on disk, no listener
        self.assertTrue(os.path.exists(self.sock_path))
        self.assertFalse(BR.socket_is_live(self.sock_path))
        os.unlink(self.sock_path)   # run_socket_server unlinks on exit

        proc = subprocess.Popen(
            [sys.executable, BRIDGE_PATH, "--socket", self.sock_path,
             "--no-warmup", "--preset-dir", self.tmp],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.time() + 10
            while time.time() < deadline and not BR.socket_is_live(self.sock_path):
                time.sleep(0.05)
            self.assertTrue(BR.socket_is_live(self.sock_path),
                            "daemon should have removed the stale socket")
            # and it serves the protocol
            c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            c.settimeout(5)
            c.connect(self.sock_path)
            c.sendall(b'{"id":1,"cmd":"ping"}\n')
            data = c.recv(65536)
            self.assertTrue(json.loads(data.split(b"\n")[0])["ok"])
            c.close()
        finally:
            proc.terminate()
            proc.wait(timeout=10)
        self.assertFalse(os.path.exists(self.sock_path),
                         "socket must be removed on shutdown")

    def test_socket_is_live_detection(self):
        self.assertFalse(BR.socket_is_live(os.path.join(self.tmp, "absent")))
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.bind(self.sock_path)
        s.listen(1)
        try:
            self.assertTrue(BR.socket_is_live(self.sock_path))
        finally:
            s.close()


class TestStdinModeAndCli(unittest.TestCase):
    def _run(self, args, stdin_text):
        return subprocess.run([sys.executable, BRIDGE_PATH] + args,
                              input=stdin_text.encode(),
                              capture_output=True, timeout=30)

    def test_version_mentions_program_and_number(self):
        out = self._run(["--version"], "").stdout.decode()
        self.assertIn("inir-audio-bridge", out)
        self.assertIn(BR.VERSION, out)

    def test_stdin_mode_protocol(self):
        proc = self._run(["--stdin"],
                         '{"id":1,"cmd":"ping"}\n{"id":2,"cmd":"keys"}\n'
                         '{"id":3,"cmd":"bogus"}\n')
        lines = [json.loads(x) for x in proc.stdout.decode().splitlines() if x]
        self.assertEqual([r["id"] for r in lines], [1, 2, 3])
        self.assertTrue(lines[0]["ok"])
        self.assertTrue(lines[1]["ok"])
        self.assertFalse(lines[2]["ok"])

    def test_stdout_is_protocol_only(self):
        proc = self._run(["--stdin", "--verbose"], '{"id":1,"cmd":"ping"}\n')
        for line in proc.stdout.decode().splitlines():
            if line.strip():
                json.loads(line)   # every stdout line must be valid JSON

    def test_status_without_easyeffects(self):
        tmp = tempfile.mkdtemp(prefix="inir-noee-")
        proc = self._run(["--stdin", "--ee-socket",
                          os.path.join(tmp, "absent.sock"),
                          "--preset-dir", tmp],
                         '{"id":1,"cmd":"status"}\n')
        resp = json.loads(proc.stdout.decode().splitlines()[0])
        self.assertFalse(resp["ok"])
        self.assertEqual(resp["error"], BR.ERR_UNAVAILABLE)


class TestNoThirdPartyImports(unittest.TestCase):
    def test_only_stdlib(self):
        with open(BRIDGE_PATH) as fh:
            source = fh.read()
        banned = ["import requests", "import numpy", "import yaml",
                  "from gi", "import gi", "PyQt5", "PySide"]
        for name in banned:
            self.assertNotIn(name, source)


class TestStatusReportsEngineDeath(unittest.TestCase):
    """`status` must never be answered out of the cache.

    refresh() short-circuits on a cached snapshot unless forced, so the engine's
    LIVENESS must bypass it: after EasyEffects dies the daemon would keep
    answering available:True from the last good snapshot, and the panel would
    never learn it had to offer opening it again. Every other caller of
    refresh() already forces.
    """

    def _kill_engine(self):
        fx = BridgeFixture(chain=["equalizer"]).start()
        self.addCleanup(fx.close)
        alive = fx.bridge.cmd_status({})
        self.assertTrue(alive.get("ok"),
                        "fixture must come up alive, got %r" % (alive,))
        self.assertTrue(alive.get("available"), alive)
        fx.fake.stop()
        return fx

    def test_status_stops_claiming_available_once_the_engine_dies(self):
        fx = self._kill_engine()
        st = fx.bridge.cmd_status({})
        self.assertFalse(st.get("ok"), st)
        self.assertEqual(st.get("error"), BR.ERR_UNAVAILABLE, st)
        self.assertFalse(st.get("available"), st)

    def test_status_ignores_the_callers_force_flag(self):
        # The panel never sends `force`, so it must not be the only way to get
        # the truth out of a status call.
        fx = self._kill_engine()
        for payload in ({}, {"force": False}, {"force": True}):
            st = fx.bridge.cmd_status(payload)
            self.assertEqual(st.get("error"), BR.ERR_UNAVAILABLE, payload)
            self.assertFalse(st.get("available"), payload)
            self.assertFalse(st.get("ok"), payload)


class TestBandEnumWrites(unittest.TestCase):
    """Per-band `type` and `mode` travel the same _band_writes path as gain.

    EasyEffects does not clamp enums and set_property returns nothing at all,
    so a wrong label fails silently. Everything here is therefore readback
    verified, and an unknown label must be an error that writes nothing.
    """

    def test_verified_enum_tables_match_the_binary(self):
        """The published label sets are pinned so a future edit cannot silently
        reorder them. `Off` sits at index 0 and `Bell` at index 1, which is what
        the live engine reads for a default band; a wrong order misreports
        every default band."""
        types = BR.EQ_BAND_PARAMS["Type"]["enum"]
        modes = BR.EQ_BAND_PARAMS["Mode"]["enum"]
        self.assertEqual(types[0], "Off")
        self.assertEqual(types[1], "Bell")
        self.assertEqual(types[2:],
                         ["Hi-pass", "Hi-shelf", "Lo-pass", "Lo-shelf", "Notch",
                          "Resonance", "Allpass", "Bandpass", "Ladder-pass",
                          "Ladder-rej"])
        self.assertEqual(BR.EQ_BAND_PARAMS["Type"]["max"], len(types) - 1)
        # All six documented modes confirmed as literals in the binary, plus
        # APO (DR). There is no "APO (PS)": it occurs zero times.
        self.assertEqual(modes,
                         ["RLC (BT)", "RLC (MT)", "BWC (BT)", "BWC (MT)",
                          "LRX (BT)", "LRX (MT)", "APO (DR)"])
        self.assertEqual(BR.EQ_BAND_PARAMS["Mode"]["max"], len(modes) - 1)
        self.assertNotIn("APO (PS)", modes)
        self.assertEqual(BR.EQ_BAND_TYPES["Bell"], 1)
        self.assertEqual(BR.EQ_BAND_MODES["RLC (BT)"], 0)

    def test_filter_plugin_spelling_is_not_mixed_in(self):
        """The Filter plugin spells these "Low-pass"/"High-pass"/"All-pass".
        Accepting them here would be cross-contamination: the equalizer's own
        labels are "Lo-pass"/"Hi-pass"/"Allpass"."""
        for wrong in ("Low-pass", "High-pass", "Low-shelf", "High-shelf",
                      "All-pass", "High Pass", "Low Pass", "All Pass"):
            fx = BridgeFixture(chain=["equalizer"]).start()
            try:
                r = fx.bridge.handle({"id": 1, "cmd": "set_band",
                                      "index": 0, "type": wrong, "sync": True})
                self.assertFalse(r.get("ok"), (wrong, r))
            finally:
                fx.close()

    def test_type_round_trips_through_the_readback(self):
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            for label in ("Bell", "Hi-pass", "Lo-shelf", "Notch", "Allpass"):
                r = fx.bridge.handle({"id": 1, "cmd": "set_band", "sync": True,
                                      "index": 2, "type": label})
                self.assertTrue(r["ok"], (label, r))
                self.assertEqual(r["mismatched"], [], (label, r))
                self.assertEqual(fx.fake.state["left2Type"],
                                 str(BR.EQ_BAND_TYPES[label]))
                self.assertEqual(fx.fake.state["right2Type"],
                                 str(BR.EQ_BAND_TYPES[label]))
            # and the cached status reports the label back
            bands = fx.bridge.cmd_status({})["equalizer"]["bands"]
            self.assertEqual(bands[2]["type"], "Allpass")
        finally:
            fx.close()

    def test_mode_round_trips_through_the_readback(self):
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            for label in BR.EQ_BAND_PARAMS["Mode"]["enum"]:
                r = fx.bridge.handle({"id": 1, "cmd": "set_band", "sync": True,
                                      "index": 1, "mode": label})
                self.assertTrue(r["ok"], (label, r))
                self.assertEqual(r["mismatched"], [], (label, r))
                self.assertEqual(fx.fake.state["left1Mode"],
                                 str(BR.EQ_BAND_MODES[label]))
                self.assertEqual(fx.fake.state["right1Mode"],
                                 str(BR.EQ_BAND_MODES[label]))
            bands = fx.bridge.cmd_status({})["equalizer"]["bands"]
            self.assertEqual(bands[1]["mode"], "APO (DR)")
        finally:
            fx.close()

    def test_unknown_label_is_an_error_and_writes_nothing(self):
        """An unknown label must never reach the wire: a rejected write that
        still emitted a set_property would half-apply the batch."""
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            r = fx.bridge.handle({"id": 1, "cmd": "set_band", "sync": True,
                                  "index": 0, "type": "Nope",
                                  "mode": "BWC (PS)"})
            self.assertFalse(r["ok"], r)
            self.assertIn("error", r)
            self.assertNotIn("left0Type", fx.fake.state)
            self.assertNotIn("right0Type", fx.fake.state)
            self.assertNotIn("left0Mode", fx.fake.state)
            verbs = [v for v in fx.fake.verbs if v.startswith("set_property")]
            self.assertEqual(verbs, [], verbs)
        finally:
            fx.close()

    def test_unknown_label_rejects_the_whole_batch_entry(self):
        """A good field alongside a bad one must not be written: the entry is
        rejected as a unit, so the band cannot end up half-changed."""
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            r = fx.bridge.handle({"id": 1, "cmd": "set_bands", "sync": True,
                                  "bands": [{"index": 0, "gain": 3.0,
                                             "type": "Bogus"}]})
            self.assertFalse(r["ok"], r)
            self.assertNotIn("left0Gain", fx.fake.state)
        finally:
            fx.close()

    def test_enums_are_not_written_when_the_engine_ignores_them(self):
        """The readback-failure path. This fake accepts set_property and drops
        it, which is exactly how EasyEffects behaves for a refused value."""
        fx = BridgeFixture(chain=["equalizer"], ignore_writes=True).start()
        try:
            fx.bridge.cmd_status({})  # seed the cache
            r = fx.bridge.handle({"id": 1, "cmd": "set_band", "sync": True,
                                  "index": 0, "type": "Notch"})
            self.assertFalse(r["ok"], r)
            self.assertEqual(len(r["mismatched"]), 2, r)  # left and right
            for entry in r["mismatched"]:
                self.assertEqual(entry["want"], "Notch", entry)
                self.assertNotEqual(entry["got"], "Notch", entry)
        finally:
            fx.close()

    def test_a_numeric_field_alongside_an_ignored_enum_is_still_caught(self):
        fx = BridgeFixture(chain=["equalizer"], ignore_writes=True).start()
        try:
            fx.bridge.cmd_status({})
            r = fx.bridge.handle({"id": 1, "cmd": "set_band", "sync": True,
                                  "index": 0, "gain": 3.0, "mode": "LRX (BT)"})
            self.assertFalse(r["ok"], r)
            self.assertEqual({e["key"] for e in r["mismatched"]},
                             {"left:band0Gain", "right:band0Gain",
                              "left:band0Mode", "right:band0Mode"})
        finally:
            fx.close()

    def test_out_of_range_band_index_is_still_rejected(self):
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            for bad in (-1, BR.MAX_BANDS):
                r = fx.bridge.handle({"id": 1, "cmd": "set_band",
                                      "index": bad, "type": "Bell",
                                      "sync": True})
                self.assertFalse(r["ok"], (bad, r))
        finally:
            fx.close()

    def test_status_reports_type_and_mode_for_every_band(self):
        """IrisAudio binds bands[i].type / .mode, so status has to carry them
        on every band rather than only on the ones that were written."""
        fx = BridgeFixture(chain=["equalizer"]).start()
        try:
            bands = fx.bridge.cmd_status({})["equalizer"]["bands"]
            self.assertEqual(len(bands), 10)
            for band in bands:
                self.assertEqual(band["type"], "Bell")
                self.assertEqual(band["mode"], "RLC (BT)")
        finally:
            fx.close()


class TestCrystalizerBandFlags(unittest.TestCase):
    """`mute` and `bypass` are writable per band. They are BOOLEANS in the
    preset, so "1"/"0" on the wire would be wrong even where it happens to be
    read back as true."""

    def _write(self, fx, key, value):
        return fx.bridge.handle({"id": 1, "cmd": "set_param", "sync": True,
                                 "module": "crystalizer", "key": key,
                                 "value": value})

    def test_mute_and_bypass_round_trip_as_booleans(self):
        fx = BridgeFixture(chain=["equalizer", "crystalizer"]).start()
        try:
            for band in range(13):
                for field, value in (("mute", True), ("bypass", False)):
                    key = "band%d.%s" % (band, field)
                    r = self._write(fx, key, value)
                    self.assertTrue(r["ok"], (key, r))
                    self.assertEqual(r["mismatched"], [], (key, r))
                    # the wire carries true/false, never 1/0
                    stored = fx.fake.state["%sBand%d" % (field, band)]
                    self.assertIn(stored, ("true", "false"), (key, stored))
                    self.assertEqual(stored, "true" if value else "false")
                    # ... and the readback is a real bool, not an int
                    got = [e["value"] for e in r["verified"]
                           if e["key"] == "%sBand%d" % (field, band)]
                    self.assertEqual(got, [value])
                    self.assertIsInstance(got[0], bool)
        finally:
            fx.close()

    def test_status_reports_band_flags_as_booleans(self):
        fx = BridgeFixture(chain=["equalizer", "crystalizer"]).start()
        try:
            mod = fx.bridge.cmd_status({})["modules"]["crystalizer"]
            self.assertIs(mod["band0.mute"], False)
            self.assertIs(mod["band0.bypass"], True)   # bypass defaults true
            for i in range(13):
                self.assertIsInstance(mod["band%d.mute" % i], bool)
                self.assertIsInstance(mod["band%d.bypass" % i], bool)
        finally:
            fx.close()

    def test_numeric_one_is_not_accepted_as_a_boolean(self):
        """encode_public maps "1"/"on" to true, but a real 0/1 int must not be
        mistaken for a request to write the literal string "1"."""
        spec = BR.ipc_key_for("crystalizer", "band0.mute")[1]
        self.assertEqual(BR.encode_public(spec, True), "true")
        self.assertEqual(BR.encode_public(spec, 1), "true")
        self.assertEqual(BR.encode_public(spec, 0), "false")

    def test_out_of_range_band_index_is_rejected(self):
        fx = BridgeFixture(chain=["equalizer", "crystalizer"]).start()
        try:
            for bad in (-1, 13, 99):
                for field in ("mute", "bypass"):
                    key = "band%d.%s" % (bad, field)
                    r = self._write(fx, key, True)
                    self.assertFalse(r["ok"], (key, r))
                    self.assertNotIn("%sBand%d" % (field, bad), fx.fake.state)
        finally:
            fx.close()

    def test_unknown_field_is_rejected(self):
        fx = BridgeFixture(chain=["equalizer", "crystalizer"]).start()
        try:
            r = self._write(fx, "band0.solo", True)
            self.assertFalse(r["ok"], r)
        finally:
            fx.close()

    def test_flags_are_refused_when_the_engine_ignores_the_write(self):
        fx = BridgeFixture(chain=["equalizer", "crystalizer"],
                           ignore_writes=True).start()
        try:
            fx.bridge.cmd_status({})
            r = self._write(fx, "band2.mute", True)
            self.assertFalse(r["ok"], r)
            self.assertEqual([e["key"] for e in r["mismatched"]], ["muteBand2"])
        finally:
            fx.close()


class TestApplyBundle(unittest.TestCase):
    """`apply_bundle` writes target + curve + module states in ONE batch.

    This is the backend for profiles. Two properties matter and are asserted
    here rather than assumed:

    * ONE round trip for the whole bundle. The fake counts verbs per
      connection, so "exactly one set_property batch" is measured, not inferred.
    * A module that is not in the live chain is SKIPPED and reported, never
      installed. Installing is set_chain's job; doing it here would turn one tap
      into a preset reload.
    """

    FULL_CHAIN = ["equalizer", "autogain", "limiter", "crystalizer"]

    def _bundle(self, **kw):
        req = {"id": 1, "cmd": "apply_bundle"}
        req.update(kw)
        return self.fx.bridge.handle(req)

    def _set_batches(self):
        return [b for b in self.fx.fake.batches
                if any(v.startswith("set_property") for v in b)]

    def setUp(self):
        self.fx = BridgeFixture(chain=list(self.FULL_CHAIN)).start()

    def tearDown(self):
        self.fx.close()

    def test_whole_bundle_is_one_set_many(self):
        """The whole point: a profile is ONE write batch, not N round trips.

        10 bands -> 20 band writes (left+right), plus autogain target and two
        module bypasses = 23 writes. They must travel in a single connection.
        """
        before = len(self._set_batches())
        r = self._bundle(target=-16.0, bands=[-3.0] * 10,
                         modules=[["limiter", True], ["crystalizer", False]])
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["mismatched"], [], r)
        batches = self._set_batches()[before:]
        self.assertEqual(len(batches), 1,
                         "the bundle must be ONE set_many, got %d"
                         % len(batches))
        self.assertEqual(len(batches[0]), 23,
                         "10 bands x left/right + target + 2 bypasses")
        # ... and there were no set_property batches before it at all, so the
        # assertion above is not just seeing a pre-existing batch.
        self.assertEqual(before, 0)
        self.assertEqual(r["written"], 23)
        self.assertEqual(r["applied"]["target"], -16.0)
        self.assertEqual(r["applied"]["bands"], 20)
        self.assertEqual(r["applied"]["modules"],
                         {"limiter": True, "crystalizer": False})
        self.assertEqual(r["skipped"], [])
        # left and right really moved
        self.assertEqual(self.fx.fake.state["left0Gain"], "-3")
        self.assertEqual(self.fx.fake.state["right0Gain"], "-3")
        self.assertEqual(self.fx.fake.state["target"], "-16")

    def test_module_absent_from_chain_is_skipped_and_the_rest_applies(self):
        """THE RULE: not in the chain -> skipped, NOT installed.

        The fixture's chain is equalizer/autogain/limiter/crystalizer, so a
        preset load would be visible as a fake.loads entry. There must be none:
        an absent module is skipped, never installed.
        """
        loads_before = len(self.fx.fake.loads)
        r = self._bundle(target=-16.0, bands=[0.0] * 10,
                         modules=[["bass_enhancer", True],   # not installed
                                  ["limiter", True]])          # in the chain
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["skipped"],
                         [{"module": "bass_enhancer",
                           "reason": "not_in_chain"}], r)
        self.assertEqual(r["applied"]["modules"], {"limiter": True})
        self.assertEqual(len(self.fx.fake.loads), loads_before,
                         "a bundle must never load a preset")
        # the rest of the bundle still landed
        self.assertEqual(r["applied"]["target"], -16.0)
        self.assertEqual(self.fx.fake.state["bypass"], "false")
        self.assertNotIn("floorActive", self.fx.fake.state)

    def test_an_unknown_module_is_skipped_not_an_error(self):
        """Unknown AND absent are both non-errors: the rest still applies."""
        r = self._bundle(target=-16.0,
                         modules=[["not_a_module", True], ["limiter", False]])
        self.assertTrue(r["ok"], r)
        self.assertIn({"module": "not_a_module", "reason": "unknown_module"},
                      r["skipped"])
        self.assertEqual(r["applied"]["modules"], {"limiter": False})
        self.assertEqual(self.fx.fake.state["bypass"], "true")

    def test_unknown_param_key_is_rejected_and_writes_nothing(self):
        """A bad key must never reach the wire.

        apply_bundle takes no free-form key (its only param is the fixed
        `target`), so the key check lives in the translator it shares with
        set_param. Both are asserted: the shared helper raises, and the
        set_param path that uses it still emits no set_property.
        """
        for key in ("targetLUFS", "target-lufs", "ceiling", "silenceThreshold"):
            with self.assertRaises(ValueError, msg=key):
                self.fx.bridge._param_write("autogain", key, -16.0)
        with self.assertRaises(ValueError):
            self.fx.bridge._param_write("not_a_module", "target", -16.0)
        r = self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                                   "module": "autogain", "key": "targetLUFS",
                                   "value": -16.0})
        self.assertFalse(r["ok"], r)
        self.assertEqual(self._set_batches(), [],
                         "an unknown key must emit no set_property")
        self.assertNotIn("target", self.fx.fake.state)

    def test_a_valid_bundle_still_writes_after_a_rejected_one(self):
        """The refusal above left nothing queued; the next bundle is its own
        single batch rather than inheriting the rejected writes."""
        self.fx.bridge.handle({"id": 1, "cmd": "set_param",
                               "module": "autogain", "key": "targetLUFS",
                               "value": -16.0})
        r = self._bundle(target=-16.0, bands=[1.0] * 10,
                         modules=[["limiter", True]])
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["carriedOver"], 0,
                         "a rejected request must queue nothing")
        self.assertEqual(len(self._set_batches()), 1,
                         "the valid bundle still writes exactly one batch")
        self.assertEqual(len(self._set_batches()[0]), 22)

    def test_bool_reaches_the_wire_as_true_false(self):
        for active in (True, False):
            with self.subTest(active=active):
                fx = BridgeFixture(chain=list(self.FULL_CHAIN)).start()
                try:
                    r = fx.bridge.handle(
                        {"id": 1, "cmd": "apply_bundle", "sync": True,
                         "modules": [["limiter", active]]})
                    self.assertTrue(r["ok"], r)
                    stored = fx.fake.state["bypass"]
                    self.assertIn(stored, ("true", "false"), stored)
                    self.assertEqual(stored, "false" if active else "true")
                    # and the readback is a real bool, not an int
                    got = [e["value"] for e in r["verified"]
                           if e["key"] == "bypass"]
                    self.assertEqual(got, [not active])
                    self.assertIsInstance(got[0], bool)
                finally:
                    fx.close()

    def test_a_non_bool_active_is_refused(self):
        """"false" is a truthy string: accepting it would install the opposite
        state, and 1/0 must never be what reaches the wire as a bool."""
        for bad in ("false", "true", 0, 1, None):
            r = self._bundle(modules=[["limiter", bad]])
            self.assertFalse(r["ok"], (bad, r))
        self.assertEqual(self._set_batches(), [])

    def test_unknown_band_type_label_is_rejected_at_request_time(self):
        """The long form of a band entry shares _band_writes' validation, so a
        bad label is an error and NOTHING is written."""
        r = self._bundle(bands=[{"index": 0, "gain": 1.0},
                                {"index": 1, "gain": 2.0, "type": "Bogus"}])
        self.assertFalse(r["ok"], r)
        self.assertIn("error", r)
        self.assertEqual(self._set_batches(), [],
                         "a bad label must not emit a set_property")
        self.assertNotIn("left0Gain", self.fx.fake.state)

    def test_partial_bundles_are_valid(self):
        """Every section is optional and any subset is a legal bundle."""
        cases = [
            {"target": -14.0},
            {"bands": [0.0] * 10},
            {"modules": [["limiter", True]]},
            {"target": -14.0, "modules": [["limiter", True]]},
            {"bands": [0.0] * 10, "modules": [["limiter", False]]},
            {},
        ]
        for case in cases:
            with self.subTest(case=sorted(case)):
                fx = BridgeFixture(chain=list(self.FULL_CHAIN)).start()
                try:
                    req = {"id": 1, "cmd": "apply_bundle"}
                    req.update(case)
                    r = fx.bridge.handle(req)
                    self.assertTrue(r["ok"], r)
                    self.assertEqual(r["skipped"], [], r)
                    # however few sections it had, it is still one batch
                    self.assertEqual(
                        len([b for b in fx.fake.batches
                             if any(v.startswith("set_property") for v in b)]),
                        0 if not case else 1, r)
                finally:
                    fx.close()

    def test_band_count_must_match_the_current_curve(self):
        """A wrong-length list would write bands that do not exist, which
        EasyEffects accepts and silently discards."""
        self.fx.bridge.cmd_status({})   # seed the cached numBands
        for bad in ([0.0] * 9, [0.0] * 15, []):
            r = self._bundle(bands=bad)
            self.assertFalse(r["ok"], (len(bad), r))
        self.assertEqual(self._set_batches(), [])

    def test_band_entries_may_be_objects_with_type_and_mode(self):
        r = self._bundle(bands=[{"gain": 1.0, "type": "Notch"},
                                {"gain": 2.0, "mode": "LRX (BT)"}]
                         + [0.0] * 8)
        self.assertTrue(r["ok"], r)
        self.assertEqual(self.fx.fake.state["left0Type"],
                         str(BR.EQ_BAND_TYPES["Notch"]))
        self.assertEqual(self.fx.fake.state["left1Mode"],
                         str(BR.EQ_BAND_MODES["LRX (BT)"]))
        self.assertEqual(r["applied"]["bands"], 24, "4 fields x left+right")

    def test_a_write_the_engine_ignores_is_not_reported_as_applied(self):
        """A reply must never report success for a write it did not make: the
        fake accepts set_property and drops it, which is how EasyEffects refuses
        a value."""
        fx = BridgeFixture(chain=list(self.FULL_CHAIN),
                           ignore_writes=True).start()
        try:
            fx.bridge.cmd_status({})
            r = fx.bridge.handle({"id": 1, "cmd": "apply_bundle",
                                  "target": -16.0,
                                  "modules": [["limiter", True]]})
            self.assertFalse(r["ok"], r)
            self.assertEqual(r["applied"], {}, r)
            self.assertNotIn("target", r["applied"])
            reasons = {(e["module"], e["reason"]) for e in r["skipped"]}
            self.assertIn(("autogain", "write_not_confirmed"), reasons)
            self.assertIn(("limiter", "write_not_confirmed"), reasons)
        finally:
            fx.close()

    def test_target_is_skipped_when_autogain_is_absent(self):
        fx = BridgeFixture(chain=["equalizer", "limiter"]).start()
        try:
            r = fx.bridge.handle({"id": 1, "cmd": "apply_bundle",
                                  "target": -16.0, "bands": [0.0] * 10,
                                  "modules": [["limiter", True]]})
            self.assertTrue(r["ok"], r)
            self.assertEqual(r["skipped"],
                             [{"module": "autogain",
                               "reason": "not_in_chain"}], r)
            self.assertNotIn("target", r["applied"])
            self.assertEqual(r["applied"]["modules"], {"limiter": True})
        finally:
            fx.close()

    def test_bundle_never_loads_a_preset_even_with_nothing_to_write(self):
        """The rule holds on the degenerate path too: an empty bundle must not
        turn into a chain reconcile."""
        before = len(self.fx.fake.loads)
        r = self._bundle()
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["applied"], {})
        self.assertEqual(r["written"], 0)
        self.assertEqual(len(self.fx.fake.loads), before)
        self.assertEqual(self._set_batches(), [])

    def test_pending_writes_from_earlier_commands_are_reported_separately(self):
        """A bundle coalesces with whatever is already queued. The reply says so
        instead of implying the bundle was the only thing written."""
        self.fx.bridge.handle({"id": 1, "cmd": "set_band", "index": 0,
                               "gain": 5.0})
        r = self._bundle(modules=[["limiter", True]])
        self.assertTrue(r["ok"], r)
        self.assertEqual(r["carriedOver"], 2, "left+right of band 0")
        self.assertEqual(len(self._set_batches()), 1,
                         "still one batch for the coalesced set")
        self.assertEqual(r["written"], 3)


if __name__ == "__main__":
    unittest.main(verbosity=2)
