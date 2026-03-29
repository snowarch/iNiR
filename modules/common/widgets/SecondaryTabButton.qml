import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TabButton {
    id: root
    property string buttonText
    property string buttonIcon
    property bool selected: false
    property int rippleDuration: 1200
    property real horizontalContentPadding: 14
    property real iconTextSpacing: 5
    height: buttonBackground.height
    property int tabContentWidth: buttonBackground.width - buttonBackground.radius*2
    implicitWidth: buttonBackground.implicitWidth
    implicitHeight: buttonBackground.implicitHeight

    property color colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
    property color colBackgroundHover: Appearance.colors.colLayer1Hover
    property color colRipple: Appearance.colors.colLayer1Active

    PointingHandInteraction {}

    component RippleAnim: NumberAnimation {
        duration: rippleDuration
        easing.type: Appearance.animation.elementMoveEnter.type
        easing.bezierCurve: Appearance.animationCurves.standardDecel
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: (event) => {
            root.click() // Because the MouseArea already consumed the event
            const {x,y} = event
            const stateY = buttonBackground.y;
            rippleAnim.x = x;
            rippleAnim.y = y - stateY;

            const dist = (ox,oy) => ox*ox + oy*oy
            const stateEndY = stateY + buttonBackground.height
            rippleAnim.radius = Math.sqrt(Math.max(dist(0, stateY), dist(0, stateEndY), dist(width, stateY), dist(width, stateEndY)))

            rippleFadeAnim.complete();
            rippleAnim.restart();
        }
        onReleased: (event) => {
            rippleFadeAnim.restart();
        }
    }

    RippleAnim {
        id: rippleFadeAnim
        duration: rippleDuration * 2
        target: ripple
        property: "opacity"
        to: 0
    }

    SequentialAnimation {
        id: rippleAnim

        property real x
        property real y
        property real radius

        PropertyAction {
            target: ripple
            property: "x"
            value: rippleAnim.x
        }
        PropertyAction {
            target: ripple
            property: "y"
            value: rippleAnim.y
        }
        PropertyAction {
            target: ripple
            property: "opacity"
            value: 1
        }
        ParallelAnimation {
            RippleAnim {
                target: ripple
                properties: "rippleWidth,rippleHeight"
                from: 0
                to: rippleAnim.radius * 2
            }
        }
    }

    background: Rectangle {
        id: buttonBackground
        radius: Appearance?.rounding.normal
        implicitHeight: 37
        implicitWidth: tabContent.implicitWidth + root.horizontalContentPadding * 2
        color: (root.hovered ? root.colBackgroundHover : root.colBackground)
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: buttonBackground.width
                height: buttonBackground.height
                radius: buttonBackground.radius
            }
        }
        
        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        Item {
            id: ripple
            width: ripple.rippleWidth
            height: ripple.rippleHeight
            opacity: 0

            property real rippleWidth: 0
            property real rippleHeight: 0
            visible: width > 0 && height > 0

            Behavior on opacity {
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            RadialGradient {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.colRipple }
                    GradientStop { position: 0.3; color: root.colRipple }
                    GradientStop { position: 0.5 ; color: Qt.rgba(root.colRipple.r, root.colRipple.g, root.colRipple.b, 0) }
                }
            }

            transform: Translate {
                x: -ripple.width / 2
                y: -ripple.height / 2
            }
        }
    }

    contentItem: Item {
        anchors.centerIn: buttonBackground
        implicitWidth: tabContent.implicitWidth
        implicitHeight: tabContent.implicitHeight
        RowLayout {
            id: tabContent
            anchors.centerIn: parent
            spacing: 0
            
            Loader {
                id: iconLoader
                active: buttonIcon?.length > 0
                sourceComponent: buttonIcon?.length > 0 ? materialSymbolComponent : null
                Layout.rightMargin: root.iconTextSpacing
            }

            Component {
                id: materialSymbolComponent
                MaterialSymbol {
                    verticalAlignment: Text.AlignVCenter
                    text: buttonIcon
                    iconSize: Appearance.font.pixelSize.huge
                    fill: selected ? 1 : 0
                    color: selected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                    Behavior on color {
                        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
            }
            StyledText {
                id: buttonTextWidget
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.small
                color: selected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                text: buttonText
                Behavior on color {
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }
    }
}
