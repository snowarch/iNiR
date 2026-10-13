#!/usr/bin/env python3
"""Adapt the iNiR shell to NixOS at build time.

iNiR targets Arch: it looks for icons under /usr/share/icons, shells out to
/usr/bin/find, and only knows how to find its own payload from a handful of
system paths. NixOS has none of those.

These edits are deliberately written as regex rewrites rather than a diff with
context, because a context patch stops applying the moment upstream touches an
adjacent line — that is exactly what broke the previous build. Each rewrite is
idempotent and self-skipping: if upstream ever ships the same fix, this notices
and leaves the file alone instead of failing the build.
"""

import os
import re
import sys

# Everything the store mounts for the running system. Populated by the NixOS
# module, which symlinks /usr/share/icons and /usr/share/quickshell here.
NIXOS_STORE = "/run/current-system/sw"


def apply(text, name, pattern, replacement, *, already, required=True, flags=re.M):
    """Rewrite `pattern` once. Skip cleanly when `already` shows it is applied."""
    if re.search(already, text, flags):
        print(f"  = {name}: already applied upstream, leaving as-is")
        return text, True

    new_text, count = re.subn(pattern, replacement, text, flags=flags)
    if count == 0:
        print(f"  ! {name}: no match")
        if required:
            print(
                f"postpatch: '{name}' is required for a working NixOS build but "
                f"upstream no longer matches it. Re-anchor this regex in "
                f"nix/nixos-postpatch.py."
            )
            sys.exit(1)
        return text, False

    print(f"  + {name}")
    return new_text, True


def patch_icon_theme(text):
    """Icon themes must resolve on NixOS, where the icon theme lives in the store."""
    # For every "~/.local/share/icons/<theme>/<rest>" entry, add the ~/.icons and
    # the system-store equivalents; likewise for the /usr/share one.
    def expand_home(match):
        indent, rest = match.group(1), match.group(2)
        return (
            match.group(0)
            + f"\n{indent}`file://${{home}}/.icons/${{theme}}/{rest}`,"
            + f"\n{indent}`file://{NIXOS_STORE}/share/icons/${{theme}}/{rest}`,"
        )

    text, _ = apply(
        text,
        "IconThemeService: ~/.icons + system store search paths",
        r"^([ \t]*)`file://\$\{home\}/\.local/share/icons/\$\{theme\}/([^`]+)`,[ \t]*$",
        expand_home,
        already=r"`file://\$\{home\}/\.icons/\$\{theme\}/",
        flags=re.M,
    )

    # 48x48 is what many distro themes ship at; without it icons fall back to a
    # generic glyph.
    if "`48x48/apps/${iconName}.svg`" not in text:
        entries = []
        for suffix in ("svg", "png"):
            for root in (
                f"file://${{home}}/.local/share/icons/${{theme}}",
                f"file://${{home}}/.icons/${{theme}}",
                f"file://{NIXOS_STORE}/share/icons/${{theme}}",
                "file:///usr/share/icons/${theme}",
            ):
                entries.append(f"            `{root}/48x48/apps/${{iconName}}.{suffix}`,")
        block = "\n".join(entries)
        text, _ = apply(
            text,
            "IconThemeService: 48x48 icon entries",
            r"^([ \t]*`file:///usr/share/icons/\$\{theme\}/256x256/apps/\$\{iconName\}\.png`,[ \t]*)$",
            rf"\1\n{block}",
            already=r"`48x48/apps/\$\{iconName\}\.svg`",
            required=False,
        )

    # `find` must come from PATH, and it has to walk the store icon directory too.
    # -xtype follows symlinks, which is how /usr/share/icons reaches the store.
    text, _ = apply(
        text,
        "IconThemeService: find-based theme scan",
        re.escape('            "/usr/bin/find",\n')
        + re.escape('            "/usr/share/icons",\n')
        + re.escape("            `${FileUtils.trimFileProtocol(Directories.home)}/.local/share/icons`,\n")
        + re.escape('            "-maxdepth",\n')
        + re.escape('            "1",\n')
        + re.escape('            "-type",\n')
        + re.escape('            "d"'),
        "\n".join(
            [
                '            "find",',
                "            `${FileUtils.trimFileProtocol(Directories.home)}/.local/share/icons`,",
                "            `${FileUtils.trimFileProtocol(Directories.home)}/.icons`,",
                f'            "{NIXOS_STORE}/share/icons",',
                '            "/usr/share/icons",',
                '            "-maxdepth",',
                '            "1",',
                '            "-mindepth",',
                '            "1",',
                '            "-xtype",',
                '            "d"',
            ]
        ),
        already=r'"-xtype",',
        required=False,
    )

    # NOTE: an earlier revision also forced the theme list to be rescanned at the top of
    # ensureInitialized(), before the `_initialized` guard. Upstream 2.33.0 already
    # rescans it once per initialization, and the Process chains run
    # listThemesProc -> gsettingsSetProc -> kdeGlobalsUpdateProc -> kwriteconfigProc.
    # Restarting that chain before the guard made every call re-fire it, which fought
    # the shell during a family switch. Upstream's own single refresh is left alone.

    return text


def patch_family_transition(text):
    """Let the animated family transition run on Qt 6.11, behind an opt-in.

    Qt 6.11 can segfault while tearing down layer-shell surfaces, so upstream
    skips the animated family transition there and restarts the shell instead.
    That is the right default, but it means the transition never plays on the
    Qt that nixpkgs currently ships (6.11.2), so the family switch just blinks.

    Gating the guard behind an env var keeps opting in a config change rather
    than a patch, and records what was traded away.
    """
    text, _ = apply(
        text,
        "shell.qml: make the Qt 6.11 family-transition bail-out opt-in",
        re.escape(
            "        const qt611LayerShellRisk = Quickshell.hasQtVersion(6, 11)\n"
            "            && !Quickshell.hasQtVersion(6, 12)\n"
        ),
        '        const qt611LayerShellRisk = '
        'Quickshell.env("INIR_FAMILY_ANIMATION_ON_QT611") !== "1"\n'
        "            && Quickshell.hasQtVersion(6, 11)\n"
        "            && !Quickshell.hasQtVersion(6, 12)\n",
        already=r"INIR_FAMILY_ANIMATION_ON_QT611",
        required=False,
    )
    return text


def patch_launcher(text):
    """The launcher must find its payload inside the read-only store."""
    text, _ = apply(
        text,
        "scripts/inir: system store payload fallback",
        re.escape(
            '    for candidate in "$user_config_dir" "$system_config_dir" '
            '"$fallback_system_config_dir"; do'
        ),
        "    for candidate in \"$user_config_dir\" \"$system_config_dir\" "
        '"$fallback_system_config_dir" '
        f'"{NIXOS_STORE}/share/quickshell/inir"; do',
        already=re.escape(f'"{NIXOS_STORE}/share/quickshell/inir"; do'),
    )
    return text


def patch_record_script(text):
    """Probe hardware video encoders before selecting them, avoiding failed VAAPI startup.

    Upstream detects VAAPI support merely by checking if a render device exists
    and ffmpeg lists h264_vaapi. In VMs and systems without functional VAAPI
    drivers, wf-recorder fails immediately upon launch with 'Failed to initialise
    VAAPI connection', forcing an error notification ('Preferred encoder failed,
    retrying with safe mode') before falling back to libx264.

    By probing actual encoder functionality via a lightweight 0.05s test command,
    we cleanly select libx264 as preferred on non-VAAPI hardware and never trigger
    the fallback failure notification.
    """
    original_detect = """detect_hw_video_codec() {
    # Nvidia: skip VAAPI (unreliable even if ffmpeg lists it), go straight to NVENC
    if is_nvidia_gpu; then
        if has_ffmpeg_encoder h264_nvenc; then
            printf '%s\\n' 'h264_nvenc'
            return
        fi
        if has_ffmpeg_encoder hevc_nvenc; then
            printf '%s\\n' 'hevc_nvenc'
            return
        fi
    fi
    # AMD/Intel: try VAAPI (needs render device)
    if [[ -n "$HARDWARE_DEVICE" && -c "$HARDWARE_DEVICE" ]]; then
        if has_ffmpeg_encoder h264_vaapi; then
            printf '%s\\n' 'h264_vaapi'
            return
        fi
        if has_ffmpeg_encoder hevc_vaapi; then
            printf '%s\\n' 'hevc_vaapi'
            return
        fi
    fi
    # Fallback: try NVENC anyway (hybrid GPU setups)
    if has_ffmpeg_encoder h264_nvenc; then
        printf '%s\\n' 'h264_nvenc'
        return
    fi
    printf '%s\\n' 'libx264'
}"""

    replacement_detect = """can_test_encoder() {
    local codec="$1"
    local dev="${2:-}"
    if [[ "$codec" == *"_vaapi" ]]; then
        [[ -n "$dev" && -c "$dev" ]] || return 1
        ffmpeg -loglevel error -f lavfi -i color=c=black:s=64x64:d=0.04 -vaapi_device "$dev" -vf 'format=nv12,hwupload' -c:v "$codec" -f null - >/dev/null 2>&1
    elif [[ "$codec" == *"_nvenc" ]]; then
        ffmpeg -loglevel error -f lavfi -i color=c=black:s=64x64:d=0.04 -c:v "$codec" -f null - >/dev/null 2>&1
    else
        has_ffmpeg_encoder "$codec"
    fi
}

detect_hw_video_codec() {
    # Nvidia: skip VAAPI (unreliable even if ffmpeg lists it), go straight to NVENC
    if is_nvidia_gpu; then
        if can_test_encoder h264_nvenc; then
            printf '%s\\n' 'h264_nvenc'
            return
        fi
        if can_test_encoder hevc_nvenc; then
            printf '%s\\n' 'hevc_nvenc'
            return
        fi
    fi
    # AMD/Intel: try VAAPI (needs verified working render device)
    if [[ -n "$HARDWARE_DEVICE" && -c "$HARDWARE_DEVICE" ]]; then
        if can_test_encoder h264_vaapi "$HARDWARE_DEVICE"; then
            printf '%s\\n' 'h264_vaapi'
            return
        fi
        if can_test_encoder hevc_vaapi "$HARDWARE_DEVICE"; then
            printf '%s\\n' 'hevc_vaapi'
            return
        fi
    fi
    # Fallback: try NVENC anyway (hybrid GPU setups)
    if can_test_encoder h264_nvenc; then
        printf '%s\\n' 'h264_nvenc'
        return
    fi
    printf '%s\\n' 'libx264'
}"""

    text, _ = apply(
        text,
        "scripts/videos/record.sh: probe hardware encoder before selecting",
        re.escape(original_detect),
        replacement_detect,
        already=r"can_test_encoder\(\)",
        required=False,
    )

    vaapi_guard = """if is_vaapi_codec "$VIDEO_CODEC"; then
    if ! can_test_encoder "$VIDEO_CODEC" "$HARDWARE_DEVICE"; then
        VIDEO_CODEC="libx264"
    fi"""

    text, _ = apply(
        text,
        "scripts/videos/record.sh: validate configured VAAPI codec before launch",
        re.escape('if is_vaapi_codec "$VIDEO_CODEC"; then'),
        vaapi_guard,
        already=r'if ! can_test_encoder "\$VIDEO_CODEC"',
        required=False,
    )

    return text


def patch_root_qml():

    """Strip /usr/bin/ from QML and JS anywhere in the tree.

    package.nix already rewrites these paths, but only under
    modules/, services/, defaults/ and scripts/. The top-level QML
    (killDialog.qml, welcome.qml) sits outside those directories and would
    keep absolute /usr/bin/pidof, /usr/bin/killall and /usr/bin/notify-send,
    none of which exist on NixOS.

    Shebangs are untouched because .qml and .js files never carry one.
    """
    changed = []
    for dirpath, _dirnames, filenames in os.walk("."):
        if "/.git" in dirpath:
            continue
        for filename in filenames:
            if not filename.endswith((".qml", ".js")):
                continue
            path = os.path.join(dirpath, filename)
            with open(path, encoding="utf-8") as handle:
                original = handle.read()
            patched = original.replace("/usr/bin/", "")
            if patched != original:
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(patched)
                changed.append(path)

    print(
        f"  + /usr/bin/ stripped from {len(changed)} top-level QML/JS file(s)"
        if changed
        else "  = /usr/bin/ in QML/JS: already handled upstream, leaving as-is"
    )
    return changed


def patch_iris_morph_surface(text):
    """Make iris morph surface animations fluid: reduce warmup delay, improve settle dynamics and fade."""
    text, _ = apply(
        text,
        "modules/iris/components/IrisMorphSurface.qml: adaptive content fade on settle",
        re.escape("    property real contentFadeStart: IrisStyle.contentRise\n    property real contentFadeSpan: IrisStyle.contentSpan"),
        "    property real contentFadeStart: root.settles ? 0.0 : IrisStyle.contentRise\n    property real contentFadeSpan: root.settles ? 0.6 : IrisStyle.contentSpan",
        already=r"contentFadeStart: root\.settles",
        required=False,
    )

    text, _ = apply(
        text,
        "modules/iris/components/IrisMorphSurface.qml: settleShare 0.92 and settleCut 0.04",
        re.escape("    readonly property real settleShare: 0.95\n    readonly property real settleCut: 0.4"),
        "    readonly property real settleShare: 0.92\n    readonly property real settleCut: 0.04",
        already=r"settleShare: 0\.92",
        required=False,
    )

    text, _ = apply(
        text,
        "modules/iris/components/IrisMorphSurface.qml: reduce warmup interval from 90ms to 16ms",
        re.escape("    Timer { interval: 90; running: root.armed && !root.launched; onTriggered: root.launched = true }"),
        "    Timer { interval: 16; running: root.armed && !root.launched; onTriggered: root.launched = true }",
        already=r"interval: 16",
        required=False,
    )

    text, _ = apply(
        text,
        "modules/iris/components/IrisMorphSurface.qml: warmup arm launch on next tick",
        re.escape("            root.launchFrames = 0\n        }\n        root.armed = true"),
        "            root.launchFrames = 0\n            Qt.callLater(() => { if (root.armed && !root.launched) root.launched = true })\n        }\n        root.armed = true",
        already=r"root\.launched = true \}\)\n        \}\n        root\.armed = true",
        required=False,
    )

    text, _ = apply(
        text,
        "modules/iris/components/IrisMorphSurface.qml: drops exclude settles",
        re.escape("    readonly property bool drops: IrisStyle.revealDrops && !root.contentTravels\n"),
        "    readonly property bool drops: IrisStyle.revealDrops && !root.contentTravels && !root.settles\n",
        already=r"drops: IrisStyle\.revealDrops && !root\.contentTravels && !root\.settles",
        required=False,
    )
    return text


def patch_iris_palette(text):
    """Ensure IrisPalette opens smoothly and without clipboard mode lag or height jumps."""
    text, _ = apply(
        text,
        "modules/iris/palette/IrisPalette.qml: immediate prefix detection for clipboard and action modes",
        re.escape("    readonly property bool browsing: root.settled.length === 0"),
        "    readonly property bool browsing: (LauncherSearch.query.length === 0)",
        already=r"readonly property bool browsing: \(LauncherSearch\.query\.length === 0\)",
        required=False,
    )

    text, _ = apply(
        text,
        "modules/iris/palette/IrisPalette.qml: immediate clipboardMode on query prefix",
        re.escape("    readonly property bool clipboardMode: root.settled.startsWith(root.clipboardPrefix)"),
        "    readonly property bool clipboardMode: (root.settled.length > 0 ? root.settled : LauncherSearch.query).startsWith(root.clipboardPrefix)",
        already=r"readonly property bool clipboardMode: \(root\.settled\.length > 0",
        required=False,
    )

    text, _ = apply(
        text,
        "modules/iris/palette/IrisPalette.qml: immediate actionMode on query prefix",
        re.escape("    readonly property bool actionMode: root.settled.startsWith(root.actionPrefix)"),
        "    readonly property bool actionMode: (root.settled.length > 0 ? root.settled : LauncherSearch.query).startsWith(root.actionPrefix)",
        already=r"readonly property bool actionMode: \(root\.settled\.length > 0",
        required=False,
    )

    text, _ = apply(
        text,
        "modules/iris/palette/IrisPalette.qml: smoother shadow opacity and settles respects fromIsland",
        re.escape("                opacity: IrisStyle.shadowAt(surface.progress)\n            }\n            IrisMorphSurface {\n                id: surface\n                compositorBlurred: true\n                open: root.here && GlobalStates.searchOpen\n                settles: true"),
        "                opacity: Math.pow(Math.max(0, Math.min(1, surface.progress)), 1.8)\n            }\n            IrisMorphSurface {\n                id: surface\n                compositorBlurred: true\n                open: root.here && GlobalStates.searchOpen\n                settles: !root.fromIsland",
        already=r"settles: !root\.fromIsland",
        required=False,
    )

    text, _ = apply(
        text,
        "modules/iris/palette/IrisPalette.qml: animate height whenever open",
        re.escape("                Behavior on height {\n                    enabled: surface.settled\n                    NumberAnimation"),
        "                Behavior on height {\n                    enabled: surface.open\n                    NumberAnimation",
        already=r"enabled: surface\.open\n                    NumberAnimation",
        required=False,
    )
    return text


def patch_launcher_search(text):
    """Instantly settle mode prefixes in LauncherSearch without waiting for 80ms debounce."""
    original_on_query = (
        '    onQueryChanged: {\n'
        '        // Immediate update for empty query (instant clear)\n'
        '        if (query === "") {\n'
        '            _debouncedQuery = ""\n'
        '            debounceTimer.stop()\n'
        '        } else {\n'
        '            debounceTimer.restart()\n'
        '        }\n'
        '    }'
    )
    replacement_on_query = (
        '    onQueryChanged: {\n'
        '        // Immediate update for empty query or single prefix char (instant mode switch)\n'
        '        const prefixes = [\n'
        '            Config.options?.search?.prefix?.action ?? "/",\n'
        '            Config.options?.search?.prefix?.app ?? ">",\n'
        '            Config.options?.search?.prefix?.clipboard ?? ";",\n'
        '            Config.options?.search?.prefix?.emojis ?? ":",\n'
        '            Config.options?.search?.prefix?.math ?? "=",\n'
        '            Config.options?.search?.prefix?.shellCommand ?? "$",\n'
        '            Config.options?.search?.prefix?.webSearch ?? "?",\n'
        '        ]\n'
        '        if (query === "" || (query.length === 1 && prefixes.includes(query))) {\n'
        '            _debouncedQuery = query\n'
        '            debounceTimer.stop()\n'
        '        } else {\n'
        '            debounceTimer.restart()\n'
        '        }\n'
        '    }'
    )
    text, _ = apply(
        text,
        "services/deferred/LauncherSearch.qml: instant prefix debounce handling",
        re.escape(original_on_query),
        replacement_on_query,
        already=r"// Immediate update for empty query or single prefix char",
        required=False,
    )

    original_ensure_prefix = (
        '        if (prefixes.some(p => root.query.startsWith(p))) {\n'
        '            root.query = prefix + root.query.slice(1)\n'
        '        } else {\n'
        '            root.query = prefix + root.query\n'
        '        }\n'
        '    }'
    )
    replacement_ensure_prefix = (
        '        if (prefixes.some(p => root.query.startsWith(p))) {\n'
        '            root.query = prefix + root.query.slice(1)\n'
        '        } else {\n'
        '            root.query = prefix + root.query\n'
        '        }\n'
        '        root._debouncedQuery = root.query\n'
        '        debounceTimer.stop()\n'
        '    }'
    )
    text, _ = apply(
        text,
        "services/deferred/LauncherSearch.qml: ensurePrefix settles debounced query immediately",
        re.escape(original_ensure_prefix),
        replacement_ensure_prefix,
        already=r"root\._debouncedQuery = root\.query\n        debounceTimer\.stop\(\)\n    \}",
        required=False,
    )
    return text


def patch_generate_colors_material(text):
    """Preserve raw seeds before surface/contrast shifting to eliminate iris-seeds cycle."""
    text, _ = apply(
        text,
        "scripts/colors/generate_colors_material.py: capture iris_raw_seeds",
        re.escape('seed_background = material_colors.get("background", "")\nif args.surface_seed'),
        'seed_background = material_colors.get("background", "")\niris_raw_seeds = {k: material_colors.get(k, "") for k in ("primary", "secondary", "tertiary")}\niris_raw_seeds["background"] = seed_background\nif args.surface_seed',
        already=r"iris_raw_seeds = \{k: material_colors\.get\(k",
        required=False,
    )

    text, _ = apply(
        text,
        "scripts/colors/generate_colors_material.py: use iris_raw_seeds in washi_roles",
        re.escape('        seeds = {k: material_colors.get(k, "") for k in ("primary", "secondary", "tertiary")}\n        seeds["background"] = seed_background'),
        '        seeds = iris_raw_seeds',
        already=r"seeds = iris_raw_seeds",
        required=False,
    )
    return text


def patch_switchwall(text):
    """Serialize switchwall executions and use unique PID temp files to prevent race conditions."""
    text, _ = apply(
        text,
        "scripts/colors/switchwall.sh: serialize execution with flock",
        re.escape("main() {\n    imgpath="),
        'main() {\n    # Serialize switchwall execution — prevent concurrent switchwall runs from colliding\n    mkdir -p "$STATE_DIR/user/generated"\n    local _sw_lock="$STATE_DIR/user/generated/switchwall.lock"\n    exec 201>"$_sw_lock"\n    flock -w 10 201 || { echo "[switchwall.sh] lock timeout waiting for running switchwall" >&2; return 0; }\n\n    imgpath=',
        already=r"_sw_lock=\"\$STATE_DIR/user/generated/switchwall\.lock\"",
        required=False,
    )

    text, _ = apply(
        text,
        "scripts/colors/switchwall.sh: PID suffixed temp files",
        re.escape('    _scss_tmp="$STATE_DIR/user/generated/material_colors.scss.tmp"\n    _json_tmp="$STATE_DIR/user/generated/colors.json.tmp"\n    _json_out="$STATE_DIR/user/generated/colors.json"\n    _palette_tmp="$STATE_DIR/user/generated/palette.json.tmp"\n    _palette_out="$STATE_DIR/user/generated/palette.json"\n    _app_palette_tmp="$STATE_DIR/user/generated/app-palette.json.tmp"\n    _app_palette_out="$STATE_DIR/user/generated/app-palette.json"\n    _terminal_tmp="$STATE_DIR/user/generated/terminal.json.tmp"\n    _terminal_out="$STATE_DIR/user/generated/terminal.json"\n    _meta_tmp="$STATE_DIR/user/generated/theme-meta.json.tmp"'),
        '    _scss_tmp="$STATE_DIR/user/generated/material_colors.scss.tmp.$$"\n    _json_tmp="$STATE_DIR/user/generated/colors.json.tmp.$$"\n    _json_out="$STATE_DIR/user/generated/colors.json"\n    _palette_tmp="$STATE_DIR/user/generated/palette.json.tmp.$$"\n    _palette_out="$STATE_DIR/user/generated/palette.json"\n    _app_palette_tmp="$STATE_DIR/user/generated/app-palette.json.tmp.$$"\n    _app_palette_out="$STATE_DIR/user/generated/app-palette.json"\n    _terminal_tmp="$STATE_DIR/user/generated/terminal.json.tmp.$$"\n    _terminal_out="$STATE_DIR/user/generated/terminal.json"\n    _meta_tmp="$STATE_DIR/user/generated/theme-meta.json.tmp.$$"',
        already=r"_scss_tmp=\"\$STATE_DIR/user/generated/material_colors\.scss\.tmp\.\$\$\"",
        required=False,
    )

    text, _ = apply(
        text,
        "scripts/colors/switchwall.sh: force terminal PID suffixed temp file",
        re.escape('        _terminal_force_tmp="$STATE_DIR/user/generated/terminal.json.force.tmp"'),
        '        _terminal_force_tmp="$STATE_DIR/user/generated/terminal.json.force.tmp.$$"',
        already=r"_terminal_force_tmp=\"\$STATE_DIR/user/generated/terminal\.json\.force\.tmp\.\$\$\"",
        required=False,
    )
    return text


def patch_theme_service(text):
    """Defer regenerateAutoTheme if wallpaper apply is in progress."""
    text, _ = apply(
        text,
        "services/ThemeService.qml: defer regeneration when apply in progress",
        re.escape('    function regenerateAutoTheme(): void {\n        root._log("[ThemeService] regenerateAutoTheme called");\n        const now = Date.now()'),
        '    function regenerateAutoTheme(): void {\n        root._log("[ThemeService] regenerateAutoTheme called");\n        if (Wallpapers._applyInProgress) {\n            root._log("[ThemeService] regenerateAutoTheme deferred — Wallpapers apply in progress");\n            root._regenPending = true\n            regenCooldownTimer.interval = Math.max(80, root._regenCooldownMs)\n            regenCooldownTimer.restart()\n            return\n        }\n        const now = Date.now()',
        already=r"if \(Wallpapers\._applyInProgress\)",
        required=False,
    )
    return text


def patch_wallpapers(text):
    """Prevent wallpaper transition conflicts and preview glitches."""
    text, _ = apply(
        text,
        "services/Wallpapers.qml: cooldown timestamp update in _runWallpaperScript",
        re.escape('        root._applyInProgress = true\n        _applySuppressTimer.restart()\n        applyProc.activeRequestKey = root._applyRequestKey'),
        '        root._applyInProgress = true\n        _applySuppressTimer.restart()\n        ThemeService._lastRegenTimestamp = Date.now()\n        applyProc.activeRequestKey = root._applyRequestKey',
        already=r"ThemeService\._lastRegenTimestamp = Date\.now\(\)",
        required=False,
    )

    text, _ = apply(
        text,
        "services/Wallpapers.qml: unconditional clear preview in apply awwwBackend",
        re.escape('            Config.setNestedValue("background.thumbnailPath", "")\n            if (adoptedPreview)\n                root._clearInternalPreview()\n            root._queueWallpaperScript'),
        '            Config.setNestedValue("background.thumbnailPath", "")\n            root._clearInternalPreview()\n            root._queueWallpaperScript',
        already=r'Config\.setNestedValue\("background\.thumbnailPath", ""\)\n            root\._clearInternalPreview\(\)\n            root\._queueWallpaperScript',
        required=False,
    )

    text, _ = apply(
        text,
        "services/Wallpapers.qml: unconditional clear preview in apply fallback",
        re.escape('        Config.setNestedValue("background.thumbnailPath", "")\n        if (adoptedPreview)\n            root._clearInternalPreview()\n        root._queueWallpaperScript'),
        '        Config.setNestedValue("background.thumbnailPath", "")\n        root._clearInternalPreview()\n        root._queueWallpaperScript',
        already=r'Config\.setNestedValue\("background\.thumbnailPath", ""\)\n        root\._clearInternalPreview\(\)\n        root\._queueWallpaperScript',
        required=False,
    )

    text, _ = apply(
        text,
        "services/Wallpapers.qml: random fallback to any file",
        re.escape('        const currentPath = Config.options?.background?.wallpaperPath ?? ""\n        const files = []\n        for (let i = 0; i < folderModel.count; ++i) {\n            if (folderModel.get(i, "fileIsDir")) continue\n            const path = folderModel.get(i, "filePath")\n            if (path && path !== currentPath) files.push(path)\n        }\n        if (files.length === 0) return'),
        '        const currentPath = Config.options?.background?.wallpaperPath ?? ""\n        let files = []\n        for (let i = 0; i < folderModel.count; ++i) {\n            if (folderModel.get(i, "fileIsDir")) continue\n            const path = folderModel.get(i, "filePath")\n            if (path && path !== currentPath) files.push(path)\n        }\n        if (files.length === 0) {\n            for (let i = 0; i < folderModel.count; ++i) {\n                if (folderModel.get(i, "fileIsDir")) continue\n                const path = folderModel.get(i, "filePath")\n                if (path) files.push(path)\n            }\n        }\n        if (files.length === 0) return',
        already=r'let files = \[\]',
        required=False,
    )
    return text


def patch_iris_wallpaper_picker(text):
    """Exclude currently selected wallpaper from random candidate pool in picker."""
    pattern = (
        r'([ \t]*)onClicked:\s*\{\s*'
        r'const pick = root\.visibleFiles\[Math\.floor\(Math\.random\(\) \* root\.visibleFiles\.length\)\]\s*'
        r'if \(pick\) root\.apply\(pick\.path, false\)\s*'
        r'\}'
    )
    replacement = (
        r'\1onClicked: {\n'
        r'\1    const current = FileUtils.trimFileProtocol(String(root.currentPath ?? ""))\n'
        r'\1    let candidates = (root.visibleFiles ?? []).filter(entry => entry && entry.path !== current)\n'
        r'\1    if (candidates.length === 0) candidates = root.visibleFiles ?? []\n'
        r'\1    if (candidates.length === 0) return\n'
        r'\1    const pick = candidates[Math.floor(Math.random() * candidates.length)]\n'
        r'\1    if (pick) root.apply(pick.path, false)\n'
        r'\1}'
    )
    text, _ = apply(
        text,
        "modules/iris/wallpaper/IrisWallpaperPicker.qml: random wallpaper exclude current",
        pattern,
        replacement,
        already=r'let candidates = \(root\.visibleFiles',
        required=False,
    )
    return text


def patch_apply_gtk_theme(text):
    """Ensure apply-gtk-theme writes decimal RGB to kdeglobals and adds standard GTK theme aliases."""
    text, _ = apply(
        text,
        "scripts/colors/apply-gtk-theme.sh: add GTK color aliases in GTK3_CSS",
        re.escape('@define-color accent_bg_color ${PRIMARY};\n\n@define-color window_bg_color ${BG};'),
        '@define-color accent_bg_color ${PRIMARY};\n\n/* Standard GTK theme color aliases (used by GTK3 apps, Flutter, LocalSend, etc.) */\n@define-color theme_selected_bg_color ${PRIMARY};\n@define-color theme_selected_fg_color ${ON_PRIMARY};\n@define-color theme_bg_color ${BG};\n@define-color theme_fg_color ${FG};\n@define-color theme_base_color ${BG};\n@define-color theme_text_color ${FG};\n@define-color theme_view_bg_color ${BG};\n@define-color theme_view_fg_color ${FG};\n@define-color theme_unfocused_selected_bg_color ${PRIMARY};\n@define-color theme_unfocused_selected_fg_color ${ON_PRIMARY};\n@define-color theme_unfocused_bg_color ${BG};\n@define-color theme_unfocused_fg_color ${FG};\n@define-color theme_unfocused_base_color ${BG};\n@define-color theme_unfocused_text_color ${FG};\n\n@define-color window_bg_color ${BG};',
        already=r"@define-color theme_selected_bg_color",
        required=False,
    )

    text, _ = apply(
        text,
        "scripts/colors/apply-gtk-theme.sh: add GTK color aliases in GTK4_CSS",
        re.escape('/* CSS custom properties for libadwaita color overrides */\n:root {\n    /* Accent */\n    --accent-bg-color: ${PRIMARY};\n    --accent-fg-color: ${ON_PRIMARY};\n    --accent-color: ${PRIMARY};'),
        '@define-color accent_color ${PRIMARY};\n@define-color accent_fg_color ${ON_PRIMARY};\n@define-color accent_bg_color ${PRIMARY};\n@define-color theme_selected_bg_color ${PRIMARY};\n@define-color theme_selected_fg_color ${ON_PRIMARY};\n@define-color theme_bg_color ${BG};\n@define-color theme_fg_color ${FG};\n@define-color theme_base_color ${BG};\n@define-color theme_text_color ${FG};\n@define-color theme_view_bg_color ${BG};\n@define-color theme_view_fg_color ${FG};\n\n/* CSS custom properties for libadwaita color overrides */\n:root {\n    /* Accent */\n    --accent-bg-color: ${PRIMARY};\n    --accent-fg-color: ${ON_PRIMARY};\n    --accent-color: ${PRIMARY};\n    --theme-selected-bg-color: ${PRIMARY};\n    --theme-selected-fg-color: ${ON_PRIMARY};\n    --theme-bg-color: ${BG};\n    --theme-fg-color: ${FG};\n    --theme-base-color: ${BG};\n    --theme-text-color: ${FG};',
        already=r"--theme-selected-bg-color:",
        required=False,
    )

    text, _ = apply(
        text,
        "scripts/colors/apply-gtk-theme.sh: fallback to adw-gtk3-dark when dark mode preferred",
        re.escape('    prefer_dark=0\n    [[ "$current_scheme" == "prefer-dark" ]] && prefer_dark=1'),
        '    prefer_dark=0\n    [[ "$current_scheme" == "prefer-dark" ]] && prefer_dark=1\n    if [[ "$prefer_dark" -eq 1 && ( -z "$current_theme" || "$current_theme" == "adw-gtk3" || "$current_theme" == "Adwaita" ) ]]; then\n        current_theme="adw-gtk3-dark"\n    fi',
        already=r'current_theme="adw-gtk3-dark"',
        required=False,
    )
    return text


def patch_recognize_music(text):
    """Ensure recognize-music.sh preserves PATH and NixOS store/system binaries."""
    text, _ = apply(
        text,
        "scripts/musicRecognition/recognize-music.sh: preserve PATH and nix store",
        re.escape('PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"'),
        'PATH="${PATH:+$PATH:}/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"',
        already=r'/run/current-system/sw/bin',
        required=False,
    )
    return text


def patch_ytmusic(text):
    """Ensure YtMusic.qml uses /bin/sh instead of /bin/bash on NixOS and robust search checks."""
    yt_pattern = r'(id:\s*_checkAvailability\b[^\n]*\n(?:\s*//[^\n]*\n)*\s*command:\s*\[)"/bin/bash"'
    text, _ = apply(
        text,
        "services/YtMusic.qml: use /bin/sh for _checkAvailability",
        yt_pattern,
        r'\1"/bin/sh"',
        already=r'id:\s*_checkAvailability\b[^\n]*\n(?:\s*//[^\n]*\n)*\s*command:\s*\["/bin/sh"',
        required=False,
    )
    text, _ = apply(
        text,
        "services/YtMusic.qml: use /bin/sh for _detectBrowsersProc",
        re.escape('    Process {\n        id: _detectBrowsersProc\n        command: ["/bin/bash", "-c", `'),
        '    Process {\n        id: _detectBrowsersProc\n        command: ["/bin/sh", "-c", `',
        already=r'id: _detectBrowsersProc\n        command: \["/bin/sh", "-c", `',
        required=False,
    )
    text, _ = apply(
        text,
        "services/YtMusic.qml: resilient search availability check",
        re.escape("    function search(query, filter): void {\n        if (!query.trim() || !root.available) return"),
        "    function search(query, filter): void {\n        if (!query.trim()) return\n        if (!root.available && !InnerTube.available) {\n            if (!_checkAvailability.running) _checkAvailability.running = true\n            return\n        }",
        already=r'!root\.available && !InnerTube\.available',
        required=False,
    )
    text, _ = apply(
        text,
        "services/YtMusic.qml: sync onSearchingChanged in Connections",
        re.escape("        function onSearchResultsChanged() {\n            if (!root._searchViaInnerTube) return\n            root.searchResults = InnerTube.searchResults\n            root.searching = false\n            root._searchViaInnerTube = false\n        }\n        function onRadioTracksChanged() { root._onRadioTracks() }"),
        "        function onSearchResultsChanged() {\n            if (!root._searchViaInnerTube) return\n            root.searchResults = InnerTube.searchResults\n            if (!InnerTube.searching) {\n                root.searching = false\n                root._searchViaInnerTube = false\n            }\n        }\n        function onSearchingChanged() {\n            if (root._searchViaInnerTube) {\n                root.searching = InnerTube.searching\n                if (!InnerTube.searching) {\n                    root.searchResults = InnerTube.searchResults\n                    root._searchViaInnerTube = false\n                }\n            }\n        }\n        function onRadioTracksChanged() { root._onRadioTracks() }",
        already=r'root\.searching = InnerTube\.searching',
        required=False,
    )
    return text


def patch_innertube(text):
    """Ensure InnerTube search recovers and handles errors cleanly."""
    text, _ = apply(
        text,
        "services/deferred/InnerTube.qml: import qs.services",
        re.escape("import qs.modules.common\n"),
        "import qs.modules.common\nimport qs.services\n",
        already=r'import qs\.services',
        required=False,
    )
    text, _ = apply(
        text,
        "services/deferred/InnerTube.qml: reset searching on error in StreamCollector",
        re.escape("            if (obj.error) { root.error = obj.error; return; }"),
        "            if (obj.error) {\n                root.error = obj.error;\n                root.searching = false;\n                buffer = [];\n                return;\n            }",
        already=r'root\.searching = false;\s*buffer = \[\];\s*return;',
        required=False,
    )
    text, _ = apply(
        text,
        "services/deferred/InnerTube.qml: clone buffer on finished",
        re.escape('            if (obj._done) { finished(buffer, lyricsId); buffer = []; lyricsId = ""; return; }'),
        '            if (obj._done) {\n                finished(buffer.slice ? buffer.slice() : buffer, lyricsId);\n                buffer = [];\n                lyricsId = "";\n                return;\n            }',
        already=r'finished\(buffer\.slice',
        required=False,
    )
    text, _ = apply(
        text,
        "services/deferred/InnerTube.qml: clear searchResults and retry availability",
        re.escape('    function search(query, filter): void {\n        if (!query || !root.available) return;\n        root.error = "";\n        root.searching = true;\n        _searchProc.exec([root._runner, "search", query, filter || "songs"]);\n    }'),
        '    function search(query, filter): void {\n        if (!query) return;\n        if (!root.available) {\n            root.retryAvailability();\n            return;\n        }\n        root.error = "";\n        root.searching = true;\n        _searchProc.exec([root._runner, "search", query, filter || "songs"]);\n    }',
        already=r'root\.retryAvailability\(\);',
        required=False,
    )
    text, _ = apply(
        text,
        "services/deferred/InnerTube.qml: handle _searchProc onExited",
        re.escape('    Process {\n        id: _searchProc\n        stdout: StreamCollector { onFinished: (items) => { root.searchResults = items; root.searching = false; } }\n    }'),
        '    Process {\n        id: _searchProc\n        stdout: StreamCollector {\n            onFinished: (items) => {\n                root.searchResults = items;\n                root.searching = false;\n            }\n        }\n        onExited: (code) => {\n            if (code !== 0 && root.searching) {\n                root.searching = false;\n                if (root.searchResults.length === 0 && !root.error) {\n                    root.error = Translation.tr("Search failed. Check your connection.");\n                }\n            }\n        }\n    }',
        already=r'onExited:\s*\(code\)\s*=>\s*\{\s*if\s*\(code !== 0 && root\.searching\)',
        required=False,
    )
    return text


def patch_conflict_killer(text):
    """Auto-kill conflicting notification daemons on NixOS without opening killDialog."""
    target = (
        '        if (conflictingNotifications) {\n'
        '            if (!(Config.options?.conflictKiller?.autoKillNotificationDaemons ?? false)) openDialog = true;\n'
        '            else Quickshell.execDetached(["/usr/bin/killall", "mako", "dunst"])\n'
        '        }'
    )
    replacement = (
        '        if (conflictingNotifications) {\n'
        '            Quickshell.execDetached(["/usr/bin/killall", "mako", "dunst"])\n'
        '        }'
    )
    text, _ = apply(
        text,
        "services/ConflictKiller.qml: auto-kill conflicting notification daemons without popup",
        re.escape(target),
        replacement,
        already=r'Quickshell\.execDetached\(\["/usr/bin/killall", "mako", "dunst"\]\)\n        }',
        required=False,
    )
    return text


def patch_family_transition_overlay(text):
    """Resume reloaded family transition straight into exit without replaying entry chain."""
    target_ft = (
        "    // no timer starts, fadeOut never runs, enterComplete never fires, and a\n"
        "    // fullscreen WlrKeyboardFocus.Exclusive window stays up forever. That is the\n"
        "    // freeze that forces a TTY. Arm on construction too.\n"
        "    Component.onCompleted: if (GlobalStates.familyTransitionActive) root._beginTransition()"
    )
    replacement_ft = (
        "    // no timer starts, fadeOut never runs, enterComplete never fires, and a\n"
        "    // fullscreen WlrKeyboardFocus.Exclusive window stays up forever. That is the\n"
        "    // freeze that forces a TTY. Arm on construction too.\n"
        "    Component.onCompleted: {\n"
        "        if (!GlobalStates.familyTransitionActive) return\n"
        "        if (GlobalStates.familyTransitionTarget.length > 0)\n"
        "            root._resumeIntoExit()\n"
        "        else\n"
        "            root._beginTransition()\n"
        "    }\n\n"
        "    // Once the panels are already swapped and the hold has passed, replaying\n"
        "    // the entry chain only delays the exit and leaves the exclusive-keyboard\n"
        "    // window up for another worst-case interval. Resume straight into the exit.\n"
        "    function _resumeIntoExit(): void {\n"
        "        if (root._phase) return\n"
        "        root._targetFamily = GlobalStates.familyTransitionTarget || \"ii\"\n"
        "        root._isWaffle = root._targetFamily === \"waffle\"\n"
        "        root._isIris = root._targetFamily === \"iris\"\n"
        "        enterTimer.stop(); holdTimer.stop(); contentExitTimer.stop()\n"
        "        fadeIn.stop(); bgScaleIn.stop(); blurIn.stop()\n"
        "        root._phase = true\n"
        "        root._active = true\n"
        "        fadeOut.restart()\n"
        "        bgScaleOut.restart()\n"
        "        watchdog.restart()\n"
        "    }"
    )
    text, _ = apply(
        text,
        "FamilyTransitionOverlay.qml: resume reloaded transition into exit",
        re.escape(target_ft),
        replacement_ft,
        already=r"function _resumeIntoExit\(\): void",
        required=False,
    )
    return text


def patch_washi(text):
    """Probe well-known paths and Nix profiles/store for go binary in washi.sh."""
    target_washi = (
        "if stale; then\n"
        '  go_bin="$(command -v go || true)"\n'
        '  if [[ -z "$go_bin" ]]; then\n'
        '    [[ -x "$bin" ]] || { echo "washi: Go is not installed; iRiS keeps its default palette" >&2; exit 3; }'
    )
    replacement_washi = (
        "if stale; then\n"
        '  go_bin="$(command -v go || true)"\n'
        '  if [[ -z "$go_bin" ]]; then\n'
        '    for candidate in \\\n'
        '      "$HOME/go/bin/go" \\\n'
        '      "$HOME/.local/bin/go" \\\n'
        '      /usr/local/go/bin/go \\\n'
        '      /usr/lib/go/bin/go \\\n'
        '      /usr/bin/go \\\n'
        '      /opt/homebrew/bin/go \\\n'
        '      "$HOME/.nix-profile/bin/go" \\\n'
        '      "/run/current-system/sw/bin/go"; do\n'
        '      if [[ -x "$candidate" ]]; then\n'
        '        go_bin="$candidate"\n'
        '        break\n'
        '      fi\n'
        '    done\n'
        '    if [[ -z "$go_bin" ]]; then\n'
        '      for profile in "$HOME"/.local/state/nix/profiles/profile/bin/go \\\n'
        '        /nix/var/nix/profiles/default/bin/go \\\n'
        '        /nix/var/nix/profiles/per-user/*/profile/bin/go; do\n'
        '        if [[ -x "$profile" ]]; then\n'
        '          go_bin="$profile"\n'
        '          break\n'
        '        fi\n'
        '      done\n'
        '    fi\n'
        '    if [[ -z "$go_bin" ]] && [[ -d "/nix/store" ]]; then\n'
        '      while IFS= read -r store_go; do\n'
        '        if [[ -x "$store_go" ]]; then\n'
        '          go_bin="$store_go"\n'
        '          break\n'
        '        fi\n'
        '      done < <(find /nix/store -maxdepth 4 -path \'*-go-*/bin/go\' -type f 2>/dev/null | sort -r)\n'
        '    fi\n'
        '  fi\n'
        '  if [[ -z "$go_bin" ]]; then\n'
        '    [[ -x "$bin" ]] || { echo "washi: Go is not installed; iRiS keeps its default palette" >&2; exit 3; }'
    )
    text, _ = apply(
        text,
        "scripts/colors/washi.sh: find Go off-PATH in well-known locations and Nix store",
        re.escape(target_washi),
        replacement_washi,
        already=r"/run/current-system/sw/bin/go",
        required=False,
    )
    return text


def patch_widget_surface(text):
    """Eliminate border.width animation and keep border opacity clean on widgets."""
    target_border_anim = (
        "    Behavior on border.width {\n"
        "        enabled: (root._iris ? IrisStyle.motionEnabled : Appearance.animationsEnabled)\n"
        "        NumberAnimation { duration: root._iris ? IrisStyle.revealDuration : Appearance.animation.elementMoveFast.duration; easing.type: root._iris ? Easing.BezierSpline : Appearance.animation.elementMoveFast.type; easing.bezierCurve: root._iris ? IrisStyle.morphCurve : Appearance.animation.elementMoveFast.bezierCurve }\n"
        "    }"
    )
    text, _ = apply(
        text,
        "modules/background/widgets/WidgetSurface.qml: remove border.width animation",
        re.escape(target_border_anim),
        "",
        already=r"// no border.width animation",
        required=False,
    )
    text, _ = apply(
        text,
        "modules/background/widgets/WidgetSurface.qml: unmultiplied border opacity",
        re.escape("ColorUtils.applyAlpha(Appearance.inir.colBorder, root.surfaceBorderOpacity * 3)"),
        "ColorUtils.applyAlpha(Appearance.inir.colBorder, root.surfaceBorderOpacity)",
        already=r"ColorUtils\.applyAlpha\(Appearance\.inir\.colBorder,\s*root\.surfaceBorderOpacity\)",
        required=False,
    )
    return text


def patch_zzz_plate(text):
    """Eliminate strokeWidth animation in ZzzPlate."""
    target_stroke_anim = (
        "    Behavior on strokeWidth {\n"
        "        enabled: Appearance.animationsEnabled\n"
        "        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }\n"
        "    }"
    )
    text, _ = apply(
        text,
        "modules/common/widgets/ZzzPlate.qml: remove strokeWidth animation",
        re.escape(target_stroke_anim),
        "",
        already=r"// no strokeWidth animation",
        required=False,
    )
    return text


PATCHES = {
    "services/IconThemeService.qml": patch_icon_theme,
    "shell.qml": patch_family_transition,
    "FamilyTransitionOverlay.qml": patch_family_transition_overlay,
    "scripts/inir": patch_launcher,
    "scripts/videos/record.sh": patch_record_script,
    "modules/iris/components/IrisMorphSurface.qml": patch_iris_morph_surface,
    "modules/iris/palette/IrisPalette.qml": patch_iris_palette,
    "services/deferred/LauncherSearch.qml": patch_launcher_search,
    "scripts/colors/generate_colors_material.py": patch_generate_colors_material,
    "scripts/colors/switchwall.sh": patch_switchwall,
    "scripts/colors/washi.sh": patch_washi,
    "services/ThemeService.qml": patch_theme_service,
    "services/Wallpapers.qml": patch_wallpapers,
    "modules/iris/wallpaper/IrisWallpaperPicker.qml": patch_iris_wallpaper_picker,
    "scripts/colors/apply-gtk-theme.sh": patch_apply_gtk_theme,
    "scripts/musicRecognition/recognize-music.sh": patch_recognize_music,
    "services/YtMusic.qml": patch_ytmusic,
    "services/deferred/InnerTube.qml": patch_innertube,
    "services/ConflictKiller.qml": patch_conflict_killer,
    "modules/background/widgets/WidgetSurface.qml": patch_widget_surface,
    "modules/common/widgets/ZzzPlate.qml": patch_zzz_plate,
}



def main():
    applied, skipped = [], []

    for path, patch in PATCHES.items():
        print(f"postpatch: {path}")
        try:
            with open(path, encoding="utf-8") as handle:
                original = handle.read()
        except FileNotFoundError:
            print("  ! missing, skipped")
            skipped.append(path)
            continue

        patched = patch(original)
        if patched != original:
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(patched)
            applied.append(path)
        else:
            skipped.append(path)

    print("postpatch: tree-wide")
    applied += patch_root_qml()

    print(f"postpatch: {len(applied)} file(s) adapted, {len(skipped)} unchanged")
    if not applied:
        print("postpatch: nothing to do (upstream may already be NixOS-ready)")


if __name__ == "__main__":
    main()