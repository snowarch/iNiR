// iNiR SDDM pixel theme — exact replica of modules/lock/LockSurface.qml (ii/Material)
// States: "clock" (initial) ↔ "login" (password entry), same layout + transitions.
import QtQuick 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0
import "."

MouseArea {
    id: root
    width: Screen.width; height: Screen.height
    focus: true; hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    // ── SDDM state ─────────────────────────────────────────────────────────
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int currentSessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool loginInProgress: false
    property bool loginFailed: false
    property bool keyboardOpen: false
    property string currentView: "clock"
    property bool showLoginView: currentView === "login"

    readonly property string currentUserName: {
        if (userModel.count <= 0 || !userModel.get) return ""
        const u = userModel.get(root.userIndex)
        return u ? (u.realName || u.name || "") : ""
    }
    readonly property string currentUserLogin: {
        if (userModel.count <= 0 || !userModel.get) return ""
        const u = userModel.get(root.userIndex)
        return u ? (u.name || "") : ""
    }
    readonly property string currentUserIcon: {
        if (userModel.count <= 0 || !userModel.get) return ""
        const u = userModel.get(root.userIndex)
        return u ? (u.icon || "") : ""
    }
    readonly property string currentSessionName: {
        if (sessionModel.count <= 0 || !sessionModel.get) return ""
        const s = sessionModel.get(root.currentSessionIndex)
        return s ? (s.name || "") : ""
    }

    // ── Theme (synced from matugen by sync-pixel-sddm.py) ──────────────────
    readonly property color colPrimary:          config.primaryColor          || "#cba6f7"
    readonly property color colOnPrimary:        config.onPrimaryColor        || "#1e1e2e"
    readonly property color colSurface:          config.surfaceColor          || "#1e1e2e"
    readonly property color colSurfaceContainer: config.surfaceContainerColor || "#181825"
    readonly property color colOnSurface:        config.onSurfaceColor        || "#cdd6f4"
    readonly property color colOnSurfaceVariant: config.onSurfaceVariantColor || "#9399b2"
    readonly property color colBackground:       config.backgroundColor       || "#1e1e2e"
    readonly property color colError:            config.errorColor            || "#f38ba8"
    readonly property real  blurRadius:          isNaN(Number(config.blurRadius)) ? 64 : Number(config.blurRadius)

    function symFont(): string {
        return materialSymbolsFont.status === FontLoader.Ready ? materialSymbolsFont.name : ""
    }

    function makeFileUrl(p): string {
        if (!p || p.length === 0) return ""
        return p.startsWith("file://") ? p : "file://" + p
    }

    // Avatar paths — try in order: SDDM provided → AccountsService → ~/.face
    readonly property string _avatarPath1: root.currentUserIcon
    readonly property string _avatarPath2: "/var/lib/AccountsService/icons/" + root.currentUserLogin
    readonly property string _avatarPath3: "/home/" + root.currentUserLogin + "/.face"

    function switchToLogin(captureChar) {
        root.currentView = "login"
        Qt.callLater(function() {
            passwordBox.forceActiveFocus()
            if (captureChar && captureChar.length === 1 && captureChar.charCodeAt(0) >= 32)
                passwordBox.text += captureChar
        })
    }

    function attemptLogin() {
        if (root.loginInProgress || passwordBox.text.length === 0) return
        root.loginInProgress = true
        root.loginFailed = false
        sddm.login(root.currentUserLogin, passwordBox.text, root.currentSessionIndex)
    }

    TextConstants { id: textConstants }
    FontLoader { id: materialSymbolsFont; source: "fonts/MaterialSymbolsRounded.ttf" }

    Connections {
        target: sddm
        function onLoginSucceeded() { unlockFadeAnim.start() }
        function onLoginFailed() {
            root.loginInProgress = false
            root.loginFailed = true
            passwordBox.text = ""
            shakeAnim.restart()
        }
    }

    // ── BACKGROUND ─────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: root.colBackground; z: -1 }

    Image {
        id: wallpaper
        anchors.fill: parent; source: config.background || ""
        fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
        layer.enabled: true
        layer.effect: FastBlur { radius: root.blurRadius }
        transform: Scale {
            origin.x: wallpaper.width / 2; origin.y: wallpaper.height / 2
            xScale: 1.15; yScale: 1.15
        }
    }


    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.1) }
            GradientStop { position: 0.5; color: Qt.rgba(0,0,0,0.05) }
            GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.3) }
        }
    }

    Rectangle {
        id: smokeOverlay; anchors.fill: parent; color: Qt.rgba(0,0,0,0.4)
        opacity: root.showLoginView ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: unlockOverlay; anchors.fill: parent; color: root.colBackground; opacity: 0; z: 100
        NumberAnimation { id: unlockFadeAnim; target: unlockOverlay; property: "opacity"
            from: 0; to: 1; duration: 300; easing.type: Easing.InQuad }
    }

    // ── CLOCK VIEW ─────────────────────────────────────────────────────────
    Item {
        id: clockView
        anchors.fill: parent
        opacity: root.showLoginView ? 0 : 1
        visible: opacity > 0
        scale: root.showLoginView ? 0.92 : 1
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -80
            spacing: 8

            Text {
                id: clockText
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(new Date(), "hh:mm")
                font.pixelSize: 108; font.weight: Font.Light; font.family: "Gabarito"
                color: root.colOnSurface
                layer.enabled: true
                layer.effect: DropShadow { horizontalOffset: 0; verticalOffset: 3; radius: 16; samples: 33; color: Qt.rgba(0,0,0,0.5) }
                Timer { interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm") }
            }

            Text {
                id: dateText
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(new Date(), "dddd, d MMMM")
                font.pixelSize: 22; font.weight: Font.Normal; color: root.colOnSurface
                layer.enabled: true
                layer.effect: DropShadow { horizontalOffset: 0; verticalOffset: 1; radius: 8; samples: 17; color: Qt.rgba(0,0,0,0.4) }
                Timer { interval: 60000; running: true; repeat: true
                    onTriggered: dateText.text = Qt.formatDate(new Date(), "dddd, d MMMM") }
            }
        }

        Text {
            id: hintText
            anchors.bottom: parent.bottom; anchors.bottomMargin: 40
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Press any key or click to login"
            font.pixelSize: 15; color: root.colOnSurfaceVariant
            opacity: hintOpacity
            property real hintOpacity: 0.7
            layer.enabled: true
            layer.effect: DropShadow { horizontalOffset: 0; verticalOffset: 1; radius: 4; samples: 9; color: Qt.rgba(0,0,0,0.3) }
            Behavior on hintOpacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            Timer { interval: 4000; running: clockView.visible; onTriggered: hintText.hintOpacity = 0 }
            Connections {
                target: clockView
                function onVisibleChanged() {
                    if (clockView.visible) { hintText.hintOpacity = 0.7 }
                }
            }
        }
    }

    // ── LOGIN VIEW ─────────────────────────────────────────────────────────
    Item {
        id: loginView
        anchors.fill: parent
        opacity: root.showLoginView ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: loginContent
            anchors.centerIn: parent
            spacing: 16
            property real animProgress: root.showLoginView ? 1 : 0
            Behavior on animProgress { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

            // Avatar (100×100 + accent ring) — matches LockSurface exactly
            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 100; height: 100
                opacity: Math.min(1, loginContent.animProgress * 3)
                scale: 0.8 + 0.2 * Math.min(1, loginContent.animProgress * 3)
                Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }

                Rectangle {
                    anchors.centerIn: parent; width: 108; height: 108; radius: width / 2
                    color: "transparent"; border.color: root.colPrimary; border.width: 3; opacity: 0.8
                    layer.enabled: true
                    layer.effect: DropShadow { horizontalOffset: 0; verticalOffset: 4; radius: 16; samples: 33; color: Qt.rgba(0,0,0,0.4) }
                }

                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: Qt.rgba(root.colSurface.r, root.colSurface.g, root.colSurface.b, 0.95); clip: true
                    // Avatar fallback chain: SDDM icon → AccountsService → ~/.face → initial letter
                    Image {
                        id: avatarImg1
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                        asynchronous: true; cache: true; smooth: true; mipmap: true
                        sourceSize.width: 200; sourceSize.height: 200
                        source: root.makeFileUrl(root._avatarPath1)
                        visible: status === Image.Ready
                    }
                    Image {
                        id: avatarImg2
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                        asynchronous: true; cache: true; smooth: true; mipmap: true
                        sourceSize.width: 200; sourceSize.height: 200
                        source: avatarImg1.status !== Image.Ready ? root.makeFileUrl(root._avatarPath2) : ""
                        visible: status === Image.Ready && avatarImg1.status !== Image.Ready
                    }
                    Image {
                        id: avatarImg3
                        anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                        asynchronous: true; cache: true; smooth: true; mipmap: true
                        sourceSize.width: 200; sourceSize.height: 200
                        source: avatarImg1.status !== Image.Ready && avatarImg2.status !== Image.Ready
                            ? root.makeFileUrl(root._avatarPath3) : ""
                        visible: status === Image.Ready && avatarImg1.status !== Image.Ready && avatarImg2.status !== Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        text: (root.currentUserName || root.currentUserLogin || "?").charAt(0).toUpperCase()
                        font.pixelSize: 40; font.weight: Font.Medium; color: root.colOnSurface
                        visible: avatarImg1.status !== Image.Ready && avatarImg2.status !== Image.Ready && avatarImg3.status !== Image.Ready
                    }
                }
            }

            // Username with stagger Y — matches LockSurface exactly
            Text {
                Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8
                text: root.currentUserName || root.currentUserLogin
                font.pixelSize: 22; font.weight: Font.Medium; color: root.colOnSurface
                opacity: Math.min(1, Math.max(0, loginContent.animProgress * 3 - 0.3))
                transform: Translate { y: (1 - Math.min(1, Math.max(0, loginContent.animProgress * 3 - 0.3))) * 15 }
                layer.enabled: true
                layer.effect: DropShadow { horizontalOffset: 0; verticalOffset: 1; radius: 6; samples: 13; color: Qt.rgba(0,0,0,0.4) }
            }

            // Password pill (300×52) with stagger Y + shake X — matches LockSurface exactly
            Rectangle {
                id: passwordPill
                Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 12
                width: 300; height: 52; radius: height / 2
                color: Qt.rgba(root.colSurface.r, root.colSurface.g, root.colSurface.b, 0.85)
                border.color: root.loginFailed ? root.colError
                    : (passwordBox.activeFocus ? root.colPrimary
                    : Qt.rgba(root.colOnSurface.r, root.colOnSurface.g, root.colOnSurface.b, 0.3))
                border.width: passwordBox.activeFocus ? 2 : 1
                opacity: Math.min(1, Math.max(0, loginContent.animProgress * 3 - 0.5))
                property real staggerY: (1 - Math.min(1, Math.max(0, loginContent.animProgress * 3 - 0.5))) * 20
                property real shakeOffset: 0
                transform: Translate { x: passwordPill.shakeOffset; y: passwordPill.staggerY }
                layer.enabled: true
                layer.effect: DropShadow { horizontalOffset: 0; verticalOffset: 4; radius: 12; samples: 25; color: Qt.rgba(0,0,0,0.3) }

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: passwordPill; property: "shakeOffset"; to: -20; duration: 50 }
                    NumberAnimation { target: passwordPill; property: "shakeOffset"; to:  20; duration: 50 }
                    NumberAnimation { target: passwordPill; property: "shakeOffset"; to: -10; duration: 40 }
                    NumberAnimation { target: passwordPill; property: "shakeOffset"; to:  10; duration: 40 }
                    NumberAnimation { target: passwordPill; property: "shakeOffset"; to:   0; duration: 30 }
                }

                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 8; spacing: 8

                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.loginFailed ? "Incorrect password" : "Password"
                            font.pixelSize: 16
                            color: root.loginFailed ? root.colError : root.colOnSurfaceVariant
                            visible: passwordBox.text.length === 0
                        }

                        PixelDots {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            dotCount: passwordBox.text.length
                            dotColor: root.colOnSurface; animColor: root.colPrimary
                            visible: passwordBox.text.length > 0
                        }

                        TextInput {
                            id: passwordBox
                            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                            echoMode: TextInput.Password; color: "transparent"
                            inputMethodHints: Qt.ImhSensitiveData
                            enabled: !root.loginInProgress; focus: true
                            onTextChanged: root.loginFailed = false
                            Keys.onReturnPressed: root.attemptLogin()
                            Keys.onEnterPressed:  root.attemptLogin()
                            Keys.onEscapePressed: {
                                if (passwordBox.text.length > 0) passwordBox.text = ""
                                else root.currentView = "clock"
                            }
                        }
                    }

                    Rectangle {
                        id: submitButton
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: submitMouse.pressed ? Qt.darker(root.colPrimary, 1.2)
                             : submitMouse.containsMouse ? Qt.lighter(root.colPrimary, 1.1)
                             : root.colPrimary
                        Behavior on color { ColorAnimation { duration: 120 } }

                        MSymbol {
                            anchors.centerIn: parent
                            text: root.loginInProgress ? "progress_activity" : "arrow_forward"
                            iconSize: 20; iconColor: root.colOnPrimary; symFont: root.symFont()
                            RotationAnimation on rotation {
                                running: root.loginInProgress; loops: Animation.Infinite
                                from: 0; to: 360; duration: 1000
                            }
                        }
                        MouseArea {
                            id: submitMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; enabled: !root.loginInProgress
                            onClicked: root.attemptLogin()
                        }
                    }
                }
            }
        }

        // Bottom-right: keyboard toggle + power buttons (symmetric with bottom-left)
        Row {
            anchors.bottom: parent.bottom; anchors.right: parent.right
            anchors.bottomMargin: 24; anchors.rightMargin: 24
            spacing: 8

            LockIconButton { icon: "keyboard"; tooltip: "Virtual keyboard"; toggled: root.keyboardOpen
                onClicked: root.keyboardOpen = !root.keyboardOpen }
            LockIconButton { icon: "dark_mode";          tooltip: "Sleep";      enabled: sddm.canSuspend;  onClicked: sddm.suspend() }
            LockIconButton { icon: "power_settings_new"; tooltip: "Shut down";  enabled: sddm.canPowerOff; onClicked: sddm.powerOff() }
            LockIconButton { icon: "restart_alt";        tooltip: "Restart";    enabled: sddm.canReboot;   onClicked: sddm.reboot() }
        }

        // Bottom-left: session selector only (keyboard moved to bottom-right for symmetry)
        MouseArea {
            anchors.bottom: parent.bottom; anchors.left: parent.left
            anchors.bottomMargin: 34; anchors.leftMargin: 30
            visible: sessionModel.count > 0
            width: sessionRow.implicitWidth + 8; height: sessionRow.implicitHeight + 8
            onClicked: if (sessionModel.count > 1)
                root.currentSessionIndex = (root.currentSessionIndex + 1) % sessionModel.count
            cursorShape: sessionModel.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor

            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 6
                MSymbol { text: "desktop_windows"; iconSize: 16; iconColor: root.colOnSurfaceVariant; opacity: 0.7; symFont: root.symFont() }
                Text {
                    text: root.currentSessionName
                    font.pixelSize: 13; color: root.colOnSurfaceVariant; opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }
                MSymbol {
                    text: "chevron_right"; iconSize: 14; iconColor: root.colOnSurfaceVariant; opacity: 0.5
                    symFont: root.symFont()
                    visible: sessionModel.count > 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ── VIRTUAL KEYBOARD ───────────────────────────────────────────────────
    VirtualKeyboard {
        id: virtualKeyboard
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        anchors.bottomMargin: 8; anchors.leftMargin: 24; anchors.rightMargin: 24
        visible: root.keyboardOpen
        bgColor: root.colSurfaceContainer
        btnColor: Qt.lighter(root.colSurfaceContainer, 1.3)
        funcBgColor: root.colSurface
        accentColor: root.colPrimary
        accentTextColor: root.colOnPrimary
        textColor: root.colOnSurface
        onKeyClicked: function(key) { passwordBox.text += key; passwordBox.forceActiveFocus() }
        onBackspaceClicked: { if (passwordBox.text.length > 0) passwordBox.text = passwordBox.text.slice(0, -1); passwordBox.forceActiveFocus() }
        onEnterClicked: root.attemptLogin()
        onCloseRequested: root.keyboardOpen = false
    }

    // ── INPUT HANDLING — matches LockSurface logic exactly ─────────────────
    onClicked: function(mouse) {
        if (!root.showLoginView) root.switchToLogin(null)
        else passwordBox.forceActiveFocus()
    }
    onPositionChanged: { if (root.showLoginView) passwordBox.forceActiveFocus() }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.keyboardOpen) { root.keyboardOpen = false; return }
            if (passwordBox.text.length > 0) passwordBox.text = ""
            else if (root.showLoginView) root.currentView = "clock"
            return
        }
        if (!root.showLoginView) {
            root.switchToLogin(event.text)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (passwordBox.text.length > 0) root.attemptLogin()
            event.accepted = true
            return
        }
        if (!passwordBox.activeFocus) passwordBox.forceActiveFocus()
    }

    Component.onCompleted: {
        root.currentView = "clock"
        Qt.callLater(function() { root.forceActiveFocus() })
    }

    // ── LockIconButton — matches LockSurface component exactly ─────────────
    component LockIconButton: Rectangle {
        id: lockBtn
        required property string icon
        property string tooltip: ""
        property bool toggled: false
        signal clicked()

        width: 44; height: 44; radius: 12
        color: {
            if (!enabled) return Qt.rgba(root.colSurface.r, root.colSurface.g, root.colSurface.b, 0.2)
            if (toggled)  return root.colPrimary
            if (lockBtnMouse.pressed)       return Qt.rgba(root.colOnSurface.r, root.colOnSurface.g, root.colOnSurface.b, 0.3)
            if (lockBtnMouse.containsMouse) return Qt.rgba(root.colOnSurface.r, root.colOnSurface.g, root.colOnSurface.b, 0.15)
            return Qt.rgba(root.colSurface.r, root.colSurface.g, root.colSurface.b, 0.3)
        }
        opacity: enabled ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: 150 } }
        layer.enabled: true
        layer.effect: DropShadow { horizontalOffset: 0; verticalOffset: 2; radius: 8; samples: 17; color: Qt.rgba(0,0,0,0.3) }

        MSymbol {
            anchors.centerIn: parent; text: lockBtn.icon; iconSize: 22
            iconColor: lockBtn.toggled ? root.colOnPrimary : root.colOnSurface
            symFont: root.symFont()
        }
        MouseArea {
            id: lockBtnMouse; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor; onClicked: lockBtn.clicked()
        }
        Rectangle {
            visible: lockBtnMouse.containsMouse && lockBtn.tooltip.length > 0
            anchors.bottom: parent.top; anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(root.colSurface.r, root.colSurface.g, root.colSurface.b, 0.95)
            border.color: Qt.rgba(root.colOnSurface.r, root.colOnSurface.g, root.colOnSurface.b, 0.2)
            border.width: 1; radius: 6
            width: tipLabel.implicitWidth + 16; height: tipLabel.implicitHeight + 10
            z: 99
            Text { id: tipLabel; anchors.centerIn: parent; text: lockBtn.tooltip
                font.pixelSize: 12; color: root.colOnSurface }
        }
    }
}
