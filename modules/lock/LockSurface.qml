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
    
    // States: "clock" (initial view) or "login" (password entry)
    property string currentView: "clock"
    // Show login view when explicitly switched OR when there's password text
    property bool showLoginView: currentView === "login"
    property bool hasAttemptedUnlock: false
    
    readonly property bool requirePasswordToPower: Config.options?.lock?.security?.requirePasswordToPower ?? true
    readonly property bool blurEnabled: Config.options?.lock?.blur?.enable ?? true
    readonly property real blurRadius: Config.options?.lock?.blur?.radius ?? 64
    readonly property real blurZoom: Config.options?.lock?.blur?.extraZoom ?? 1.1
    
    // Emergency fallback - triple click anywhere to force unlock (safety net)
    property int emergencyClickCount: 0
    Timer {
        id: emergencyClickTimer
        interval: 1000
        onTriggered: root.emergencyClickCount = 0
    }

    // Safe fallback background color (prevents red screen on errors)
    Rectangle {
        anchors.fill: parent
        color: Appearance.m3colors?.m3background ?? "#1a1a2e"
        z: -1
    }
    
    // Background wallpaper with blur
    Image {
        id: backgroundWallpaper
        anchors.fill: parent
        source: Config.options?.background?.wallpaperPath ?? ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        
        layer.enabled: root.blurEnabled
        layer.effect: FastBlur {
            radius: root.blurRadius
        }
        
        transform: Scale {
            origin.x: backgroundWallpaper.width / 2
            origin.y: backgroundWallpaper.height / 2
            xScale: root.blurEnabled ? root.blurZoom : 1
            yScale: root.blurEnabled ? root.blurZoom : 1
        }
    }
    
    // Gradient overlay for better text readability
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.1) }
            GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.05) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.3) }
        }
    }

    // Smoke overlay for login view (dims background)
    Rectangle {
        id: smokeOverlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: root.showLoginView ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
            }
        }
    }

    // ===== CLOCK VIEW (Initial) =====
    Item {
        id: clockView
        anchors.fill: parent
        opacity: root.showLoginView ? 0 : 1
        visible: opacity > 0
        scale: root.showLoginView ? 0.95 : 1
        
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.OutCubic
            }
        }
        
        // Clock - Material You style (centered, large)
        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -80
            spacing: 8
            
            // Time
            Text {
                id: clockText
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(new Date(), "hh:mm")
                font.pixelSize: Math.round(108 * Appearance.fontSizeScale)
                font.weight: Font.Light
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnSurface
                
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 3
                    radius: 16
                    samples: 33
                    color: Qt.rgba(0, 0, 0, 0.5)
                }
                
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
                }
            }
            
            // Date
            Text {
                id: dateText
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(new Date(), "dddd, d MMMM")
                font.pixelSize: Math.round(22 * Appearance.fontSizeScale)
                font.weight: Font.Normal
                font.family: Appearance.font.family.main
                color: Appearance.colors.colOnSurface
                
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 1
                    radius: 8
                    samples: 17
                    color: Qt.rgba(0, 0, 0, 0.4)
                }
                
                Timer {
                    interval: 60000
                    running: true
                    repeat: true
                    onTriggered: dateText.text = Qt.formatDate(new Date(), "dddd, d MMMM")
                }
            }
        }

        // Media player widget (below clock) - only show if music is actually playing or paused
        Loader {
            id: mediaWidgetLoader
            active: MprisController.activePlayer !== null && 
                    MprisController.activePlayer.playbackState !== MprisPlaybackState.Stopped &&
                    (MprisController.activePlayer.trackTitle?.length > 0 ?? false)
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.verticalCenter
                topMargin: 60
            }
            
            sourceComponent: LockMediaWidget {
                player: MprisController.activePlayer
                width: 360
                height: 120
            }
        }
        
        // Bottom left: Weather widget
        Loader {
            active: Weather.data?.temp && Weather.data.temp.length > 0
            visible: active
            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: 40
                bottomMargin: 40
            }
            
            sourceComponent: Row {
                spacing: 12
                
                function isNightTime(): bool {
                    const now = new Date()
                    const currentHour = now.getHours()
                    const currentMinutes = now.getMinutes()
                    const currentTime = currentHour * 60 + currentMinutes
                    
                    function parseTime(timeStr: string): int {
                        if (!timeStr) return -1
                        const match = timeStr.match(/(\d+):(\d+)\s*(AM|PM)/i)
                        if (!match) return -1
                        let hours = parseInt(match[1])
                        const minutes = parseInt(match[2])
                        const isPM = match[3].toUpperCase() === "PM"
                        if (isPM && hours !== 12) hours += 12
                        if (!isPM && hours === 12) hours = 0
                        return hours * 60 + minutes
                    }
                    
                    const sunrise = parseTime(Weather.data?.sunrise ?? "")
                    const sunset = parseTime(Weather.data?.sunset ?? "")
                    
                    if (sunrise < 0 || sunset < 0) return currentHour < 6 || currentHour >= 20
                    return currentTime < sunrise || currentTime >= sunset
                }
                
                function getWeatherIconWithTime(code: string): string {
                    const baseIcon = Icons.getWeatherIcon(code) ?? "cloud"
                    const isNight = isNightTime()
                    if (isNight) {
                        if (baseIcon === "clear_day") return "clear_night"
                        if (baseIcon === "partly_cloudy_day") return "partly_cloudy_night"
                    }
                    return baseIcon
                }
                
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.getWeatherIconWithTime(Weather.data?.wCode ?? "113")
                    iconSize: 44
                    fill: 0
                    color: Appearance.colors.colOnSurface
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 2
                        radius: 8
                        samples: 17
                        color: Qt.rgba(0, 0, 0, 0.4)
                    }
                }
                
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    
                    Text {
                        text: Weather.data?.temp ?? ""
                        font.pixelSize: Math.round(26 * Appearance.fontSizeScale)
                        font.weight: Font.Light
                        font.family: Appearance.font.family.main
                        color: Appearance.colors.colOnSurface
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 4
                            samples: 9
                            color: Qt.rgba(0, 0, 0, 0.4)
                        }
                    }
                    
                    Text {
                        text: Weather.data?.city ?? ""
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        color: Appearance.colors.colOnSurfaceVariant
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 2
                            samples: 5
                            color: Qt.rgba(0, 0, 0, 0.3)
                        }
                    }
                }
            }
        }

        // Bottom hint text
        Text {
            id: hintText
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            text: Translation.tr("Press any key or click to unlock")
            font.pixelSize: Appearance.font.pixelSize.normal
            font.family: Appearance.font.family.main
            color: Appearance.colors.colOnSurfaceVariant
            opacity: hintOpacity
            
            property real hintOpacity: 0.7
            
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 1
                radius: 4
                samples: 9
                color: Qt.rgba(0, 0, 0, 0.3)
            }
            
            Timer {
                id: hintFadeTimer
                interval: 4000
                running: clockView.visible
                onTriggered: hintText.hintOpacity = 0
            }
            
            // Reset hint when returning to clock view
            Connections {
                target: clockView
                function onVisibleChanged() {
                    if (clockView.visible) {
                        hintText.hintOpacity = 0.7
                        hintFadeTimer.restart()
                    }
                }
            }
            
            Behavior on hintOpacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration * 2
                    easing.type: Easing.OutCubic
                }
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
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.OutCubic
            }
        }

        // Centered login content
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            
            // User Avatar - Material You style (large circular with accent ring)
            Item {
                id: avatarContainer
                Layout.alignment: Qt.AlignHCenter
                width: 100
                height: 100
                
                // Accent ring behind avatar
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: parent.height + 8
                    radius: width / 2
                    color: "transparent"
                    border.color: Appearance.colors.colPrimary
                    border.width: 3
                    opacity: 0.8
                    
                    layer.enabled: Appearance.effectsEnabled
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 4
                        radius: 16
                        samples: 33
                        color: Qt.rgba(0, 0, 0, 0.4)
                    }
                }
                
                // Avatar circle
                Rectangle {
                    id: avatarCircle
                    anchors.fill: parent
                    radius: width / 2
                    color: Appearance.colors.colPrimary
                    clip: true
                    
                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        source: `file://${Directories.userAvatarPathRicersAndWeirdSystems}`
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                        
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarCircle.width
                                height: avatarCircle.height
                                radius: width / 2
                            }
                        }
                    }
                    
                    Image {
                        id: avatarImageFallback
                        anchors.fill: parent
                        source: avatarImage.status !== Image.Ready 
                            ? `file://${Directories.userAvatarPathAccountsService}` 
                            : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready && avatarImage.status !== Image.Ready
                        
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarCircle.width
                                height: avatarCircle.height
                                radius: width / 2
                            }
                        }
                    }
                    
                    // Fallback initial
                    Text {
                        anchors.centerIn: parent
                        text: SystemInfo.username.charAt(0).toUpperCase()
                        font.pixelSize: 40
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimary
                        visible: avatarImage.status !== Image.Ready && avatarImageFallback.status !== Image.Ready
                    }
                }
            }
            
            // Username
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                text: SystemInfo.username
                font.pixelSize: Math.round(22 * Appearance.fontSizeScale)
                font.weight: Font.Medium
                font.family: Appearance.font.family.main
                color: Appearance.colors.colOnSurface
                
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 1
                    radius: 6
                    samples: 13
                    color: Qt.rgba(0, 0, 0, 0.4)
                }
            }

            // Password field - Material You style pill
            Rectangle {
                id: passwordContainer
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                width: 300
                height: 52
                radius: height / 2
                color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.2)
                border.color: loginPasswordField.activeFocus 
                    ? Appearance.colors.colPrimary 
                    : ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.7)
                border.width: loginPasswordField.activeFocus ? 2 : 1
                
                Behavior on border.color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                
                layer.enabled: Appearance.effectsEnabled
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 4
                    radius: 12
                    samples: 25
                    color: Qt.rgba(0, 0, 0, 0.3)
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 8
                    spacing: 8
                    
                    // Fingerprint icon (if available)
                    Loader {
                        Layout.alignment: Qt.AlignVCenter
                        active: root.context.fingerprintsConfigured
                        visible: active
                        
                        sourceComponent: MaterialSymbol {
                            text: "fingerprint"
                            iconSize: 22
                            fill: 1
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }
                    
                    TextInput {
                        id: loginPasswordField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.family: Appearance.font.family.main
                        color: materialShapeChars ? "transparent" : Appearance.colors.colOnSurface
                        selectionColor: Appearance.colors.colPrimary
                        selectedTextColor: Appearance.colors.colOnPrimary
                        
                        enabled: !root.context.unlockInProgress
                        
                        property bool materialShapeChars: Config.options?.lock?.materialShapeChars ?? false
                        property string placeholder: GlobalStates.screenUnlockFailed 
                            ? Translation.tr("Incorrect password") 
                            : Translation.tr("Password")
                        
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: loginPasswordField.placeholder
                            font: loginPasswordField.font
                            color: GlobalStates.screenUnlockFailed 
                                ? Appearance.colors.colError 
                                : Appearance.colors.colOnSurfaceVariant
                            visible: loginPasswordField.text.length === 0
                        }
                        
                        onTextChanged: root.context.currentText = text
                        onAccepted: {
                            root.hasAttemptedUnlock = true
                            root.context.tryUnlock(root.ctrlHeld)
                        }
                        
                        Connections {
                            target: root.context
                            function onCurrentTextChanged() {
                                loginPasswordField.text = root.context.currentText
                            }
                        }
                        
                        Keys.onPressed: event => {
                            root.context.resetClearTimer()
                        }
                        
                        // Material shape password chars overlay
                        Loader {
                            active: loginPasswordField.materialShapeChars && loginPasswordField.text.length > 0
                            anchors {
                                fill: parent
                                leftMargin: 4
                                rightMargin: 4
                            }
                            sourceComponent: PasswordChars {
                                length: root.context.currentText.length
                            }
                        }
                    }
                    
                    // Submit button
                    Rectangle {
                        id: submitButton
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: submitMouseArea.pressed 
                            ? Appearance.colors.colPrimaryActive 
                            : submitMouseArea.containsMouse 
                                ? Appearance.colors.colPrimaryHover 
                                : Appearance.colors.colPrimary
                        
                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                        
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: {
                                if (root.context.targetAction === LockContext.ActionEnum.Unlock) {
                                    return root.ctrlHeld ? "emoji_food_beverage" : "arrow_forward"
                                } else if (root.context.targetAction === LockContext.ActionEnum.Poweroff) {
                                    return "power_settings_new"
                                } else if (root.context.targetAction === LockContext.ActionEnum.Reboot) {
                                    return "restart_alt"
                                }
                            }
                            iconSize: 20
                            color: Appearance.colors.colOnPrimary
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
                
                // Shake animation
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

            // Loading indicator
            Loader {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                active: root.context.unlockInProgress
                visible: active
                
                sourceComponent: StyledIndeterminateProgressBar {
                    width: 120
                }
            }
            
            // Fingerprint hint
            Loader {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                active: root.context.fingerprintsConfigured && !root.context.unlockInProgress
                visible: active
                
                sourceComponent: Text {
                    text: Translation.tr("Touch sensor to unlock")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.main
                    color: Appearance.colors.colOnSurfaceVariant
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 1
                        radius: 2
                        samples: 5
                        color: Qt.rgba(0, 0, 0, 0.3)
                    }
                }
            }
        }
        
        // Bottom right: Power options
        Row {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 24
            anchors.rightMargin: 24
            spacing: 8
            
            LockIconButton {
                icon: "dark_mode"
                tooltip: Translation.tr("Sleep")
                onClicked: Session.suspend()
            }
            
            LockIconButton {
                icon: "power_settings_new"
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
                        loginPasswordField.forceActiveFocus()
                    }
                }
            }
            
            LockIconButton {
                icon: "restart_alt"
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
                        loginPasswordField.forceActiveFocus()
                    }
                }
            }
        }
        
        // Bottom left: Battery & keyboard layout
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 24
            anchors.leftMargin: 24
            spacing: 16
            
            // Battery
            Loader {
                active: UPower.displayDevice.isLaptopBattery
                visible: active
                anchors.verticalCenter: parent.verticalCenter
                
                sourceComponent: Row {
                    spacing: 6
                    
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Battery.isCharging ? "bolt" : "battery_full"
                        iconSize: 20
                        fill: 1
                        color: (Battery.isLow && !Battery.isCharging) 
                            ? Appearance.colors.colError 
                            : Appearance.colors.colOnSurfaceVariant
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 3
                            samples: 7
                            color: Qt.rgba(0, 0, 0, 0.3)
                        }
                    }
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Battery.percentage * 100) + "%"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.family: Appearance.font.family.main
                        color: (Battery.isLow && !Battery.isCharging) 
                            ? Appearance.colors.colError 
                            : Appearance.colors.colOnSurfaceVariant
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 3
                            samples: 7
                            color: Qt.rgba(0, 0, 0, 0.3)
                        }
                    }
                }
            }
            
            // Keyboard layout
            Loader {
                active: typeof HyprlandXkb !== "undefined" && HyprlandXkb.currentLayoutCode.length > 0
                visible: active
                anchors.verticalCenter: parent.verticalCenter
                
                sourceComponent: Row {
                    spacing: 4
                    
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "keyboard"
                        iconSize: 18
                        fill: 1
                        color: Appearance.colors.colOnSurfaceVariant
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 2
                            samples: 5
                            color: Qt.rgba(0, 0, 0, 0.3)
                        }
                    }
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: HyprlandXkb.currentLayoutCode.toUpperCase()
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        color: Appearance.colors.colOnSurfaceVariant
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 2
                            samples: 5
                            color: Qt.rgba(0, 0, 0, 0.3)
                        }
                    }
                }
            }
        }
    }

    // ===== INPUT HANDLING =====
    
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    focus: true
    activeFocusOnTab: true
    
    onClicked: mouse => {
        // Emergency fallback: 5 rapid right-clicks to force unlock
        if (mouse.button === Qt.RightButton) {
            root.emergencyClickCount++
            emergencyClickTimer.restart()
            if (root.emergencyClickCount >= 5) {
                console.warn("[LockSurface] Emergency unlock triggered!")
                root.emergencyClickCount = 0
                GlobalStates.screenLocked = false
            }
            return
        }
        
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
    
    property bool ctrlHeld: false
    
    function forceFieldFocus(): void {
        if (root.showLoginView && loginView.visible) {
            loginPasswordField.forceActiveFocus()
        }
    }
    
    function switchToLogin(): void {
        root.currentView = "login"
        // Use Qt.callLater to ensure loginView is visible before focusing
        Qt.callLater(() => loginPasswordField.forceActiveFocus())
    }
    
    Connections {
        target: context
        function onShouldReFocus() {
            forceFieldFocus()
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
                root.currentView = "clock"
            }
            return
        }
        
        // Capture printable character BEFORE switching view so we don't lose it
        const isPrintable = event.text.length > 0 && !event.modifiers && event.text.charCodeAt(0) >= 32
        const capturedChar = isPrintable ? event.text : ""
        
        // Switch to login view on any key press
        if (!root.showLoginView) {
            root.currentView = "login"
            // Add the captured character immediately to context (syncs to field)
            if (capturedChar.length > 0) {
                // Use Qt.callLater to ensure the field is ready before adding text
                Qt.callLater(() => {
                    root.context.currentText += capturedChar
                    loginPasswordField.forceActiveFocus()
                })
                event.accepted = true
            } else {
                // Focus the field after view switch
                Qt.callLater(() => loginPasswordField.forceActiveFocus())
            }
            return
        }
        
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.hasAttemptedUnlock = true
            root.context.tryUnlock(root.ctrlHeld)
            event.accepted = true
            return
        }
        
        // Ensure field has focus before accepting input
        if (!loginPasswordField.activeFocus) {
            loginPasswordField.forceActiveFocus()
        }
        
        // Let the TextInput handle the key naturally when it has focus
        if (isPrintable && loginPasswordField.activeFocus) {
            // Don't manually add - let TextInput handle it
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
        // Start in clock view, will switch to login on interaction
        root.currentView = "clock"
        GlobalStates.screenUnlockFailed = false
        root.hasAttemptedUnlock = false
        // Force focus to receive keyboard events - use callLater to ensure component is fully ready
        Qt.callLater(() => root.forceActiveFocus())
    }
    
    // Reset state when lock screen is activated
    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) {
                root.currentView = "clock"
                root.hasAttemptedUnlock = false
                GlobalStates.screenUnlockFailed = false
                // Force focus when lock activates - delayed to ensure visibility
                Qt.callLater(() => root.forceActiveFocus())
            }
        }
    }
    
    // Ensure focus on first show (workaround for focus issues with Loader)
    Timer {
        id: focusEnsureTimer
        interval: 100
        running: GlobalStates.screenLocked && root.visible
        repeat: false
        onTriggered: {
            if (!root.activeFocus && !loginPasswordField.activeFocus) {
                root.forceActiveFocus()
            }
        }
    }
    
    // ===== COMPONENTS =====
    
    component LockIconButton: Rectangle {
        id: lockBtn
        required property string icon
        property string tooltip: ""
        property bool toggled: false
        
        signal clicked()
        
        width: 44
        height: 44
        radius: Appearance.rounding.normal
        color: {
            if (toggled) return Appearance.colors.colPrimary
            if (lockBtnMouse.pressed) return ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.7)
            if (lockBtnMouse.containsMouse) return ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.85)
            return ColorUtils.transparentize(Appearance.colors.colLayer1, 0.3)
        }
        
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        
        layer.enabled: Appearance.effectsEnabled
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 2
            radius: 8
            samples: 17
            color: Qt.rgba(0, 0, 0, 0.3)
        }
        
        MaterialSymbol {
            anchors.centerIn: parent
            text: lockBtn.icon
            iconSize: 22
            color: lockBtn.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
        }
        
        MouseArea {
            id: lockBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lockBtn.clicked()
        }
        
        StyledToolTip {
            visible: lockBtnMouse.containsMouse && lockBtn.tooltip.length > 0
            text: lockBtn.tooltip
        }
    }
}
