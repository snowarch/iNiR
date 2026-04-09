import qs.modules.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
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

    function openBarContextMenu(clickX, clickY, mouseArea) {
        // Position anchor at bar edge for correct popup positioning
        // For bar top: anchor at bottom edge (y = height), popup appears below
        // For bar bottom: anchor at top edge (y = 0), popupAbove makes it appear above
        const mapped = mouseArea.mapToItem(root, clickX, clickY)
        barContextMenuAnchor.x = mapped.x
        barContextMenuAnchor.y = (Config.options?.bar?.bottom ?? false) ? 0 : root.height
        barContextMenu.active = true
    }

    ContextMenu {
        id: barContextMenu
        anchorItem: barContextMenuAnchor
        popupAbove: Config.options?.bar?.bottom ?? false
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
    readonly property bool taskbarEnabled: Config.options?.bar?.modules?.taskbar ?? false

    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    readonly property int baseCenterSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth
    // Both center groups share the same width so workspaces stay perfectly centered
    readonly property int centerSideModuleWidth: Math.max(baseCenterSideModuleWidth, rightCenterGroupContent.implicitWidth)
    readonly property bool cardStyleEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && (Config.options?.bar?.cornerStyle === 3)
    readonly property color separatorColor: Appearance.colors.colOutlineVariant

    // Per-monitor wallpaper URL for Aurora blur — uses the actual wallpaper on this screen
    readonly property string wallpaperUrl: {
        const _dep1 = WallpaperListener.multiMonitorEnabled
        const _dep2 = WallpaperListener.effectivePerMonitor
        const _dep3 = Wallpapers.effectiveWallpaperUrl
        return WallpaperListener.wallpaperUrlForScreen(root.screen)
    }

    readonly property bool _useGlobalQuantizer: root.wallpaperUrl === Wallpapers.effectiveWallpaperUrl
    ColorQuantizer {
        id: wallpaperColorQuantizer
        source: (Appearance.auroraEverywhere || Appearance.angelEverywhere)
            ? (root._useGlobalQuantizer ? "" : root.wallpaperUrl)
            : ""
        depth: 0 // 2^0 = 1 color
        rescaleSize: 10
    }

    readonly property color wallpaperDominantColor: root._useGlobalQuantizer
        ? Appearance.wallpaperDominantColor
        : (wallpaperColorQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
    AdaptedMaterialScheme {
        id: _localBlendedColors
        color: ColorUtils.mix(root.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    }
    readonly property QtObject blendedColors: root._useGlobalQuantizer
        ? Appearance.wallpaperBlendedColors : _localBlendedColors

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property string leftAction: Config.options?.bar?.leftScrollAction ?? "brightness"
    readonly property string rightAction: Config.options?.bar?.rightScrollAction ?? "volume"

    function performScrollAction(action: string, isUp: bool): void {
        if (action === "brightness") {
            const step = 0.05;
            root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + (isUp ? step : -step));
        } else if (action === "volume") {
            if (isUp) Audio.incrementVolume();
            else Audio.decrementVolume();
        } else if (action === "workspace") {
            let up = isUp;
            if (Config.options?.bar?.workspaces?.invertScroll ?? false) up = !up;

            if (CompositorService.isNiri) {
                if (up) NiriService.focusWorkspaceUp();
                else NiriService.focusWorkspaceDown();
            } else if (CompositorService.isHyprland) {
                Hyprland.dispatch(up ? "workspace r-1" : "workspace r+1");
            }
        }
    }

    function closeOSD(action: string): void {
        if (action === "brightness") GlobalStates.osdBrightnessOpen = false;
        else if (action === "volume") GlobalStates.osdVolumeOpen = false;
    }

    function getScrollIcon(action: string): string {
        if (action === "brightness") return "light_mode";
        if (action === "volume") return "volume_up";
        if (action === "workspace") return "workspaces";
        return "";
    }

    function getScrollTooltip(action: string): string {
        if (action === "brightness") return Translation.tr("Scroll to change brightness");
        if (action === "volume") return Translation.tr("Scroll to change volume");
        if (action === "workspace") return Translation.tr("Scroll to switch workspaces");
        return "";
    }

    component VerticalBarSeparator: Rectangle {
        Layout.topMargin: Appearance.sizes.baseBarHeight / 3
        Layout.bottomMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillHeight: true
        implicitWidth: 1
        color: root.inirEverywhere ? Appearance.inir.colBorderSubtle : root.separatorColor
    }

    // Background shadow
    Loader {
        active: !root.inirEverywhere
            && (Appearance.angelEverywhere || !Appearance.auroraEverywhere)
            && !Appearance.gameModeMinimal
            && (Config.options?.bar?.showBackground ?? true)
            && (Appearance.angelEverywhere || (((Config.options?.bar?.cornerStyle ?? 0) === 1 || (Config.options?.bar?.cornerStyle ?? 0) === 3)
            && (Config.options?.bar?.floatStyleShadow ?? true)))
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        readonly property bool auroraEverywhere: Appearance.auroraEverywhere
        readonly property bool gameModeMinimal: Appearance.gameModeMinimal
        readonly property int cornerStyle: Config.options?.bar?.cornerStyle ?? 0
        // Float (1) and Card (3) are floating; Aurora makes everything floating except Hug and Rect
        readonly property bool floatingStyle: (cornerStyle === 1 || cornerStyle === 3) || (auroraEverywhere && cornerStyle !== 0 && cornerStyle !== 2)

        anchors {
            fill: parent
            margins: floatingStyle ? Appearance.sizes.hyprlandGapsOut : 0
        }
        readonly property real barMargin: floatingStyle ? Appearance.sizes.hyprlandGapsOut : 0
        readonly property bool isBottom: Config.options?.bar?.bottom ?? false

        readonly property QtObject blendedColors: root.blendedColors

        visible: (Config.options?.bar?.showBackground ?? true) && !gameModeMinimal

        // Color logic per global style and corner style
        color: {
            if (root.angelEverywhere) {
                return ColorUtils.applyAlpha((blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
            }
            if (root.inirEverywhere) {
                return Appearance.inir.colLayer0
            }
            if (auroraEverywhere) {
                // Aurora: use solid base for non-floating, blended for floating
                return ColorUtils.applyAlpha((blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
            }
            // Material/Cards
            if (root.cardStyleEverywhere || cornerStyle === 3) {
                return Appearance.colors.colLayer1
            }
            return Appearance.colors.colLayer0
        }

        // Radius logic per global style and corner style
        radius: {
            // Custom rounding override (-1 means use theme default)
            const customRounding = Config.options?.bar?.customRounding ?? -1
            if (customRounding >= 0) {
                return customRounding
            }
            if (root.angelEverywhere) {
                return (cornerStyle === 1 || cornerStyle === 3) ? Appearance.angel.roundingNormal : 0
            }
            if (root.inirEverywhere) {
                // Inir: use inir rounding for Float/Card, 0 for Hug/Rect
                if (cornerStyle === 1 || cornerStyle === 3) {
                    return Appearance.inir.roundingNormal
                }
                return 0
            }
            if (floatingStyle) {
                // Float or Card floating
                return cornerStyle === 3 ? Appearance.rounding.normal : Appearance.rounding.windowRounding
            }
            return 0
        }

        // Border logic per global style
        border.width: {
            if (root.angelEverywhere) return Appearance.angel.panelBorderWidth
            if (root.inirEverywhere) {
                return (cornerStyle === 1 || cornerStyle === 3) ? 1 : 0
            }
            if (auroraEverywhere) {
                return floatingStyle ? 1 : 0
            }
            return floatingStyle ? 1 : 0
        }
        border.color: {
            if (root.angelEverywhere) return Appearance.angel.colPanelBorder
            if (root.inirEverywhere) {
                return Appearance.inir.colBorder
            }
            if (auroraEverywhere) {
                return Appearance.aurora.colTooltipBorder
            }
            return Appearance.colors.colLayer0Border
        }

        clip: true

        layer.enabled: auroraEverywhere && !root.inirEverywhere && !gameModeMinimal
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: barBackground.width
                height: barBackground.height
                radius: barBackground.radius
            }
        }

        Image {
            id: blurredWallpaper
            x: -barBackground.barMargin
            y: barBackground.isBottom ? -(root.screen?.height ?? 1080) + barBackground.height + barBackground.barMargin : -barBackground.barMargin
            width: root.screen?.width ?? 1920
            height: root.screen?.height ?? 1080
            visible: barBackground.auroraEverywhere && !root.inirEverywhere && !barBackground.gameModeMinimal
            source: root.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screen?.width ?? 1920
            sourceSize.height: root.screen?.height ?? 1080
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled && barBackground.auroraEverywhere && !root.inirEverywhere
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: source
                saturation: root.angelEverywhere
                    ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 100
                blur: Appearance.effectsEnabled
                    ? (root.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                    : 0
            }

            Rectangle {
                anchors.fill: parent
                color: root.angelEverywhere
                    ? ColorUtils.transparentize((barBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity * Appearance.angel.panelTransparentize)
                    : ColorUtils.transparentize((barBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: root.angelEverywhere
            color: Appearance.angel.colInsetGlow
        }

        // Angel partial border — elegant half-borders
        AngelPartialBorder {
            targetRadius: barBackground.radius
        }
    }

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: middleSection.left
        }
        implicitWidth: leftSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: root.performScrollAction(root.leftAction, false)
        onScrollUp: root.performScrollAction(root.leftAction, true)
        onMovedAway: root.closeOSD(root.leftAction)
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
            else if (event.button === Qt.RightButton)
                root.openBarContextMenu(event.x, event.y, barLeftSideMouseArea)
        }

        // ScrollHint as overlay - at the inner edge of the margin space
        ScrollHint {
            id: leftScrollHint
            reveal: barLeftSideMouseArea.hovered && (Config.options?.bar?.showScrollHints ?? true) && root.leftAction !== "none"
            icon: root.getScrollIcon(root.leftAction)
            tooltipText: root.getScrollTooltip(root.leftAction)
            side: "left"
            x: Appearance.rounding.screenRounding - implicitWidth - Appearance.sizes.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            z: 1
        }

        RowLayout {
            id: leftSectionRowLayout
            anchors.fill: parent
            anchors.leftMargin: Appearance.rounding.screenRounding
            anchors.rightMargin: Appearance.rounding.screenRounding
            spacing: 10

            LeftSidebarButton { // Left sidebar button
                visible: Config.options?.bar?.modules?.leftSidebarButton ?? true
                Layout.alignment: Qt.AlignVCenter
                colBackground: barLeftSideMouseArea.hovered
                    ? (Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1Hover)
                    : "transparent"
            }

            ActiveWindow {
                visible: (Config.options?.bar?.modules?.activeWindow ?? true) && root.useShortenedForm === 0 && !root.taskbarEnabled
                Layout.fillWidth: !root.taskbarEnabled
                Layout.fillHeight: true
            }

            Loader {
                active: root.taskbarEnabled
                visible: active
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: BarTaskbar {
                    parentWindow: root.QsWindow.window
                }
            }
        }
    }

    Row { // Middle section
        id: middleSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 4

        BarGroup {
            id: leftCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.centerSideModuleWidth

            Loader {
                active: Config.options?.bar?.modules?.resources ?? true
                visible: active
                Layout.fillWidth: root.useShortenedForm === 2
                sourceComponent: Resources {
                    alwaysShowAllResources: root.useShortenedForm === 2
                }
            }

            Loader {
                active: (Config.options?.bar?.modules?.media ?? true) && root.useShortenedForm < 2
                visible: active
                Layout.fillWidth: true
                sourceComponent: Media {
                }
            }
        }

        VerticalBarSeparator {
            visible: Config.options?.bar.borderless
        }

        BarGroup {
            id: middleCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            padding: workspacesWidget.widgetPadding

            Workspaces {
                id: workspacesWidget
                visible: Config.options?.bar?.modules?.workspaces ?? true
                Layout.fillHeight: true
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

        VerticalBarSeparator {
            visible: Config.options?.bar.borderless
        }

        MouseArea {
            id: rightCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: root.centerSideModuleWidth
            implicitHeight: rightCenterGroupContent.implicitHeight
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            // Gesture sequence tracking for multi-tap detection
            property int _tapSeq: 0
            property bool _confirmFx: false
            Timer { id: _tapSeqTimer; interval: 500; onTriggered: rightCenterGroup._tapSeq = 0 }
            Timer { id: _fxResetTimer; interval: 2000; onTriggered: rightCenterGroup._confirmFx = false }

            onPressed: event => {
                if (event.button === Qt.RightButton) {
                    GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen;
                } else {
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                    _tapSeq++; _tapSeqTimer.restart()
                    if (_tapSeq >= 3) { _confirmFx = true; _tapSeq = 0; _fxResetTimer.restart() }
                }
            }

            BarGroup {
                id: rightCenterGroupContent
                anchors.fill: parent

                ClockWidget {
                    visible: Config.options?.bar?.modules?.clock ?? true
                    showDate: ((Config.options?.bar?.verbose ?? true) && root.useShortenedForm < 2)
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                }

                UtilButtons {
                    visible: (Config.options?.bar?.modules?.utilButtons ?? true) && ((Config.options?.bar?.verbose ?? true) && root.useShortenedForm === 0)
                    Layout.alignment: Qt.AlignVCenter
                }

                BatteryIndicator {
                    visible: (Config.options?.bar?.modules?.battery ?? true) && (root.useShortenedForm < 2 && Battery.available)
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Tap-sequence visual confirmation overlay
            Repeater {
                model: rightCenterGroup._confirmFx ? 3 : 0
                Text {
                    property int _delay: index * 120
                    text: "\ud83e\udec3\ud83c\udffb"
                    font.pixelSize: 22
                    x: (rightCenterGroup.width - implicitWidth) / 2 + (index - 1) * 28
                    y: rightCenterGroup.height / 2
                    z: 10
                    scale: 0
                    opacity: 0
                    SequentialAnimation on y {
                        PauseAnimation { duration: _delay }
                        NumberAnimation { to: -20; duration: 1200; easing.type: Easing.OutCubic }
                    }
                    SequentialAnimation on scale {
                        PauseAnimation { duration: _delay }
                        NumberAnimation { to: 1.3; duration: 250; easing.type: Easing.OutBack }
                        NumberAnimation { to: 1.0; duration: 200 }
                        PauseAnimation { duration: 500 }
                        NumberAnimation { to: 0; duration: 300; easing.type: Easing.InBack }
                    }
                    SequentialAnimation on opacity {
                        PauseAnimation { duration: _delay }
                        NumberAnimation { to: 1; duration: 200 }
                        PauseAnimation { duration: 700 }
                        NumberAnimation { to: 0; duration: 350 }
                    }
                }
            }
        }
    }

    FocusedScrollMouseArea { // Right side | scroll to change volume
        id: barRightSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: middleSection.right
            right: parent.right
        }
        implicitWidth: rightSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: root.performScrollAction(root.rightAction, false)
        onScrollUp: root.performScrollAction(root.rightAction, true)
        onMovedAway: root.closeOSD(root.rightAction)
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            } else if (event.button === Qt.RightButton) {
                root.openBarContextMenu(event.x, event.y, barRightSideMouseArea)
            }
        }

        // ScrollHint as overlay - at the inner edge of the margin space
        ScrollHint {
            id: rightScrollHint
            reveal: barRightSideMouseArea.hovered && (Config.options?.bar?.showScrollHints ?? true) && root.rightAction !== "none"
            icon: root.getScrollIcon(root.rightAction)
            tooltipText: root.getScrollTooltip(root.rightAction)
            side: "right"
            x: parent.width - Appearance.rounding.screenRounding + Appearance.sizes.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            z: 1
        }

        RowLayout {
            id: rightSectionRowLayout
            anchors.fill: parent
            anchors.leftMargin: Appearance.rounding.screenRounding
            anchors.rightMargin: Appearance.rounding.screenRounding
            spacing: 5
            layoutDirection: Qt.RightToLeft

            RippleButton { // Right sidebar button
                id: rightSidebarButton
                visible: Config.options?.bar?.modules?.rightSidebarButton ?? true

                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillWidth: false

                implicitWidth: indicatorsRowLayout.implicitWidth + 10 * 2
                implicitHeight: indicatorsRowLayout.implicitHeight + 5 * 2

                buttonRadius: Appearance.rounding.full

                colBackground: barRightSideMouseArea.hovered
                    ? (Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1Hover)
                    : "transparent"
                colBackgroundHover: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1Hover
                colRipple: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer1Active
                colBackgroundToggled: Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover : Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive

                toggled: GlobalStates.sidebarRightOpen
                property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0

                Behavior on colText {
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                onPressed: {
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                }

                RowLayout {
                    id: indicatorsRowLayout
                    anchors.centerIn: parent
                    property real realSpacing: 15
                    spacing: 0

                    Revealer {
                        reveal: Audio.sink?.audio?.muted ?? false
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        Behavior on Layout.rightMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        MaterialSymbol {
                            text: "volume_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Revealer {
                        reveal: Audio.micMuted
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        Behavior on Layout.rightMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        MaterialSymbol {
                            text: "mic_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    HyprlandXkbIndicator {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: indicatorsRowLayout.realSpacing
                        color: rightSidebarButton.colText
                    }
                    Revealer {
                        reveal: Notifications.silent || Notifications.unread > 0
                        Layout.fillHeight: true
                        Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                        implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                        implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                        Behavior on Layout.rightMargin {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        NotificationUnreadCount {
                            id: notificationUnreadCount
                        }
                    }
                    MaterialSymbol {
                        text: Network.materialSymbol
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                    MaterialSymbol {
                        Layout.leftMargin: indicatorsRowLayout.realSpacing
                        visible: BluetoothStatus.available
                        text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
            }

            SysTray {
                visible: (Config.options?.bar?.modules?.sysTray ?? true) && root.useShortenedForm === 0
                Layout.fillWidth: false
                Layout.fillHeight: true
                invertSide: Config.options?.bar?.bottom ?? false
            }

            // Timer indicator
            TimerIndicator {
                Layout.alignment: Qt.AlignVCenter
            }

            // iNiR shell update indicator
            ShellUpdateIndicator {
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // Weather
            Loader {
                Layout.leftMargin: 4
                active: (Config.options?.bar?.modules?.weather ?? true) && (Config.options?.bar?.weather?.enable ?? false)

                sourceComponent: BarGroup {
                    WeatherBar {}
                }
            }
        }
    }
}
