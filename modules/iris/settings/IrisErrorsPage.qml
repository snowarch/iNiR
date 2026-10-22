pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// What the shell and qs-rs complained about, live, by the area that owns it. The check under it compiles every file
// of every family, so a broken switch shows up here before anybody touches it.
Flickable {
    id: root

    readonly property real d: IrisStyle.settingsDensity
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    contentHeight: pageColumn.implicitHeight + 40 * root.d
    ScrollBar.vertical: IrisScrollBar {}

    readonly property var areaNames: ({
        iris: "iRiS", ii: "Material", waffle: "Waffle", services: "Services", common: "Shared pieces",
        root: "Shell root", defaults: "Defaults", "?": "Shell, no file named"
    })
    readonly property var areaOrder: ["iris", "ii", "waffle", "services", "common", "root", "?"]
    // One list per owner: the shell's areas first, then qs-rs, then what the machine is missing.
    readonly property var groups: {
        const byKey = {}
        const add = (key, title, item) => {
            if (!byKey[key]) byKey[key] = { key: key, title: title, items: [] }
            byKey[key].items.push(item)
        }
        ShellErrors.kinds.forEach(kind => {
            const key = kind.owner === "shell" ? kind.area : kind.owner
            const title = kind.owner === "runtime" ? "qs-rs" : kind.owner === "system" ? Translation.tr("This computer")
                : Translation.tr(root.areaNames[kind.area] ?? kind.area)
            add(key, title, { error: kind.level === "error", text: ShellErrors.short(kind.text), stale: kind.current === 0,
                note: root.note(kind), order: kind.current > 0 ? 0 : 1 })
        })
        ShellErrors.checked.forEach(found => {
            add(found.area, Translation.tr(root.areaNames[found.area] ?? found.area), { error: true, text: found.text, stale: false,
                note: Translation.tr("Found by the check, before anything opened it"), order: 0 })
        })
        const rank = key => {
            const at = root.areaOrder.indexOf(key)
            return key === "runtime" ? 50 : key === "system" ? 60 : at >= 0 ? at : 40
        }
        return Object.values(byKey).sort((a, b) => rank(a.key) - rank(b.key)).map(group => {
            group.items.sort((a, b) => a.order - b.order || Number(b.error) - Number(a.error))
            return group
        })
    }

    function ago(ms: real): string {
        const s = Math.max(0, Math.round((Date.now() - ms) / 1000))
        if (s < 60) return Translation.tr("%1 s ago").arg(s)
        if (s < 3600) return Translation.tr("%1 min ago").arg(Math.floor(s / 60))
        return Translation.tr("%1 h ago").arg(Math.floor(s / 3600))
    }
    function note(kind: var): string {
        const times = kind.count === 1 ? Translation.tr("Once") : Translation.tr("%1 times").arg(kind.count)
        const now = kind.current === 0 ? Translation.tr("not since the last reload")
            : kind.current === kind.count ? "" : Translation.tr("%1 since the last reload").arg(kind.current)
        return [times, now, root.ago(kind.last)].filter(part => part.length > 0).join(" · ")
    }

    ColumnLayout {
        id: pageColumn
        width: Math.min(root.width - 32 * root.d, 720 * root.d)
        x: Math.round((root.width - width) / 2)
        y: Math.round(18 * root.d)
        spacing: 18 * root.d

        // The answer first: how many, how fresh, and the check that reads every file.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4 * root.d
            spacing: 14 * root.d
            IrisText {
                role: IrisText.Display
                text: String(ShellErrors.count)
                color: ShellErrors.count > 0 ? IrisStyle.danger : IrisStyle.text
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * root.d
                IrisText {
                    Layout.fillWidth: true
                    role: IrisText.Name
                    text: !ShellErrors.available ? Translation.tr("Only on qs-rs")
                        : ShellErrors.count === 0 ? Translation.tr("Nothing to fix") : Translation.tr("To fix, since the last reload")
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    role: IrisText.Detail
                    text: !ShellErrors.available ? Translation.tr("Quickshell keeps its log to itself; run the shell on qs-rs to see it here.")
                        : ShellErrors.checking ? Translation.tr("Checking every file of every family…")
                        : ShellErrors.summary.length > 0 ? ShellErrors.summary
                        : Translation.tr("Every file gets checked a few seconds after the shell starts.")
                    wrapMode: Text.Wrap
                }
            }
            IrisButton {
                visible: ShellErrors.available
                enabled: !ShellErrors.checking
                text: ShellErrors.checking ? Translation.tr("Checking") : Translation.tr("Check every file")
                onClicked: ShellErrors.check()
            }
        }

        Repeater {
            model: root.groups
            ColumnLayout {
                id: group
                required property var modelData
                Layout.fillWidth: true
                spacing: 6 * root.d
                IrisText {
                    Layout.leftMargin: 16 * root.d
                    role: IrisText.Group
                    text: group.modelData.title
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: itemColumn.implicitHeight
                    radius: IrisStyle.radiusTile
                    color: IrisStyle.readingCard
                    Column {
                        id: itemColumn
                        width: parent.width
                        Repeater {
                            model: group.modelData.items
                            MouseArea {
                                id: item
                                required property var modelData
                                required property int index
                                width: itemColumn.width
                                height: itemText.implicitHeight + itemNote.implicitHeight + 22 * root.d
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                opacity: item.modelData.stale ? 0.6 : 1
                                // A click copies the message, to paste where it gets fixed.
                                onClicked: Quickshell.clipboardText = item.modelData.text
                                Rectangle {
                                    anchors.fill: parent
                                    radius: IrisStyle.radiusTile
                                    color: IrisStyle.fillHover
                                    visible: item.containsMouse
                                }
                                Rectangle {
                                    id: mark
                                    x: 16 * root.d
                                    y: 11 * root.d + (itemText.font.pixelSize - height) / 2 + 2 * root.d
                                    width: 8 * root.d
                                    height: width
                                    radius: width / 2
                                    color: item.modelData.error ? IrisStyle.danger : IrisStyle.warning
                                }
                                IrisText {
                                    id: itemText
                                    anchors.left: mark.right
                                    anchors.leftMargin: 12 * root.d
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16 * root.d
                                    y: 11 * root.d
                                    role: IrisText.Name
                                    text: item.modelData.text
                                    font.family: IrisStyle.fontMono
                                    font.pixelSize: IrisStyle.typeMeta
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                                IrisText {
                                    id: itemNote
                                    anchors.left: itemText.left
                                    anchors.right: itemText.right
                                    anchors.top: itemText.bottom
                                    anchors.topMargin: 3 * root.d
                                    role: IrisText.Detail
                                    text: item.modelData.note
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    anchors.left: itemText.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    visible: item.index < group.modelData.items.length - 1
                                    color: IrisStyle.hairline
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
