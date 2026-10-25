pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// What Home shows first, edited on a sheet over Settings (iOS's Edit, not a field of chips under the rows): the rows
// on Home in order, each with its area, moved or taken off in place; under them a search over every row Home can hold.
// The page behind follows every change live.
Item {
    id: root

    property real d: IrisStyle.settingsDensity
    // The body it covers: the scrim follows its corners, so nothing darkens past it.
    property real bodyRadius: 0
    function u(n: real): int { return Math.round(n * root.d) }
    readonly property bool open: IrisOptions.homeEditing
    readonly property var pinned: Array.from(Config.options?.iris?.appearance?.settingsHome ?? IrisOptions.homeDefault).map(entry => String(entry))
    readonly property var candidates: IrisOptions.homeCandidates
    function entryOf(value: string): var { return root.candidates.find(entry => entry.value === value) ?? null }
    readonly property var matches: {
        const words = query.text.trim().toLowerCase().split(/\s+/).filter(word => word.length > 0)
        const free = root.candidates.filter(entry => !root.pinned.includes(entry.value))
        if (words.length === 0) return free.filter(entry => entry.daily).slice(0, 6)
        return free.filter(entry => words.every(word => entry.search.includes(word))).slice(0, 8)
    }
    function write(list: var): void { Config.setNestedValue("iris.appearance.settingsHome", list) }
    function move(value: string, step: int): void {
        const list = root.pinned.slice()
        const at = list.indexOf(value)
        const to = at + step
        if (at < 0 || to < 0 || to >= list.length) return
        list.splice(at, 1)
        list.splice(to, 0, value)
        root.write(list)
    }
    function close(): void { IrisOptions.homeEditing = false; query.text = "" }

    visible: scrim.opacity > 0
    onOpenChanged: if (root.open) Qt.callLater(() => query.forceActiveFocus())

    Item {
        id: scrim
        readonly property color ink: Qt.rgba(0, 0, 0, IrisStyle.light ? 0.18 : 0.34) // iris-literal: a scrim, the page stays readable under it
        anchors.fill: parent
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        Rectangle { anchors.fill: parent; visible: !IrisStyle.fieldChamfer; radius: root.bodyRadius; color: scrim.ink }
        IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: scrim.ink }
        MouseArea { anchors.fill: parent; onClicked: root.close(); onWheel: wheel => wheel.accepted = true }
    }

    RectangularShadow {
        visible: !IrisStyle.fieldChamfer
        anchors.fill: sheet
        radius: sheet.radius
        blur: root.u(40)
        offset.y: root.u(14)
        color: IrisStyle.shadow
        opacity: sheet.opacity
    }
    Rectangle {
        id: sheet
        readonly property real pad: root.u(20)
        width: Math.min(root.u(520), root.width - root.u(48))
        height: Math.min(body.implicitHeight + 2 * sheet.pad, root.height - root.u(80))
        anchors.centerIn: parent
        radius: root.u(24)
        color: IrisStyle.fieldChamfer ? "transparent" : IrisStyle.surfaceOpaque
        border.width: IrisStyle.fieldChamfer ? 0 : 1
        border.color: IrisStyle.hairline
        IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: IrisStyle.surfaceOpaque; stroke: IrisStyle.hairline; strokeWidth: 1 }
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing } }
        MouseArea { anchors.fill: parent; onWheel: wheel => wheel.accepted = false }

        Flickable {
            anchors.fill: parent
            anchors.margins: sheet.pad
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Column {
                id: body
                width: parent.width
                spacing: root.u(14)

                // Head: what this is, and the way out.
                Item {
                    width: parent.width
                    height: Math.max(headText.implicitHeight, done.implicitHeight)
                    Column {
                        id: headText
                        anchors.left: parent.left
                        anchors.right: done.left
                        anchors.rightMargin: root.u(12)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.u(2)
                        IrisText { role: IrisText.Title; text: Translation.tr("On Home"); color: IrisStyle.text }
                        IrisText {
                            width: parent.width
                            text: Translation.tr("What you change every day")
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeMeta
                        }
                    }
                    IrisButton {
                        id: done
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Done")
                        emphasized: true
                        onClicked: root.close()
                    }
                }

                // What Home holds, in its order.
                Rectangle {
                    width: parent.width
                    height: pinnedColumn.implicitHeight
                    radius: IrisStyle.fieldChamfer ? 0 : root.u(16)
                    color: IrisStyle.fillQuiet
                    Column {
                        id: pinnedColumn
                        width: parent.width
                        Repeater {
                            model: root.pinned
                            Line {
                                required property string modelData
                                required property int index
                                width: pinnedColumn.width
                                entry: root.entryOf(modelData)
                                value: modelData
                                first: index === 0
                                last: index === root.pinned.length - 1
                                pinnedLine: true
                            }
                        }
                    }
                }

                // Every row Home can hold, by what you type.
                Rectangle {
                    width: parent.width
                    height: root.u(38)
                    radius: IrisStyle.capsule(height)
                    color: query.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet
                    border.width: query.activeFocus ? 1 : 0
                    border.color: IrisStyle.tintBorder(IrisStyle.accent)
                    MaterialSymbol {
                        id: findGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: root.u(12)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        iconSize: root.u(17)
                        color: IrisStyle.muted
                    }
                    TextInput {
                        id: query
                        anchors.left: findGlyph.right
                        anchors.leftMargin: root.u(8)
                        anchors.right: parent.right
                        anchors.rightMargin: root.u(12)
                        anchors.verticalCenter: parent.verticalCenter
                        color: IrisStyle.text
                        font.family: IrisStyle.fontMain
                        font.pixelSize: IrisStyle.typeLabel
                        clip: true
                        Keys.onEscapePressed: root.close()
                        Keys.onReturnPressed: if (root.matches.length > 0) root.write(root.pinned.concat([root.matches[0].value]))
                        IrisText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: query.text.length === 0
                            text: Translation.tr("Search to add")
                            color: IrisStyle.muted
                            font.pixelSize: query.font.pixelSize
                        }
                    }
                }
                Column {
                    width: parent.width
                    Repeater {
                        model: root.matches
                        Line {
                            required property var modelData
                            width: parent.width
                            entry: modelData
                            value: String(modelData.value)
                        }
                    }
                    IrisText {
                        visible: root.matches.length === 0
                        width: parent.width
                        topPadding: root.u(10)
                        bottomPadding: root.u(10)
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr("No matching settings")
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeMeta
                    }
                }
            }
        }
    }

    // A row Home holds or could hold: its area's glyph on the area's tint, its name over its area's, then what can be
    // done to it (moved, taken off) or the way to add it.
    component Line: MouseArea {
        id: line
        property var entry: null
        property string value: ""
        property bool pinnedLine: false
        property bool first: false
        property bool last: false
        height: root.u(50)
        hoverEnabled: true
        cursorShape: line.pinnedLine ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: if (!line.pinnedLine) root.write(root.pinned.concat([line.value]))
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.u(3)
            radius: IrisStyle.fieldChamfer ? 0 : root.u(12)
            color: line.containsMouse ? IrisStyle.fillHover : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        }
        Rectangle {
            visible: line.pinnedLine && !line.first
            x: tile.x
            width: parent.width - x - root.u(12)
            height: 1
            color: IrisStyle.hairline
        }
        Rectangle {
            id: tile
            x: root.u(12)
            anchors.verticalCenter: parent.verticalCenter
            width: root.u(28)
            height: width
            radius: IrisStyle.fieldChamfer ? 0 : root.u(8)
            gradient: Gradient {
                GradientStop { position: 0; color: IrisStyle.tileTop(line.entry?.tint ?? IrisStyle.identity.gray) }
                GradientStop { position: 1; color: line.entry?.tint ?? IrisStyle.identity.gray }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: String(line.entry?.icon ?? "settings")
                fill: 1
                iconSize: root.u(16)
                color: IrisStyle.onTintFor(line.entry?.tint ?? IrisStyle.identity.gray)
            }
        }
        Column {
            anchors.left: tile.right
            anchors.leftMargin: root.u(12)
            anchors.right: actions.left
            anchors.rightMargin: root.u(8)
            anchors.verticalCenter: parent.verticalCenter
            IrisText {
                width: parent.width
                elide: Text.ElideRight
                text: line.entry ? Translation.tr(String(line.entry.label)) : line.value
                color: IrisStyle.text
                font.pixelSize: IrisStyle.typeLabel
            }
            IrisText {
                width: parent.width
                visible: text.length > 0
                elide: Text.ElideRight
                text: !line.entry ? "" : Translation.tr(String(line.entry.area)) + (line.entry.group.length > 0 ? " · " + Translation.tr(String(line.entry.group)) : "")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }
        }
        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: root.u(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(2)
            Key { visible: line.pinnedLine; glyph: "keyboard_arrow_up"; name: Translation.tr("Move up"); usable: !line.first; onActed: root.move(line.value, -1) }
            Key { visible: line.pinnedLine; glyph: "keyboard_arrow_down"; name: Translation.tr("Move down"); usable: !line.last; onActed: root.move(line.value, 1) }
            Key {
                visible: line.pinnedLine
                glyph: "remove"
                name: Translation.tr("Remove")
                tint: IrisStyle.danger
                onActed: root.write(root.pinned.filter(entry => entry !== line.value))
            }
            Key { visible: !line.pinnedLine; glyph: "add"; name: Translation.tr("Add"); tint: IrisStyle.accent; onActed: root.write(root.pinned.concat([line.value])) }
        }
    }
    component Key: MouseArea {
        id: key
        property string glyph: ""
        property string name: ""
        property color tint: "transparent"
        property bool usable: true
        signal acted()
        readonly property bool tinted: key.tint.a > 0
        width: root.u(30)
        height: width
        enabled: key.usable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.name
        onClicked: key.acted()
        Rectangle {
            anchors.centerIn: parent
            width: key.tinted ? root.u(22) : parent.width
            height: width
            radius: width / 2
            color: key.tinted ? key.tint : key.containsMouse ? IrisStyle.fillHover : "transparent"
            scale: key.pressed ? IrisStyle.pressScale(0.9) : 1
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: key.glyph
            iconSize: root.u(key.tinted ? 16 : 20)
            color: key.tinted ? IrisStyle.onTintFor(key.tint) : IrisStyle.subtext
            opacity: key.usable ? 1 : 0.3
        }
    }
}
