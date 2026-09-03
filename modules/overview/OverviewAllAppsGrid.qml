pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

// All-apps grid mode for the ii overview.
// Two layouts driven by Config.options.overview.allAppsGridMode:
//   "minimal" — flat alphabetical A–Z sections
//   "folder"  — apps grouped into rounded category cards (Internet, System, etc.)
Item {
    id: root
    property bool panelVisible: true
    property real availableHeight: 600
    property bool applicationDragActive: false
    readonly property string mode: Config.options?.overview?.allAppsGridMode ?? "minimal"
    readonly property bool zzzEverywhere: Appearance.zzzEverywhere

    signal appLaunched()

    implicitWidth: gridBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: gridBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    readonly property int gridWidth: root.zzzEverywhere ? 840 : 760
    readonly property int tileColumns: 6
    readonly property color headerAccentColor: root.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colAccent
        : Appearance.colors.colPrimary
    readonly property color surfaceColor: root.zzzEverywhere ? Appearance.zzz.paper
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
        : Appearance.colors.colLayer1
    readonly property color surfaceHoverColor: root.zzzEverywhere ? Appearance.zzz.paperAlt
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
        : Appearance.colors.colLayer1Hover
    readonly property color surfaceActiveColor: root.zzzEverywhere ? Appearance.zzz.signal
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer1Active
    readonly property color surfaceBorderColor: root.zzzEverywhere ? Appearance.zzz.hairline
        : Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
        : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : Appearance.colors.colLayer0Border

    // ── Folder definitions: friendly name → freedesktop categories ──
    readonly property var folderDefs: [
        { name: Translation.tr("Internet"), icon: "language", cats: ["Network", "WebBrowser", "Email"] },
        { name: Translation.tr("Multimedia"), icon: "movie", cats: ["AudioVideo", "Audio", "Video", "Player"] },
        { name: Translation.tr("Graphics"), icon: "palette", cats: ["Graphics", "Photography"] },
        { name: Translation.tr("Office"), icon: "description", cats: ["Office", "Calendar", "ContactManagement"] },
        { name: Translation.tr("Development"), icon: "code", cats: ["Development", "IDE"] },
        { name: Translation.tr("Games"), icon: "sports_esports", cats: ["Game"] },
        { name: Translation.tr("Utilities"), icon: "build", cats: ["Utility", "Accessories", "Archiving", "Calculator"] },
        { name: Translation.tr("System"), icon: "settings", cats: ["System", "Settings", "Security"] },
        { name: Translation.tr("Education"), icon: "school", cats: ["Education", "Science"] }
    ]
    readonly property string otherFolderName: Translation.tr("Other")

    function categorize(entry) {
        const cats = entry?.categories ?? entry?.originalEntry?.categories ?? []
        if (cats && cats.length > 0) {
            for (let i = 0; i < root.folderDefs.length; i++) {
                const def = root.folderDefs[i]
                for (let j = 0; j < def.cats.length; j++) {
                    if (cats.indexOf(def.cats[j]) !== -1) return def.name
                }
            }
        }
        return root.otherFolderName
    }

    readonly property var appList: (AppSearch.list ?? []).filter(e => e && !e.noDisplay)

    // ── Minimal: alphabetical groups ──
    readonly property var groupedApps: {
        const all = root.appList
        const groups = []
        let currentLetter = ""
        let currentGroup = null
        for (const app of all) {
            const rawName = (app.name || "?").trim()
            const firstChar = rawName.length > 0 ? rawName[0].toUpperCase() : "#"
            const letter = /[A-Z]/.test(firstChar) ? firstChar : "#"
            if (letter !== currentLetter) {
                currentLetter = letter
                currentGroup = { letter: letter, apps: [] }
                groups.push(currentGroup)
            }
            currentGroup.apps.push(app)
        }
        return groups
    }

    // ── Folder: category groups ──
    readonly property var categorizedApps: {
        const all = root.appList
        const buckets = {}
        for (const app of all) {
            const folder = root.categorize(app)
            if (!buckets[folder]) buckets[folder] = []
            buckets[folder].push(app)
        }
        const ordered = []
        for (let i = 0; i < root.folderDefs.length; i++) {
            const def = root.folderDefs[i]
            if (buckets[def.name] && buckets[def.name].length > 0)
                ordered.push({ name: def.name, icon: def.icon, apps: buckets[def.name] })
        }
        if (buckets[root.otherFolderName] && buckets[root.otherFolderName].length > 0)
            ordered.push({ name: root.otherFolderName, icon: "apps", apps: buckets[root.otherFolderName] })
        return ordered
    }

    function launchApp(entry) {
        if (!entry) return
        AppSearch.launchEntry(entry)
        root.appLaunched()
    }

    StyledRectangularShadow {
        target: gridBackground
    }

    GlassBackground {
        id: gridBackground
        screenX: {
            const win = gridBackground.QsWindow?.window
            return win ? gridBackground.mapToItem(win.contentItem, 0, 0).x : 0
        }
        screenY: {
            const win = gridBackground.QsWindow?.window
            return win ? gridBackground.mapToItem(win.contentItem, 0, 0).y : 0
        }
        screenWidth: gridBackground.QsWindow?.window?.screen?.width ?? root.width
        screenHeight: gridBackground.QsWindow?.window?.screen?.height ?? root.height
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: Appearance.sizes.elevationMargin
        }
        implicitWidth: root.gridWidth
        implicitHeight: Math.min(root.availableHeight, 680)
        radius: root.zzzEverywhere ? Appearance.zzz.panelRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingLarge
            : Appearance.inirEverywhere ? Appearance.inir.roundingLarge
            : Appearance.rounding.large
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
        fallbackColor: root.surfaceColor
        inirColor: Appearance.inir.colLayer1
        auroraTransparency: Appearance.aurora.popupTransparentize
        wallpaperBackdropEnabled: root.panelVisible && !root.zzzEverywhere
        border.width: root.zzzEverywhere ? Appearance.zzz.borderThick : Appearance.angelEverywhere ? 0 : 1
        border.color: root.surfaceBorderColor
        Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

        ZzzPanelBackdrop {
            anchors.fill: parent
            label: "APPLICATIONS"
            index: "GRID"
            ghostText: "APPS"
            accentColor: Appearance.zzz.accent
            showTicks: false
            showBurst: false
            showGrid: false
            horizontalBias: 0.12
            verticalBias: 0.02
            ghostStrength: 0.7
        }

        StyledFlickable {
            id: appsFlickable
            anchors.fill: parent
            anchors.margins: root.zzzEverywhere ? 24 : 18
            contentHeight: contentColumn.implicitHeight
            clip: true

            Column {
                id: contentColumn
                width: appsFlickable.width
                spacing: 16

                Item {
                    width: parent.width
                    implicitHeight: headerRow.implicitHeight

                    RowLayout {
                        id: headerRow
                        width: parent.width
                        spacing: 12

                        MaterialShapeWrappedMaterialSymbol {
                            text: "apps"
                            iconSize: 18
                            padding: 8
                            colSymbol: root.headerAccentColor
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: root.zzzEverywhere ? Translation.tr("All apps").toUpperCase() : Translation.tr("All apps")
                                font {
                                    family: Appearance.font.family.title
                                    pixelSize: Appearance.font.pixelSize.larger
                                    variableAxes: Appearance.font.variableAxes.title
                                    weight: Font.DemiBold
                                }
                                color: root.headerAccentColor
                            }

                            StyledText {
                                text: root.mode === "folder"
                                    ? Translation.tr("Grouped by category")
                                    : Translation.tr("Alphabetical index")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                opacity: 0.85
                            }
                        }

                        StyledText {
                            text: Translation.tr("%1 apps").arg(root.appList.length)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                            opacity: 0.7
                        }
                    }
                }

                // ── MINIMAL MODE: flat alphabetical sections ──
                Repeater {
                    model: root.mode === "folder" ? [] : root.groupedApps
                    delegate: Column {
                        id: alphaSection
                        required property var modelData
                        width: contentColumn.width
                        spacing: 6

                        RowLayout {
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 3
                                implicitHeight: 18
                                radius: Appearance.rounding.unsharpen
                                color: root.headerAccentColor
                            }

                            StyledText {
                                text: alphaSection.modelData.letter
                                font {
                                    family: Appearance.font.family.title
                                    pixelSize: Appearance.font.pixelSize.large
                                    variableAxes: Appearance.font.variableAxes.title
                                    weight: Font.DemiBold
                                }
                                color: root.headerAccentColor
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                implicitHeight: 1
                                color: root.surfaceBorderColor
                                opacity: 0.5
                            }
                        }

                        Flow {
                            id: alphaFlow
                            width: parent.width
                            spacing: 4
                            readonly property real tileWidth: Math.floor((width - spacing * (root.tileColumns - 1)) / root.tileColumns)
                            Repeater {
                                model: alphaSection.modelData.apps
                                delegate: AppTile {
                                    required property var modelData
                                    entry: modelData
                                    implicitWidth: alphaFlow.tileWidth
                                    onActivated: root.launchApp(modelData)
                                }
                            }
                        }
                    }
                }

                // ── FOLDER MODE: rounded category cards ──
                Repeater {
                    model: root.mode === "folder" ? root.categorizedApps : []
                    delegate: Rectangle {
                        id: catCard
                        required property var modelData
                        width: contentColumn.width
                        implicitHeight: catCardColumn.implicitHeight + 32
                        radius: root.zzzEverywhere ? Appearance.zzz.panelRadius
                            : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
                            : Appearance.rounding.normal
                        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                        color: root.zzzEverywhere ? Appearance.zzz.paperAlt
                            : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                            : Appearance.colors.colLayer2
                        border.width: 1
                        border.color: root.surfaceBorderColor

                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Behavior on border.color {
                            enabled: Appearance.animationsEnabled
                            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }

                        Column {
                            id: catCardColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 16
                            }
                            spacing: 12

                            RowLayout {
                                width: parent.width
                                spacing: 10

                                MaterialShapeWrappedMaterialSymbol {
                                    text: catCard.modelData.icon
                                    iconSize: 18
                                    padding: 8
                                    colSymbol: root.headerAccentColor
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: catCard.modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.DemiBold
                                    color: root.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer1
                                    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                }

                                StyledText {
                                    text: String(catCard.modelData.apps.length)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: root.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                                    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                    opacity: 0.7
                                }
                            }

                            Flow {
                                id: catFlow
                                width: parent.width
                                spacing: 4
                                readonly property real tileWidth: Math.floor((width - spacing * (root.tileColumns - 1)) / root.tileColumns)
                                Repeater {
                                    model: catCard.modelData.apps
                                    delegate: AppTile {
                                        required property var modelData
                                        entry: modelData
                                        implicitWidth: catFlow.tileWidth
                                        onActivated: root.launchApp(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }

        ScrollEdgeFade {
            target: appsFlickable
        }

        PagePlaceholder {
            anchors.fill: parent
            shown: (root.mode === "folder" ? root.categorizedApps.length : root.groupedApps.length) === 0
            icon: "apps_outage"
            mascotPose: "chibi-shrug"
            title: Translation.tr("No apps found")
            description: Translation.tr("No desktop applications are visible on this system.")
            descriptionHorizontalAlignment: Text.AlignHCenter
        }
    }

    // Shared app tile: bare icon over transparent background, hover highlight only
    component AppTile: RippleButton {
        id: appBtn
        property var entry
        readonly property string desktopEntryId: String(appBtn.entry?.id ?? "")
            .replace(/\.desktop$/i, "")
        property bool suppressClick: false
        property bool nativeApplicationDragActive: false
        signal activated()
        implicitWidth: 110
        implicitHeight: 98
        dragTarget: appBtn.desktopEntryId.length > 0 ? appDragProxy : null
        pointerDragThreshold: 10
        buttonRadius: root.zzzEverywhere ? Appearance.zzz.panelRadius : Appearance.rounding.normal
        buttonRadiusPressed: root.zzzEverywhere ? Appearance.zzz.cornerRadius : Appearance.rounding.small
        colBackgroundHover: root.surfaceHoverColor
        colBackgroundToggled: root.surfaceActiveColor
        colBackgroundToggledHover: root.surfaceActiveColor
        colRipple: root.surfaceActiveColor
        releaseAction: () => {
            if (appBtn.suppressClick)
                appDragReset.restart()
        }
        cancelAction: () => {
            if (!appBtn.nativeApplicationDragActive) {
                appBtn.suppressClick = false
                appDragReset.stop()
            }
        }
        onPointerDragActiveChanged: {
            if (appBtn.pointerDragActive && appBtn.desktopEntryId.length > 0) {
                appBtn.nativeApplicationDragActive = true
                root.applicationDragActive = true
                appBtn.suppressClick = true
            } else if (!appBtn.nativeApplicationDragActive && appBtn.suppressClick) {
                appDragReset.restart()
            }
        }
        onClicked: {
            if (appBtn.suppressClick) {
                appBtn.suppressClick = false
                return
            }
            appBtn.activated()
        }

        StyledToolTip {
            text: appBtn.entry?.name || ""
        }

        contentItem: Item {
            anchors.fill: parent

            SmartAppIcon {
                id: tileIcon
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                icon: appBtn.entry?.icon || appBtn.entry?.name
                fallback: "application-x-executable"
                iconSize: 40

                scale: appBtn.down ? 0.9 : 1
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            StyledText {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: tileIcon.bottom
                    topMargin: 6
                    leftMargin: 6
                    rightMargin: 6
                }
                text: appBtn.entry?.name || ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                color: root.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer1

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }

        Timer {
            id: appDragReset
            interval: 0
            onTriggered: appBtn.suppressClick = false
        }

        Item {
            id: appDragProxy
            width: appBtn.width
            height: appBtn.height
            z: -100

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.keys: ["application/x-inir-desktop-entry"]
            Drag.mimeData: ({
                "application/x-inir-desktop-entry": appBtn.desktopEntryId
            })
            Drag.imageSource: Quickshell.iconPath(
                String(appBtn.entry?.icon ?? ""), "application-x-executable")
            Drag.imageSourceSize: Qt.size(52, 52)
            Drag.hotSpot: Qt.point(26, 26)
            Drag.active: appBtn.nativeApplicationDragActive && appBtn.desktopEntryId.length > 0
            Drag.onDragFinished: dropAction => {
                appDragProxy.x = 0
                appDragProxy.y = 0
                appBtn.nativeApplicationDragActive = false
                root.applicationDragActive = false
                if (dropAction === Qt.CopyAction)
                    GlobalStates.closeOverview()
                appDragReset.restart()
            }
        }

        Component.onDestruction: root.applicationDragActive = false
    }
}
