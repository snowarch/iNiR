import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    settingsPageIndex: 23
    settingsPageName: Translation.tr("Sidebars")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    property string activeSection: "general"

    SettingsTaskNavigator {
        icon: "side_navigation"
        title: Translation.tr("Sidebars")
        description: Translation.tr("Configure the sidebars in focused views: layout, widgets, media panels and edge opening behavior.")
        summary: Translation.tr("General \u00b7 Left \u00b7 Right \u00b7 Media \u00b7 Opening")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        options: [
            { displayName: Translation.tr("General"), icon: "tune", value: "general" },
            { displayName: Translation.tr("Left sidebar"), icon: "first_page", value: "left" },
            { displayName: Translation.tr("Right sidebar"), icon: "last_page", value: "right" },
            { displayName: Translation.tr("Media & content"), icon: "music_note", value: "media" },
            { displayName: Translation.tr("Opening"), icon: "swipe", value: "open" }
        ]
    }

    SettingsCardSection {
        settingsTaskSection: "general"
        visible: root.isIiActive && !(Config.options?.settingsUi?.easyMode ?? false) && root.activeSection === "general"
        expanded: true
        icon: "tune"
        title: Translation.tr("General")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("General")

                ConfigSelectionArray {
                    currentValue: Config.options?.sidebar?.style ?? "panel"
                    onSelected: newValue => {
                        Config.setNestedValue("sidebar.style", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("Panel"), icon: "side_navigation", value: "panel" },
                        { displayName: Translation.tr("Island"), icon: "blur_on", value: "island" }
                    ]
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Island wraps both sidebars in the gradient card look used by the island bar and dock.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                SettingsSwitch {
                    buttonIcon: "branding_watermark"
                    text: Translation.tr("Use Card style")
                    enabled: Appearance.globalStyle === "material" || Appearance.globalStyle === "inir"
                    checked: Config.options.sidebar?.cardStyle ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("sidebar.cardStyle", checked);
                    }
                    StyledToolTip {
                        text: (Appearance.globalStyle === "material" || Appearance.globalStyle === "inir")
                            ? Translation.tr("Apply rounded card styling to sidebars")
                            : Translation.tr("Only available with Material or Inir global style")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "unfold_less"
                    text: Translation.tr("Collapse notifications when empty")
                    checked: Config.options.sidebar?.collapseEmptyNotifications ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.collapseEmptyNotifications", checked)
                    StyledToolTip {
                        text: Translation.tr("Shrink the right sidebar when there are no notifications")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "fit_screen"
                    text: Translation.tr("Fit left sidebar to widgets")
                    checked: Config.options.sidebar?.collapseWidgetsTab ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.collapseWidgetsTab", checked)
                    StyledToolTip {
                        text: Translation.tr("Shrink the left sidebar to its content on the Widgets tab instead of full height")
                    }
                }

                SidebarHeightPreview {
                    Layout.fillWidth: true
                }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Sidebar content is preserved after first use so searches, conversations and navigation resume where you left them.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                buttonIcon: "animation"
                text: Translation.tr("Instant sidebar opening")
                checked: Config.options.sidebar?.instantOpen ?? false
                onCheckedChanged: Config.setNestedValue("sidebar.instantOpen", checked)
                StyledToolTip {
                    text: Translation.tr("Skips the slide animation to reduce stutter under load.")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: !(Config.options?.sidebar?.instantOpen ?? false)
                spacing: 4

                RowLayout {
                    spacing: 8
                    MaterialSymbol {
                        text: "swipe_right"
                        iconSize: Appearance.font.pixelSize.hugeass
                        color: Appearance.m3colors?.m3OnSurface ?? Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Translation.tr("Sidebar animation")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors?.m3OnSurface ?? Appearance.colors.colOnLayer1
                    }
                }

                StyledComboBox {
                    Layout.fillWidth: true
                    readonly property var animOptions: [
                        { displayName: Translation.tr("Slide"), value: "slide" },
                        { displayName: Translation.tr("Fade"), value: "fade" },
                        { displayName: Translation.tr("Pop"), value: "pop" },
                        { displayName: Translation.tr("Reveal"), value: "reveal" },
                        { displayName: Translation.tr("Swing"), value: "swing" },
                        { displayName: Translation.tr("Drop"), value: "drop" },
                        { displayName: Translation.tr("Elastic"), value: "elastic" }
                    ]
                    model: animOptions
                    textRole: "displayName"
                    currentIndex: {
                        const current = Config.options?.sidebar?.animationType ?? "slide"
                        const idx = animOptions.findIndex(o => o.value === current)
                        return idx >= 0 ? idx : 0
                    }
                    onActivated: index => {
                        if (index >= 0 && index < animOptions.length)
                            Config.setNestedValue("sidebar.animationType", animOptions[index].value)
                    }
                }
            }

            SettingsSwitch {
                buttonIcon: "folder_open"
                text: Translation.tr("Open folder after wallpaper download")
                checked: Config.options.sidebar?.openFolderOnDownload ?? false
                onCheckedChanged: Config.setNestedValue("sidebar.openFolderOnDownload", checked)
                StyledToolTip {
                    text: Translation.tr("Open file manager when downloading wallpapers from Wallhaven or Booru")
                }
            }
            }


            ContentSubsection {
                title: Translation.tr("Arrange")
                tooltip: Translation.tr("Arrange sidebar sections, tab order and elastic heights")

                SidebarLayoutEditor {
                    Layout.fillWidth: true
                }
            }

        }
    }

    SettingsCardSection {
        settingsTaskSection: "left"
        visible: root.isIiActive && !(Config.options?.settingsUi?.easyMode ?? false) && root.activeSection === "left"
        expanded: true
        icon: "first_page"
        title: Translation.tr("Left sidebar")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Left Sidebar")
                tooltip: Translation.tr("Choose which tabs appear in the left sidebar")

                SettingsSwitch {
                    buttonIcon: "widgets"
                    text: Translation.tr("Widgets")
                    checked: Config.options.sidebar?.widgets?.enable ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Dashboard with clock, weather, media controls and quick actions")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "neurology"
                    text: Translation.tr("AI Chat")
                    readonly property int currentAiPolicy: Config.options?.policies?.ai ?? 0
                    checked: currentAiPolicy !== 0
                    onCheckedChanged: {
                        // Preserve "Local only" (2) if it was set, otherwise use "Yes" (1)
                        const newValue = checked ? (currentAiPolicy === 2 ? 2 : 1) : 0
                        Config.setNestedValue("policies.ai", newValue)
                    }
                    StyledToolTip {
                        text: Translation.tr("Chat with AI assistants (OpenAI, Gemini, local models)")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "translate"
                    text: Translation.tr("Translator")
                    checked: Config.options.sidebar?.translator?.enable ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.translator.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Translate text between languages")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "bookmark_heart"
                    text: Translation.tr("Anime")
                    readonly property int currentWeebPolicy: Config.options?.policies?.weeb ?? 0
                    checked: currentWeebPolicy !== 0
                    onCheckedChanged: {
                        // Preserve "Closet" (2) if it was set, otherwise use "Yes" (1)
                        const newValue = checked ? (currentWeebPolicy === 2 ? 2 : 1) : 0
                        Config.setNestedValue("policies.weeb", newValue)
                    }
                    StyledToolTip {
                        text: Translation.tr("Browse anime artwork from booru sites")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "image"
                    text: Translation.tr("Wallhaven")
                    checked: Config.options.sidebar?.wallhaven?.enable ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.wallhaven.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Browse and download wallpapers from Wallhaven")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "newspaper"
                    text: Translation.tr("News")
                    checked: Config.options.sidebar?.news?.enable ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.news.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Local and topic headlines from Google News")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "calendar_month"
                    text: Translation.tr("Anime Schedule")
                    checked: Config.options.sidebar?.animeSchedule?.enable ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.animeSchedule.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("View anime airing schedule, seasonal and top anime")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "build"
                    text: Translation.tr("Tools")
                    checked: Config.options.sidebar?.tools?.enable ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.tools.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Niri debug options and quick actions")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "store"
                    text: Translation.tr("Software")
                    checked: Config.options.sidebar?.software?.enable ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.software.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Browse and install curated companion apps")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "library_music"
                    text: Translation.tr("YT Music")
                    checked: Config.options.sidebar?.ytmusic?.enable ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.ytmusic.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Search and play music from YouTube using yt-dlp")
                    }
                }

                // DISABLED: webapps — requires quickshell-webengine rebuild
                // SettingsSwitch {
                //     buttonIcon: "extension"
                //     text: Translation.tr("Web Apps")
                //     checked: Config.options?.sidebar?.plugins?.enable ?? false
                //     onCheckedChanged: Config.setNestedValue("sidebar.plugins.enable", checked)
                //     StyledToolTip {
                //         text: Translation.tr("Embed web apps like Discord, YouTube Music and more in the sidebar (requires quickshell-webengine)")
                //     }
                // }
            }

        }
    }

    SettingsCardSection {
        settingsTaskSection: "right"
        visible: root.isIiActive && !(Config.options?.settingsUi?.easyMode ?? false) && root.activeSection === "right"
        expanded: true
        icon: "last_page"
        title: Translation.tr("Right sidebar")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Right sidebar header")
                tooltip: Translation.tr("Look of the system section at the top of the right sidebar")

                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options?.sidebar?.right?.headerStyle ?? "profile"
                    onSelected: newValue => {
                        Config.setNestedValue("sidebar.right.headerStyle", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("Profile card"), icon: "account_box", value: "profile" },
                        { displayName: Translation.tr("Classic"), icon: "view_agenda", value: "classic" }
                    ]
                }

                ContentSubsectionLabel {
                    visible: (Config.options?.sidebar?.right?.headerStyle ?? "profile") === "profile"
                    text: Translation.tr("Banner")
                }

                ConfigSelectionArray {
                    Layout.fillWidth: false
                    visible: (Config.options?.sidebar?.right?.headerStyle ?? "profile") === "profile"
                    currentValue: Config.options?.sidebar?.right?.headerBanner ?? "wallpaper"
                    onSelected: newValue => {
                        Config.setNestedValue("sidebar.right.headerBanner", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("Wallpaper"), icon: "wallpaper", value: "wallpaper" },
                        { displayName: Translation.tr("Custom media"), icon: "perm_media", value: "custom" },
                        { displayName: Translation.tr("Solid"), icon: "format_color_fill", value: "solid" },
                        { displayName: Translation.tr("None"), icon: "block", value: "none" }
                    ]
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: (Config.options?.sidebar?.right?.headerStyle ?? "profile") === "profile"
                        && (Config.options?.sidebar?.right?.headerBanner ?? "wallpaper") === "custom"

                    StyledText {
                        Layout.fillWidth: true
                        text: (Config.options?.sidebar?.right?.headerBannerPath ?? "").length > 0
                            ? Directories.shortHomePath(Config.options.sidebar.right.headerBannerPath)
                            : Translation.tr("No media selected")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideMiddle
                        wrapMode: Text.NoWrap
                    }

                    RippleButtonWithIcon {
                        materialIcon: "folder_open"
                        mainText: Translation.tr("Choose")
                        onClicked: bannerImageDialog.open()
                    }
                }

                FileDialog {
                    id: bannerImageDialog
                    title: Translation.tr("Choose header media")
                    fileMode: FileDialog.OpenFile
                    nameFilters: [
                        Translation.tr("Images and animations") + " (*.png *.jpg *.jpeg *.webp *.bmp *.avif *.gif *.mp4 *.webm *.mkv *.avi *.mov)",
                        Translation.tr("All files") + " (*)"
                    ]
                    onAccepted: Config.setNestedValue("sidebar.right.headerBannerPath",
                        FileUtils.trimFileProtocol(String(selectedFile)))
                }

                SettingsNativeDialogGuard {
                    dialog: bannerImageDialog
                    dialogKey: "sidebar-header-media"
                }
            }


            ContentSubsection {
                id: rightSidebarWidgets
                title: Translation.tr("Right Sidebar")
                tooltip: Translation.tr("Toggle which widgets appear in the right sidebar")

                readonly property var defaults: ["calendar", "todo", "notepad", "calculator", "sysmon", "weather", "timer"]

                function isEnabled(widgetId) {
                    return (Config.options?.sidebar?.right?.enabledWidgets ?? defaults).includes(widgetId)
                }

                function setWidget(widgetId, active) {
                    _log(`[RightSidebar] setWidget(${widgetId}, ${active})`)
                    let current = [...(Config.options?.sidebar?.right?.enabledWidgets ?? defaults)]
                    _log(`[RightSidebar] Current widgets:`, JSON.stringify(current))

                    if (active && !current.includes(widgetId)) {
                        current.push(widgetId)
                        _log(`[RightSidebar] Adding ${widgetId}, new array:`, JSON.stringify(current))
                        Config.setNestedValue("sidebar.right.enabledWidgets", current)
                    } else if (!active && current.includes(widgetId)) {
                        current.splice(current.indexOf(widgetId), 1)
                        _log(`[RightSidebar] Removing ${widgetId}, new array:`, JSON.stringify(current))
                        Config.setNestedValue("sidebar.right.enabledWidgets", current)
                    } else {
                        _log(`[RightSidebar] No change needed`)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "calendar_month"
                    text: Translation.tr("Calendar")
                    Component.onCompleted: checked = rightSidebarWidgets.isEnabled("calendar")
                    onClicked: {
                        // checked ya fue invertido por ConfigSwitch.onClicked
                        rightSidebarWidgets.setWidget("calendar", checked)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "event_upcoming"
                    text: Translation.tr("Events")
                    Component.onCompleted: checked = rightSidebarWidgets.isEnabled("events")
                    onClicked: {
                        rightSidebarWidgets.setWidget("events", checked)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "done_outline"
                    text: Translation.tr("To Do")
                    Component.onCompleted: checked = rightSidebarWidgets.isEnabled("todo")
                    onClicked: {
                        rightSidebarWidgets.setWidget("todo", checked)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "edit_note"
                    text: Translation.tr("Notepad")
                    Component.onCompleted: checked = rightSidebarWidgets.isEnabled("notepad")
                    onClicked: {
                        rightSidebarWidgets.setWidget("notepad", checked)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "calculate"
                    text: Translation.tr("Calculator")
                    Component.onCompleted: checked = rightSidebarWidgets.isEnabled("calculator")
                    onClicked: {
                        rightSidebarWidgets.setWidget("calculator", checked)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "monitor_heart"
                    text: Translation.tr("System Monitor")
                    Component.onCompleted: checked = rightSidebarWidgets.isEnabled("sysmon")
                    onClicked: {
                        rightSidebarWidgets.setWidget("sysmon", checked)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "partly_cloudy_day"
                    text: Translation.tr("Weather")
                    Component.onCompleted: checked = rightSidebarWidgets.isEnabled("weather")
                    onClicked: {
                        rightSidebarWidgets.setWidget("weather", checked)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "schedule"
                    text: Translation.tr("Timer")
                    Component.onCompleted: checked = rightSidebarWidgets.isEnabled("timer")
                    onClicked: {
                        rightSidebarWidgets.setWidget("timer", checked)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "av_timer"
                    text: Translation.tr("Screen Time")
                    Component.onCompleted: checked = rightSidebarWidgets.isEnabled("screentime")
                    onClicked: {
                        rightSidebarWidgets.setWidget("screentime", checked)
                        Config.setNestedValue("sidebar.screenTime.enable", checked)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Quick toggles")

                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.sidebar.quickToggles.style
                    onSelected: newValue => {
                        Config.setNestedValue("sidebar.quickToggles.style", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("Classic"), icon: "password_2", value: "classic" },
                        { displayName: Translation.tr("Android"), icon: "action_key", value: "android" }
                    ]
                }

                ConfigSpinBox {
                    enabled: Config.options.sidebar.quickToggles.style === "android"
                    icon: "splitscreen_left"
                    text: Translation.tr("Columns")
                    value: Config.options.sidebar.quickToggles.android.columns
                    from: 1
                    to: 8
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("sidebar.quickToggles.android.columns", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of columns for the Android-style quick settings grid")
                    }
                }
            }


            ContentSubsection {
                title: Translation.tr("Sliders")

                SettingsSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.sidebar.quickSliders.enable
                    onCheckedChanged: {
                        Config.setNestedValue("sidebar.quickSliders.enable", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show volume/brightness/mic sliders in the sidebar")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "brightness_6"
                    text: Translation.tr("Brightness")
                    enabled: Config.options.sidebar.quickSliders.enable
                    checked: Config.options.sidebar.quickSliders.showBrightness
                    onCheckedChanged: {
                        Config.setNestedValue("sidebar.quickSliders.showBrightness", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show brightness slider")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "volume_up"
                    text: Translation.tr("Volume")
                    enabled: Config.options.sidebar.quickSliders.enable
                    checked: Config.options.sidebar.quickSliders.showVolume
                    onCheckedChanged: {
                        Config.setNestedValue("sidebar.quickSliders.showVolume", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show volume slider")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "mic"
                    text: Translation.tr("Microphone")
                    enabled: Config.options.sidebar.quickSliders.enable
                    checked: Config.options.sidebar.quickSliders.showMic
                    onCheckedChanged: {
                        Config.setNestedValue("sidebar.quickSliders.showMic", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show microphone input level slider")
                    }
                }
            }

        }
    }

    SettingsCardSection {
        settingsTaskSection: "media"
        visible: root.isIiActive && !(Config.options?.settingsUi?.easyMode ?? false) && root.activeSection === "media"
        expanded: true
        icon: "music_note"
        title: Translation.tr("Media & content")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("YT Music")
                tooltip: Translation.tr("Control how next-track notifications behave")
                visible: Config.options.sidebar?.ytmusic?.enable ?? false

                SettingsSwitch {
                    buttonIcon: "sync"
                    text: Translation.tr("Reconnect account on launch")
                    checked: Config.options.sidebar?.ytmusic?.autoConnect ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.ytmusic.autoConnect", checked)
                    StyledToolTip {
                        text: Translation.tr("Re-reads your browser's YouTube session on startup so a stale login heals itself.")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "music_note"
                    text: Translation.tr("Up Next notifications")
                    checked: Config.options.sidebar?.ytmusic?.upNextNotifications ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.ytmusic.upNextNotifications", checked)
                    StyledToolTip {
                        text: Translation.tr("Show a desktop notification with the upcoming track when playback auto-advances")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "sports_esports"
                    text: Translation.tr("Mute while fullscreen or GameMode")
                    enabled: Config.options.sidebar?.ytmusic?.upNextNotifications ?? true
                    checked: Config.options.sidebar?.ytmusic?.suppressUpNextInFullscreen ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.ytmusic.suppressUpNextInFullscreen", checked)
                    StyledToolTip {
                        text: Translation.tr("Suppress Up Next notifications when a fullscreen app is active or GameMode is enabled")
                    }
                }

                ConfigSelectionArray {
                    options: [
                        { displayName: Translation.tr("Best"), icon: "high_quality", value: "best" },
                        { displayName: Translation.tr("Medium (≤128 kbps)"), icon: "graphic_eq", value: "medium" },
                        { displayName: Translation.tr("Low"), icon: "data_saver_on", value: "low" }
                    ]
                    currentValue: Config.options.sidebar?.ytmusic?.audioQuality ?? "best"
                    onSelected: (newValue) => Config.setNestedValue("sidebar.ytmusic.audioQuality", newValue)
                    StyledToolTip {
                        text: Translation.tr("Audio quality for playback — lower quality uses less bandwidth")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "graphic_eq"
                    text: Translation.tr("Normalize loudness")
                    checked: Config.options.sidebar?.ytmusic?.normalizeVolume ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.ytmusic.normalizeVolume", checked)
                    StyledToolTip {
                        text: Translation.tr("Even out volume across tracks (EBU R128, like YouTube Music). Disable for the unprocessed stream.")
                    }
                }
            }


            ContentSubsection {
                title: Translation.tr("Anime Schedule")
                visible: Config.options.sidebar?.animeSchedule?.enable ?? false

                SettingsSwitch {
                    buttonIcon: "visibility_off"
                    text: Translation.tr("Show NSFW")
                    checked: Config.options.sidebar?.animeSchedule?.showNsfw ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.animeSchedule.showNsfw", checked)
                    StyledToolTip {
                        text: Translation.tr("Include adult-rated anime in results")
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialSymbol {
                        text: "play_circle"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: Translation.tr("Watch site")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }

                        MaterialTextField {
                            Layout.fillWidth: true
                            placeholderText: "https://9animetv.to/search?keyword=%s"
                            text: Config.options.sidebar?.animeSchedule?.watchSite ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSurface
                            placeholderTextColor: Appearance.colors.colSubtext
                            background: Rectangle {
                                color: Appearance.colors.colLayer1
                                radius: Appearance.rounding.small
                                border.width: parent.activeFocus ? 2 : 1
                                border.color: parent.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                            }
                            onTextEdited: Config.setNestedValue("sidebar.animeSchedule.watchSite", text)

                            StyledToolTip {
                                text: Translation.tr("Custom streaming site URL. Use %s for search query.")
                            }
                        }
                    }
                }
            }


            ContentSubsection {
                title: Translation.tr("Booru download paths")
                visible: (Config.options?.policies?.weeb ?? 0) !== 0

                ContentSubsectionLabel {
                    text: Translation.tr("SFW download folder (empty = wallpapers dir)")
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Directories.wallpapersPath
                    text: Config.options?.sidebar?.booru?.downloadPath?.sfw ?? ""
                    onEditingFinished: Config.setNestedValue("sidebar.booru.downloadPath.sfw", text)
                }

                ContentSubsectionLabel {
                    text: Translation.tr("NSFW download folder (empty = wallpapers/pepper)")
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Directories.wallpapersPath + "/pepper"
                    text: Config.options?.sidebar?.booru?.downloadPath?.nsfw ?? ""
                    onEditingFinished: Config.setNestedValue("sidebar.booru.downloadPath.nsfw", text)
                }
            }


            ContentSubsection {
                title: Translation.tr("Wallhaven")
                visible: Config.options.sidebar?.wallhaven?.enable ?? true

                ConfigSpinBox {
                    icon: "format_list_numbered"
                    text: Translation.tr("Results per page")
                    value: Config.options.sidebar?.wallhaven?.limit ?? 24
                    from: 12
                    to: 72
                    stepSize: 4
                    onValueChanged: Config.setNestedValue("sidebar.wallhaven.limit", value)
                    StyledToolTip {
                        text: Translation.tr("Number of wallpapers to fetch per request")
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: "key"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: Translation.tr("API key")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurface
                    }
                    MaterialTextField {
                        id: wallhavenApiInput
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Optional - for NSFW content")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurface
                        placeholderTextColor: Appearance.colors.colSubtext
                        echoMode: TextInput.Password
                        text: Config.options.sidebar?.wallhaven?.apiKey ?? ""
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            radius: Appearance.rounding.small
                            border.width: wallhavenApiInput.activeFocus ? 2 : 1
                            border.color: wallhavenApiInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                        }
                        onTextChanged: Config.setNestedValue("sidebar.wallhaven.apiKey", text)
                    }
                }
            }

        }
    }

    SettingsCardSection {
        settingsTaskSection: "open"
        visible: root.isIiActive && !(Config.options?.settingsUi?.easyMode ?? false) && root.activeSection === "open"
        expanded: true
        icon: "swipe"
        title: Translation.tr("Opening")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Side edge open")
                tooltip: Translation.tr("Open the left or right sidebar by touching that screen edge")

                ConfigRow {
                    uniform: true
                    SettingsSwitch {
                        buttonIcon: "dock_to_left"
                        text: Translation.tr("Hover screen edges")
                        checked: Config.options?.sidebar?.edgeOpen?.enable ?? false
                        onCheckedChanged: Config.setNestedValue("sidebar.edgeOpen.enable", checked)
                    }
                    ConfigSpinBox {
                        icon: "width"
                        text: Translation.tr("Trigger width (px)")
                        value: Config.options?.sidebar?.edgeOpen?.regionWidth ?? 2
                        from: 1
                        to: 12
                        stepSize: 1
                        enabled: Config.options?.sidebar?.edgeOpen?.enable ?? false
                        opacity: enabled ? 1 : 0.5
                        onValueChanged: Config.setNestedValue("sidebar.edgeOpen.regionWidth", value)
                    }
                }
            }


            ContentSubsection {
                title: Translation.tr("Corner open")
                tooltip: Translation.tr("Allows you to open sidebars by clicking or hovering screen corners regardless of bar position")
                ConfigRow {
                    uniform: true
                    SettingsSwitch {
                        buttonIcon: "check"
                        text: Translation.tr("Enable")
                        checked: Config.options.sidebar.cornerOpen.enable
                        onCheckedChanged: {
                            Config.setNestedValue("sidebar.cornerOpen.enable", checked);
                        }
                        StyledToolTip {
                            text: Translation.tr("Allow opening sidebars by interacting with screen corners")
                        }
                    }
                }
                SettingsSwitch {
                    buttonIcon: "highlight_mouse_cursor"
                    text: Translation.tr("Hover to trigger")
                    checked: Config.options.sidebar.cornerOpen.clickless
                    onCheckedChanged: {
                        Config.setNestedValue("sidebar.cornerOpen.clickless", checked);
                    }

                    StyledToolTip {
                        text: Translation.tr("When this is off you'll have to click")
                    }
                }
                ConfigRow {
                    SettingsSwitch {
                        enabled: !Config.options.sidebar.cornerOpen.clickless
                        text: Translation.tr("Force hover open at absolute corner")
                        checked: Config.options.sidebar.cornerOpen.clicklessCornerEnd
                        onCheckedChanged: {
                            Config.setNestedValue("sidebar.cornerOpen.clicklessCornerEnd", checked);
                        }

                        StyledToolTip {
                            text: Translation.tr("When the previous option is off and this is on,\nyou can still hover the corner's end to open sidebar,\nand the remaining area can be used for volume/brightness scroll")
                        }
                    }
                    ConfigSpinBox {
                        icon: "arrow_cool_down"
                        text: Translation.tr("with vertical offset")
                        value: Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset
                        from: 0
                        to: 20
                        stepSize: 1
                        onValueChanged: {
                            Config.setNestedValue("sidebar.cornerOpen.clicklessCornerVerticalOffset", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("Why this is cool:\nFor non-0 values, it won't trigger when you reach the\nscreen corner along the horizontal edge, but it will when\nyou do along the vertical edge")
                        }
                    }
                }

                ConfigRow {
                    uniform: true
                    SettingsSwitch {
                        buttonIcon: "vertical_align_bottom"
                        text: Translation.tr("Place at bottom")
                        checked: Config.options.sidebar.cornerOpen.bottom
                        onCheckedChanged: {
                            Config.setNestedValue("sidebar.cornerOpen.bottom", checked);
                        }

                        StyledToolTip {
                            text: Translation.tr("Place the corners to trigger at the bottom")
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "unfold_more_double"
                        text: Translation.tr("Value scroll")
                        checked: Config.options.sidebar.cornerOpen.valueScroll
                        onCheckedChanged: {
                            Config.setNestedValue("sidebar.cornerOpen.valueScroll", checked);
                        }

                        StyledToolTip {
                            text: Translation.tr("Brightness and volume")
                        }
                    }
                }
                SettingsSwitch {
                    buttonIcon: "visibility"
                    text: Translation.tr("Visualize region")
                    checked: Config.options.sidebar.cornerOpen.visualize
                    onCheckedChanged: {
                        Config.setNestedValue("sidebar.cornerOpen.visualize", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a colored overlay indicating the corner trigger areas (debug)")
                    }
                }
                ConfigRow {
                    ConfigSpinBox {
                        icon: "arrow_range"
                        text: Translation.tr("Region width")
                        value: Config.options.sidebar.cornerOpen.cornerRegionWidth
                        from: 1
                        to: 300
                        stepSize: 1
                        onValueChanged: {
                            Config.setNestedValue("sidebar.cornerOpen.cornerRegionWidth", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("Horizontal size of the active corner area")
                        }
                    }
                    ConfigSpinBox {
                        icon: "height"
                        text: Translation.tr("Region height")
                        value: Config.options.sidebar.cornerOpen.cornerRegionHeight
                        from: 1
                        to: 300
                        stepSize: 1
                        onValueChanged: {
                            Config.setNestedValue("sidebar.cornerOpen.cornerRegionHeight", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("Vertical size of the active corner area")
                        }
                    }
                }
            }
        }
    }

}
