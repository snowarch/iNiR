pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    // --- Public state ---
    property bool available: false
    property bool busy: _anyRunning
    property bool loadingThemes: listThemesProc.running
    property string error: ""
    property int previewRevision: 0
    property var availableThemes: []
    property var extractedColors: []
    property string compressResult: ""
    property var currentThemeColors: []
    readonly property bool hasCurrentThemePalette: currentThemeColors.length > 0

    readonly property bool _anyRunning: availabilityProc.running || listThemesProc.running
        || ensureDirProc.running || writeThemeProc.running || operationProc.running
        || copyProc.running || extractProc.running || compressProc.running

    // Single reusable preview file — never spams new images
    readonly property string previewFile: "/tmp/inir-gowall-preview"
    readonly property string previewUrl: _previewReady ? `file://${_currentPreviewPath}?rev=${previewRevision}` : ""

    // --- Internal state ---
    property bool _previewReady: false
    property string _currentPreviewPath: ""

    // Pending operation params
    property var _pendingCommand: []
    property string _pendingFormat: "png"
    property string _pendingThemeJson: ""
    property bool _pendingNeedsThemeFile: false
    property string _pendingSourceBasename: ""  // Track source for smart naming

    readonly property string _runtimeDir: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/gowall`)
    readonly property string _customThemePath: FileUtils.trimFileProtocol(`${_runtimeDir}/custom-theme.json`)
    readonly property string _outputDir: FileUtils.trimFileProtocol(`${Directories.pictures}/Wallpapers/Gowall`)
    readonly property string _generatedThemePath: Directories.generatedMaterialThemePath

    // --- Helpers ---
    function _norm(path: string): string {
        return FileUtils.trimFileProtocol(String(path ?? ""))
    }

    function _ext(format: string): string {
        const f = String(format ?? "png").toLowerCase()
        return (f === "jpg" || f === "jpeg" || f === "webp") ? f : "png"
    }

    function _previewPathFor(format: string): string {
        return `${previewFile}.${_ext(format)}`
    }

    function _shellEscape(value: string): string {
        return "'" + String(value ?? "").replace(/'/g, "'\"'\"'") + "'"
    }

    function _extFromPath(path: string): string {
        const parts = String(path ?? "").split(".")
        if (parts.length < 2) return "png"
        const ext = parts[parts.length - 1].toLowerCase()
        return (ext === "jpg" || ext === "jpeg" || ext === "webp" || ext === "png") ? ext : "png"
    }

    function _basenameWithoutExt(path: string): string {
        const p = String(path ?? "")
        const lastSlash = p.lastIndexOf("/")
        const name = lastSlash >= 0 ? p.substring(lastSlash + 1) : p
        const dotIdx = name.lastIndexOf(".")
        return dotIdx > 0 ? name.substring(0, dotIdx) : name
    }

    // --- Public API ---

    function refreshAvailability(): void {
        availabilityProc.running = true
    }

    function refreshThemes(): void {
        if (!available || listThemesProc.running) return
        listThemesProc.running = true
    }

    // convert --theme <name>
    function convertTheme(sourcePath: string, themeName: string, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        if (themeName.length === 0) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "convert", src, "--theme", themeName, "--output", _previewPathFor(fmt), "--format", fmt], fmt, "", false, _basenameWithoutExt(src))
    }

    // convert --theme <json> (custom palette)
    function convertCustomTheme(sourcePath: string, themeName: string, colors, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const palette = _buildPalette(colors)
        if (palette.length === 0) { error = "Custom palette is empty"; return }
        const label = (themeName ?? "").length > 0 ? themeName : "custom"
        const json = JSON.stringify({ name: label, colors: palette }, null, 2)
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "convert", src, "--theme", _customThemePath, "--output", _previewPathFor(fmt), "--format", fmt], fmt, json, true, _basenameWithoutExt(src))
    }

    function convertCurrentTheme(sourcePath: string, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const palette = _buildPalette(currentThemeColors)
        if (palette.length === 0) { error = "Current iNiR theme palette is unavailable"; return }
        const json = JSON.stringify({ name: "inir-current", colors: palette }, null, 2)
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "convert", src, "--theme", _customThemePath, "--output", _previewPathFor(fmt), "--format", fmt], fmt, json, true, _basenameWithoutExt(src))
    }

    // effects grayscale / flip / mirror
    function effectSimple(sourcePath: string, effectName: string, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "effects", effectName, src, "--output", _previewPathFor(fmt)], fmt, "", false, _basenameWithoutExt(src))
    }

    // effects br --factor <f>
    function effectBrightness(sourcePath: string, factor: real, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "effects", "br", src, "--factor", String(factor), "--output", _previewPathFor(fmt)], fmt, "", false, _basenameWithoutExt(src))
    }

    // invert
    function invert(sourcePath: string, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "invert", src, "--output", _previewPathFor(fmt)], fmt, "", false, _basenameWithoutExt(src))
    }

    // pixelate --scale <s>
    function pixelate(sourcePath: string, scale: real, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "pixelate", src, "--scale", String(scale), "--output", _previewPathFor(fmt)], fmt, "", false, _basenameWithoutExt(src))
    }

    // extract -c <n>
    function extract(sourcePath: string, numColors: int): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        extractedColors = []
        extractProc.command = ["/usr/bin/gowall", "extract", src, "-c", String(numColors)]
        extractProc.running = true
    }

    // draw border --color <hex> --borderThickness <n>
    function drawBorder(sourcePath: string, borderColor: string, thickness: int, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "draw", "border", src,
            "--color", borderColor, "--borderThickness", String(thickness),
            "--output", _previewPathFor(fmt)], fmt, "", false, _basenameWithoutExt(src))
    }

    // draw grid --color <hex> --size <n> --thickness <n>
    function drawGrid(sourcePath: string, gridColor: string, gridSize: int, thickness: int, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "draw", "grid", src,
            "--color", gridColor, "--size", String(gridSize), "--thickness", String(thickness),
            "--output", _previewPathFor(fmt)], fmt, "", false, _basenameWithoutExt(src))
    }

    // compress --quality <n> --method <m>
    function compress(sourcePath: string, quality: int, method: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const outPath = `${previewFile}-compressed.${_extFromPath(src)}`
        const cmd = ["/usr/bin/gowall", "compress", src, "--quality", String(quality), "--output", outPath]
        if (method.length > 0)
            cmd.push("--method", method)
        compressProc._outputPath = outPath
        compressProc.command = cmd
        ensureDirProc._nextAction = "compress"
        ensureDirProc.running = true
    }

    // bg (remove background)
    function removeBg(sourcePath: string, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "bg", src,
            "--output", _previewPathFor(fmt)], fmt, "", false, _basenameWithoutExt(src))
    }

    // convert --replace #from,#to
    function replaceColor(sourcePath: string, fromColor: string, toColor: string, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "convert", src,
            "--replace", `${fromColor},${toColor}`,
            "--output", _previewPathFor(fmt), "--format", fmt], fmt, "", false, _basenameWithoutExt(src))
    }

    // upscale --scale <n> --model <m>
    function upscale(sourcePath: string, scale: int, model: string, format: string): void {
        const src = _norm(sourcePath)
        if (!_guardReady(src)) return
        const fmt = _ext(format)
        _runOperation(["/usr/bin/gowall", "upscale", src,
            "--scale", String(scale), "--model", model,
            "--output", _previewPathFor(fmt)], fmt, "", false, _basenameWithoutExt(src) + "-upscaled")
    }

    // Apply current preview as wallpaper — copies to final destination, then calls Wallpapers.apply
    // Uses source-based naming to avoid spamming multiple files for the same wallpaper
    function applyPreview(): void {
        if (!_previewReady || _currentPreviewPath.length === 0) return
        if (busy) return
        error = ""
        // Use source basename for predictable naming (overwrites previous result from same source)
        const basename = _pendingSourceBasename.length > 0 ? _pendingSourceBasename : "gowall"
        const dest = `${_outputDir}/${basename}.${_pendingFormat}`
        copyProc.command = ["/usr/bin/cp", _currentPreviewPath, dest]
        copyProc._destPath = dest
        ensureDirProc._nextAction = "copy"
        ensureDirProc.running = true
    }

    // --- Internal pipeline ---
    function _guardReady(src: string): bool {
        if (!available) { error = "gowall is not installed"; return false }
        if (src.length === 0) return false
        if (busy) return false
        error = ""
        return true
    }

    function _buildPalette(colors): list<string> {
        const result = []
        for (const c of colors ?? []) {
            const text = String(c ?? "").trim()
            if (text.length > 0) result.push(text)
        }
        return result
    }

    function _runOperation(command, format: string, themeJson: string, needsThemeFile: bool, sourceBasename): void {
        _pendingCommand = command
        _pendingFormat = format
        _pendingThemeJson = themeJson
        _pendingNeedsThemeFile = needsThemeFile
        _pendingSourceBasename = sourceBasename
        ensureDirProc._nextAction = "operation"
        ensureDirProc.running = true
    }

    function _syncCurrentThemePalette(fileContent): void {
        if (!fileContent || fileContent.trim().length === 0)
            return

        let json
        try {
            json = JSON.parse(fileContent)
        } catch (e) {
            return
        }

        if (!json || typeof json !== "object")
            return

        const preferredKeys = [
            "primary",
            "secondary",
            "tertiary",
            "primary_container",
            "surface_container_high",
            "surface",
            "background",
            "on_surface",
        ]
        const next = []
        const seen = ({})

        function appendColor(value): void {
            const text = String(value ?? "").trim()
            if (!/^#[0-9a-fA-F]{6}$/.test(text))
                return
            const normalized = text.toLowerCase()
            if (seen[normalized])
                return
            seen[normalized] = true
            next.push(text)
        }

        for (const key of preferredKeys)
            appendColor(json[key])

        if (next.length < 6) {
            for (const key in json) {
                appendColor(json[key])
                if (next.length >= 8)
                    break
            }
        }

        if (next.length > 0)
            currentThemeColors = next
    }

    FileView {
        id: currentThemePaletteReader
        path: Qt.resolvedUrl(root._generatedThemePath)
        watchChanges: true
        onFileChanged: {
            this.reload()
        }
        onLoadedChanged: {
            root._syncCurrentThemePalette(currentThemePaletteReader.text())
        }
    }

    Component.onCompleted: {
        refreshAvailability()
        currentThemePaletteReader.reload()
    }

    // --- Processes ---

    Process {
        id: availabilityProc
        command: ["/usr/bin/which", "gowall"]
        stdout: SplitParser {
            onRead: data => { root.available = data.trim().length > 0 }
        }
        onStarted: { root.available = false; root.error = "" }
        onExited: (exitCode) => {
            root.available = exitCode === 0
            if (root.available) root.refreshThemes()
        }
    }

    Process {
        id: listThemesProc
        command: ["/usr/bin/gowall", "list"]
        stdout: SplitParser {
            onRead: data => {
                const theme = data.trim()
                if (theme.length > 0)
                    root.availableThemes = [...root.availableThemes, theme]
            }
        }
        onStarted: { root.availableThemes = []; root.error = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.error = "Failed to load gowall themes"
        }
    }

    Process {
        id: ensureDirProc
        property string _nextAction: "operation"
        command: ["/usr/bin/mkdir", "-p", root._runtimeDir, root._outputDir]
        onExited: (exitCode) => {
            if (exitCode !== 0) { root.error = "Failed to prepare directories"; return }
            if (_nextAction === "copy") {
                copyProc.running = true
                return
            }
            if (_nextAction === "compress") {
                compressProc.running = true
                return
            }
            if (root._pendingNeedsThemeFile) {
                const cmd = `printf '%s' ${root._shellEscape(root._pendingThemeJson)} > ${root._shellEscape(root._customThemePath)}`
                writeThemeProc.command = ["/usr/bin/bash", "-c", cmd]
                writeThemeProc.running = true
                return
            }
            operationProc.command = root._pendingCommand
            operationProc.running = true
        }
    }

    Process {
        id: writeThemeProc
        onExited: (exitCode) => {
            if (exitCode !== 0) { root.error = "Failed to write custom theme file"; return }
            operationProc.command = root._pendingCommand
            operationProc.running = true
        }
    }

    Process {
        id: operationProc
        onExited: (exitCode) => {
            if (exitCode !== 0) { root.error = "gowall operation failed"; return }
            root._currentPreviewPath = root._previewPathFor(root._pendingFormat)
            root._previewReady = true
            root.previewRevision += 1
        }
    }

    Process {
        id: copyProc
        property string _destPath: ""
        onExited: (exitCode) => {
            if (exitCode !== 0) { root.error = "Failed to copy result to wallpapers"; return }
            Wallpapers.apply(_destPath, Appearance.m3colors.darkmode)
        }
    }

    Process {
        id: extractProc
        command: ["/usr/bin/gowall", "extract", "/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.startsWith("#") || line.startsWith("rgb"))
                    root.extractedColors = [...root.extractedColors, line]
            }
        }
        onStarted: { root.extractedColors = []; root.error = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.error = "Color extraction failed"
        }
    }

    Process {
        id: compressProc
        property string _outputPath: ""
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.length > 0) root.compressResult += (root.compressResult.length > 0 ? "\n" : "") + line
            }
        }
        onStarted: { root.compressResult = ""; root.error = "" }
        onExited: (exitCode) => {
            if (exitCode !== 0) { root.error = "Compression failed"; return }
            root._currentPreviewPath = _outputPath
            root._previewReady = true
            root.previewRevision += 1
        }
    }
}
