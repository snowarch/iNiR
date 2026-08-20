import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Process {
    id: root

    signal done(string path, int width, int height)
    signal failed(string path, string reason)

    required property string filePath
    required property string sourceUrl
    property string downloadUserAgent: Config.options?.networking.userAgent ?? ""
    property string activeFilePath: ""

    function processFilePath(): string {
        return StringUtils.shellSingleQuoteEscape(
            FileUtils.trimFileProtocol(root.filePath))
    }

    function processSourceUrl(): string {
        return StringUtils.shellSingleQuoteEscape(root.sourceUrl.trim())
    }

    running: false
    command: [
        "/usr/bin/bash",
        "-c",
        `set -euo pipefail
src='${root.processSourceUrl()}'
dst='${root.processFilePath()}'
[ -n "$src" ] && [ -n "$dst" ] || exit 2
/usr/bin/mkdir -p "$(/usr/bin/dirname "$dst")"
if [ -s "$dst" ] && ! /usr/bin/magick identify -quiet "$dst"'[0]' >/dev/null 2>&1; then
    /usr/bin/rm -f -- "$dst"
fi
if [ ! -s "$dst" ]; then
    tmp="$dst.part.$$"
    trap '/usr/bin/rm -f "$tmp"' EXIT
    case "$src" in
        /*)
            [ -f "$src" ] && [ -r "$src" ] || {
                printf 'Local image is not a readable file: %s\n' "$src" >&2
                exit 3
            }
            /usr/bin/cp -- "$src" "$tmp"
            ;;
        file://*|http://*|https://*)
            /usr/bin/curl --fail --silent --show-error --location "$src" -o "$tmp"
            ;;
        *)
            printf 'Unsupported image source: %s\n' "$src" >&2
            exit 3
            ;;
    esac
    /usr/bin/magick identify -quiet "$tmp"'[0]' >/dev/null
    /usr/bin/mv -f "$tmp" "$dst"
    trap - EXIT
fi
/usr/bin/magick identify -format '%w %h' "$dst"'[0]'`
    ]

    stdout: StdioCollector {
        id: imageSizeOutputCollector
    }

    stderr: StdioCollector {
        id: errorOutputCollector
    }

    onStarted: root.activeFilePath = root.filePath

    onExited: (exitCode, exitStatus) => {
        const output = imageSizeOutputCollector.text.trim()
        const dimensions = output.split(/\s+/).map(Number)
        const width = dimensions[0] ?? 0
        const height = dimensions[1] ?? 0
        if (exitCode === 0 && Number.isFinite(width) && width > 0
                && Number.isFinite(height) && height > 0) {
            root.done(root.activeFilePath, width, height)
            return
        }
        const stderrText = errorOutputCollector.text.trim()
        root.failed(root.activeFilePath, stderrText.length > 0
            ? stderrText
            : `download exited with code ${exitCode} (${exitStatus})`)
    }
}
