pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings
import qs.modules.iris.settings.layouts.drawer as Skins // so Quickshell mirrors the skins IrisSkin loads by url

// Drawer: Settings pulled out from the foot of the screen like a desk's drawer, the desktop above it left in view. Its
// head is a row of keys, one per area, the way the Dock holds apps: the open one names itself, a key you rest on says
// its name. An area is its title and live stage on the left and its groups flowing across columns; the grip raises
// the drawer to the top of the room for a long area.
Item {
    id: root
    property Item host
    readonly property real d: Number(root.host?.d ?? 1)
    function u(n: real): int { return Math.round(n * root.d) }

    readonly property alias searchSlot: searchSlot
    readonly property alias rowsSlot: rowsSlot
    readonly property real pageWidth: body.width
    readonly property real need: 0
    readonly property string voice: "drawer"
    readonly property bool ownsStage: true
    readonly property bool readsWhole: true
    readonly property bool drawsRows: true
    readonly property string searchHint: Translation.tr("Search settings")
    // Raised to the room's top; the engine reads it for the body's height.
    property bool tall: false

    readonly property bool windowed: root.host?.windowed ?? false
    readonly property var sections: root.host?.sections ?? []
    readonly property string section: String(root.host?.section ?? "")
    readonly property bool searching: root.host?.searching ?? false
    readonly property bool paged: Number(root.host?.advancedPage ?? -1) >= 0
    readonly property var noteCounts: root.host?.noteCounts ?? ({})
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    readonly property real pad: root.u(20)

    // ── The grip: a click raises or lowers the drawer, a pull up or down says which.
    MouseArea {
        id: grip
        objectName: "drawerGrip"
        visible: !root.windowed
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.u(120)
        height: root.u(20)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: root.tall ? Translation.tr("Lower settings") : Translation.tr("Raise settings")
        property real from: 0
        property bool pulled: false
        onPressed: mouse => { grip.from = mouse.y; grip.pulled = false }
        onPositionChanged: mouse => {
            if (!grip.pressed || grip.pulled || Math.abs(mouse.y - grip.from) < root.u(12)) return
            grip.pulled = true
            root.tall = mouse.y < grip.from
        }
        onClicked: if (!grip.pulled) root.tall = !root.tall
        Rectangle {
            anchors.centerIn: parent
            width: root.u(grip.containsMouse ? 52 : 44)
            height: root.u(5)
            radius: height / 2
            color: grip.containsMouse ? IrisStyle.textTertiary : IrisStyle.hairlineStrong
            Behavior on width { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        }
    }

    // ── The head: the search, the keys, the switch and the way out.
    RowLayout {
        id: head
        x: root.pad
        y: root.u(root.windowed ? 14 : 22)
        width: root.width - 2 * root.pad
        height: root.u(40)
        spacing: root.u(10)
        Item { id: searchSlot; Layout.preferredWidth: root.u(250); Layout.preferredHeight: root.u(36) }
        Flickable {
            id: keyFlick
            Layout.fillWidth: true
            Layout.preferredHeight: root.u(40)
            contentWidth: keyRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: keyRow.width > keyFlick.width
            clip: true
            Row {
                id: keyRow
                x: Math.max(0, Math.round((keyFlick.width - width) / 2))
                height: keyFlick.height
                spacing: root.u(2)
                Repeater {
                    model: root.sections
                    Row {
                        id: slot
                        required property var modelData
                        required property int index
                        readonly property bool starts: slot.index > 0 && root.sections[slot.index - 1]?.cluster !== slot.modelData.cluster
                        height: keyRow.height
                        spacing: root.u(2)
                        Item {
                            visible: slot.starts
                            width: root.u(15)
                            height: parent.height
                            Rectangle { anchors.centerIn: parent; width: 1; height: root.u(20); color: IrisStyle.hairline }
                        }
                        AreaKey { entry: slot.modelData; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
        LayoutSwitch { host: root.host; voice: "drawer"; compact: true }
        HeadKey {
            glyph: root.windowed ? "layers" : "web_asset"
            name: root.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
            onClicked: root.host.switchHost()
        }
        HeadKey { glyph: "close"; name: Translation.tr("Close settings"); onClicked: root.host.close() }
    }

    // ── The body: an area of the pool, or a search's results and a shared page on their own sheet.
    Item {
        id: body
        x: root.pad
        y: head.y + head.height + root.u(16)
        width: root.width - 2 * root.pad
        height: root.height - y - root.u(14)

        AreaPool {
            id: pool
            anchors.fill: parent
            current: root.searching ? pool.shown : root.section
            hidden: root.searching || root.paged
            settled: Boolean(root.host?.bodySettled ?? true)
            urlFor: id => Qt.resolvedUrl("DrawerPage.qml")
            propsFor: id => ({ host: root.host })
            order: root.sections.map(entry => entry.id)
            distance: root.u(30)
            onArrived: id => {
                if (root.wantedGroup.length > 0 && id === root.section) {
                    pool.shownItem?.showGroup?.(root.wantedGroup)
                    root.wantedGroup = ""
                }
            }
        }
        Rectangle {
            visible: root.searching || root.paged
            anchors.fill: parent
            radius: IrisStyle.radiusSheet
            color: IrisStyle.glassy ? IrisStyle.readingSidebar : "transparent"
            Item {
                id: rowsSlot
                anchors.fill: parent
                anchors.margins: IrisStyle.glassy ? root.u(6) : 0
            }
        }
    }

    // A group asked for by name lands once its area's page stands.
    property string wantedGroup: ""
    function showGroup(key: string): void {
        if (pool.shown === root.section && pool.shownItem?.showGroup) pool.shownItem.showGroup(key)
        else root.wantedGroup = key
    }

    // The key the pointer rests on names itself after a beat; sweeping on along the row, each names itself at once.
    property string resting: ""
    property string named: ""
    Timer { id: nameSoon; interval: 260; onTriggered: root.named = root.resting }

    // An area's key: its glyph; open, an inverted capsule with its name; rested on, its name in a quiet capsule.
    component AreaKey: MouseArea {
        id: key
        property var entry: ({})
        readonly property string areaId: String(key.entry.id ?? "")
        readonly property bool on: key.areaId === root.section && !root.searching && !root.paged
        readonly property bool found: !root.searching || (root.host?.matchedSections?.has(key.areaId) ?? false)
        readonly property bool open: key.on || root.named === key.areaId
        readonly property int noted: Number(root.noteCounts[key.areaId] ?? 0)
        width: key.open ? keyName.implicitWidth + root.u(48) : root.u(38)
        height: root.u(38)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        opacity: key.found ? 1 : 0.35
        Accessible.role: Accessible.PageTab
        Accessible.name: Translation.tr(String(key.entry.title ?? ""))
        Accessible.checked: key.on
        Behavior on width { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        onContainsMouseChanged: {
            if (key.containsMouse) {
                root.resting = key.areaId
                if (root.named.length > 0) root.named = key.areaId
                else nameSoon.restart()
            } else if (root.resting === key.areaId) {
                root.resting = ""
                Qt.callLater(() => { if (root.resting.length === 0) { nameSoon.stop(); root.named = "" } })
            }
        }
        onClicked: root.host.selectSection(key.areaId)
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.capsule(height)
            color: key.on ? IrisStyle.text : key.containsMouse || key.open ? IrisStyle.fillHover : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        }
        MaterialSymbol {
            id: keyGlyph
            x: (root.u(38) - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            text: String(key.entry.icon ?? "settings")
            iconSize: root.u(19)
            fill: key.on ? 1 : 0
            color: key.on ? IrisStyle.surfaceOpaque : key.open ? IrisStyle.text : IrisStyle.subtext
        }
        IrisText {
            id: keyName
            x: root.u(36)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - x - root.u(12))
            clip: true
            opacity: key.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
            text: Translation.tr(String(key.entry.title ?? ""))
            color: key.on ? IrisStyle.surfaceOpaque : IrisStyle.text
            font.pixelSize: IrisStyle.typeMeta
            font.weight: Font.DemiBold
        }
        Rectangle {
            visible: key.noted > 0
            x: root.u(26)
            y: root.u(7)
            width: root.u(7)
            height: width
            radius: width / 2
            color: root.signal
        }
    }

    component HeadKey: MouseArea {
        id: key
        property string glyph
        property string name
        Layout.preferredWidth: root.u(36)
        Layout.preferredHeight: root.u(36)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.name
        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: key.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet }
        MaterialSymbol { anchors.centerIn: parent; text: key.glyph; iconSize: root.u(18); color: IrisStyle.text }
    }
}
