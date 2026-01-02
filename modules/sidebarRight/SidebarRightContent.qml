import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

import qs.modules.sidebarRight.quickToggles
import qs.modules.sidebarRight.quickToggles.classicStyle

import qs.modules.sidebarRight.bluetoothDevices
import qs.modules.sidebarRight.nightLight
import qs.modules.sidebarRight.volumeMixer
import qs.modules.sidebarRight.wifiNetworks

Item {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 10
    property string settingsQmlPath: Quickshell.shellPath("settings.qml")
    property int screenWidth: 1920
    property int screenHeight: 1080
    property bool showAudioOutputDialog: false
    property bool showAudioInputDialog: false
    property bool showBluetoothDialog: false
    property bool showNightLightDialog: false
    property bool showWifiDialog: false
    property bool editMode: false
    
    // Debounce timers to prevent accidental double-clicks
    property bool reloadButtonEnabled: true
    property bool settingsButtonEnabled: true

    function focusActiveItem() {
        if (bottomWidgetGroup && bottomWidgetGroup.focusActiveItem) {
            bottomWidgetGroup.focusActiveItem()
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (!GlobalStates.sidebarRightOpen) {
                root.showWifiDialog = false;
                root.showBluetoothDialog = false;
                root.showAudioOutputDialog = false;
                root.showAudioInputDialog = false;
                root.showNightLightDialog = false;
            }
        }
    }

    implicitHeight: sidebarRightBackground.implicitHeight
    implicitWidth: sidebarRightBackground.implicitWidth

    StyledRectangularShadow {
        target: sidebarRightBackground
        visible: !Appearance.inirEverywhere && !Appearance.gameModeMinimal
    }
    Rectangle {
        id: sidebarRightBackground

        anchors.fill: parent
        implicitHeight: parent.height - Appearance.sizes.hyprlandGapsOut * 2
        implicitWidth: sidebarWidth - Appearance.sizes.hyprlandGapsOut * 2
        property bool cardStyle: Config.options.sidebar?.cardStyle ?? false
        readonly property bool auroraEverywhere: Appearance.auroraEverywhere
        readonly property bool inirEverywhere: Appearance.inirEverywhere
        readonly property bool gameModeMinimal: Appearance.gameModeMinimal
        readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl

        ColorQuantizer {
            id: sidebarRightWallpaperQuantizer
            source: sidebarRightBackground.wallpaperUrl
            depth: 0
            rescaleSize: 10
        }

        readonly property color wallpaperDominantColor: (sidebarRightWallpaperQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
        readonly property QtObject blendedColors: AdaptedMaterialScheme {
            color: ColorUtils.mix(sidebarRightBackground.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
        }

        color: gameModeMinimal ? "transparent"
            : inirEverywhere ? Appearance.inir.colLayer0
            : auroraEverywhere ? ColorUtils.applyAlpha((blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
            : (cardStyle ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)
        border.width: gameModeMinimal ? 0 : (inirEverywhere ? 1 : 1)
        border.color: inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
        radius: inirEverywhere ? Appearance.inir.roundingNormal
            : cardStyle ? Appearance.rounding.normal : (Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1)

        clip: true

        layer.enabled: auroraEverywhere && !inirEverywhere && !gameModeMinimal
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: sidebarRightBackground.width
                height: sidebarRightBackground.height
                radius: sidebarRightBackground.radius
            }
        }

        Image {
            id: sidebarRightBlurredWallpaper
            x: -(root.screenWidth - sidebarRightBackground.width - Appearance.sizes.hyprlandGapsOut)
            y: -Appearance.sizes.hyprlandGapsOut
            width: root.screenWidth ?? 1920
            height: root.screenHeight ?? 1080
            visible: sidebarRightBackground.auroraEverywhere && !sidebarRightBackground.inirEverywhere && !sidebarRightBackground.gameModeMinimal
            source: sidebarRightBackground.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled
            layer.effect: StyledBlurEffect {
                source: sidebarRightBlurredWallpaper
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize((sidebarRightBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebarPadding
            spacing: sidebarPadding

            SystemButtonRow {
                Layout.fillHeight: false
                Layout.fillWidth: true
                // Layout.margins: 10
                Layout.topMargin: 5
                Layout.bottomMargin: 0
            }

            Loader {
                id: slidersLoader
                Layout.fillWidth: true
                visible: active
                active: {
                    const configQuickSliders = Config.options?.sidebar?.quickSliders
                    if (!configQuickSliders?.enable) return false
                    if (!configQuickSliders?.showMic && !configQuickSliders?.showVolume && !configQuickSliders?.showBrightness) return false;
                    return true;
                }
                sourceComponent: QuickSliders {}
            }

            LoaderedQuickPanelImplementation {
                styleName: "classic"
                sourceComponent: ClassicQuickPanel {}
            }

            LoaderedQuickPanelImplementation {
                styleName: "android"
                sourceComponent: AndroidQuickPanel {
                    editMode: root.editMode
                }
            }

            CenterWidgetGroup {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.fillWidth: true
            }

            BottomWidgetGroup {
                id: bottomWidgetGroup
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
            }
        }
    }

    ToggleDialog {
        shownPropertyString: "showAudioOutputDialog"
        dialog: VolumeDialog {
            isSink: true
        }
    }

    ToggleDialog {
        shownPropertyString: "showAudioInputDialog"
        dialog: VolumeDialog {
            isSink: false
        }
    }

    ToggleDialog {
        shownPropertyString: "showBluetoothDialog"
        dialog: BluetoothDialog {}
        onShownChanged: {
            if (!Bluetooth.defaultAdapter) return
            if (!shown) {
                Bluetooth.defaultAdapter.discovering = false;
            } else {
                Bluetooth.defaultAdapter.enabled = true;
                Bluetooth.defaultAdapter.discovering = true;
            }
        }
    }

    ToggleDialog {
        shownPropertyString: "showNightLightDialog"
        dialog: NightLightDialog {}
    }

    ToggleDialog {
        shownPropertyString: "showWifiDialog"
        dialog: WifiDialog {}
        onShownChanged: {
            if (!shown) return;
            Network.enableWifi();
            Network.rescanWifi();
        }
    }

    component ToggleDialog: Loader {
        id: toggleDialogLoader
        required property string shownPropertyString
        property alias dialog: toggleDialogLoader.sourceComponent
        readonly property bool shown: root[shownPropertyString]
        anchors.fill: parent

        active: shown
        
        onItemChanged: {
            if (item) {
                item.show = true;
                item.forceActiveFocus();
            }
        }
        
        Connections {
            target: toggleDialogLoader.item
            function onDismiss() {
                root[toggleDialogLoader.shownPropertyString] = false;
            }
        }
    }

    component LoaderedQuickPanelImplementation: Loader {
        id: quickPanelImplLoader
        required property string styleName
        Layout.alignment: item?.Layout.alignment ?? Qt.AlignHCenter
        Layout.fillWidth: item?.Layout.fillWidth ?? false
        visible: active
        active: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === styleName
        Connections {
            target: quickPanelImplLoader.item
            function onOpenAudioOutputDialog() {
                root.showAudioOutputDialog = true;
            }
            function onOpenAudioInputDialog() {
                root.showAudioInputDialog = true;
            }
            function onOpenBluetoothDialog() {
                root.showBluetoothDialog = true;
            }
            function onOpenNightLightDialog() {
                root.showNightLightDialog = true;
            }
            function onOpenWifiDialog() {
                root.showWifiDialog = true;
            }
        }
    }

    component SystemButtonRow: Item {
        implicitHeight: Math.max(uptimeContainer.implicitHeight, systemButtonsRow.implicitHeight)

        Rectangle {
            id: uptimeContainer
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            color: sidebarRightBackground.auroraEverywhere
                ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer1
            radius: height / 2
            implicitWidth: uptimeRow.implicitWidth + 24
            implicitHeight: uptimeRow.implicitHeight + 8
            
            Row {
                id: uptimeRow
                anchors.centerIn: parent
                spacing: 8
                CustomIcon {
                    id: distroIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    source: SystemInfo.distroIcon
                    colorize: true
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                    text: Translation.tr("Up %1").arg(DateTime.uptime)
                    textFormat: Text.MarkdownText
                }
            }
        }

        ButtonGroup {
            id: systemButtonsRow
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            color: sidebarRightBackground.auroraEverywhere
                ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer1
            padding: 4
            spacing: 8  // Increased from default 5 to reduce accidental clicks

            QuickToggleButton {
                toggled: root.editMode
                visible: (Config.options?.sidebar?.quickToggles?.style ?? "classic") === "android"
                buttonIcon: "edit"
                onClicked: root.editMode = !root.editMode
                StyledToolTip {
                    text: Translation.tr("Edit quick toggles") + (root.editMode ? Translation.tr("\nLMB to enable/disable\nRMB to toggle size\nScroll to swap position") : "")
                }
            }
            QuickToggleButton {
                id: reloadButton
                toggled: false
                enabled: root.reloadButtonEnabled
                opacity: enabled ? 1.0 : 0.5
                buttonIcon: "restart_alt"
                onClicked: {
                    if (!root.reloadButtonEnabled) {
                        console.log("[SidebarRight] Reload button still on cooldown, ignoring click");
                        return;
                    }
                    
                    console.log("[SidebarRight] Reload button clicked");
                    root.reloadButtonEnabled = false;
                    reloadButtonCooldown.restart();
                    
                    if (CompositorService.isHyprland) {
                        Hyprland.dispatch("reload");
                    } else if (CompositorService.isNiri) {
                        Quickshell.execDetached(["/usr/bin/niri", "msg", "action", "load-config-file"]);
                    }
                    Quickshell.reload(true);
                }
                StyledToolTip {
                    text: Translation.tr("Reload Quickshell")
                }
            }
            
            Timer {
                id: reloadButtonCooldown
                interval: 500
                onTriggered: {
                    root.reloadButtonEnabled = true;
                    console.log("[SidebarRight] Reload button cooldown finished");
                }
            }
            QuickToggleButton {
                id: settingsButton
                toggled: false
                enabled: root.settingsButtonEnabled
                opacity: enabled ? 1.0 : 0.5
                buttonIcon: "settings"
                onClicked: {
                    if (!root.settingsButtonEnabled) {
                        console.log("[SidebarRight] Settings button still on cooldown, ignoring click");
                        return;
                    }
                    
                    console.log("[SidebarRight] Settings button clicked");
                    root.settingsButtonEnabled = false;
                    settingsButtonCooldown.restart();
                    
                    if (CompositorService.isNiri) {
                        const wins = NiriService.windows || []
                        console.log("[SidebarRight] Checking for existing settings window among", wins.length, "windows");
                        for (let i = 0; i < wins.length; i++) {
                            const w = wins[i]
                            if (w.title === "illogical-impulse Settings" && w.app_id === "org.quickshell") {
                                console.log("[SidebarRight] Found existing settings window, focusing it");
                                GlobalStates.sidebarRightOpen = false;
                                Qt.callLater(() => {
                                    NiriService.focusWindow(w.id)
                                })
                                return
                            }
                        }
                        console.log("[SidebarRight] No existing settings window found");
                    }
                    
                    console.log("[SidebarRight] Opening new settings window via IPC");
                    GlobalStates.sidebarRightOpen = false;
                    Qt.callLater(() => {
                        Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "settings", "open"]);
                    })
                }
                StyledToolTip {
                    text: Translation.tr("Settings")
                }
            }
            
            Timer {
                id: settingsButtonCooldown
                interval: 500
                onTriggered: {
                    root.settingsButtonEnabled = true;
                    console.log("[SidebarRight] Settings button cooldown finished");
                }
            }
            QuickToggleButton {
                toggled: false
                buttonIcon: "power_settings_new"
                onClicked: {
                    GlobalStates.sessionOpen = true;
                }
                StyledToolTip {
                    text: Translation.tr("Session")
                }
            }
        }
    }
}
