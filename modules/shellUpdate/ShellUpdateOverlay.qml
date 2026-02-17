pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root

    readonly property bool isOpen: ShellUpdates.overlayOpen
    readonly property bool hasUpdate: ShellUpdates.hasUpdate
    readonly property bool hasLocalMods: ShellUpdates.localModifications.length > 0
    property bool modsExpanded: false
    property bool suppressOutsideClose: false

    // Style-aware tokens (no hardcoded hex fallbacks)
    readonly property color accentColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? (Appearance.inir?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary

    readonly property color layerColor: Appearance.angelEverywhere ? Appearance.colors.colLayer0Base
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colSurface ?? Appearance.colors.colLayer0)
        : Appearance.colors.colLayer0

    readonly property color surfaceColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colSubSurface ?? Appearance.m3colors.m3surfaceContainerLow)
        : Appearance.m3colors.m3surfaceContainerLow

    readonly property color textColor: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnSurface
    readonly property color subtextColor: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary : Appearance.colors.colSubtext
    readonly property color borderColor: Appearance.angelEverywhere ? Appearance.angel.colBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.colors.colLayer0Border

    // Adaptive rounding
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.windowRounding
    readonly property real sectionRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.rounding.small
    readonly property real pillRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : 999

    // Parse commit log lines: "hash|subject|relative_date|author"
    function parseCommits(raw) {
        if (!raw || raw.length === 0) return []
        return raw.split("\n").filter(l => l.length > 0).map(line => {
            const parts = line.split("|")
            return {
                hash: parts[0] ?? "",
                subject: parts[1] ?? "",
                date: parts[2] ?? "",
                author: parts[3] ?? ""
            }
        })
    }

    // Extract only new changelog sections (between remote and local version)
    function extractNewChangelog(fullChangelog, localVer, remoteVer) {
        if (!fullChangelog || fullChangelog.length === 0) return ""
        const lines = fullChangelog.split("\n")
        let result = []
        let capturing = false
        let pastHeader = false
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const headerMatch = line.match(/^## \[([^\]]+)\]/)
            if (headerMatch) {
                const ver = headerMatch[1]
                if (!pastHeader) {
                    pastHeader = true
                    capturing = true
                    result.push(line)
                    continue
                }
                if (ver === localVer) break
                capturing = true
                result.push(line)
                continue
            }
            if (capturing) result.push(line)
        }
        return result.join("\n").trim()
    }

    // Format ISO date to human-readable
    function formatDate(isoDate) {
        if (!isoDate || isoDate.length === 0) return ""
        try {
            const d = new Date(isoDate)
            if (isNaN(d.getTime())) return isoDate
            const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            return months[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear()
        } catch (e) { return isoDate }
    }

    onIsOpenChanged: {
        if (!isOpen) {
            modsExpanded = false
            suppressOutsideClose = false
            return
        }
        suppressOutsideClose = true
        outsideCloseGuard.restart()
    }

    Timer {
        id: outsideCloseGuard
        interval: 220
        repeat: false
        onTriggered: root.suppressOutsideClose = false
    }

    PanelWindow {
        id: window
        visible: root.isOpen
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell:shellUpdate"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Key handler
        Item {
            anchors.fill: parent
            focus: root.isOpen
            Keys.onPressed: function(event) {
                if (!root.isOpen) return
                if (event.key === Qt.Key_Escape) {
                    ShellUpdates.closeOverlay()
                    event.accepted = true
                }
            }
        }

        // Glassmorphism backdrop
        Item {
            anchors.fill: parent
            visible: root.isOpen

            Image {
                id: wallpaperSource
                anchors.fill: parent
                source: {
                    const wpPath = Config.options?.background?.wallpaperPath ?? ""
                    const isVideo = wpPath.endsWith(".mp4") || wpPath.endsWith(".webm") || wpPath.endsWith(".mkv") || wpPath.endsWith(".avi") || wpPath.endsWith(".mov")
                    return isVideo ? (Config.options?.background?.thumbnailPath ?? wpPath) : wpPath
                }
                fillMode: Image.PreserveAspectCrop
                visible: false
                cache: true
                asynchronous: true
            }

            MultiEffect {
                anchors.fill: parent
                source: wallpaperSource
                blurEnabled: Appearance.effectsEnabled && !Appearance.inirEverywhere
                blur: (Appearance.effectsEnabled && !Appearance.inirEverywhere) ? 1.0 : 0
                blurMax: 64
                blurMultiplier: 1.0
                saturation: (Appearance.effectsEnabled && !Appearance.inirEverywhere) ? 0.2 : 0
                visible: !Appearance.inirEverywhere
                opacity: root.isOpen ? 1 : 0

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.inirEverywhere
                    ? ColorUtils.applyAlpha(root.layerColor, 0.95)
                    : ColorUtils.applyAlpha(root.layerColor, 0.85)
                opacity: root.isOpen ? 1 : 0

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                    }
                }
            }
        }

        // Click outside to close
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: mouse => {
                if (root.suppressOutsideClose) {
                    mouse.accepted = false
                    return
                }
                const localPos = mapToItem(card, mouse.x, mouse.y)
                if (localPos.x < 0 || localPos.x > card.width || localPos.y < 0 || localPos.y > card.height) {
                    ShellUpdates.closeOverlay()
                } else {
                    mouse.accepted = false
                }
            }
        }

        StyledRectangularShadow {
            target: card
            radius: card.radius
            visible: Appearance.angelEverywhere || !Appearance.auroraEverywhere
        }

        // Main card
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 640)
            height: Math.min(parent.height - 80, contentLayout.implicitHeight + 2)
            color: root.layerColor
            border.width: 1
            border.color: root.borderColor
            radius: root.cardRadius
            clip: true

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            scale: root.isOpen ? 1.0 : 0.95
            opacity: root.isOpen ? 1 : 0

            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: root.isOpen ?
                        (Appearance.animation?.elementMoveEnter?.duration ?? 400) :
                        (Appearance.animation?.elementMoveExit?.duration ?? 200)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.isOpen ?
                        (Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]) :
                        (Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1])
                }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: root.isOpen ?
                        (Appearance.animation?.elementMoveEnter?.duration ?? 400) :
                        (Appearance.animation?.elementMoveExit?.duration ?? 200)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.isOpen ?
                        (Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]) :
                        (Appearance.animationCurves?.emphasizedAccel ?? [0.3, 0, 0.8, 0.15, 1, 1])
                }
            }

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                // ── Header ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.topMargin: 20
                    Layout.bottomMargin: 16
                    spacing: 16

                    // Icon
                    Rectangle {
                        width: 44
                        height: 44
                        radius: root.sectionRadius
                        color: ColorUtils.transparentize(root.accentColor, 0.85)
                        border.width: Appearance.inirEverywhere ? 1 : 0
                        border.color: Appearance.inirEverywhere ? root.borderColor : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.hasUpdate ? "upgrade" : "check_circle"
                            iconSize: Appearance.font.pixelSize.huge
                            color: root.accentColor
                        }
                    }

                    ColumnLayout {
                        spacing: 6
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        StyledText {
                            text: root.hasUpdate
                                ? Translation.tr("Shell Update Available")
                                : Translation.tr("Shell Status")
                            font {
                                pixelSize: Appearance.font.pixelSize.larger
                                weight: Font.DemiBold
                            }
                            color: root.textColor
                        }

                        // Subtitle info row
                        RowLayout {
                            spacing: 8

                            // Version pill
                            Rectangle {
                                visible: ShellUpdates.localVersion.length > 0
                                implicitWidth: versionRow.implicitWidth + 20
                                implicitHeight: versionRow.implicitHeight + 10
                                radius: root.pillRadius
                                color: root.surfaceColor
                                border.width: Appearance.inirEverywhere ? 1 : 0
                                border.color: Appearance.inirEverywhere ? root.borderColor : "transparent"

                                RowLayout {
                                    id: versionRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    StyledText {
                                        text: "v" + ShellUpdates.localVersion
                                        font {
                                            pixelSize: Appearance.font.pixelSize.smaller
                                            family: Appearance.font.family.monospace
                                        }
                                        color: root.subtextColor
                                    }
                                    MaterialSymbol {
                                        text: "arrow_forward"
                                        iconSize: Appearance.font.pixelSize.smaller
                                        color: root.accentColor
                                        visible: root.hasUpdate && ShellUpdates.remoteVersion.length > 0 && ShellUpdates.remoteVersion !== ShellUpdates.localVersion
                                    }
                                    StyledText {
                                        visible: root.hasUpdate && ShellUpdates.remoteVersion.length > 0 && ShellUpdates.remoteVersion !== ShellUpdates.localVersion
                                        text: "v" + ShellUpdates.remoteVersion
                                        font {
                                            pixelSize: Appearance.font.pixelSize.smaller
                                            family: Appearance.font.family.monospace
                                            weight: Font.DemiBold
                                        }
                                        color: root.accentColor
                                    }
                                }
                            }

                            // Commits behind badge
                            Rectangle {
                                visible: ShellUpdates.commitsBehind > 0
                                implicitWidth: commitsBehindText.implicitWidth + 20
                                implicitHeight: commitsBehindText.implicitHeight + 10
                                radius: root.pillRadius
                                color: ShellUpdates.commitsBehind > 10
                                    ? ColorUtils.transparentize(Appearance.m3colors.m3error, 0.85)
                                    : ColorUtils.transparentize(root.accentColor, 0.85)

                                StyledText {
                                    id: commitsBehindText
                                    anchors.centerIn: parent
                                    text: ShellUpdates.commitsBehind + " " + Translation.tr("commits behind")
                                    font {
                                        pixelSize: Appearance.font.pixelSize.smallest
                                        weight: Font.Medium
                                    }
                                    color: ShellUpdates.commitsBehind > 10
                                        ? Appearance.m3colors.m3error
                                        : root.accentColor
                                }
                            }

                            // Branch
                            RowLayout {
                                visible: ShellUpdates.currentBranch.length > 0
                                spacing: 4
                                MaterialSymbol {
                                    text: "account_tree"
                                    iconSize: Appearance.font.pixelSize.smallest
                                    color: root.subtextColor
                                }
                                StyledText {
                                    text: ShellUpdates.currentBranch
                                    font {
                                        pixelSize: Appearance.font.pixelSize.smallest
                                        family: Appearance.font.family.monospace
                                    }
                                    color: root.subtextColor
                                }
                            }
                        }
                    }

                    // Close button
                    RippleButton {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 36
                        implicitHeight: 36
                        onClicked: ShellUpdates.closeOverlay()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: Appearance.font.pixelSize.large
                            color: root.subtextColor
                        }
                    }
                }

                // ── Separator ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    color: root.borderColor
                    opacity: 0.6
                }

                // ── Loading indicator ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ShellUpdates.isFetchingDetails ? 4 : 0
                    visible: ShellUpdates.isFetchingDetails
                    clip: true

                    StyledProgressBar {
                        anchors.fill: parent
                        indeterminate: true
                        highlightColor: root.accentColor
                    }
                }

                // ── Error section (when updates unavailable) ──
                Rectangle {
                    visible: !ShellUpdates.available
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.topMargin: 16
                    implicitHeight: errorCol.implicitHeight + 28
                    radius: root.sectionRadius
                    color: ColorUtils.transparentize(Appearance.m3colors.m3error, 0.92)
                    border.width: 1
                    border.color: ColorUtils.transparentize(Appearance.m3colors.m3error, 0.7)

                    ColumnLayout {
                        id: errorCol
                        anchors {
                            fill: parent
                            margins: 14
                        }
                        spacing: 12

                        // Error header
                        RowLayout {
                            spacing: 8
                            MaterialSymbol {
                                text: "error"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.m3colors.m3error
                            }
                            StyledText {
                                text: Translation.tr("Updates Unavailable")
                                font {
                                    pixelSize: Appearance.font.pixelSize.normal
                                    weight: Font.DemiBold
                                }
                                color: Appearance.m3colors.m3error
                            }
                        }

                        // Error message
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Repository not found. The update system cannot locate the iNiR git repository.")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.textColor
                            wrapMode: Text.WordWrap
                        }

                        // Suggested action
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Run './setup doctor' in your terminal to diagnose the issue, or use the diagnose command below.")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.subtextColor
                            wrapMode: Text.WordWrap
                        }

                        // Diagnose button
                        RippleButton {
                            Layout.topMargin: 4
                            implicitWidth: diagLabel.implicitWidth + 28
                            implicitHeight: 32
                            onClicked: {
                                const diag = ShellUpdates.getDiagnostics()
                                console.log("[ShellUpdates] Diagnostics:\n" + diag)
                                Notifications.notify({
                                    summary: "Update System Diagnostics",
                                    body: "Diagnostics printed to console. Run: qs log -c ii | tail -50",
                                    urgency: NotificationUrgency.Normal,
                                    timeout: 8000,
                                    appName: "iNiR Shell"
                                })
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: parent.pressed ? Appearance.colors.colLayer1Active
                                     : parent.hovered ? Appearance.colors.colLayer1Hover
                                     : "transparent"
                                border.width: 1
                                border.color: Appearance.m3colors.m3error

                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }
                            }

                            RowLayout {
                                id: diagLabel
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialSymbol {
                                    text: "bug_report"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.m3colors.m3error
                                }
                                StyledText {
                                    text: Translation.tr("Run Diagnostics")
                                    font {
                                        pixelSize: Appearance.font.pixelSize.small
                                        weight: Font.Medium
                                    }
                                    color: Appearance.m3colors.m3error
                                }
                            }
                        }
                    }
                }

                // ── Scrollable content ──
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 0
                    contentWidth: availableWidth
                    clip: true

                    Flickable {
                        contentHeight: contentColumn.implicitHeight + 32
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: contentColumn
                            width: parent.width
                            spacing: 16

                            Item { Layout.preferredHeight: 4 }

                            // ── Current System Info ──
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: 24
                                Layout.rightMargin: 24
                                implicitHeight: sysInfoCol.implicitHeight + 28
                                radius: root.sectionRadius
                                color: root.surfaceColor
                                border.width: Appearance.inirEverywhere ? 1 : 0
                                border.color: Appearance.inirEverywhere ? root.borderColor : "transparent"

                                ColumnLayout {
                                    id: sysInfoCol
                                    anchors {
                                        fill: parent
                                        margins: 14
                                    }
                                    spacing: 12

                                    // Section header
                                    RowLayout {
                                        spacing: 8
                                        MaterialSymbol {
                                            text: "info"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: root.accentColor
                                        }
                                        StyledText {
                                            text: Translation.tr("Current System")
                                            font {
                                                pixelSize: Appearance.font.pixelSize.normal
                                                weight: Font.DemiBold
                                            }
                                            color: root.textColor
                                        }
                                    }

                                    // Info grid — uses GridLayout for perfect column alignment
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: 16
                                        rowSpacing: 8

                                        // Version
                                        StyledText {
                                            text: Translation.tr("Version")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: root.subtextColor
                                        }
                                        StyledText {
                                            text: ShellUpdates.localVersion.length > 0 ? ("v" + ShellUpdates.localVersion) : "\u2014"
                                            font {
                                                pixelSize: Appearance.font.pixelSize.small
                                                family: Appearance.font.family.monospace
                                                weight: Font.Medium
                                            }
                                            color: root.textColor
                                        }

                                    // Repository commit (git HEAD)
                                    StyledText {
                                        text: Translation.tr("Repository")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: root.subtextColor
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Rectangle {
                                        implicitWidth: headHashLabel.implicitWidth + 20
                                        implicitHeight: headHashLabel.implicitHeight + 10
                                        radius: root.pillRadius
                                        color: ColorUtils.transparentize(root.accentColor, 0.88)

                                            StyledText {
                                                id: headHashLabel
                                                anchors.centerIn: parent
                                                text: ShellUpdates.localCommit.length > 0 ? ShellUpdates.localCommit : "\u2014"
                                                font {
                                                    pixelSize: Appearance.font.pixelSize.smaller
                                                    family: Appearance.font.family.monospace
                                                    weight: Font.Medium
                                                }
                                                color: root.accentColor
                                            }
                                        }

                                    // Installed commit (from manifest)
                                    StyledText {
                                        visible: ShellUpdates.installedCommit.length > 0
                                        text: Translation.tr("Installed commit")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: root.subtextColor
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Rectangle {
                                        visible: ShellUpdates.installedCommit.length > 0
                                        implicitWidth: instHashLabel.implicitWidth + 20
                                        implicitHeight: instHashLabel.implicitHeight + 10
                                        radius: root.pillRadius
                                        color: ColorUtils.transparentize(root.subtextColor, 0.88)

                                            StyledText {
                                                id: instHashLabel
                                                anchors.centerIn: parent
                                                text: ShellUpdates.installedCommit
                                                font {
                                                    pixelSize: Appearance.font.pixelSize.smaller
                                                    family: Appearance.font.family.monospace
                                                }
                                                color: root.subtextColor
                                            }
                                        }

                                        // Last updated
                                        StyledText {
                                            visible: ShellUpdates.installedDate.length > 0
                                            text: Translation.tr("Last updated")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: root.subtextColor
                                        }
                                        StyledText {
                                            visible: ShellUpdates.installedDate.length > 0
                                            text: root.formatDate(ShellUpdates.installedDate)
                                            font {
                                                pixelSize: Appearance.font.pixelSize.small
                                                weight: Font.Medium
                                            }
                                            color: root.textColor
                                        }

                                        // Branch
                                        StyledText {
                                            visible: ShellUpdates.currentBranch.length > 0
                                            text: Translation.tr("Branch")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: root.subtextColor
                                        }
                                        StyledText {
                                            visible: ShellUpdates.currentBranch.length > 0
                                            text: ShellUpdates.currentBranch
                                            font {
                                                pixelSize: Appearance.font.pixelSize.small
                                                family: Appearance.font.family.monospace
                                            }
                                            color: root.textColor
                                        }

                                    // Status
                                    StyledText {
                                        text: Translation.tr("Status")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: root.subtextColor
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Rectangle {
                                        implicitWidth: statusText.implicitWidth + 20
                                        implicitHeight: statusText.implicitHeight + 10
                                        radius: root.pillRadius
                                        color: root.hasUpdate
                                            ? ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.85)
                                            : ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.85)

                                        StyledText {
                                            id: statusText
                                            anchors.centerIn: parent
                                            text: root.hasUpdate
                                                ? Translation.tr("Update available")
                                                : Translation.tr("Up to date")
                                            font {
                                                pixelSize: Appearance.font.pixelSize.smallest
                                                weight: Font.DemiBold
                                            }
                                            color: root.hasUpdate
                                                ? Appearance.m3colors.m3primary
                                                : Appearance.m3colors.m3tertiary
                                        }
                                    }
                                    }
                                }
                            }

                            // ── Local Modifications Warning ──
                            Rectangle {
                                visible: root.hasLocalMods
                                Layout.fillWidth: true
                                Layout.leftMargin: 24
                                Layout.rightMargin: 24
                                implicitHeight: modsCol.implicitHeight + 24
                                radius: root.sectionRadius
                                color: ColorUtils.transparentize(Appearance.m3colors.m3error, 0.92)
                                border.width: 1
                                border.color: ColorUtils.transparentize(Appearance.m3colors.m3error, 0.7)

                                ColumnLayout {
                                    id: modsCol
                                    anchors {
                                        fill: parent
                                        margins: 12
                                    }
                                    spacing: 10

                                    // Header
                                    RowLayout {
                                        spacing: 8
                                        MaterialSymbol {
                                            text: "warning"
                                            iconSize: Appearance.font.pixelSize.large
                                            color: Appearance.m3colors.m3error
                                        }
                                        ColumnLayout {
                                            spacing: 2
                                            Layout.fillWidth: true
                                            StyledText {
                                                text: Translation.tr("Local modifications detected")
                                                font {
                                                    pixelSize: Appearance.font.pixelSize.small
                                                    weight: Font.DemiBold
                                                }
                                                color: Appearance.m3colors.m3error
                                            }
                                            StyledText {
                                                text: ShellUpdates.localModifications.length + " " + Translation.tr("file(s) differ from the installed version")
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: root.subtextColor
                                            }
                                        }
                                    }

                                    // Explanation
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: explanationCol.implicitHeight + 16
                                        radius: root.sectionRadius
                                        color: ColorUtils.transparentize(Appearance.m3colors.m3error, 0.95)

                                        ColumnLayout {
                                            id: explanationCol
                                            anchors {
                                                fill: parent
                                                margins: 8
                                            }
                                            spacing: 6

                                            RowLayout {
                                                spacing: 6
                                                MaterialSymbol {
                                                    text: "inventory_2"
                                                    iconSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colOnLayer1
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: Translation.tr("A full snapshot of your current config will be saved before updating.")
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: Appearance.colors.colOnLayer1
                                                    wrapMode: Text.WordWrap
                                                }
                                            }
                                            RowLayout {
                                                spacing: 6
                                                MaterialSymbol {
                                                    text: "undo"
                                                    iconSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colOnLayer1
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: Translation.tr("You can restore your modifications anytime with:") + "  ./setup rollback"
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: Appearance.colors.colOnLayer1
                                                    wrapMode: Text.WordWrap
                                                }
                                            }
                                        }
                                    }

                                    // Collapsible file list toggle
                                    MouseArea {
                                        Layout.fillWidth: true
                                        implicitHeight: modsToggleRow.implicitHeight + 8
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.modsExpanded = !root.modsExpanded

                                        RowLayout {
                                            id: modsToggleRow
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                verticalCenter: parent.verticalCenter
                                            }
                                            spacing: 6

                                            MaterialSymbol {
                                                text: root.modsExpanded ? "expand_less" : "expand_more"
                                                iconSize: Appearance.font.pixelSize.normal
                                                color: root.subtextColor
                                            }
                                            StyledText {
                                                text: root.modsExpanded
                                                    ? Translation.tr("Hide modified files")
                                                    : Translation.tr("Show modified files") + " (" + ShellUpdates.localModifications.length + ")"
                                                font {
                                                    pixelSize: Appearance.font.pixelSize.smallest
                                                    weight: Font.Medium
                                                }
                                                color: root.subtextColor
                                            }
                                        }
                                    }

                                    // File list (collapsible)
                                    ColumnLayout {
                                        visible: root.modsExpanded
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Repeater {
                                            model: ShellUpdates.localModifications

                                            RowLayout {
                                                required property string modelData
                                                spacing: 6
                                                Layout.leftMargin: 4

                                                MaterialSymbol {
                                                    text: "edit_document"
                                                    iconSize: Appearance.font.pixelSize.smallest
                                                    color: Appearance.m3colors.m3error
                                                    opacity: 0.6
                                                }
                                                StyledText {
                                                    text: modelData
                                                    font {
                                                        pixelSize: Appearance.font.pixelSize.smallest
                                                        family: Appearance.font.family.monospace
                                                    }
                                                    color: Appearance.colors.colOnLayer1
                                                    opacity: 0.8
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Changelog Section (only when update available) ──
                            ColumnLayout {
                                visible: root.hasUpdate && changelogText.text.length > 0
                                Layout.fillWidth: true
                                Layout.leftMargin: 24
                                Layout.rightMargin: 24
                                spacing: 8

                                RowLayout {
                                    spacing: 8
                                    MaterialSymbol {
                                        text: "description"
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: root.accentColor
                                    }
                                    StyledText {
                                        text: Translation.tr("What's New")
                                        font {
                                            pixelSize: Appearance.font.pixelSize.normal
                                            weight: Font.DemiBold
                                        }
                                        color: root.textColor
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: changelogText.implicitHeight + 24
                                    radius: root.sectionRadius
                                    color: root.surfaceColor
                                    border.width: Appearance.inirEverywhere ? 1 : 0
                                    border.color: Appearance.inirEverywhere ? root.borderColor : "transparent"

                                    StyledText {
                                        id: changelogText
                                        anchors {
                                            fill: parent
                                            margins: 12
                                        }
                                        text: root.extractNewChangelog(
                                            ShellUpdates.remoteChangelog,
                                            ShellUpdates.localVersion,
                                            ShellUpdates.remoteVersion
                                        )
                                        font {
                                            pixelSize: Appearance.font.pixelSize.small
                                            family: Appearance.font.family.monospace
                                        }
                                        color: Appearance.colors.colOnLayer1
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.4
                                    }
                                }
                            }

                            // ── Incoming Commits (only when update available) ──
                            ColumnLayout {
                                visible: root.hasUpdate && ShellUpdates.commitLog.length > 0
                                Layout.fillWidth: true
                                Layout.leftMargin: 24
                                Layout.rightMargin: 24
                                spacing: 8

                                RowLayout {
                                    spacing: 8
                                    MaterialSymbol {
                                        text: "download"
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: root.accentColor
                                    }
                                    StyledText {
                                        text: Translation.tr("Incoming Commits")
                                        font {
                                            pixelSize: Appearance.font.pixelSize.normal
                                            weight: Font.DemiBold
                                        }
                                        color: root.textColor
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: incomingCommitsCol.implicitHeight + 16
                                    radius: root.sectionRadius
                                    color: root.surfaceColor
                                    border.width: Appearance.inirEverywhere ? 1 : 0
                                    border.color: Appearance.inirEverywhere ? root.borderColor : "transparent"

                                    ColumnLayout {
                                        id: incomingCommitsCol
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            top: parent.top
                                            margins: 8
                                        }
                                        spacing: 2

                                        Repeater {
                                            model: root.parseCommits(ShellUpdates.commitLog)

                                            Rectangle {
                                                required property var modelData
                                                required property int index
                                                Layout.fillWidth: true
                                                implicitHeight: incomingRow.implicitHeight + 12
                                                radius: Appearance.inirEverywhere ? 2 : (Appearance.rounding?.smaller ?? 4)
                                                color: index % 2 === 0
                                                    ? "transparent"
                                                    : ColorUtils.transparentize(root.layerColor, 0.5)

                                                RowLayout {
                                                    id: incomingRow
                                                    anchors {
                                                        fill: parent
                                                        leftMargin: 8
                                                        rightMargin: 8
                                                        topMargin: 6
                                                        bottomMargin: 6
                                                    }
                                                    spacing: 10

                                                    Rectangle {
                                                        implicitWidth: incomingHash.implicitWidth + 18
                                                        implicitHeight: incomingHash.implicitHeight + 10
                                                        radius: root.pillRadius
                                                        color: ColorUtils.transparentize(root.accentColor, 0.88)

                                                        StyledText {
                                                            id: incomingHash
                                                            anchors.centerIn: parent
                                                            text: modelData.hash
                                                            font {
                                                                pixelSize: Appearance.font.pixelSize.smallest
                                                                family: Appearance.font.family.monospace
                                                                weight: Font.Medium
                                                            }
                                                            color: root.accentColor
                                                        }
                                                    }

                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        text: modelData.subject
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        color: Appearance.colors.colOnLayer1
                                                        elide: Text.ElideRight
                                                        maximumLineCount: 1
                                                    }

                                                    StyledText {
                                                        text: modelData.date
                                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                                        color: root.subtextColor
                                                        opacity: 0.7
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Recent History (local commits - always visible) ──
                            ColumnLayout {
                                visible: ShellUpdates.recentLocalLog.length > 0
                                Layout.fillWidth: true
                                Layout.leftMargin: 24
                                Layout.rightMargin: 24
                                spacing: 8

                                RowLayout {
                                    spacing: 8
                                    MaterialSymbol {
                                        text: "history"
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: root.accentColor
                                    }
                                    StyledText {
                                        text: Translation.tr("Recent History")
                                        font {
                                            pixelSize: Appearance.font.pixelSize.normal
                                            weight: Font.DemiBold
                                        }
                                        color: root.textColor
                                    }
                                    StyledText {
                                        text: Translation.tr("(installed)")
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: root.subtextColor
                                        opacity: 0.7
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: localCommitsCol.implicitHeight + 16
                                    radius: root.sectionRadius
                                    color: root.surfaceColor
                                    border.width: Appearance.inirEverywhere ? 1 : 0
                                    border.color: Appearance.inirEverywhere ? root.borderColor : "transparent"

                                    ColumnLayout {
                                        id: localCommitsCol
                                        anchors {
                                            left: parent.left
                                            right: parent.right
                                            top: parent.top
                                            margins: 8
                                        }
                                        spacing: 2

                                        Repeater {
                                            model: root.parseCommits(ShellUpdates.recentLocalLog)

                                            Rectangle {
                                                required property var modelData
                                                required property int index
                                                Layout.fillWidth: true
                                                implicitHeight: localRow.implicitHeight + 12
                                                radius: Appearance.inirEverywhere ? 2 : (Appearance.rounding?.smaller ?? 4)
                                                color: index % 2 === 0
                                                    ? "transparent"
                                                    : ColorUtils.transparentize(root.layerColor, 0.5)

                                                RowLayout {
                                                    id: localRow
                                                    anchors {
                                                        fill: parent
                                                        leftMargin: 8
                                                        rightMargin: 8
                                                        topMargin: 6
                                                        bottomMargin: 6
                                                    }
                                                    spacing: 10

                                                    Rectangle {
                                                        implicitWidth: localHash.implicitWidth + 18
                                                        implicitHeight: localHash.implicitHeight + 10
                                                        radius: root.pillRadius
                                                        color: ColorUtils.transparentize(root.subtextColor, 0.88)

                                                        StyledText {
                                                            id: localHash
                                                            anchors.centerIn: parent
                                                            text: modelData.hash
                                                            font {
                                                                pixelSize: Appearance.font.pixelSize.smallest
                                                                family: Appearance.font.family.monospace
                                                            }
                                                            color: root.subtextColor
                                                        }
                                                    }

                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        text: modelData.subject
                                                        font.pixelSize: Appearance.font.pixelSize.small
                                                        color: Appearance.colors.colOnLayer1
                                                        elide: Text.ElideRight
                                                        maximumLineCount: 1
                                                        opacity: 0.8
                                                    }

                                                    StyledText {
                                                        text: modelData.date
                                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                                        color: root.subtextColor
                                                        opacity: 0.5
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.preferredHeight: 8 }
                        }
                    }
                }

                // ── Separator ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    color: root.borderColor
                    opacity: 0.6
                }

                // ── Footer with actions ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.topMargin: 12
                    Layout.bottomMargin: 14
                    spacing: 12

                    // Snapshot info (only when update available)
                    RowLayout {
                        visible: root.hasUpdate
                        spacing: 6
                        MaterialSymbol {
                            text: "inventory_2"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: root.subtextColor
                            opacity: 0.7
                        }
                        StyledText {
                            text: Translation.tr("A snapshot will be created before updating")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.subtextColor
                            opacity: 0.7
                        }
                    }

                    // Up to date message (when no update)
                    RowLayout {
                        visible: !root.hasUpdate
                        spacing: 6
                        MaterialSymbol {
                            text: "check_circle"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.m3colors.m3tertiary
                            opacity: 0.8
                        }
                        StyledText {
                            text: Translation.tr("Your shell is up to date")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.subtextColor
                            opacity: 0.7
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Dismiss button (only when update)
                    RippleButton {
                        visible: root.hasUpdate
                        implicitWidth: dismissLabel.implicitWidth + 28
                        implicitHeight: 36
                        onClicked: ShellUpdates.dismiss()

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: parent.pressed ? Appearance.colors.colLayer1Active
                                 : parent.hovered ? Appearance.colors.colLayer1Hover
                                 : "transparent"
                            border.width: 1
                            border.color: root.borderColor

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }

                        StyledText {
                            id: dismissLabel
                            anchors.centerIn: parent
                            text: Translation.tr("Dismiss")
                            font {
                                pixelSize: Appearance.font.pixelSize.small
                                weight: Font.Medium
                            }
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    // Update button (only when update)
                    RippleButton {
                        visible: root.hasUpdate
                        enabled: !ShellUpdates.isUpdating
                        implicitWidth: updateBtnContent.implicitWidth + 32
                        implicitHeight: 36
                        onClicked: ShellUpdates.performUpdate()

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: ShellUpdates.isUpdating ? Qt.darker(root.accentColor, 1.2)
                                 : parent.pressed ? Qt.darker(root.accentColor, 1.3)
                                 : parent.hovered ? Qt.lighter(root.accentColor, 1.1)
                                 : root.accentColor
                            opacity: ShellUpdates.isUpdating ? 0.7 : 1.0

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                            Behavior on opacity {
                                enabled: Appearance.animationsEnabled
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                        }

                        RowLayout {
                            id: updateBtnContent
                            anchors.centerIn: parent
                            spacing: 6

                            // Spinner when updating
                            MaterialSymbol {
                                visible: ShellUpdates.isUpdating
                                text: "progress_activity"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.m3colors.m3onPrimary

                                RotationAnimation on rotation {
                                    running: ShellUpdates.isUpdating
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1000
                                }
                            }

                            MaterialSymbol {
                                visible: !ShellUpdates.isUpdating
                                text: "upgrade"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.m3colors.m3onPrimary
                            }
                            StyledText {
                                text: ShellUpdates.isUpdating
                                    ? Translation.tr("Updating...")
                                    : Translation.tr("Update Now")
                                font {
                                    pixelSize: Appearance.font.pixelSize.small
                                    weight: Font.DemiBold
                                }
                                color: Appearance.m3colors.m3onPrimary
                            }
                        }
                    }

                    // Close button (when no update)
                    RippleButton {
                        visible: !root.hasUpdate
                        implicitWidth: closeLabel.implicitWidth + 28
                        implicitHeight: 36
                        onClicked: ShellUpdates.closeOverlay()

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: parent.pressed ? Appearance.colors.colLayer1Active
                                 : parent.hovered ? Appearance.colors.colLayer1Hover
                                 : "transparent"
                            border.width: 1
                            border.color: root.borderColor

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }

                        StyledText {
                            id: closeLabel
                            anchors.centerIn: parent
                            text: Translation.tr("Close")
                            font {
                                pixelSize: Appearance.font.pixelSize.small
                                weight: Font.Medium
                            }
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
        }
    }
}
