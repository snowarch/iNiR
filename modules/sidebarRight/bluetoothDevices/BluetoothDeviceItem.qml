import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property var device
    property bool expanded: false
    pointingHandCursor: !expanded

    onClicked: expanded = !expanded
    altAction: () => expanded = !expanded
    
    component ActionButton: DialogButton {
        colBackground: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover : Appearance.colors.colPrimaryHover
        colRipple: Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive : Appearance.colors.colPrimaryActive
        colText: Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
    }

    contentItem: ColumnLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 0

        RowLayout {
            // Name
            spacing: 10

            MaterialSymbol {
                iconSize: Appearance.font.pixelSize.larger
                text: Icons.getBluetoothDeviceMaterialSymbol(root.device?.icon || "")
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOnSurfaceVariant
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    text: root.device?.name || Translation.tr("Unknown device")
                }
                Revealer {
                    vertical: true
                    reveal: (root.device?.connected || root.device?.paired) ?? false
                    Layout.fillWidth: true
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                        elide: Text.ElideRight
                        text: {
                            if (!root.device?.paired) return "";
                            let statusText = root.device?.connected ? Translation.tr("Connected") : Translation.tr("Paired");
                            if (!root.device?.batteryAvailable) return statusText;
                            statusText += ` • ${Math.round(root.device?.battery * 100)}%`;
                            return statusText;
                        }
                    }
                }
            }

            MaterialSymbol {
                text: "keyboard_arrow_down"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOnLayer3
                rotation: root.expanded ? 180 : 0
                Behavior on rotation {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            visible: implicitHeight > 0
            implicitHeight: root.expanded ? actionsRow.implicitHeight : 0
            Layout.topMargin: root.expanded ? 8 : 0
            clip: true

            Behavior on implicitHeight {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            Behavior on Layout.topMargin {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }

            RowLayout {
                id: actionsRow
                width: parent.width

                Item { Layout.fillWidth: true }
                ActionButton {
                    id: connectBtn
                    property bool operationPending: false
                    buttonText: {
                        if (operationPending) {
                            return root.device?.connected ? Translation.tr("Disconnecting…") : Translation.tr("Connecting…");
                        }
                        return root.device?.connected ? Translation.tr("Disconnect") : Translation.tr("Connect")
                    }

                    onClicked: {
                        operationPending = true;
                        pendingTimeout.start();
                        if (root.device?.connected) {
                            root.device.disconnect();
                        } else {
                            root.device.trusted = true;
                            root.device.connect();
                        }
                    }

                    Connections {
                        target: root.device
                        function onConnectedChanged() {
                            connectBtn.operationPending = false;
                            pendingTimeout.stop();
                        }
                    }

                    Timer {
                        id: pendingTimeout
                        interval: 15000
                        onTriggered: connectBtn.operationPending = false
                    }
                }
                Revealer {
                    reveal: root.device?.paired ?? false
                    ActionButton {
                        colBackground: Appearance.colors.colError
                        colBackgroundHover: Appearance.colors.colErrorHover
                        colRipple: Appearance.colors.colErrorActive
                        colText: Appearance.colors.colOnError
                        buttonText: Translation.tr("Forget")
                        onClicked: root.device?.forget()
                    }
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
