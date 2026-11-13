pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.overlay

// A scratch note kept on disk. A line that starts with "- " gets a copy button: a shopping list for a build, codes,
// whatever has to be pasted into the game one by one.
Item {
    id: root

    property real d: OverlayLook.d
    // "saving", "saved", "failed"; empty until the first write.
    property string saveState: ""
    property bool storageReady: false
    property var copyLines: []
    property var _bullets: []
    property string _parsed: ""

    implicitWidth: Math.round(300 * root.d)
    implicitHeight: Math.round(220 * root.d)

    Component.onCompleted: ensureFile.running = true

    function parseBullets(): void {
        const text = editor.text
        if (text === root._parsed) return
        root._parsed = text
        const found = []
        const lineRegex = /(.*?)(\r?\n|$)/g
        let match = null
        while ((match = lineRegex.exec(text)) !== null) {
            const bullet = match[1].match(/^\s*-\s+(.*\S)\s*$/)
            if (bullet)
                found.push({ content: bullet[1].trim(), start: match.index, end: match.index + match[1].length })
            if (match[2] === "") break
        }
        root._bullets = found
    }
    function placeCopyButtons(): void {
        root.parseBullets()
        if (root._bullets.length === 0) {
            root.copyLines = []
            return
        }
        const a = editor.selectionStart === -1 ? editor.cursorPosition : editor.selectionStart
        const b = editor.selectionEnd === -1 ? editor.cursorPosition : editor.selectionEnd
        const from = Math.min(a, b)
        const to = Math.max(a, b)
        root.copyLines = root._bullets.map(line => {
            // No button on the line being edited.
            if (to > line.start && from <= line.end) return null
            const r = editor.positionToRectangle(line.start)
            if (!isFinite(r.y)) return null
            return { content: line.content, y: r.y + r.height / 2 }
        }).filter(line => line !== null)
    }

    ScrollView {
        id: scroller
        anchors.fill: parent
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        onWidthChanged: placeTimer.restart()

        StyledTextArea {
            id: editor
            width: scroller.availableWidth
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            persistentSelection: true
            background: null
            padding: Math.round(10 * root.d)
            rightPadding: Math.round(36 * root.d)
            color: OverlayLook.colOnLayer1
            placeholderTextColor: OverlayLook.colFaint
            selectionColor: OverlayLook.colToggle
            selectedTextColor: OverlayLook.colOnToggle
            font.family: OverlayLook.fontMain
            font.pixelSize: OverlayLook.typeBody
            placeholderText: Translation.tr("Write something here...\nUse '-' to create copyable bullet points, like this:\n\nSheep fricker\n- 4x Slab\n- 1x Boat\n- 4x Redstone Dust\n- 1x Sticky Piston\n- 1x End Rod\n- 4x Redstone Repeater\n- 1x Redstone Torch\n- 1x Sheep")
            onTextChanged: {
                if (editor.activeFocus) {
                    root.saveState = "saving"
                    saveTimer.restart()
                }
                placeTimer.restart()
            }
            onContentHeightChanged: placeTimer.restart()
            onCursorPositionChanged: placeTimer.restart()
            onSelectionStartChanged: placeTimer.restart()
            onSelectionEndChanged: placeTimer.restart()
        }

        Item {
            anchors.fill: parent
            visible: root.copyLines.length > 0
            Repeater {
                model: ScriptModel { values: root.copyLines }
                OverlayButton {
                    id: copyButton
                    required property var modelData
                    property bool copied: false
                    size: Math.round(24 * root.d)
                    glyphSize: Math.round(14 * root.d)
                    x: parent.width - width - Math.round(6 * root.d)
                    y: copyButton.modelData.y - height / 2
                    glyph: copyButton.copied ? "check" : "content_copy"
                    tint: copyButton.copied ? OverlayLook.colSuccess : OverlayLook.colPrimary
                    toggled: copyButton.copied
                    tip: copyButton.copied ? Translation.tr("Copied") : Translation.tr("Copy")
                    onClicked: {
                        Quickshell.clipboardText = copyButton.modelData.content
                        copyButton.copied = true
                        copiedTimer.restart()
                    }
                    Timer {
                        id: copiedTimer
                        interval: 900
                        onTriggered: copyButton.copied = false
                    }
                }
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 500
        onTriggered: noteFile.setText(editor.text)
    }
    Timer {
        id: placeTimer
        interval: 60
        onTriggered: root.placeCopyButtons()
    }

    Process {
        id: ensureFile
        command: ["bash", "-c", "mkdir -p -- \"$1\" && { [ -e \"$2\" ] || touch -- \"$2\"; }", "bash",
            Directories.notesPath.substring(0, Directories.notesPath.lastIndexOf('/')), Directories.notesPath]
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[Overlay Notes] Could not prepare the note:", code, status)
                root.saveState = "failed"
                return
            }
            root.storageReady = true
        }
    }

    FileView {
        id: noteFile
        path: root.storageReady ? Qt.resolvedUrl(Directories.notesPath) : ""
        onLoaded: {
            editor.text = noteFile.text()
            placeTimer.restart()
        }
        onSaved: root.saveState = "saved"
        onSaveFailed: error => {
            console.warn("[Overlay Notes] Could not save:", error)
            root.saveState = "failed"
        }
    }
}
