pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root
    property QtObject darkColors
    property QtObject lightColors
    property QtObject colors
    property QtObject radius
    property QtObject font
    property QtObject transition
    property string iconsPath: `${Directories.assetsPath}/icons/fluent`
    property bool dark: Appearance.m3colors.darkmode
    property bool auroraEverywhere: (Config.options?.appearance?.globalStyle ?? "material") === "aurora"
    property bool useMaterial: (Config.options?.waffles?.theming?.useMaterialColors ?? false) || root.auroraEverywhere
    
    // Font family - reactive property at root level for proper binding updates
    readonly property string fontFamily: {
        const f = Config.options?.waffles?.theming?.font?.family;
        return (f && f.length > 0) ? f : "Noto Sans";
    }
    // Font scale - reactive property
    readonly property real fontScale: Config.options?.waffles?.theming?.font?.scale ?? 1.0

    readonly property bool transparencyEnabled: Config.options?.appearance?.transparency?.enable ?? false
    property real backgroundTransparency: root.auroraEverywhere ? (Appearance.backgroundTransparency ?? 0) : (transparencyEnabled ? 0.13 : 0)
    property real panelBackgroundTransparency: root.auroraEverywhere ? (Appearance.backgroundTransparency ?? 0) : (transparencyEnabled ? 0.12 : 0)
    property real panelLayerTransparency: root.auroraEverywhere ? (Appearance.aurora.popupSurfaceTransparentize ?? 0.5) : (root.dark ? 0.6 : 0.5)
    property real contentTransparency: root.auroraEverywhere ? (Appearance.contentTransparency ?? 0) : (root.dark ? 0.87 : 0.5)
    function applyBackgroundTransparency(col) {
        return ColorUtils.applyAlpha(col, 1 - root.backgroundTransparency)
    }
    function applyContentTransparency(col) {
        return ColorUtils.applyAlpha(col, 1 - root.contentTransparency)
    }
    lightColors: QtObject {
        id: lightColors
        property color bgPanelFooter: "#EEEEEE"
        property color bgPanelBody: "#F2F2F2"
        property color bgPanelSeparator: "#E0E0E0"
        property color bg0: "#EEEEEE"
        property color bg0Border: '#adadad'
        property color bg1: "#F7F7F7"
        property color bg1Base: "#F7F7F7"
        property color bg1Hover: "#F7F7F7"
        property color bg1Active: '#EFEFEF'
        property color bg1Border: '#d7d7d7'
        property color bg2: "#FBFBFB"
        property color bg2Base: "#FBFBFB"
        property color bg2Hover: '#ffffff'
        property color bg2Active: '#eeeeee'
        property color bg2Border: '#cdcdcd'
        property color subfg: "#5C5C5C"
        property color fg: "#000000"
        property color fg1: "#626262"
        property color inactiveIcon: "#C4C4C4"
        property color controlBgInactive: '#555458'
        property color controlBg: '#807F85'
        property color controlBgHover: '#57575B'
        property color controlFg: "#FFFFFF"
        property color accentUnfocused: "#848484"
        property color link: "#235CCF"
        property color inputBg: ColorUtils.transparentize(bg0, 0.4)
    }
    darkColors: QtObject {
        id: darkColors
        property color bgPanelFooter: "#1C1C1C"
        property color bgPanelBody: '#616161'
        property color bgPanelSeparator: "#191919"
        property color bg0: "#1C1C1C"
        property color bg0Border: "#404040"
        property color bg1Base: "#2C2C2C"
        property color bg1: "#a8a8a8"
        property color bg1Hover: "#b3b3b3"
        property color bg1Active: '#727272'
        property color bg1Border: '#bebebe'
        property color bg2Base: "#313131"
        property color bg2: '#8a8a8a'
        property color bg2Hover: '#b1b1b1'
        property color bg2Active: '#919191'
        property color bg2Border: '#bdbdbd'
        property color subfg: "#CED1D7"
        property color fg: "#FFFFFF"
        property color fg1: "#D1D1D1"
        property color inactiveIcon: "#494949"
        property color controlBgInactive: "#CDCECF"
        property color controlBg: "#9B9B9B"
        property color controlBgHover: "#CFCED1"
        property color controlFg: "#454545"
        property color accentUnfocused: "#989898"
        property color link: "#A7C9FC"
        property color inputBg: ColorUtils.transparentize(darkColors.bg0, 0.5)
    }
    colors: QtObject {
        id: colors
        property color shadow: ColorUtils.transparentize('#161616', 0.62)
        property color ambientShadow: ColorUtils.transparentize("#000000", 0.75)
        
        // Material-aware colors - use Appearance colors when useMaterial is true
        property color bgPanelFooterBase: root.useMaterial 
            ? Appearance.colors.colLayer0 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bgPanelFooter : root.lightColors.bgPanelFooter, root.panelBackgroundTransparency)
        property color bgPanelFooter: root.useMaterial 
            ? Appearance.colors.colLayer1 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bgPanelFooter : root.lightColors.bgPanelFooter, root.panelLayerTransparency)
        property color bgPanelBody: root.useMaterial 
            ? Appearance.colors.colLayer2 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bgPanelBody : root.lightColors.bgPanelBody, root.panelLayerTransparency)
        property color bgPanelSeparator: root.useMaterial 
            ? Appearance.colors.colOutlineVariant 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bgPanelSeparator : root.lightColors.bgPanelSeparator, root.backgroundTransparency)
        property color bg0Opaque: root.useMaterial 
            ? Appearance.m3colors.m3background 
            : (root.dark ? root.darkColors.bg0 : root.lightColors.bg0)
        property color bg0: root.useMaterial 
            ? Appearance.colors.colLayer0 
            : ColorUtils.transparentize(bg0Opaque, root.backgroundTransparency)
        property color bg0Border: root.useMaterial 
            ? Appearance.colors.colLayer0Border 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg0Border : root.lightColors.bg0Border, root.backgroundTransparency)
        property color bg1Base: root.useMaterial 
            ? Appearance.colors.colLayer1 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg1Base : root.lightColors.bg1Base, root.backgroundTransparency)
        property color bg1: root.useMaterial 
            ? Appearance.colors.colLayer1 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg1 : root.lightColors.bg1, root.contentTransparency)
        property color bg1Hover: root.useMaterial 
            ? Appearance.colors.colLayer1Hover 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg1Hover : root.lightColors.bg1Hover, root.contentTransparency)
        property color bg1Active: root.useMaterial 
            ? Appearance.colors.colLayer1Active 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg1Active : root.lightColors.bg1Active, root.contentTransparency)
        property color bg1Border: root.useMaterial 
            ? Appearance.colors.colOutlineVariant 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg1Border : root.lightColors.bg1Border, root.contentTransparency)
        property color bg2Base: root.useMaterial 
            ? Appearance.colors.colLayer2 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg2Base : root.lightColors.bg2Base, root.backgroundTransparency)
        property color bg2: root.useMaterial 
            ? Appearance.colors.colLayer2 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg2 : root.lightColors.bg2, root.contentTransparency)
        property color bg2Hover: root.useMaterial 
            ? Appearance.colors.colLayer2Hover 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg2Hover : root.lightColors.bg2Hover, root.contentTransparency)
        property color bg2Active: root.useMaterial 
            ? Appearance.colors.colLayer2Active 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg2Active : root.lightColors.bg2Active, root.contentTransparency)
        property color bg2Border: root.useMaterial 
            ? Appearance.colors.colOutlineVariant 
            : ColorUtils.transparentize(root.dark ? root.darkColors.bg2Border : root.lightColors.bg2Border, root.contentTransparency)
        property color subfg: root.useMaterial 
            ? Appearance.colors.colSubtext 
            : (root.dark ? root.darkColors.subfg : root.lightColors.subfg)
        property color fg: root.useMaterial 
            ? Appearance.colors.colOnLayer0 
            : (root.dark ? root.darkColors.fg : root.lightColors.fg)
        property color fg1: root.useMaterial 
            ? Appearance.colors.colOnLayer1 
            : (root.dark ? root.darkColors.fg1 : root.lightColors.fg1)
        property color inactiveIcon: root.useMaterial 
            ? Appearance.colors.colOnLayer1Inactive 
            : (root.dark ? root.darkColors.inactiveIcon : root.lightColors.inactiveIcon)
        property color controlBgInactive: root.useMaterial 
            ? Appearance.colors.colSecondaryContainer 
            : (root.dark ? root.darkColors.controlBgInactive : root.lightColors.controlBgInactive)
        property color controlBg: root.useMaterial 
            ? Appearance.colors.colSecondary 
            : (root.dark ? root.darkColors.controlBg : root.lightColors.controlBg)
        property color controlBgHover: root.useMaterial 
            ? Appearance.colors.colSecondaryHover 
            : (root.dark ? root.darkColors.controlBgHover : root.lightColors.controlBgHover)
        property color controlFg: root.useMaterial 
            ? Appearance.colors.colOnSecondary 
            : (root.dark ? root.darkColors.controlFg : root.lightColors.controlFg)
        property color inputBg: root.useMaterial 
            ? Appearance.colors.colLayer1 
            : (root.dark ? root.darkColors.inputBg : root.lightColors.inputBg)
        property color link: root.useMaterial 
            ? Appearance.colors.colPrimary 
            : (root.dark ? root.darkColors.link : root.lightColors.link)
        property color danger: "#C42B1C"
        property color dangerActive: "#B62D1F"
        property color warning: "#FF9900"
        property color accent: Appearance.colors.colPrimary
        property color accentHover: Appearance.colors.colPrimaryHover
        property color accentActive: Appearance.colors.colPrimaryActive
        property color accentUnfocused: root.useMaterial 
            ? Appearance.colors.colOutline 
            : (root.dark ? root.darkColors.accentUnfocused : root.lightColors.accentUnfocused)
        property color accentFg: ColorUtils.isDark(accent) ? "#FFFFFF" : "#000000"
        property color selection: Appearance.colors.colPrimaryContainer
        property color selectionFg: Appearance.colors.colOnPrimaryContainer
    }

    radius: QtObject {
        id: radius
        property int none: 0
        property int small: 2
        property int medium: 4
        property int large: 8
        property int xLarge: 12
    }

    font: QtObject {
        id: font
        property QtObject family: QtObject {
            // Delegates to root.fontFamily for reactive updates
            readonly property string ui: root.fontFamily
        }
        property QtObject variableAxes: QtObject {
            property var ui: ({
                "wdth": 25
            })
        }
        property QtObject weight: QtObject {
            property int thin: Font.Normal
            property int regular: Font.Medium
            property int strong: Font.DemiBold
            property int stronger: (Font.DemiBold + 2*Font.Bold) / 3
            property int strongest: Font.Bold
        }
        property QtObject pixelSize: QtObject {
            property real tiny: Math.round(9 * root.fontScale)
            property real small: Math.round(10 * root.fontScale)
            property real normal: Math.round(11 * root.fontScale)
            property real large: Math.round(13 * root.fontScale)
            property real larger: Math.round(15 * root.fontScale)
            property real xlarger: Math.round(17 * root.fontScale)
        }
    }

    transition: QtObject {
        id: transition

        // Respect GameMode - disable animations when Appearance says so
        readonly property bool enabled: Appearance.animationsEnabled
        
        property int velocity: 850

        // Windows 11 / Fluent Design inspired easing curves
        property QtObject easing: QtObject {
            property QtObject bezierCurve: QtObject {
                // Standard curves
                readonly property list<real> easeInOut: [0.42, 0.00, 0.58, 1.00, 1, 1]
                readonly property list<real> easeIn: [0.42, 0.0, 1.0, 1.0, 1, 1]
                readonly property list<real> easeOut: [0.0, 0.0, 0.58, 1.0, 1, 1]
                
                // Fluent Design curves - Windows 11 style
                readonly property list<real> decelerate: [0.0, 0.0, 0.0, 1.0, 1, 1]      // Fast start, smooth stop (entries)
                readonly property list<real> accelerate: [0.7, 0.0, 1.0, 0.5, 1, 1]      // Smooth start, fast end (exits)
                readonly property list<real> standard: [0.4, 0.0, 0.2, 1.0, 1, 1]        // Balanced movement (Win11)
                readonly property list<real> emphasize: [0.0, 0.0, 0.2, 1.0, 1, 1]       // Dramatic deceleration
                readonly property list<real> spring: [0.175, 0.885, 0.32, 1.075, 1, 1]   // Subtle overshoot
                
                // New Windows 11 specific curves
                readonly property list<real> popIn: [0.0, 0.0, 0.0, 1.0, 1, 1]           // Pop-in effect for menus/tooltips
                readonly property list<real> popOut: [0.5, 0.0, 1.0, 0.5, 1, 1]          // Quick pop-out
                readonly property list<real> bounce: [0.34, 1.56, 0.64, 1.0, 1, 1]       // Playful bounce
                readonly property list<real> smooth: [0.25, 0.1, 0.25, 1.0, 1, 1]        // Very smooth, natural
            }
        }
        
        // Duration presets (in ms) - tuned for Windows 11 feel
        property QtObject duration: QtObject {
            readonly property int instant: 0
            readonly property int ultraFast: 67      // ~4 frames at 60fps
            readonly property int fast: 100
            readonly property int normal: 150
            readonly property int medium: 200
            readonly property int slow: 300
            readonly property int panel: 250         // Slightly faster panels
            readonly property int overlay: 300
            readonly property int page: 350          // Page transitions
        }

        // === Basic transitions (improved) ===
        
        property Component color: Component {
            ColorAnimation {
                duration: transition.enabled ? 70 : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.standard
            }
        }

        property Component opacity: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.normal : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.standard
            }
        }

        property Component resize: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.standard
            }
        }

        property Component enter: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.panel : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.decelerate
            }
        }

        property Component exit: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.accelerate
            }
        }

        property Component move: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.standard
            }
        }

        property Component rotate: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.standard
            }
        }

        property Component anchor: Component {
            AnchorAnimation {
                duration: transition.enabled ? transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.standard
            }
        }

        property Component longMovement: Component {
            NumberAnimation {
                duration: transition.enabled ? 800 : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.emphasize
            }
        }

        property Component scroll: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.slow : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.decelerate
            }
        }
        
        // === Panel/Overlay transitions (new) ===
        
        // For panels sliding in from edges
        property Component panelSlide: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.panel : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.decelerate
            }
        }
        
        // For panel scale animations
        property Component panelScale: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.panel : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.spring
            }
        }
        
        // For panel opacity
        property Component panelFade: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.standard
            }
        }
        
        // For overlay backgrounds
        property Component overlayFade: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.overlay : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.decelerate
            }
        }
        
        // === Item/List transitions (new) ===
        
        // For list items appearing
        property Component itemEnter: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.medium : 0
                easing.type: Easing.OutBack
                easing.overshoot: 0.3
            }
        }
        
        // For hover state changes
        property Component hover: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.normal : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.standard
            }
        }
        
        // For press/active state changes
        property Component press: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.fast : 0
                easing.type: Easing.OutQuad
            }
        }
        
        // === Windows 11 specific transitions ===
        
        // For menu/popup reveal (scale + fade)
        property Component menuReveal: Component {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    duration: transition.enabled ? transition.duration.normal : 0
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    property: "scale"
                    duration: transition.enabled ? transition.duration.medium : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: transition.easing.bezierCurve.popIn
                }
            }
        }
        
        // For button press feedback
        property Component buttonPress: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.ultraFast : 0
                easing.type: Easing.OutQuad
            }
        }
        
        // For smooth value changes (sliders, progress)
        property Component smoothValue: Component {
            NumberAnimation {
                duration: transition.enabled ? transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: transition.easing.bezierCurve.smooth
            }
        }
        
        // For list item stagger animations
        property Component listItem: Component {
            SequentialAnimation {
                PauseAnimation { duration: 0 }  // Will be set by staggerDelay
                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 0; to: 1
                        duration: transition.enabled ? transition.duration.normal : 0
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        property: "y"
                        from: 8
                        duration: transition.enabled ? transition.duration.medium : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: transition.easing.bezierCurve.decelerate
                    }
                }
            }
        }
        
        // === Helper functions ===
        
        // Calculate stagger delay for list items
        function staggerDelay(index: int, baseDelay: int): int {
            if (!enabled) return 0
            return Math.min(index * baseDelay, 400)  // Cap at 400ms
        }
        
        // Get duration based on distance (for natural feel)
        function durationForDistance(distance: real, minDuration: int, maxDuration: int): int {
            if (!enabled) return 0
            const normalized = Math.min(Math.abs(distance) / 200, 1)
            return minDuration + (maxDuration - minDuration) * normalized
        }
    }
}
