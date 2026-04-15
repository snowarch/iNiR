import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.bar as Bar
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    // Right-click context menu anchor (invisible, positioned at click)
    Item {
        id: barContextMenuAnchor
        width: 1
        height: 1
    }

    // For vertical bar: bottom config means bar is on the RIGHT side
    // (same config key reused for different meaning in vertical mode)
    readonly property bool barOnRight: Config.options?.bar?.bottom ?? false

    function openBarContextMenu(clickX, clickY, mouseArea) {
        // Position anchor at bar edge for correct horizontal popup positioning
        // If bar on right: anchor at left edge (x=0), popup goes left via popupSide=Edges.Left
        // If bar on left: anchor at right edge (x=width), popup goes right via popupSide=Edges.Right
        const mapped = mouseArea.mapToItem(root, clickX, clickY)
        barContextMenuAnchor.x = root.barOnRight ? 0 : root.width
        barContextMenuAnchor.y = mapped.y
        barContextMenu.active = true
    }

    ContextMenu {
        id: barContextMenu
        anchorItem: barContextMenuAnchor
        popupSide: root.barOnRight ? Edges.Left : Edges.Right
        closeOnFocusLost: true
        closeOnHoverLost: true

        model: [
            {
                iconName: "browse_activity",
                monochromeIcon: true,
                text: Translation.tr("Mission Center"),
                action: () => {
                    Session.launchTaskManager()
                },
            },
            { type: "separator" },
            {
                iconName: "settings",
                monochromeIcon: true,
                text: Translation.tr("Settings"),
                action: () => {
                    Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                },
            },
        ]
    }
    readonly property bool cardStyleEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && (Config.options?.bar?.cornerStyle === 3)
    readonly property color separatorColor: Appearance.colors.colOutlineVariant
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool gameModeMinimal: Appearance.gameModeMinimal

    readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl

    ColorQuantizer {
        id: wallpaperColorQuantizer
        source: (Appearance.auroraEverywhere || Appearance.angelEverywhere) ? root.wallpaperUrl : ""
        depth: 0 // 2^0 = 1 color
        rescaleSize: 10
    }

    readonly property color wallpaperDominantColor: (wallpaperColorQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
    readonly property QtObject blendedColors: AdaptedMaterialScheme {
        color: ColorUtils.mix(root.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    }

    component HorizontalBarSeparator: Rectangle {
        Layout.leftMargin: Appearance.sizes.baseBarHeight / 3
        Layout.rightMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillWidth: true
        implicitHeight: 1
        color: root.separatorColor
    }

    // Background shadow - for floating styles or always for angel
    Loader {
        active: (Config.options?.bar?.showBackground ?? true) && !root.gameModeMinimal
            && (Appearance.angelEverywhere || ((Config.options?.bar?.cornerStyle ?? 0) === 1 || (Config.options?.bar?.cornerStyle ?? 0) === 3))
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }

    // Background
    Rectangle {
        id: barBackground
        // Floating style: cornerStyle 1 (floating) or 3 (card) - NOT 0 (hug)
        // Aurora style forces floating appearance but hug mode should still work
        readonly property bool floatingStyle: (Config.options?.bar?.cornerStyle ?? 0) === 1 || (Config.options?.bar?.cornerStyle ?? 0) === 3

        anchors {
            fill: parent
            // Only add margins for floating styles, NOT for hug mode (cornerStyle 0)
            margins: floatingStyle ? Appearance.sizes.hyprlandGapsOut : 0
        }
        visible: (Config.options?.bar?.showBackground ?? true) && !root.gameModeMinimal
        color: Appearance.angelEverywhere ? ColorUtils.applyAlpha((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
            : root.inirEverywhere ? Appearance.inir.colLayer0
            : root.auroraEverywhere ? ColorUtils.applyAlpha((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
            : (root.cardStyleEverywhere ? Appearance.colors.colLayer1 : ((Config.options?.bar?.cornerStyle ?? 0) === 3 ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0))
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : root.inirEverywhere ? Appearance.inir.roundingNormal
            : floatingStyle ? ((Config.options?.bar?.cornerStyle ?? 0) === 3 ? Appearance.rounding.normal : Appearance.rounding.windowRounding) : 0
        border.width: Appearance.angelEverywhere ? 0 : (root.inirEverywhere ? 1 : (floatingStyle ? 1 : 0))
        border.color: Appearance.angelEverywhere ? "transparent"
            : root.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.colors.colLayer0Border

        clip: true

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: Appearance.angelEverywhere
            color: Appearance.angel.colInsetGlow
        }

        // Angel partial border
        AngelPartialBorder {
            targetRadius: barBackground.radius
        }
    }

    // Aurora/Angel blur layer — rendered as sibling of barBackground so the blur
    // is applied over the full screen-sized wallpaper image (not the narrow
    // clipped bar region). Placed right after barBackground in z-order so it
    // sits between background and content.
    Item {
        id: auroraBlurLayer
        anchors.fill: barBackground
        visible: root.auroraEverywhere && !root.inirEverywhere && !root.gameModeMinimal
            && (Config.options?.bar?.showBackground ?? true)

        // Clip + mask to barBackground shape
        clip: true
        layer.enabled: visible
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: auroraBlurLayer.width
                height: auroraBlurLayer.height
                radius: barBackground.radius
            }
        }

        Image {
            id: blurredWallpaper
            // Position relative to screen — uses screen-sized source so the
            // wallpaper portion shown matches corner decorators exactly.
            readonly property real barMargin: barBackground.floatingStyle ? Appearance.sizes.hyprlandGapsOut : 0
            x: root.barOnRight
                ? (-(root.screen?.width ?? 1920) + auroraBlurLayer.width + barMargin)
                : -barMargin
            y: -barMargin
            width: root.screen?.width ?? 1920
            height: root.screen?.height ?? 1080
            source: root.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screen?.width ?? 1920
            sourceSize.height: root.screen?.height ?? 1080
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled && root.auroraEverywhere && !root.inirEverywhere
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: source
                saturation: Appearance.angelEverywhere
                    ? Appearance.angel.blurSaturation
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 100
                blur: Appearance.effectsEnabled ? 1 : 0
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.angelEverywhere
                    ? ColorUtils.transparentize((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity)
                    : ColorUtils.transparentize((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }
    }

    FocusedScrollMouseArea { // Top section | scroll to change brightness
        id: barTopSectionMouseArea
        anchors.top: parent.top
        implicitHeight: topSectionColumnLayout.implicitHeight
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        height: (root.height - middleSection.height) / 2
        width: Appearance.sizes.verticalBarWidth

        onScrollDown: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness - 0.05)
        onScrollUp: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + 0.05)
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
            else if (event.button === Qt.RightButton)
                root.openBarContextMenu(event.x, event.y, barTopSectionMouseArea)
        }

        ColumnLayout { // Content
            id: topSectionColumnLayout
            anchors.fill: parent
            spacing: 10

            Bar.LeftSidebarButton { // Left sidebar button
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: (Appearance.sizes.baseVerticalBarWidth - implicitWidth) / 2 + Appearance.sizes.hyprlandGapsOut
                colBackground: buttonHovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
            }

            Item {
                Layout.fillHeight: true
            }
            
        }
    }

    Column { // Middle section
        id: middleSection
        anchors.centerIn: parent
        spacing: 4

        // When taskbar is active: clock/date moves up to where resources was
        Bar.BarGroup {
            id: clockGroupTop
            vertical: true
            padding: 8
            visible: Config.options?.bar?.modules?.taskbar ?? false

            VerticalClockWidget {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {}

            VerticalDateWidget {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: Battery.available
            }

            BatteryIndicator {
                visible: Battery.available
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
        }

        Bar.BarGroup {
            id: resourcesGroup
            vertical: true
            padding: 8
            // Hide resources when taskbar is active to free vertical space
            visible: !(Config.options?.bar?.modules?.taskbar ?? false)
            Resources {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            
            HorizontalBarSeparator {}

            VerticalMedia {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
        }

    HorizontalBarSeparator {
            visible: Config.options?.bar?.borderless ?? false
        }

        Bar.BarGroup {
            id: middleCenterGroup
            vertical: true
            padding: 6

            Bar.Workspaces {
                id: workspacesWidget
                vertical: true
                MouseArea {
                    // Right-click to toggle overview
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton

                    onPressed: event => {
                        if (event.button === Qt.RightButton) {
                            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                        }
                    }
                }
            }
        }

        HorizontalBarSeparator {
            visible: (Config.options?.bar?.modules?.taskbar ?? false) && (Config.options?.bar?.borderless ?? false)
        }

        // Taskbar (apps in bar) — vertical mode
        Bar.BarGroup {
            id: taskbarGroup
            vertical: true
            padding: 4
            visible: Config.options?.bar?.modules?.taskbar ?? false

            Bar.BarTaskbar {
                vertical: true
                parentWindow: root.QsWindow.window
                Layout.fillWidth: true
                Layout.fillHeight: false
                maximumHeight: Math.max(80, root.height
                    - (clockGroupTop.visible ? clockGroupTop.height : 0)
                    - middleCenterGroup.height
                    - (clockGroup.visible ? clockGroup.height : 0)
                    - middleSection.spacing * 6
                    - 140)
            }
        }

        HorizontalBarSeparator {
            visible: Config.options?.bar?.borderless ?? false
        }

        // When taskbar is NOT active: clock/date stays in its original position
        Bar.BarGroup {
            id: clockGroup
            vertical: true
            padding: 8
            visible: !(Config.options?.bar?.modules?.taskbar ?? false)
            
            VerticalClockWidget {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {}

            VerticalDateWidget {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: Battery.available
            }

            BatteryIndicator {
                visible: Battery.available
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            
        }
    }

    FocusedScrollMouseArea { // Bottom section | scroll to change volume
        id: barBottomSectionMouseArea

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        implicitHeight: bottomSectionColumnLayout.implicitHeight
        height: (root.height - middleSection.height) / 2
        width: Appearance.sizes.verticalBarWidth
        
        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            } else if (event.button === Qt.RightButton) {
                root.openBarContextMenu(event.x, event.y, barBottomSectionMouseArea)
            }
        }

        ColumnLayout {
            id: bottomSectionColumnLayout
            anchors.fill: parent
            spacing: 4

            Item { 
                Layout.fillWidth: true
                Layout.fillHeight: true 
            }

            Bar.SysTray {
                vertical: true
                Layout.fillWidth: true
                Layout.fillHeight: false
                invertSide: Config?.options.bar.bottom
            }

            RippleButton { // Right sidebar button
                id: rightSidebarButton

                Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
                Layout.bottomMargin: Appearance.rounding.screenRounding
                Layout.fillHeight: false

                implicitHeight: indicatorsColumnLayout.implicitHeight + 4 * 2
                implicitWidth: indicatorsColumnLayout.implicitWidth + 6 * 2

                buttonRadius: Appearance.rounding.full
                colBackground: buttonHovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                toggled: GlobalStates.sidebarRightOpen
                property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0

                Behavior on colText {
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                onPressed: {
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                }

                ColumnLayout {
                    id: indicatorsColumnLayout
                    anchors.centerIn: parent
                    property real realSpacing: 6
                    spacing: 0

                    Revealer {
                        vertical: true
                        reveal: Audio.sink?.audio?.muted ?? false
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        Behavior on Layout.bottomMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        MaterialSymbol {
                            text: "volume_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Revealer {
                        vertical: true
                        reveal: Audio.micMuted
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        Behavior on Layout.topMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        MaterialSymbol {
                            text: "mic_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Loader {
                        active: CompositorService.isHyprland
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: indicatorsColumnLayout.realSpacing
                        sourceComponent: Bar.HyprlandXkbIndicator {
                            vertical: true
                            color: rightSidebarButton.colText
                        }
                    }
                    Revealer {
                        vertical: true
                        reveal: Notifications.silent || Notifications.unread > 0
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                        implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                        Behavior on Layout.bottomMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Bar.NotificationUnreadCount {
                            id: notificationUnreadCount
                        }
                    }
                    MaterialSymbol {
                        Layout.bottomMargin: indicatorsColumnLayout.realSpacing
                        text: Network.materialSymbol
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                    MaterialSymbol {
                        visible: BluetoothStatus.available
                        text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
            }
        }
    }
}
