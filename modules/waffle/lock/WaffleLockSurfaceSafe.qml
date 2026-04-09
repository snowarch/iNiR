pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtMultimedia
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.lock
import qs.modules.waffle.looks
import Quickshell

MouseArea {
    id: root
    required property LockContext context

    // States: "lock" (clock view) or "login" (password entry)
    property string currentView: "lock"
    property bool showLoginView: currentView === "login"
    readonly property bool requirePasswordToPower: Config.options?.lock?.security?.requirePasswordToPower ?? true

    property bool hasAttemptedUnlock: false

    readonly property color textColor: Looks.colors.fg
    readonly property color textShadowColor: Looks.colors.shadow
    readonly property real clockFontSize: 96 * Looks.fontScale
    readonly property real dateFontSize: 20 * Looks.fontScale

    readonly property bool blurEnabled: Config.options?.lock?.blur?.enable ?? true
    readonly property real blurAmount: 0.8
    readonly property real blurMax: Config.options?.lock?.blur?.radius ?? 64

    readonly property color smokeColor: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.5)

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    readonly property string _wallpaperPath: {
        const wBg = Config.options?.waffles?.background
        if (wBg?.useMainWallpaper ?? true) return Config.options?.background?.wallpaperPath ?? ""
        return wBg?.wallpaperPath ?? Config.options?.background?.wallpaperPath ?? ""
    }
    readonly property bool enableAnimation: Config.options?.lock?.enableAnimation ?? false
    readonly property bool wallpaperIsVideo: {
        const lp = _wallpaperPath.toLowerCase();
        return lp.endsWith(".mp4") || lp.endsWith(".webm") || lp.endsWith(".mkv") || lp.endsWith(".avi") || lp.endsWith(".mov");
    }
    readonly property bool wallpaperIsGif: _wallpaperPath.toLowerCase().endsWith(".gif")

    // Safe base background
    Rectangle {
        anchors.fill: parent
        color: Looks.colors.bg0
        z: -2
    }

     // Wallpaper (piped through MultiEffect for blur)
     Image {
         id: backgroundWallpaperSource
         anchors.fill: parent
         source: (!root.wallpaperIsGif && !root.wallpaperIsVideo) ? root._wallpaperPath : ""
         fillMode: Image.PreserveAspectCrop
         asynchronous: true
         visible: false
         z: -2
     }

     // Animated GIF wallpaper — first frame when animation disabled
     AnimatedImage {
         id: gifWallpaperSource
         anchors.fill: parent
         source: root.wallpaperIsGif ? root._wallpaperPath : ""
         fillMode: Image.PreserveAspectCrop
         asynchronous: true
         cache: false
         playing: visible && root.enableAnimation
         visible: false
         z: -2
     }

     // Video wallpaper — first frame (paused) when animation disabled
     Video {
         id: videoWallpaperSource
         anchors.fill: parent
         visible: false
         z: -2
         source: {
             if (!root.wallpaperIsVideo || !root._wallpaperPath) return "";
             const path = root._wallpaperPath;
             return path.startsWith("file://") ? path : ("file://" + path);
         }
         fillMode: VideoOutput.PreserveAspectCrop
         loops: MediaPlayer.Infinite
         muted: true
         autoPlay: true

         readonly property bool shouldPlay: root.enableAnimation

         function pauseAndShowFirstFrame() {
             pause()
             seek(0)
         }

         onPlaybackStateChanged: {
             if (playbackState === MediaPlayer.PlayingState && !shouldPlay)
                 pauseAndShowFirstFrame()
             if (playbackState === MediaPlayer.StoppedState && visible && shouldPlay)
                 play()
         }

         onShouldPlayChanged: {
             if (root.wallpaperIsVideo) {
                 if (shouldPlay) play()
                 else pauseAndShowFirstFrame()
             }
         }
     }

     MultiEffect {
         id: backgroundWallpaper
         anchors.fill: parent
         source: root.wallpaperIsGif ? gifWallpaperSource
               : root.wallpaperIsVideo ? videoWallpaperSource
               : backgroundWallpaperSource
         visible: true
         z: -1

         blurEnabled: root.blurEnabled
         blur: root.blurAmount
         blurMax: root.blurMax
         saturation: 0.5
     }

    // Dim overlay to keep text readable without shadows
    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.65)
        opacity: root.showLoginView ? 0.75 : 0.25
        Behavior on opacity {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
        }
    }

    // Smoke overlay (login)
    Rectangle {
        anchors.fill: parent
        color: root.smokeColor
        opacity: root.showLoginView ? 1 : 0
        Behavior on opacity {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
        }
    }

    // ===== LOCK VIEW =====
    Item {
        id: lockView
        anchors.fill: parent
        opacity: root.showLoginView ? 0 : 1
        visible: opacity > 0
        scale: root.showLoginView ? 0.95 : 1

        Behavior on opacity {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        // Bottom left widgets row (Weather + Media)
        RowLayout {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 48
            anchors.leftMargin: 48
            spacing: 24

            Loader {
                active: (Weather.data?.temp?.length ?? 0) > 0
                visible: active

                sourceComponent: Row {
                    spacing: 12

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const icon = Icons.getWeatherIcon(Weather.data?.wCode ?? "113", Weather.isNightNow())
                            return icon ? icon : "cloud"
                        }
                        iconSize: 48
                        color: root.textColor
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: Weather.data?.temp ?? ""
                            font.pixelSize: 24 * Looks.fontScale
                            font.weight: Looks.font.weight.thin
                            font.family: Looks.font.family.ui
                            color: root.textColor
                        }

                        Text {
                            text: Weather.visibleCity
                            visible: Weather.showVisibleCity
                            font.pixelSize: Looks.font.pixelSize.small
                            font.family: Looks.font.family.ui
                            color: Looks.colors.subfg
                        }
                    }
                }
            }

            Loader {
                active: root.activePlayer !== null &&
                        root.activePlayer.playbackState !== MprisPlaybackState.Stopped &&
                        (root.activePlayer.trackTitle?.length > 0 ?? false)
                visible: active

                sourceComponent: Rectangle {
                    id: mediaWidget
                    width: Math.max(320, mediaRow.implicitWidth + 32)
                    height: 80
                    radius: Looks.radius.xLarge
                    color: ColorUtils.transparentize(Looks.colors.bg1Base, 0.15)
                    border.color: ColorUtils.transparentize(Looks.colors.bg1Border, 0.5)
                    border.width: 1

                    readonly property MprisPlayer player: root.activePlayer

                    RowLayout {
                        id: mediaRow
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignVCenter
                            radius: Looks.radius.medium
                            color: Looks.colors.bg2Base
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: mediaWidget.player?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            FluentIcon {
                                anchors.centerIn: parent
                                icon: "music-note-2"
                                implicitSize: 24
                                color: Looks.colors.subfg
                                visible: !(mediaWidget.player?.trackArtUrl?.length > 0)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: StringUtils.cleanMusicTitle(mediaWidget.player?.trackTitle ?? "")
                                font.pixelSize: Looks.font.pixelSize.large
                                font.weight: Looks.font.weight.regular
                                font.family: Looks.font.family.ui
                                color: root.textColor
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: mediaWidget.player?.trackArtist ?? ""
                                font.pixelSize: Looks.font.pixelSize.normal
                                font.family: Looks.font.family.ui
                                color: Looks.colors.subfg
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            WaffleLockMediaButton {
                                icon: "previous"
                                onClicked: mediaWidget.player?.previous()
                            }

                            WaffleLockMediaButton {
                                icon: mediaWidget.player?.isPlaying ? "pause" : "play"
                                filled: true
                                size: 40
                                onClicked: mediaWidget.player?.togglePlaying()
                            }

                            WaffleLockMediaButton {
                                icon: "next"
                                onClicked: mediaWidget.player?.next()
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -60
            spacing: 4

            Text {
                id: clockText
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(new Date(), "hh:mm")
                font.pixelSize: root.clockFontSize
                font.weight: Looks.font.weight.thin
                font.family: Looks.font.family.ui
                color: root.textColor

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
                }
            }

            Text {
                id: dateText
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(new Date(), "dddd, MMMM d")
                font.pixelSize: root.dateFontSize
                font.weight: Looks.font.weight.regular
                font.family: Looks.font.family.ui
                color: root.textColor

                Timer {
                    interval: 60000
                    running: true
                    repeat: true
                    onTriggered: dateText.text = Qt.formatDate(new Date(), "dddd, MMMM d")
                }
            }
        }

        // Bottom hint
        Rectangle {
            id: hintContainer
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 48
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintText.implicitWidth + 32
            height: 36
            radius: height / 2
            color: ColorUtils.transparentize(Looks.colors.bg1Base, 0.25)
            border.color: Looks.colors.bg1Border
            border.width: 1
            opacity: hintOpacity

            property real hintOpacity: 1

            Text {
                id: hintText
                anchors.centerIn: parent
                text: Translation.tr("Press any key or click to unlock")
                font.pixelSize: Looks.font.pixelSize.normal
                font.weight: Looks.font.weight.regular
                font.family: Looks.font.family.ui
                color: root.textColor
            }

            Timer {
                id: hintFadeTimer
                interval: 4000
                running: lockView.visible
                onTriggered: hintContainer.hintOpacity = 0
            }

            Connections {
                target: lockView
                function onVisibleChanged() {
                    if (lockView.visible) {
                        hintContainer.hintOpacity = 1
                        hintFadeTimer.restart()
                    }
                }
            }

            Behavior on hintOpacity {
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }
        }
    }

    // ===== LOGIN VIEW =====
    Item {
        id: loginView
        anchors.fill: parent
        opacity: root.showLoginView ? 1 : 0
        visible: opacity > 0
        scale: root.showLoginView ? 1 : 1.05

        Behavior on opacity {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            // Avatar (Material-like ring + circular clip, no OpacityMask)
            Item {
                id: avatarContainer
                Layout.alignment: Qt.AlignHCenter
                width: 120
                height: 120

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: parent.height + 8
                    radius: width / 2
                    color: "transparent"
                    border.color: Looks.colors.accent
                    border.width: 3
                }

                Rectangle {
                    id: avatarCircle
                    anchors.fill: parent
                    radius: width / 2
                    color: Looks.colors.accent

                    // Sources (kept invisible, rendered via masked MultiEffect below)
                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        source: safeLockAvatarResolver.resolvedSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        mipmap: true
                        sourceSize.width: avatarCircle.width * 2
                        sourceSize.height: avatarCircle.height * 2
                        visible: false
                    }

                    QtObject {
                        id: safeLockAvatarResolver
                        property int avatarIndex: 0
                        readonly property string resolvedSource: Directories.avatarSourceAt(avatarIndex)
                        readonly property string primaryWatch: Directories.userAvatarSourcePrimary
                        onPrimaryWatchChanged: avatarIndex = 0
                        readonly property int imgStatus: avatarImage.status
                        onImgStatusChanged: {
                            if (imgStatus === Image.Error) {
                                const nextIdx = avatarIndex + 1
                                if (nextIdx < Directories.userAvatarPaths.length)
                                    avatarIndex = nextIdx
                            }
                        }
                    }

                    ShaderEffectSource {
                        id: avatarMaskSource
                        visible: false
                        sourceItem: Rectangle {
                            width: avatarCircle.width
                            height: avatarCircle.height
                            radius: width / 2
                            color: "white"
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: avatarImage
                        maskEnabled: true
                        maskSource: avatarMaskSource
                        visible: avatarImage.status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: (SystemInfo.displayName || SystemInfo.username || "?").charAt(0).toUpperCase()
                        font.pixelSize: 48 * Looks.fontScale
                        font.weight: Looks.font.weight.regular
                        font.family: Looks.font.family.ui
                        color: Looks.colors.accentFg
                        visible: avatarImage.status !== Image.Ready
                    }
                }
            }

            // Display name
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                text: SystemInfo.displayName || SystemInfo.username
                font.pixelSize: 24 * Looks.fontScale
                font.weight: Looks.font.weight.regular
                font.family: Looks.font.family.ui
                color: root.textColor
            }

            Rectangle {
                id: passwordContainer
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                width: 280
                height: 40
                radius: Looks.radius.medium
                color: Looks.colors.inputBg
                border.color: passwordField.activeFocus ? Looks.colors.accent : Looks.colors.accentUnfocused
                border.width: passwordField.activeFocus ? 2 : 1

                Behavior on border.color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }
                Behavior on border.width { animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Loader {
                        Layout.alignment: Qt.AlignVCenter
                        active: root.context.fingerprintsConfigured
                        visible: active

                        sourceComponent: FluentIcon {
                            icon: "fingerprint"
                            implicitSize: 20
                            color: Looks.colors.subfg
                        }
                    }

                    TextInput {
                        id: passwordField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        font.pixelSize: Looks.font.pixelSize.large
                        font.family: Looks.font.family.ui
                        color: root.textColor
                        selectionColor: Looks.colors.selection
                        selectedTextColor: Looks.colors.accentFg
                        enabled: !root.context.unlockInProgress

                        property string placeholder: GlobalStates.screenUnlockFailed
                            ? Translation.tr("Incorrect password")
                            : Translation.tr("Password")

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: passwordField.placeholder
                            font: passwordField.font
                            color: GlobalStates.screenUnlockFailed ? Looks.colors.danger : Looks.colors.subfg
                            visible: passwordField.text.length === 0
                        }

                        onTextChanged: root.context.currentText = text
                        onAccepted: {
                            root.hasAttemptedUnlock = true
                            root.context.tryUnlock(root.ctrlHeld)
                        }

                        Connections {
                            target: root.context
                            function onCurrentTextChanged() {
                                passwordField.text = root.context.currentText
                            }
                        }

                        Keys.onPressed: event => {
                            root.context.resetClearTimer()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Looks.radius.medium
                        color: submitMouseArea.pressed
                            ? Looks.colors.accentActive
                            : submitMouseArea.containsMouse
                                ? Looks.colors.accentHover
                                : Looks.colors.accent

                        Behavior on color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

                        FluentIcon {
                            anchors.centerIn: parent
                            icon: {
                                if (root.context.targetAction === LockContext.ActionEnum.Unlock) {
                                    return root.ctrlHeld ? "drink-coffee" : "chevron-right"
                                } else if (root.context.targetAction === LockContext.ActionEnum.Poweroff) {
                                    return "power"
                                } else if (root.context.targetAction === LockContext.ActionEnum.Reboot) {
                                    return "arrow-counterclockwise"
                                }
                                return "chevron-right"
                            }
                            implicitSize: 16
                            color: Looks.colors.accentFg
                        }

                        MouseArea {
                            id: submitMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.context.unlockInProgress
                            onClicked: {
                                root.hasAttemptedUnlock = true
                                root.context.tryUnlock(root.ctrlHeld)
                            }
                        }
                    }
                }

                // Shake animation on wrong password
                property real shakeOffset: 0
                transform: Translate { x: passwordContainer.shakeOffset }

                SequentialAnimation {
                    id: wrongPasswordShakeAnim
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: -20; duration: 50 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: 20; duration: 50 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: -10; duration: 40 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: 10; duration: 40 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: 0; duration: 30 }
                }

                Connections {
                    target: GlobalStates
                    function onScreenUnlockFailedChanged() {
                        if (GlobalStates.screenUnlockFailed && root.hasAttemptedUnlock) {
                            wrongPasswordShakeAnim.restart()
                        }
                    }
                }
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                active: root.context.unlockInProgress
                visible: active
                sourceComponent: WIndeterminateProgressBar { width: 120 }
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                active: root.context.fingerprintsConfigured && !root.context.unlockInProgress
                visible: active
                sourceComponent: Text {
                    text: Translation.tr("Touch sensor to unlock")
                    font.pixelSize: Looks.font.pixelSize.small
                    font.family: Looks.font.family.ui
                    color: Looks.colors.subfg
                }
            }
        }

        // Bottom right: Power options
        RowLayout {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 24
            anchors.rightMargin: 24
            spacing: 8

            WaffleLockButton {
                icon: "weather-moon"
                tooltip: Translation.tr("Sleep")
                onClicked: Session.suspend()
            }

            WaffleLockButton {
                icon: "power"
                tooltip: Translation.tr("Shut down")
                toggled: root.context.targetAction === LockContext.ActionEnum.Poweroff
                onClicked: {
                    if (!root.requirePasswordToPower) {
                        root.context.unlocked(LockContext.ActionEnum.Poweroff)
                        return
                    }
                    if (root.context.targetAction === LockContext.ActionEnum.Poweroff) {
                        root.context.resetTargetAction()
                    } else {
                        root.context.targetAction = LockContext.ActionEnum.Poweroff
                        root.context.shouldReFocus()
                    }
                }
            }

            WaffleLockButton {
                icon: "arrow-counterclockwise"
                tooltip: Translation.tr("Restart")
                toggled: root.context.targetAction === LockContext.ActionEnum.Reboot
                onClicked: {
                    if (!root.requirePasswordToPower) {
                        root.context.unlocked(LockContext.ActionEnum.Reboot)
                        return
                    }
                    if (root.context.targetAction === LockContext.ActionEnum.Reboot) {
                        root.context.resetTargetAction()
                    } else {
                        root.context.targetAction = LockContext.ActionEnum.Reboot
                        root.context.shouldReFocus()
                    }
                }
            }
        }

        // Bottom left: Battery
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 24
            anchors.leftMargin: 24
            spacing: 16

            Loader {
                active: UPower.displayDevice.isLaptopBattery
                visible: active
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: Row {
                    spacing: 6

                    FluentIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Battery.isCharging ? "battery-charging" : "battery-full"
                        implicitSize: 20
                        color: (Battery.isLow && !Battery.isCharging)
                            ? Looks.colors.danger
                            : root.textColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Battery.percentage * 100) + "%"
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.family: Looks.font.family.ui
                        color: (Battery.isLow && !Battery.isCharging)
                            ? Looks.colors.danger
                            : root.textColor
                    }
                }
            }
        }
    }

    // ===== INPUT HANDLING =====

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    focus: true
    activeFocusOnTab: true

    property bool ctrlHeld: false

    function forceFieldFocus(): void {
        if (root.showLoginView && loginView.visible) {
            passwordField.forceActiveFocus()
        }
    }

    function switchToLogin(): void {
        root.currentView = "login"
        Qt.callLater(() => passwordField.forceActiveFocus())
    }

    Connections {
        target: context
        function onShouldReFocus() {
            forceFieldFocus()
        }
    }

    onClicked: mouse => {
        if (!root.showLoginView) {
            root.switchToLogin()
        } else {
            root.forceFieldFocus()
        }
    }

    onPositionChanged: mouse => {
        if (root.showLoginView) {
            root.forceFieldFocus()
        }
    }

    Keys.onPressed: event => {
        root.context.resetClearTimer()

        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = true
            return
        }

        if (event.key === Qt.Key_Escape) {
            if (root.context.currentText.length > 0) {
                root.context.currentText = ""
            } else if (root.showLoginView && root.currentView === "login") {
                root.currentView = "lock"
            }
            return
        }

        const isPrintable = event.text.length > 0 && !event.modifiers && event.text.charCodeAt(0) >= 32
        const capturedChar = isPrintable ? event.text : ""

        if (!root.showLoginView) {
            root.currentView = "login"
            if (capturedChar.length > 0) {
                Qt.callLater(() => {
                    root.context.currentText += capturedChar
                    passwordField.forceActiveFocus()
                })
                event.accepted = true
            } else {
                Qt.callLater(() => passwordField.forceActiveFocus())
            }
            return
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.hasAttemptedUnlock = true
            root.context.tryUnlock(root.ctrlHeld)
            event.accepted = true
            return
        }

        if (!passwordField.activeFocus) {
            passwordField.forceActiveFocus()
        }

        if (isPrintable && passwordField.activeFocus) {
            event.accepted = false
        }
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = false
        }
        forceFieldFocus()
    }

    Component.onCompleted: {
        root.currentView = "lock"
        GlobalStates.screenUnlockFailed = false
        root.hasAttemptedUnlock = false
        Qt.callLater(() => root.forceActiveFocus())
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) {
                root.currentView = "lock"
                root.hasAttemptedUnlock = false
                GlobalStates.screenUnlockFailed = false
                Qt.callLater(() => root.forceActiveFocus())
            }
        }
    }

    Timer {
        id: focusEnsureTimer
        interval: 100
        running: GlobalStates.screenLocked && root.visible
        repeat: false
        onTriggered: {
            if (!root.activeFocus && !passwordField.activeFocus) {
                root.forceActiveFocus()
            }
        }
    }

    component WaffleLockButton: Rectangle {
        id: lockBtn
        required property string icon
        property string tooltip: ""
        property bool toggled: false

        signal clicked()

        width: 44
        height: 44
        radius: Looks.radius.medium

        color: {
            if (lockBtn.toggled) return Looks.colors.accent
            if (btnMouseArea.pressed) return Looks.colors.bg1Active
            if (btnMouseArea.containsMouse) return Looks.colors.bg1Hover
            return Looks.colors.bg1Base
        }

        border.color: Looks.colors.bg1Border
        border.width: 1

        Behavior on color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }
        Behavior on border.color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

        FluentIcon {
            anchors.centerIn: parent
            icon: lockBtn.icon
            implicitSize: 20
            color: lockBtn.toggled ? Looks.colors.accentFg : root.textColor
        }

        MouseArea {
            id: btnMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: lockBtn.clicked()
        }
    }

    component WaffleLockMediaButton: Rectangle {
        id: mediaBtn
        required property string icon
        property bool filled: false
        property int size: 32

        signal clicked()

        width: size
        height: size
        radius: filled ? Looks.radius.medium : width / 2

        color: {
            if (filled) {
                if (mediaMouseArea.pressed) return Looks.colors.accentActive
                if (mediaMouseArea.containsMouse) return Looks.colors.accentHover
                return Looks.colors.accent
            }
            if (mediaMouseArea.pressed) return Looks.colors.bg2Active
            if (mediaMouseArea.containsMouse) return Looks.colors.bg2Hover
            return Looks.colors.bg2Base
        }

        Behavior on color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

        FluentIcon {
            anchors.centerIn: parent
            icon: mediaBtn.icon
            implicitSize: mediaBtn.filled ? 20 : 16
            color: filled ? Looks.colors.accentFg : root.textColor
        }

        MouseArea {
            id: mediaMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaBtn.clicked()
        }
    }
}
