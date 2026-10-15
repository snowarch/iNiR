pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

// ZZZ style editor — surfaces the ZZZ personality axis: silhouette variant.
// Square = sharp console plates with cut-corner chamfers (classic ZZZ).
// Round = softer anime UI — pill controls, rounded panels, no chamfer.
// Bound to `appearance.zzz.shape`. Geometry flips shell-wide reactively
// (every radius/cutCorner consumer reads Appearance.zzz.* which depends on it).
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12

    // Percentage slider row with label + value readout (mirrors AngelStyleEditor).
    component SliderRow: RowLayout {
        id: sliderRowRoot
        Layout.fillWidth: true
        spacing: 8

        property string label: ""
        property string icon: ""
        property string description: ""
        property real configValue: 1.0
        property real from: 0.0
        property real to: 1.0
        property real stepSize: 0.01
        property string configPath: ""

        MaterialSymbol {
            text: sliderRowRoot.icon
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colSubtext
            visible: sliderRowRoot.icon !== ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                text: sliderRowRoot.label
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                visible: sliderRowRoot.description !== ""
                text: sliderRowRoot.description
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        StyledText {
            text: Math.round(slider.value * 100) + "%"
            font.pixelSize: Appearance.font.pixelSize.small
            font.family: Appearance.font.family.monospace
            color: Appearance.colors.colPrimary
            Layout.preferredWidth: 45
            horizontalAlignment: Text.AlignRight
        }

        StyledSlider {
            id: slider
            Layout.preferredWidth: 160
            from: sliderRowRoot.from
            to: sliderRowRoot.to
            stepSize: sliderRowRoot.stepSize
            value: sliderRowRoot.configValue
            configuration: StyledSlider.Configuration.S
            onMoved: {
                if (sliderRowRoot.configPath !== "")
                    Config.setNestedValue(sliderRowRoot.configPath, Math.round(value * 100) / 100)
            }
        }
    }

    ConfigSelectionArray {
        Layout.fillWidth: true
        currentValue: Config.options?.appearance?.zzz?.shape ?? "square"
        onSelected: (newValue) => {
            Config.setNestedValue("appearance.zzz.shape", newValue)
        }
        options: [
            { displayName: Translation.tr("Square"), icon: "square", value: "square" },
            { displayName: Translation.tr("Round"), icon: "rounded_corner", value: "round" }
        ]
    }

    StyledText {
        Layout.fillWidth: true
        text: Translation.tr("Square stays ZZZ's sharp console silhouette with cut-corner chamfers. Round softens the whole shell into an anime UI: pill controls, rounded panels and no chamfer. Changes apply instantly across every surface.")
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.smaller
        wrapMode: Text.WordWrap
    }

    ConfigSwitch {
        Layout.fillWidth: true
        text: Translation.tr("Wallpaper glass")
        checked: Config.options?.appearance?.zzz?.glass ?? true
        onCheckedChanged: Config.setNestedValue("appearance.zzz.glass", checked)
    }

    StyledText {
        Layout.fillWidth: true
        text: Translation.tr("Adds a subtle blurred-wallpaper wash behind the technical grid on ZZZ panels, so the carbon console picks up a faint hue of your desktop. The grid lines stay crisp on top. Disabled automatically when effects are off (game mode / reduced effects).")
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.smaller
        wrapMode: Text.WordWrap
    }

    // ─── Backdrop layers: master switches for the technical ornaments drawn
    // behind panel content. Each ANDs with the per-panel design, so turning one
    // off hides it shell-wide (dashboard, sidebars, control panel, etc.). ───
    ContentSubsection {
        title: Translation.tr("Backdrop layers")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Toggle the technical ornaments ZZZ draws behind panel content. Each switch applies everywhere the ZZZ backdrop appears.")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        ConfigSwitch {
            Layout.fillWidth: true
            text: Translation.tr("Diagonal burst")
            checked: Config.options?.appearance?.zzz?.backdrop?.burst ?? true
            onCheckedChanged: Config.setNestedValue("appearance.zzz.backdrop.burst", checked)
        }

        ConfigSwitch {
            Layout.fillWidth: true
            text: Translation.tr("Ghost wordmark")
            checked: Config.options?.appearance?.zzz?.backdrop?.ghost ?? true
            onCheckedChanged: Config.setNestedValue("appearance.zzz.backdrop.ghost", checked)
        }

        ConfigSwitch {
            Layout.fillWidth: true
            text: Translation.tr("Technical grid")
            checked: Config.options?.appearance?.zzz?.backdrop?.grid ?? true
            onCheckedChanged: Config.setNestedValue("appearance.zzz.backdrop.grid", checked)
        }

        ConfigSwitch {
            Layout.fillWidth: true
            text: Translation.tr("Scan ticks")
            checked: Config.options?.appearance?.zzz?.backdrop?.ticks ?? true
            onCheckedChanged: Config.setNestedValue("appearance.zzz.backdrop.ticks", checked)
        }

        SliderRow {
            label: Translation.tr("Diagonal size")
            icon: "open_in_full"
            description: Translation.tr("Size of the diagonal burst slashes (100% = default).")
            configValue: Config.options?.appearance?.zzz?.backdrop?.burstSize ?? 1.0
            from: 0.3; to: 2.0; stepSize: 0.05
            configPath: "appearance.zzz.backdrop.burstSize"
        }
    }
}
