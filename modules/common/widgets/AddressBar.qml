import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root
    required property var directory
    property bool showBreadcrumb: true
    onShowBreadcrumbChanged: {
        addressInput.text = root.directory;
    }

    signal navigateToDirectory(string path)

    property real padding: 6
    implicitWidth: mainLayout.implicitWidth + padding * 2
    implicitHeight: mainLayout.implicitHeight + padding * 2
    color: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt : Appearance.colors.colLayer2
    radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : 0
    border.width: Appearance.zzzEverywhere ? 1 : 0
    border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong : "transparent"
    // Organic morph on style/shape switch (organic-transitions)
    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
    Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

    function focusBreadcrumb() {
        root.showBreadcrumb = false;
        addressInput.forceActiveFocus();
    }

    RowLayout {
        id: mainLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 8

        RippleButton {
            id: parentDirButton
            downAction: () => root.navigateToDirectory(FileUtils.parentDirectory(root.directory))
            contentItem: MaterialSymbol {
                text: "drive_folder_upload"
                iconSize: Appearance.font.pixelSize.larger
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: directoryEntry
                visible: !root.showBreadcrumb
                anchors.fill: parent
                color: Appearance.zzzEverywhere ? Appearance.zzz.paper : Appearance.colors.colLayer1
                radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.full
                border.width: Appearance.zzzEverywhere ? 1 : 0
                border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairline : "transparent"
                // Organic morph on style/shape switch (organic-transitions)
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                implicitWidth: addressInput.implicitWidth
                implicitHeight: addressInput.implicitHeight

                Keys.onPressed: event => {
                    if (directoryEntry.visible && event.key === Qt.Key_Escape) {
                        root.showBreadcrumb = true;
                        event.accepted = true;
                        return;
                    }
                    event.accepted = false;
                }

                StyledTextInput {
                    id: addressInput
                    anchors.fill: parent
                    padding: 10
                    text: root.directory

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.navigateToDirectory(text);
                            root.showBreadcrumb = true;
                            event.accepted = true;
                        }
                    }

                    MouseArea {
                        // I-beam cursor
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                    }
                }
            }

            Loader {
                id: breadcrumbLoader
                active: root.showBreadcrumb
                visible: root.showBreadcrumb
                anchors.fill: parent
                sourceComponent: AddressBreadcrumb {
                    directory: root.directory
                    onNavigateToDirectory: dir => {
                        root.navigateToDirectory(dir);
                    }
                }
            }
        }

        RippleButton {
            id: dirEditButton
            toggled: !root.showBreadcrumb
            // ZZZ toggled = accent sticker plate so onSticker icon stays readable
            colBackgroundToggled: Appearance.zzzEverywhere ? Appearance.zzz.sticker : (Appearance.colors.colPrimary)
            colBackgroundToggledHover: Appearance.zzzEverywhere ? ColorUtils.mix(Appearance.zzz.sticker, Appearance.zzz.accent, 0.5) : (Appearance.colors.colPrimaryHover)
            downAction: () => root.showBreadcrumb = !root.showBreadcrumb
            contentItem: MaterialSymbol {
                text: "edit"
                iconSize: Appearance.font.pixelSize.larger
                color: dirEditButton.toggled
                    ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimary)
                    : (Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer2)
            }

            StyledToolTip {
                text: Translation.tr("Edit directory")
            }
        }
    }
}
