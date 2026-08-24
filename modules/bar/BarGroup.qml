import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.pill
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    readonly property alias islandSurface: islandSurface
    property bool nativeBlurActive: false
    property var screen: null
    property bool vertical: false
    property bool spectrumEnabled: false
    property var spectrumPoints: []
    property real spectrumCeiling: 1000
    property string spectrumType: "bars"
    property real spectrumOpacity: 0.35
    property real spectrumFillRatio: 0.6
    property string spectrumBarsOrigin: "bottom"
    property real spectrumDensity: 12
    property real spectrumGap: 2
    property int spectrumSmoothing: 2
    property string spectrumWaveMode: "fill"
    property real spectrumLineWidth: 2
    property real spectrumEdgeInset: 0
    property real spectrumEdgeSoftness: 0.28
    property string spectrumFrequencyProfile: "flat"
    property real spectrumAccentStrength: 0.7
    property Item spectrumDomain: null
    // Islands: the capsule needs real breathing room around content (matches
    // the edge islands' inner padding); classic groups keep the tight fit and
    // bare chips (no surface of their own) don't pad like a capsule.
    property real padding: islandStyle && !bare ? 12 : 8
    readonly property bool cardStyleEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && (Config.options?.bar?.cornerStyle === 3)
    // Islands bar appearance: each group is its own floating surface
    readonly property bool islandStyle: !vertical && (Config.options?.bar?.appearanceStyle ?? "classic") === "islands"
    // Bare: no surface of its own — for groups that live INSIDE another island
    // (e.g. the weather chip in an edge island) so cards never nest.
    property bool bare: false
    readonly property bool zzzPlate: false
    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight
    // Natural content width regardless of any implicitWidth override, so the bar
    // can size a pill to its content without a binding loop.
    readonly property real contentWidth: gridLayout.implicitWidth + padding * 2
    // True when the group has no visible children (Qt layouts exclude
    // visible:false items, so an all-hidden zone reports ~0 inner width). Lets
    // callers collapse the pill entirely instead of showing a ghost background.
    readonly property bool empty: gridLayout.implicitWidth < 1
    default property alias items: gridLayout.children

    readonly property real _spectrumX: {
        const geometryDependency = root.x + root.y + root.width + root.height
            + (root.parent?.x ?? 0) + (root.parent?.width ?? 0)
        if (!root.spectrumDomain || !(root.spectrumDomain.width > 0))
            return 0
        return root.mapToItem(root.spectrumDomain, 0, 0).x
    }
    readonly property real _spectrumStartRatio: !root.spectrumDomain
        ? 0
        : Math.max(0, Math.min(1, root._spectrumX / root.spectrumDomain.width))
    readonly property real _spectrumEndRatio: !root.spectrumDomain
        ? 1
        : Math.max(root._spectrumStartRatio,
            Math.min(1, (root._spectrumX + root.width) / root.spectrumDomain.width))

    // El fondo de cada grupo de la barra ahora sale del molde compartido
    // (PanelSurface) en vez de dibujarse a mano. Misma pinta que antes, pero
    // controlada desde un solo lugar → cambiar PanelSurface cambia toda la barra.
    PanelSurface {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        visible: !root.islandStyle && !root.bare
        cardStyle: root.cardStyleEverywhere
        borderless: !root.islandStyle && (Config.options?.bar?.borderless ?? false)
        elevation: 1
        // En zzz la barra mantiene su contorno unificado; los grupos quedan transparentes.
        zzzChamfer: false
    }

    // Islands wear the Ricelin pill card in EVERY global style — picking the
    // islands bar is an explicit opt-in to that dialect, so the zzz "groups
    // stay transparent" doctrine (which left the centre groups naked over the
    // wallpaper) does not apply here.
    IslandPanel {
        id: islandSurface
        readonly property int inset: Config.options?.bar?.islands?.inset ?? 4
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : inset
            bottomMargin: root.vertical ? 0 : inset
            leftMargin: root.vertical ? inset : 0
            rightMargin: root.vertical ? inset : 0
        }
        visible: root.islandStyle && !root.bare
        glassEnabled: true
        nativeBlurActive: root.nativeBlurActive
        screen: root.screen
        glassScreenX: {
            const geometryDependency = root.x + root.width + islandSurface.x
            return islandSurface.mapToItem(null, 0, 0).x
        }
        glassScreenY: {
            const geometryDependency = root.y + root.height + islandSurface.y
            return islandSurface.mapToItem(null, 0, 0).y
        }
        glassScreenWidth: root.screen?.width ?? 1920
        glassScreenHeight: root.screen?.height ?? 1080

        CavaSpectrum {
            anchors.fill: parent
            active: root.spectrumEnabled && islandSurface.visible
            threadedRendering: true
            points: active ? root.spectrumPoints : []
            normalizationCeiling: active ? root.spectrumCeiling : 100
            visualizerType: root.spectrumType
            spectrumOpacity: root.spectrumOpacity
            fillRatio: root.spectrumFillRatio
            spectrumColor: Appearance.colors.colPrimary
            sampleStartRatio: root._spectrumStartRatio
            sampleEndRatio: root._spectrumEndRatio
            barsOrigin: root.spectrumBarsOrigin
            pixelsPerBar: root.spectrumDensity
            barSpacing: root.spectrumGap
            smoothing: root.spectrumSmoothing
            waveMode: root.spectrumWaveMode
            lineWidth: root.spectrumLineWidth
            edgeInset: root.spectrumEdgeInset
            edgeSoftness: root.spectrumEdgeSoftness
            frequencyProfile: root.spectrumFrequencyProfile
            accentStrength: root.spectrumAccentStrength
            topLeftRadius: islandSurface.radius
            topRightRadius: islandSurface.radius
            bottomLeftRadius: islandSurface.radius
            bottomRightRadius: islandSurface.radius
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors {
            verticalCenter: root.vertical ? undefined : parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
            top: root.vertical ? parent.top : undefined
            bottom: root.vertical ? parent.bottom : undefined
            margins: root.padding
        }
        columnSpacing: 4
        rowSpacing: 12
    }
}
