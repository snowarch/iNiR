pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets

/**
 * Material 3 slider. See https://m3.material.io/components/sliders/overview
 * It doesn't exactly match the spec because it does not make sense to have stuff on a computer that fucking huge.
 * Should be at 3/4 scale...
 */
 
Slider {
    id: root

    // Settings search integration (optional)
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1
    property string settingsSearchLabel: ""
    property string settingsSearchDescription: ""
    property list<string> settingsSearchKeywords: []

    property list<real> stopIndicatorValues: [1]
    enum Configuration {
        Wavy = 4,
        XS = 12,
        S = 18,
        M = 30,
        L = 42,
        XL = 72
    }

    property var configuration: StyledSlider.Configuration.S

    property real handleDefaultWidth: Appearance.regaliaEverywhere ? 15 : Appearance.zzzEverywhere ? 0 : 3
    property real handlePressedWidth: Appearance.regaliaEverywhere ? 13 : Appearance.zzzEverywhere ? 0 : 1.5
    property color highlightColor: Appearance.regaliaEverywhere ? Appearance.regalia.hardwarePrimary
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.zzzEverywhere ? Appearance.zzz.accentSoft : Appearance.colors.colPrimary
    property color trackColor: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlate
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
        : Appearance.zzzEverywhere ? Appearance.zzz.metricTrack
        : Appearance.colors.colSecondaryContainer
    property color handleColor: Appearance.regaliaEverywhere ? Appearance.regalia.hardwarePrimary
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.zzzEverywhere ? "transparent" : Appearance.colors.colPrimary
    property color dotColor: Appearance.regaliaEverywhere ? Appearance.regalia.onMuted
        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.zzzEverywhere ? Appearance.zzz.onMuted : Appearance.colors.colOnSecondaryContainer
    property color dotColorHighlighted: Appearance.regaliaEverywhere ? Appearance.regalia.hardwarePrimaryInk
        : Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
        : Appearance.zzzEverywhere ? Appearance.zzz.onColor : Appearance.colors.colOnPrimary
    property real unsharpenRadius: Appearance.rounding.unsharpen
    property real trackWidth: Appearance.regaliaEverywhere ? Math.min(7, configuration) : configuration
    property real trackRadius: Appearance.regaliaEverywhere ? Appearance.regalia.roundVerySmall
        : trackWidth >= StyledSlider.Configuration.XL ? 21
        : trackWidth >= StyledSlider.Configuration.L ? 12
        : trackWidth >= StyledSlider.Configuration.M ? 9
        : trackWidth >= StyledSlider.Configuration.S ? 6
        : height / 2
    property real handleHeight: Appearance.regaliaEverywhere ? 15
        : (configuration === StyledSlider.Configuration.Wavy) ? 24 : Math.max(33, trackWidth + 9)
    property real handleWidth: root.pressed ? handlePressedWidth : handleDefaultWidth
    property real handleMargins: 4
    property real trackDotSize: 3
    property string tooltipContent: `${Math.round(value * 100)}%`
    property bool scrollable: false
    property bool _userInteracting: false
    property bool wavy: !Appearance.regaliaEverywhere && configuration === StyledSlider.Configuration.Wavy
    property bool animateWave: true
    property real waveAmplitudeMultiplier: wavy ? 0.5 : 0
    property real waveFrequency: 6
    readonly property bool usesWaveTrack: !Appearance.regaliaEverywhere
        && (wavy || configuration === StyledSlider.Configuration.Wavy)

    Behavior on waveAmplitudeMultiplier {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    leftPadding: handleMargins
    rightPadding: handleMargins
    property real effectiveDraggingWidth: Math.max(0, width - leftPadding - rightPadding)

    Layout.fillWidth: true
    from: 0
    to: 1

    function _findSettingsContext() {
        var page = null;
        var sectionTitle = "";
        var groupTitle = "";
        var p = root.parent;
        while (p) {
            if (!page && p.hasOwnProperty("settingsPageIndex")) {
                page = p;
            }
            if (p.hasOwnProperty("title")) {
                if (!sectionTitle && p.hasOwnProperty("icon")) {
                    sectionTitle = p.title;
                } else if (!groupTitle && !p.hasOwnProperty("icon")) {
                    groupTitle = p.title;
                }
            }
            p = p.parent;
        }
        return { page: page, sectionTitle: sectionTitle, groupTitle: groupTitle };
    }

    function focusFromSettingsSearch() {
        var p = root.parent;
        while (p) {
            if (p.hasOwnProperty("expanded") && p.hasOwnProperty("collapsible")) {
                p.expanded = true;
                break;
            }
            p = p.parent;
        }
        root.forceActiveFocus();
    }

    Component.onCompleted: {
        if (!enableSettingsSearch)
            return;
        if (typeof SettingsSearchRegistry === "undefined")
            return;

        var ctx = _findSettingsContext();
        var page = ctx.page;
        var pageIndex = page && page.settingsPageIndex !== undefined ? page.settingsPageIndex : -1;
        if (pageIndex < 0)
            return;

        var sectionTitle = ctx.sectionTitle;
        var label = root.settingsSearchLabel || ctx.groupTitle || sectionTitle;

        settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: pageIndex,
            pageName: page && page.settingsPageName ? page.settingsPageName : "",
            section: sectionTitle,
            label: label,
            description: root.settingsSearchDescription || "",
            keywords: root.settingsSearchKeywords || []
        });
    }

    Component.onDestruction: {
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.unregisterControl(root);
        }
    }

    Timer {
        id: _userInteractingReset
        interval: 250
        repeat: false
        onTriggered: root._userInteracting = false
    }

    // No animation on value - instant response to user input
    // External changes (volume changed by other app) also instant, which is fine

    onPressedChanged: {
        if (pressed) {
            root._userInteracting = true
        } else {
            _userInteractingReset.restart()
            root.moved()
        }
    }

    Behavior on handleMargins {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    component TrackDot: Rectangle {
        required property real value
        property real normalizedValue: (value - root.from) / (root.to - root.from)
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleMargins + (normalizedValue * root.effectiveDraggingWidth) - (root.trackDotSize / 2)
        width: root.trackDotSize
        height: root.trackDotSize
        radius: Math.min(width, height) / 2
        color: normalizedValue > root.visualPosition ? root.dotColor : root.dotColorHighlighted

        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => mouse.accepted = false
        cursorShape: root.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor 

        onWheel: (event) => {
            if (!root.scrollable) {
                event.accepted = false
                return
            }

            root._userInteracting = true
            _userInteractingReset.restart()

            const step = root.stepSize > 0 ? root.stepSize : 0.02
            if (event.angleDelta.y > 0) {
                root.value = Math.min(root.value + step, root.to)
                root.moved()
            } else {
                root.value = Math.max(root.value - step, root.from)
                root.moved()
            }
        }
    }

    background: Item {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        implicitHeight: trackWidth

        // Fill left
        Loader {
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
            }
            width: Math.max(0, root.visualPosition * root.effectiveDraggingWidth - handle.implicitWidth / 2)
            height: root.trackWidth
            active: !root.usesWaveTrack
            sourceComponent: Rectangle {
                color: root.highlightColor
                topLeftRadius: root.trackRadius
                bottomLeftRadius: root.trackRadius
                topRightRadius: root.unsharpenRadius
                bottomRightRadius: root.unsharpenRadius
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Appearance.regaliaEverywhere
                            ? ColorUtils.mix(root.highlightColor, Appearance.regalia.hardwarePrimaryInk, 0.91)
                            : root.highlightColor
                    }
                    GradientStop {
                        position: 1
                        color: Appearance.regaliaEverywhere
                            ? ColorUtils.mix(root.highlightColor, Appearance.m3colors.m3shadow, 0.90)
                            : root.highlightColor
                    }
                }
            }
        }

        Loader {
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
            }
            width: Math.max(0, root.visualPosition * root.effectiveDraggingWidth - handle.implicitWidth / 2)
            height: root.trackWidth * (1 + 2 * Math.max(0.5, Math.abs(root.waveAmplitudeMultiplier)))
            active: root.usesWaveTrack
            sourceComponent: WavyLine {
                anchors.fill: parent
                frequency: root.waveFrequency
                fullLength: root.width
                color: root.highlightColor
                lineWidth: root.trackWidth
                amplitudeMultiplier: root.waveAmplitudeMultiplier
                animate: root.animateWave && root.wavy
            }
        }

        // Fill right
        Rectangle {
            anchors {
                verticalCenter: parent.verticalCenter
                right: parent.right
            }
            width: Math.max(0, (1 - root.visualPosition) * root.effectiveDraggingWidth - handle.implicitWidth / 2)
            height: trackWidth
            color: root.trackColor
            topRightRadius: root.trackRadius
            bottomRightRadius: root.trackRadius
            topLeftRadius: root.unsharpenRadius
            bottomLeftRadius: root.unsharpenRadius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Appearance.regaliaEverywhere
                        ? ColorUtils.mix(root.trackColor, Appearance.regalia.onColor, 0.965)
                        : root.trackColor
                }
                GradientStop {
                    position: 1
                    color: Appearance.regaliaEverywhere
                        ? ColorUtils.mix(root.trackColor, Appearance.m3colors.m3shadow, 0.90)
                        : root.trackColor
                }
            }
        }

        // Stop indicators
        Repeater {
            model: root.stopIndicatorValues
            TrackDot {
                required property real modelData
                value: modelData
                anchors.verticalCenter: parent?.verticalCenter
            }
        }
    }

    handle: Rectangle {
        id: handle

        implicitWidth: root.handleWidth
        implicitHeight: root.handleHeight
        x: root.handleMargins + (root.visualPosition * root.effectiveDraggingWidth) - (implicitWidth / 2)
        anchors.verticalCenter: parent.verticalCenter
        radius: Appearance.regaliaEverywhere ? 4 : Math.min(width, height) / 2
        color: root.handleColor
        border.width: 0
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Appearance.regaliaEverywhere
                    ? ColorUtils.mix(root.handleColor, Appearance.regalia.hardwarePrimaryInk, 0.88)
                    : root.handleColor
            }
            GradientStop { position: 0.5; color: root.handleColor }
            GradientStop {
                position: 1
                color: Appearance.regaliaEverywhere
                    ? ColorUtils.mix(root.handleColor, Appearance.m3colors.m3shadow, 0.86)
                    : root.handleColor
            }
        }

        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        StyledToolTip {
            extraVisibleCondition: root.pressed
            text: root.tooltipContent
            font {
                family: Appearance.font.family.numbers
                variableAxes: Appearance.font.variableAxes.numbers
                features: { "tnum": 1 }
            }
        }
    }
}
