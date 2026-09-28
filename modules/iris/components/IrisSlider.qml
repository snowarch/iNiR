import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: root

    property alias value: slider.value
    signal moved(real value)

    implicitWidth: 220
    implicitHeight: Math.round(34 * IrisStyle.density)

    StyledSlider {
        id: slider
        anchors.fill: parent
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
        dotColorHighlighted: IrisStyle.onAccentContainer
        scrollable: true
        onMoved: root.moved(slider.value)
    }
}
