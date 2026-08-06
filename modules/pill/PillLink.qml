pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import qs.modules.common
import qs.services

/**
 * 繋 LINK surface: connectivity rows (auto-detected Netz, Bluetooth) over the
 * 報 INBOX notification center, with WLAN and Bluetooth drill-in subviews that
 * cross-fade in place. Owns the `subview` state machine and exposes
 * `desiredW` and `back()` for the pill's morph and Escape plumbing. Opening marks all
 * notifications seen after a short beat so unread embers register first.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 16
    mRight: 16
    mBottom: 13

    property string subview: "main"

    /**
     * Subview to land on the next time the surface opens. The pill sets this from
     * the glance that opened the surface (wifi → "wifi", inbox → "main") so the
     * wifi glance drills straight to the network list past the connectivity rows.
     */
    property string initialView: "main"

    readonly property real desiredW: (subview === "wifi" ? 272 : subview === "bt" ? 286 : 330) * s

    /**
     * Row-soul focus registry. Each hoverable row reports itself here; the bead
     * docks as a glowing seam at the left edge of the focused row and hides
     * when nothing is focused. Only the main subview participates.
     */
    property Item focusRowItem: null

    /**
     * Sticky: once a row has been focused the seam stays parked on it when the
     * pointer leaves, gliding to the next focused row instead of re-waking
     * from the pill centre on every hover. Cleared only when the surface
     * closes.
     */
    function reportRowHover(item, hovered) {
        if (hovered)
            focusRowItem = item;
    }

    readonly property bool rowFocused: focusRowItem !== null && subview === "main" && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void mainCol.implicitHeight;
        void root.focusRowItem;
        if (!focusRowItem)
            return Qt.point(4 * s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint

    implicitHeight: subview === "wifi" ? wifiPage.implicitHeight
        : subview === "bt" ? btPage.implicitHeight
        : mainCol.implicitHeight

    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var eth: netDevices.find(function(d) { return d && d.type === DeviceType.Wired && d.connected }) || null
    readonly property var wifiDev: netDevices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wired: eth !== null

    readonly property real ethSpeed: (eth && eth.linkSpeed) ? eth.linkSpeed : 0
    readonly property string ethSpeedText: ethSpeed > 0
        ? (ethSpeed >= 1000 ? (ethSpeed / 1000).toFixed(ethSpeed % 1000 === 0 ? 0 : 1) + " Gb/s" : ethSpeed + " Mb/s")
        : ""

    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(function(n) { return n && n.connected }) || null

    readonly property string netzSubText: wired
        ? ("Ethernet"
            + (ethSpeedText.length ? " · " + ethSpeedText : "")
            + (ethIp.length ? " · " + ethIp : ""))
        : (wifiActive ? (wifiActive.name || "") : (wifiOn ? Translation.tr("Not connected") : Translation.tr("Off")))

    readonly property var btAdapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
    readonly property var btDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []
    readonly property var btConnected: btDevices.filter(function(d) { return d && d.connected })
    readonly property bool btOn: btAdapter ? btAdapter.enabled === true : false
    readonly property var btPrimary: btConnected.length > 0 ? btConnected[0] : null
    readonly property int btBattery: batteryLevel(btPrimary)

    readonly property string btSubText: !btOn ? "Off"
        : (btPrimary
            ? ((btPrimary.deviceName || btPrimary.name || "Unknown")
                + (btConnected.length > 1 ? " +" + (btConnected.length - 1) : ""))
            : "Not connected")

    property string ethIp: ""

    /**
     * Pops one navigation level: drill-in back to main returns true, main
     * returns false so the caller closes the surface instead.
     */
    function back() {
        if (subview !== "main") {
            subview = "main";
            return true;
        }
        return false;
    }

    function batteryLevel(d) {
        if (!d || d.battery === undefined || d.battery === null) return -1;
        var b = d.battery;
        if (b <= 0) return -1;
        if (b <= 1) b = b * 100;
        return Math.round(b);
    }

    onActiveChanged: {
        if (active) {
            subview = (initialView === "wifi" && wifiDev) ? "wifi" : "main";
            seenTimer.restart();
        } else {
            seenTimer.stop();
            focusRowItem = null;
        }
    }

    Timer {
        id: seenTimer
        interval: 600
        repeat: false
        onTriggered: PillNotifs.markAllSeen()
    }

    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 -o addr show scope global up | awk '{for(i=1;i<=NF;i++) if($i==\"inet\"){print $(i+1); exit}}' | cut -d/ -f1"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.ethIp = this.text.trim() }
    }

    Timer {
        interval: 15000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: ipProc.running = true
    }

    /**
     * Ember mark: a small flame-glow dot over a soft halo, the unread marker
     * shared by the header badge and unread notification titles.
     */
    component Ember: Item {
        id: ember
        property real size: 4 * root.s

        width: size * 2.2
        height: size * 2.2

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: PillTheme.flameGlow
            opacity: 0.22
        }

        Rectangle {
            anchors.centerIn: parent
            width: ember.size
            height: ember.size
            radius: width / 2
            color: PillTheme.flameGlow
        }
    }

    /**
     * Single inbox entry: icon tile or diamond, body text, ×N coalesce badge,
     * age label that cross-fades into a dismiss glyph on hover. Critical
     * entries gain a vermilion left hairline and cream emphasis.
     */
    component NotifRow: Rectangle {
        id: nrow

        required property var entry
        property bool critical: false
        readonly property var n: entry.n

        width: parent ? parent.width : 0
        height: 26 * root.s
        radius: 7 * root.s
        color: nrowHover.hovered ? PillTheme.frameBg : "transparent"

        HoverHandler {
            id: nrowHover
            onHoveredChanged: root.reportRowHover(nrow, hovered)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                PillNotifs.activateEntry(nrow.entry);
                root.requestClose();
            }
        }

        Rectangle {
            visible: nrow.critical
            anchors.left: parent.left
            anchors.leftMargin: 1 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 2 * root.s
            height: parent.height - 10 * root.s
            radius: 999
            color: PillTheme.verm
        }

        Rectangle {
            id: nrowTile
            anchors.left: parent.left
            anchors.leftMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            radius: 5 * root.s
            color: PillTheme.tileBg
            border.width: 1
            border.color: PillTheme.border

            Image {
                id: nrowImg
                anchors.fill: parent
                anchors.margins: nrow.n.image ? 0 : 2 * root.s
                source: PillNotifs.iconFor(nrow.n)
                sourceSize.width: 40
                sourceSize.height: 40
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: source.toString().length > 0
            }

            Rectangle {
                anchors.centerIn: parent
                visible: !nrowImg.visible
                width: 5 * root.s
                height: 5 * root.s
                radius: 1.5 * root.s
                rotation: 45
                color: nrow.critical ? PillTheme.vermLit : PillTheme.verm
            }
        }

        Text {
            anchors.left: nrowTile.right
            anchors.leftMargin: 8 * root.s
            anchors.right: nrowRight.left
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: nrow.n.body.length > 0 ? nrow.n.body : nrow.n.summary
            color: nrow.critical ? PillTheme.cream : PillTheme.subtle
            font.family: PillTheme.font
            font.pixelSize: 10.5 * root.s
            font.weight: nrow.critical ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }

        Row {
            id: nrowRight
            anchors.right: parent.right
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s

            Text {
                visible: nrow.entry.count > 1
                anchors.verticalCenter: parent.verticalCenter
                text: "×" + nrow.entry.count
                color: nrow.critical ? PillTheme.vermLit : PillTheme.vermDim
                font.family: PillTheme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Bold
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(nrowAge.implicitWidth, nrowX.implicitWidth)
                height: Math.max(nrowAge.implicitHeight, nrowX.implicitHeight)

                Text {
                    id: nrowAge
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: nrowHover.hovered ? 0 : 1
                    text: PillNotifs.ageLabel(nrow.n)
                    color: PillTheme.faint
                    font.family: PillTheme.font
                    font.pixelSize: 9 * root.s
                    Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
                }

                GlyphIcon {
                    id: nrowX
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 11 * root.s
                    height: 11 * root.s
                    opacity: nrowHover.hovered ? 1 : 0
                    name: "close"
                    color: nrowXArea.containsMouse ? PillTheme.cream : PillTheme.dim
                    stroke: 1.9
                    Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

                    MouseArea {
                        id: nrowXArea
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        enabled: nrowHover.hovered
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PillNotifs.dismissEntry(nrow.entry)
                    }
                }
            }
        }
    }

    Item {
        id: mainView
        anchors.fill: parent
        opacity: root.subview === "main" ? 1 : 0
        visible: opacity > 0.01
        enabled: root.subview === "main" && root.active
        Behavior on opacity {
            NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard }
        }

        Column {
            id: mainCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4 * root.s

            Item {
                width: parent.width
                height: 24 * root.s

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * root.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PillTheme.showGlyphs
                        text: PillTheme.glyph("link")
                        color: PillTheme.cream
                        font.family: PillTheme.fontJp
                        font.weight: Font.Medium
                        font.pixelSize: 16 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("LINK")
                        color: PillTheme.subtle
                        font.family: PillTheme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.6 * root.s
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * root.s
                    visible: PillNotifs.unread > 0

                    Ember {
                        id: headerEmber
                        anchors.verticalCenter: parent.verticalCenter
                        size: 6 * root.s

                        SequentialAnimation on opacity {
                            running: headerEmber.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.55; to: 1; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1; to: 0.55; duration: 1200; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PillNotifs.unread + " NEW"
                        color: PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4 * root.s
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: PillTheme.hair
            }

            Rectangle {
                id: netzRow
                width: parent.width
                height: 44 * root.s
                radius: 10 * root.s
                color: netzHover.hovered ? PillTheme.frameBg : "transparent"

                HoverHandler {
                    id: netzHover
                    onHoveredChanged: root.reportRowHover(netzRow, hovered)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.subview = "wifi"
                }

                GlyphIcon {
                    id: netzGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: root.wired ? "ethernet" : "wifi"
                    color: !root.wired && root.wifiOn ? PillTheme.vermLit : PillTheme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: netzGlyph.right
                    anchors.leftMargin: 11 * root.s
                    anchors.right: netzRight.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        width: parent.width
                        text: Translation.tr("Network")
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.netzSubText
                        color: !root.wired && root.wifiActive ? PillTheme.vermLit : PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 10 * root.s
                        font.weight: !root.wired && root.wifiActive ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: netzRight
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9 * root.s

                    Filament {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.wired && root.wifiOn && root.wifiActive !== null
                        s: root.s
                        kind: "signal"
                        level: (root.wifiActive && root.wifiActive.signalStrength) || 0
                    }

                    LinkToggle {
                        s: root.s
                        visible: !root.wired
                        anchors.verticalCenter: parent.verticalCenter
                        on: root.wifiOn
                        onToggled: {
                            if (typeof Networking !== "undefined" && Networking)
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                        }
                    }

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "chevron-right"
                        color: PillTheme.iconDim
                        stroke: 1.8
                    }
                }
            }

            Rectangle {
                id: btRow
                width: parent.width
                height: 44 * root.s
                radius: 10 * root.s
                color: btHover.hovered ? PillTheme.frameBg : "transparent"

                HoverHandler {
                    id: btHover
                    onHoveredChanged: root.reportRowHover(btRow, hovered)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.subview = "bt"
                }

                GlyphIcon {
                    id: btGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: "bluetooth"
                    color: root.btConnected.length > 0 ? PillTheme.vermLit : PillTheme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: btGlyph.right
                    anchors.leftMargin: 11 * root.s
                    anchors.right: btRight.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        width: parent.width
                        text: Translation.tr("Bluetooth")
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.btSubText
                        color: root.btPrimary ? PillTheme.vermLit : PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 10 * root.s
                        font.weight: root.btPrimary ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: btRight
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9 * root.s

                    Filament {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.btPrimary !== null && root.btBattery >= 0
                        s: root.s
                        kind: "battery"
                        level: Math.max(0, root.btBattery) / 100
                    }

                    LinkToggle {
                        s: root.s
                        anchors.verticalCenter: parent.verticalCenter
                        on: root.btOn
                        onToggled: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
                    }

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "chevron-right"
                        color: PillTheme.iconDim
                        stroke: 1.8
                    }
                }
            }

            Item {
                width: parent.width
                height: 20 * root.s

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * root.s

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10 * root.s
                        height: 10 * root.s
                    }

                    Text {
                        id: inboxKanji
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PillTheme.showGlyphs
                        text: PillTheme.glyph("notify")
                        color: PillTheme.dim
                        font.family: PillTheme.fontJp
                        font.weight: Font.Medium
                        font.pixelSize: 11.5 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: PillTheme.showGlyphs ? "INBOX" : "Notifications"
                        color: PillTheme.faint
                        font.family: PillTheme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: PillTheme.showGlyphs ? 1.8 * root.s : 0.8 * root.s
                    }
                }

                Row {
                    id: clearRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: PillNotifs.count > 0
                    spacing: 4 * root.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: PillTheme.showGlyphs
                        text: PillTheme.glyph("clear")
                        color: clearArea.containsMouse ? PillTheme.vermLit : PillTheme.vermDim
                        font.family: PillTheme.fontJp
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Bold
                    }
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !PillTheme.showGlyphs
                        width: 11 * root.s
                        height: 11 * root.s
                        name: "trash"
                        color: clearArea.containsMouse ? PillTheme.vermLit : PillTheme.vermDim
                        stroke: 1.8
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("CLEAR")
                        color: clearArea.containsMouse ? PillTheme.vermLit : PillTheme.vermDim
                        font.family: PillTheme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4 * root.s
                    }
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: clearRow
                    anchors.margins: -5 * root.s
                    visible: PillNotifs.count > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PillNotifs.clearAll()
                }
            }

            Item {
                visible: PillNotifs.count > 0
                width: parent.width
                height: notifFlick.height

                Flickable {
                    id: notifFlick
                    width: parent.width
                    height: Math.min(notifCol.implicitHeight, 320 * root.s)
                    contentHeight: notifCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: returnToBounds()

                    Column {
                        id: notifCol
                        width: notifFlick.width
                        spacing: 6 * root.s

                        Repeater {
                            model: PillNotifs.groups

                            Column {
                                id: group
                                required property var modelData
                                readonly property bool expanded: PillNotifs.expandedApps[modelData.app] === true
                                width: notifCol.width
                                spacing: 2 * root.s

                                Repeater {
                                    model: group.modelData.criticals

                                    NotifRow {
                                        required property var modelData
                                        entry: modelData
                                        critical: true
                                    }
                                }

                                Rectangle {
                                    id: groupHead
                                    width: parent.width
                                    height: 32 * root.s
                                    radius: 8 * root.s
                                    color: headHover.hovered ? PillTheme.frameBg : "transparent"

                                    HoverHandler {
                                        id: headHover
                                        onHoveredChanged: root.reportRowHover(groupHead, hovered)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: PillNotifs.toggleExpanded(group.modelData.app)
                                    }

                                    Rectangle {
                                        id: headTile
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20 * root.s
                                        height: 20 * root.s
                                        radius: 6 * root.s
                                        color: PillTheme.tileBg
                                        border.width: 1
                                        border.color: PillTheme.border

                                        Image {
                                            id: headImg
                                            anchors.fill: parent
                                            anchors.margins: group.modelData.newest.image ? 0 : 3 * root.s
                                            source: PillNotifs.iconFor(group.modelData.newest)
                                            sourceSize.width: 40
                                            sourceSize.height: 40
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true
                                            visible: source.toString().length > 0
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            visible: !headImg.visible
                                            width: 6 * root.s
                                            height: 6 * root.s
                                            radius: 2 * root.s
                                            rotation: 45
                                            color: PillTheme.verm
                                        }
                                    }

                                    Text {
                                        id: headName
                                        anchors.left: headTile.right
                                        anchors.leftMargin: 8 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, 110 * root.s)
                                        text: group.modelData.app
                                        color: PillTheme.subtle
                                        font.family: PillTheme.font
                                        font.pixelSize: 9 * root.s
                                        font.weight: Font.Bold
                                        font.capitalization: Font.AllUppercase
                                        font.letterSpacing: 1.2 * root.s
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: headCount
                                        anchors.left: headName.right
                                        anchors.leftMargin: 5 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "· " + group.modelData.count
                                        color: PillTheme.faint
                                        font.family: PillTheme.font
                                        font.pixelSize: 9 * root.s
                                    }

                                    Text {
                                        anchors.left: headCount.right
                                        anchors.leftMargin: 8 * root.s
                                        anchors.right: headX.left
                                        anchors.rightMargin: 8 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: group.modelData.preview.body.length > 0
                                            ? group.modelData.preview.body
                                            : group.modelData.preview.summary
                                        color: PillTheme.dim
                                        font.family: PillTheme.font
                                        font.pixelSize: 10 * root.s
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        textFormat: Text.PlainText
                                    }

                                    GlyphIcon {
                                        id: headChev
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 11 * root.s
                                        height: 11 * root.s
                                        name: group.expanded ? "chevron-down" : "chevron-right"
                                        color: PillTheme.faint
                                        stroke: 2
                                    }

                                    GlyphIcon {
                                        id: headX
                                        anchors.right: headChev.left
                                        anchors.rightMargin: 7 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 11 * root.s
                                        height: 11 * root.s
                                        opacity: headHover.hovered ? 1 : 0
                                        name: "close"
                                        color: headXArea.containsMouse ? PillTheme.cream : PillTheme.dim
                                        stroke: 1.9
                                        Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }

                                        MouseArea {
                                            id: headXArea
                                            anchors.fill: parent
                                            anchors.margins: -6 * root.s
                                            enabled: headHover.hovered
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: PillNotifs.dismissApp(group.modelData.app)
                                        }
                                    }
                                }

                                Column {
                                    visible: group.expanded
                                    width: parent.width
                                    spacing: 2 * root.s

                                    Repeater {
                                        model: group.expanded ? group.modelData.entries : []

                                        NotifRow {
                                            required property var modelData
                                            entry: modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                WheelScroller {
                    anchors.fill: parent
                    s: root.s
                    flick: notifFlick
                }
            }

            Column {
                visible: PillNotifs.count === 0
                width: parent.width
                topPadding: 14 * root.s
                bottomPadding: 14 * root.s
                spacing: 4 * root.s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: PillTheme.showGlyphs
                    text: PillTheme.glyph("dnd")
                    color: PillTheme.ghost
                    opacity: 0.55
                    font.family: PillTheme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 32 * root.s
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: PillTheme.showGlyphs ? "SILENCE" : "No notifications to display"
                    color: PillTheme.faint
                    font.family: PillTheme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                    font.letterSpacing: PillTheme.showGlyphs ? 2.2 * root.s : 0.8 * root.s
                }
            }
        }
    }

    LinkWifi {
        id: wifiPage
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        active: root.active && root.subview === "wifi"
        opacity: root.subview === "wifi" ? 1 : 0
        visible: opacity > 0.01
        enabled: root.subview === "wifi" && root.active
        Behavior on opacity {
            NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard }
        }
        onBack: root.subview = "main"
    }

    LinkBt {
        id: btPage
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        active: root.active && root.subview === "bt"
        opacity: root.subview === "bt" ? 1 : 0
        visible: opacity > 0.01
        enabled: root.subview === "bt" && root.active
        Behavior on opacity {
            NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard }
        }
        onBack: root.subview = "main"
    }
}
