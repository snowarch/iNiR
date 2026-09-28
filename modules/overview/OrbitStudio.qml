pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

FocusScope {
    id: root

    required property var effectiveOptions
    required property bool dirty
    required property real availableWidth
    required property real availableHeight
    required property bool docked
    property bool workspaceMode: false

    signal previewRequested(string path, var value)
    signal commitRequested()
    signal revertRequested()
    signal resetDefaultsRequested()
    signal dismissed()
    signal moveStarted()
    signal moveRequested(real deltaX, real deltaY)
    signal resizeStarted()
    signal resizeRequested(real deltaX, real deltaY)
    signal resetGeometryRequested()
    signal dockRequested(bool docked)
    signal heightHintRequested(real height)

    property string section: "scene"
    property real revealProgress: 0
    property real sectionReveal: 1
    property bool resetArmed: false
    readonly property var orbital: effectiveOptions?.orbital ?? ({})
    readonly property var workspaceSurface: orbital.surface ?? ({})
    readonly property var geometry: orbital.geometry ?? ({})
    readonly property var presentation: effectiveOptions?.presentation ?? ({})
    readonly property var studioOptions: effectiveOptions?.studio ?? ({})
    readonly property var navigationMotion: effectiveOptions?.navigationMotion ?? ({})
    readonly property var shelf: effectiveOptions?.shelf ?? ({})
    readonly property int effectiveNavigationDuration: OrbitTuning.navigationDuration(
        navigationMotion, activeView === "stage" ? "stage" : activeView)
    readonly property string effectiveNavigationEasing: OrbitTuning.navigationEasing(navigationMotion)
    readonly property string effectiveEntryStyle: OrbitTuning.presentationEntryStyle(presentation)
    readonly property string effectiveEntryDirection: OrbitTuning.presentationDirection(
        presentation, activeView === "stage" ? "stage" : "orbital", activeView)
    readonly property int effectivePresentationDistance: OrbitTuning.presentationDistance(presentation)
    readonly property int effectiveEnterDuration: OrbitTuning.presentationEnterDuration(presentation)
    readonly property int effectiveExitDuration: OrbitTuning.presentationExitDuration(presentation)
    readonly property int effectiveEntryDelay: OrbitTuning.presentationEntryDelay(presentation)
    readonly property int effectiveEntryStagger: OrbitTuning.presentationStagger(presentation)
    readonly property int effectiveShelfDelay: OrbitTuning.presentationShelfDelay(presentation)
    readonly property int effectiveEntryOpacityPercent: Math.round(OrbitTuning.presentationEntryOpacity(presentation) * 100)
    readonly property string workspaceLabelMode: {
        const configured = String(orbital.workspaceLabelMode ?? "")
        if (["index", "name", "workspace", "full", "off"].includes(configured))
            return configured
        return (orbital.showWorkspaceLabels ?? true) ? "index" : "off"
    }
    readonly property string activeView: effectiveOptions?.stageMode === "stage"
        ? "stage" : ["horizon", "gallery", "deck", "atlas"].includes(orbital.layout)
            ? orbital.layout : "orbit"
    readonly property string sectionTitle: root.section === "scene" ? Translation.tr("Scene")
        : root.section === "camera" ? Translation.tr("Depth")
        : root.section === "atmosphere" ? Translation.tr("Look")
        : root.section === "motion" ? Translation.tr("Motion")
        : root.section === "shelf" ? Translation.tr("Shelf")
        : Translation.tr("Advanced")
    readonly property string sectionSummary: root.section === "scene"
        ? Translation.tr("Layout, profiles and workspace identity")
        : root.section === "camera"
            ? Translation.tr("Depth, previews and workspace surfaces")
        : root.section === "atmosphere"
            ? Translation.tr("Backdrop, blur and scene atmosphere")
        : root.section === "motion"
            ? Translation.tr("Workspace navigation and Orbit presentation")
        : root.section === "shelf"
            ? Translation.tr("Shelf layout, material and visible modules")
        : Translation.tr("Fine geometry and interaction controls")
    readonly property string sectionIcon: root.section === "scene" ? "view_in_ar"
        : root.section === "camera" ? "layers"
        : root.section === "atmosphere" ? "palette"
        : root.section === "motion" ? "animation"
        : root.section === "shelf" ? "dock_to_bottom" : "tune"
    readonly property real controlColumnWidth: Math.max(292,
        Math.min(root.workspaceMode ? 376 : root.docked ? 448 : 336,
            sectionLoader.width - 12))
    readonly property real chromeHeight: 36 + 10 + 38 + 10 + 1 + 10 + 1 + 10 + 40 + 28
    readonly property real preferredHeight: Math.max(360, Math.min(620,
        chromeHeight + (sectionLoader.item?.implicitHeight ?? 110)))
    readonly property int idealHeight: Math.ceil(Math.max(380, Math.min(620,
        208 + (sectionLoader.height || 0))))

    implicitWidth: root.workspaceMode ? 404
        : Math.max(360, Math.min(root.docked ? 520 : 420, availableWidth))
    implicitHeight: root.workspaceMode ? 520
        : Math.max(440, Math.min(500, availableHeight))
    opacity: revealProgress
    transform: Translate {
        x: root.docked ? Math.round((1 - root.revealProgress) * 52)
            : Math.round((1 - root.revealProgress) * 10)
    }

    Component.onCompleted: {
        revealProgress = 1
        Qt.callLater(() => root.heightHintRequested(root.idealHeight))
    }
    onSectionChanged: {
        sectionViewport.contentY = 0
        root.sectionReveal = 0
        sectionEnter.restart()
        Qt.callLater(() => root.heightHintRequested(root.idealHeight))
    }
    onIdealHeightChanged: Qt.callLater(() => root.heightHintRequested(root.idealHeight))

    Behavior on revealProgress {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    NumberAnimation {
        id: sectionEnter
        target: root
        property: "sectionReveal"
        from: 0
        to: 1
        duration: 120
        easing.type: Easing.OutCubic
    }

    Timer {
        id: resetArmTimer
        interval: 3000
        onTriggered: root.resetArmed = false
    }

    function focusFirst(): void {
        if (root.workspaceMode)
            workspaceSceneTab.forceActiveFocus()
        else
            sceneTab.forceActiveFocus()
    }

    function chooseNavigationPreset(preset: string): void {
        root.previewRequested("navigationMotion.advanced", false)
        root.previewRequested("navigationMotion.preset", preset)
    }

    function applyOrbitProfile(profile: string): void {
        const updates = OrbitTuning.profileUpdates(profile)
        root.applyUpdateMap(updates)
    }

    function applyUpdateMap(updates): void {
        for (const fullPath in updates) {
            if (!fullPath.startsWith("orbit."))
                continue
            root.previewRequested(fullPath.slice(6), updates[fullPath])
        }
    }

    function saveUserProfile(): void {
        Config.setNestedValue("orbit.userPresetJson",
            OrbitTuning.captureUserPreset(root.effectiveOptions))
    }

    function applyUserProfile(): void {
        root.applyUpdateMap(OrbitTuning.userPresetUpdates(
            String(root.effectiveOptions?.userPresetJson ?? "")))
    }

    function setGeometryValue(key: string, value): void {
        root.previewRequested("orbital.geometry.advanced", true)
        root.previewRequested(`orbital.geometry.${key}`, value)
    }

    function choosePresentationPreset(preset: string): void {
        root.previewRequested("presentation.advanced", false)
        root.previewRequested("presentation.preset", preset)
    }

    Keys.onPressed: event => {
        if (!(event.modifiers & Qt.AltModifier))
            return
        const step = 16
        const horizontal = event.key === Qt.Key_Left ? -step
            : event.key === Qt.Key_Right ? step : 0
        const vertical = event.key === Qt.Key_Up ? -step
            : event.key === Qt.Key_Down ? step : 0
        if (horizontal === 0 && vertical === 0)
            return
        if (event.modifiers & Qt.ShiftModifier) {
            root.resizeStarted()
            root.resizeRequested(horizontal, vertical)
        } else {
            root.moveStarted()
            root.moveRequested(horizontal, vertical)
        }
        event.accepted = true
    }

    function chooseView(view: string): void {
        if (view === "stage") {
            root.previewRequested("stageMode", "stage")
            return
        }
        root.previewRequested("stageMode", "orbital")
        root.previewRequested("orbital.layout", ["horizon", "gallery", "deck", "atlas"].includes(view)
            ? view : "orbit")
    }

    component DeckChip: SelectionGroupButton {
        id: deckChip
        property string chipIcon: ""
        property bool selected: false
        readonly property color studioContentColor: Appearance.regaliaEverywhere
            ? (deckChip.toggled ? Appearance.regalia.primaryPlateInk : Appearance.regalia.onColor)
            : Appearance.zzzEverywhere
                ? (deckChip.toggled ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                : (deckChip.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer)

        buttonText: deckChip.text
        buttonIcon: chipIcon
        toggled: selected
        bounce: false
        enableImplicitWidthAnimation: false
        enableImplicitHeightAnimation: false
        horizontalPadding: 9
        verticalPadding: 5
        Layout.fillWidth: true
        leftmost: (parent?.orbitChoiceGrid ?? false) || indexInParent === 0
        rightmost: (parent?.orbitChoiceGrid ?? false)
            || indexInParent === ((parent?.children?.length ?? 1) - 1)

        contentItem: Item {
            implicitWidth: Math.min(centeredContent.implicitWidth, 168)
            implicitHeight: centeredContent.implicitHeight
            clip: true

            RowLayout {
                id: centeredContent
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: deckChip.chipIcon.length > 0 && deckChip.text.length > 0 ? 5 : 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: visible ? implicitWidth : 0
                    Layout.maximumWidth: implicitWidth
                    visible: deckChip.chipIcon.length > 0
                    text: deckChip.chipIcon
                    iconSize: Appearance.font.pixelSize.normal
                    textRenderType: Text.QtRendering
                    color: deckChip.studioContentColor
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter
                    visible: deckChip.text.length > 0
                    text: deckChip.text
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    renderType: Text.QtRendering
                    color: deckChip.studioContentColor
                    font.weight: deckChip.toggled ? Font.DemiBold : Font.Medium
                }
            }
        }
    }

    component MetricSlider: StyledSlider {
        enableSettingsSearch: false
        configuration: StyledSlider.Configuration.XS
        Layout.fillWidth: false
        Layout.preferredWidth: 118
        stopIndicatorValues: []
    }

    component MetricControl: Item {
        id: metricControl
        required property string labelText
        property real from: 0
        property real to: 100
        property real stepSize: 1
        property real value: 0
        property string valueText: String(Math.round(value))
        property string descriptionText: ""
        property bool controlEnabled: true
        signal moved(real value)

        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: 48
        opacity: controlEnabled ? 1 : 0.48

        HoverHandler {
            id: metricHover
            enabled: metricControl.controlEnabled && metricControl.descriptionText.length > 0
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                text: `${metricControl.labelText}  ${metricControl.valueText}`
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
            }
            MetricSlider {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(126, Math.max(96, parent.width - 12))
                enabled: metricControl.controlEnabled
                from: metricControl.from
                to: metricControl.to
                stepSize: metricControl.stepSize
                value: metricControl.value
                tooltipContent: metricControl.valueText
                onMoved: metricControl.moved(value)
            }
        }

        M3ToolTip {
            text: metricControl.descriptionText
            enabled: metricControl.controlEnabled && metricControl.descriptionText.length > 0
            extraVisibleCondition: metricHover.hovered
        }
    }

    component MetricGrid: Item {
        id: metricGrid
        default property alias metrics: metricsLayout.data
        readonly property int columnCount: root.docked && root.controlColumnWidth >= 420 ? 3
            : root.controlColumnWidth >= 300 ? 2 : 1

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.controlColumnWidth
        Layout.preferredHeight: metricsLayout.implicitHeight

        GridLayout {
            id: metricsLayout
            anchors.fill: parent
            columns: metricGrid.columnCount
            columnSpacing: root.studioOptions.density === "comfortable" ? 12 : 8
            rowSpacing: root.studioOptions.density === "comfortable" ? 8 : 5
            uniformCellWidths: true
            uniformCellHeights: true
        }
    }

    component ChoiceControl: ColumnLayout {
        id: choiceControl
        required property string labelText
        property string descriptionText: ""
        default property alias choices: choiceGrid.data
        readonly property int choiceCount: choiceGrid.children.length
        property int columnCountOverride: 0
        readonly property int columnCount: columnCountOverride > 0 ? columnCountOverride
            : choiceCount <= 3 ? Math.max(1, choiceCount)
            : root.controlColumnWidth >= 430 ? 3 : 2

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.controlColumnWidth
        spacing: root.studioOptions.density === "comfortable" ? 6 : 4

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: choiceControl.labelText
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
        }

        StyledText {
            Layout.fillWidth: true
            visible: choiceControl.descriptionText.length > 0
                && (root.studioOptions.showDescriptions ?? true)
            horizontalAlignment: Text.AlignHCenter
            text: choiceControl.descriptionText
            elide: Text.ElideRight
            maximumLineCount: 1
            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.48)
            font.pixelSize: Appearance.font.pixelSize.smaller
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: choiceControl.width
            Layout.preferredHeight: choiceGrid.implicitHeight
            GridLayout {
                id: choiceGrid
                property bool orbitChoiceGrid: true
                anchors.fill: parent
                columns: choiceControl.columnCount
                columnSpacing: 4
                rowSpacing: 4
                uniformCellWidths: true
                uniformCellHeights: true
            }
        }
    }

    component ControlRail: Item {
        id: controlRail
        default property alias controls: railGroup.contentData
        property bool compact: false

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: compact ? Math.min(214, root.controlColumnWidth) : root.controlColumnWidth
        Layout.preferredHeight: railGroup.implicitHeight

        ButtonGroup {
            id: railGroup
            anchors.fill: parent
            spacing: 4
            uniformCellSizes: true
        }
    }

    component SectionIntro: ColumnLayout {
        id: sectionIntro
        required property string titleText
        required property string descriptionText

        visible: !root.workspaceMode
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.controlColumnWidth
        Layout.preferredHeight: visible ? implicitHeight : 0
        spacing: 2

        StyledText {
            text: sectionIntro.titleText
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            Layout.fillWidth: true
            visible: root.studioOptions.showDescriptions ?? true
            text: sectionIntro.descriptionText
            wrapMode: Text.WordWrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    component NavigationFineControls: ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.controlColumnWidth
        spacing: 8

        MetricGrid {
            MetricControl {
                controlEnabled: (root.navigationMotion.preset ?? "fluid") !== "instant"
                labelText: Translation.tr("Navigation time")
                descriptionText: Translation.tr("Duration of workspace changes triggered by scroll or selection")
                from: 80; to: 600; stepSize: 10
                value: root.effectiveNavigationDuration
                valueText: `${Math.round(value)} ms`
                onMoved: value => {
                    root.previewRequested("navigationMotion.advanced", true)
                    root.previewRequested("navigationMotion.durationMs", Math.round(value))
                }
            }
        }

        ChoiceControl {
            visible: (root.navigationMotion.preset ?? "fluid") !== "instant"
            labelText: Translation.tr("Navigation curve")
            descriptionText: Translation.tr("Interpolation used while workspace cards settle")
            DeckChip {
                text: Translation.tr("Direct")
                selected: root.effectiveNavigationEasing === "direct"
                onClicked: {
                    root.previewRequested("navigationMotion.advanced", true)
                    root.previewRequested("navigationMotion.easing", "direct")
                }
            }
            DeckChip {
                text: Translation.tr("Smooth")
                selected: root.effectiveNavigationEasing === "smooth"
                onClicked: {
                    root.previewRequested("navigationMotion.advanced", true)
                    root.previewRequested("navigationMotion.easing", "smooth")
                }
            }
            DeckChip {
                text: Translation.tr("Linear")
                selected: root.effectiveNavigationEasing === "linear"
                onClicked: {
                    root.previewRequested("navigationMotion.advanced", true)
                    root.previewRequested("navigationMotion.easing", "linear")
                }
            }
        }
    }

    component PresentationFineControls: ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: root.controlColumnWidth
        spacing: 8

        ChoiceControl {
            visible: (root.presentation.preset ?? "adaptive") !== "instant"
            labelText: Translation.tr("Entry assembly")
            DeckChip { text: Translation.tr("Fade"); selected: root.effectiveEntryStyle === "fade"; onClicked: { root.previewRequested("presentation.advanced", true); root.previewRequested("presentation.entryStyle", "fade") } }
            DeckChip { text: Translation.tr("Drift"); selected: root.effectiveEntryStyle === "drift"; onClicked: { root.previewRequested("presentation.advanced", true); root.previewRequested("presentation.entryStyle", "drift") } }
            DeckChip { text: Translation.tr("Cascade"); selected: root.effectiveEntryStyle === "cascade"; onClicked: { root.previewRequested("presentation.advanced", true); root.previewRequested("presentation.entryStyle", "cascade") } }
            DeckChip { text: Translation.tr("Instant"); selected: root.effectiveEntryStyle === "instant"; onClicked: { root.previewRequested("presentation.advanced", true); root.previewRequested("presentation.entryStyle", "instant") } }
        }

        ChoiceControl {
            visible: (root.presentation.preset ?? "adaptive") !== "instant"
            labelText: Translation.tr("Entry edge")
            DeckChip { text: Translation.tr("Center"); selected: root.effectiveEntryDirection === "center"; onClicked: { root.previewRequested("presentation.advanced", true); root.previewRequested("presentation.direction", "center") } }
            DeckChip { text: Translation.tr("Top"); selected: root.effectiveEntryDirection === "top"; onClicked: { root.previewRequested("presentation.advanced", true); root.previewRequested("presentation.direction", "top") } }
            DeckChip { text: Translation.tr("Bottom"); selected: root.effectiveEntryDirection === "bottom"; onClicked: { root.previewRequested("presentation.advanced", true); root.previewRequested("presentation.direction", "bottom") } }
            DeckChip { text: Translation.tr("Left"); selected: root.effectiveEntryDirection === "left"; onClicked: { root.previewRequested("presentation.advanced", true); root.previewRequested("presentation.direction", "left") } }
            DeckChip { text: Translation.tr("Right"); selected: root.effectiveEntryDirection === "right"; onClicked: { root.previewRequested("presentation.advanced", true); root.previewRequested("presentation.direction", "right") } }
        }

        MetricGrid {
            visible: (root.presentation.preset ?? "adaptive") !== "instant"
            MetricControl {
                labelText: Translation.tr("Travel")
                descriptionText: Translation.tr("Initial distance between the stage and its settled position")
                from: 0; to: 160; stepSize: 4
                value: root.effectivePresentationDistance
                valueText: `${Math.round(value)} px`
                onMoved: value => {
                    root.previewRequested("presentation.advanced", true)
                    root.previewRequested("presentation.distance", Math.round(value))
                }
            }
            MetricControl {
                labelText: Translation.tr("Pre-roll")
                descriptionText: Translation.tr("Delay between backdrop appearance and stage assembly")
                from: 0; to: 240; stepSize: 8
                value: root.effectiveEntryDelay
                valueText: `${Math.round(value)} ms`
                onMoved: value => {
                    root.previewRequested("presentation.advanced", true)
                    root.previewRequested("presentation.entryDelayMs", Math.round(value))
                }
            }
            MetricControl {
                labelText: Translation.tr("Start opacity")
                descriptionText: Translation.tr("Stage opacity at the beginning of entry")
                from: 0; to: 90; stepSize: 5
                value: root.effectiveEntryOpacityPercent
                valueText: `${Math.round(value)}%`
                onMoved: value => {
                    root.previewRequested("presentation.advanced", true)
                    root.previewRequested("presentation.entryOpacityPercent", Math.round(value))
                }
            }
            MetricControl {
                labelText: Translation.tr("Card stagger")
                descriptionText: Translation.tr("Delay between successive workspace cards during entry")
                from: 0; to: 120; stepSize: 4
                value: root.effectiveEntryStagger
                valueText: `${Math.round(value)} ms`
                onMoved: value => {
                    root.previewRequested("presentation.advanced", true)
                    root.previewRequested("presentation.entryStaggerMs", Math.round(value))
                }
            }
            MetricControl {
                labelText: Translation.tr("Shelf delay")
                descriptionText: Translation.tr("How long the Shelf waits before joining the entry")
                from: 0; to: 240; stepSize: 8
                value: root.effectiveShelfDelay
                valueText: `${Math.round(value)} ms`
                onMoved: value => {
                    root.previewRequested("presentation.advanced", true)
                    root.previewRequested("presentation.shelfDelayMs", Math.round(value))
                }
            }
        }

        MetricGrid {
            visible: (root.presentation.preset ?? "adaptive") !== "instant"
            MetricControl {
                labelText: Translation.tr("Enter")
                descriptionText: Translation.tr("Total stage assembly duration")
                from: 80; to: 600; stepSize: 10
                value: root.effectiveEnterDuration
                valueText: `${Math.round(value)} ms`
                onMoved: value => {
                    root.previewRequested("presentation.advanced", true)
                    root.previewRequested("presentation.enterDurationMs", Math.round(value))
                }
            }
            MetricControl {
                labelText: Translation.tr("Exit")
                descriptionText: Translation.tr("Host-level Orbit exit duration")
                from: 60; to: 500; stepSize: 10
                value: root.effectiveExitDuration
                valueText: `${Math.round(value)} ms`
                onMoved: value => {
                    root.previewRequested("presentation.advanced", true)
                    root.previewRequested("presentation.exitDurationMs", Math.round(value))
                }
            }
        }
    }

    PanelSurface {
        anchors.fill: parent
        elevation: 3
        cardStyle: true
        outlined: true
        clipContent: true
        opaqueSurface: root.studioOptions.surfaceStyle !== "ricelin"
        islandSkin: root.studioOptions.surfaceStyle === "ricelin"
        surfaceDialect: root.studioOptions.surfaceStyle === "ricelin"
            ? "island" : Appearance.surfaceDialectFor("")
        wallpaperBackdrop: root.studioOptions.surfaceStyle === "ricelin"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        // Studio is a modal editing surface inside Orbit. Own wheel input at
        // the overlay itself so no child/control can accidentally let it reach
        // the spatial stage behind the editor.
        WheelHandler {
            target: null
            blocking: true
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const maxY = Math.max(0, sectionViewport.contentHeight - sectionViewport.height)
                const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y
                if (maxY > 0)
                    sectionViewport.contentY = Math.max(0, Math.min(maxY,
                        sectionViewport.contentY - delta))
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.workspaceMode ? 12 : 14
            spacing: root.workspaceMode ? 8 : 10

            RowLayout {
                id: studioHeader
                visible: !root.workspaceMode
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 36 : 0
                spacing: 8

                Item {
                    id: titleGrip
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34

                    HoverHandler {
                        id: moveHover
                        enabled: !root.docked
                        cursorShape: moveDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    }
                    DragHandler {
                        id: moveDrag
                        target: null
                        enabled: !root.docked
                        acceptedButtons: Qt.LeftButton
                        onActiveChanged: if (active) root.moveStarted()
                        onTranslationChanged: if (active) root.moveRequested(translation.x, translation.y)
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 8

                        MaterialSymbol {
                            text: "tune"
                            iconSize: 20
                            textRenderType: Text.QtRendering
                            color: Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0
                            StyledText {
                                text: Translation.tr("Orbit Studio")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: root.dirty
                                    ? Translation.tr("LIVE · session preview")
                                    : root.docked ? Translation.tr("FOCUS · docked live editor")
                                        : Translation.tr("LIVE · editing current Orbit")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: root.dirty ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                IconToolbarButton {
                    Layout.fillHeight: false
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    text: root.docked ? "open_in_full" : "dock_to_right"
                    iconRenderType: Text.QtRendering
                    onClicked: root.dockRequested(!root.docked)
                    M3ToolTip {
                        text: root.docked ? Translation.tr("Detach Studio")
                            : Translation.tr("Dock Studio to the right edge")
                    }
                }

                IconToolbarButton {
                    Layout.fillHeight: false
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    text: "center_focus_strong"
                    iconRenderType: Text.QtRendering
                    visible: !root.docked
                    onClicked: root.resetGeometryRequested()
                    M3ToolTip { text: Translation.tr("Reset Studio position and size") }
                }

                IconToolbarButton {
                    Layout.fillHeight: false
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    text: "settings"
                    iconRenderType: Text.QtRendering
                    onClicked: {
                        root.dismissed()
                        GlobalStates.openSettingsPage(27)
                    }
                    M3ToolTip { text: Translation.tr("Advanced Orbit settings") }
                }

                IconToolbarButton {
                    Layout.fillHeight: false
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    text: "close"
                    iconRenderType: Text.QtRendering
                    onClicked: root.dismissed()
                    M3ToolTip { text: Translation.tr("Close Studio") }
                }
            }

            RowLayout {
                visible: root.workspaceMode
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 42 : 0
                spacing: 9

                MaterialSymbol {
                    text: root.sectionIcon
                    iconSize: 20
                    textRenderType: Text.QtRendering
                    color: Appearance.colors.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: root.sectionTitle
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.sectionSummary
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.56)
                    }
                }

                StyledText {
                    visible: root.dirty
                    text: Translation.tr("LIVE")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colPrimary
                }
            }

            Item {
                visible: true
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.controlColumnWidth
                Layout.preferredHeight: root.workspaceMode ? 64 : studioTabs.implicitHeight

                ButtonGroup {
                    id: studioTabs
                    visible: !root.workspaceMode
                    anchors.fill: parent
                    spacing: 4
                    uniformCellSizes: true
                    DeckChip {
                        id: sceneTab
                        text: Translation.tr("Scene")
                        selected: root.section === "scene"
                        onClicked: root.section = "scene"
                    }
                    DeckChip {
                        text: Translation.tr("Camera")
                        selected: root.section === "camera"
                        onClicked: root.section = "camera"
                    }
                    DeckChip {
                        text: Translation.tr("Look")
                        chipIcon: "blur_on"
                        selected: root.section === "atmosphere"
                        onClicked: root.section = "atmosphere"
                    }
                    DeckChip {
                        text: Translation.tr("Motion")
                        selected: root.section === "motion"
                        onClicked: root.section = "motion"
                    }
                    DeckChip {
                        text: Translation.tr("Shelf")
                        selected: root.section === "shelf"
                        onClicked: root.section = "shelf"
                    }
                    DeckChip {
                        text: Translation.tr("Advanced")
                        chipIcon: "tune"
                        selected: root.section === "advanced"
                        onClicked: root.section = "advanced"
                    }
                }

                GridLayout {
                    visible: root.workspaceMode
                    anchors.fill: parent
                    columns: 3
                    columnSpacing: 4
                    rowSpacing: 4

                    DeckChip {
                        id: workspaceSceneTab
                        text: Translation.tr("Scene")
                        chipIcon: "view_in_ar"
                        selected: root.section === "scene"
                        onClicked: root.section = "scene"
                    }
                    DeckChip {
                        text: Translation.tr("Depth")
                        chipIcon: "layers"
                        selected: root.section === "camera"
                        onClicked: root.section = "camera"
                    }
                    DeckChip {
                        text: Translation.tr("Look")
                        chipIcon: "palette"
                        selected: root.section === "atmosphere"
                        onClicked: root.section = "atmosphere"
                    }
                    DeckChip {
                        text: Translation.tr("Motion")
                        chipIcon: "animation"
                        selected: root.section === "motion"
                        onClicked: root.section = "motion"
                    }
                    DeckChip {
                        text: Translation.tr("Shelf")
                        chipIcon: "dock_to_bottom"
                        selected: root.section === "shelf"
                        onClicked: root.section = "shelf"
                    }
                    DeckChip {
                        text: Translation.tr("Advanced")
                        chipIcon: "tune"
                        selected: root.section === "advanced"
                        onClicked: root.section = "advanced"
                    }
                }
            }

            Rectangle {
                visible: true
                Layout.fillWidth: true
                implicitHeight: 1
                color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.55)
            }

            StyledFlickable {
                id: sectionViewport
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: width
                contentHeight: sectionLoader.height

                Loader {
                    id: sectionLoader
                    width: sectionViewport.width
                    height: item?.implicitHeight ?? 0
                    opacity: root.sectionReveal
                    sourceComponent: root.section === "scene" ? sceneSection
                        : root.section === "camera" ? cameraSection
                        : root.section === "atmosphere" ? atmosphereSection
                        : root.section === "motion" ? motionSection
                        : root.section === "shelf" ? shelfSection : advancedSection
                }
            }

            Rectangle {
                visible: !root.workspaceMode
                Layout.fillWidth: true
                implicitHeight: visible ? 1 : 0
                color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.55)
            }

            Item {
                visible: !root.workspaceMode
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.controlColumnWidth
                Layout.preferredHeight: visible ? studioActions.implicitHeight : 0

                ButtonGroup {
                    id: studioActions
                    anchors.fill: parent
                    spacing: 4
                    uniformCellSizes: true
                    DeckChip {
                        text: Translation.tr("Revert preview")
                        chipIcon: "undo"
                        enabled: root.dirty
                        onClicked: root.revertRequested()
                    }
                    DeckChip {
                        text: Translation.tr("Save current")
                        chipIcon: "save"
                        selected: root.dirty
                        enabled: root.dirty
                        onClicked: root.commitRequested()
                    }
                    DeckChip {
                        text: root.resetArmed ? Translation.tr("Confirm reset") : Translation.tr("Reset Orbit")
                        chipIcon: root.resetArmed ? "warning" : "restart_alt"
                        selected: root.resetArmed
                        onClicked: {
                            if (!root.resetArmed) {
                                root.resetArmed = true
                                resetArmTimer.restart()
                                return
                            }
                            resetArmTimer.stop()
                            root.resetArmed = false
                            root.resetDefaultsRequested()
                        }
                    }
                }
            }
        }
    }



    Component {
        id: sceneSection
        ColumnLayout {
            width: sectionLoader.width
            spacing: 12

            SectionIntro {
                titleText: Translation.tr("Scene composition")
                descriptionText: Translation.tr("Choose the spatial model and the amount of workspace context Orbit keeps visible.")
            }

            ChoiceControl {
                labelText: Translation.tr("Orbit profile")
                descriptionText: Translation.tr("Applies layout, material, motion and Shelf as one starting point")
                DeckChip { text: Translation.tr("Balanced"); onClicked: root.applyOrbitProfile("balanced") }
                DeckChip { text: Translation.tr("Classic"); onClicked: root.applyOrbitProfile("classic") }
                DeckChip { text: Translation.tr("Spatial"); onClicked: root.applyOrbitProfile("spatial") }
                DeckChip { text: Translation.tr("Minimal"); onClicked: root.applyOrbitProfile("minimal") }
                DeckChip { text: Translation.tr("Cinematic"); onClicked: root.applyOrbitProfile("cinematic") }
            }

            ControlRail {
                compact: false
                DeckChip {
                    text: Translation.tr("Apply saved preset")
                    chipIcon: "bookmark"
                    enabled: String(root.effectiveOptions?.userPresetJson ?? "").length > 0
                    onClicked: root.applyUserProfile()
                }
                DeckChip {
                    text: Translation.tr("Save as preset")
                    chipIcon: "bookmark_add"
                    onClicked: root.saveUserProfile()
                }
            }

            ChoiceControl {
                visible: !root.workspaceMode
                labelText: Translation.tr("View")
                DeckChip { text: Translation.tr("Stage"); chipIcon: "view_week"; selected: root.activeView === "stage"; onClicked: root.chooseView("stage") }
                DeckChip { text: Translation.tr("Orbit"); chipIcon: "orbit"; selected: root.activeView === "orbit"; onClicked: root.chooseView("orbit") }
                DeckChip { text: Translation.tr("Horizon"); chipIcon: "panorama_horizontal"; selected: root.activeView === "horizon"; onClicked: root.chooseView("horizon") }
                DeckChip { text: Translation.tr("Gallery"); chipIcon: "view_carousel"; selected: root.activeView === "gallery"; onClicked: root.chooseView("gallery") }
                DeckChip { text: Translation.tr("Deck"); chipIcon: "stacks"; selected: root.activeView === "deck"; onClicked: root.chooseView("deck") }
                DeckChip { text: Translation.tr("Atlas"); chipIcon: "grid_view"; selected: root.activeView === "atlas"; onClicked: root.chooseView("atlas") }
            }

            ChoiceControl {
                visible: root.activeView !== "stage"
                labelText: Translation.tr("Workspaces")
                descriptionText: Translation.tr("How much neighboring workspace context stays visible")
                Repeater {
                    model: [3, 5, 7]
                    delegate: DeckChip {
                        required property int modelData
                        text: String(modelData)
                        selected: (root.orbital.visibleWorkspaces ?? 5) === modelData
                        onClicked: root.previewRequested("orbital.visibleWorkspaces", modelData)
                    }
                }
            }

            MetricGrid {
                visible: root.activeView !== "stage"
                MetricControl {
                    from: 36; to: 62; stepSize: 1
                    value: root.orbital.coreSizePercent ?? 48
                    labelText: Translation.tr("Core size")
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("orbital.coreSizePercent", Math.round(value))
                }
                MetricControl {
                    from: 28; to: 60; stepSize: 1
                    value: root.orbital.satelliteSizePercent ?? 42
                    labelText: Translation.tr("Satellite size")
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("orbital.satelliteSizePercent", Math.round(value))
                }
            }

            ChoiceControl {
                visible: root.activeView !== "stage"
                labelText: Translation.tr("Workspace label")
                DeckChip { text: Translation.tr("Number"); selected: root.workspaceLabelMode === "index"; onClicked: root.previewRequested("orbital.workspaceLabelMode", "index") }
                DeckChip { text: Translation.tr("Name"); selected: root.workspaceLabelMode === "name"; onClicked: root.previewRequested("orbital.workspaceLabelMode", "name") }
                DeckChip { text: Translation.tr("Workspace"); selected: root.workspaceLabelMode === "workspace"; onClicked: root.previewRequested("orbital.workspaceLabelMode", "workspace") }
                DeckChip { text: Translation.tr("Off"); selected: root.workspaceLabelMode === "off"; onClicked: root.previewRequested("orbital.workspaceLabelMode", "off") }
            }
        }
    }

    Component {
        id: cameraSection
        ColumnLayout {
            width: sectionLoader.width
            spacing: 12

            SectionIntro {
                titleText: Translation.tr("Depth and previews")
                descriptionText: Translation.tr("Tune the static spatial composition without pointer-driven scene movement.")
            }

            ControlRail {
                visible: root.activeView !== "stage"
                compact: true
                DeckChip {
                    text: Translation.tr("Satellite previews")
                    chipIcon: "preview"
                    selected: root.orbital.satellitePreviews ?? true
                    onClicked: root.previewRequested("orbital.satellitePreviews", !selected)
                }
            }

            MetricGrid {
                visible: root.activeView !== "stage"
                MetricControl {
                    from: 0; to: 35; stepSize: 1
                    value: root.orbital.depthPercent ?? 18
                    labelText: Translation.tr("Scene depth")
                    descriptionText: Translation.tr("Static perspective separation between workspace planes")
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("orbital.depthPercent", Math.round(value))
                }
                MetricControl {
                    from: 58; to: 96; stepSize: 1
                    value: root.orbital.horizontalSpreadPercent ?? 82
                    labelText: Translation.tr("Horizontal field")
                    descriptionText: Translation.tr("Horizontal travel available to surrounding workspaces")
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("orbital.horizontalSpreadPercent", Math.round(value))
                }
                MetricControl {
                    from: 40; to: 82; stepSize: 1
                    value: root.orbital.verticalSpreadPercent ?? 58
                    labelText: Translation.tr("Vertical field")
                    descriptionText: Translation.tr("Vertical travel available to surrounding workspaces")
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("orbital.verticalSpreadPercent", Math.round(value))
                }
            }

            ChoiceControl {
                labelText: Translation.tr("Workspace surface")
                descriptionText: Translation.tr("Material and frame treatment shared by workspace cards")
                DeckChip {
                    text: Translation.tr("Current")
                    selected: (root.workspaceSurface.style ?? "current") === "current"
                    onClicked: root.previewRequested("orbital.surface.style", "current")
                }
                DeckChip {
                    text: Translation.tr("Ricelin")
                    selected: root.workspaceSurface.style === "ricelin"
                    onClicked: root.previewRequested("orbital.surface.style", "ricelin")
                }
                DeckChip {
                    text: Translation.tr("Outline")
                    selected: root.workspaceSurface.outline ?? true
                    onClicked: root.previewRequested("orbital.surface.outline", !selected)
                }
            }

            MetricGrid {
                MetricControl {
                    labelText: Translation.tr("Rounding")
                    from: 55; to: 160; stepSize: 5
                    value: root.workspaceSurface.radiusPercent ?? 100
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("orbital.surface.radiusPercent", Math.round(value))
                }
                MetricControl {
                    controlEnabled: root.workspaceSurface.outline ?? true
                    labelText: Translation.tr("Border width")
                    from: 0; to: 4; stepSize: 1
                    value: root.workspaceSurface.outlineWidth ?? 1
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.previewRequested("orbital.surface.outlineWidth", Math.round(value))
                }
                MetricControl {
                    controlEnabled: root.workspaceSurface.outline ?? true
                    labelText: Translation.tr("Border intensity")
                    from: 0; to: 100; stepSize: 4
                    value: root.workspaceSurface.outlineOpacityPercent ?? 72
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("orbital.surface.outlineOpacityPercent", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Frame inset")
                    descriptionText: Translation.tr("Visible material frame around wallpaper and previews")
                    from: 0; to: 18; stepSize: 1
                    value: root.workspaceSurface.frameInset ?? 5
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.previewRequested("orbital.surface.frameInset", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Card elevation")
                    descriptionText: Translation.tr("Base material layer. Focus depth is animated separately so cards never jump between layers.")
                    from: 0; to: 4; stepSize: 1
                    value: root.workspaceSurface.satelliteElevation ?? 1
                    valueText: String(Math.round(value))
                    onMoved: value => {
                        const elevation = Math.round(value)
                        root.previewRequested("orbital.surface.coreElevation", elevation)
                        root.previewRequested("orbital.surface.satelliteElevation", elevation)
                    }
                }
            }

            ChoiceControl {
                labelText: Translation.tr("Workspace shadow")
                descriptionText: Translation.tr("Choose which workspace cards receive elevation shadow")
                DeckChip { text: Translation.tr("Off"); selected: (root.workspaceSurface.shadowMode ?? "core") === "off"; onClicked: root.previewRequested("orbital.surface.shadowMode", "off") }
                DeckChip { text: Translation.tr("Core"); selected: (root.workspaceSurface.shadowMode ?? "core") === "core"; onClicked: root.previewRequested("orbital.surface.shadowMode", "core") }
                DeckChip { text: Translation.tr("All"); selected: root.workspaceSurface.shadowMode === "all"; onClicked: root.previewRequested("orbital.surface.shadowMode", "all") }
            }

            MetricGrid {
                visible: (root.workspaceSurface.shadowMode ?? "core") !== "off"
                MetricControl {
                    labelText: Translation.tr("Shadow intensity")
                    from: 0; to: 100; stepSize: 4
                    value: root.workspaceSurface.shadowOpacityPercent ?? 72
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("orbital.surface.shadowOpacityPercent", Math.round(value))
                }
            }

            ChoiceControl {
                visible: root.activeView !== "stage"
                labelText: Translation.tr("Satellite click")
                descriptionText: Translation.tr("Select Core keeps editing context; Enter jumps to the workspace")
                DeckChip {
                    text: Translation.tr("Select core")
                    selected: (root.orbital.satelliteClickAction ?? "select") === "select"
                    onClicked: root.previewRequested("orbital.satelliteClickAction", "select")
                }
                DeckChip {
                    text: Translation.tr("Enter directly")
                    selected: root.orbital.satelliteClickAction === "enter"
                    onClicked: root.previewRequested("orbital.satelliteClickAction", "enter")
                }
            }

        }
    }

    Component {
        id: atmosphereSection
        ColumnLayout {
            width: sectionLoader.width
            spacing: 12

            SectionIntro {
                titleText: Translation.tr("Atmosphere")
                descriptionText: Translation.tr("Shape the material behind Orbit. These controls affect the live iNiR glass, scrim and workspace wallpaper only.")
            }

            ChoiceControl {
                labelText: Translation.tr("Backdrop blur")
                DeckChip {
                    text: Translation.tr("Off")
                    chipIcon: "blur_off"
                    selected: {
                        const mode = String(root.effectiveOptions?.backdropBlurMode ?? "")
                        return mode.length > 0 ? mode === "off"
                            : !(root.effectiveOptions?.backdropBlurEnable ?? true)
                    }
                    onClicked: root.previewRequested("backdropBlurMode", "off")
                }
                DeckChip {
                    text: Translation.tr("iNiR glass")
                    chipIcon: "blur_on"
                    selected: {
                        const mode = String(root.effectiveOptions?.backdropBlurMode ?? "")
                        return mode.length > 0 ? mode !== "off"
                            : (root.effectiveOptions?.backdropBlurEnable ?? true)
                    }
                    onClicked: root.previewRequested("backdropBlurMode", "shell")
                }
            }

            MetricGrid {
                MetricControl {
                    controlEnabled: String(root.effectiveOptions?.backdropBlurMode ?? "") !== "off"
                    labelText: Translation.tr("Blur")
                    from: 0; to: 100; stepSize: 2
                    value: root.effectiveOptions?.backdropBlurStrength ?? 72
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("backdropBlurStrength", Math.round(value))
                }
                MetricControl {
                    controlEnabled: String(root.effectiveOptions?.backdropBlurMode ?? "") !== "off"
                    labelText: Translation.tr("Saturation")
                    from: 0; to: 100; stepSize: 2
                    value: root.effectiveOptions?.backdropBlurSaturation ?? 18
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("backdropBlurSaturation", Math.round(value))
                }
                MetricControl {
                    controlEnabled: String(root.effectiveOptions?.backdropBlurMode ?? "") !== "off"
                    labelText: Translation.tr("Tint")
                    from: 0; to: 80; stepSize: 2
                    value: root.effectiveOptions?.backdropBlurTint ?? 28
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("backdropBlurTint", Math.round(value))
                }
            }

            ControlRail {
                compact: true
                DeckChip {
                    text: Translation.tr("Workspace wallpaper")
                    chipIcon: "image"
                    selected: root.orbital.showWorkspaceWallpaper ?? true
                    onClicked: root.previewRequested("orbital.showWorkspaceWallpaper", !selected)
                }
            }

            MetricGrid {
                MetricControl {
                    from: 0; to: 80; stepSize: 1
                    value: root.effectiveOptions?.scrimDim ?? 35
                    labelText: Translation.tr("Dim")
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("scrimDim", Math.round(value))
                }
                MetricControl {
                    controlEnabled: root.orbital.showWorkspaceWallpaper ?? true
                    from: 20; to: 100; stepSize: 1
                    value: root.orbital.workspaceWallpaperOpacity ?? 70
                    labelText: Translation.tr("Workspace wallpaper")
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("orbital.workspaceWallpaperOpacity", Math.round(value))
                }
            }

        }
    }

    Component {
        id: motionSection
        ColumnLayout {
            width: sectionLoader.width
            spacing: 12

            SectionIntro {
                titleText: Translation.tr("Motion")
                descriptionText: Translation.tr("Pick the feel. Orbit tunes timing for the current layout automatically; detailed controls live in Advanced.")
            }

            ChoiceControl {
                labelText: Translation.tr("Workspace navigation")
                descriptionText: Translation.tr("How quickly the focused workspace follows your scroll or keys")
                DeckChip { text: Translation.tr("Fast"); selected: (root.navigationMotion.preset ?? "fluid") === "snappy"; onClicked: root.chooseNavigationPreset("snappy") }
                DeckChip { text: Translation.tr("Balanced"); selected: (root.navigationMotion.preset ?? "fluid") === "fluid"; onClicked: root.chooseNavigationPreset("fluid") }
                DeckChip { text: Translation.tr("Soft"); selected: root.navigationMotion.preset === "cinematic"; onClicked: root.chooseNavigationPreset("cinematic") }
                DeckChip { text: Translation.tr("Off"); selected: root.navigationMotion.preset === "instant"; onClicked: root.chooseNavigationPreset("instant") }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: (root.studioOptions.showDescriptions ?? true)
                    && (root.navigationMotion.preset ?? "fluid") !== "instant"
                text: Translation.tr("%1 · %2 ms · tuned for %3")
                    .arg((root.navigationMotion.preset ?? "fluid") === "snappy"
                        ? Translation.tr("Fast")
                        : root.navigationMotion.preset === "cinematic"
                            ? Translation.tr("Soft") : Translation.tr("Balanced"))
                    .arg(root.effectiveNavigationDuration)
                    .arg(root.activeView === "stage" ? Translation.tr("Stage") : root.activeView)
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            ChoiceControl {
                labelText: Translation.tr("Open / close")
                descriptionText: Translation.tr("How Orbit enters the screen; this does not change workspace navigation")
                DeckChip { text: Translation.tr("Adaptive"); selected: root.presentation.preset === "adaptive"; onClicked: root.choosePresentationPreset("adaptive") }
                DeckChip { text: Translation.tr("Subtle"); selected: root.presentation.preset === "soft"; onClicked: root.choosePresentationPreset("soft") }
                DeckChip { text: Translation.tr("Float"); selected: root.presentation.preset === "float"; onClicked: root.choosePresentationPreset("float") }
                DeckChip { text: Translation.tr("Sweep"); selected: root.presentation.preset === "sweep"; onClicked: root.choosePresentationPreset("sweep") }
                DeckChip { text: Translation.tr("Off"); selected: root.presentation.preset === "instant"; onClicked: root.choosePresentationPreset("instant") }
            }
        }
    }

    Component {
        id: shelfSection
        ColumnLayout {
            width: sectionLoader.width
            spacing: 12

            SectionIntro {
                titleText: Translation.tr("Shelf composition")
                descriptionText: Translation.tr("Keep the live Shelf compact here. Pinning actions and deeper module behavior stay in Settings.")
            }
            ControlRail {
                compact: true
                DeckChip {
                    text: Translation.tr("Shelf")
                    chipIcon: "dock_to_bottom"
                    selected: root.shelf.enable ?? true
                    onClicked: root.previewRequested("shelf.enable", !selected)
                }
            }

            ChoiceControl {
                labelText: Translation.tr("Layout")
                DeckChip { text: Translation.tr("Islands"); selected: (root.shelf.layout ?? "islands") === "islands"; onClicked: root.previewRequested("shelf.layout", "islands") }
                DeckChip { text: Translation.tr("Bar"); selected: root.shelf.layout === "bar"; onClicked: root.previewRequested("shelf.layout", "bar") }
                DeckChip { text: Translation.tr("Minimal"); selected: root.shelf.layout === "minimal"; onClicked: root.previewRequested("shelf.layout", "minimal") }
            }

            ChoiceControl {
                labelText: Translation.tr("Shelf surface")
                descriptionText: Translation.tr("Material skin used by Bar, Islands and Minimal")
                DeckChip {
                    text: Translation.tr("Current")
                    selected: (root.shelf.islandStyle ?? "material") === "material"
                    onClicked: root.previewRequested("shelf.islandStyle", "material")
                }
                DeckChip {
                    text: Translation.tr("Ricelin")
                    selected: root.shelf.islandStyle === "ricelin"
                    onClicked: root.previewRequested("shelf.islandStyle", "ricelin")
                }
            }

            ChoiceControl {
                labelText: Translation.tr("Density")
                columnCountOverride: 2
                DeckChip { text: Translation.tr("Comfortable"); selected: (root.shelf.density ?? "comfortable") === "comfortable"; onClicked: root.previewRequested("shelf.density", "comfortable") }
                DeckChip { text: Translation.tr("Compact"); selected: root.shelf.density === "compact"; onClicked: root.previewRequested("shelf.density", "compact") }
                DeckChip {
                    Layout.columnSpan: 2
                    text: Translation.tr("HUGE AS YOUR MOM")
                    selected: root.shelf.density === "huge"
                    onClicked: root.previewRequested("shelf.density", "huge")
                }
            }

            ChoiceControl {
                labelText: Translation.tr("Labels")
                DeckChip { text: Translation.tr("Auto"); selected: (root.shelf.labels ?? "auto") === "auto"; onClicked: root.previewRequested("shelf.labels", "auto") }
                DeckChip { text: Translation.tr("Always"); selected: root.shelf.labels === "always"; onClicked: root.previewRequested("shelf.labels", "always") }
                DeckChip { text: Translation.tr("Icons"); selected: root.shelf.labels === "icons"; onClicked: root.previewRequested("shelf.labels", "icons") }
            }

        }
    }

    Component {
        id: advancedSection
        ColumnLayout {
            width: sectionLoader.width
            spacing: 14

            SectionIntro {
                titleText: Translation.tr("Advanced Orbit tuning")
                descriptionText: Translation.tr("Fine geometry and interaction values. Presets stay intact until one of these controls is moved.")
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Studio")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            ChoiceControl {
                labelText: Translation.tr("Studio surface")
                DeckChip {
                    text: Translation.tr("Current")
                    selected: (root.studioOptions.surfaceStyle ?? "ricelin") === "current"
                    onClicked: root.previewRequested("studio.surfaceStyle", "current")
                }
                DeckChip {
                    text: Translation.tr("Ricelin")
                    selected: (root.studioOptions.surfaceStyle ?? "ricelin") === "ricelin"
                    onClicked: root.previewRequested("studio.surfaceStyle", "ricelin")
                }
            }

            ChoiceControl {
                labelText: Translation.tr("Studio density")
                DeckChip {
                    text: Translation.tr("Compact")
                    selected: (root.studioOptions.density ?? "compact") === "compact"
                    onClicked: root.previewRequested("studio.density", "compact")
                }
                DeckChip {
                    text: Translation.tr("Comfortable")
                    selected: root.studioOptions.density === "comfortable"
                    onClicked: root.previewRequested("studio.density", "comfortable")
                }
                DeckChip {
                    text: Translation.tr("Descriptions")
                    selected: root.studioOptions.showDescriptions ?? true
                    onClicked: root.previewRequested("studio.showDescriptions", !selected)
                }
            }

            MetricGrid {
                MetricControl {
                    labelText: Translation.tr("Dock width")
                    from: 20; to: 34; stepSize: 1
                    value: root.studioOptions.widthPercent ?? 26
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("studio.widthPercent", Math.round(value))
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Workspace navigation")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            NavigationFineControls {}

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Orbit presentation")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            PresentationFineControls {}

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Viewport")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            MetricGrid {
                MetricControl {
                    labelText: Translation.tr("Panel width")
                    from: 60; to: 100; stepSize: 1
                    value: root.effectiveOptions?.maxPanelWidthPercent ?? 92
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.previewRequested("maxPanelWidthPercent", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Window gap")
                    from: 0; to: 18; stepSize: 1
                    value: root.effectiveOptions?.windowGap ?? 4
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.previewRequested("windowGap", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Edge padding")
                    from: 0; to: 48; stepSize: 2
                    value: root.geometry.edgePadding ?? 10
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("edgePadding", Math.round(value))
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Card interior")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            MetricGrid {
                MetricControl {
                    labelText: Translation.tr("Core inset")
                    from: 0; to: 28; stepSize: 1
                    value: root.geometry.coreContentMargin ?? 9
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("coreContentMargin", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Satellite inset")
                    from: 0; to: 24; stepSize: 1
                    value: root.geometry.satelliteContentMargin ?? 6
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("satelliteContentMargin", Math.round(value))
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Horizon geometry")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            MetricGrid {
                MetricControl {
                    labelText: Translation.tr("Card gap")
                    from: 0; to: 48; stepSize: 2
                    value: root.geometry.horizonGap ?? 12
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("horizonGap", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Rail inset")
                    from: 0; to: 96; stepSize: 4
                    value: root.geometry.horizonInset ?? 24
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("horizonInset", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Base separation")
                    from: 0; to: 80; stepSize: 2
                    value: root.geometry.horizonVerticalBase ?? 8
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("horizonVerticalBase", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Spread range")
                    from: 0; to: 96; stepSize: 2
                    value: root.geometry.horizonVerticalRange ?? 26
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("horizonVerticalRange", Math.round(value))
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Gallery geometry")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            MetricGrid {
                MetricControl {
                    labelText: Translation.tr("Side gap")
                    from: 0; to: 120; stepSize: 4
                    value: root.geometry.galleryBaseGap ?? 34
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("galleryBaseGap", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Row gap")
                    descriptionText: Translation.tr("Vertical spacing between workspaces in each comparison column")
                    from: 0; to: 48; stepSize: 2
                    value: root.geometry.galleryRowGap ?? 14
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("galleryRowGap", Math.round(value))
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Deck geometry")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            MetricGrid {
                MetricControl {
                    labelText: Translation.tr("Base gap")
                    descriptionText: Translation.tr("Distance between the Core and the first cards in each stack")
                    from: 0; to: 120; stepSize: 2
                    value: root.geometry.deckBaseGap ?? 26
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("deckBaseGap", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Stack step")
                    descriptionText: Translation.tr("Horizontal separation added for each deeper workspace")
                    from: 12; to: 120; stepSize: 2
                    value: root.geometry.deckStep ?? 44
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("deckStep", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Fan step")
                    descriptionText: Translation.tr("Vertical fan applied to deeper cards on each side")
                    from: 0; to: 80; stepSize: 2
                    value: root.geometry.deckLiftStep ?? 24
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("deckLiftStep", Math.round(value))
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Atlas geometry")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            MetricGrid {
                MetricControl {
                    labelText: Translation.tr("Card gap")
                    descriptionText: Translation.tr("Spacing between workspace cells in the session map")
                    from: 0; to: 48; stepSize: 2
                    value: root.geometry.atlasGap ?? 14
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.setGeometryValue("atlasGap", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Columns")
                    descriptionText: Translation.tr("Grid width used by Atlas")
                    from: 2; to: 3; stepSize: 1
                    value: root.geometry.atlasColumns ?? 3
                    valueText: String(Math.round(value))
                    onMoved: value => root.setGeometryValue("atlasColumns", Math.round(value))
                }
                MetricControl {
                    labelText: Translation.tr("Core emphasis")
                    descriptionText: Translation.tr("Extra size reserved for the selected workspace")
                    from: 0; to: 20; stepSize: 1
                    value: root.geometry.atlasCoreBoostPercent ?? 10
                    valueText: `${Math.round(value)}%`
                    onMoved: value => root.setGeometryValue("atlasCoreBoostPercent", Math.round(value))
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Shelf fine tuning")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            MetricGrid {
                MetricControl {
                    labelText: Translation.tr("Module gap")
                    from: 0; to: 16; stepSize: 1
                    value: root.shelf.moduleSpacing ?? 7
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.previewRequested("shelf.moduleSpacing", Math.round(value))
                }
                MetricControl {
                    controlEnabled: (root.shelf.layout ?? "islands") === "islands"
                    labelText: Translation.tr("Island padding")
                    from: 6; to: 16; stepSize: 1
                    value: root.shelf.islandPadding ?? 8
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.previewRequested("shelf.islandPadding", Math.round(value))
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Interaction")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }

            ControlRail {
                DeckChip {
                    text: Translation.tr("Keyboard nav")
                    chipIcon: "keyboard"
                    selected: root.effectiveOptions?.keyboardNavigation ?? true
                    onClicked: root.previewRequested("keyboardNavigation", !selected)
                }
                DeckChip {
                    text: Translation.tr("Scroll nav")
                    chipIcon: "mouse"
                    selected: root.effectiveOptions?.scrollNavigation ?? true
                    onClicked: root.previewRequested("scrollNavigation", !selected)
                }
                DeckChip {
                    text: Translation.tr("Close on select")
                    chipIcon: "close_fullscreen"
                    selected: root.effectiveOptions?.closeOnSelect ?? true
                    onClicked: root.previewRequested("closeOnSelect", !selected)
                }
            }

            ChoiceControl {
                visible: root.activeView !== "stage"
                labelText: Translation.tr("Wheel action")
                DeckChip {
                    text: Translation.tr("Switch Niri")
                    chipIcon: "swap_vert"
                    selected: root.effectiveOptions?.scrollSwitchWorkspace ?? true
                    onClicked: root.previewRequested("scrollSwitchWorkspace", true)
                }
                DeckChip {
                    text: Translation.tr("Preview Core")
                    chipIcon: "visibility"
                    selected: !(root.effectiveOptions?.scrollSwitchWorkspace ?? true)
                    onClicked: root.previewRequested("scrollSwitchWorkspace", false)
                }
            }

            MetricGrid {
                MetricControl {
                    controlEnabled: root.effectiveOptions?.scrollNavigation ?? true
                    labelText: Translation.tr("Wheel ticks")
                    descriptionText: Translation.tr("Wheel notches required to step one workspace")
                    from: 1; to: 4; stepSize: 1
                    value: root.effectiveOptions?.scrollSteps ?? 1
                    valueText: String(Math.round(value))
                    onMoved: value => root.previewRequested("scrollSteps", Math.round(value))
                }
            }

            ControlRail {
                DeckChip {
                    text: Translation.tr("Wrap around")
                    chipIcon: "repeat"
                    selected: root.effectiveOptions?.scrollWrapAround ?? false
                    onClicked: root.previewRequested("scrollWrapAround", !selected)
                }
                DeckChip {
                    text: Translation.tr("Canvas scrub")
                    chipIcon: "swipe"
                    selected: root.effectiveOptions?.canvasScrubNavigation ?? true
                    onClicked: root.previewRequested("canvasScrubNavigation", !selected)
                }
            }

            MetricGrid {
                MetricControl {
                    controlEnabled: root.effectiveOptions?.canvasScrubNavigation ?? true
                    labelText: Translation.tr("Scrub step")
                    descriptionText: Translation.tr("Horizontal drag distance required to step one workspace")
                    from: 48; to: 180; stepSize: 4
                    value: root.effectiveOptions?.canvasScrubThreshold ?? 96
                    valueText: `${Math.round(value)} px`
                    onMoved: value => root.previewRequested("canvasScrubThreshold", Math.round(value))
                }
            }
        }
    }

    Item {
        id: resizeGrip
        z: 20
        visible: !root.docked && !root.workspaceMode
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        width: 24
        height: 24

        MaterialSymbol {
            anchors.centerIn: parent
            text: "drag_handle"
            rotation: -45
            iconSize: 18
            textRenderType: Text.QtRendering
            color: resizeHover.hovered || resizeDrag.active
                ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
        }
        HoverHandler { id: resizeHover; cursorShape: Qt.SizeFDiagCursor }
        DragHandler {
            id: resizeDrag
            target: null
            acceptedButtons: Qt.LeftButton
            onActiveChanged: if (active) root.resizeStarted()
            onTranslationChanged: if (active) root.resizeRequested(translation.x, translation.y)
        }
    }

    PanelSurface {
        z: 19
        visible: !root.docked && !root.workspaceMode && resizeDrag.active
        anchors.right: parent.right
        anchors.bottom: resizeGrip.top
        anchors.rightMargin: 8
        anchors.bottomMargin: 4
        width: sizeLabel.implicitWidth + 16
        height: 24
        elevation: 3
        island: true
        outlined: false
        surfaceDialect: Appearance.surfaceDialectFor("")

        StyledText {
            id: sizeLabel
            anchors.centerIn: parent
            text: `${Math.round(root.width)} × ${Math.round(root.height)}`
            renderType: Text.QtRendering
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.family: Appearance.font.family.monospace
            color: Appearance.colors.colOnLayer2
        }
    }
}
