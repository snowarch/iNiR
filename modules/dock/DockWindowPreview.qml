pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Button {
    id: root

    required property var toplevel
    property real previewWidthConstraint: 200
    property real previewHeightConstraint: 110
    padding: 6
    Layout.fillHeight: true

    // Emitted BEFORE focus IPC so the popup can close instantly (no flash)
    signal windowActivated()

    onClicked: {
        root.windowActivated()
        if (CompositorService.isNiri && root.toplevel?.niriWindowId) {
            NiriService.focusWindow(root.toplevel.niriWindowId)
        } else {
            root.toplevel?.activate()
        }
    }

    background: Rectangle {
        id: background
        radius: Appearance.inirEverywhere ? (Appearance.inir?.roundingSmall ?? 8) : Appearance.rounding.small
        color: root.down 
            ? ColorUtils.transparentize(Appearance.inirEverywhere ? Appearance.inir?.colPrimary ?? Appearance.colors.colPrimary : Appearance.colors.colPrimary, 0.7)
            : (root.hovered 
                ? ColorUtils.transparentize(Appearance.inirEverywhere ? Appearance.inir?.colLayer2Hover ?? Appearance.colors.colSurfaceContainerHigh : Appearance.colors.colSurfaceContainerHigh, 0.5)
                : "transparent")
        
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    contentItem: ColumnLayout {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 6

            IconImage {
                id: appIcon
                Layout.alignment: Qt.AlignVCenter
                // Use desktop entry icon (same resolution as dock button) instead of weak guessIcon
                source: {
                    const appId = root.toplevel?.appId ?? "";
                    const de = DesktopEntries.heuristicLookup(appId);
                    const icon = de?.icon || AppSearch.guessIcon(appId);
                    const resolved = IconThemeService.smartIconName(icon, appId);
                    return Quickshell.iconPath(resolved, "application-x-executable");
                }
                implicitSize: 16
                mipmap: true
                smooth: true
            }

            Item {
                id: appTitleContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: closeButton.implicitHeight

                StyledText {
                    id: appTitleText
                    anchors.fill: parent
                    anchors.rightMargin: closeButton.visible ? closeButton.width + 4 : 0
                    text: root.toplevel?.title ?? ""
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.inirEverywhere 
                        ? (Appearance.inir?.colText ?? Appearance.colors.colOnLayer0)
                        : Appearance.colors.colOnLayer0
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RippleButton {
                id: closeButton
                visible: root.hovered
                implicitWidth: 20
                implicitHeight: 20
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.8)
                colRipple: ColorUtils.transparentize(Appearance.colors.colError, 0.6)
                
                onClicked: root.toplevel?.close()

                contentItem: MaterialSymbol {
                    text: "close"
                    iconSize: 14
                    color: root.hovered 
                        ? Appearance.colors.colError
                        : (Appearance.inirEverywhere ? Appearance.inir?.colTextSecondary ?? Appearance.colors.colSubtext : Appearance.colors.colSubtext)
                }
            }
        }

        Item {
            id: previewArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 4
            Layout.topMargin: 0
            implicitWidth: 140
            implicitHeight: 90

            // Prefer niriWindowId for Niri compositor — WindowPreviewService captures by niri IDs
            readonly property int windowId: CompositorService.isNiri
                ? (root.toplevel?.niriWindowId ?? root.toplevel?.id ?? 0)
                : (root.toplevel?.id ?? 0)
            property string previewUrl: ""

            // Loading shimmer effect
            Rectangle {
                id: shimmerBg
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.inirEverywhere 
                    ? (Appearance.inir?.colLayer1 ?? Appearance.colors.colSurfaceContainerLow)
                    : Appearance.colors.colSurfaceContainerLow
                visible: windowPreview.status !== Image.Ready

                Rectangle {
                    id: shimmer
                    width: parent.width * 0.4
                    height: parent.height
                    x: -width
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.92) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }

                    SequentialAnimation on x {
                        running: shimmerBg.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: -shimmer.width
                            to: shimmerBg.width
                            duration: 1200
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation { duration: 400 }
                    }
                }
            }

            // Fallback icon - shown until preview loads (uses same resolution as header icon)
            IconImage {
                id: fallbackIcon
                anchors.centerIn: parent
                source: appIcon.source
                implicitSize: Math.min(48, parent.width * 0.4)
                opacity: windowPreview.status === Image.Ready ? 0 : 0.7
                mipmap: true
                smooth: true

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
            }

            // Preview image
            Image {
                id: windowPreview
                source: previewArea.previewUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                anchors.fill: parent
                anchors.margins: 2
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: windowPreview.width
                        height: windowPreview.height
                        radius: Appearance.rounding.small
                    }
                }
            }

            // Listen for preview updates
            Connections {
                target: WindowPreviewService
                function onPreviewUpdated(updatedId: int): void {
                    if (updatedId === previewArea.windowId) {
                        previewArea.previewUrl = WindowPreviewService.getPreviewUrl(updatedId)
                    }
                }
                function onCaptureComplete(): void {
                    const url = WindowPreviewService.getPreviewUrl(previewArea.windowId)
                    if (url) previewArea.previewUrl = url
                }
            }

            // Check if preview exists on load
            Component.onCompleted: {
                Qt.callLater(() => {
                    const url = WindowPreviewService.getPreviewUrl(windowId)
                    if (url) previewUrl = url
                })
            }
        }
    }
}
