//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property int currentStep: 0
    readonly property int totalSteps: 5
    property bool wizardVisible: true
    property var focusedScreen: Quickshell.screens[0]

    readonly property var steps: [
        { icon: "waving_hand", title: Translation.tr("Welcome") },
        { icon: "palette", title: Translation.tr("Appearance") },
        { icon: "dashboard", title: Translation.tr("Layout") },
        { icon: "tune", title: Translation.tr("Features") },
        { icon: "rocket_launch", title: Translation.tr("Ready") }
    ]

    function finish() {
        ShellExec.writeFileViaShell(root.firstRunFilePath, root.firstRunFileContent)
        Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Welcome to inir"), Translation.tr("Press Super+/ for all keyboard shortcuts."), "-a", "Shell"])
        Qt.quit()
    }

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Config.readWriteDelay = 0
    }

    PanelWindow {
        id: wizardPanel
        visible: root.wizardVisible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:welcome"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }
        implicitWidth: root.focusedScreen?.width ?? 1920
        implicitHeight: root.focusedScreen?.height ?? 1080

        // Blurred wallpaper background
        Image {
            id: bgWallpaper
            anchors.fill: parent
            source: Config.options?.background?.wallpaperPath ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            layer.enabled: Appearance.effectsEnabled
            layer.effect: FastBlur { radius: 64 }
            transform: Scale {
                origin.x: bgWallpaper.width / 2
                origin.y: bgWallpaper.height / 2
                xScale: 1.1; yScale: 1.1
            }
        }

        // Dim overlay
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        // Click outside to skip
        MouseArea {
            anchors.fill: parent
            onClicked: root.finish()
        }

        // Main wizard card
        Item {
            id: wizardCard
            anchors.centerIn: parent
            width: Math.min(960, parent.width * 0.75)
            height: Math.min(parent.height * 0.85, parent.height - 60)
            focus: true

            // Entrance animation - using project animation system
            scale: root.wizardVisible ? 1 : 0.95
            opacity: root.wizardVisible ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }

            // Keyboard navigation
            Keys.onEscapePressed: root.finish()
            Keys.onLeftPressed: if (root.currentStep > 0) root.currentStep--
            Keys.onRightPressed: if (root.currentStep < root.totalSteps - 1) root.currentStep++
            Keys.onReturnPressed: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish()
            Keys.onEnterPressed: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish()

            // Shadow (hide in aurora)
            StyledRectangularShadow {
                target: cardBg
                visible: Appearance.angelEverywhere || !Appearance.auroraEverywhere
            }

            // Card background - style-aware
            Rectangle {
                id: cardBg
                anchors.fill: parent

                radius: Appearance.inirEverywhere ? Appearance.inir.roundingLarge
                      : Appearance.rounding.large

                // Base color
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? "transparent"
                     : Appearance.colors.colLayer1

                border.width: Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
                border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.colors.colLayer0Border

                Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                Behavior on border.color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                // Aurora: Wallpaper blur inside card
                Image {
                    visible: Appearance.auroraEverywhere
                    anchors.fill: parent
                    source: Config.options?.background?.wallpaperPath ?? ""
                    fillMode: Image.PreserveAspectCrop

                    // Position to align with background wallpaper
                    x: -wizardCard.x
                    y: -wizardCard.y
                    width: wizardPanel.width
                    height: wizardPanel.height

                    layer.enabled: Appearance.effectsEnabled
                    layer.effect: FastBlur { radius: 40 }
                }

                // Aurora: Tinted overlay
                Rectangle {
                    anchors.fill: parent
                    visible: Appearance.auroraEverywhere
                    radius: parent.radius
                    color: ColorUtils.transparentize(Appearance.colors.colLayer1Base, 0.25)
                }

                // Block clicks from propagating to background MouseArea
                MouseArea {
                    anchors.fill: parent
                    onClicked: (event) => event.accepted = true
                }

                // Clip content to rounded corners
                layer.enabled: Appearance.effectsEnabled
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: cardBg.width
                        height: cardBg.height
                        radius: cardBg.radius
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 36
                spacing: 24

                // Header with step indicator
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Step circles
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 0

                        Repeater {
                            model: root.steps
                            Row {
                                required property int index
                                required property var modelData

                                Rectangle {
                                    id: stepCircle
                                    width: 38; height: 38; radius: 19

                                    color: index < root.currentStep ? Appearance.colors.colPrimary
                                         : index === root.currentStep ? Appearance.colors.colPrimaryContainer
                                         : Appearance.colors.colLayer2

                                    border.width: index === root.currentStep ? 2 : 0
                                    border.color: Appearance.colors.colPrimary

                                    Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Appearance.animation.elementMove.duration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                    Behavior on border.width { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                                    scale: index === root.currentStep ? 1.12 : 1.0

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: index < root.currentStep ? "check" : modelData.icon
                                        iconSize: index === root.currentStep ? 20 : 18
                                        color: index < root.currentStep ? Appearance.colors.colOnPrimary
                                             : index === root.currentStep ? Appearance.colors.colOnPrimaryContainer
                                             : Appearance.colors.colOnLayer2

                                        Behavior on iconSize { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                                    }
                                }

                                // Connector line with progress
                                Item {
                                    visible: index < root.steps.length - 1
                                    width: 36; height: 4
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 2
                                        color: Appearance.colors.colLayer2
                                    }

                                    Rectangle {
                                        height: parent.height
                                        radius: 2
                                        color: Appearance.colors.colPrimary
                                        width: index < root.currentStep ? parent.width : 0
                                        Behavior on width {
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMove.duration
                                                easing.type: Appearance.animation.elementMove.type
                                                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Step title
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.steps[root.currentStep].title
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.hugeass
                        color: Appearance.colors.colOnLayer1
                    }
                }

                // Separator
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    height: 1
                    color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                         : Appearance.colors.colOutlineVariant
                }

                // Content area with transitions
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    StackLayout {
                        id: stepStack
                        anchors.fill: parent
                        anchors.topMargin: 8
                        currentIndex: root.currentStep

                        // Step transition - improved with scale and better easing
                        property int prevStep: 0
                        onCurrentIndexChanged: {
                            stepAnim.direction = currentIndex > prevStep ? 1 : -1
                            stepAnim.restart()
                            prevStep = currentIndex
                        }

                        opacity: 1
                        scale: 1
                        transform: Translate { id: stepTranslate; x: 0 }

                        ParallelAnimation {
                            id: stepAnim
                            property int direction: 1
                            property int moveDuration: Appearance.animation.elementMove.duration

                            // Fade + scale out, then fade + scale in
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { 
                                        target: stepStack; property: "opacity"; to: 0
                                        duration: stepAnim.moveDuration * 0.35
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation { 
                                        target: stepStack; property: "scale"; to: 0.96
                                        duration: stepAnim.moveDuration * 0.35
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                ParallelAnimation {
                                    NumberAnimation { 
                                        target: stepStack; property: "opacity"; to: 1
                                        duration: stepAnim.moveDuration * 0.65
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation { 
                                        target: stepStack; property: "scale"; to: 1
                                        duration: stepAnim.moveDuration * 0.65
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.2
                                    }
                                }
                            }

                            // Slide animation with improved easing
                            SequentialAnimation {
                                NumberAnimation { 
                                    target: stepTranslate; property: "x"
                                    to: stepAnim.direction * -30
                                    duration: stepAnim.moveDuration * 0.35
                                    easing.type: Easing.OutCubic
                                }
                                PropertyAction { 
                                    target: stepTranslate; property: "x"
                                    value: stepAnim.direction * 30
                                }
                                NumberAnimation { 
                                    target: stepTranslate; property: "x"; to: 0
                                    duration: stepAnim.moveDuration * 0.65
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Item {
                            WelcomeContent {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                            }
                        }
                        Item {
                            ThemeContent {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                            }
                        }
                        Item {
                            LayoutContent {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                            }
                        }
                        Item {
                            FeaturesContent {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                            }
                        }
                        Item {
                            ReadyContent {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                            }
                        }
                    }
                }

                // Navigation buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    DialogButton {
                        visible: root.currentStep > 0
                        buttonText: Translation.tr("Back")
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: root.currentStep--
                    }

                    Item { Layout.fillWidth: true }

                    // Keyboard hint
                    RowLayout {
                        spacing: 6
                        opacity: 0.6

                        Row {
                            spacing: 2
                            KeyboardKey { key: "←" }
                            KeyboardKey { key: "→" }
                        }
                        StyledText {
                            text: Translation.tr("navigate")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                    }

                    Item { Layout.fillWidth: true }

                    DialogButton {
                        buttonText: Translation.tr("Skip")
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: root.finish()
                    }

                    DialogButton {
                        buttonText: root.currentStep === root.totalSteps - 1 ? Translation.tr("Get Started") : Translation.tr("Continue")
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colText: Appearance.colors.colOnPrimary
                        onClicked: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish()
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP CONTENT COMPONENTS
    // ═══════════════════════════════════════════════════════════════════════

    component WelcomeContent: ColumnLayout {
        width: 600
        spacing: 24

        Item { Layout.fillHeight: true }

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "waving_hand"
            iconSize: 56
            padding: 18
            shape: MaterialShape.Shape.Cookie4Sided
            color: Appearance.colors.colPrimaryContainer
            colSymbol: Appearance.colors.colOnPrimaryContainer
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Welcome to inir")
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.hugeass + 6
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("A modern, customizable shell for Niri compositor")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.normal
        }

        // Keyboard shortcuts
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            implicitWidth: shortcutsGrid.implicitWidth + 40
            implicitHeight: shortcutsGrid.implicitHeight + 28
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                 : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                 : Appearance.colors.colLayer2
            border.width: Appearance.inirEverywhere ? 1 : 0
            border.color: Appearance.inir.colBorderSubtle

            GridLayout {
                id: shortcutsGrid
                anchors.centerIn: parent
                columns: 2
                columnSpacing: 40
                rowSpacing: 8

                Repeater {
                    model: [
                        { keys: "Super+Space", desc: Translation.tr("App launcher") },
                        { keys: "Super+/", desc: Translation.tr("All shortcuts") },
                        { keys: "Super+Q", desc: Translation.tr("Close window") },
                        { keys: "Super+,", desc: Translation.tr("Settings") }
                    ]
                    RowLayout {
                        required property var modelData
                        spacing: 10
                        Row {
                            spacing: 3
                            Repeater {
                                model: modelData.keys.split("+")
                                KeyboardKey {
                                    required property string modelData
                                    key: modelData
                                }
                            }
                        }
                        StyledText {
                            text: modelData.desc
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    component ThemeContent: Flickable {
        id: themeFlickable
        width: 600
        contentHeight: themeColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        
        ColumnLayout {
            id: themeColumn
            width: parent.width
            spacing: 16

        // Light/Dark toggle
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            LightDarkPreferenceButton { dark: false }
            LightDarkPreferenceButton { dark: true }
        }

        // Global style selector
        SettingsGroup {
            Layout.fillWidth: true
            Layout.maximumWidth: 560
            Layout.alignment: Qt.AlignHCenter

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    MaterialSymbol { text: "style"; iconSize: 20; color: Appearance.colors.colPrimary }
                    StyledText { text: Translation.tr("Visual Style"); font.pixelSize: Appearance.font.pixelSize.normal }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: {
                            const style = Config.options?.appearance?.globalStyle ?? "material"
                            return style === "material" ? "Clean & Solid"
                                 : style === "cards" ? "Rounded Cards"
                                 : style === "aurora" ? "Glass & Blur"
                                 : style === "angel" ? "Neo-Brutalism Glass"
                                 : "Terminal Style"
                        }
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options?.appearance?.globalStyle ?? "material"
                    onSelected: newValue => {
                        Config.setNestedValue("appearance.globalStyle", newValue)
                        Config.setNestedValue("appearance.transparency.enable", newValue === "aurora" || newValue === "angel")
                    }
                    options: [
                        { displayName: "Material", icon: "dashboard", value: "material" },
                        { displayName: "Cards", icon: "crop_square", value: "cards" },
                        { displayName: "Aurora", icon: "blur_on", value: "aurora" },
                        { displayName: "Angel", icon: "auto_awesome", value: "angel" },
                        { displayName: "Inir", icon: "terminal", value: "inir" }
                    ]
                }
            }
        }

        // Wallpaper - Inline picker (like QuickWallpaper widget)
        SettingsGroup {
            id: wallpaperGroup
            Layout.fillWidth: true
            Layout.maximumWidth: 560
            Layout.alignment: Qt.AlignHCenter

            property var wallpapersList: []
            readonly property string wallpapersPath: `${FileUtils.trimFileProtocol(Directories.pictures)}/Wallpapers`
            readonly property real itemWidth: 130
            readonly property real itemHeight: 78

            Component.onCompleted: wallpaperScanProc.running = true

            Process {
                id: wallpaperScanProc
                command: ["/usr/bin/fish", "-c", `find '${wallpaperGroup.wallpapersPath}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' \\) -printf '%C@\\t%p\\n'`]
                stdout: SplitParser {
                    splitMarker: ""
                    onRead: data => {
                        const lines = data.trim().split("\n").filter(l => l.length > 0)
                        lines.sort((a, b) => parseFloat(b.split("\t")[0]) - parseFloat(a.split("\t")[0]))
                        wallpaperGroup.wallpapersList = lines.map(l => l.split("\t")[1]).filter(p => p && p.length > 0)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    MaterialSymbol { text: "wallpaper"; iconSize: 20; color: Appearance.colors.colPrimary }
                    StyledText { text: Translation.tr("Wallpaper & Colors"); font.pixelSize: Appearance.font.pixelSize.normal }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: Translation.tr("Colors auto-generated")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                }

                // Carousel like QuickWallpaper widget
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: wallpaperGroup.itemHeight + 16
                    visible: wallpaperGroup.wallpapersList.length > 0

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colLayer2
                    }

                    ListView {
                        id: wallpaperCarousel
                        anchors.fill: parent
                        anchors.margins: 8
                        orientation: ListView.Horizontal
                        spacing: 8
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: wallpaperGroup.wallpapersList

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                                wallpaperCarousel.contentX = Math.max(0, Math.min(
                                    wallpaperCarousel.contentWidth - wallpaperCarousel.width,
                                    wallpaperCarousel.contentX - delta
                                ))
                            }
                        }

                        delegate: Item {
                            id: wpDelegate
                            required property int index
                            required property string modelData
                            readonly property string filePath: modelData
                            readonly property bool isCurrentWallpaper: (Config.options?.background?.wallpaperPath ?? "") === filePath
                            readonly property bool isHovered: wpMouseArea.containsMouse

                            width: wallpaperGroup.itemWidth
                            height: wallpaperGroup.itemHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: "transparent"
                                border.width: wpDelegate.isCurrentWallpaper ? 2 : 0
                                border.color: Appearance.colors.colPrimary
                                z: 2
                            }

                            Rectangle {
                                id: wpThumb
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer3
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: wpDelegate.filePath ? `file://${wpDelegate.filePath}` : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    sourceSize.width: wallpaperGroup.itemWidth * 2
                                    sourceSize.height: wallpaperGroup.itemHeight * 2

                                    layer.enabled: Appearance.effectsEnabled
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: wpThumb.width
                                            height: wpThumb.height
                                            radius: wpThumb.radius
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: wpDelegate.isHovered && !wpDelegate.isCurrentWallpaper ? "#50000000" : "transparent"
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 28; height: 28
                                    radius: 14
                                    color: Appearance.colors.colPrimary
                                    visible: wpDelegate.isCurrentWallpaper
                                    scale: wpDelegate.isCurrentWallpaper ? 1 : 0
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconSize: 18
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }

                                MouseArea {
                                    id: wpMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Wallpapers.select(wpDelegate.filePath)
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: wallpaperGroup.itemHeight + 16
                    visible: wallpaperGroup.wallpapersList.length === 0
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "image"; iconSize: 24; color: Appearance.colors.colSubtext }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("No wallpapers found in ~/Pictures/Wallpapers")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }

                // Browse button
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: GlobalStates.wallpaperSelectorOpen = true

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol { text: "folder_open"; iconSize: 18; color: Appearance.colors.colOnLayer1 }
                        StyledText {
                            text: Translation.tr("Browse for more...")
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 16 }
        }
    }

    component LayoutContent: ColumnLayout {
        width: 600
        spacing: 16

        Item { Layout.fillHeight: true; Layout.maximumHeight: 16 }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 2
            columnSpacing: 20
            rowSpacing: 16

            // Bar position
            SettingsGroup {
                Layout.preferredWidth: 260
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        MaterialSymbol { text: "web_asset"; iconSize: 18; color: Appearance.colors.colPrimary }
                        StyledText { text: Translation.tr("Bar"); font.pixelSize: Appearance.font.pixelSize.small }
                    }
                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: Config.options?.bar?.bottom ?? false
                        onSelected: v => Config.setNestedValue("bar.bottom", v)
                        options: [
                            { displayName: Translation.tr("Top"), icon: "vertical_align_top", value: false },
                            { displayName: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: true }
                        ]
                    }
                }
            }

            // Bar style
            SettingsGroup {
                Layout.preferredWidth: 260
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        MaterialSymbol { text: "rounded_corner"; iconSize: 18; color: Appearance.colors.colPrimary }
                        StyledText { text: Translation.tr("Bar Style"); font.pixelSize: Appearance.font.pixelSize.small }
                    }
                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: Config.options?.bar?.cornerStyle ?? 0
                        onSelected: v => Config.setNestedValue("bar.cornerStyle", v)
                        options: [
                            { displayName: Translation.tr("Hug"), icon: "line_curve", value: 0 },
                            { displayName: Translation.tr("Float"), icon: "crop_free", value: 1 },
                            { displayName: Translation.tr("Full"), icon: "rectangle", value: 2 }
                        ]
                    }
                }
            }

            // Dock position
            SettingsGroup {
                Layout.preferredWidth: 260
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        MaterialSymbol { text: "dock_to_bottom"; iconSize: 18; color: Appearance.colors.colPrimary }
                        StyledText { text: Translation.tr("Dock"); font.pixelSize: Appearance.font.pixelSize.small }
                    }
                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: Config.options?.dock?.position ?? "bottom"
                        onSelected: v => Config.setNestedValue("dock.position", v)
                        options: [
                            { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: "bottom" },
                            { displayName: Translation.tr("Left"), icon: "arrow_back", value: "left" },
                            { displayName: Translation.tr("Right"), icon: "arrow_forward", value: "right" }
                        ]
                    }
                }
            }

            // Panel family
            SettingsGroup {
                Layout.preferredWidth: 260
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    RowLayout {
                        MaterialSymbol { text: "view_quilt"; iconSize: 18; color: Appearance.colors.colPrimary }
                        StyledText { text: Translation.tr("Panel Style"); font.pixelSize: Appearance.font.pixelSize.small }
                    }
                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: Config.options?.panelFamily ?? "inir"
                        onSelected: v => Config.setNestedValue("panelFamily", v)
                        options: [
                            { displayName: "Material iNiR", icon: "dashboard", value: "inir" },
                            { displayName: "Waffle", icon: "grid_view", value: "waffle" }
                        ]
                    }
                }
            }
        }

        // Additional layout options
        SettingsGroup {
            Layout.fillWidth: true
            Layout.maximumWidth: 560
            Layout.alignment: Qt.AlignHCenter

            ConfigSwitch {
                buttonIcon: "visibility"
                text: Translation.tr("Show bar background")
                checked: Config.options?.bar?.showBackground ?? false
                onCheckedChanged: Config.setNestedValue("bar.showBackground", checked)
            }
            ConfigSwitch {
                buttonIcon: "auto_awesome_motion"
                text: Translation.tr("Bar auto-hide")
                checked: Config.options?.bar?.autoHide?.enable ?? false
                onCheckedChanged: Config.setNestedValue("bar.autoHide.enable", checked)
            }
        }

        Item { Layout.fillHeight: true }
    }

    component FeaturesContent: ColumnLayout {
        width: 640
        spacing: 16

        Item { Layout.fillHeight: true; Layout.maximumHeight: 12 }

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            // Left column
            SettingsGroup {
                Layout.fillWidth: true

                ConfigSwitch {
                    buttonIcon: "auto_awesome"
                    text: Translation.tr("AI Assistant")
                    checked: (Config.options?.policies?.ai ?? 0) >= 1
                    onCheckedChanged: Config.setNestedValue("policies.ai", checked ? 1 : 0)
                }
                ConfigSwitch {
                    buttonIcon: "image"
                    text: Translation.tr("Anime wallpapers")
                    checked: (Config.options?.policies?.weeb ?? 0) >= 1
                    onCheckedChanged: Config.setNestedValue("policies.weeb", checked ? 1 : 0)
                }
                ConfigSwitch {
                    buttonIcon: "notifications_active"
                    text: Translation.tr("Sound effects")
                    checked: Config.options?.sounds?.notifications ?? true
                    onCheckedChanged: Config.setNestedValue("sounds.notifications", checked)
                }
                ConfigSwitch {
                    buttonIcon: "sports_esports"
                    text: Translation.tr("Game mode")
                    checked: Config.options?.gameMode?.autoDetect ?? true
                    onCheckedChanged: Config.setNestedValue("gameMode.autoDetect", checked)
                }
            }

            // Right column
            SettingsGroup {
                Layout.fillWidth: true

                ConfigSwitch {
                    buttonIcon: "dock_to_bottom"
                    text: Translation.tr("Show dock")
                    checked: Config.options?.dock?.enable ?? true
                    onCheckedChanged: Config.setNestedValue("dock.enable", checked)
                }
                ConfigSwitch {
                    buttonIcon: "schedule"
                    text: Translation.tr("Desktop clock")
                    checked: Config.options?.background?.widgets?.clock?.enable ?? true
                    onCheckedChanged: Config.setNestedValue("background.widgets.clock.enable", checked)
                }
                ConfigSwitch {
                    buttonIcon: "bolt"
                    text: Translation.tr("Reduce animations")
                    checked: Config.options?.performance?.reduceAnimations ?? false
                    onCheckedChanged: Config.setNestedValue("performance.reduceAnimations", checked)
                }
                ConfigSwitch {
                    buttonIcon: "hearing"
                    text: Translation.tr("Volume protection")
                    checked: Config.options?.audio?.protection?.enable ?? true
                    onCheckedChanged: Config.setNestedValue("audio.protection.enable", checked)
                }
            }
        }

        // Extra options
        SettingsGroup {
            Layout.fillWidth: true
            Layout.maximumWidth: 600
            Layout.alignment: Qt.AlignHCenter

            ConfigSwitch {
                buttonIcon: "dark_mode"
                text: Translation.tr("Night light (auto)")
                checked: Config.options?.light?.night?.automatic ?? false
                onCheckedChanged: Config.setNestedValue("light.night.automatic", checked)
            }
            ConfigSwitch {
                buttonIcon: "translate"
                text: Translation.tr("Sidebar translator")
                checked: Config.options?.sidebar?.translator?.enable ?? true
                onCheckedChanged: Config.setNestedValue("sidebar.translator.enable", checked)
            }
        }

        Item { Layout.fillHeight: true }
    }

    component ReadyContent: ColumnLayout {
        width: 500
        spacing: 24

        Item { Layout.fillHeight: true }

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "check_circle"
            iconSize: 60
            padding: 20
            shape: MaterialShape.Shape.Circle
            color: Appearance.colors.colPrimaryContainer
            colSymbol: Appearance.colors.colOnPrimaryContainer
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("You're all set!")
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.hugeass + 6
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 400
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("Your desktop is configured and ready to use.\nYou can always change these settings later.")
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        // Quick actions
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            spacing: 12

            RippleButton {
                implicitWidth: 130; implicitHeight: 42
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "settings", "open"])
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol { text: "settings"; iconSize: 18 }
                    StyledText { text: Translation.tr("Settings"); font.pixelSize: Appearance.font.pixelSize.small }
                }
            }

            RippleButton {
                implicitWidth: 130; implicitHeight: 42
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: Qt.openUrlExternally("https://github.com/YaLTeR/niri/wiki")
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol { text: "menu_book"; iconSize: 18 }
                    StyledText { text: Translation.tr("Niri Wiki"); font.pixelSize: Appearance.font.pixelSize.small }
                }
            }

            RippleButton {
                implicitWidth: 130; implicitHeight: 42
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir")
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    StyledText { text: "󰊤"; font.family: Appearance.font.family.iconNerd; font.pixelSize: 18 }
                    StyledText { text: "GitHub"; font.pixelSize: Appearance.font.pixelSize.small }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
