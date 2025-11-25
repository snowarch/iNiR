//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ApplicationWindow {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false
    visible: true
    onClosing: {
        Quickshell.execDetached([
            "notify-send",
            Translation.tr("Welcome app"),
            Translation.tr("Enjoy! Press <tt>Super+G</tt> for the overlay and <tt>Alt+Tab</tt> to switch windows.\nOpen Settings from the right sidebar (<tt>Super+N</tt>)."),
            "-a", "Shell"
        ]);
        Qt.quit();
    }
    title: Translation.tr("ii on Niri - Welcome")

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0 // Welcome app always only sets one var at a time so delay isn't needed
    }

    minimumWidth: 600
    minimumHeight: 400
    width: 900
    height: 650
    color: Appearance.m3colors.m3background

    Process {
        id: konachanWallProc
        property string status: ""
        command: ["bash", "-c", Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")]
        stdout: SplitParser {
            onRead: data => {
                console.log(`Konachan wall proc output: ${data}`);
                konachanWallProc.status = data.trim();
            }
        }
    }


    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Item {
            // Titlebar
            visible: Config.options?.windows.showTitlebar
            Layout.fillWidth: true
            implicitHeight: Math.max(welcomeText.implicitHeight, windowControlsRow.implicitHeight)
            StyledText {
                id: welcomeText
                anchors {
                    left: Config.options.windows.centerTitle ? undefined : parent.left
                    horizontalCenter: Config.options.windows.centerTitle ? parent.horizontalCenter : undefined
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                color: Appearance.colors.colOnLayer0
                text: Translation.tr("Welcome to ii on Niri")
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }
            RowLayout { // Window controls row
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: Translation.tr("Show next time")
                }
                StyledSwitch {
                    id: showNextTimeSwitch
                    checked: root.showNextTime
                    scale: 0.6
                    Layout.alignment: Qt.AlignVCenter
                    onCheckedChanged: {
                        if (checked) {
                            Quickshell.execDetached(["rm", root.firstRunFilePath]);
                        } else {
                            Quickshell.execDetached(["bash", "-c", `echo '${StringUtils.shellSingleQuoteEscape(root.firstRunFileContent)}' > '${StringUtils.shellSingleQuoteEscape(root.firstRunFilePath)}'`]);
                        }
                    }
                }
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }

                    StyledToolTip {
                        text: Translation.tr("Tip: Close windows with Mod+Q")
                    }
                }
            }
        }

        Rectangle {
            // Content container
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding - root.contentPadding
            implicitHeight: contentColumn.implicitHeight
            implicitWidth: contentColumn.implicitWidth
            Layout.fillWidth: true
            Layout.fillHeight: true

            ContentPage {
                id: contentColumn
                anchors.fill: parent


                ContentSection {
                    icon: "keyboard"
                    title: Translation.tr("Keybinds (ii on Niri)")

                    component ShortcutRow: RowLayout {
                        required property var keys
                        required property string desc
                        spacing: 6
                        RowLayout {
                            Layout.minimumWidth: 150
                            spacing: 2
                            Repeater {
                                model: keys
                                delegate: RowLayout {
                                    spacing: 2
                                    KeyboardKey { key: modelData }
                                    StyledText {
                                        visible: index < keys.length - 1
                                        text: "+"
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                    }
                                }
                            }
                        }
                        StyledText {
                            text: desc
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 24
                        rowSpacing: 6

                        ShortcutRow { keys: ["Super"]; desc: Translation.tr("Overview (tap)") }
                        ShortcutRow { keys: ["Alt", "Tab"]; desc: Translation.tr("Switch windows") }
                        ShortcutRow { keys: ["Super", "G"]; desc: Translation.tr("ii overlay") }
                        ShortcutRow { keys: ["Mod", "V"]; desc: Translation.tr("Clipboard manager") }
                        ShortcutRow { keys: ["Mod", "Q"]; desc: Translation.tr("Close window") }
                        ShortcutRow { keys: ["Ctrl", "Alt", "T"]; desc: Translation.tr("Wallpaper selector") }
                        ShortcutRow { keys: ["Mod", "Alt", "L"]; desc: Translation.tr("Lock screen") }
                        ShortcutRow { keys: ["Mod", "Tab"]; desc: Translation.tr("Niri overview") }
                    }
                }


                ContentSection {
                    icon: "overview_key"
                    title: Translation.tr("Quick setup")

                    ContentSubsection {
                        title: Translation.tr("Overview & overlay")

                        ConfigRow {
                            ConfigSwitch {
                                buttonIcon: "overview_key"
                                text: Translation.tr("Enable overview grid")
                                checked: Config.options.overview.enable
                                onCheckedChanged: {
                                    Config.options.overview.enable = checked;
                                }
                            }
                            ConfigSwitch {
                                buttonIcon: "opacity"
                                text: Translation.tr("Darken screen behind overlay")
                                checked: Config.options.overlay.darkenScreen
                                onCheckedChanged: {
                                    Config.options.overlay.darkenScreen = checked;
                                }
                            }
                        }

                        ConfigRow {
                            ConfigSpinBox {
                                icon: "loupe"
                                text: Translation.tr("Overview scale (%)")
                                value: Config.options.overview.scale * 100
                                from: 50
                                to: 150
                                stepSize: 5
                                onValueChanged: {
                                    Config.options.overview.scale = value / 100;
                                }
                            }
                            ConfigSpinBox {
                                icon: "opacity"
                                text: Translation.tr("Overlay scrim dim (%)")
                                value: Config.options.overlay.scrimDim
                                from: 0
                                to: 100
                                stepSize: 5
                                enabled: Config.options.overlay.darkenScreen
                                onValueChanged: {
                                    Config.options.overlay.scrimDim = value;
                                }
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "screenshot_monitor"
                    title: Translation.tr("Bar")

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
                }

                ContentSection {
                    icon: "format_paint"
                    title: Translation.tr("Style & wallpaper")

                    ButtonGroup {
                        Layout.alignment: Qt.AlignHCenter
                        LightDarkPreferenceButton {
                            dark: false
                        }
                        LightDarkPreferenceButton {
                            dark: true
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        RippleButtonWithIcon {
                            id: rndWallBtn
                            visible: Config.options.policies.weeb === 1
                            Layout.alignment: Qt.AlignHCenter
                            buttonRadius: Appearance.rounding.small
                            materialIcon: "ifl"
                            mainText: konachanWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: Konachan")
                            onClicked: {
                                console.log(konachanWallProc.command.join(" "));
                                konachanWallProc.running = true;
                            }
                            StyledToolTip {
                                text: Translation.tr("Random SFW Anime wallpaper from Konachan\nImage is saved to ~/Pictures/Wallpapers")
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "wallpaper"
                            StyledToolTip {
                                text: Translation.tr("Pick wallpaper image on your system")
                            }
                            onClicked: {
                                Quickshell.execDetached([`${Directories.wallpaperSwitchScriptPath}`]);
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
                    }

                    NoticeBox {
                        Layout.fillWidth: true
                        text: Translation.tr("Change anytime with /dark, /light, /wallpaper in the overview search.\nIf colors don't update, reload ii from the right sidebar (Super+N).")
                    }
                }

                ContentSection {
                    icon: "rule"
                    title: Translation.tr("Policies")

                    ConfigRow {
                        Layout.fillWidth: true

                        ContentSubsection {
                            title: "Weeb"

                            ConfigSelectionArray {
                                currentValue: Config.options.policies.weeb
                                onSelected: newValue => {
                                    Config.options.policies.weeb = newValue;
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
                                        displayName: Translation.tr("Closet"),
                                        icon: "ev_shadow",
                                        value: 2
                                    }
                                ]
                            }
                        }

                        ContentSubsection {
                            title: "AI"

                            ConfigSelectionArray {
                                currentValue: Config.options.policies.ai
                                onSelected: newValue => {
                                    Config.options.policies.ai = newValue;
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
                                        displayName: Translation.tr("Local only"),
                                        icon: "sync_saved_locally",
                                        value: 2
                                    }
                                ]
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "info"
                    title: Translation.tr("Info")

                    Flow {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 720
                        spacing: 5

                        RippleButtonWithIcon {
                            materialIcon: "tune"
                            mainText: Translation.tr("Open Settings")
                            onClicked: {
                                Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")]);
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "article"
                            mainText: Translation.tr("Niri Wiki")
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/YaLTeR/niri/wiki");
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "help"
                            mainText: Translation.tr("ii Wiki")
                            onClicked: {
                                Qt.openUrlExternally("https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/02usage/");
                            }
                        }
                    }
                }

                ContentSection {
                    icon: "link"
                    title: Translation.tr("Links")

                    Flow {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 720
                        spacing: 5

                        RippleButtonWithIcon {
                            nerdIcon: "󰊤"
                            mainText: "GitHub (ii on Niri)"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/snowarch/quickshell-ii-niri");
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "favorite"
                            mainText: Translation.tr("Original ii by end-4")
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/end-4/dots-hyprland");
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }
}
