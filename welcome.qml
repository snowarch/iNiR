//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
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
            Translation.tr("Press Super+/ for all keyboard shortcuts."),
            "-a", "Shell"
        ]);
        Qt.quit();
    }
    title: Translation.tr("ii on Niri - Welcome")

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0
    }

    minimumWidth: 600
    minimumHeight: 400
    width: 900
    height: 650
    color: Appearance.m3colors.m3background

    Process {
        id: konachanWallProc
        property string status: ""
        command: [Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")]
        stdout: SplitParser {
            onRead: data => {
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
            visible: Config.options?.windows?.showTitlebar ?? true
            Layout.fillWidth: true
            implicitHeight: Math.max(welcomeText.implicitHeight, windowControlsRow.implicitHeight)
            StyledText {
                id: welcomeText
                anchors {
                    left: (Config.options?.windows?.centerTitle ?? false) ? undefined : parent.left
                    horizontalCenter: (Config.options?.windows?.centerTitle ?? false) ? parent.horizontalCenter : undefined
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
            RowLayout {
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: Translation.tr("Show next time")
                }
                StyledSwitch {
                    checked: root.showNextTime
                    scale: 0.6
                    Layout.alignment: Qt.AlignVCenter
                    onCheckedChanged: {
                        if (checked) {
                            Quickshell.execDetached(["rm", root.firstRunFilePath]);
                        } else {
                            Quickshell.execDetached(["fish", "-c", `echo '${StringUtils.shellSingleQuoteEscape(root.firstRunFileContent)}' > '${StringUtils.shellSingleQuoteEscape(root.firstRunFilePath)}'`]);
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
                        text: Translation.tr("Tip: Close windows with Super+Q")
                    }
                }
            }
        }

        Rectangle {
            color: Appearance.m3colors.m3surfaceContainerLow
            radius: Appearance.rounding.windowRounding - root.contentPadding
            implicitHeight: contentColumn.implicitHeight
            implicitWidth: contentColumn.implicitWidth
            Layout.fillWidth: true
            Layout.fillHeight: true

            ContentPage {
                id: contentColumn
                anchors.fill: parent

                // ══════════════════════════════════════════════════════════════
                // 1. STYLE & WALLPAPER
                // ══════════════════════════════════════════════════════════════
                ContentSection {
                    icon: "format_paint"
                    title: Translation.tr("Style & wallpaper")

                    ButtonGroup {
                        Layout.alignment: Qt.AlignHCenter
                        LightDarkPreferenceButton { dark: false }
                        LightDarkPreferenceButton { dark: true }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        RippleButtonWithIcon {
                            visible: (Config.options?.policies?.weeb ?? 0) >= 1
                            buttonRadius: Appearance.rounding.small
                            materialIcon: "ifl"
                            mainText: konachanWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: Konachan")
                            onClicked: { konachanWallProc.running = true; }
                            StyledToolTip {
                                text: Translation.tr("Random SFW Anime wallpaper from Konachan\nImage is saved to ~/Pictures/Wallpapers")
                            }
                        }
                        RippleButtonWithIcon {
                            materialIcon: "wallpaper"
                            mainText: Translation.tr("Choose wallpaper")
                            onClicked: {
                                Quickshell.execDetached([`${Directories.wallpaperSwitchScriptPath}`]);
                            }
                        }
                    }

                    NoticeBox {
                        Layout.fillWidth: true
                        text: Translation.tr("Tip: Type /dark, /light or /wallpaper in the overview search (Super+Space).")
                    }
                }

                // ══════════════════════════════════════════════════════════════
                // 2. KEYBINDS
                // ══════════════════════════════════════════════════════════════
                ContentSection {
                    icon: "keyboard"
                    title: Translation.tr("Getting started")

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

                        ShortcutRow { keys: ["Super", "Space"]; desc: Translation.tr("Search & launch apps") }
                        ShortcutRow { keys: ["Alt", "Tab"]; desc: Translation.tr("Switch windows") }
                        ShortcutRow { keys: ["Super", "Q"]; desc: Translation.tr("Close window") }
                        ShortcutRow { keys: ["Super", "V"]; desc: Translation.tr("Clipboard") }
                        ShortcutRow { keys: ["Super", "Slash"]; desc: Translation.tr("All shortcuts") }
                        ShortcutRow { keys: ["Super", "Comma"]; desc: Translation.tr("Settings") }
                    }
                }

                // ══════════════════════════════════════════════════════════════
                // 3. BAR
                // ══════════════════════════════════════════════════════════════
                ContentSection {
                    icon: "screenshot_monitor"
                    title: Translation.tr("Bar")

                    ConfigRow {
                        ContentSubsection {
                            title: Translation.tr("Bar position")
                            ConfigSelectionArray {
                                currentValue: ((Config.options?.bar?.bottom ?? false) ? 1 : 0) | ((Config.options?.bar?.vertical ?? false) ? 2 : 0)
                                onSelected: newValue => {
                                    Config.setNestedValue("bar.bottom", (newValue & 1) !== 0);
                                    Config.setNestedValue("bar.vertical", (newValue & 2) !== 0);
                                }
                                options: [
                                    { displayName: Translation.tr("Top"), icon: "arrow_upward", value: 0 },
                                    { displayName: Translation.tr("Left"), icon: "arrow_back", value: 2 },
                                    { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                                    { displayName: Translation.tr("Right"), icon: "arrow_forward", value: 3 }
                                ]
                            }
                        }
                        ContentSubsection {
                            title: Translation.tr("Bar style")
                            ConfigSelectionArray {
                                currentValue: Config.options?.bar?.cornerStyle ?? 0
                                onSelected: newValue => {
                                    Config.setNestedValue("bar.cornerStyle", newValue);
                                }
                                options: [
                                    { displayName: Translation.tr("Hug"), icon: "line_curve", value: 0 },
                                    { displayName: Translation.tr("Float"), icon: "page_header", value: 1 },
                                    { displayName: Translation.tr("Rect"), icon: "toolbar", value: 2 }
                                ]
                            }
                        }
                    }

                    ContentSubsection {
                        title: Translation.tr("Wallpaper mode")
                        ConfigSelectionArray {
                            currentValue: (Config.options?.background?.backdrop?.hideWallpaper ?? false) ? 1 : 0
                            onSelected: newValue => {
                                Config.setNestedValue("background.backdrop.hideWallpaper", newValue === 1);
                            }
                            options: [
                                { displayName: Translation.tr("Normal"), icon: "image", value: 0 },
                                { displayName: Translation.tr("Backdrop only"), icon: "blur_on", value: 1 }
                            ]
                        }
                    }
                }

                // ══════════════════════════════════════════════════════════════
                // 4. PREFERENCES
                // ══════════════════════════════════════════════════════════════
                ContentSection {
                    icon: "tune"
                    title: Translation.tr("Preferences")

                    ConfigRow {
                        Layout.fillWidth: true

                        ContentSubsection {
                            title: Translation.tr("Anime wallpapers")
                            ConfigSelectionArray {
                                currentValue: Config.options?.policies?.weeb ?? 0
                                onSelected: newValue => {
                                    Config.setNestedValue("policies.weeb", newValue);
                                }
                                options: [
                                    { displayName: Translation.tr("Off"), icon: "close", value: 0 },
                                    { displayName: Translation.tr("On"), icon: "check", value: 1 }
                                ]
                            }
                        }

                        ContentSubsection {
                            title: Translation.tr("AI features")
                            ConfigSelectionArray {
                                currentValue: Config.options?.policies?.ai ?? 0
                                onSelected: newValue => {
                                    Config.setNestedValue("policies.ai", newValue);
                                }
                                options: [
                                    { displayName: Translation.tr("Off"), icon: "close", value: 0 },
                                    { displayName: Translation.tr("On"), icon: "check", value: 1 },
                                    { displayName: Translation.tr("Local"), icon: "computer", value: 2 }
                                ]
                            }
                        }
                    }
                }

                // ══════════════════════════════════════════════════════════════
                // 5. RESOURCES
                // ══════════════════════════════════════════════════════════════
                ContentSection {
                    icon: "info"
                    title: Translation.tr("Resources")

                    Flow {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 720
                        spacing: 5

                        RippleButtonWithIcon {
                            materialIcon: "tune"
                            mainText: Translation.tr("Open Settings")
                            onClicked: {
                                Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "settings", "open"]);
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
                            nerdIcon: "󰊤"
                            mainText: "GitHub"
                            onClicked: {
                                Qt.openUrlExternally("https://github.com/snowarch/quickshell-ii-niri");
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
