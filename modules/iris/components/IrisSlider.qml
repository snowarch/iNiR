import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: root

    property alias value: slider.value
    readonly property alias pressed: slider.pressed
    // What a skin draws from: the pointer over it.
    readonly property bool hovered: hover.hovered
    signal moved(real value)

    implicitWidth: 220
    implicitHeight: Math.round(34 * IrisStyle.density)

    StyledSlider {
        id: slider
        anchors.fill: parent
        // Under a Design's skin the slider keeps its input and draws nothing.
        opacity: skin.active ? 0 : 1
        enabled: root.enabled
        enableSettingsSearch: false
        configuration: StyledSlider.Configuration.XS
        trackWidth: 4
        trackRadius: 2
        handleHeight: 12
        handleDefaultWidth: 12
        handlePressedWidth: 14
        handleMargins: 0
        stopIndicatorValues: []
        highlightColor: IrisStyle.accent
        handleColor: IrisStyle.accent
        trackColor: IrisStyle.accentContainer
        dotColor: IrisStyle.subtext
        dotColorHighlighted: IrisStyle.inkOnAccentContainer
        scrollable: true
        onMoved: root.moved(slider.value)
    }
    HoverHandler { id: hover; enabled: skin.active }
    IrisSkin { id: skin; part: "slider"; host: root }
}
