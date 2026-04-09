pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

// Slider setting row — WSettingsRow with inline WSlider and value display
WSettingsRow {
    id: root

    property real value: 0.5
    property real from: 0.0
    property real to: 1.0
    property real stepSize: 0.01
    property string suffix: ""
    property int displayDecimals: 0
    property int sliderWidth: 180
    property string tooltipContent: ""

    signal moved()

    control: Component {
        RowLayout {
            spacing: 10

            WSlider {
                id: slider
                implicitWidth: root.sliderWidth
                from: root.from
                to: root.to
                value: root.value
                stepSize: root.stepSize
                scrollable: true
                tooltipContent: root.tooltipContent || (root.displayDecimals > 0
                    ? `${value.toFixed(root.displayDecimals)}${root.suffix}`
                    : `${Math.round(value)}${root.suffix}`)

                onMoved: {
                    root.value = value
                    root.moved()
                }
            }

            WText {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: root.displayDecimals > 0
                    ? `${root.value.toFixed(root.displayDecimals)}${root.suffix}`
                    : `${Math.round(root.value)}${root.suffix}`
                font.pixelSize: Looks.font.pixelSize.normal
                font.family: Looks.font.family.ui
                font.weight: Looks.font.weight.strong
                font.features: { "tnum": 1 }
                color: Looks.colors.subfg
            }
        }
    }
}
