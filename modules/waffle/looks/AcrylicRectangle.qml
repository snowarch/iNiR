import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

Rectangle {
    id: root

    property bool shiny: true // Top border
    property color borderColor: ColorUtils.transparentize(Looks.colors.bg1Hover, 0.7)
    property color internalBorderColor: ColorUtils.transparentize(borderColor, shiny ? 0.0 : 1)
    color: Looks.colors.bg1Hover
    radius: Looks.radius.medium
    Behavior on color {
        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
    }
    Behavior on internalBorderColor {
        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
    }
    onInternalBorderColorChanged: {
        borderLoader.item?.requestPaint();
    }
    
    Loader {
        id: borderLoader
        anchors.fill: parent
        active: root.shiny && !Looks.gameModeMinimal
        sourceComponent: Canvas {
            // Shiny top border in dark mode, shadow-like bottom one in light.
            rotation: Looks.dark ? 0 : 180
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (width <= 0 || height <= 0)
                    return

                const borderColor = root.internalBorderColor
                // Canvas gradient stops must remain within 0..1.
                const r = Math.min(root.radius, width / 2, height / 2)
                const fadeLengthPercent = Math.min(0.5, Math.max(1, r) / width)
                const grad = ctx.createLinearGradient(0, 0, width, 0)
                grad.addColorStop(0, Qt.rgba(borderColor.r, borderColor.g, borderColor.b, 0))
                grad.addColorStop(fadeLengthPercent, borderColor)
                grad.addColorStop(1 - fadeLengthPercent, borderColor)
                grad.addColorStop(1, Qt.rgba(borderColor.r, borderColor.g, borderColor.b, 0))

                ctx.strokeStyle = grad
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(r, 0.5)
                ctx.lineTo(width - r, 0.5)
                ctx.arcTo(width, 0.5, width, r + 0.5, r)
                ctx.moveTo(width - r, 0.5)
                ctx.arcTo(0, 0.5, 0, r + 0.5, r)
                ctx.stroke()
            }
        }
    }
}
