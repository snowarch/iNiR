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

    readonly property bool glassEnabled: Config.options?.appearance?.island?.glass ?? true
    readonly property real bodyOpacity: Config.options?.appearance?.island?.opacity ?? 1
    readonly property bool glassEffective: glassEnabled && bodyOpacity < 0.999 && Appearance.effectsEnabled

    readonly property var surfaceDescriptors: [
        { key: "dock", icon: "dock_to_bottom", label: Translation.tr("Dock") },
        { key: "sidebars", icon: "view_sidebar", label: Translation.tr("Sidebars") },
        { key: "search", icon: "search", label: Translation.tr("Search") },
        { key: "controlPanel", icon: "tune", label: Translation.tr("Control panel") },
        { key: "widgets", icon: "widgets", label: Translation.tr("Desktop widgets") },
        { key: "workspaceStrip", icon: "dock_to_right", label: Translation.tr("Workspace strip") }
    ]

    function surfaceEnabled(key) {
        switch (key) {
        case "dock": return (Config.options?.dock?.style ?? "panel") === "island";
        case "sidebars": return (Config.options?.sidebar?.style ?? "panel") === "island";
        case "search": return (Config.options?.search?.style ?? "default") === "island";
        case "controlPanel": return (Config.options?.controlPanel?.style ?? "panel") === "island";
        case "widgets": return (Config.options?.background?.widgets?.style ?? "panel") === "island";
        case "workspaceStrip": return (Config.options?.workspaceStrip?.style ?? "auto") === "island";
        }
        return false;
    }

    function setSurfaceEnabled(key, enabled) {
        switch (key) {
        case "dock":
            if (enabled) Config.setNestedValue("dock.style", "island");
            else if ((Config.options?.dock?.style ?? "panel") === "island") Config.setNestedValue("dock.style", "panel");
            break;
        case "sidebars": Config.setNestedValue("sidebar.style", enabled ? "island" : "panel"); break;
        case "search": Config.setNestedValue("search.style", enabled ? "island" : "default"); break;
        case "controlPanel": Config.setNestedValue("controlPanel.style", enabled ? "island" : "panel"); break;
        case "widgets": Config.setNestedValue("background.widgets.style", enabled ? "island" : "panel"); break;
        case "workspaceStrip": Config.setNestedValue("workspaceStrip.style", enabled ? "island" : "auto"); break;
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: intro.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.colors.colPrimaryContainer

        ColumnLayout {
            id: intro
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                MaterialCookie {
                    implicitSize: 40
                    sides: 9
                    color: Appearance.colors.colPrimary
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "layers"
                        iconSize: 19
                        color: Appearance.colors.colOnPrimary
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: Translation.tr("One Ricelin skin, reused everywhere")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Opacity, glass and edge treatment are shared. Each surface keeps geometry appropriate to its role instead of becoming the same card everywhere.")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.82
                        wrapMode: Text.WordWrap
                    }
                }
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
                    text: root.glassEffective ? "blur_on" : "layers"
                    iconSize: 19
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Island body preview")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                }
                StyledText {
                    text: Math.round(root.bodyOpacity * 100) + "%"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            Item {
                id: previewSurface
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.min(430, Math.max(260, previewColumn.width - 80))
                implicitHeight: 92

                IslandPanel {
                    anchors.fill: parent
                    glassEnabled: true
                    screen: previewSurface.QsWindow?.window?.screen ?? null
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.fillHeight: true
                        radius: 10
                        color: Qt.alpha(PillTheme.vermLit, 0.12)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "widgets"
                            iconSize: 21
                            color: PillTheme.vermLit
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.rightMargin: 54
                            implicitHeight: 9
                            radius: 4
                            color: Qt.alpha(PillTheme.cream, 0.82)
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.rightMargin: 16
                            implicitHeight: 6
                            radius: 3
                            color: Qt.alpha(PillTheme.cream, 0.26)
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.glassEffective
                    ? Translation.tr("Glass is active behind translucent Island surfaces.")
                    : root.glassEnabled && root.bodyOpacity >= 0.999
                        ? Translation.tr("Lower body opacity below 100% to reveal the glass background.")
                        : Translation.tr("Glass background is currently off.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                wrapMode: Text.WordWrap
            }
        }
    }

    ContentSubsection {
        title: Translation.tr("Body & glass")

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "opacity"
                text: Translation.tr("Body opacity (%)")
                value: Math.round(root.bodyOpacity * 100)
                from: 20
                to: 100
                stepSize: 5
                onValueChanged: Config.setNestedValue("appearance.island.opacity", value / 100)
                StyledToolTip { text: Translation.tr("Only the Ricelin card body fades. Content stays fully opaque.") }
            }
            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Glass background")
                checked: root.glassEnabled
                onCheckedChanged: Config.setNestedValue("appearance.island.glass", checked)
                StyledToolTip { text: Translation.tr("Blur the wallpaper behind translucent Island surfaces.") }
            }
        }

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "lens_blur"
                text: Translation.tr("Glass blur (%)")
                enabled: root.glassEnabled
                value: Math.round((Config.options?.appearance?.island?.glassBlur ?? 1) * 100)
                from: 20
                to: 100
                stepSize: 10
                onValueChanged: Config.setNestedValue("appearance.island.glassBlur", value / 100)
            }
            ConfigSpinBox {
                icon: "rounded_corner"
                text: Translation.tr("Base radius (px)")
                value: Config.options?.appearance?.island?.radius ?? 18
                from: 4
                to: 32
                stepSize: 2
                onValueChanged: Config.setNestedValue("appearance.island.radius", value)
                StyledToolTip { text: Translation.tr("Used by Pill and generic Island cards. Sidebars, search and other specialized surfaces keep their own contextual geometry.") }
            }
        }

        ConfigRow {
            uniform: true
            SettingsSwitch {
                buttonIcon: "ev_shadow"
                text: Translation.tr("Drop shadow")
                checked: Config.options?.appearance?.island?.shadow ?? true
                onCheckedChanged: Config.setNestedValue("appearance.island.shadow", checked)
            }
            SettingsSwitch {
                buttonIcon: "flare"
                text: Translation.tr("Lit top edge")
                checked: Config.options?.appearance?.island?.sheen ?? true
                onCheckedChanged: Config.setNestedValue("appearance.island.sheen", checked)
            }
        }

        SettingsNote {
            visible: root.glassEnabled && !Appearance.effectsEnabled
            warning: true
            icon: "blur_off"
            text: Translation.tr("Glass needs shell visual effects enabled. Body opacity still applies without blur.")
        }
    }

    ContentSubsection {
        title: Translation.tr("Use Island skin on")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("These switches change only the surface dialect. They do not alter the content or behavior of each iNiR panel.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallest
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
                        checked: root.surfaceEnabled(modelData.key)
                        onCheckedChanged: root.setSurfaceEnabled(modelData.key, checked)
                    }
                }
            }
        }

        SettingsNote {
            icon: "info"
            text: Translation.tr("Bar Islands use the same body opacity and glass settings automatically when Bar appearance is set to Islands.")
        }
    }
}
