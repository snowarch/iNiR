pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.modules.common
import qs.services

/**
 * WLAN drill-in for the link surface: back chevron, wifi enable toggle and the
 * live network list sorted by signal strength. Security and known-profile
 * ground truth come from nmcli; clicking a secured unknown network expands an
 * inline password row that connects through `nmcli dev wifi connect`. The pill
 * body provides the surface material, so this item draws no background.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    signal back()

    readonly property var devices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: devices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var nets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var netsSorted: nets.slice().sort(function(a, b) {
        return ((b ? b.signalStrength : 0) || 0) - ((a ? a.signalStrength : 0) || 0)
    })
    readonly property var activeNet: nets.find(function(n) { return n && n.connected }) || null
    readonly property string statusText: !wifiOn ? "Off"
        : (activeNet ? (activeNet.name || "Connected") : "Not connected")

    property var securityMap: ({})
    property var knownProfiles: ({})
    property string expandedSsid: ""
    property bool connecting: false
    property bool connectFailed: false
    property bool scanning: false

    /**
     * SSID of the saved network whose stored password is currently shown, plus
     * the revealed secret itself. Keying both to one SSID keeps the reveal local
     * to the row the user asked about and lets `revealResolved` distinguish "not
     * yet read" from "read but empty" so an open profile shows a clear message.
     */
    property string revealedSsid: ""
    property string revealedPw: ""
    property bool revealResolved: false

    readonly property string hsCon: "RicelinHotspot"
    readonly property string hsIface: wifiDev ? (wifiDev.name || "wlan0") : "wlan0"
    property string hsName: "Ricelin"
    property string hsPw: ""
    property bool hsActive: false
    property bool hsBusy: false
    property string hsEdit: ""
    property string hsDraft: ""

    /**
     * Draft of the password being typed for `expandedSsid`. Lives on the root so
     * the field can restore itself from the draft if the keyed list model swaps
     * the delegate's network object under it on a rescan.
     */
    property string pwDraft: ""
    property string pendingPw: ""
    property string attemptSsid: ""
    property bool attemptWasKnown: false

    implicitHeight: hsBlock.y + hsBlock.height

    function isSecured(ssid) {
        var sec = securityMap[ssid];
        return sec !== undefined && sec !== "" && sec !== "--";
    }

    function refresh() {
        secProc.running = true;
        profProc.running = true;
    }

    /**
     * Splits one `nmcli -t` line at its last unescaped colon and unescapes the
     * leading field. Returns null for lines without a field separator.
     */
    function splitTerse(line) {
        for (var k = line.length - 1; k >= 0; k--) {
            if (line[k] === ":" && (k === 0 || line[k - 1] !== "\\"))
                return { head: line.slice(0, k).replace(/\\:/g, ":"), tail: line.slice(k + 1) };
        }
        return null;
    }

    /**
     * Click dispatch for a network row. A connected or saved network expands the
     * inline confirm row (disconnect/connect plus forget) rather than acting at
     * once; an open unknown network connects directly; an unknown secured network
     * expands the password row. Tapping the open row again collapses it.
     */
    function activateNetwork(net) {
        if (!net)
            return;
        var ssid = net.name || "";
        if (expandedSsid === ssid && ssid.length) {
            expandedSsid = "";
            return;
        }
        if (net.connected || knownProfiles[ssid] === true) {
            connectFailed = false;
            pwDraft = "";
            expandedSsid = ssid;
            return;
        }
        if (!isSecured(ssid)) {
            expandedSsid = "";
            if (typeof net.connect === "function")
                net.connect();
            refresh();
            return;
        }
        connectFailed = false;
        pwDraft = "";
        expandedSsid = ssid;
    }

    /**
     * Connects a saved profile from its confirm row. Known profiles connect by
     * name through the device so no password prompt is needed.
     */
    function connectKnown(net) {
        if (!net)
            return;
        expandedSsid = "";
        if (typeof net.connect === "function")
            net.connect();
        refresh();
    }

    function disconnectNetwork(net) {
        if (!net)
            return;
        expandedSsid = "";
        if (typeof net.disconnect === "function")
            net.disconnect();
        refresh();
    }

    /**
     * Drops the saved connection profile for `ssid`. The SSID is passed as its
     * own argv element so an odd character can neither break nor inject the
     * command. The list refreshes once nmcli exits.
     */
    function forgetNetwork(ssid) {
        if (forgetProc.running || !ssid.length)
            return;
        expandedSsid = "";
        forgetProc.command = ["nmcli", "connection", "delete", "id", ssid];
        forgetProc.running = true;
    }

    /**
     * Reveals the stored password of a saved profile, or hides it again if the
     * same row is already showing. NetworkManager lets the owning user read their
     * own saved secret without root, so this runs unprivileged. The SSID is
     * passed as its own argv element so an odd character can neither break nor
     * inject the command.
     */
    function revealPassword(ssid) {
        if (!ssid.length)
            return;
        if (revealedSsid === ssid) {
            hidePassword();
            return;
        }
        revealedSsid = ssid;
        revealedPw = "";
        revealResolved = false;
        revealProc.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", "id", ssid];
        revealProc.running = true;
    }

    function hidePassword() {
        revealedSsid = "";
        revealedPw = "";
        revealResolved = false;
    }

    /**
     * Connects via `nmcli --ask`, feeding the password through stdin so the
     * secret never appears in the process command line (`/proc/<pid>/cmdline`
     * is world-readable for the whole connection attempt).
     */
    function connectWithPassword(ssid, pw) {
        if (connProc.running || !pw.length)
            return;
        connecting = true;
        connectFailed = false;
        attemptSsid = ssid;
        attemptWasKnown = knownProfiles[ssid] === true;
        pendingPw = pw;
        connProc.command = ["nmcli", "--ask", "dev", "wifi", "connect", ssid];
        connProc.running = true;
    }

    /**
     * Reload pulse: forces a fresh nmcli rescan and spins the control for up to
     * 10s. The device scanner already runs while the drill-in is open, so the
     * list never empties; this only refreshes results and drives the spinner.
     */
    function startScan() {
        if (!wifiOn)
            return;
        scanning = true;
        rescanProc.running = true;
        scanTimer.restart();
    }

    function stopScan() {
        scanning = false;
        scanTimer.stop();
    }

    onActiveChanged: {
        if (active) {
            refresh();
            refreshHotspot();
        } else {
            stopScan();
            expandedSsid = "";
            connectFailed = false;
            hsEdit = "";
            hidePassword();
        }
    }

    onWifiOnChanged: if (!wifiOn) stopScan()

    onExpandedSsidChanged: if (revealedSsid !== expandedSsid) hidePassword()

    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.active && root.wifiOn
        when: root.wifiDev !== null
    }

    Timer {
        id: scanTimer
        interval: 10000
        onTriggered: root.stopScan()
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
    }

    /**
     * Brings the shared AP up with the current name and password, creating the
     * persistent connection on first use and modifying it on later changes. Name
     * and password are passed as positional arguments, never spliced into the
     * shell string, so an odd character cannot break or inject the command.
     */
    function applyHotspot() {
        if (hsBusy || hsPw.length < 8)
            return;
        hsBusy = true;
        hsApplyProc.command = ["sh", "-c",
            'c="' + hsCon + '"; '
            + 'if nmcli -t connection show "$c" >/dev/null 2>&1; then '
            +   'nmcli connection modify "$c" 802-11-wireless.ssid "$1" 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$2"; '
            + 'else '
            +   'nmcli connection add type wifi ifname "$3" con-name "$c" autoconnect no 802-11-wireless.ssid "$1" 802-11-wireless.mode ap 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$2" ipv4.method shared; '
            + 'fi; '
            + 'nmcli connection up "$c"',
            "sh", hsName, hsPw, hsIface];
        hsApplyProc.running = true;
    }

    function stopHotspot() {
        if (hsBusy)
            return;
        hsBusy = true;
        hsDownProc.running = true;
    }

    function refreshHotspot() {
        hsStateProc.running = true;
        hsReadProc.running = true;
    }

    /**
     * Commits an inline name or password edit, ignoring a password shorter than
     * the 8-character WPA2 minimum. A live hotspot is re-applied so the change
     * takes effect at once.
     */
    function commitHotspotEdit() {
        if (hsEdit === "name") {
            if (hsDraft.length)
                hsName = hsDraft;
        } else if (hsEdit === "pw") {
            if (hsDraft.length >= 8)
                hsPw = hsDraft;
        }
        hsEdit = "";
        if (hsActive)
            applyHotspot();
    }

    /**
     * Builds an eight-character WPA2 password from an unambiguous alphabet, used
     * when the hotspot is switched on before a password has been set.
     */
    function generatePw() {
        var cs = "abcdefghijkmnpqrstuvwxyz23456789";
        var s = "";
        for (var i = 0; i < 8; i++)
            s += cs.charAt(Math.floor(Math.random() * cs.length));
        return s;
    }

    Process {
        id: hsApplyProc
        onExited: {
            root.hsBusy = false;
            root.refreshHotspot();
        }
    }

    Process {
        id: hsDownProc
        command: ["nmcli", "connection", "down", root.hsCon]
        onExited: {
            root.hsBusy = false;
            root.refreshHotspot();
        }
    }

    Process {
        id: hsStateProc
        command: ["sh", "-c", "nmcli -t -f NAME connection show --active | grep -qx \"$1\" && echo on || echo off", "sh", root.hsCon]
        stdout: StdioCollector {
            onStreamFinished: root.hsActive = this.text.trim() === "on"
        }
    }

    Process {
        id: hsReadProc
        command: ["nmcli", "-t", "-s", "-g", "802-11-wireless.ssid,802-11-wireless-security.psk", "connection", "show", root.hsCon]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                if (lines.length >= 1 && lines[0].length)
                    root.hsName = lines[0];
                if (lines.length >= 2 && lines[1].length)
                    root.hsPw = lines[1];
            }
        }
    }

    Process {
        id: secProc
        command: ["nmcli", "-t", "-f", "SSID,SECURITY", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i].length)
                        continue;
                    var parts = root.splitTerse(lines[i]);
                    if (parts && parts.head.length)
                        map[parts.head] = parts.tail;
                }
                root.securityMap = map;
            }
        }
    }

    Process {
        id: profProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var set = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = root.splitTerse(lines[i]);
                    if (parts && parts.head.length && parts.tail === "802-11-wireless")
                        set[parts.head] = true;
                }
                root.knownProfiles = set;
            }
        }
    }

    Process {
        id: connProc
        stdinEnabled: true
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onStarted: {
            write(root.pendingPw + "\n");
            root.pendingPw = "";
        }
        onExited: function(exitCode) {
            root.connecting = false;
            if (exitCode === 0) {
                root.expandedSsid = "";
                root.pwDraft = "";
                root.connectFailed = false;
                root.refresh();
            } else {
                root.connectFailed = true;
                if (!root.attemptWasKnown && root.attemptSsid.length) {
                    cleanupProc.command = ["nmcli", "connection", "delete", "id", root.attemptSsid];
                    cleanupProc.running = true;
                }
            }
        }
    }

    /**
     * A failed `nmcli dev wifi connect` still leaves a connection profile
     * named after the SSID behind; without deleting it the network would be
     * treated as known on the next click and silently fail forever.
     */
    Process {
        id: cleanupProc
        onExited: root.refresh()
    }

    /**
     * Drops a saved profile on Forget. The list refreshes on exit so the row
     * loses its known/connected state and its lock falls back to dim.
     */
    Process {
        id: forgetProc
        onExited: root.refresh()
    }

    /**
     * Reads one saved profile's PSK on demand. The result is held only as long as
     * the row stays open; an empty result means the profile is open or stores no
     * recoverable secret, surfaced by the row as a plain note.
     */
    Process {
        id: revealProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.revealedPw = this.text.replace(/\n+$/, "");
                root.revealResolved = true;
            }
        }
    }

    onNetsChanged: if (active) secRefresh.restart()

    Timer {
        id: secRefresh
        interval: 1200
        onTriggered: if (root.active) secProc.running = true
    }

    /**
     * Keys the network list by SSID so a rescan diffs into the existing rows
     * rather than tearing every delegate down and rebuilding it. Delegates keep
     * their identity across scans, so the inline confirm or password row stays
     * open under the network the user tapped.
     */
    ScriptModel {
        id: netModel
        objectProp: "name"
        values: root.netsSorted
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 17 * root.s
                height: 17 * root.s

                GlyphIcon {
                    anchors.fill: parent
                    name: "chevron-left"
                    color: backArea.containsMouse ? PillTheme.cream : PillTheme.iconDim
                    stroke: 1.8
                }

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("WIFI")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "· " + root.statusText
                color: root.activeNet ? PillTheme.vermLit : PillTheme.faint
                font.family: PillTheme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * root.s

            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.wifiOn
                width: 16 * root.s
                height: 16 * root.s

                GlyphIcon {
                    id: reloadGlyph
                    anchors.fill: parent
                    name: "reboot"
                    color: root.scanning ? PillTheme.flameGlow : (reloadArea.containsMouse ? PillTheme.cream : PillTheme.iconDim)
                    stroke: 1.8

                    RotationAnimator {
                        target: reloadGlyph
                        running: root.scanning
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) reloadGlyph.rotation = 0
                    }
                }

                MouseArea {
                    id: reloadArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.scanning ? root.stopScan() : root.startScan()
                }
            }

            LinkToggle {
                s: root.s
                anchors.verticalCenter: parent.verticalCenter
                on: root.wifiOn
                onToggled: {
                    if (typeof Networking !== "undefined" && Networking)
                        Networking.wifiEnabled = !Networking.wifiEnabled;
                }
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: PillTheme.hair
    }

    Item {
        id: listFrame
        anchors.top: divider.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.wifiOn ? Math.min(Math.max(netCol.implicitHeight, 26 * root.s), 280 * root.s) : 0

        Text {
            anchors.centerIn: parent
            visible: root.wifiOn && root.nets.length === 0
            text: Translation.tr("Searching networks…")
            color: PillTheme.faint
            font.family: PillTheme.font
            font.pixelSize: 10.5 * root.s
        }

        Flickable {
            id: netFlick
            anchors.fill: parent
            contentHeight: netCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: netCol
                width: netFlick.width
                spacing: 2 * root.s

                Repeater {
                    model: netModel

                    Column {
                        id: netItem
                        required property var modelData
                        readonly property string ssid: (modelData && modelData.name) ? modelData.name : ""
                        readonly property bool isActive: modelData ? modelData.connected === true : false
                        readonly property bool secured: root.isSecured(ssid)
                        readonly property bool known: root.knownProfiles[ssid] === true
                        readonly property bool expanded: ssid.length > 0 && root.expandedSsid === ssid
                        readonly property bool confirming: expanded && (isActive || known)
                        readonly property bool asking: expanded && !confirming
                        width: netCol.width
                        spacing: 2 * root.s

                        function syncPwField() {
                            pwField.text = root.pwDraft;
                            pwField.cursorPosition = pwField.text.length;
                            pwField.forceActiveFocus();
                        }

                        onExpandedChanged: if (asking) Qt.callLater(syncPwField)
                        Component.onCompleted: if (asking) Qt.callLater(syncPwField)

                        Rectangle {
                            width: parent.width
                            height: 30 * root.s
                            radius: 9 * root.s
                            color: netItem.isActive ? Qt.rgba(PillTheme.verm.r, PillTheme.verm.g, PillTheme.verm.b, 0.14)
                                : (rowHover.hovered ? PillTheme.frameBg : "transparent")

                            HoverHandler { id: rowHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateNetwork(netItem.modelData)
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: rowRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: netItem.ssid.length ? netItem.ssid : "Hidden"
                                color: netItem.isActive ? PillTheme.vermLit : PillTheme.subtle
                                font.family: PillTheme.font
                                font.pixelSize: 11.5 * root.s
                                font.weight: netItem.isActive ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                            }

                            Row {
                                id: rowRight
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7 * root.s

                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -1.4 * root.s
                                    visible: netItem.secured
                                    width: 14 * root.s
                                    height: 14 * root.s

                                    GlyphIcon {
                                        anchors.fill: parent
                                        name: "lock-outline"
                                        color: netItem.isActive ? PillTheme.vermLit : PillTheme.iconDim
                                        stroke: 1.9
                                    }
                                }

                                WifiGlyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15 * root.s
                                    height: 15 * root.s
                                    s: root.s
                                    on: true
                                    level: (netItem.modelData && netItem.modelData.signalStrength) || 0
                                }
                            }
                        }

                        Item {
                            visible: netItem.confirming
                            width: parent.width
                            height: 30 * root.s

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: confirmBtns.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: netItem.isActive ? "Connected" : "Saved network"
                                color: PillTheme.faint
                                font.family: PillTheme.font
                                font.pixelSize: 9.5 * root.s
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Row {
                                id: confirmBtns
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6 * root.s

                                Rectangle {
                                    id: primaryBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: primaryLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 7 * root.s
                                    color: primaryArea.containsMouse ? PillTheme.tileBg : "transparent"
                                    border.width: 1
                                    border.color: primaryArea.containsMouse ? PillTheme.vermDim : PillTheme.border

                                    Text {
                                        id: primaryLabel
                                        anchors.centerIn: parent
                                        text: netItem.isActive ? "Disconnect" : "Connect"
                                        color: PillTheme.cream
                                        font.family: PillTheme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.3 * root.s
                                    }

                                    MouseArea {
                                        id: primaryArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: netItem.isActive
                                            ? root.disconnectNetwork(netItem.modelData)
                                            : root.connectKnown(netItem.modelData)
                                    }
                                }

                                Rectangle {
                                    id: revealBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: netItem.known
                                    readonly property bool shown: root.revealedSsid === netItem.ssid
                                    width: revealLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 7 * root.s
                                    color: revealArea.containsMouse ? PillTheme.tileBg : "transparent"
                                    border.width: 1
                                    border.color: revealBtn.shown
                                        ? PillTheme.vermDim
                                        : (revealArea.containsMouse ? PillTheme.vermDim : PillTheme.border)

                                    Text {
                                        id: revealLabel
                                        anchors.centerIn: parent
                                        text: revealBtn.shown ? "Hide" : "Show"
                                        color: PillTheme.cream
                                        font.family: PillTheme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.3 * root.s
                                    }

                                    MouseArea {
                                        id: revealArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.revealPassword(netItem.ssid)
                                    }
                                }

                                Rectangle {
                                    id: forgetBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: forgetLabel.implicitWidth + 20 * root.s
                                    height: 22 * root.s
                                    radius: 7 * root.s
                                    color: forgetArea.containsMouse
                                        ? Qt.rgba(PillTheme.verm.r, PillTheme.verm.g, PillTheme.verm.b, 0.2)
                                        : Qt.rgba(PillTheme.verm.r, PillTheme.verm.g, PillTheme.verm.b, 0.12)
                                    border.width: 1
                                    border.color: Qt.rgba(PillTheme.vermLit.r, PillTheme.vermLit.g, PillTheme.vermLit.b, 0.45)

                                    Text {
                                        id: forgetLabel
                                        anchors.centerIn: parent
                                        text: Translation.tr("Forget")
                                        color: PillTheme.vermLit
                                        font.family: PillTheme.font
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                        font.letterSpacing: 0.3 * root.s
                                    }

                                    MouseArea {
                                        id: forgetArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.forgetNetwork(netItem.ssid)
                                    }
                                }
                            }
                        }

                        Item {
                            readonly property bool shown: netItem.confirming && root.revealedSsid === netItem.ssid
                            visible: shown
                            width: parent.width
                            height: shown ? 24 * root.s : 0

                            Text {
                                id: revealCaption
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: Translation.tr("PASSWORD")
                                color: PillTheme.faint
                                font.family: PillTheme.font
                                font.pixelSize: 9 * root.s
                                font.weight: Font.Medium
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 1 * root.s
                            }

                            Text {
                                visible: root.revealResolved && root.revealedPw.length === 0
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: Translation.tr("no saved password")
                                color: PillTheme.faint
                                font.family: PillTheme.font
                                font.pixelSize: 10 * root.s
                                font.weight: Font.Medium
                            }

                            TextEdit {
                                visible: root.revealedPw.length > 0
                                anchors.left: revealCaption.right
                                anchors.leftMargin: 10 * root.s
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: TextEdit.AlignRight
                                readOnly: true
                                selectByMouse: true
                                selectionColor: PillTheme.verm
                                wrapMode: TextEdit.NoWrap
                                clip: true
                                text: root.revealedSsid === netItem.ssid ? root.revealedPw : ""
                                color: PillTheme.flameCore
                                font.family: PillTheme.font
                                font.pixelSize: 11.5 * root.s
                                font.weight: Font.Medium
                            }
                        }

                        Item {
                            visible: netItem.asking
                            width: parent.width
                            height: 30 * root.s

                            TextField {
                                id: pwField
                                anchors.left: parent.left
                                anchors.leftMargin: 10 * root.s
                                anchors.right: pwRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                background: null
                                padding: 0
                                color: PillTheme.cream
                                font.family: PillTheme.font
                                font.pixelSize: 11.5 * root.s
                                echoMode: TextInput.Password
                                placeholderText: Translation.tr("Password")
                                placeholderTextColor: PillTheme.faint
                                selectByMouse: true
                                selectionColor: PillTheme.verm
                                onTextEdited: root.pwDraft = text
                                onAccepted: root.connectWithPassword(netItem.ssid, text)
                            }

                            Row {
                                id: pwRight
                                anchors.right: parent.right
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7 * root.s

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: root.connecting && netItem.asking
                                    width: 4 * root.s
                                    height: 4 * root.s
                                    radius: width / 2
                                    color: PillTheme.flameGlow

                                    SequentialAnimation on opacity {
                                        running: root.connecting && netItem.asking
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: PillMotion.pulse; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: PillMotion.pulse; easing.type: Easing.InOutSine }
                                    }
                                }

                                GlyphIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14 * root.s
                                    height: 14 * root.s
                                    name: "return"
                                    color: enterArea.containsMouse ? PillTheme.cream : PillTheme.vermLit
                                    stroke: 1.8

                                    MouseArea {
                                        id: enterArea
                                        anchors.fill: parent
                                        anchors.margins: -6 * root.s
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.connectWithPassword(netItem.ssid, pwField.text)
                                    }
                                }
                            }
                        }

                        Text {
                            visible: netItem.asking && root.connectFailed
                            text: Translation.tr("Connection failed")
                            color: PillTheme.vermLit
                            font.family: PillTheme.font
                            font.pixelSize: 9.5 * root.s
                            leftPadding: 10 * root.s
                        }
                    }
                }
            }
        }

        WheelScroller {
            anchors.fill: parent
            s: root.s
            flick: netFlick
        }
    }

    Item {
        id: hsBlock
        anchors.top: listFrame.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.wifiOn
        height: root.wifiOn ? hsCol.implicitHeight + 9 * root.s : 0
        clip: true

        Rectangle {
            id: hsDivider
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: PillTheme.hair
        }

        Column {
            id: hsCol
            anchors.top: hsDivider.bottom
            anchors.topMargin: 9 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6 * root.s

            component CredRow: Item {
                id: cr
                property string field: ""
                property string label: ""
                property string value: ""
                property bool secret: false
                readonly property bool editing: root.hsEdit === cr.field
                width: parent ? parent.width : 0
                height: 22 * root.s

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: cr.label
                    color: PillTheme.faint
                    font.family: PillTheme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1 * root.s
                }

                Text {
                    visible: !cr.editing
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: cr.value.length ? cr.value : "tap to set"
                    color: cr.value.length ? (cr.secret ? PillTheme.flameCore : PillTheme.cream) : PillTheme.faint
                    font.family: PillTheme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.hsDraft = cr.value;
                            root.hsEdit = cr.field;
                            Qt.callLater(crField.forceActiveFocus);
                        }
                    }
                }

                TextField {
                    id: crField
                    visible: cr.editing
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150 * root.s
                    horizontalAlignment: TextInput.AlignRight
                    background: null
                    padding: 0
                    color: PillTheme.cream
                    font.family: PillTheme.font
                    font.pixelSize: 12 * root.s
                    placeholderText: cr.field === "pw" ? "8+ characters" : "Name"
                    placeholderTextColor: PillTheme.faint
                    selectByMouse: true
                    selectionColor: PillTheme.verm
                    text: cr.editing ? root.hsDraft : ""
                    onTextEdited: root.hsDraft = text
                    onAccepted: root.commitHotspotEdit()
                }
            }

            Rectangle {
                width: parent.width
                height: 34 * root.s
                radius: 10 * root.s
                color: root.hsActive ? PillTheme.frameBg : "transparent"

                GlyphIcon {
                    id: hsGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: "hotspot"
                    color: root.hsActive ? PillTheme.flameGlow : PillTheme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: hsGlyph.right
                    anchors.leftMargin: 11 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Text {
                        text: Translation.tr("Hotspot")
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: root.hsBusy ? "…" : (root.hsActive ? "Active" : "Off")
                        color: root.hsActive ? PillTheme.flameGlow : PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Medium
                    }
                }

                LinkToggle {
                    s: root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.hsActive
                    onToggled: {
                        if (root.hsActive) {
                            root.stopHotspot();
                        } else {
                            if (root.hsPw.length < 8)
                                root.hsPw = root.generatePw();
                            root.applyHotspot();
                        }
                    }
                }
            }

            CredRow {
                field: "name"
                label: Translation.tr("Network")
                value: root.hsName
            }

            CredRow {
                field: "pw"
                label: Translation.tr("Password")
                value: root.hsPw
                secret: true
            }
        }
    }
}
