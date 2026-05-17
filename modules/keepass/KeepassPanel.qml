pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell:keepass"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: KeePass.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true

    // Always-mapped surface: input gated by mask, never by visibility.
    // Avoids Qt6 physicalDpiChanged infinite recursion on Hyprland surface remap.
    mask: Region { item: KeePass.open ? backdropClickArea : noInputItem }

    Connections {
        target: KeePass
        function onOpenChanged() {
            if (KeePass.open) panelColumn.focusDefault()
        }
    }

    Item { id: noInputItem; width: 0; height: 0 }

    // Click outside the panel to close
    MouseArea {
        id: backdropClickArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: mouse => {
            const pos = mapToItem(panelBackground, mouse.x, mouse.y)
            const outside = pos.x < 0 || pos.x > panelBackground.width
                         || pos.y < 0 || pos.y > panelBackground.height
            if (outside) KeePass.close()
            else mouse.accepted = false
        }
    }

    StyledRectangularShadow {
        target: panelBackground
        radius: panelBackground.radius
        visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
        opacity: panelBackground.opacity
    }

    GlassBackground {
        id: panelBackground
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Appearance.sizes.elevationMargin
        width: 600
        height: panelColumn.implicitHeight + 24
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingLarge
              : Appearance.inirEverywhere  ? Appearance.inir.roundingLarge
              : Appearance.rounding.screenRounding
        fallbackColor: Appearance.colors.colLayer1
        inirColor: Appearance.inir.colLayer1
        auroraTransparency: Appearance.angelEverywhere
            ? Appearance.angel.panelTransparentize
            : Math.max(0.12, Appearance.aurora.subSurfaceTransparentize - 0.14)
        border.width: 1
        border.color: Appearance.angelEverywhere ? Appearance.angel.colPanelBorder
                    : Appearance.inirEverywhere  ? Appearance.inir.colBorder
                    : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : Appearance.colors.colOutlineVariant
        screenX: (root.screen?.width ?? 1920) / 2 - width / 2
        screenY: Appearance.sizes.elevationMargin
        screenWidth: root.screen?.width ?? 1920
        screenHeight: root.screen?.height ?? 1080

        opacity: KeePass.open ? 1 : 0
        scale: KeePass.open ? 1 : 0.97

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        // Shared tokens for inner section cards — defined once to avoid 50+ repeated ternaries
        readonly property color sectionColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                            : Appearance.inirEverywhere  ? Appearance.inir.colLayer2
                                            : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                            : Appearance.colors.colLayer1
        readonly property color sectionBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                                             : Appearance.inirEverywhere  ? Appearance.inir.colBorder
                                             : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
                                             : Appearance.colors.colOutlineVariant
        readonly property real sectionRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                                            : Appearance.inirEverywhere  ? Appearance.inir.roundingNormal
                                            : Appearance.rounding.windowRounding

        ColumnLayout {
            id: panelColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            focus: KeePass.open

            property bool showVaultPicker: !KeePass.vaultExists
            onShowVaultPickerChanged: focusDefault()

            Connections {
                target: KeePass
                function onVaultExistsChanged() {
                    if (KeePass.vaultExists) panelColumn.showVaultPicker = false
                }
                function onOpenChanged() {
                    if (!KeePass.open) panelColumn.showVaultPicker = !KeePass.vaultExists
                }
            }

            function focusDefault() {
                if (!KeePass.open) return
                if (showVaultPicker) {
                    if (KeePass.availableVaults.length > 0)
                        Qt.callLater(() => vaultPickerList.forceActiveFocus())
                    else
                        Qt.callLater(() => panelColumn.forceActiveFocus())
                    return
                }
                if (!KeePass.unlocked) {
                    Qt.callLater(() => unlockPassword.forceActiveFocus())
                    return
                }
                if (KeePass.addMode) {
                    Qt.callLater(() => panelColumn.forceActiveFocus())
                    return
                }
                Qt.callLater(() => filterField.forceActiveFocus())
            }

            function cycleTab(direction) {
                if (!KeePass.unlocked) return
                const current = showVaultPicker ? 0 : (KeePass.addMode ? 2 : 1)
                const next = (current + direction + 3) % 3
                if (next === 0) {
                    showVaultPicker = true
                } else if (next === 1) {
                    showVaultPicker = false
                    KeePass.addMode = false
                } else {
                    showVaultPicker = false
                    KeePass.addMode = true
                }
            }

            Connections {
                target: KeePass
                // Re-focus vault list once the async scan populates availableVaults.
                // focusDefault() runs before the scan finishes (list is empty at that
                // point) so it falls back to panelColumn. This corrects it.
                function onAvailableVaultsChanged() {
                    if (KeePass.open && panelColumn.showVaultPicker && KeePass.availableVaults.length > 0)
                        Qt.callLater(() => vaultPickerList.forceActiveFocus())
                }
                function onUnlockedChanged() {
                    panelColumn.focusDefault()
                    if (KeePass.unlocked && KeePass.addMode && KeePass.pendingPassword.length > 0) {
                        addPassword.text = KeePass.pendingPassword
                        KeePass.pendingPassword = ""
                        addPanel.addPasswordVisible = true
                    }
                }
                function onAddModeChanged() {
                    panelColumn.focusDefault()
                    if (KeePass.addMode && KeePass.unlocked && KeePass.pendingPassword.length > 0) {
                        addPassword.text = KeePass.pendingPassword
                        KeePass.pendingPassword = ""
                        addPanel.addPasswordVisible = true
                    }
                }
                function onGeneratedPasswordChanged() {
                    if (KeePass.generatedPassword.length > 0) {
                        addPassword.text = KeePass.generatedPassword
                        addPanel.addPasswordVisible = true
                        KeePass.generatedPassword = ""
                    }
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (KeePass.selectedEntry.length > 0) KeePass.openEntry("")
                    else KeePass.close()
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    panelColumn.cycleTab(event.key === Qt.Key_Right ? 1 : -1)
                    event.accepted = true
                    return
                }
                if (event.key === Qt.Key_Alt && !event.isAutoRepeat
                    && KeePass.unlocked && KeePass.selectedEntry.length > 0) {
                    if (!KeePass.reveal) KeePass.showPassword()
                    return
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (!KeePass.unlocked) {
                        KeePass.unlock(unlockPassword.text)
                        unlockPassword.text = ""
                        event.accepted = true
                    } else if (KeePass.addMode) {
                        KeePass.addEntry(addEntryName.text, addPassword.text, addUsername.text, addUrl.text)
                        addPanel.clearForm()
                        event.accepted = true
                    } else if (KeePass.selectedEntry.length > 0) {
                        KeePass.copyPassword()
                        event.accepted = true
                    }
                }
            }
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Alt) {
                    KeePass.reveal = false
                    KeePass.revealedPassword = ""
                }
            }

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                StyledText {
                    text: KeePass.addMode ? Translation.tr("KeePass - Save")
                        : KeePass.vaultExists ? Translation.tr("KeePass · %1").arg(KeePass.vaultName)
                        : Translation.tr("KeePass")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.angelEverywhere ? Appearance.angel.colText
                         : Appearance.inirEverywhere  ? Appearance.inir.colOnLayer1
                         : Appearance.colors.colOnLayer1
                }

                // Timer badge — click to reset
                RippleButton {
                    visible: KeePass.unlocked
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: timerLabel.implicitWidth + 12
                    buttonRadius: height / 2
                    activeFocusOnTab: false
                    colBackground: Appearance.inirEverywhere ? Appearance.inir.colLayer0 : Appearance.colors.colLayer1
                    onClicked: KeePass.remainingTime = KeePass.cacheTtl

                    contentItem: Item {
                        anchors.fill: parent

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            radius: height / 2
                            width: parent.width * (KeePass.remainingTime / Math.max(1, KeePass.cacheTtl))
                            color: KeePass.remainingTime < 30
                                ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                                : (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                            opacity: 0.2
                        }

                        StyledText {
                            id: timerLabel
                            anchors.centerIn: parent
                            text: "%1:%2".arg(Math.floor(KeePass.remainingTime / 60)).arg((KeePass.remainingTime % 60).toString().padStart(2, '0'))
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Bold
                            color: KeePass.remainingTime < 30
                                ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                                : (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // ── Nav: Browse entries ──────────────────────────────────────
                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.full
                    activeFocusOnTab: false
                    enabled: KeePass.vaultExists && KeePass.unlocked
                    opacity: enabled ? 1.0 : 0.3
                    colBackground: (KeePass.vaultExists && KeePass.unlocked && !panelColumn.showVaultPicker && !KeePass.addMode)
                        ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                        : "transparent"
                    onClicked: { panelColumn.showVaultPicker = false; KeePass.addMode = false }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "key"
                        iconSize: Appearance.font.pixelSize.larger
                        color: (KeePass.vaultExists && KeePass.unlocked && !panelColumn.showVaultPicker && !KeePass.addMode)
                            ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                            : (Appearance.inirEverywhere ? Appearance.inir.colOnLayer1 : Appearance.colors.colOnLayer1)
                    }
                }

                // ── Nav: Add entry ───────────────────────────────────────────
                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.full
                    activeFocusOnTab: false
                    enabled: KeePass.vaultExists && KeePass.unlocked
                    opacity: enabled ? 1.0 : 0.3
                    colBackground: (KeePass.vaultExists && KeePass.unlocked && !panelColumn.showVaultPicker && KeePass.addMode)
                        ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                        : "transparent"
                    onClicked: { panelColumn.showVaultPicker = false; KeePass.addMode = true }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "edit_note"
                        iconSize: Appearance.font.pixelSize.larger
                        color: (KeePass.vaultExists && KeePass.unlocked && !panelColumn.showVaultPicker && KeePass.addMode)
                            ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                            : (Appearance.inirEverywhere ? Appearance.inir.colOnLayer1 : Appearance.colors.colOnLayer1)
                    }
                }

                // ── Nav: Vault selector ──────────────────────────────────────
                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.full
                    activeFocusOnTab: false
                    colBackground: panelColumn.showVaultPicker
                        ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                        : "transparent"
                    onClicked: panelColumn.showVaultPicker = !panelColumn.showVaultPicker
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "folder_open"
                        iconSize: Appearance.font.pixelSize.larger
                        color: panelColumn.showVaultPicker
                            ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                            : (Appearance.inirEverywhere ? Appearance.inir.colOnLayer1 : Appearance.colors.colOnLayer1)
                    }
                }

                RippleButton {
                    implicitWidth: 34
                    implicitHeight: 34
                    buttonRadius: Appearance.rounding.full
                    activeFocusOnTab: false
                    colBackground: "transparent"
                    onClicked: if (KeePass.unlocked) KeePass.lock()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: KeePass.unlocked ? "lock_open" : "lock"
                        iconSize: Appearance.font.pixelSize.larger
                        color: KeePass.unlocked
                            ? Appearance.m3colors.m3tertiary
                            : (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                    }
                }
                IconToolbarButton {
                    text: "close"
                    activeFocusOnTab: false
                    onClicked: KeePass.close()
                }
            }

            // ── Unavailable banner ───────────────────────────────────────────
            Rectangle {
                visible: !KeePass.available
                Layout.fillWidth: true
                implicitHeight: unavailableColumn.implicitHeight + 16
                radius: panelBackground.sectionRadius
                color: panelBackground.sectionColor
                border.color: panelBackground.sectionBorder

                ColumnLayout {
                    id: unavailableColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    StyledText {
                        text: Translation.tr("keepassxc-cli not found")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Install the keepassxc package to use this feature.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.WordWrap
                        color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOnSurfaceVariant
                    }
                }
            }

            // ── Vault picker ─────────────────────────────────────────────────
            Rectangle {
                visible: KeePass.available && panelColumn.showVaultPicker && !KeePass.busy
                Layout.fillWidth: true
                implicitHeight: vaultPickerColumn.implicitHeight + 16
                radius: panelBackground.sectionRadius
                color: panelBackground.sectionColor
                border.color: panelBackground.sectionBorder

                ColumnLayout {
                    id: vaultPickerColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    ColumnLayout {
                        visible: KeePass.availableVaults.length > 0
                        Layout.fillWidth: true
                        spacing: 4

                        StyledText {
                            text: Translation.tr("Select a vault")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.angelEverywhere ? Appearance.angel.colText
                                 : Appearance.inirEverywhere  ? Appearance.inir.colOnLayer1
                                 : Appearance.colors.colOnLayer1
                        }

                        ListView {
                            id: vaultPickerList
                            Layout.fillWidth: true
                            implicitHeight: Math.min(260, contentHeight + 8)
                            clip: true
                            spacing: 4
                            model: KeePass.availableVaults
                            keyNavigationEnabled: false
                            currentIndex: 0

                            highlightFollowsCurrentItem: true
                            highlightMoveDuration: 0
                            highlight: Rectangle {
                                width: vaultPickerList.width
                                height: 36
                                radius: height / 2
                                color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                            }

                            delegate: DialogListItem {
                                id: vaultDelegate
                                required property string modelData
                                readonly property bool isSelected: modelData === KeePass.vaultPath
                                width: vaultPickerList.width
                                implicitHeight: 36
                                active: ListView.isCurrentItem
                                focus: false
                                activeFocusOnTab: false
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover : Appearance.colors.colLayer1Hover
                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    MaterialSymbol {
                                        text: (vaultDelegate.isSelected && KeePass.unlocked) ? "lock_open" : "lock"
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: vaultDelegate.active
                                            ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                                            : vaultDelegate.isSelected
                                                ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                                                : (Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOnSurfaceVariant)
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.substring(modelData.lastIndexOf("/") + 1)
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: vaultDelegate.active
                                            ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                                            : vaultDelegate.isSelected
                                                ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                                                : (Appearance.inirEverywhere ? Appearance.inir.colOnLayer1 : Appearance.colors.colOnLayer1)
                                        elide: Text.ElideRight
                                    }
                                }
                                onClicked: {
                                    KeePass.selectVault(modelData)
                                    panelColumn.showVaultPicker = false
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Down) {
                                    currentIndex = Math.min(count - 1, currentIndex + 1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up) {
                                    currentIndex = Math.max(0, currentIndex - 1)
                                    event.accepted = true
                                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && currentIndex >= 0 && count > 0) {
                                    KeePass.selectVault(model[currentIndex])
                                    panelColumn.showVaultPicker = false
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                    panelColumn.cycleTab(event.key === Qt.Key_Right ? 1 : -1)
                                    event.accepted = true
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colOutlineVariant
                            opacity: 0.5
                        }
                    }

                    StyledText {
                        text: Translation.tr("Create new vault")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.angelEverywhere ? Appearance.angel.colText
                             : Appearance.inirEverywhere  ? Appearance.inir.colOnLayer1
                             : Appearance.colors.colOnLayer1
                    }

                    ToolbarTextField {
                        id: newVaultName
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Vault name (e.g. personal)")
                    }

                    ToolbarTextField {
                        id: newVaultPassword
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Password")
                        echoMode: TextInput.Password
                    }

                    ToolbarTextField {
                        id: newVaultConfirm
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Confirm password")
                        echoMode: TextInput.Password
                        onAccepted: {
                            if (newVaultConfirm.text !== newVaultPassword.text) {
                                KeePass.lastError = Translation.tr("Passwords do not match")
                                return
                            }
                            KeePass.createVault(newVaultName.text, newVaultPassword.text)
                            newVaultName.text = ""
                            newVaultPassword.text = ""
                            newVaultConfirm.text = ""
                        }
                    }

                    RowLayout {
                        spacing: 8
                        DialogButton {
                            buttonText: Translation.tr("Create")
                            activeFocusOnTab: false
                            buttonRadius: height / 2
                            onClicked: {
                                if (newVaultConfirm.text !== newVaultPassword.text) {
                                    KeePass.lastError = Translation.tr("Passwords do not match")
                                    return
                                }
                                KeePass.createVault(newVaultName.text, newVaultPassword.text)
                                newVaultName.text = ""
                                newVaultPassword.text = ""
                                newVaultConfirm.text = ""
                            }
                        }
                        DialogButton {
                            buttonText: Translation.tr("Cancel")
                            activeFocusOnTab: false
                            buttonRadius: height / 2
                            onClicked: KeePass.close()
                        }
                    }
                }
            }

            // ── Unlock panel ─────────────────────────────────────────────────
            Rectangle {
                visible: KeePass.available && !panelColumn.showVaultPicker && KeePass.vaultExists && !KeePass.unlocked
                Layout.fillWidth: true
                implicitHeight: unlockColumn.implicitHeight + 16
                radius: panelBackground.sectionRadius
                color: panelBackground.sectionColor
                border.color: panelBackground.sectionBorder

                ColumnLayout {
                    id: unlockColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    ToolbarTextField {
                        id: unlockPassword
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Vault password")
                        echoMode: TextInput.Password
                        onAccepted: { KeePass.unlock(text); text = "" }
                    }

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        StyledText {
                            text: KeePass.unlocked
                                ? Translation.tr("Time left: %1:%2").arg(Math.floor(KeePass.remainingTime / 60)).arg((KeePass.remainingTime % 60).toString().padStart(2, '0'))
                                : Translation.tr("Stay unlocked: %1 min").arg(Math.floor(KeePass.cacheTtl / 60))
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                                 : Appearance.inirEverywhere  ? Appearance.inir.colTextSecondary
                                 : Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    Slider {
                        id: ttlSlider
                        Layout.fillWidth: true
                        from: 60
                        to: 14400
                        stepSize: 60
                        value: KeePass.cacheTtl
                        onMoved: KeePass.cacheTtl = value

                        background: Rectangle {
                            x: ttlSlider.leftPadding
                            y: ttlSlider.topPadding + ttlSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200
                            implicitHeight: 4
                            width: ttlSlider.availableWidth
                            height: implicitHeight
                            radius: 2
                            color: Appearance.inirEverywhere ? Appearance.inir.colLayer0 : Appearance.colors.colLayer1

                            Rectangle {
                                width: ttlSlider.visualPosition * parent.width
                                height: parent.height
                                color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                                radius: 2
                            }
                        }

                        handle: Rectangle {
                            x: ttlSlider.leftPadding + ttlSlider.visualPosition * (ttlSlider.availableWidth - width)
                            y: ttlSlider.topPadding + ttlSlider.availableHeight / 2 - height / 2
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                            border.color: Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
                            border.width: 1
                        }
                    }

                    RowLayout {
                        spacing: 8
                        DialogButton {
                            buttonText: Translation.tr("Unlock")
                            activeFocusOnTab: false
                            onClicked: { KeePass.unlock(unlockPassword.text); unlockPassword.text = "" }
                        }
                        DialogButton {
                            buttonText: Translation.tr("Cancel")
                            activeFocusOnTab: false
                            onClicked: KeePass.close()
                        }
                    }
                }
            }

            // ── Error ────────────────────────────────────────────────────────
            StyledText {
                visible: KeePass.lastError.length > 0
                text: KeePass.lastError
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
            }

            // ── Entry list & detail ──────────────────────────────────────────
            ColumnLayout {
                visible: KeePass.available && !panelColumn.showVaultPicker && KeePass.vaultExists && KeePass.unlocked && !KeePass.addMode
                spacing: 8

                ToolbarTextField {
                    id: filterField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Search entries")
                    onTextChanged: KeePass.filter = text
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            entryList.forceActiveFocus()
                            event.accepted = true
                        }
                    }
                }

                ListView {
                    id: entryList
                    Layout.fillWidth: true
                    implicitHeight: Math.min(420, contentHeight + 8)
                    clip: true
                    spacing: 4
                    model: KeePass.filteredEntries(KeePass.filter)
                    keyNavigationEnabled: false
                    currentIndex: 0

                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 0
                    highlight: Rectangle {
                        width: entryList.width
                        height: 36
                        radius: height / 2
                        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                    }

                    delegate: DialogListItem {
                        id: listDelegate
                        required property var modelData
                        width: entryList.width
                        implicitHeight: 36
                        active: ListView.isCurrentItem
                        focus: false
                        activeFocusOnTab: false
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover : Appearance.colors.colLayer1Hover

                        contentItem: StyledText {
                            text: modelData
                            font.pixelSize: Appearance.font.pixelSize.small
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: Text.AlignVCenter
                            color: listDelegate.active
                                ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                                : (Appearance.inirEverywhere ? Appearance.inir.colOnLayer1 : Appearance.colors.colOnLayer1)
                            elide: Text.ElideRight
                        }
                        onClicked: KeePass.openEntry(modelData)
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            currentIndex = Math.min(count - 1, currentIndex + 1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (currentIndex <= 0) filterField.forceActiveFocus()
                            else currentIndex = Math.max(0, currentIndex - 1)
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && currentIndex >= 0) {
                            const entry = model[currentIndex]
                            if (KeePass.selectedEntry === entry) KeePass.copyPassword()
                            else KeePass.openEntry(entry)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                            panelColumn.cycleTab(event.key === Qt.Key_Right ? 1 : -1)
                            event.accepted = true
                        } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 0x20) {
                            filterField.forceActiveFocus()
                            filterField.text += event.text
                            filterField.cursorPosition = filterField.text.length
                            event.accepted = true
                        }
                    }
                }

                // Entry detail card
                Rectangle {
                    visible: KeePass.selectedEntry.length > 0
                    Layout.fillWidth: true
                    implicitHeight: detailColumn.implicitHeight + 16
                    radius: panelBackground.sectionRadius
                    color: panelBackground.sectionColor
                    border.color: panelBackground.sectionBorder

                    ColumnLayout {
                        id: detailColumn
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: KeePass.selectedEntry
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                     : Appearance.inirEverywhere  ? Appearance.inir.colOnLayer1
                                     : Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                            RippleButton {
                                implicitWidth: 28
                                implicitHeight: 28
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                onClicked: KeePass.openEntry("")
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                                         : Appearance.inirEverywhere  ? Appearance.inir.colTextSecondary
                                         : Appearance.colors.colOnSurfaceVariant
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Appearance.rounding.full
                            color: Appearance.angelEverywhere  ? Appearance.angel.colGlassPanel
                                 : Appearance.inirEverywhere   ? Appearance.inir.colLayer0
                                 : Appearance.auroraEverywhere ? Appearance.aurora.colOverlay
                                 : Appearance.colors.colLayer0
                            border.color: Appearance.angelEverywhere  ? Appearance.angel.colCardBorder
                                        : Appearance.inirEverywhere   ? Appearance.inir.colBorder
                                        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
                                        : Appearance.colors.colLayer0Border

                            TextEdit {
                                anchors.centerIn: parent
                                text: KeePass.reveal ? KeePass.revealedPassword : "••••••••••"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                     : Appearance.inirEverywhere  ? Appearance.inir.colOnLayer0
                                     : Appearance.colors.colOnLayer0
                                selectByMouse: true
                                readOnly: true
                                wrapMode: TextEdit.NoWrap
                            }
                        }

                        RowLayout {
                            spacing: 8
                            DialogButton {
                                buttonText: KeePass.reveal ? Translation.tr("Hide") : Translation.tr("Show")
                                activeFocusOnTab: false
                                buttonRadius: height / 2
                                onClicked: {
                                    if (KeePass.reveal) { KeePass.reveal = false; KeePass.revealedPassword = "" }
                                    else KeePass.showPassword()
                                }
                            }
                            DialogButton {
                                buttonText: Translation.tr("Copy Password")
                                activeFocusOnTab: false
                                buttonRadius: height / 2
                                onClicked: KeePass.copyPassword()
                            }
                            DialogButton {
                                buttonText: Translation.tr("Copy Username")
                                activeFocusOnTab: false
                                buttonRadius: height / 2
                                onClicked: KeePass.copyUsername()
                            }
                        }
                    }
                }
            }

            // ── Add entry panel ──────────────────────────────────────────────
            ColumnLayout {
                id: addPanel
                visible: KeePass.available && !panelColumn.showVaultPicker && KeePass.vaultExists && KeePass.unlocked && KeePass.addMode
                spacing: 8

                property bool addPasswordVisible: false
                property int genLength: 20
                property bool genUppercase: true
                property bool genNumbers: true
                property bool genSymbols: true
                property bool genWords: false

                function clearForm() {
                    addEntryName.text  = ""
                    addUsername.text   = ""
                    addUrl.text        = ""
                    addPassword.text   = ""
                    addPasswordVisible = false
                }

                ToolbarTextField { id: addEntryName; Layout.fillWidth: true; placeholderText: Translation.tr("Entry name (e.g. Email/GitHub)") }
                ToolbarTextField { id: addUsername;  Layout.fillWidth: true; placeholderText: Translation.tr("Username (optional)") }
                ToolbarTextField { id: addUrl;       Layout.fillWidth: true; placeholderText: Translation.tr("URL (optional)") }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    ToolbarTextField {
                        id: addPassword
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Password")
                        echoMode: addPanel.addPasswordVisible ? TextInput.Normal : TextInput.Password
                        onAccepted: {
                            KeePass.addEntry(addEntryName.text, text, addUsername.text, addUrl.text)
                            addPanel.clearForm()
                        }
                    }
                    RippleButton {
                        implicitWidth: 34; implicitHeight: 34
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        onClicked: addPanel.addPasswordVisible = !addPanel.addPasswordVisible
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: addPanel.addPasswordVisible ? "visibility_off" : "visibility"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.angelEverywhere ? Appearance.angel.colText
                                 : Appearance.inirEverywhere  ? Appearance.inir.colOnLayer1
                                 : Appearance.colors.colOnLayer1
                        }
                    }
                    DialogButton {
                        buttonText: Translation.tr("Generate")
                        activeFocusOnTab: false
                        buttonRadius: height / 2
                        onClicked: KeePass.generate(addPanel.genLength, addPanel.genUppercase, addPanel.genNumbers, addPanel.genSymbols, addPanel.genWords)
                    }
                }

                RowLayout {
                    spacing: 4
                    StyledText {
                        text: Translation.tr("Len:")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                             : Appearance.inirEverywhere  ? Appearance.inir.colTextSecondary
                             : Appearance.colors.colOnSurfaceVariant
                    }
                    Repeater {
                        model: [8, 12, 20]
                        delegate: DialogButton {
                            id: lenBtn
                            required property int modelData
                            buttonText: modelData.toString()
                            activeFocusOnTab: false
                            buttonRadius: height / 2
                            toggled: addPanel.genLength === modelData
                            colBackgroundToggled: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                            contentItem: StyledText {
                                text: lenBtn.buttonText
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: lenBtn.toggled
                                    ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                                    : (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                            }
                            onClicked: addPanel.genLength = modelData
                        }
                    }
                    Item { implicitWidth: 8 }
                    Repeater {
                        model: [
                            { label: "A-Z",                  prop: "genUppercase" },
                            { label: "0-9",                  prop: "genNumbers"   },
                            { label: "!@#",                  prop: "genSymbols"   },
                            { label: Translation.tr("words"), prop: "genWords"     },
                        ]
                        delegate: DialogButton {
                            id: toggleBtn
                            required property var modelData
                            buttonText: modelData.label
                            activeFocusOnTab: false
                            buttonRadius: height / 2
                            toggled: addPanel[modelData.prop]
                            colBackgroundToggled: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                            contentItem: StyledText {
                                text: toggleBtn.buttonText
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: toggleBtn.toggled
                                    ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                                    : (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                            }
                            onClicked: addPanel[modelData.prop] = !addPanel[modelData.prop]
                        }
                    }
                }

                RowLayout {
                    spacing: 8
                    DialogButton {
                        buttonText: Translation.tr("Save")
                        activeFocusOnTab: false
                        buttonRadius: height / 2
                        onClicked: {
                            KeePass.addEntry(addEntryName.text, addPassword.text, addUsername.text, addUrl.text)
                            addPanel.clearForm()
                        }
                    }
                    DialogButton {
                        buttonText: Translation.tr("Cancel")
                        activeFocusOnTab: false
                        buttonRadius: height / 2
                        onClicked: KeePass.close()
                    }
                }
            }
        }
    }
}
