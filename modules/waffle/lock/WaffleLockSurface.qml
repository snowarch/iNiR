pragma ComponentBehavior: Bound
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
    
    // Track if we've attempted unlock at least once (to prevent shake on load)
    property bool hasAttemptedUnlock: false
    
    // Emergency fallback - 5 rapid right-clicks to force unlock (safety net)
    property int emergencyClickCount: 0
    Timer {
        id: emergencyClickTimer
        interval: 1000
        onTriggered: root.emergencyClickCount = 0
    }
    
    // Windows 11 Lock Screen Design Tokens (from Looks.qml)
    readonly property color textColor: Looks.colors.fg
    readonly property color textShadowColor: Looks.colors.shadow
    readonly property real clockFontSize: 96 * Looks.fontScale
    readonly property real dateFontSize: 20 * Looks.fontScale
    readonly property real blurRadius: Config.options?.lock?.blur?.radius ?? 64
    readonly property bool blurEnabled: Config.options?.lock?.blur?.enable ?? true
    
    // Smoke material (Windows 11 - dimming overlay)
    readonly property color smokeColor: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.5)
    
    // Media player reference
    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    // Safe fallback background color (prevents issues on errors)
    Rectangle {
        anchors.fill: parent
        color: Looks.colors.bg0
        z: -1
    }

    // Resolve wallpaper path: waffle-specific if configured, otherwise main
    readonly property string _wallpaperPath: {
        const wBg = Config.options?.waffles?.background
        if (wBg?.useMainWallpaper ?? true) return Config.options?.background?.wallpaperPath ?? ""
        return wBg?.wallpaperPath ?? Config.options?.background?.wallpaperPath ?? ""
    }

    // Background wallpaper with Acrylic blur effect
    Image {
        id: backgroundWallpaper
        anchors.fill: parent
        source: root._wallpaperPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        
        layer.enabled: root.blurEnabled
        layer.effect: FastBlur {
            radius: root.blurRadius
        }
        
        // Slight zoom to hide blur edges
        transform: Scale {
            origin.x: backgroundWallpaper.width / 2
            origin.y: backgroundWallpaper.height / 2
            xScale: root.blurEnabled ? 1.1 : 1
            yScale: root.blurEnabled ? 1.1 : 1
        }
    }
    
    // Smoke overlay for login view (Windows 11 modal dimming - always black per Fluent spec)
    Rectangle {
        id: smokeOverlay
        anchors.fill: parent
        color: root.smokeColor
        opacity: root.showLoginView ? 1 : 0
        Behavior on opacity {
            animation: Looks.transition.enter.createObject(this)
        }
    }

    // ===== LOCK VIEW (Clock) =====
    Item {
        id: lockView
        anchors.fill: parent
        opacity: root.showLoginView ? 0 : 1
        visible: opacity > 0
        scale: root.showLoginView ? 0.95 : 1
        
        Behavior on opacity {
            animation: Looks.transition.enter.createObject(this)
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        
        // Clock - Windows 11 style (centered, large)
        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -60
            spacing: 4
            
            // Time - Windows 11 uses Segoe UI Variable Display with Light weight
            Text {
                id: clockText
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(new Date(), "hh:mm")
                font.pixelSize: root.clockFontSize
                font.weight: Looks.font.weight.thin  // Light weight like Windows 11
                font.family: Looks.font.family.ui
                color: root.textColor
                // Drop shadow for readability on any wallpaper
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 2
                    radius: 8
                    samples: 17
                    color: root.textShadowColor
                }
                
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
                }
            }
            
            // Date - Windows 11 format: "Tuesday, October 5"
            Text {
                id: dateText
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(new Date(), "dddd, MMMM d")
                font.pixelSize: root.dateFontSize
                font.weight: Looks.font.weight.regular
                font.family: Looks.font.family.ui
                color: root.textColor
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 1
                    radius: 4
                    samples: 9
                    color: root.textShadowColor
                }
                
                Timer {
                    interval: 60000  // Update every minute
                    running: true
                    repeat: true
                    onTriggered: dateText.text = Qt.formatDate(new Date(), "dddd, MMMM d")
                }
            }
        }
        
        // Bottom left widgets row (Weather + Media)
        RowLayout {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 48
            anchors.leftMargin: 48
            spacing: 24
            
            // Weather widget - Windows 11 style
            Loader {
                active: Weather.data?.temp && Weather.data.temp.length > 0
                visible: active
                
                sourceComponent: Row {
                    spacing: 12
                    
                    // Weather icon
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const icon = Icons.getWeatherIcon(Weather.data?.wCode ?? "113")
                            return icon ? icon : "cloud"
                        }
                        iconSize: 48
                        color: root.textColor
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 2
                            radius: 6
                            samples: 13
                            color: root.textShadowColor
                        }
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
                            layer.enabled: true
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 1
                                radius: 4
                                samples: 9
                                color: root.textShadowColor
                            }
                        }
                        
                        Text {
                            text: Weather.data?.city ?? ""
                            font.pixelSize: Looks.font.pixelSize.small
                            font.family: Looks.font.family.ui
                            color: Looks.colors.subfg
                            layer.enabled: true
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 1
                                radius: 2
                                samples: 5
                                color: root.textShadowColor
                            }
                        }
                    }
                }
            }
            
            // Media player widget - Windows 11 style (only show if music is playing or paused)
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
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 4
                        radius: 16
                        samples: 33
                        color: root.textShadowColor
                    }
                    
                    RowLayout {
                        id: mediaRow
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16
                        
                        // Album art
                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignVCenter
                            radius: Looks.radius.medium
                            color: Looks.colors.bg2Base
                            clip: true
                            
                            layer.enabled: true
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 2
                                radius: 4
                                samples: 9
                                color: Looks.colors.shadow
                            }
                            
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
                                visible: !mediaWidget.player?.trackArtUrl
                            }
                        }
                        
                        // Track info
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
                        
                        // Controls
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
        
        // Bottom hint - Windows 11 style pill
        Rectangle {
            id: hintContainer
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 48
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintText.implicitWidth + 32
            height: 36
            radius: height / 2
            color: ColorUtils.transparentize(Looks.colors.bg1Base, 0.2)
            border.color: Looks.colors.bg1Border
            border.width: 1
            opacity: hintOpacity
            
            property real hintOpacity: 1
            
            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: 2
                radius: 8
                samples: 17
                color: root.textShadowColor
            }
            
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
            
            // Reset hint when returning to lock view
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
                animation: Looks.transition.opacity.createObject(this)
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
            animation: Looks.transition.enter.createObject(this)
        }
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        // Centered login content
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            
            // User Avatar - Windows 11 style (large circular with shadow)
            Item {
                id: avatarContainer
                Layout.alignment: Qt.AlignHCenter
                width: 120
                height: 120
                
                // Shadow behind avatar
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 4
                    height: parent.height + 4
                    radius: width / 2
                    color: ColorUtils.transparentize(Looks.colors.accent, 1)
                    layer.enabled: Appearance.effectsEnabled
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 4
                        radius: 16
                        samples: 33
                        color: Looks.colors.shadow
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: width / 2
                        color: Looks.colors.accent
                    }
                }
                
                // Avatar circle with image or initial fallback
                Rectangle {
                    id: avatarCircle
                    anchors.fill: parent
                    radius: width / 2
                    color: Looks.colors.accent
                    clip: true
                    
                    // User avatar image - try multiple paths
                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        // Try .face first, then AccountsService
                        source: `file://${Directories.userAvatarPathRicersAndWeirdSystems}`
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready || avatarImageFallback.status === Image.Ready
                        
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarCircle.width
                                height: avatarCircle.height
                                radius: width / 2
                            }
                        }
                    }
                    
                    // Fallback to AccountsService path
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
                    
                    // Fallback: initial letter
                    Text {
                        anchors.centerIn: parent
                        text: SystemInfo.username.charAt(0).toUpperCase()
                        font.pixelSize: 48 * Looks.fontScale
                        font.weight: Looks.font.weight.regular
                        font.family: Looks.font.family.ui
                        color: Looks.colors.accentFg
                        visible: avatarImage.status !== Image.Ready && avatarImageFallback.status !== Image.Ready
                    }
                }
            }
            
            // Username
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                text: SystemInfo.username
                font.pixelSize: 24 * Looks.fontScale
                font.weight: Looks.font.weight.regular
                font.family: Looks.font.family.ui
                color: root.textColor
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 1
                    radius: 4
                    samples: 9
                    color: root.textShadowColor
                }
            }
            
            // Password field container - Windows 11 Acrylic style
            Rectangle {
                id: passwordContainer
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                width: 280
                height: 40
                radius: Looks.radius.medium
                
                // Acrylic-like background (frosted glass effect)
                color: Looks.colors.inputBg
                border.color: passwordField.activeFocus ? Looks.colors.accent : Looks.colors.accentUnfocused
                border.width: passwordField.activeFocus ? 2 : 1
                
                Behavior on border.color {
                    animation: Looks.transition.color.createObject(this)
                }
                Behavior on border.width {
                    animation: Looks.transition.resize.createObject(this)
                }
                
                // Bottom accent line when focused (Windows 11 style)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: passwordField.activeFocus ? parent.width - 4 : 0
                    height: 2
                    radius: 1
                    color: Looks.colors.accent
                    
                    Behavior on width {
                        animation: Looks.transition.resize.createObject(this)
                    }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8
                    
                    // Fingerprint icon (if available)
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
                            anchors.leftMargin: 0
                            verticalAlignment: Text.AlignVCenter
                            text: passwordField.placeholder
                            font: passwordField.font
                            color: GlobalStates.screenUnlockFailed ? Looks.colors.danger : Looks.colors.subfg
                            visible: passwordField.text.length === 0
                            
                            layer.enabled: true
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 1
                                radius: 2
                                samples: 5
                                color: root.textShadowColor
                            }
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
                    
                    // Submit button - Windows 11 accent button
                    Rectangle {
                        id: submitButton
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Looks.radius.medium
                        color: submitMouseArea.pressed 
                            ? Looks.colors.accentActive 
                            : submitMouseArea.containsMouse 
                                ? Looks.colors.accentHover 
                                : Looks.colors.accent
                        
                        Behavior on color {
                            animation: Looks.transition.color.createObject(this)
                        }
                        
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
                        // Only shake if we've actually attempted to unlock
                        if (GlobalStates.screenUnlockFailed && root.hasAttemptedUnlock) {
                            wrongPasswordShakeAnim.restart()
                        }
                    }
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
                    font.pixelSize: Looks.font.pixelSize.small
                    font.family: Looks.font.family.ui
                    color: Looks.colors.subfg
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 1
                        radius: 2
                        samples: 5
                        color: root.textShadowColor
                    }
                }
            }
            
            // Loading indicator when unlocking
            Loader {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                active: root.context.unlockInProgress
                visible: active
                
                sourceComponent: WIndeterminateProgressBar {
                    width: 120
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
            
            // Sleep button
            WaffleLockButton {
                icon: "weather-moon"
                tooltip: Translation.tr("Sleep")
                onClicked: Session.suspend()
            }
            
            // Power button
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
            
            // Restart button
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
                    
                    FluentIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Battery.isCharging ? "battery-charging" : "battery-full"
                        implicitSize: 20
                        color: (Battery.isLow && !Battery.isCharging) 
                            ? Looks.colors.danger 
                            : root.textColor
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 3
                            samples: 7
                            color: root.textShadowColor
                        }
                    }
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Battery.percentage * 100) + "%"
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.family: Looks.font.family.ui
                        color: (Battery.isLow && !Battery.isCharging) 
                            ? Looks.colors.danger 
                            : root.textColor
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 3
                            samples: 7
                            color: root.textShadowColor
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
                    
                    FluentIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "keyboard"
                        implicitSize: 18
                        color: root.textColor
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 2
                            samples: 5
                            color: root.textShadowColor
                        }
                    }
                    
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: HyprlandXkb.currentLayoutCode.toUpperCase()
                        font.pixelSize: Looks.font.pixelSize.small
                        font.family: Looks.font.family.ui
                        color: root.textColor
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 1
                            radius: 2
                            samples: 5
                            color: root.textShadowColor
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
    
    property bool ctrlHeld: false
    
    function forceFieldFocus(): void {
        if (root.showLoginView && loginView.visible) {
            passwordField.forceActiveFocus()
        }
    }
    
    function switchToLogin(): void {
        root.currentView = "login"
        // Use Qt.callLater to ensure loginView is visible before focusing
        Qt.callLater(() => passwordField.forceActiveFocus())
    }
    
    Connections {
        target: context
        function onShouldReFocus() {
            forceFieldFocus()
        }
    }
    
    onClicked: mouse => {
        // Emergency fallback: 5 rapid right-clicks to force unlock
        if (mouse.button === Qt.RightButton) {
            root.emergencyClickCount++
            emergencyClickTimer.restart()
            if (root.emergencyClickCount >= 5) {
                console.warn("[WaffleLockSurface] Emergency unlock triggered!")
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
        
        // Capture printable character BEFORE switching view
        const isPrintable = event.text.length > 0 && !event.modifiers && event.text.charCodeAt(0) >= 32
        const capturedChar = isPrintable ? event.text : ""
        
        // Switch to login view on any key press
        if (!root.showLoginView) {
            root.currentView = "login"
            // Add captured character after view switch completes
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
        
        // Ensure field has focus before accepting input
        if (!passwordField.activeFocus) {
            passwordField.forceActiveFocus()
        }
        
        // Let the TextInput handle the key naturally when it has focus
        if (isPrintable && passwordField.activeFocus) {
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
        // Start in lock view, will switch to login on interaction
        root.currentView = "lock"
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
                root.currentView = "lock"
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
            if (!root.activeFocus && !passwordField.activeFocus) {
                root.forceActiveFocus()
            }
        }
    }
    
    // Helper component for lock screen buttons - Windows 11 style
    component WaffleLockButton: Rectangle {
        id: lockBtn
        required property string icon
        property string tooltip: ""
        property bool toggled: false
        signal clicked()
        
        width: 40
        height: 40
        radius: Looks.radius.medium
        
        // Acrylic-like button background
        color: {
            if (lockBtn.toggled) return Looks.colors.accent
            if (lockBtnMouse.pressed) return Looks.colors.bg1Active
            if (lockBtnMouse.containsMouse) return Looks.colors.bg1Hover
            return Looks.colors.bg1Base
        }
        
        border.color: Looks.colors.bg1Border
        border.width: 1
        
        Behavior on color {
            animation: Looks.transition.color.createObject(this)
        }
        
        FluentIcon {
            anchors.centerIn: parent
            icon: lockBtn.icon
            implicitSize: 20
            color: lockBtn.toggled ? Looks.colors.accentFg : root.textColor
        }
        
        MouseArea {
            id: lockBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lockBtn.clicked()
        }
        
        WToolTip {
            visible: lockBtnMouse.containsMouse && lockBtn.tooltip.length > 0
            text: lockBtn.tooltip
        }
    }
    
    // Helper component for media control buttons
    component WaffleLockMediaButton: Rectangle {
        id: mediaBtn
        required property string icon
        property bool filled: false
        property real size: 32
        signal clicked()
        
        width: size
        height: size
        radius: filled ? Looks.radius.medium : width / 2
        
        color: {
            if (filled) {
                if (mediaBtnMouse.pressed) return Looks.colors.accentActive
                if (mediaBtnMouse.containsMouse) return Looks.colors.accentHover
                return Looks.colors.accent
            } else {
                if (mediaBtnMouse.pressed) return Looks.colors.bg2Active
                if (mediaBtnMouse.containsMouse) return Looks.colors.bg2Hover
                return Looks.colors.bg2Base
            }
        }
        
        Behavior on color {
            animation: Looks.transition.color.createObject(this)
        }
        
        FluentIcon {
            anchors.centerIn: parent
            icon: mediaBtn.icon
            filled: mediaBtn.filled
            implicitSize: mediaBtn.filled ? 20 : 16
            color: mediaBtn.filled ? Looks.colors.accentFg : root.textColor
        }
        
        MouseArea {
            id: mediaBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaBtn.clicked()
        }
    }
}
