//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
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
    property var focusedScreen: GlobalStates.primaryScreen

    // ─── Entry/exit animation state (gate pattern) ───
    property bool _entryReady: false
    property bool _contentReady: false
    property bool _closing: false

    readonly property var steps: [
        { icon: "waving_hand", title: Translation.tr("Welcome") },
        { icon: "palette", title: Translation.tr("Appearance") },
        { icon: "dashboard", title: Translation.tr("Layout") },
        { icon: "tune", title: Translation.tr("Features") },
        { icon: "celebration", title: Translation.tr("Ready") }
    ]

    function finish(skipped: bool): void {
        if (root._closing) return
        root._closing = true
        // Write config keys
        Config.setNestedValue("welcomeWizard.completed", !skipped)
        Config.setNestedValue("welcomeWizard.skipped", skipped)
        // Reverse the entry animation
        root._contentReady = false
        root._entryReady = false
        _exitTimer.start()
    }

    Timer {
        id: _exitTimer
        interval: Appearance.animationsEnabled ? 400 : 0
        repeat: false
        onTriggered: {
            // first_run.txt is already written by FirstRunExperience before launching us
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Welcome to inir"), Translation.tr("Press Super+/ for all keyboard shortcuts."), "-a", "Shell"])
            Qt.quit()
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false
        MaterialThemeLoader.reapplyTheme()
        Config.readWriteDelay = 0
        // Staggered entry: scrim first, then card content
        if (Appearance.animationsEnabled) {
            _entryTimer.start()
        } else {
            root._entryReady = true
            root._contentReady = true
        }
    }

    Timer {
        id: _entryTimer
        interval: 80
        repeat: false
        onTriggered: {
            root._entryReady = true
            _contentEntryTimer.start()
        }
    }
    Timer {
        id: _contentEntryTimer
        interval: 120
        repeat: false
        onTriggered: root._contentReady = true
    }

    PanelWindow {
        id: wizardPanel
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:welcome"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root._closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }
        implicitWidth: root.focusedScreen?.width ?? 1920
        implicitHeight: root.focusedScreen?.height ?? 1080

        // ─── Blurred wallpaper backdrop (scrim) ───
        Item {
            id: scrim
            anchors.fill: parent
            opacity: root._entryReady ? 1.0 : 0.0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(320)
                    easing.type: Easing.OutCubic
                }
            }

            // Blur edge compensation: MultiEffect fades at boundaries
            readonly property int blurOverflow: 64

            Item {
                id: blurSource
                anchors.fill: parent
                anchors.margins: -scrim.blurOverflow

                Image {
                    anchors.fill: parent
                    anchors.margins: scrim.blurOverflow
                    source: Config.options?.background?.wallpaperPath ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: wizardPanel.implicitWidth
                    sourceSize.height: wizardPanel.implicitHeight
                }
            }

            MultiEffect {
                source: blurSource
                anchors.fill: parent
                anchors.margins: -scrim.blurOverflow
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled ? 1.0 : 0
                saturation: Appearance.effectsEnabled ? 0.15 : 0
            }

            // Scrim overlay
            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: 0.55
            }

            // Vignette
            GE.RadialGradient {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.6; color: "transparent" }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.35) }
                }
            }
        }

        // Click outside does NOT dismiss — just absorb clicks
        MouseArea {
            anchors.fill: parent
        }

        // Main wizard card
        Item {
            id: wizardCard
            anchors.centerIn: parent
            width: Math.min(960, parent.width * 0.75)
            height: Math.min(parent.height * 0.85, parent.height - 60)
            focus: true

            // Staggered entry animation — card comes in after scrim
            transformOrigin: Item.Center
            scale: root._contentReady ? 1.0 : 0.92
            opacity: root._contentReady ? 1.0 : 0.0
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(420)
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(350)
                    easing.type: Easing.OutCubic
                }
            }

            // Keyboard navigation
            Keys.onEscapePressed: root.finish(true)
            Keys.onLeftPressed: if (root.currentStep > 0) root.currentStep--
            Keys.onRightPressed: if (root.currentStep < root.totalSteps - 1) root.currentStep++
            Keys.onReturnPressed: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish(false)
            Keys.onEnterPressed: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish(false)

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

                // Base color — colLayer1Base is the raw m3surfaceContainerLow without
                // contentTransparency mixing, so the wizard stays solid even when the user
                // has transparency enabled in Material/Cards styles.
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.auroraEverywhere ? "transparent"
                     : Appearance.colors.colLayer1Base

                border.width: Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
                border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.colors.colLayer0Border

                Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                Behavior on border.color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                // Aurora: Wallpaper blur inside card
                Item {
                    id: auroraBlurSource
                    visible: Appearance.auroraEverywhere
                    anchors.fill: parent

                    Image {
                        x: -wizardCard.x
                        y: -wizardCard.y
                        width: wizardPanel.width
                        height: wizardPanel.height
                        source: Config.options?.background?.wallpaperPath ?? ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                MultiEffect {
                    visible: Appearance.auroraEverywhere
                    source: auroraBlurSource
                    anchors.fill: parent
                    blurEnabled: Appearance.effectsEnabled
                    blurMax: 40
                    blur: Appearance.effectsEnabled ? 1.0 : 0
                    saturation: Appearance.effectsEnabled ? 0.1 : 0
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
                layer.effect: GE.OpacityMask {
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
                    spacing: 10

                    // Step circles + labels
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 0

                        Repeater {
                            model: root.steps
                            Row {
                                required property int index
                                required property var modelData

                                ColumnLayout {
                                    spacing: 4

                                    Rectangle {
                                        id: stepCircle
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: 38; implicitHeight: 38; radius: 19

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

                                        // Click on a past step to jump back to it (forward jumping disabled to keep flow)
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: index <= root.currentStep ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: index <= root.currentStep
                                            onClicked: root.currentStep = index
                                        }
                                    }

                                    // Step label (small, below circle)
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 70
                                        text: modelData.title
                                        horizontalAlignment: Text.AlignHCenter
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.weight: index === root.currentStep ? Font.Medium : Font.Normal
                                        color: index === root.currentStep
                                            ? Appearance.colors.colOnLayer1
                                            : Appearance.colors.colSubtext
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                                    }
                                }

                                // Connector line with progress
                                Item {
                                    visible: index < root.steps.length - 1
                                    width: 36; height: 4
                                    y: 17  // align with circle vertical center (38/2 - 4/2)

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

                    // "Step X of N" subtle counter
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        text: Translation.tr("Step %1 of %2").arg(root.currentStep + 1).arg(root.totalSteps)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                        opacity: 0.8
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

                // Navigation buttons — Back / hint / Continue (Skip moved to top-right corner)
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
                        buttonText: root.currentStep === root.totalSteps - 1 ? Translation.tr("Get Started") : Translation.tr("Continue")
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colText: Appearance.colors.colOnPrimary
                        onClicked: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish(false)
                    }
                }
            }

            // Subtle "Skip setup" escape hatch in the top-right corner of the card.
            // Hidden on the last step (where "Get Started" is the right action).
            RippleButton {
                id: skipButton
                property bool _hovered: false
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 14
                anchors.rightMargin: 14
                visible: root.currentStep < root.totalSteps - 1
                opacity: visible ? (_hovered ? 1.0 : 0.65) : 0
                Behavior on opacity { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                implicitHeight: 30
                implicitWidth: skipRow.implicitWidth + 20
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover

                onClicked: root.finish(true)

                contentItem: RowLayout {
                    id: skipRow
                    anchors.centerIn: parent
                    spacing: 4

                    StyledText {
                        text: Translation.tr("Skip setup")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    MaterialSymbol {
                        text: "close"
                        iconSize: 14
                        color: Appearance.colors.colSubtext
                    }
                }

                StyledToolTip {
                    text: Translation.tr("You can re-open this wizard anytime with:\n  inir welcome")
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: skipButton._hovered = hovered
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP CONTENT COMPONENTS
    // ═══════════════════════════════════════════════════════════════════════

    component WelcomeContent: ColumnLayout {
        width: 640
        spacing: 18

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
            text: Translation.tr("Two minutes to make it yours. Skipping is fine, but you'll thank yourself later.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.normal
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            Layout.maximumWidth: 520
        }

        // "What we'll set up" — gives users a preview so they see VALUE before skipping
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.maximumWidth: 540
            implicitWidth: 520
            implicitHeight: previewCol.implicitHeight + 24
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                 : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                 : Appearance.colors.colLayer2
            border.width: Appearance.inirEverywhere ? 1 : 0
            border.color: Appearance.inir.colBorderSubtle

            ColumnLayout {
                id: previewCol
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 10

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("What you'll dial in")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: Appearance.colors.colSubtext
                }

                Repeater {
                    model: [
                        { icon: "palette",       label: Translation.tr("Theme & wallpaper"), desc: Translation.tr("Light/dark, visual style, and your colors") },
                        { icon: "dashboard",     label: Translation.tr("Layout"),            desc: Translation.tr("Bar, dock, panel family — where things live") },
                        { icon: "tune",          label: Translation.tr("Features"),          desc: Translation.tr("AI, weather, sounds, time format, and more") },
                        { icon: "celebration",   label: Translation.tr("Tips for daily use"), desc: Translation.tr("Keyboard shortcuts and one-click actions") }
                    ]
                    RowLayout {
                        Layout.fillWidth: true
                        required property var modelData
                        spacing: 12

                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: 22
                            color: Appearance.colors.colPrimary
                            Layout.preferredWidth: 24
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.label
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurface
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.desc
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                wrapMode: Text.WordWrap
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // Settings UI experience choice — Easy vs Advanced
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            Layout.maximumWidth: 560
            spacing: 8

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("How do you want to see Settings?")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurface
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                // Easy mode card
                Rectangle {
                    id: easyCard
                    readonly property bool selected: (Config.options?.settingsUi?.easyMode ?? false) === true
                    implicitWidth: 240
                    implicitHeight: easyCardCol.implicitHeight + 24
                    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                    color: selected
                        ? Appearance.colors.colPrimaryContainer
                        : (Appearance.inirEverywhere ? Appearance.inir.colLayer2
                          : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                          : Appearance.colors.colLayer2)
                    border.width: selected ? 2 : 1
                    border.color: selected
                        ? Appearance.colors.colPrimary
                        : (Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                          : Appearance.colors.colLayer0Border)

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }

                    ColumnLayout {
                        id: easyCardCol
                        anchors {
                            fill: parent
                            margins: 12
                        }
                        spacing: 6

                        RowLayout {
                            spacing: 8
                            MaterialSymbol {
                                text: "school"
                                iconSize: 22
                                color: easyCard.selected
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Easy")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: easyCard.selected
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colOnSurface
                            }
                            MaterialSymbol {
                                visible: easyCard.selected
                                text: "check_circle"
                                iconSize: 18
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Just the essentials. Less noise, friendlier for new users. You can switch anytime.")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            wrapMode: Text.WordWrap
                            color: easyCard.selected
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colSubtext
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.setNestedValue("settingsUi.easyMode", true)
                    }
                }

                // Advanced mode card
                Rectangle {
                    id: advancedCard
                    readonly property bool selected: (Config.options?.settingsUi?.easyMode ?? false) === false
                    implicitWidth: 240
                    implicitHeight: advancedCardCol.implicitHeight + 24
                    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                    color: selected
                        ? Appearance.colors.colPrimaryContainer
                        : (Appearance.inirEverywhere ? Appearance.inir.colLayer2
                          : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                          : Appearance.colors.colLayer2)
                    border.width: selected ? 2 : 1
                    border.color: selected
                        ? Appearance.colors.colPrimary
                        : (Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                          : Appearance.colors.colLayer0Border)

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }

                    ColumnLayout {
                        id: advancedCardCol
                        anchors {
                            fill: parent
                            margins: 12
                        }
                        spacing: 6

                        RowLayout {
                            spacing: 8
                            MaterialSymbol {
                                text: "tune"
                                iconSize: 22
                                color: advancedCard.selected
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Advanced")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: advancedCard.selected
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colOnSurface
                            }
                            MaterialSymbol {
                                visible: advancedCard.selected
                                text: "check_circle"
                                iconSize: 18
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Everything iNiR has to offer. Recommended if you like to tinker.")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            wrapMode: Text.WordWrap
                            color: advancedCard.selected
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colSubtext
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.setNestedValue("settingsUi.easyMode", false)
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
                            return style === "material" ? Translation.tr("Clean & Solid")
                                 : style === "cards" ? Translation.tr("Rounded Cards")
                                 : style === "aurora" ? Translation.tr("Glass & Blur")
                                 : style === "angel" ? Translation.tr("Neo-Brutalism Glass")
                                 : Translation.tr("Terminal Style")
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
            readonly property string wallpapersPath: Directories.wallpapersPath
            readonly property real itemWidth: 130
            readonly property real itemHeight: 78

            Component.onCompleted: wallpaperScanProc.running = true

            Process {
                id: wallpaperScanProc
                command: ["/bin/sh", "-c", `find '${wallpaperGroup.wallpapersPath}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' \\) -printf '%C@\\t%p\\n' 2>/dev/null`]
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
                                    layer.effect: GE.OpacityMask {
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
                            text: Translation.tr("No wallpapers found in ~/Pictures/Wallpapers").replace("~/Pictures/Wallpapers", Directories.shortHomePath(Directories.wallpapersPath))
                            color: Appearance.colors.colSubtext
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
                        currentValue: Config.options?.panelFamily ?? "ii"
                        onSelected: v => Config.setNestedValue("panelFamily", v)
                        options: [
                            { displayName: "Material II", icon: "dashboard", value: "ii" },
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

    component FeaturesContent: Flickable {
        id: featuresFlickable
        width: 640
        contentHeight: featuresColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: featuresColumn
            width: parent.width
            spacing: 16

            Item { Layout.preferredHeight: 4 }

            // Row 1 + 2 — main feature toggles (4 + 4)
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

            // Row 3 — extra toggles (night light, translator, weather, autohide)
            RowLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 600
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                SettingsGroup {
                    Layout.fillWidth: true

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

                SettingsGroup {
                    Layout.fillWidth: true

                    ConfigSwitch {
                        buttonIcon: "cloud"
                        text: Translation.tr("Weather widget")
                        checked: Config.options?.bar?.weather?.enable ?? false
                        onCheckedChanged: Config.setNestedValue("bar.weather.enable", checked)
                    }
                    ConfigSwitch {
                        buttonIcon: "auto_awesome_motion"
                        text: Translation.tr("Auto-hide bar")
                        checked: Config.options?.bar?.autoHide?.enable ?? false
                        onCheckedChanged: Config.setNestedValue("bar.autoHide.enable", checked)
                    }
                }
            }

            // Time & locale subsection
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: 600
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    text: Translation.tr("Time format")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                ConfigSelectionArray {
                    Layout.alignment: Qt.AlignHCenter
                    currentValue: Config.options?.background?.widgets?.clock?.timeFormat ?? "system"
                    onSelected: v => Config.setNestedValue("background.widgets.clock.timeFormat", v)
                    options: [
                        { displayName: Translation.tr("System"),  icon: "settings",    value: "system" },
                        { displayName: Translation.tr("24-hour"), icon: "schedule",    value: "24h" },
                        { displayName: Translation.tr("12-hour"), icon: "nights_stay", value: "12h" }
                    ]
                }

                SettingsGroup {
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    ConfigSwitch {
                        buttonIcon: "more_time"
                        text: Translation.tr("Show seconds in clock")
                        checked: Config.options?.background?.widgets?.clock?.showSeconds ?? false
                        onCheckedChanged: Config.setNestedValue("background.widgets.clock.showSeconds", checked)
                    }
                }
            }

            Item { Layout.preferredHeight: 8 }
        }
    }

    component ReadyContent: Flickable {
        id: readyFlickable
        width: 720
        contentHeight: readyColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: readyColumn
            width: parent.width
            spacing: 18

            Item { Layout.preferredHeight: 4 }

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "check_circle"
                iconSize: 50
                padding: 16
                shape: MaterialShape.Shape.Circle
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colOnPrimaryContainer
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("You're all set!")
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.hugeass + 4
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 540
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Bookmark these — your desktop will feel instantly faster once they're muscle memory.")
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            // Two cards side by side: shortcuts + CLI tips
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.maximumWidth: 700
                spacing: 14

                // Keyboard shortcuts card
                Rectangle {
                    Layout.preferredWidth: 340
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: shortcutsCardCol.implicitHeight + 24
                    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                    color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                         : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                         : Appearance.colors.colLayer2
                    border.width: Appearance.inirEverywhere ? 1 : 0
                    border.color: Appearance.inir.colBorderSubtle

                    ColumnLayout {
                        id: shortcutsCardCol
                        anchors {
                            fill: parent
                            margins: 12
                        }
                        spacing: 10

                        RowLayout {
                            spacing: 8
                            MaterialSymbol { text: "keyboard"; iconSize: 18; color: Appearance.colors.colPrimary }
                            StyledText {
                                text: Translation.tr("Keyboard")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                            }
                            Item { Layout.fillWidth: true }
                            StyledText {
                                text: Translation.tr("Press Super+/ for full list")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Repeater {
                            model: [
                                { keys: "Super+/",     desc: Translation.tr("All shortcuts") },
                                { keys: "Super+Space", desc: Translation.tr("App launcher") },
                                { keys: "Super+,",     desc: Translation.tr("Settings") },
                                { keys: "Super+T",     desc: Translation.tr("Terminal") },
                                { keys: "Super+E",     desc: Translation.tr("File manager") },
                                { keys: "Super+V",     desc: Translation.tr("Clipboard history") }
                            ]
                            RowLayout {
                                Layout.fillWidth: true
                                required property var modelData
                                spacing: 10

                                Row {
                                    spacing: 2
                                    Repeater {
                                        model: modelData.keys.split("+")
                                        KeyboardKey {
                                            required property string modelData
                                            key: modelData
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                StyledText {
                                    text: modelData.desc
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }

                // Try it now — interactive action card
                Rectangle {
                    Layout.preferredWidth: 340
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: tryItCardCol.implicitHeight + 24
                    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                    color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                         : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                         : Appearance.colors.colLayer2
                    border.width: Appearance.inirEverywhere ? 1 : 0
                    border.color: Appearance.inir.colBorderSubtle

                    ColumnLayout {
                        id: tryItCardCol
                        anchors {
                            fill: parent
                            margins: 12
                        }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol { text: "rocket_launch"; iconSize: 18; color: Appearance.colors.colPrimary }
                            StyledText {
                                text: Translation.tr("Try it now")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                            }
                            Item { Layout.fillWidth: true }
                            StyledText {
                                text: Translation.tr("one click, no typing")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Repeater {
                            model: [
                                {
                                    icon: "wallpaper",
                                    label: Translation.tr("Pick a wallpaper"),
                                    sub: Translation.tr("Browse and apply"),
                                    target: "wallpaperSelector",
                                    fn: "toggle"
                                },
                                {
                                    icon: "notifications_active",
                                    label: Translation.tr("Test a notification"),
                                    sub: Translation.tr("See how popups look"),
                                    target: "notifications",
                                    fn: "test"
                                },
                                {
                                    icon: "keyboard",
                                    label: Translation.tr("Show all shortcuts"),
                                    sub: Translation.tr("Cheatsheet overlay"),
                                    target: "cheatsheet",
                                    fn: "toggle"
                                },
                                {
                                    icon: "tune",
                                    label: Translation.tr("Open quick settings"),
                                    sub: Translation.tr("Wi-Fi, audio, brightness"),
                                    target: "controlPanel",
                                    fn: "toggle"
                                }
                            ]
                            RippleButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                required property var modelData
                                buttonRadius: Appearance.rounding.small
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colLayer1Hover

                                onClicked: Quickshell.execDetached([
                                    Quickshell.shellPath("scripts/inir"),
                                    modelData.target,
                                    modelData.fn
                                ])

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    MaterialSymbol {
                                        text: modelData.icon
                                        iconSize: 22
                                        color: Appearance.colors.colPrimary
                                        Layout.preferredWidth: 26
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnLayer1
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.sub
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: Appearance.colors.colSubtext
                                            elide: Text.ElideRight
                                        }
                                    }
                                    MaterialSymbol {
                                        text: "arrow_forward"
                                        iconSize: 16
                                        color: Appearance.colors.colSubtext
                                        opacity: 0.6
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Need help? clickable callout — opens troubleshooting wiki
            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                Layout.preferredWidth: 694
                Layout.maximumWidth: 700
                Layout.preferredHeight: helpCalloutRow.implicitHeight + 18
                buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.6)
                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.4)

                onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/wiki/Troubleshooting")

                Rectangle {
                    anchors.fill: parent
                    radius: parent.buttonRadius
                    color: "transparent"
                    border.width: 1
                    border.color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)
                }

                RowLayout {
                    id: helpCalloutRow
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 9
                    anchors.bottomMargin: 9
                    spacing: 10

                    MaterialSymbol {
                        text: "support"
                        iconSize: 20
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Something not working?")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Open the troubleshooting guide — common fixes, in plain English.")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.2)
                            wrapMode: Text.WordWrap
                        }
                    }
                    MaterialSymbol {
                        text: "open_in_new"
                        iconSize: 16
                        color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.3)
                    }
                }
            }

            // Quick actions
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                spacing: 10

                RippleButton {
                    implicitWidth: 120; implicitHeight: 38
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol { text: "settings"; iconSize: 16 }
                        StyledText { text: Translation.tr("Settings"); font.pixelSize: Appearance.font.pixelSize.small }
                    }
                }

                RippleButton {
                    implicitWidth: 120; implicitHeight: 38
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/wiki")
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol { text: "menu_book"; iconSize: 16 }
                        StyledText { text: Translation.tr("iNiR Wiki"); font.pixelSize: Appearance.font.pixelSize.small }
                    }
                }

                RippleButton {
                    implicitWidth: 120; implicitHeight: 38
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/issues")
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol { text: "bug_report"; iconSize: 16 }
                        StyledText { text: Translation.tr("Report bug"); font.pixelSize: Appearance.font.pixelSize.small }
                    }
                }

                RippleButton {
                    implicitWidth: 120; implicitHeight: 38
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir")
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        StyledText { text: "󰊤"; font.family: Appearance.font.family.iconNerd; font.pixelSize: 16 }
                        StyledText { text: "GitHub"; font.pixelSize: Appearance.font.pixelSize.small }
                    }
                }
            }

            Item { Layout.preferredHeight: 8 }
        }
    }
}
