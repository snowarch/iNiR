pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › General › At login: what Niri starts with you. Only what starts is listed; one field adds an app
// (picked from its suggestions) or, failing that, the words typed as a shell command.
ColumnLayout {
    id: root

    readonly property real d: IrisStyle.settingsDensity
    readonly property var apps: AppSearch.list ?? []
    readonly property string query: field.text.trim()
    function appOf(id: string): var { return root.apps.find(app => app.id === id) ?? null }
    function iconOf(app: var): string { return app ? AppSearch.getIconSource(app.icon, app.name) : "" }
    // A managed entry keeps its index in Autostart.entries: removeEntry and setEntryEnabled take it.
    readonly property var managed: (Autostart.entries ?? []).map((entry, index) => ({ entry: entry, index: index, app: entry.type === "app" ? root.appOf(String(entry.desktopId)) : null }))
    // Apps a line outside iNiR's block starts: shown, never rewritten.
    readonly property var external: root.apps.filter(app => Autostart.appEntrySource(app) === "external")
    readonly property var suggestions: {
        const words = root.query.toLowerCase()
        if (words.length === 0) return []
        return root.apps.filter(app => Autostart.appEntrySource(app) === "none"
            && (String(app.name ?? "").toLowerCase().includes(words) || String(app.genericName ?? "").toLowerCase().includes(words))).slice(0, 5)
    }
    function add(app: var): void {
        if (app) Autostart.addApp(app.id)
        else if (root.query.length > 0) Autostart.addCommand(root.query)
        field.text = ""
    }

    spacing: Math.round(4 * root.d)

    IrisText {
        Layout.fillWidth: true
        visible: !Autostart.isNiri || Autostart.status === "missing"
        wrapMode: Text.Wrap
        font.pixelSize: IrisStyle.typeMeta
        color: IrisStyle.subtext
        text: !Autostart.isNiri ? Translation.tr("Apps start from Niri's startup file, so this works only under Niri.")
            : Translation.tr("Niri's startup file is missing. Run iNiR's setup again to bring it back.")
    }

    IrisField {
        id: field
        visible: Autostart.isNiri && Autostart.status !== "missing"
        Layout.fillWidth: true
        implicitHeight: Math.round(36 * root.d)
        font.pixelSize: IrisStyle.typeLabel
        placeholderText: Translation.tr("Add an app or a command")
        onAccepted: root.add(root.suggestions[0] ?? null)
    }

    Repeater {
        model: root.suggestions
        delegate: EntryRow {
            required property var modelData
            iconSource: root.iconOf(modelData)
            glyph: "apps"
            title: String(modelData.name ?? "")
            detail: Translation.tr("Start it with you")
            adds: true
            onClicked: root.add(modelData)
        }
    }

    EntryRow {
        visible: root.query.length > 0
        glyph: "terminal"
        title: root.query
        detail: Translation.tr("Run it as a command when you sign in")
        adds: true
        onClicked: root.add(null)
    }

    Rectangle {
        visible: root.query.length > 0 && (root.managed.length + root.external.length) > 0
        Layout.fillWidth: true
        Layout.topMargin: Math.round(4 * root.d)
        Layout.bottomMargin: Math.round(4 * root.d)
        implicitHeight: 1
        color: IrisStyle.hairline
    }

    Repeater {
        model: root.managed
        delegate: EntryRow {
            required property var modelData
            readonly property bool command: modelData.entry.type === "command"
            iconSource: root.iconOf(modelData.app)
            glyph: command ? "terminal" : "apps"
            title: command ? String(modelData.entry.command) : String(modelData.app?.name ?? modelData.entry.desktopId)
            detail: command ? Translation.tr("Command") : ""
            switchable: true
            on: modelData.entry.enabled === true
            removable: true
            onToggle: Autostart.setEntryEnabled(modelData.index, !on)
            onRemove: Autostart.removeEntry(modelData.index)
        }
    }

    Repeater {
        model: root.external
        delegate: EntryRow {
            required property var modelData
            iconSource: root.iconOf(modelData)
            glyph: "apps"
            title: String(modelData.name ?? "")
            detail: Translation.tr("Started by your Niri config")
        }
    }

    IrisText {
        visible: Autostart.isNiri && Autostart.status !== "missing" && root.query.length === 0 && root.managed.length + root.external.length === 0
        Layout.fillWidth: true
        Layout.topMargin: Math.round(4 * root.d)
        font.pixelSize: IrisStyle.typeMeta
        color: IrisStyle.subtext
        text: Translation.tr("Nothing starts with you yet.")
    }

    component EntryRow: MouseArea {
        id: row

        property string iconSource: ""
        property string glyph: "apps"
        property string title: ""
        property string detail: ""
        property bool adds: false
        property bool switchable: false
        property bool on: false
        property bool removable: false
        signal toggle()
        signal remove()

        Layout.fillWidth: true
        implicitHeight: Math.round(46 * root.d)
        hoverEnabled: true
        cursorShape: row.adds || row.switchable ? Qt.PointingHandCursor : Qt.ArrowCursor
        Accessible.role: row.adds ? Accessible.Button : Accessible.ListItem
        Accessible.name: row.title
        onClicked: if (row.switchable) row.toggle()

        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.radiusRow
            color: row.containsMouse && (row.adds || row.switchable) ? IrisStyle.fillQuiet : "transparent"
            Behavior on color {
                enabled: IrisStyle.motionEnabled
                ColorAnimation { duration: IrisStyle.duration(110) }
            }
        }
        Item {
            id: mark
            anchors.left: parent.left
            anchors.leftMargin: Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(26 * root.d)
            height: width
            IrisImage {
                id: icon
                anchors.fill: parent
                source: row.iconSource
                fillMode: Image.PreserveAspectFit
                visible: row.iconSource.length > 0 && icon.status === Image.Ready
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: !icon.visible
                text: row.glyph
                iconSize: Math.round(20 * root.d)
                color: IrisStyle.subtext
            }
        }
        ColumnLayout {
            anchors.left: mark.right
            anchors.leftMargin: Math.round(12 * root.d)
            anchors.right: controls.left
            anchors.rightMargin: Math.round(8 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            IrisText {
                Layout.fillWidth: true
                text: row.title
                font.pixelSize: IrisStyle.typeLabel
                color: row.switchable && !row.on ? IrisStyle.subtext : IrisStyle.text
                elide: Text.ElideRight
            }
            IrisText {
                Layout.fillWidth: true
                visible: row.detail.length > 0
                text: row.detail
                font.pixelSize: IrisStyle.typeFootnote
                color: IrisStyle.subtext
                elide: Text.ElideRight
            }
        }
        RowLayout {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(6 * root.d)
            MaterialSymbol {
                visible: row.adds
                text: "add"
                iconSize: Math.round(18 * root.d)
                color: row.containsMouse ? IrisStyle.accent : IrisStyle.textTertiary
            }
            IrisIconButton {
                visible: row.removable
                materialIcon: "close"
                iconSize: Math.round(16 * root.d)
                Accessible.name: Translation.tr("Remove")
                onClicked: row.remove()
            }
            IrisSwitch {
                visible: row.switchable
                on: row.on
                name: row.title
                onToggled: row.toggle()
            }
        }
    }
}
