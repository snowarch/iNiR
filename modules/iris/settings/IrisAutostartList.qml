pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › General › At login: what Niri starts with you, as pieces on a plate in the order they start, the way
// the Dock holds apps. A click pauses a piece (it dims) or starts it again; hovering one offers its remove mark and
// says what it is on the line under the plate. Pieces from the person's own Niri lines carry a link mark and are
// only shown. The last piece adds: a field whose suggestions are apps, and whose words otherwise become a command.
ColumnLayout {
    id: root

    readonly property real d: IrisStyle.settingsDensity
    readonly property var apps: AppSearch.list ?? []
    readonly property string query: field.text.trim()
    property bool adding: false
    property var hovered: null
    function appOf(id: string): var { return root.apps.find(app => app.id === id) ?? null }
    // A command reads as the program it ends up running: after its last exec, past env and VAR=value words, and
    // through gtk-launch to the app it names. When that is an installed app the piece wears its icon and name.
    function commandTarget(command: string): string {
        const words = String(command).split(/\s+/).map(word => word.replace(/^['"]|['"]$/g, ""))
        let at = Math.max(0, words.lastIndexOf("exec") + 1)
        while (at < words.length - 1 && (words[at].split("/").pop() === "env" || /^[A-Z_][A-Z0-9_]*=/.test(words[at]))) at++
        if (words[at] === "gtk-launch" && at + 1 < words.length) at++
        return String(words[at] ?? "").split("/").pop().replace(/\.desktop$/, "")
    }
    function commandApp(command: string): var {
        const target = root.commandTarget(command).toLowerCase()
        return root.apps.find(app => String(app.id ?? "").toLowerCase().replace(/\.desktop$/, "") === target
            || String(app.name ?? "").toLowerCase() === target) ?? null
    }
    function iconOf(app: var): string { return app ? AppSearch.getIconSource(app.icon, app.name) : "" }
    // A managed piece keeps its index in Autostart.entries: removeEntry and setEntryEnabled take it.
    readonly property var pieces: (Autostart.entries ?? []).map((entry, index) => {
        const command = entry.type === "command"
        const app = command ? root.commandApp(String(entry.command)) : root.appOf(String(entry.desktopId))
        return { index: index, command: command, external: false, on: entry.enabled === true, icon: root.iconOf(app),
            name: command ? String(entry.command) : String(app?.name ?? entry.desktopId),
            short: app ? String(app.name ?? "") : command ? root.commandTarget(String(entry.command)) : String(entry.desktopId) }
    }).concat(root.apps.filter(app => Autostart.appEntrySource(app) === "external")
        .map(app => ({ index: -1, command: false, external: true, on: true, icon: root.iconOf(app), name: String(app.name ?? ""), short: String(app.name ?? "") })))
    readonly property var suggestions: {
        const words = root.query.toLowerCase()
        if (words.length === 0) return []
        return root.apps.filter(app => Autostart.appEntrySource(app) === "none"
            && (String(app.name ?? "").toLowerCase().includes(words) || String(app.genericName ?? "").toLowerCase().includes(words))).slice(0, 4)
    }
    function add(app: var): void {
        if (app) Autostart.addApp(app.id)
        else if (root.query.length > 0) Autostart.addCommand(root.query)
        field.text = ""
        root.adding = false
    }
    readonly property string caption: {
        const piece = root.hovered
        if (!piece) return root.pieces.length === 0 ? Translation.tr("Nothing starts with you yet.") : Translation.tr("In the order they start. Click one to pause it.")
        const name = piece.command ? Translation.tr("%1, as a command").arg(piece.short) : piece.short
        if (piece.external) return Translation.tr("%1 · started by your Niri config").arg(name)
        return (piece.on ? Translation.tr("%1 · starts with you") : Translation.tr("%1 · paused")).arg(name)
    }

    spacing: Math.round(8 * root.d)

    IrisText {
        Layout.fillWidth: true
        visible: !Autostart.isNiri || Autostart.status === "missing"
        wrapMode: Text.Wrap
        font.pixelSize: IrisStyle.typeMeta
        color: IrisStyle.subtext
        text: !Autostart.isNiri ? Translation.tr("Apps start from Niri's startup file, so this works only under Niri.")
            : Translation.tr("Niri's startup file is missing. Run iNiR's setup again to bring it back.")
    }

    Rectangle {
        id: plate
        visible: Autostart.isNiri && Autostart.status !== "missing"
        Layout.fillWidth: true
        implicitHeight: strip.implicitHeight + Math.round(24 * root.d)
        radius: IrisStyle.radiusCard
        color: IrisStyle.fillQuiet

        Flow {
            id: strip
            x: Math.round(12 * root.d)
            y: Math.round(12 * root.d)
            width: plate.width - Math.round(24 * root.d)
            spacing: Math.round(4 * root.d)

            Repeater {
                model: root.pieces
                delegate: Piece {}
            }

            // The last piece adds.
            MouseArea {
                width: Math.round(72 * root.d)
                height: Math.round(76 * root.d)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Add an app or a command")
                onClicked: { root.adding = !root.adding; if (root.adding) field.forceActiveFocus() }
                onContainsMouseChanged: root.hovered = null
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(6 * root.d)
                    width: Math.round(44 * root.d)
                    height: width
                    radius: IrisStyle.iconRadius(width)
                    color: root.adding ? IrisStyle.tintFill(IrisStyle.accent) : parent.containsMouse ? IrisStyle.fillHover : IrisStyle.fill
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.adding ? "close" : "add"
                        iconSize: Math.round(22 * root.d)
                        color: root.adding ? IrisStyle.accent : IrisStyle.textSecondary
                    }
                }
                IrisText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(56 * root.d)
                    text: root.adding ? Translation.tr("Cancel") : Translation.tr("Add")
                    font.pixelSize: IrisStyle.typeFootnote
                    color: IrisStyle.subtext
                }
            }
        }
    }

    IrisText {
        visible: plate.visible && !root.adding
        Layout.fillWidth: true
        Layout.leftMargin: Math.round(4 * root.d)
        text: root.caption
        font.pixelSize: IrisStyle.typeMeta
        color: root.hovered ? IrisStyle.text : IrisStyle.subtext
        elide: Text.ElideRight
    }

    IrisField {
        id: field
        visible: root.adding
        Layout.fillWidth: true
        implicitHeight: Math.round(36 * root.d)
        font.pixelSize: IrisStyle.typeLabel
        placeholderText: Translation.tr("An app's name, or a command")
        onAccepted: root.add(root.suggestions[0] ?? null)
        Keys.onEscapePressed: { field.text = ""; root.adding = false }
    }

    Repeater {
        model: root.adding ? root.suggestions : []
        delegate: AddRow {
            required property var modelData
            iconSource: root.iconOf(modelData)
            glyph: "apps"
            title: String(modelData.name ?? "")
            onClicked: root.add(modelData)
        }
    }

    AddRow {
        visible: root.adding && root.query.length > 0
        glyph: "terminal"
        title: Translation.tr("Run “%1” when you sign in").arg(root.query)
        onClicked: root.add(null)
    }

    component Piece: MouseArea {
        id: piece
        required property var modelData
        readonly property bool editable: !piece.modelData.external
        width: Math.round(72 * root.d)
        height: Math.round(76 * root.d)
        hoverEnabled: true
        cursorShape: piece.editable ? Qt.PointingHandCursor : Qt.ArrowCursor
        Accessible.role: Accessible.CheckBox
        Accessible.name: piece.modelData.name
        Accessible.checked: piece.modelData.on
        onContainsMouseChanged: root.hovered = piece.containsMouse ? piece.modelData : (root.hovered === piece.modelData ? null : root.hovered)
        onClicked: if (piece.editable) Autostart.setEntryEnabled(piece.modelData.index, !piece.modelData.on)

        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.radiusTile
            color: piece.containsMouse && piece.editable ? IrisStyle.fillHover : "transparent"
            Behavior on color {
                enabled: IrisStyle.motionEnabled
                ColorAnimation { duration: IrisStyle.duration(110) }
            }
        }
        Item {
            id: mark
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(6 * root.d)
            width: Math.round(44 * root.d)
            height: width
            opacity: piece.modelData.on ? 1 : 0.32
            Behavior on opacity {
                enabled: IrisStyle.motionEnabled
                NumberAnimation { duration: IrisStyle.duration(160) }
            }
            IrisImage {
                id: icon
                anchors.fill: parent
                source: piece.modelData.icon
                fillMode: Image.PreserveAspectFit
                visible: piece.modelData.icon.length > 0 && icon.status === Image.Ready
            }
            IrisSquircle {
                anchors.fill: parent
                visible: !icon.visible
                tint: piece.modelData.command ? IrisStyle.identity.gray : IrisStyle.identity.blue
                glyph: piece.modelData.command ? "terminal" : "apps"
            }
        }
        IrisText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(56 * root.d)
            width: Math.min(implicitWidth, parent.width - Math.round(8 * root.d))
            horizontalAlignment: Text.AlignHCenter
            text: piece.modelData.short
            font.pixelSize: IrisStyle.typeFootnote
            color: piece.modelData.on ? IrisStyle.textSecondary : IrisStyle.textTertiary
            elide: Text.ElideRight
        }
        // Marks sit beside the icon, not on its faded layer: a link for the person's own Niri lines, a prompt for a
        // command that launches an app.
        Rectangle {
            visible: piece.modelData.command && icon.visible
            x: mark.x + mark.width - width + Math.round(4 * root.d)
            y: mark.y + mark.height - height + Math.round(4 * root.d)
            width: Math.round(18 * root.d)
            height: width
            radius: IrisStyle.capsule(width)
            color: IrisStyle.bodySurface
            MaterialSymbol {
                anchors.centerIn: parent
                text: "terminal"
                iconSize: Math.round(12 * root.d)
                color: IrisStyle.textSecondary
            }
        }
        Rectangle {
            visible: piece.modelData.external
            x: mark.x + mark.width - width + Math.round(4 * root.d)
            y: mark.y + mark.height - height + Math.round(4 * root.d)
            width: Math.round(18 * root.d)
            height: width
            radius: IrisStyle.capsule(width)
            color: IrisStyle.bodySurface
            MaterialSymbol {
                anchors.centerIn: parent
                text: "link"
                iconSize: Math.round(12 * root.d)
                color: IrisStyle.textSecondary
            }
        }
        MouseArea {
            visible: piece.editable && piece.containsMouse
            x: mark.x + mark.width - width + Math.round(6 * root.d)
            y: mark.y - Math.round(6 * root.d)
            width: Math.round(20 * root.d)
            height: width
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("Remove")
            onClicked: { root.hovered = null; Autostart.removeEntry(piece.modelData.index) }
            Rectangle {
                anchors.fill: parent
                radius: IrisStyle.capsule(width)
                color: parent.containsMouse ? IrisStyle.danger : IrisStyle.raised
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: Math.round(12 * root.d)
                    color: parent.parent.containsMouse ? IrisStyle.onTintFor(IrisStyle.danger) : IrisStyle.text
                }
            }
        }
    }

    component AddRow: MouseArea {
        id: row
        property string iconSource: ""
        property string glyph: "apps"
        property string title: ""
        Layout.fillWidth: true
        implicitHeight: Math.round(42 * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: row.title
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.radiusRow
            color: row.containsMouse ? IrisStyle.fillQuiet : "transparent"
        }
        Item {
            id: rowMark
            anchors.left: parent.left
            anchors.leftMargin: Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(24 * root.d)
            height: width
            IrisImage {
                id: rowIcon
                anchors.fill: parent
                source: row.iconSource
                fillMode: Image.PreserveAspectFit
                visible: row.iconSource.length > 0 && rowIcon.status === Image.Ready
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: !rowIcon.visible
                text: row.glyph
                iconSize: Math.round(20 * root.d)
                color: IrisStyle.subtext
            }
        }
        IrisText {
            anchors.left: rowMark.right
            anchors.leftMargin: Math.round(12 * root.d)
            anchors.right: plus.left
            anchors.rightMargin: Math.round(8 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: row.title
            font.pixelSize: IrisStyle.typeLabel
            elide: Text.ElideRight
        }
        MaterialSymbol {
            id: plus
            anchors.right: parent.right
            anchors.rightMargin: Math.round(12 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: "add"
            iconSize: Math.round(18 * root.d)
            color: row.containsMouse ? IrisStyle.accent : IrisStyle.textTertiary
        }
    }
}
