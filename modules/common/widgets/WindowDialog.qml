import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    id: root

    property bool show: false
    default property alias contentData: contentColumn.data
    // Negative means content-sized. Fixed-height consumers keep assigning an
    // explicit value; compact dialogs follow their measured content instead of
    // freezing whatever height happened to exist during Component completion.
    property real backgroundHeight: -1
    property real backgroundWidth: 350
    property real backgroundAnimationMovementDistance: 60
    property string zzzLabel: "DIALOG"
    property string zzzIndex: "UI"
    property string zzzGhostText: "DIALOG"
    property color zzzAccentColor: Appearance.zzz.secondary
    property bool zzzShowBurst: true
    property bool zzzShowTicks: false
    property bool zzzDecorationsEnabled: true
    
    signal dismiss()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.dismiss();
            event.accepted = true;
        }
    }

    color: root.show ? Appearance.colors.colScrim : ColorUtils.transparentize(Appearance.colors.colScrim)
    Behavior on color {
        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    visible: root.show || dialogBackground.implicitHeight > 0 || contentColumn.opacity > 0

    onShowChanged: dialogBackgroundHeightAnimation.easing.bezierCurve = show
        ? Appearance.animationCurves.emphasizedDecel
        : Appearance.animationCurves.emphasizedAccel

    radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

    MouseArea { // Clicking outside the dialog should dismiss
        anchors.fill: parent
        enabled: root.show
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: root.dismiss()
    }

    GlassBackground {
        id: dialogBackground
        // Keep the animated chrome on whole-pixel geometry. Dialog content uses
        // NativeRendering, which Qt documents as unsuitable under transforms;
        // centering on a half pixel makes the softened result persist after open.
        x: Math.round((root.width - implicitWidth) / 2)
        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingLarge
            : Appearance.inirEverywhere ? Appearance.inir.roundingLarge
            : Appearance.rounding.large
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        fallbackColor: Appearance.zzzEverywhere ? Appearance.zzz.paper : Appearance.colors.colSurfaceContainerHigh
        inirColor: Appearance.inir.colLayer2
        auroraTransparency: Appearance.aurora.popupTransparentize * 0.85
        // ZZZ owns its wallpaper wash through ZzzPanelBackdrop. Letting both
        // layers blur the same wallpaper softens compact dialog text and chrome.
        wallpaperBackdropEnabled: !Appearance.zzzEverywhere
        border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick
            : (Appearance.angelEverywhere || Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
            : Appearance.angelEverywhere ? Appearance.angel.colBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder 
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : "transparent"
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        
        readonly property real measuredContentHeight: contentColumn.implicitHeight
            + dialogBackground.contentPad * 2
        readonly property real resolvedHeight: Math.round(root.backgroundHeight >= 0
            ? root.backgroundHeight : measuredContentHeight)
        property real targetY: Math.round(root.height / 2 - resolvedHeight / 2)
        y: root.show ? targetY : (targetY - root.backgroundAnimationMovementDistance)
        implicitWidth: Math.round(root.backgroundWidth)
        // Corner radius is visual, not spacing. Zero-radius Angel and ZZZ
        // presets still need a readable inset around dialog content.
        readonly property real contentPad: Appearance.zzzEverywhere
            ? Math.max(radius, Appearance.zzz.markerLength + Appearance.zzz.borderThick * 5)
            : Appearance.cookieEverywhere ? Appearance.sizes.spacingLarge
            : Math.max(radius, Appearance.sizes.spacingLarge)
        implicitHeight: root.show ? resolvedHeight : 0
        Behavior on implicitHeight {
            NumberAnimation {
                id: dialogBackgroundHeightAnimation
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: dialogBackgroundHeightAnimation.duration
                easing.type: dialogBackgroundHeightAnimation.easing.type
                easing.bezierCurve: dialogBackgroundHeightAnimation.easing.bezierCurve
            }
        }

        MouseArea { // So clicking inside the dialog won't dismiss
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }

        Loader {
            anchors.fill: parent
            active: root.zzzDecorationsEnabled && Appearance.zzzEverywhere
            sourceComponent: ZzzPanelBackdrop {
                label: root.zzzLabel
                index: root.zzzIndex
                ghostText: root.zzzGhostText
                accentColor: root.zzzAccentColor
                showBurst: false
                showTicks: false
                showGrid: false
                horizontalBias: 0.08
                verticalBias: 0.06
                ghostWidthFactor: 0.84
                ghostStrength: 0.7
            }
        }

    }

    // Keep text and icons at their final pixel-aligned position while the chrome
    // performs its reveal motion. Native-rendered glyphs stay crisp because they
    // are no longer children of the translated/resized background item.
    ColumnLayout {
        id: contentColumn
        x: dialogBackground.x + dialogBackground.contentPad
        y: dialogBackground.targetY + dialogBackground.contentPad
        width: Math.max(0, dialogBackground.implicitWidth - dialogBackground.contentPad * 2)
        height: Math.max(0, dialogBackground.resolvedHeight - dialogBackground.contentPad * 2)
        spacing: 16
        opacity: root.show ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
