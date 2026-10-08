pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.services
import qs.services.deferred

// Shared presentation layer for iNiR's internal Cava consumers.
// CavaService owns audio acquisition; this item owns only rendering/response.
Item {
    id: root

    property var points: []
    property bool active: false
    // False holds the last frame: no new points, no motion clock, still drawn.
    property bool animate: true
    property var _shownPoints: []
    Binding {
        target: root
        property: "_shownPoints"
        value: root.points
        when: root.animate
        restoreMode: Binding.RestoreNone
    }
    property string visualizerType: "wave" // wave | bars | organic
    property real normalizationCeiling: CavaService.normalizationCeiling
    property var spectrumColors: CavaTheme.visualizerColors
    property color spectrumColor: CavaTheme.primaryColor
    property real spectrumOpacity: 0.45
    property bool threadedRendering: true
    property int smoothing: 2
    property string frequencyProfile: "flat"
    property real accentStrength: 0.7
    property real fillRatio: 0.9
    readonly property bool effectiveActive: root.active
        && !GameMode.visualizersSuppressed
        && !Appearance.gameModeMinimal

    property int barCount: 32
    // Compatibility with CavaSpectrum callers that size bars by pixel density.
    property real pixelsPerBar: 0
    property real barSpacing: 2
    property real barRadius: 2
    property real barMinHeight: 1
    property string barsOrigin: "mirror"
    property string waveMode: "fill"
    property real lineWidth: 2
    property real edgeInset: 0
    property real edgeSoftness: 0.28
    property real topLeftRadius: -1
    property real topRightRadius: -1
    property real bottomLeftRadius: -1
    property real bottomRightRadius: -1
    property real sampleStartRatio: 0
    property real sampleEndRatio: 1
    property bool reverseFrequency: false
    property real startOpacity: 1
    property real endOpacity: 1
    property real startTaper: -1
    property real endTaper: -1
    property var clipSegments: []

    readonly property var organicPoints: {
        const source = root._shownPoints ?? []
        const start = Math.max(0, Math.min(1, root.sampleStartRatio))
        const end = Math.max(start, Math.min(1, root.sampleEndRatio))
        const samples = source.slice(Math.floor(start * source.length),
            Math.ceil(end * source.length))
        return root.reverseFrequency ? samples.reverse() : samples
    }

    property real organicSensitivity: 0.75
    property real organicPulse: 0.72
    property real organicCompression: 0.0
    property real organicMotionSpeed: 1.0
    property real organicIdleMotion: 0.16
    property real organicGlow: 0.45
    property real organicOpacity: 0.85
    property real organicOverscan: 1.34
    property real organicPresentationScale: 1.0
    property real organicBaseRadius: 0.510
    property real organicPresentationMode: 0.0
    property int organicScreenEdge: 2
    property real organicHollowAmount: 1.0
    property bool organicStretchToHost: false
    property real organicEdgeBaseRadius: 0.39
    property vector2d organicEdgeCardHalf: Qt.vector2d(0.72, 0.58)
    property vector2d organicEdgeReachHalf: organicEdgeCardHalf
    property real organicEdgeCornerRadius: 0.12
    property vector4d organicEdgeReachScales: Qt.vector4d(1, 1, 1, 1)
    property vector4d organicEdgeDirections: Qt.vector4d(1, 1, 1, 1)
    property bool organicEdgeAura: false
    property real organicEdgeReach: Math.max(18, Math.min(48, Math.min(width, height) * 0.82))
    property real organicEdgeRenderPadding: Math.max(22,
        organicEdgeReach * (0.72 + Math.max(0, Math.min(1.5, organicGlow)) * 0.42))
    readonly property real _organicEdgeMargin: root.organicEdgeReach + root.organicEdgeRenderPadding
    readonly property bool _organicUsesSegmentFields: root.organicEdgeAura
        && (root.clipSegments?.length ?? 0) > 0

    component EdgeOrganicField: Item {
        id: edgeField
        required property real cardX
        required property real cardY
        required property real cardWidth
        required property real cardHeight
        required property real cardRadius
        property bool drawing: true

        x: cardX - root._organicEdgeMargin
        y: cardY - root._organicEdgeMargin
        width: cardWidth + root._organicEdgeMargin * 2
        height: cardHeight + root._organicEdgeMargin * 2
        visible: root.visualizerType === "organic" && root.organicEdgeAura

        OrganicAudioBlob {
            anchors.fill: parent
            active: root.effectiveActive && edgeField.visible && edgeField.drawing
            animate: root.animate && edgeField.drawing
            points: root.organicPoints
            normalizationCeiling: root.normalizationCeiling
            primaryColor: root.spectrumColors?.length > 0
                ? root.spectrumColors[0] : root.spectrumColor
            secondaryColor: root.spectrumColors?.length > 1
                ? root.spectrumColors[Math.floor((root.spectrumColors.length - 1) / 2)]
                : primaryColor
            tertiaryColor: root.spectrumColors?.length > 2
                ? root.spectrumColors[root.spectrumColors.length - 1]
                : secondaryColor
            smoothing: root.smoothing
            frequencyProfile: root.frequencyProfile
            accentStrength: root.accentStrength
            mirroredStereo: Config.options?.appearance?.cava?.stereo ?? true
            sensitivity: root.organicSensitivity
            amplitude: root.fillRatio
            pulseStrength: root.organicPulse
            compression: root.organicCompression
            motionSpeed: root.organicMotionSpeed
            idleMotion: root.organicIdleMotion
            glowStrength: root.organicGlow
            overscan: 1.0
            presentationScale: 1.0
            baseRadius: root.organicBaseRadius
            presentationMode: 2.0
            stretchToHost: true
            hollowAmount: 0.0
            edgeBaseRadius: root.organicEdgeBaseRadius
            edgeCardHalf: Qt.vector2d(
                edgeField.cardWidth / Math.max(1, edgeField.width),
                edgeField.cardHeight / Math.max(1, edgeField.height))
            edgeReachHalf: Qt.vector2d(
                (edgeField.cardWidth + root.organicEdgeReach * 2) / Math.max(1, edgeField.width),
                (edgeField.cardHeight + root.organicEdgeReach * 2) / Math.max(1, edgeField.height))
            edgeCornerRadius: edgeField.cardRadius * 2 / Math.max(1, edgeField.height)
            edgeReachScales: root.organicEdgeReachScales
            edgeDirections: root.organicEdgeDirections
            opacity: root.organicOpacity
        }
    }

    // In a host that opts in (the desktop background, a full-output window), the moving field can draw in a small
    // surface of its own once the widget around it is still (LiveLayer): at the display rate it otherwise repaints
    // the whole output and Niri recomposes it. Only when the owner says nothing of its own draws over the field
    // (`detachable`): the surface sits above the whole host, so an aura behind a card or artwork on top of the
    // field would end up under it. Bars and other small windows are not hosts: it draws in place there anyway.
    property bool detachable: false
    LiveLayer {
        anchors.fill: parent
        allowed: root.detachable
        live: root.effectiveActive && root.animate
        pad: root.visualizerType === "organic" && root.organicEdgeAura ? Math.ceil(root._organicEdgeMargin) : 0
        content: field
    }

    Component {
        id: field
        Item {
            id: drawn
            property bool drawing: false

            CavaSpectrum {
                anchors.fill: parent
                visible: root.visualizerType !== "organic"
                points: root._shownPoints
                sampleStartRatio: root.sampleStartRatio
                sampleEndRatio: root.sampleEndRatio
                reverseFrequency: root.reverseFrequency
                startOpacity: root.startOpacity
                endOpacity: root.endOpacity
                startTaper: root.startTaper
                endTaper: root.endTaper
                clipSegments: root.clipSegments
                active: root.effectiveActive && root.visualizerType !== "organic" && drawn.drawing
                threadedRendering: root.threadedRendering
                visualizerType: root.visualizerType
                normalizationCeiling: root.normalizationCeiling
                spectrumColors: root.spectrumColors
                spectrumColor: root.spectrumColor
                spectrumOpacity: root.spectrumOpacity
                fillRatio: root.fillRatio
                pixelsPerBar: root.pixelsPerBar > 0
                    ? root.pixelsPerBar
                    : Math.max(3, (width + root.barSpacing) / Math.max(4, root.barCount))
                barSpacing: root.barSpacing
                barMinHeight: root.barMinHeight
                barRadius: root.barRadius
                barsOrigin: root.barsOrigin
                smoothing: root.smoothing
                waveMode: root.waveMode
                lineWidth: root.lineWidth
                edgeInset: root.edgeInset
                edgeSoftness: root.edgeSoftness
                frequencyProfile: root.frequencyProfile
                accentStrength: root.accentStrength
                mirroredStereo: Config.options?.appearance?.cava?.stereo ?? true
                topLeftRadius: root.topLeftRadius
                topRightRadius: root.topRightRadius
                bottomLeftRadius: root.bottomLeftRadius
                bottomRightRadius: root.bottomRightRadius
            }

            OrganicAudioBlob {
                id: organic
                anchors.fill: parent
                visible: root.visualizerType === "organic" && !root.organicEdgeAura
                active: root.effectiveActive && visible && drawn.drawing
                animate: root.animate && drawn.drawing
                points: root.organicPoints
                // Bar hosts constrain the halo to their surface; standalone Organic
                // widgets retain their intentional overscan.
                layer.enabled: visible && (root.topLeftRadius >= 0 || root.topRightRadius >= 0
                    || root.bottomLeftRadius >= 0 || root.bottomRightRadius >= 0
                    || root.startOpacity < 1 || root.endOpacity < 1)
                layer.effect: GE.OpacityMask {
                    maskSource: Item {
                        width: organic.width
                        height: organic.height

                        Rectangle {
                            anchors.fill: parent
                            visible: (root.clipSegments?.length ?? 0) === 0
                            topLeftRadius: Math.max(0, root.topLeftRadius)
                            topRightRadius: Math.max(0, root.topRightRadius)
                            bottomLeftRadius: Math.max(0, root.bottomLeftRadius)
                            bottomRightRadius: Math.max(0, root.bottomRightRadius)
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, Math.max(0, Math.min(1, root.startOpacity))) }
                                GradientStop { position: 0.5; color: "white" }
                                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, Math.max(0, Math.min(1, root.endOpacity))) }
                            }
                        }

                        Repeater {
                            model: root.clipSegments ?? []
                            Rectangle {
                                required property var modelData
                                x: modelData?.x ?? 0
                                y: modelData?.y ?? 0
                                width: Math.max(0, modelData?.width ?? 0)
                                height: Math.max(0, modelData?.height ?? 0)
                                topLeftRadius: Math.max(0, modelData?.radii?.[0] ?? 0)
                                topRightRadius: Math.max(0, modelData?.radii?.[1] ?? 0)
                                bottomRightRadius: Math.max(0, modelData?.radii?.[2] ?? 0)
                                bottomLeftRadius: Math.max(0, modelData?.radii?.[3] ?? 0)
                                color: "white"
                            }
                        }
                    }
                }
                normalizationCeiling: root.normalizationCeiling
                primaryColor: root.spectrumColors?.length > 0
                    ? root.spectrumColors[0] : root.spectrumColor
                secondaryColor: root.spectrumColors?.length > 1
                    ? root.spectrumColors[Math.floor((root.spectrumColors.length - 1) / 2)]
                    : primaryColor
                tertiaryColor: root.spectrumColors?.length > 2
                    ? root.spectrumColors[root.spectrumColors.length - 1]
                    : secondaryColor
                smoothing: root.smoothing
                frequencyProfile: root.frequencyProfile
                accentStrength: root.accentStrength
                mirroredStereo: Config.options?.appearance?.cava?.stereo ?? true
                sensitivity: root.organicSensitivity
                amplitude: root.fillRatio
                pulseStrength: root.organicPulse
                compression: root.organicCompression
                motionSpeed: root.organicMotionSpeed
                idleMotion: root.organicIdleMotion
                glowStrength: root.organicGlow
                overscan: root.organicOverscan
                presentationScale: root.organicPresentationScale
                baseRadius: root.organicBaseRadius
                presentationMode: root.organicPresentationMode
                screenEdge: root.organicScreenEdge
                stretchToHost: root.organicStretchToHost
                hollowAmount: root.organicHollowAmount
                edgeBaseRadius: root.organicEdgeBaseRadius
                edgeCardHalf: root.organicEdgeCardHalf
                edgeReachHalf: root.organicEdgeReachHalf
                edgeCornerRadius: root.organicEdgeCornerRadius
                edgeReachScales: root.organicEdgeReachScales
                edgeDirections: root.organicEdgeDirections
                opacity: root.organicOpacity
            }

            EdgeOrganicField {
                drawing: drawn.drawing
                visible: root.organicEdgeAura && !root._organicUsesSegmentFields
                cardX: 0
                cardY: 0
                cardWidth: root.width
                cardHeight: root.height
                cardRadius: Math.max(0, Math.max(root.topLeftRadius, root.topRightRadius,
                    root.bottomLeftRadius, root.bottomRightRadius))
            }

            Repeater {
                model: root._organicUsesSegmentFields ? (root.clipSegments ?? []) : []
                EdgeOrganicField {
                    required property var modelData
                    drawing: drawn.drawing
                    cardX: modelData?.x ?? 0
                    cardY: modelData?.y ?? 0
                    cardWidth: Math.max(0, modelData?.width ?? 0)
                    cardHeight: Math.max(0, modelData?.height ?? 0)
                    cardRadius: Math.max(0,
                        modelData?.radii?.[0] ?? 0,
                        modelData?.radii?.[1] ?? 0,
                        modelData?.radii?.[2] ?? 0,
                        modelData?.radii?.[3] ?? 0)
                }
            }
        }
    }
}
