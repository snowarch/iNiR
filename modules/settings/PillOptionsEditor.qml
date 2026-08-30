pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.pill

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 16

    readonly property var surfaceDescriptors: [
        { key: "glance", icon: "today", label: Translation.tr("Today glance") },
        { key: "launcher", icon: "apps", label: Translation.tr("App launcher") },
        { key: "clipboard", icon: "content_paste", label: Translation.tr("Clipboard") },
        { key: "sysmon", icon: "monitor_heart", label: Translation.tr("System monitor") },
        { key: "recorder", icon: "screen_record", label: Translation.tr("Screen recorder") }
    ]

    readonly property var moduleDescriptors: [
        { key: "workspaces", icon: "workspaces", label: Translation.tr("Workspaces") },
        { key: "weather", icon: "partly_cloudy_day", label: Translation.tr("Weather") },
        { key: "tray", icon: "shelf_position", label: Translation.tr("System tray") },
        { key: "wifi", icon: "wifi", label: Translation.tr("Wi-Fi") },
        { key: "battery", icon: "battery_5_bar", label: Translation.tr("Battery") },
        { key: "inbox", icon: "inbox", label: Translation.tr("Inbox") },
        { key: "mixer", icon: "tune", label: Translation.tr("Mixer") },
        { key: "sidebars", icon: "view_sidebar", label: Translation.tr("Sidebars") },
        { key: "power", icon: "power_settings_new", label: Translation.tr("Power") }
    ]
    readonly property var glyphDescriptors: [
        { key: "clock", label: Translation.tr("Clock") },
        { key: "launcher", label: Translation.tr("Launcher") },
        { key: "glance", label: Translation.tr("Today glance") },
        { key: "clipboard", label: Translation.tr("Clipboard") },
        { key: "clipboardSearch", label: Translation.tr("Clipboard search") },
        { key: "media", label: Translation.tr("Media playing") },
        { key: "mediaPaused", label: Translation.tr("Media paused") },
        { key: "mixer", label: Translation.tr("Mixer") },
        { key: "calendar", label: Translation.tr("Calendar") },
        { key: "battery", label: Translation.tr("Battery") },
        { key: "power", label: Translation.tr("Power") },
        { key: "sysmon", label: Translation.tr("System monitor") },
        { key: "recorder", label: Translation.tr("Recorder") },
        { key: "link", label: Translation.tr("Link / network") },
        { key: "workspaces", label: Translation.tr("Workspace strip") },
        { key: "settings", label: Translation.tr("Settings") },
        { key: "notify", label: Translation.tr("Notifications") },
        { key: "dnd", label: Translation.tr("Do not disturb") },
        { key: "clear", label: Translation.tr("Clear notifications") }
    ]

    property string activeSection: "basics"
    property bool glyphOverridesExpanded: false

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: introColumn.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.colors.colPrimaryContainer

        ColumnLayout {
            id: introColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialCookie {
                    implicitSize: 40
                    sides: 9
                    color: Appearance.colors.colPrimary
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "blur_on"
                        iconSize: 19
                        color: Appearance.colors.colOnPrimary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: Translation.tr("Pill setup")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Configure the controls you use first, then tune scale and spacing. Rare geometry stays out of the way under Advanced.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        wrapMode: Text.WordWrap
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Behavior · readability · surfaces")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnPrimaryContainer
                wrapMode: Text.WordWrap
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: previewColumn.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: previewColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                MaterialSymbol {
                    text: "preview"
                    iconSize: 19
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Live shape preview")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                }
                StyledText {
                    text: Math.round((Config.options?.bar?.pill?.scale ?? 1) * 100) + "%"
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: Math.max(72, previewPill.height + 28)

                Item {
                    id: previewPill
                    readonly property real previewScale: (Config.options?.bar?.pill?.scale ?? 1) * 1.25
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(parent.width - 24,
                        Math.max(160, Config.options?.bar?.pill?.restWidth ?? 176) * previewScale)
                    height: Math.max(38, Config.options?.bar?.pill?.restHeight ?? 44) * previewScale

                    IslandPanel {
                        anchors.fill: parent
                        radius: Math.min(parent.height / 2,
                            (Config.options?.appearance?.island?.radius ?? 18) * previewPill.previewScale)
                        glassEnabled: true
                        screen: previewPill.QsWindow?.window?.screen ?? null
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(10 * previewPill.previewScale)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(18 * previewPill.previewScale)
                            height: Math.max(3, Math.round(5 * previewPill.previewScale))
                            radius: height / 2
                            color: PillTheme.vermLit
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "10:48"
                            font.pixelSize: Math.round(17 * previewPill.previewScale)
                            font.weight: Font.DemiBold
                            color: PillTheme.cream
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 1
                            height: Math.round(18 * previewPill.previewScale)
                            color: PillTheme.hair
                        }
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round((index === 0 ? 16 : 5) * previewPill.previewScale)
                                height: Math.max(3, Math.round(5 * previewPill.previewScale))
                                radius: height / 2
                                color: index === 0 ? PillTheme.vermLit : PillTheme.cream
                                opacity: index === 0 ? 1 : 0.35
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("The preview uses the shared Ricelin Island material. Opacity, glass and edge treatment live in Settings › Ricelin › Island surfaces.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    ConfigSelectionArray {
        Layout.fillWidth: true
        currentValue: root.activeSection
        onSelected: (newValue) => root.activeSection = newValue
        options: [
            { displayName: Translation.tr("Basics"), icon: "tune", value: "basics" },
            { displayName: Translation.tr("Content"), icon: "widgets", value: "content" },
            { displayName: Translation.tr("Clock"), icon: "schedule", value: "clock" },
            { displayName: Translation.tr("Advanced"), icon: "construction", value: "advanced" }
        ]
    }

    ContentSubsection {
        settingsTaskSection: "basics"
        visible: root.activeSection === "basics"
        title: Translation.tr("Behavior & entry points")

        ConfigRow {
            uniform: true
            SettingsSwitch {
                buttonIcon: "expand_content"
                text: Translation.tr("Persistent bar mode")
                checked: Config.options?.bar?.pill?.barMode ?? false
                onCheckedChanged: Config.setNestedValue("bar.pill.barMode", checked)
                StyledToolTip { text: Translation.tr("Keep the expanded Ricelin row visible without hovering.") }
            }
            SettingsSwitch {
                buttonIcon: "unfold_less"
                text: Translation.tr("Compact feedback")
                enabled: (Config.options?.bar?.pill?.toasts ?? true) || (Config.options?.bar?.pill?.osd ?? true)
                checked: Config.options?.bar?.pill?.compactAnnounces ?? false
                onCheckedChanged: Config.setNestedValue("bar.pill.compactAnnounces", checked)
                StyledToolTip { text: Translation.tr("Keep notifications and OSD inside the resting pill instead of opening a larger face.") }
            }
        }

        SettingsSwitch {
            buttonIcon: "picture_in_picture"
            text: Translation.tr("Float over windows")
            enabled: !(Config.options?.bar?.autoHide?.enable ?? false)
            checked: Config.options?.bar?.pill?.floatOverWindows ?? false
            onCheckedChanged: Config.setNestedValue("bar.pill.floatOverWindows", checked)
            StyledToolTip {
                text: !(Config.options?.bar?.autoHide?.enable ?? false)
                    ? Translation.tr("Keep the visible Pill above normal windows instead of reserving the top edge. Fullscreen still hides and unmaps it.")
                    : Translation.tr("Auto-hide already controls whether the revealed Pill overlays or pushes windows.")
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Super+Space")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
        }
        ConfigSelectionArray {
            Layout.fillWidth: true
            currentValue: Config.options?.bar?.pill?.superSpaceLauncher ?? "overview"
            onSelected: (newValue) => Config.setNestedValue("bar.pill.superSpaceLauncher", newValue)
            options: [
                { displayName: Translation.tr("iNiR Overview"), icon: "overview_key", value: "overview" },
                { displayName: Translation.tr("Pill launcher"), icon: "search", value: "pill" }
            ]
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Now Playing access")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
        }
        ConfigSelectionArray {
            Layout.fillWidth: true
            currentValue: (Config.options?.bar?.pill?.mediaAccess ?? "row") === "bud" ? "bud" : "row"
            onSelected: (newValue) => Config.setNestedValue("bar.pill.mediaAccess", newValue)
            options: [
                { displayName: Translation.tr("Side bud"), icon: "music_note", value: "bud" },
                { displayName: Translation.tr("Hover row"), icon: "view_week", value: "row" }
            ]
        }

        ConfigRow {
            uniform: true
            SettingsSwitch {
                buttonIcon: "notifications"
                text: Translation.tr("Notifications in Pill")
                checked: Config.options?.bar?.pill?.toasts ?? true
                onCheckedChanged: Config.setNestedValue("bar.pill.toasts", checked)
            }
            SettingsSwitch {
                buttonIcon: "page_info"
                text: Translation.tr("OSD in Pill")
                checked: Config.options?.bar?.pill?.osd ?? true
                onCheckedChanged: Config.setNestedValue("bar.pill.osd", checked)
                StyledToolTip { text: Translation.tr("Show Pill feedback for volume, brightness and other system changes. Media feedback follows Tools › OSD › Media OSD; explicit skips stay visible during games while automatic track progression stays hidden.") }
            }
        }
    }

    ContentSubsection {
        settingsTaskSection: "basics"
        visible: root.activeSection === "basics"
        title: Translation.tr("Size & readability")

        ConfigSpinBox {
            icon: "zoom_in"
            text: Translation.tr("Scale (%)")
            value: Math.round((Config.options?.bar?.pill?.scale ?? 1) * 100)
            from: 40
            to: 160
            stepSize: 5
            onValueChanged: Config.setNestedValue("bar.pill.scale", value / 100)
            StyledToolTip {
                text: Translation.tr("Relative scale for the whole Pill and its surfaces. Logical monitor size is applied automatically; compact displays can be reduced further here.")
            }
        }

        SettingsNote {
            icon: "blur_on"
            text: Translation.tr("Pill uses the shared Ricelin Island material. Body opacity, glass blur, radius, shadow and lit edge are configured once in Settings › Ricelin › Island surfaces.")
        }

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "pinch"
                text: Translation.tr("Icon size (px)")
                value: Config.options?.bar?.pill?.iconSize ?? 19
                from: 17
                to: 28
                stepSize: 1
                onValueChanged: Config.setNestedValue("bar.pill.iconSize", value)
            }
            ConfigSpinBox {
                icon: "space_bar"
                text: Translation.tr("Icon spacing (px)")
                value: Config.options?.bar?.pill?.iconSpacing ?? 14
                from: 12
                to: 28
                stepSize: 2
                onValueChanged: Config.setNestedValue("bar.pill.iconSpacing", value)
            }
        }

        ConfigSpinBox {
            icon: "format_letter_spacing"
            text: Translation.tr("Group spacing (px)")
            value: Config.options?.bar?.pill?.rowSpacing ?? 24
            from: 20
            to: 44
            stepSize: 2
            onValueChanged: Config.setNestedValue("bar.pill.rowSpacing", value)
        }

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "width"
                text: Translation.tr("Rest width (px)")
                value: Config.options?.bar?.pill?.restWidth ?? 176
                from: 160
                to: 280
                stepSize: 4
                onValueChanged: Config.setNestedValue("bar.pill.restWidth", value)
            }
            ConfigSpinBox {
                icon: "height"
                text: Translation.tr("Rest height (px)")
                value: Config.options?.bar?.pill?.restHeight ?? 44
                from: 38
                to: 60
                stepSize: 2
                onValueChanged: Config.setNestedValue("bar.pill.restHeight", value)
            }
        }

        ConfigSpinBox {
            icon: "unfold_more"
            text: Translation.tr("Expanded height (px)")
            value: Config.options?.bar?.pill?.expandedHeight ?? 66
            from: 58
            to: 88
            stepSize: 2
            onValueChanged: Config.setNestedValue("bar.pill.expandedHeight", value)
        }
    }

    ContentSubsection {
        settingsTaskSection: "content"
        visible: root.activeSection === "content"
        title: Translation.tr("Surfaces")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Disable faces you never use. Core faces such as media, mixer, calendar, link and power stay available because they are part of the Pill's primary navigation.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: Math.ceil(root.surfaceDescriptors.length / 2)

            ConfigRow {
                required property int index
                uniform: true

                Repeater {
                    model: root.surfaceDescriptors.slice(index * 2, index * 2 + 2)
                    SettingsSwitch {
                        required property var modelData
                        buttonIcon: modelData.icon
                        text: modelData.label
                        checked: Config.options?.bar?.pill?.surfaces?.[modelData.key] ?? (modelData.key !== "recorder")
                        onCheckedChanged: Config.setNestedValue("bar.pill.surfaces." + modelData.key, checked)
                    }
                }
                Item { visible: index * 2 + 1 >= root.surfaceDescriptors.length; Layout.fillWidth: visible }
            }
        }
    }

    ContentSubsection {
        settingsTaskSection: "content"
        visible: root.activeSection === "content"
        title: Translation.tr("Hover row")

        Repeater {
            model: Math.ceil(root.moduleDescriptors.length / 2)

            ConfigRow {
                required property int index
                uniform: true
                Repeater {
                    model: root.moduleDescriptors.slice(index * 2, index * 2 + 2)
                    SettingsSwitch {
                        required property var modelData
                        buttonIcon: modelData.icon
                        text: modelData.label
                        checked: Config.options?.bar?.pill?.modules?.[modelData.key] ?? true
                        onCheckedChanged: Config.setNestedValue("bar.pill.modules." + modelData.key, checked)
                    }
                }
                Item { visible: index * 2 + 1 >= root.moduleDescriptors.length; Layout.fillWidth: visible }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Battery display")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
            visible: Config.options?.bar?.pill?.modules?.battery ?? true
        }
        ConfigSelectionArray {
            Layout.fillWidth: true
            visible: Config.options?.bar?.pill?.modules?.battery ?? true
            currentValue: Config.options?.bar?.pill?.batteryDisplay ?? "both"
            onSelected: (newValue) => Config.setNestedValue("bar.pill.batteryDisplay", newValue)
            options: [
                { displayName: Translation.tr("Icon"), icon: "battery_5_bar", value: "icon" },
                { displayName: Translation.tr("Percentage"), icon: "percent", value: "percentage" },
                { displayName: Translation.tr("Both"), icon: "battery_full", value: "both" }
            ]
        }
    }

    ContentSubsection {
        settingsTaskSection: "clock"
        visible: root.activeSection === "clock"
        title: Translation.tr("Clock & glyphs")

        ConfigRow {
            uniform: true
            SettingsSwitch {
                buttonIcon: "translate"
                text: Translation.tr("Kanji glyphs")
                checked: Config.options?.bar?.pill?.showGlyphs ?? true
                onCheckedChanged: Config.setNestedValue("bar.pill.showGlyphs", checked)
            }
            SettingsSwitch {
                buttonIcon: "schedule"
                text: Translation.tr("Clock seconds")
                checked: Config.options?.bar?.pill?.clockSeconds ?? false
                onCheckedChanged: Config.setNestedValue("bar.pill.clockSeconds", checked)
            }
        }
        SettingsSwitch {
            buttonIcon: "update"
            text: Translation.tr("12-hour time")
            checked: Config.options?.bar?.pill?.time12h ?? false
            onCheckedChanged: Config.setNestedValue("bar.pill.time12h", checked)
        }

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 38
            buttonRadius: Appearance.rounding.small
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer1Hover
            onClicked: root.glyphOverridesExpanded = !root.glyphOverridesExpanded

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8
                MaterialSymbol {
                    text: root.glyphOverridesExpanded ? "expand_less" : "expand_more"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Per-surface glyph overrides")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                }
                StyledText {
                    text: Translation.tr("Optional")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallest
                }
            }
        }

        ColumnLayout {
            visible: root.glyphOverridesExpanded
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.glyphDescriptors
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10
                    StyledText {
                        Layout.preferredWidth: 150
                        text: parent.modelData.label
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: PillTheme.glyphDefaults[parent.modelData.key] ?? ""
                        text: Config.options?.bar?.pill?.glyphs?.[parent.modelData.key] ?? ""
                        onTextChanged: Config.setNestedValue("bar.pill.glyphs." + parent.modelData.key, text)
                    }
                }
            }
        }
    }

    ContentSubsection {
        settingsTaskSection: "advanced"
        visible: root.activeSection === "advanced"
        title: Translation.tr("Advanced geometry & soul")

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 12

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "vertical_align_top"
                text: Translation.tr("Top gap (px)")
                value: Math.round((Config.options?.bar?.pill?.topGap ?? 1) * 8)
                from: 0
                to: 32
                stepSize: 2
                onValueChanged: Config.setNestedValue("bar.pill.topGap", value / 8)
            }
            ConfigSpinBox {
                icon: "expand"
                text: Translation.tr("Window gap (%)")
                enabled: !(Config.options?.bar?.pill?.floatOverWindows ?? false)
                    || (Config.options?.bar?.autoHide?.enable ?? false)
                value: Math.round((Config.options?.bar?.pill?.appGap ?? 1) * 100)
                from: 0
                to: 200
                stepSize: 10
                onValueChanged: Config.setNestedValue("bar.pill.appGap", value / 100)
                StyledToolTip { text: Translation.tr("Space between Pill and windows while the top edge is reserved.") }
            }
        }
        ConfigSpinBox {
            icon: "format_list_numbered"
            text: Translation.tr("Visible app faders")
            value: Config.options?.bar?.pill?.mixerAppRows ?? 5
            from: 3
            to: 8
            stepSize: 1
            onValueChanged: Config.setNestedValue("bar.pill.mixerAppRows", value)
        }

        ConfigRow {
            uniform: true
            SettingsSwitch {
                buttonIcon: "motion_photos_on"
                text: Translation.tr("Soul bead")
                checked: Config.options?.bar?.pill?.soul?.enable ?? true
                onCheckedChanged: Config.setNestedValue("bar.pill.soul.enable", checked)
            }
            ConfigSpinBox {
                icon: "zoom_in"
                text: Translation.tr("Bead size (%)")
                value: Math.round((Config.options?.bar?.pill?.soul?.size ?? 1) * 100)
                from: 60
                to: 160
                stepSize: 10
                onValueChanged: Config.setNestedValue("bar.pill.soul.size", value / 100)
            }
        }

        ConfigSelectionArray {
            Layout.fillWidth: true
            currentValue: Config.options?.bar?.pill?.soul?.style ?? "orb"
            onSelected: (newValue) => Config.setNestedValue("bar.pill.soul.style", newValue)
            options: [
                { displayName: Translation.tr("Orb"), icon: "blur_circular", value: "orb" },
                { displayName: Translation.tr("Ember"), icon: "circle", value: "ember" },
                { displayName: Translation.tr("Ring"), icon: "radio_button_unchecked", value: "ring" }
            ]
        }
    }
    }
}
