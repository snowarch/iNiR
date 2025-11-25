import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    forceWidth: true
    settingsPageIndex: 0
    settingsPageName: Translation.tr("Quick")

    Component.onCompleted: {
        Wallpapers.load()
    }

    Process {
        id: randomWallProc
        property string status: ""
        property string scriptPath: `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`
        command: ["bash", "-c", FileUtils.trimFileProtocol(randomWallProc.scriptPath)]
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
            Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`]);
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
    ContentSection {
        icon: "format_paint"
        title: Translation.tr("Wallpaper & Colors")
        Layout.fillWidth: true

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
                    source: Config.options.background.wallpaperPath
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
                Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
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

        ConfigSwitch {
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
                            Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"]);
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

                GridView {
                    id: wallpaperGrid
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    model: Wallpapers.folderModel
                    cellWidth: 140
                    cellHeight: 80
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    delegate: Rectangle {
                        required property bool fileIsDir
                        required property string filePath
                        required property url fileUrl

                        width: wallpaperGrid.cellWidth
                        height: wallpaperGrid.cellHeight
                        radius: Appearance.rounding.small
                        color: fileIsDir
                               ? ColorUtils.transparentize(Appearance.colors.colLayer1, 0.5)
                               : ColorUtils.transparentize(Appearance.colors.colLayer1, 0.2)
                        border.width: !fileIsDir && filePath === Config.options.background.wallpaperPath ? 2 : 0
                        border.color: Appearance.colors.colPrimary

                        StyledImage {
                            anchors.fill: parent
                            visible: !fileIsDir
                            source: fileUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: width
                            sourceSize.height: height
                        }

                        MaterialSymbol {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            visible: !fileIsDir && filePath === Config.options.background.wallpaperPath
                            text: "check_circle"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colPrimary
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4
                            visible: fileIsDir

                            RowLayout {
                                spacing: 4
                                MaterialSymbol {
                                    visible: fileIsDir
                                    text: "folder"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer0
                                }
                                StyledText {
                                    visible: fileIsDir
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    text: FileUtils.fileNameForPath(filePath)
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (fileIsDir) {
                                    Wallpapers.setDirectory(filePath);
                                } else {
                                    Wallpapers.select(filePath);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "screenshot_monitor"
        title: Translation.tr("Bar & screen")

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
            
        }
    }

    NoticeBox {
        Layout.fillWidth: true
        text: Translation.tr('Not all options are available in this app. You should also check the config file by hitting the "Config file" button on the topleft corner or opening %1 manually.').arg(Directories.shellConfigPath)

        Item {
            Layout.fillWidth: true
        }
        RippleButtonWithIcon {
            id: copyPathButton
            property bool justCopied: false
            Layout.fillWidth: false
            buttonRadius: Appearance.rounding.small
            materialIcon: justCopied ? "check" : "content_copy"
            mainText: justCopied ? Translation.tr("Path copied") : Translation.tr("Copy path")
            onClicked: {
                copyPathButton.justCopied = true
                Quickshell.clipboardText = FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                revertTextTimer.restart();
            }
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
            colRipple: Appearance.colors.colPrimaryContainerActive

            Timer {
                id: revertTextTimer
                interval: 1500
                onTriggered: {
                    copyPathButton.justCopied = false
                }
            }
        }
    }
}
