import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: root

    property alias value: slider.value
    // Whether Shift turns the wheel into a fine step. Off by default, because
    // the wheel already means "nudge by stepSize" everywhere and this only adds
    // the modifier where a caller asks for it. The field's bands take 0.5 dB
    // per notch and 0.1 with Shift, so a control that sits next to that field
    // can answer the same modifier the same way.
    property bool fineStep: false
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
        dotColorHighlighted: IrisStyle.inkOnAccentContainer
        scrollable: true
        fineStep: root.fineStep
        onMoved: root.moved(slider.value)
    }
}
