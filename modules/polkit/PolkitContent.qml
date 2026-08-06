pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root
    readonly property bool usePasswordChars: !(PolkitService.flow?.responseVisible ?? false)
    readonly property color authSurface: Appearance.cookieEverywhere
        ? Appearance.cookie.secondaryFace
        : Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer2
    readonly property color authBorder: Appearance.cookieEverywhere
        ? Appearance.cookie.borderColor
        : Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
        : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : Appearance.colors.colOutlineVariant
    readonly property int authRadius: Appearance.cookieEverywhere
        ? Appearance.cookie.roundNormal
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.rounding.small

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            PolkitService.cancel()
            event.accepted = true
        }
    }

    function submit(): void {
        PolkitService.submit(inputField.text)
    }

    Connections {
        target: PolkitService
        function onInteractionAvailableChanged(): void {
            if (!PolkitService.interactionAvailable)
                return
            inputField.text = ""
            inputField.forceActiveFocus()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity {
            animation: NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

    WindowDialog {
        id: dialog
        anchors.centerIn: parent
        backgroundWidth: 460
        zzzLabel: "AUTH"
        zzzIndex: "PK"
        zzzGhostText: "AUTH"
        zzzAccentColor: Appearance.zzz.secondary
        zzzShowTicks: true
        show: false
        Component.onCompleted: show = true

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.sizes.spacingLarge

            Rectangle {
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
                Layout.alignment: Qt.AlignTop
                radius: root.authRadius
                color: root.authSurface
                border.width: 1
                border.color: root.authBorder

                ZzzSurfaceAccent {
                    showSticker: true
                    cornerRadius: parent.radius
                }

                ZzzGlyphBadge {
                    anchors.centerIn: parent
                    visible: Appearance.zzzEverywhere
                    badgeSize: 34
                    symbol: PolkitService.batteryChargeLimitRequest ? "battery_saver" : "security"
                    accentColor: Appearance.zzz.secondary
                    inkColor: Appearance.zzz.onSecondary
                    filled: true
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !Appearance.zzzEverywhere
                    iconSize: 28
                    text: PolkitService.batteryChargeLimitRequest ? "battery_saver" : "security"
                    fill: 1
                    color: Appearance.colors.colSecondary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                WindowDialogTitle {
                    Layout.fillWidth: true
                    text: Appearance.zzzEverywhere
                        ? Translation.tr("Authentication").toUpperCase()
                        : Translation.tr("Authentication")
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: PolkitService.actionLabel !== Translation.tr("Authentication")
                    text: PolkitService.actionLabel
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSecondary
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: messageText.implicitHeight + Appearance.sizes.spacingLarge * 2
            radius: root.authRadius
            color: root.authSurface
            border.width: 1
            border.color: root.authBorder

            RowLayout {
                id: messageRow
                anchors.fill: parent
                anchors.margins: Appearance.sizes.spacingLarge
                spacing: Appearance.sizes.spacingMedium

                MaterialSymbol {
                    text: "admin_panel_settings"
                    iconSize: Appearance.font.pixelSize.larger
                    fill: 1
                    color: Appearance.colors.colSecondary
                    Layout.alignment: Qt.AlignTop
                }

                WindowDialogParagraph {
                    id: messageText
                    Layout.fillWidth: true
                    text: PolkitService.cleanMessage
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        MaterialTextField {
            id: inputField
            Layout.fillWidth: true
            focus: true
            enabled: PolkitService.interactionAvailable
            placeholderText: PolkitService.cleanPrompt
            echoMode: root.usePasswordChars ? TextInput.Password : TextInput.Normal
            onAccepted: root.submit()

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    PolkitService.cancel()
                    event.accepted = true
                }
            }
        }

        WindowDialogButtonRow {
            spacing: Appearance.sizes.spacingSmall

            Item { Layout.fillWidth: true }

            DialogButton {
                buttonText: Translation.tr("Cancel")
                onClicked: PolkitService.cancel()
            }

            DialogButton {
                enabled: PolkitService.interactionAvailable
                buttonText: Translation.tr("OK")
                colBackground: Appearance.zzzEverywhere
                    ? Appearance.zzz.secondary : Appearance.colors.colPrimary
                colBackgroundHover: Appearance.zzzEverywhere
                    ? ColorUtils.mix(Appearance.zzz.secondary, Appearance.zzz.onSecondary, 0.88)
                    : Appearance.colors.colPrimaryHover
                colRipple: Appearance.zzzEverywhere
                    ? Appearance.zzz.accentSoft : Appearance.colors.colPrimaryActive
                colText: Appearance.zzzEverywhere
                    ? Appearance.zzz.onSecondary : Appearance.colors.colOnPrimary
                onClicked: root.submit()
            }
        }
    }
}
