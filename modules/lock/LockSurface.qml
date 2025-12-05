import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.bar as Bar
import Quickshell
import Quickshell.Services.SystemTray

MouseArea {
    id: root
    required property LockContext context
    property bool active: false
    property bool showInputField: active || context.currentText.length > 0
    readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower

    // Background wallpaper with blur
    Image {
        id: backgroundWallpaper
        anchors.fill: parent
        source: Config.options.background.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        
        layer.enabled: Config.options.lock.blur.enable
        layer.effect: FastBlur {
            radius: Config.options.lock.blur.radius
        }
        
        transform: Scale {
            origin.x: backgroundWallpaper.width / 2
            origin.y: backgroundWallpaper.height / 2
            xScale: Config.options.lock.blur.enable ? Config.options.lock.blur.extraZoom : 1
            yScale: Config.options.lock.blur.enable ? Config.options.lock.blur.extraZoom : 1
        }
    }

    // Clock (center)
    Loader {
        id: clockLoader
        active: Config.options.lock.centerClock
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -100
        sourceComponent: ColumnLayout {
            spacing: 0
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(new Date(), "hh:mm")
                font.pixelSize: Math.round(120 * Appearance.fontSizeScale)
                font.weight: Font.Bold
                color: Appearance.colors.colOnSurface
                style: Text.Outline
                styleColor: Appearance.colors.colSurface
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(new Date(), "dddd, d MMMM")
                font.pixelSize: Math.round(32 * Appearance.fontSizeScale)
                color: Appearance.colors.colOnSurface
                style: Text.Outline
                styleColor: Appearance.colors.colSurface
            }
        }
    }

    // Media player widget
    Toolbar {
        id: mediaIsland
        visible: MprisController.activePlayer !== null
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: clockLoader.bottom
            topMargin: Appearance.sizes.spacingLarge
        }
        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        readonly property MprisPlayer player: MprisController.activePlayer

        ToolbarButton {
            implicitWidth: height
            onClicked: mediaIsland.player?.previous()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_previous"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        ToolbarButton {
            implicitWidth: height
            toggled: mediaIsland.player?.isPlaying ?? false
            onClicked: mediaIsland.player?.togglePlaying()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: mediaIsland.player?.isPlaying ? "pause" : "play_arrow"
                iconSize: Appearance.font.pixelSize.huge
                color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
            }
        }

        ToolbarButton {
            implicitWidth: height
            onClicked: mediaIsland.player?.next()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_next"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        StyledText {
            Layout.leftMargin: 4
            Layout.rightMargin: Appearance.sizes.spacingMedium
            Layout.alignment: Qt.AlignVCenter
            text: StringUtils.cleanMusicTitle(mediaIsland.player?.trackTitle) + (mediaIsland.player?.trackArtist ? " • " + mediaIsland.player.trackArtist : "")
            color: Appearance.colors.colOnSurfaceVariant
            elide: Text.ElideRight
            Layout.maximumWidth: 300
        }
    }
    
    // Locked text (top)
    Loader {
        active: Config.options.lock.showLockedText
        anchors.top: parent.top
        anchors.topMargin: 50
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: RowLayout {
            spacing: 10
            MaterialSymbol {
                text: "lock"
                iconSize: 24
                color: Appearance.colors.colOnSurface
            }
            StyledText {
                text: Translation.tr("Locked")
                font.pixelSize: Appearance.font.pixelSize.hugeass
                color: Appearance.colors.colOnSurface
            }
        }
    }

    // Force focus on entry
    function forceFieldFocus() {
        passwordBox.forceActiveFocus();
    }
    Connections {
        target: context
        function onShouldReFocus() {
            forceFieldFocus();
        }
    }
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: mouse => {
        forceFieldFocus();
    }
    onPositionChanged: mouse => {
        forceFieldFocus();
    }

    // Toolbar appearing animation
    property real toolbarScale: 0.9
    property real toolbarOpacity: 0
    Behavior on toolbarScale {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
        }
    }
    Behavior on toolbarOpacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    // Init
    Component.onCompleted: {
        forceFieldFocus();
        toolbarScale = 1;
        toolbarOpacity = 1;
    }

    // Key presses
    property bool ctrlHeld: false
    Keys.onPressed: event => {
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = true;
        }
        if (event.key === Qt.Key_Escape) {
            root.context.currentText = "";
        }
        forceFieldFocus();
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = false;
        }
        forceFieldFocus();
    }

    // Main toolbar: password box
    Toolbar {
        id: mainIsland
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 20
        }
        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        // Fingerprint
        Loader {
            Layout.leftMargin: 10
            Layout.rightMargin: 6
            Layout.alignment: Qt.AlignVCenter
            active: root.context.fingerprintsConfigured
            visible: active

            sourceComponent: MaterialSymbol {
                id: fingerprintIcon
                fill: 1
                text: "fingerprint"
                iconSize: Appearance.font.pixelSize.hugeass
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        ToolbarTextField {
            id: passwordBox
            Layout.rightMargin: -Layout.leftMargin
            placeholderText: GlobalStates.screenUnlockFailed ? Translation.tr("Incorrect password") : Translation.tr("Enter password")

            clip: true
            font.pixelSize: Appearance.font.pixelSize.small

            enabled: !root.context.unlockInProgress
            echoMode: TextInput.Password
            inputMethodHints: Qt.ImhSensitiveData

            onTextChanged: root.context.currentText = this.text
            onAccepted: root.context.tryUnlock(root.ctrlHeld)
            Connections {
                target: root.context
                function onCurrentTextChanged() {
                    passwordBox.text = root.context.currentText;
                }
            }

            Keys.onPressed: event => {
                root.context.resetClearTimer();
            }
            
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: passwordBox.width - 8
                    height: passwordBox.height
                    radius: height / 2
                }
            }

            SequentialAnimation {
                id: wrongPasswordShakeAnim
                NumberAnimation { target: passwordBox; property: "Layout.leftMargin"; to: -30; duration: 50 }
                NumberAnimation { target: passwordBox; property: "Layout.leftMargin"; to: 30; duration: 50 }
                NumberAnimation { target: passwordBox; property: "Layout.leftMargin"; to: -15; duration: 40 }
                NumberAnimation { target: passwordBox; property: "Layout.leftMargin"; to: 15; duration: 40 }
                NumberAnimation { target: passwordBox; property: "Layout.leftMargin"; to: 0; duration: 30 }
            }
            Connections {
                target: GlobalStates
                function onScreenUnlockFailedChanged() {
                    if (GlobalStates.screenUnlockFailed) wrongPasswordShakeAnim.restart();
                }
            }

            property bool materialShapeChars: Config.options.lock.materialShapeChars
            color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, materialShapeChars ? 1 : 0)
            Loader {
                active: passwordBox.materialShapeChars
                anchors {
                    fill: parent
                    leftMargin: passwordBox.padding
                    rightMargin: passwordBox.padding
                }
                sourceComponent: PasswordChars {
                    length: root.context.currentText.length
                }
            }
        }

        ToolbarButton {
            id: confirmButton
            implicitWidth: height
            toggled: true
            enabled: !root.context.unlockInProgress
            colBackgroundToggled: Appearance.colors.colPrimary

            onClicked: root.context.tryUnlock()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                iconSize: 24
                text: {
                    if (root.context.targetAction === LockContext.ActionEnum.Unlock) {
                        return root.ctrlHeld ? "emoji_food_beverage" : "arrow_right_alt";
                    } else if (root.context.targetAction === LockContext.ActionEnum.Poweroff) {
                        return "power_settings_new";
                    } else if (root.context.targetAction === LockContext.ActionEnum.Reboot) {
                        return "restart_alt";
                    }
                }
                color: confirmButton.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
            }
        }
    }

    // Left toolbar
    Toolbar {
        id: leftIsland
        anchors {
            right: mainIsland.left
            top: mainIsland.top
            bottom: mainIsland.bottom
            rightMargin: 10
        }
        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        IconAndTextPair {
            Layout.leftMargin: 8
            icon: "account_circle"
            text: SystemInfo.username
        }

        Loader {
            Layout.rightMargin: 8
            Layout.fillHeight: true
            active: true
            visible: active

            sourceComponent: Row {
                spacing: 8

                MaterialSymbol {
                    id: keyboardIcon
                    anchors.verticalCenter: parent.verticalCenter
                    fill: 1
                    text: "keyboard_alt"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colOnSurfaceVariant
                }
                Loader {
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: StyledText {
                        text: HyprlandXkb.currentLayoutCode
                        color: Appearance.colors.colOnSurfaceVariant
                        animateChange: true
                    }
                }
            }
        }

        Bar.SysTray {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            showSeparator: false
            showOverflowMenu: false
            pinnedItems: SystemTray.items.values.filter(i => i.id == "Fcitx")
            visible: pinnedItems.length > 0
        }
    }

    // Right toolbar
    Toolbar {
        id: rightIsland
        anchors {
            left: mainIsland.right
            top: mainIsland.top
            bottom: mainIsland.bottom
            leftMargin: 10
        }

        scale: root.toolbarScale
        opacity: root.toolbarOpacity

        IconAndTextPair {
            visible: UPower.displayDevice.isLaptopBattery
            icon: Battery.isCharging ? "bolt" : "battery_android_full"
            text: Math.round(Battery.percentage * 100)
            color: (Battery.isLow && !Battery.isCharging) ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
        }

        IconToolbarButton {
            id: sleepButton
            onClicked: Session.suspend()
            text: "dark_mode"
        }

        PasswordGuardedIconToolbarButton {
            id: powerButton
            text: "power_settings_new"
            targetAction: LockContext.ActionEnum.Poweroff
        }

        PasswordGuardedIconToolbarButton {
            id: rebootButton
            text: "restart_alt"
            targetAction: LockContext.ActionEnum.Reboot
        }
    }

    component PasswordGuardedIconToolbarButton: IconToolbarButton {
        id: guardedBtn
        required property var targetAction

        toggled: root.context.targetAction === guardedBtn.targetAction

        onClicked: {
            if (!root.requirePasswordToPower) {
                root.context.unlocked(guardedBtn.targetAction);
                return;
            }
            if (root.context.targetAction === guardedBtn.targetAction) {
                root.context.resetTargetAction();
            } else {
                root.context.targetAction = guardedBtn.targetAction;
                root.context.shouldReFocus();
            }
        }
    }

    component IconAndTextPair: Row {
        id: pair
        required property string icon
        required property string text
        property color color: Appearance.colors.colOnSurfaceVariant

        spacing: 4
        Layout.fillHeight: true
        Layout.leftMargin: 10
        Layout.rightMargin: 10

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 1
            text: pair.icon
            iconSize: Appearance.font.pixelSize.huge
            animateChange: true
            color: pair.color
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: pair.text
            color: pair.color
        }
    }
}
