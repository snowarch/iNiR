pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.equalizer

// Crystalizer is 13 nested bands, not one knob — but "more sparkle" must
// stay one gesture. So: a Sparkle master that moves all 13 together, the
// three top-level switches beside it, and the 13-band strip behind a
// disclosure for the days a single band misbehaves.
//
// Nested addressing assumption (bridge contract, flagged for the
// orchestrator): band intensity travels through
//   IrisAudio.setParam("crystalizer", "band<N>.intensity", v)
// with N = 0..12. If the bridge names them differently, only bandKey(),
// bandIntensity() and setSparkle() below need to change. Per-band mute
// and bypass ride the dedicated IrisAudio.setCrystalizerBandMute/Bypass
// setters; their reads fall back to band<N>.mute/.bypass params, then to
// a local mirror so each switch answers at once even before the engine
// echoes the state.
ColumnLayout {
    id: root

    property bool engineReady: false
    property bool expanded: false
    property bool showBands: false

    spacing: 0

    readonly property real d: IrisStyle.density
    readonly property string moduleId: "crystalizer"
    readonly property var meta: IrisEqSpec.moduleMeta(root.moduleId)
    readonly property var entry: (IrisAudio.modules ?? {})[root.moduleId] ?? {}
    readonly property bool active: Boolean(root.entry.active ?? false)
    readonly property var presets: IrisEqSpec.factoryPresets[root.moduleId] ?? []

    function bandKey(n: int): string {
        return "band%1.intensity".arg(n)
    }
    function bandIntensity(n: int): real {
        return Number(IrisEqSpec.paramOf(IrisAudio.modules, root.moduleId, root.bandKey(n), 0))
    }
    // The master's position is the mean of the 13 bands — moving one band
    // by hand moves the master a little, which is the honest thing.
    readonly property real sparkle: {
        let sum = 0
        for (let n = 0; n < 13; ++n) sum += root.bandIntensity(n)
        return sum / 13
    }
    function setSparkle(v: real): void {
        const next = Math.round(v * 10) / 10
        for (let n = 0; n < 13; ++n) IrisAudio.setParam(root.moduleId, root.bandKey(n), next)
    }
    property var muteLocal: ({})
    property var bypassLocal: ({})
    function bandFlag(n: int, leaf: string, local: var): bool {
        const key = String(n)
        if (local[key] !== undefined) return Boolean(local[key])
        return Boolean(IrisEqSpec.paramOf(IrisAudio.modules, root.moduleId, "band%1.%2".arg(n).arg(leaf), false))
    }
    function bandMuted(n: int): bool {
        return root.bandFlag(n, "mute", root.muteLocal)
    }
    function bandBypassed(n: int): bool {
        return root.bandFlag(n, "bypass", root.bypassLocal)
    }
    function commitBandFlag(n: int, leaf: string, value: bool): void {
        const key = String(n)
        if (leaf === "mute") {
            const next = Object.assign({}, root.muteLocal)
            next[key] = value
            root.muteLocal = next
            if (typeof IrisAudio.setCrystalizerBandMute === "function") IrisAudio.setCrystalizerBandMute(n, value)
        } else {
            const next = Object.assign({}, root.bypassLocal)
            next[key] = value
            root.bypassLocal = next
            if (typeof IrisAudio.setCrystalizerBandBypass === "function") IrisAudio.setCrystalizerBandBypass(n, value)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: headRow.implicitHeight + Math.round(16 * root.d)
        radius: IrisStyle.radiusCard
        color: root.active ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.readingCard
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }

        RowLayout {
            id: headRow
            anchors.fill: parent
            anchors.leftMargin: Math.round(12 * root.d)
            anchors.rightMargin: Math.round(12 * root.d)
            anchors.topMargin: Math.round(8 * root.d)
            anchors.bottomMargin: Math.round(8 * root.d)
            spacing: Math.round(10 * root.d)

            Rectangle {
                implicitWidth: Math.round(30 * root.d)
                implicitHeight: implicitWidth
                radius: height / 2
                color: root.active ? IrisStyle.accent : IrisStyle.fill
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.meta.glyph
                    fill: root.active ? 1 : 0
                    iconSize: Math.round(17 * root.d)
                    color: root.active ? IrisStyle.onTintFor(IrisStyle.accent) : IrisStyle.text
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    text: root.meta.label
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    text: !root.engineReady ? Translation.tr("Waiting for engine")
                        : root.active ? Translation.tr("Sparkle at %1").arg(IrisEqSpec.formatValue(Math.round(root.sparkle * 10) / 10, "")) : Translation.tr("Bypassed — tap to bring back")
                    color: root.active ? IrisStyle.textSecondary : IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                text: root.expanded ? "expand_less" : "expand_more"
                iconSize: Math.round(18 * root.d)
                color: IrisStyle.muted
            }

            IrisSwitch {
                on: root.active
                name: root.meta.label
                enabled: false
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: eventPoint => {
                if (!root.engineReady) return
                if (eventPoint.pressPosition.x < width - Math.round(64 * root.d)) root.expanded = !root.expanded
                else IrisAudio.toggleModule(root.moduleId)
            }
        }
        Accessible.role: Accessible.CheckBox
        Accessible.name: root.meta.label
        Accessible.checked: root.active
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.expanded
        spacing: Math.round(8 * root.d)

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(6 * root.d)
            Layout.rightMargin: Math.round(6 * root.d)
            Layout.topMargin: Math.round(8 * root.d)
            spacing: Math.round(6 * root.d)

            // The one gesture: more sparkle.
            IrisEqSliderRow {
                Layout.fillWidth: true
                label: Translation.tr("Sparkle — all 13 bands together")
                unit: ""
                minimum: -12
                maximum: 12
                value: root.sparkle
                enabled: root.engineReady && root.active
                onCommit: next => root.setSparkle(next)
            }

            Repeater {
                model: IrisEqSpec.crystalizerTop
                TopRow {
                    required property var modelData
                    Layout.fillWidth: true
                    spec: modelData
                }
            }

            IrisButton {
                Layout.alignment: Qt.AlignLeft
                quiet: true
                buttonRadius: height / 2
                text: root.showBands ? Translation.tr("Hide the 13 bands") : Translation.tr("Tune each band")
                onClicked: root.showBands = !root.showBands
            }

            // The 13-band strip, for the days one band misbehaves.
            Rectangle {
                Layout.fillWidth: true
                visible: root.showBands
                Layout.preferredHeight: Math.round(212 * root.d)
                radius: IrisStyle.radiusTile
                color: IrisStyle.fillQuiet
                clip: true
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(8 * root.d)
                    spacing: Math.round(4 * root.d)
                    Repeater {
                        model: 13
                        MiniBand {
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            band: index
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: root.presets.length > 0
                spacing: Math.round(6 * root.d)
                Repeater {
                    model: root.presets
                    IrisChip {
                        required property var modelData
                        label: modelData.name
                        glyph: "auto_fix_high"
                        enabled: root.engineReady && root.active
                        onClicked: root.setSparkle(Number(modelData.sparkle ?? 0))
                    }
                }
            }
        }
    }

    function topParam(key: string, fallback: var): var {
        return IrisEqSpec.paramOf(IrisAudio.modules, root.moduleId, key, fallback)
    }

    // -- top-level crystalizer rows ----------------------------------------
    component TopRow: ColumnLayout {
        id: row
        required property var spec
        Layout.fillWidth: true
        spacing: 0

        readonly property string key: String(row.spec.key ?? "")
        readonly property string kind: String(row.spec.kind ?? "slider")

        IrisEqSliderRow {
            Layout.fillWidth: true
            visible: row.kind === "slider" || row.kind === "int"
            label: String(row.spec.label ?? row.key)
            unit: String(row.spec.unit ?? "")
            minimum: Number(row.spec.min ?? 0)
            maximum: Number(row.spec.max ?? 1)
            integer: row.kind === "int"
            value: Number(root.topParam(row.key, row.spec.def ?? 0))
            enabled: root.engineReady && root.active
            onCommit: next => IrisAudio.setParam(root.moduleId, row.key, next)
        }
        RowLayout {
            Layout.fillWidth: true
            visible: row.kind === "bool"
            spacing: Math.round(10 * root.d)
            IrisText {
                Layout.fillWidth: true
                text: String(row.spec.label ?? row.key)
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
                elide: Text.ElideRight
            }
            IrisSwitch {
                on: Boolean(root.topParam(row.key, row.spec.def ?? false))
                name: String(row.spec.label ?? row.key)
                enabled: root.engineReady && root.active
                onToggled: IrisAudio.setParam(root.moduleId, row.key, !Boolean(root.topParam(row.key, row.spec.def ?? false)))
            }
        }
    }

    // -- one mini band fader ------------------------------------------------
    component MiniBand: Item {
        id: mini
        required property int band
        property bool held: false

        readonly property bool muted: root.bandMuted(mini.band)
        readonly property bool bypassed: root.bandBypassed(mini.band)

        readonly property real level: {
            const v = mini.held ? mini.dragValue : root.bandIntensity(mini.band)
            return Math.max(-12, Math.min(12, Number(v)))
        }
        property real dragValue: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: Math.round(2 * root.d)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                opacity: (mini.muted || mini.bypassed) ? 0.45 : 1
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.round(3 * root.d)
                    height: parent.height
                    radius: width / 2
                    color: IrisStyle.fill
                }
                Rectangle {
                    readonly property real t: (12 - mini.level) / 24
                    x: Math.round((parent.width - width) / 2)
                    y: Math.round(t * parent.height) - width / 2
                    width: Math.round(12 * root.d)
                    height: width
                    radius: width / 2
                    color: mini.held ? IrisStyle.accent : IrisStyle.surfaceHighestOpaque
                    border.width: 1
                    border.color: mini.held ? IrisStyle.accent : IrisStyle.borderStrong
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onPressed: mouse => {
                        mini.held = true
                        mini.dragValue = 12 - Math.max(0, Math.min(1, mouse.y / Math.max(1, height))) * 24
                        IrisAudio.setParam(root.moduleId, root.bandKey(mini.band), Math.round(mini.dragValue * 10) / 10)
                    }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        mini.dragValue = 12 - Math.max(0, Math.min(1, mouse.y / Math.max(1, height))) * 24
                        IrisAudio.setParam(root.moduleId, root.bandKey(mini.band), Math.round(mini.dragValue * 10) / 10)
                    }
                    onReleased: mini.held = false
                    onCanceled: mini.held = false
                }
            }
            IrisText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "%1".arg(mini.band)
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeCaption
            }
            IrisText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Mute")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeCaption
            }
            IrisSwitch {
                Layout.alignment: Qt.AlignHCenter
                on: mini.muted
                name: Translation.tr("Crystalizer band %1 mute").arg(mini.band)
                enabled: root.engineReady && root.active
                onToggled: root.commitBandFlag(mini.band, "mute", !mini.muted)
            }
            IrisText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Bypass")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeCaption
            }
            IrisSwitch {
                Layout.alignment: Qt.AlignHCenter
                on: mini.bypassed
                name: Translation.tr("Crystalizer band %1 bypass").arg(mini.band)
                enabled: root.engineReady && root.active
                onToggled: root.commitBandFlag(mini.band, "bypass", !mini.bypassed)
            }
        }
    }
}
