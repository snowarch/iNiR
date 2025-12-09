import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets

Scope {
    id: root
    property int panelWidth: 380
    property string searchText: ""
    // Animation and visibility control
    property bool animationsEnabled: Config.options.altSwitcher ? (Config.options.altSwitcher.enableAnimation !== false) : true
    property bool panelVisible: false
    property real panelRightMargin: -panelWidth
    // Snapshot actual de ventanas ordenadas que se usa mientras el panel está abierto
    property var itemSnapshot: []
    property bool useM3Layout: Config.options.altSwitcher && Config.options.altSwitcher.useM3Layout
    property bool centerPanel: Config.options.altSwitcher && Config.options.altSwitcher.panelAlignment === "center"
    property bool compactStyle: Config.options.altSwitcher && Config.options.altSwitcher.compactStyle
    property bool listStyle: Config.options?.altSwitcher?.preset === "list"
    property bool showOverviewWhileSwitching: Config.options.altSwitcher && Config.options.altSwitcher.showOverviewWhileSwitching
    property bool overviewOpenedByAltSwitcher: false



    onUseM3LayoutChanged: {
        // Al cambiar de layout normal 
        // a Material 3 (y viceversa), reseteamos la visibilidad
        // interna si el switcher está cerrado para que se
        // vuelva a construir limpio en el próximo Alt+Tab.
        if (!GlobalStates.altSwitcherOpen) {
            panelVisible = false
        }
    }

    function toTitleCase(name) {
        if (!name)
            return ""
        let s = name.replace(/[._-]+/g, " ")
        const parts = s.split(/\s+/)
        for (let i = 0; i < parts.length; i++) {
            const p = parts[i]
            if (!p)
                continue
            parts[i] = p.charAt(0).toUpperCase() + p.slice(1)
        }
        return parts.join(" ")
    }

    function buildItemsFrom(windows, workspaces, mruIds) {
        if (!windows || !windows.length)
            return []

        const items = []
        const itemsById = {}

        for (let i = 0; i < windows.length; i++) {
            const w = windows[i]
            const appId = w.app_id || ""
            let appName = appId
            if (appName && appName.indexOf(".") !== -1) {
                const parts = appName.split(".")
                appName = parts[parts.length - 1]
            }
            if (!appName && w.title)
                appName = w.title

            appName = toTitleCase(appName)
            const ws = workspaces[w.workspace_id]
            const wsIdx = ws && ws.idx !== undefined ? ws.idx : 0

            const item = {
                id: w.id,
                appId: appId,
                appName: appName,
                title: w.title || "",
                workspaceId: w.workspace_id,
                workspaceIdx: wsIdx
            }
            items.push(item)
            itemsById[item.id] = item
        }

        items.sort(function (a, b) {
            const wa = workspaces[a.workspaceId]
            const wb = workspaces[b.workspaceId]
            const ia = wa ? wa.idx : 0
            const ib = wb ? wb.idx : 0
            if (ia !== ib)
                return ia - ib

            const an = (a.appName || a.title || "").toString()
            const bn = (b.appName || b.title || "").toString()
            const cmp = an.localeCompare(bn)
            if (cmp !== 0)
                return cmp

            return a.id - b.id
        })

        const cfg = Config.options.altSwitcher
        const useMostRecentFirst = cfg && cfg.useMostRecentFirst !== false

        if (useMostRecentFirst && mruIds && mruIds.length > 0) {
            const ordered = []
            const used = {}

            for (let i = 0; i < mruIds.length; i++) {
                const id = mruIds[i]
                const it = itemsById[id]
                if (it) {
                    ordered.push(it)
                    used[id] = true
                }
            }

            for (let i = 0; i < items.length; i++) {
                const it = items[i]
                if (!used[it.id])
                    ordered.push(it)
            }

            return ordered
        }

        return items
    }

    function rebuildSnapshot() {
        const windows = NiriService.windows || []
        const workspaces = NiriService.workspaces || {}
        const mruIds = NiriService.mruWindowIds || []
        itemSnapshot = buildItemsFrom(windows, workspaces, mruIds)
    }

    function ensureSnapshot() {
        if (!itemSnapshot || itemSnapshot.length === 0)
            rebuildSnapshot()
    }

    function maybeOpenOverview() {
        if (!CompositorService.isNiri)
            return
        const cfg = Config.options.altSwitcher
        if (!cfg || !cfg.showOverviewWhileSwitching)
            return
        if (!NiriService.inOverview) {
            overviewOpenedByAltSwitcher = true
            NiriService.toggleOverview()
        } else {
            overviewOpenedByAltSwitcher = false
        }
    }

    function maybeCloseOverview() {
        if (!CompositorService.isNiri)
            return
        const cfg = Config.options.altSwitcher
        if (!cfg || !cfg.showOverviewWhileSwitching)
            return
        if (overviewOpenedByAltSwitcher && NiriService.inOverview) {
            NiriService.toggleOverview()
        }
        overviewOpenedByAltSwitcher = false
    }

    // Fullscreen scrim on all screens: same pattern as Overview, controlled by GlobalStates.altSwitcherOpen.
    Variants {
        id: altSwitcherScrimVariants
        model: Quickshell.screens
        PanelWindow {
            id: scrimRoot
            required property var modelData
            screen: modelData
            visible: GlobalStates.altSwitcherOpen
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell:altSwitcherScrim"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                z: -1
                color: {
                    const cfg = Config.options.altSwitcher
                    const v = (cfg && cfg.scrimDim !== undefined) ? cfg.scrimDim : 35
                    const clamped = Math.max(0, Math.min(100, v))
                    const a = clamped / 100
                    return Qt.rgba(0, 0, 0, a)
                }
                visible: GlobalStates.altSwitcherOpen
            }

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.altSwitcherOpen = false
            }
        }
    }

    PanelWindow {
        id: window
        visible: root.panelVisible
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell:altSwitcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            id: windowMouseArea
            anchors.fill: parent
            onClicked: function (mouse) {
                // mouse.x/mouse.y están en coordenadas del PanelWindow.
                // Cerramos el AltSwitcher solo si el click cae fuera del rectángulo visual del panel.
                if (mouse.x < panel.x || mouse.x > panel.x + panel.width
                        || mouse.y < panel.y || mouse.y > panel.y + panel.height) {
                    GlobalStates.altSwitcherOpen = false
                }
            }
        }

        Keys.onPressed: function (event) {
            if (!GlobalStates.altSwitcherOpen)
                return
            if (event.key === Qt.Key_Escape) {
                GlobalStates.altSwitcherOpen = false
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activateCurrent()
                event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                root.nextItem()
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                root.previousItem()
                event.accepted = true
            }
        }

        Rectangle {
            id: panel
            width: root.listStyle ? 420 : (root.compactStyle ? compactRow.implicitWidth + 40 : root.panelWidth)
            height: root.compactStyle ? 100 : undefined
            color: "transparent"
            border.width: 0

            states: [
                State {
                    name: "right"
                    when: !root.centerPanel && !root.compactStyle && !root.listStyle
                    AnchorChanges {
                        target: panel
                        anchors.right: parent.right
                        anchors.horizontalCenter: undefined
                    }
                    PropertyChanges {
                        target: panel
                        anchors.rightMargin: root.panelRightMargin
                    }
                },
                State {
                    name: "center"
                    when: root.centerPanel || root.compactStyle || root.listStyle
                    AnchorChanges {
                        target: panel
                        anchors.right: undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    PropertyChanges {
                        target: panel
                        anchors.rightMargin: 0
                    }
                }
            ]
            
            anchors.verticalCenter: parent.verticalCenter

            implicitHeight: root.listStyle 
                ? Math.min(listContent.implicitHeight, parent.height - Appearance.sizes.hyprlandGapsOut * 2)
                : (root.compactStyle ? 100 : Math.min(contentColumn.implicitHeight + Appearance.sizes.hyprlandGapsOut * 2,
                                      parent.height - Appearance.sizes.hyprlandGapsOut * 2))

            Rectangle {
                id: panelBackground
                visible: !root.compactStyle && !root.listStyle
                z: 0
                anchors.fill: parent
                radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
                color: {
                    const cfg = Config.options.altSwitcher
                    if (cfg && cfg.useM3Layout)
                        return Appearance.colors.colLayer0
                    const base = ColorUtils.mix(Appearance.colors.colLayer0, Qt.rgba(0, 0, 0, 1), 0.35)
                    const opacity = cfg && cfg.backgroundOpacity !== undefined ? cfg.backgroundOpacity : 0.9
                    return ColorUtils.applyAlpha(base, opacity)
                }
                border.width: Config.options.altSwitcher && Config.options.altSwitcher.useM3Layout ? 1 : 0
                border.color: Appearance.colors.colLayer0Border
            }

            Rectangle {
                id: compactBackground
                visible: root.compactStyle
                anchors.fill: parent
                radius: Appearance.rounding.large
                color: Appearance.m3colors.m3surfaceContainerHigh
                border.width: 0
            }

            StyledRectangularShadow {
                target: root.compactStyle ? compactBackground : panelBackground
            }

            MultiEffect {
                z: 0.5
                anchors.fill: panelBackground
                source: panelBackground
                visible: !root.compactStyle && Config.options.altSwitcher && !Config.options.altSwitcher.useM3Layout && Appearance.effectsEnabled && Config.options.altSwitcher.blurAmount !== undefined && Config.options.altSwitcher.blurAmount > 0
                blurEnabled: true
                blur: Config.options.altSwitcher && Config.options.altSwitcher.blurAmount !== undefined ? Config.options.altSwitcher.blurAmount : 0.4
                blurMax: 64
                saturation: 1.0
            }

            Row {
                id: compactRow
                visible: root.compactStyle
                z: 1
                anchors.centerIn: parent
                spacing: 4
                
                Repeater {
                    model: ScriptModel { values: root.itemSnapshot }
                    
                    Item {
                        required property var modelData
                        required property int index
                        width: 64
                        height: 64
                        
                        Rectangle {
                            id: compactTile
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: Appearance.rounding.normal
                            color: listView.currentIndex === index 
                                   ? Appearance.m3colors.m3primaryContainer 
                                   : Appearance.m3colors.m3surfaceContainerHighest
                            scale: compactMouseArea.pressed ? 0.92 : (compactMouseArea.containsMouse ? 1.05 : 1.0)
                            
                            Behavior on color { 
                                ColorAnimation { 
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                } 
                            }
                            Behavior on scale { 
                                NumberAnimation { 
                                    duration: 200
                                    easing.type: Easing.OutCubic
                                } 
                            }
                            
                            IconImage {
                                id: compactIcon
                                anchors.centerIn: parent
                                width: 40
                                height: 40
                                source: Quickshell.iconPath(
                                    AppSearch.guessIcon(modelData.appId || modelData.appName || modelData.title),
                                    "image-missing"
                                )
                            }
                            
                            Loader {
                                active: Config.options.altSwitcher && Config.options.altSwitcher.monochromeIcons
                                anchors.fill: compactIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desaturatedCompactIcon
                                        visible: false
                                        anchors.fill: parent
                                        source: compactIcon
                                        desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desaturatedCompactIcon
                                        source: desaturatedCompactIcon
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                                    }
                                }
                            }
                            
                            Rectangle {
                                visible: listView.currentIndex === index
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 6
                                width: 24
                                height: 3
                                radius: height / 2
                                color: Appearance.m3colors.m3primary
                            }
                        }
                        
                        MouseArea {
                            id: compactMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                listView.currentIndex = index
                                if (modelData && modelData.id !== undefined) {
                                    NiriService.focusWindow(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            // List mode content
            Rectangle {
                id: listContent
                visible: root.listStyle
                z: 1
                anchors.centerIn: parent
                width: 400
                implicitHeight: listHeader.height + listSeparator.height + listColumn.height
                radius: Appearance.rounding.large
                color: Appearance.colors.colSurfaceContainer

                StyledRectangularShadow {
                    target: listContent
                    blur: 0.5 * Appearance.sizes.elevationMargin
                    spread: 0
                }

                Column {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        id: listHeader
                        width: parent.width
                        height: 44

                        Item { width: 16 }
                        StyledText {
                            text: Translation.tr("Switch windows")
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            text: (root.itemSnapshot?.length ?? 0) + " " + Translation.tr("windows")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        Item { width: 16 }
                    }

                    Rectangle {
                        id: listSeparator
                        width: parent.width
                        height: 1
                        color: Appearance.colors.colLayer0Border
                    }

                    Column {
                        id: listColumn
                        width: parent.width
                        topPadding: 8
                        bottomPadding: 8
                        leftPadding: 8
                        rightPadding: 8
                        spacing: 4

                        Repeater {
                            model: ScriptModel { values: root.itemSnapshot }

                            RippleButton {
                                id: listTile
                                required property var modelData
                                required property int index

                                width: listColumn.width - listColumn.leftPadding - listColumn.rightPadding
                                implicitHeight: 52
                                buttonRadius: Appearance.rounding.normal
                                toggled: listView.currentIndex === index

                                colBackground: "transparent"
                                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                                colBackgroundToggled: Appearance.colors.colPrimaryContainer
                                colBackgroundToggledHover: ColorUtils.mix(Appearance.colors.colPrimaryContainer, Appearance.colors.colPrimary, 0.9)
                                colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                                colRippleToggled: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.7)

                                onClicked: {
                                    listView.currentIndex = index
                                    if (modelData?.id !== undefined) {
                                        NiriService.focusWindow(modelData.id)
                                    }
                                }

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Appearance.colors.colOnPrimaryContainer
                                        visible: listTile.toggled
                                    }

                                    IconImage {
                                        Layout.alignment: Qt.AlignVCenter
                                        width: 32
                                        height: 32
                                        source: Quickshell.iconPath(
                                            AppSearch.guessIcon(listTile.modelData?.appId ?? listTile.modelData?.appName ?? ""),
                                            "image-missing"
                                        )
                                        implicitSize: 32
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: listTile.modelData?.appName ?? listTile.modelData?.title ?? "Window"
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            font.weight: listTile.toggled ? Font.DemiBold : Font.Normal
                                            color: listTile.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: {
                                                const wsIdx = listTile.modelData?.workspaceIdx
                                                const title = listTile.modelData?.title
                                                if (wsIdx && wsIdx > 0 && title && title !== listTile.modelData?.appName)
                                                    return "WS " + wsIdx + " · " + title
                                                if (wsIdx && wsIdx > 0)
                                                    return "WS " + wsIdx
                                                if (title && title !== listTile.modelData?.appName)
                                                    return title
                                                return ""
                                            }
                                            visible: text !== ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: listTile.toggled 
                                                ? ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.3) 
                                                : Appearance.colors.colSubtext
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: (listTile.modelData?.workspaceIdx ?? 0) > 0
                                        width: wsText.implicitWidth + 12
                                        height: 22
                                        radius: Appearance.rounding.small
                                        color: listTile.toggled 
                                            ? ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.85)
                                            : Appearance.colors.colLayer2

                                        StyledText {
                                            id: wsText
                                            anchors.centerIn: parent
                                            text: listTile.modelData?.workspaceIdx ?? ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.DemiBold
                                            color: listTile.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: contentColumn
                visible: !root.compactStyle && !root.listStyle
                z: 1
                anchors.fill: parent
                anchors.margins: Appearance.sizes.hyprlandGapsOut
                spacing: Appearance.sizes.spacingSmall

                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.minimumHeight: 0
                    clip: true
                    spacing: Appearance.sizes.spacingSmall
                    property int rowHeight: (count <= 6
                                              ? 60
                                              : (count <= 10 ? 52 : 44))
                    property int maxVisibleRows: 8
                    implicitHeight: {
                        const minRows = 3
                        const rows = count > 0 ? count : 0
                        const visibleRows = Math.min(rows, maxVisibleRows)
                        const baseRows = visibleRows > 0 ? visibleRows : minRows
                        const base = rowHeight * baseRows + spacing * Math.max(0, baseRows - 1)
                        return base
                    }
                    model: ScriptModel {
                        values: root.itemSnapshot
                    }
                    delegate: Item {
                        id: row
                        required property var modelData
                        width: listView.width
                        height: listView.rowHeight
                        property bool selected: ListView.isCurrentItem

                        // Base highlight for the currently cycled window
                        Rectangle {
                            id: highlightBase
                            anchors.fill: parent
                            radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut
                            visible: selected
                            color: Config.options.altSwitcher && Config.options.altSwitcher.useM3Layout
                                   ? Appearance.m3colors.m3primaryContainer
                                   : Appearance.colors.colLayer1
                        }

                        // Dark gradient towards the left edge inside the highlight
                        Rectangle {
                            anchors.fill: parent
                            radius: highlightBase.radius
                            visible: selected
                            color: "transparent"
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            // Left dot indicator for the currently selected window
                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                width: 12
                                height: 12

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 8
                                    height: 8
                                    radius: width / 2
                                    color: Appearance.colors.colOnLayer1
                                    visible: selected
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    text: modelData.appName || modelData.title || "Window"
                                    color: {
                                        const selected = row.selected
                                        const cfg = Config.options.altSwitcher
                                        const useM3 = cfg && cfg.useM3Layout
                                        if (useM3 && selected)
                                            return Appearance.m3colors.m3onPrimaryContainer
                                        if (useM3)
                                            return Appearance.m3colors.m3onSurface
                                        return Appearance.colors.colOnLayer1
                                    }
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    elide: Text.ElideRight
                                }

                                Item {
                                    Layout.fillWidth: true
                                    height: Appearance.font.pixelSize.small * 1.6

                                    StyledText {
                                        id: subtitleText
                                        anchors.fill: parent
                                        text: {
                                            const wsIdx = modelData.workspaceIdx
                                            const title = modelData.title
                                            if (wsIdx && wsIdx > 0 && title)
                                                return "WS " + wsIdx + " · " + title
                                            if (wsIdx && wsIdx > 0)
                                                return "WS " + wsIdx
                                            return title
                                        }
                                        color: {
                                            const selected = row.selected
                                            const cfg = Config.options.altSwitcher
                                            const useM3 = cfg && cfg.useM3Layout
                                            if (useM3 && selected)
                                                return Appearance.m3colors.m3onPrimaryContainer
                                            if (useM3)
                                                return Appearance.colors.colSubtext
                                            return ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.6)
                                        }
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // App icon on the right, resolved via AppSearch like Overview
                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                width: listView.rowHeight * 0.6
                                height: listView.rowHeight * 0.6

                                IconImage {
                                    id: altSwitcherIcon
                                    anchors.fill: parent
                                    source: Quickshell.iconPath(
                                        AppSearch.guessIcon(modelData.appId || modelData.appName || modelData.title),
                                        "image-missing"
                                    )
                                    implicitSize: parent.height
                                }

                                // Optional monochrome tint, same pattern as dock/workspaces
                                Loader {
                                    active: Config.options.altSwitcher && Config.options.altSwitcher.monochromeIcons
                                    anchors.fill: altSwitcherIcon
                                    sourceComponent: Item {
                                        Desaturate {
                                            id: desaturatedAltSwitcherIcon
                                            visible: false // ColorOverlay handles final output
                                            anchors.fill: parent
                                            source: altSwitcherIcon
                                            desaturation: 0.8
                                        }
                                        ColorOverlay {
                                            anchors.fill: desaturatedAltSwitcherIcon
                                            source: desaturatedAltSwitcherIcon
                                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: function () {
                                listView.currentIndex = index
                                row.activate()
                            }
                        }

                        function activate() {
                            if (modelData && modelData.id !== undefined) {
                                NiriService.focusWindow(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        Timer {
            id: autoHideTimer
            interval: Config.options.altSwitcher && Config.options.altSwitcher.autoHideDelayMs !== undefined
                      ? Config.options.altSwitcher.autoHideDelayMs
                      : 500
            repeat: false
            onTriggered: GlobalStates.altSwitcherOpen = false
        }

        Connections {
            target: GlobalStates
            function onAltSwitcherOpenChanged() {
                if (GlobalStates.altSwitcherOpen) {
                    root.showPanel()
                    root.maybeOpenOverview()
                } else {
                    root.hidePanel()
                    root.maybeCloseOverview()
                }
            }
        }

        Connections {
            target: NiriService
            function onWindowsChanged() {
                if (!GlobalStates.altSwitcherOpen || !root.itemSnapshot || root.itemSnapshot.length === 0)
                    return

                const wins = NiriService.windows || []
                if (!wins.length) {
                    root.itemSnapshot = []
                    listView.currentIndex = -1
                    GlobalStates.altSwitcherOpen = false
                    return
                }

                const alive = {}
                for (let i = 0; i < wins.length; i++) {
                    alive[wins[i].id] = true
                }

                const filtered = []
                for (let i = 0; i < root.itemSnapshot.length; i++) {
                    const it = root.itemSnapshot[i]
                    if (alive[it.id])
                        filtered.push(it)
                }

                if (filtered.length === 0) {
                    GlobalStates.altSwitcherOpen = false
                    return
                }

                root.itemSnapshot = filtered

                if (listView.currentIndex >= filtered.length) {
                    listView.currentIndex = filtered.length - 1
                }
            }
        }

        NumberAnimation {
            id: slideInAnim
            target: root
            property: "panelRightMargin"
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOutAnim
            target: root
            property: "panelRightMargin"
            easing.type: Easing.InCubic
            onFinished: {
                if (!GlobalStates.altSwitcherOpen) {
                    root.panelVisible = false
                }
            }
        }
    }

    function currentAnimDuration() {
        const cfg = Config.options.altSwitcher
        if (cfg && cfg.animationDurationMs !== undefined)
            return cfg.animationDurationMs
        return 200
    }

    function showPanel() {
        rebuildSnapshot()
        panelVisible = true
        if (animationsEnabled && !centerPanel && !compactStyle) {
            const dur = currentAnimDuration()
            slideOutAnim.stop()
            root.panelRightMargin = -panelWidth
            slideInAnim.from = -panelWidth
            slideInAnim.to = 0
            slideInAnim.duration = dur
            slideInAnim.restart()
        } else {
            panelRightMargin = 0
        }
    }

    function hidePanel() {
        if (!panelVisible)
            return
        if (animationsEnabled && !centerPanel) {
            const dur = currentAnimDuration()
            slideInAnim.stop()
            slideOutAnim.from = panelRightMargin
            slideOutAnim.to = -panelWidth
            slideOutAnim.duration = dur
            slideOutAnim.restart()
        } else {
            panelRightMargin = -panelWidth
            panelVisible = false
        }
    }

    function hasItems() {
        ensureSnapshot()
        return itemSnapshot && itemSnapshot.length > 0
    }

    function ensureOpen() {
        if (!GlobalStates.altSwitcherOpen) {
            GlobalStates.altSwitcherOpen = true
        }
    }

    function nextItem() {
        ensureSnapshot()
        const total = itemSnapshot ? itemSnapshot.length : 0
        if (total === 0)
            return
        if (listView.currentIndex < 0)
            listView.currentIndex = 0
        else
            listView.currentIndex = (listView.currentIndex + 1) % total
        listView.positionViewAtIndex(listView.currentIndex, ListView.Visible)
    }

    function previousItem() {
        ensureSnapshot()
        const total = itemSnapshot ? itemSnapshot.length : 0
        if (total === 0)
            return
        if (listView.currentIndex < 0)
            listView.currentIndex = total - 1
        else
            listView.currentIndex = (listView.currentIndex - 1 + total) % total
        listView.positionViewAtIndex(listView.currentIndex, ListView.Visible)
    }

    function activateCurrent() {
        if (listView.currentItem && listView.currentItem.activate) {
            listView.currentItem.activate()
        }
    }



    // Only handle IPC when Material ii family is active
    property bool isActive: Config.options?.panelFamily !== "waffle"

    IpcHandler {
        target: "altSwitcher"
        enabled: root.isActive

        function open(): void {
            ensureOpen()
            autoHideTimer.restart()
        }

        function close(): void {
            GlobalStates.altSwitcherOpen = false
        }

        function toggle(): void {
            GlobalStates.altSwitcherOpen = !GlobalStates.altSwitcherOpen
            if (GlobalStates.altSwitcherOpen)
                autoHideTimer.restart()
        }

        function next(): void {
            ensureOpen()
            nextItem()
            activateCurrent()
            autoHideTimer.restart()
        }

        function previous(): void {
            ensureOpen()
            previousItem()
            activateCurrent()
            autoHideTimer.restart()
        }
    }
}
