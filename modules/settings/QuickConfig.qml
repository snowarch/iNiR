import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    settingsPageIndex: 0
    settingsPageName: Translation.tr("Quick")

    Component.onCompleted: {
        Wallpapers.load()
    }

    Process {
        id: randomWallProc
        property string status: ""
        property string scriptPath: `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`
        command: ["/usr/bin/bash", "-c", FileUtils.trimFileProtocol(randomWallProc.scriptPath)]
        stdout: SplitParser {
            onRead: data => {
                randomWallProc.status = data.trim();
            }
        }
    }

    component SmallLightDarkPreferenceButton: RippleButton {
        id: smallLightDarkPreferenceButton
        required property bool dark
        property color colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        padding: 5
        Layout.fillWidth: true
        toggled: Appearance.m3colors.darkmode === dark
        colBackground: Appearance.colors.colLayer2
        onClicked: {
            Quickshell.execDetached(["/usr/bin/bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`]);
        }
        contentItem: Item {
            anchors.centerIn: parent
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: 30
                    text: dark ? "dark_mode" : "light_mode"
                    color: smallLightDarkPreferenceButton.colText
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: dark ? Translation.tr("Dark") : Translation.tr("Light")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: smallLightDarkPreferenceButton.colText
                }
            }
        }
    }

    // Wallpaper selection
    SettingsCardSection {
        expanded: true
        icon: "format_paint"
        title: Translation.tr("Wallpaper & Colors")
        Layout.fillWidth: true

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true

                Item {
                    implicitWidth: 340
                    implicitHeight: 200
                    
                    StyledImage {
                        id: wallpaperPreview
                        anchors.fill: parent
                        sourceSize.width: parent.implicitWidth
                        sourceSize.height: parent.implicitHeight
                        fillMode: Image.PreserveAspectCrop
                        source: Wallpapers.effectiveWallpaperUrl
                        cache: false
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: 360
                                height: 200
                                radius: Appearance.rounding.normal
                            }
                        }
                    }
                }

                ColumnLayout {
                    RippleButtonWithIcon {
                        enabled: !randomWallProc.running
                        visible: Config.options.policies.weeb === 1
                        Layout.fillWidth: true
                        buttonRadius: Appearance.rounding.small
                        materialIcon: "ifl"
                        mainText: randomWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: Konachan")
                        onClicked: {
                            randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`;
                            randomWallProc.running = true;
                        }
                        StyledToolTip {
                            text: Translation.tr("Random SFW Anime wallpaper from Konachan\nImage is saved to ~/Pictures/Wallpapers")
                        }
                    }
                    RippleButtonWithIcon {
                        enabled: !randomWallProc.running
                        visible: Config.options.policies.weeb === 1
                        Layout.fillWidth: true
                        buttonRadius: Appearance.rounding.small
                        materialIcon: "ifl"
                        mainText: randomWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: osu! seasonal")
                        onClicked: {
                            randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_osu_wall.sh`;
                            randomWallProc.running = true;
                        }
                        StyledToolTip {
                            text: Translation.tr("Random osu! seasonal background\nImage is saved to ~/Pictures/Wallpapers")
                        }
                    }
                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        materialIcon: "wallpaper"
                        StyledToolTip {
                            text: Translation.tr("Pick wallpaper image on your system")
                        }
                        onClicked: {
                            Quickshell.execDetached(`${Directories.wallpaperSwitchScriptPath}`);
                        }
                        mainContentComponent: Component {
                            RowLayout {
                                spacing: 10
                                StyledText {
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    text: Translation.tr("Choose file")
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                                RowLayout {
                                    spacing: 3
                                    KeyboardKey {
                                        key: "Ctrl"
                                    }
                                    KeyboardKey {
                                        key: "Alt"
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: "+"
                                    }
                                    KeyboardKey {
                                        key: "T"
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        uniformCellSizes: true

                        SmallLightDarkPreferenceButton {
                            Layout.fillHeight: true
                            dark: false
                        }
                        SmallLightDarkPreferenceButton {
                            Layout.fillHeight: true
                            dark: true
                        }
                    }
                }
            }

            ConfigSelectionArray {
                currentValue: Config.options.appearance.palette.type
                onSelected: newValue => {
                    Config.options.appearance.palette.type = newValue;
                    Quickshell.execDetached(["/usr/bin/bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
                }
                options: [
                    {
                        "value": "auto",
                        "displayName": Translation.tr("Auto")
                    },
                    {
                        "value": "scheme-content",
                        "displayName": Translation.tr("Content")
                    },
                    {
                        "value": "scheme-expressive",
                        "displayName": Translation.tr("Expressive")
                    },
                    {
                        "value": "scheme-fidelity",
                        "displayName": Translation.tr("Fidelity")
                    },
                    {
                        "value": "scheme-fruit-salad",
                        "displayName": Translation.tr("Fruit Salad")
                    },
                    {
                        "value": "scheme-monochrome",
                        "displayName": Translation.tr("Monochrome")
                    },
                    {
                        "value": "scheme-neutral",
                        "displayName": Translation.tr("Neutral")
                    },
                    {
                        "value": "scheme-rainbow",
                        "displayName": Translation.tr("Rainbow")
                    },
                    {
                        "value": "scheme-tonal-spot",
                        "displayName": Translation.tr("Tonal Spot")
                    }
                ]
            }

            SettingsSwitch {
                buttonIcon: "ev_shadow"
                text: Translation.tr("Transparency")
                checked: Config.options.appearance.transparency.enable
                onCheckedChanged: {
                    Config.options.appearance.transparency.enable = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Might look ass. Unsupported.")
                }
            }

            // Quick wallpaper grid
            ContentSubsection {
                title: Translation.tr("Quick select")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Browse local wallpapers for a quick change")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        Item { Layout.fillWidth: true }
                        RippleButtonWithIcon {
                            buttonRadius: Appearance.rounding.full
                            materialIcon: "folder_open"
                            mainText: Translation.tr("Use current folder")
                            onClicked: {
                                const currentPath = Config.options.background.wallpaperPath;
                                if (currentPath && currentPath.length) {
                                    Wallpapers.setDirectory(FileUtils.parentDirectory(currentPath));
                                } else {
                                    Wallpapers.setDirectory(Wallpapers.defaultFolder.toString());
                                }
                            }
                        }
                        RippleButtonWithIcon {
                            buttonRadius: Appearance.rounding.full
                            materialIcon: "apps"
                            mainText: Translation.tr("Open selector")
                            onClicked: {
                                Config.options.wallpaperSelector.selectionTarget = "main";
                                Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"]);
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Folder:")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            font.pixelSize: Appearance.font.pixelSize.small
                            text: FileUtils.trimFileProtocol(Wallpapers.effectiveDirectory)
                            color: Appearance.colors.colOnLayer1
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        // Dynamic height: min 120, max 400, based on content rows
                        Layout.preferredHeight: {
                            const itemCount = Wallpapers.folderModel?.count ?? 0
                            if (itemCount === 0) return 120
                            const cols = Math.max(1, Math.floor((width - 2 * Appearance.sizes.spacingSmall) / 110))
                            const rows = Math.ceil(itemCount / cols)
                            const cellH = ((width - 2 * Appearance.sizes.spacingSmall) / cols) * 0.67
                            return Math.min(400, Math.max(120, rows * cellH + 2 * Appearance.sizes.spacingSmall))
                        }
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer0
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border
                        clip: true

                        GridView {
                            id: wallpaperGrid
                            anchors.fill: parent
                            anchors.margins: Appearance.sizes.spacingSmall
                            model: Wallpapers.folderModel

                            // Responsive cell sizing - fill available width
                            property int minCellWidth: 110
                            property int columns: Math.max(1, Math.floor(width / minCellWidth))
                            cellWidth: width / columns
                            cellHeight: cellWidth * 0.67  // 3:2 aspect ratio

                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            cacheBuffer: cellHeight * 2
                            property int currentHoverIndex: -1
                            ScrollBar.vertical: StyledScrollBar { policy: wallpaperGrid.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

                            delegate: Item {
                                id: delegateItem
                                required property int index
                                required property bool fileIsDir
                                required property string filePath
                                required property string fileName
                                required property url fileUrl

                                width: wallpaperGrid.cellWidth
                                height: wallpaperGrid.cellHeight

                                QuickWallpaperItem {
                                    anchors.fill: parent
                                    fileModelData: ({
                                        filePath: delegateItem.filePath,
                                        fileName: delegateItem.fileName,
                                        fileIsDir: delegateItem.fileIsDir,
                                        fileUrl: delegateItem.fileUrl
                                    })
                                    isSelected: !delegateItem.fileIsDir && delegateItem.filePath === Config.options.background.wallpaperPath
                                    isHovered: delegateItem.index === wallpaperGrid.currentHoverIndex

                                    onEntered: wallpaperGrid.currentHoverIndex = delegateItem.index
                                    onExited: if (wallpaperGrid.currentHoverIndex === delegateItem.index) wallpaperGrid.currentHoverIndex = -1
                                    onActivated: {
                                        if (delegateItem.fileIsDir) {
                                            Wallpapers.setDirectory(delegateItem.filePath);
                                        } else {
                                            Wallpapers.select(delegateItem.filePath);
                                        }
                                    }
                                }
                            }
                        }

                        // Empty state
                        PagePlaceholder {
                            shown: Wallpapers.folderModel.count === 0
                            icon: "image"
                            description: Translation.tr("No images found")
                            shape: MaterialShape.Shape.Cookie7Sided
                        }
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "screenshot_monitor"
        title: Translation.tr("Bar & screen")

        SettingsGroup {
            ConfigRow {
                ContentSubsection {
                    title: Translation.tr("Bar position")
                    ConfigSelectionArray {
                        currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                        onSelected: newValue => {
                            Config.options.bar.bottom = (newValue & 1) !== 0;
                            Config.options.bar.vertical = (newValue & 2) !== 0;
                        }
                        options: [
                            {
                                displayName: Translation.tr("Top"),
                                icon: "arrow_upward",
                                value: 0 // bottom: false, vertical: false
                            },
                            {
                                displayName: Translation.tr("Left"),
                                icon: "arrow_back",
                                value: 2 // bottom: false, vertical: true
                            },
                            {
                                displayName: Translation.tr("Bottom"),
                                icon: "arrow_downward",
                                value: 1 // bottom: true, vertical: false
                            },
                            {
                                displayName: Translation.tr("Right"),
                                icon: "arrow_forward",
                                value: 3 // bottom: true, vertical: true
                            }
                        ]
                    }
                }
                ContentSubsection {
                    title: Translation.tr("Bar style")

                    ConfigSelectionArray {
                        currentValue: Config.options.bar.cornerStyle
                        onSelected: newValue => {
                            Config.options.bar.cornerStyle = newValue; // Update local copy
                        }
                        options: [
                            {
                                displayName: Translation.tr("Hug"),
                                icon: "line_curve",
                                value: 0
                            },
                            {
                                displayName: Translation.tr("Float"),
                                icon: "page_header",
                                value: 1
                            },
                            {
                                displayName: Translation.tr("Rect"),
                                icon: "toolbar",
                                value: 2
                            }
                        ]
                    }
                }
            }

            ConfigRow {
                ContentSubsection {
                    title: Translation.tr("Screen round corner")

                    ConfigSelectionArray {
                        currentValue: Config.options.appearance.fakeScreenRounding
                        onSelected: newValue => {
                            Config.options.appearance.fakeScreenRounding = newValue;
                        }
                        options: [
                            {
                                displayName: Translation.tr("No"),
                                icon: "close",
                                value: 0
                            },
                            {
                                displayName: Translation.tr("Yes"),
                                icon: "check",
                                value: 1
                            },
                            {
                                displayName: Translation.tr("When not fullscreen"),
                                icon: "fullscreen_exit",
                                value: 2
                            }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Wallpaper mode")

                    ConfigSelectionArray {
                        currentValue: Config.options?.background?.backdrop?.hideWallpaper ? 1 : 0
                        onSelected: newValue => {
                            if (!Config.options.background) Config.options.background = ({});
                            if (!Config.options.background.backdrop) Config.options.background.backdrop = ({});
                            Config.options.background.backdrop.hideWallpaper = (newValue === 1);
                        }
                        options: [
                            {
                                displayName: Translation.tr("Normal"),
                                icon: "image",
                                value: 0
                            },
                            {
                                displayName: Translation.tr("Backdrop only"),
                                icon: "blur_on",
                                value: 1
                            }
                        ]
                    }
                }
            }
        }
    }

    // Game Mode
    SettingsCardSection {
        expanded: false
        icon: "sports_esports"
        title: Translation.tr("Game Mode")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "fullscreen"
                text: Translation.tr("Auto-detect fullscreen")
                checked: Config.options?.gameMode?.autoDetect ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.autoDetect", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Automatically enable Game Mode when apps go fullscreen")
                }
            }

            SettingsSwitch {
                buttonIcon: "animation"
                text: Translation.tr("Disable animations")
                checked: Config.options?.gameMode?.disableAnimations ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.disableAnimations", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Turn off UI animations when Game Mode is active")
                }
            }

            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Disable effects")
                checked: Config.options?.gameMode?.disableEffects ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.disableEffects", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Turn off blur and shadows when Game Mode is active")
                }
            }

            SettingsSwitch {
                buttonIcon: "desktop_windows"
                text: Translation.tr("Disable Niri animations")
                checked: Config.options?.gameMode?.disableNiriAnimations ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.disableNiriAnimations", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Turn off compositor animations when Game Mode is active")
                }
            }

            SettingsSwitch {
                buttonIcon: "visibility_off"
                text: Translation.tr("Minimal mode")
                checked: Config.options?.gameMode?.minimalMode ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.minimalMode", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Make panels transparent and hide backgrounds for maximum performance")
                }
            }
        }
    }

    // Quick Actions
    SettingsCardSection {
        expanded: false
        icon: "bolt"
        title: Translation.tr("Quick Actions")

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.spacingSmall

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "refresh"
                    mainText: Translation.tr("Reload shell")
                    onClicked: Quickshell.execDetached(["/usr/bin/setsid", "/usr/bin/fish", "-c", "qs kill -c ii; sleep 0.3; qs -c ii"])
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "terminal"
                    mainText: Translation.tr("Open config")
                    onClicked: Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`)
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "keyboard"
                    mainText: Translation.tr("Shortcuts")
                    onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "cheatsheet", "toggle"])
                }
            }

            SettingsSwitch {
                buttonIcon: "notifications_active"
                text: Translation.tr("Show reload toasts")
                checked: Config.options?.reloadToasts?.enable ?? true
                onCheckedChanged: {
                    if (!Config.options.reloadToasts) Config.options.reloadToasts = ({})
                    Config.options.reloadToasts.enable = checked
                }
                StyledToolTip {
                    text: Translation.tr("Show toast notifications when Quickshell or Niri config reloads.\nErrors are always shown.")
                }
            }

            SettingsSwitch {
                buttonIcon: "sports_esports"
                text: Translation.tr("Hide reload toasts in Game Mode")
                checked: Config.options?.gameMode?.disableReloadToasts ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.disableReloadToasts", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Automatically suppress reload toasts when Game Mode is active")
                }
            }

            SettingsSwitch {
                buttonIcon: "help"
                text: Translation.tr("Confirm before closing windows")
                checked: Config.options?.closeConfirm?.enabled ?? false
                onCheckedChanged: {
                    Config.setNestedValue("closeConfirm.enabled", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Show a confirmation dialog when closing windows with Super+Q")
                }
            }
        }
    }

    // Subtle footer
    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.sizes.spacingSmall
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        opacity: 0.6
        text: Translation.tr("More options in other tabs • Config: %1").arg(FileUtils.trimFileProtocol(Directories.shellConfigPath))
    }
}
