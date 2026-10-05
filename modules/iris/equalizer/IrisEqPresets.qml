pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.equalizer

// Whole-chain presets: the engine's own preset list. Applying one reloads
// the full chain (like the band-count switch, this is a "heavy" action and
// reads as one); saving captures everything above into a name.
ColumnLayout {
    id: root

    property bool engineReady: false

    spacing: Math.round(8 * IrisStyle.density)

    readonly property real d: IrisStyle.density
    readonly property var names: IrisAudio.presets ?? []
    readonly property string current: String(IrisAudio.presetName ?? "")
    property bool saving: false
    property string saveError: ""

    // The engine's list arrives through list_presets (plain strings, e.g.
    // "iNiR Equalizer" — never {name} objects). Ask whenever the engine
    // becomes ready and after every change below so the row never goes stale.
    onEngineReadyChanged: {
        if (root.engineReady) IrisAudio.listPresets()
    }
    function nameOf(entry: var): string {
        if (entry === null || entry === undefined) return ""
        if (typeof entry === "string") return entry
        return String(entry.name ?? entry.label ?? "")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(8 * root.d)
        IrisText {
            text: Translation.tr("Chain presets")
            role: IrisText.Eyebrow
        }
        Item { Layout.fillWidth: true }
        IrisButton {
            quiet: true
            buttonRadius: height / 2
            text: root.saving ? Translation.tr("Cancel") : Translation.tr("Save current")
            enabled: root.engineReady
            onClicked: {
                root.saveError = ""
                root.saving = !root.saving
                if (root.saving) saveField.forceActiveFocus()
            }
        }
    }

    // Save row.
    RowLayout {
        Layout.fillWidth: true
        visible: root.saving
        spacing: Math.round(8 * root.d)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.round(34 * root.d)
            radius: height / 2
            color: IrisStyle.fillQuiet
            TextInput {
                id: saveField
                anchors.fill: parent
                anchors.leftMargin: Math.round(14 * root.d)
                anchors.rightMargin: Math.round(14 * root.d)
                verticalAlignment: TextInput.AlignVCenter
                color: IrisStyle.text
                font.family: IrisStyle.fontMain
                font.pixelSize: IrisStyle.typeLabel
                maximumLength: 64
                onAccepted: root.commitSave()
                IrisText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: saveField.text.length === 0
                    text: Translation.tr("Name this sound…")
                    color: IrisStyle.muted
                    font.pixelSize: saveField.font.pixelSize
                }
            }
        }
        IrisButton {
            text: Translation.tr("Save")
            emphasized: true
            buttonRadius: height / 2
            enabled: saveField.text.trim().length > 0
            onClicked: root.commitSave()
        }
    }

    IrisText {
        Layout.fillWidth: true
        visible: root.saveError.length > 0
        text: root.saveError
        color: IrisStyle.danger
        font.pixelSize: IrisStyle.typeFootnote
    }

    Flow {
        Layout.fillWidth: true
        spacing: Math.round(6 * root.d)

        Repeater {
            model: root.names
            PresetChip {
                required property var modelData
                visible: presetName.length > 0
                presetName: root.nameOf(modelData)
            }
        }

        IrisText {
            visible: root.engineReady && root.names.length === 0
            text: Translation.tr("No saved chains yet — shape the sound above, then save it.")
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeFootnote
        }
        IrisText {
            visible: !root.engineReady
            text: Translation.tr("Presets arrive with the engine.")
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeFootnote
        }
    }

    // Factory chains: the historical 8, voiced for 10 bands and interpolated
    // onto whatever the engine runs. Instant — they retune the band gains in
    // one batched write and never reload the preset, unlike saved chains.
    IrisText {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(4 * root.d)
        text: Translation.tr("Factory chains")
        role: IrisText.Eyebrow
    }
    Flow {
        Layout.fillWidth: true
        spacing: Math.round(6 * root.d)
        Repeater {
            model: IrisEqSpec.factoryChain
            IrisChip {
                required property var modelData
                label: String(modelData.name ?? "")
                glyph: "equalizer"
                selected: root.detectedChain === String(modelData.name ?? "")
                enabled: root.engineReady && (IrisAudio.bands ?? []).length > 0
                onClicked: root.applyFactoryChain(modelData)
            }
        }
    }
    IrisText {
        Layout.fillWidth: true
        text: Translation.tr("Factory chains retune the bands and leave the modules alone. Saved chains reload everything.")
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeFootnote
        wrapMode: Text.WordWrap
    }

    function applyFactoryChain(entry: var): void {
        const gains = entry?.gains ?? []
        const bands = IrisAudio.bands ?? []
        if (gains.length < 10 || bands.length === 0) return
        for (let i = 0; i < bands.length; ++i) {
            IrisAudio.setBandGain(i, IrisEqSpec.chainGainAt(Number(bands[i]?.frequency ?? 0), gains))
        }
    }

    // Which factory chain the live curve matches, if any — the legacy
    // panel's ±0.15 dB detection, generalized to any band count by comparing
    // each live band against the interpolated curve instead of a fixed 10.
    readonly property string detectedChain: {
        const bands = IrisAudio.bands ?? []
        if (!root.engineReady || bands.length === 0) return ""
        for (const entry of IrisEqSpec.factoryChain) {
            const gains = entry?.gains ?? []
            if (gains.length < 10) continue
            let match = true
            for (let i = 0; i < bands.length; ++i) {
                const want = IrisEqSpec.chainGainAt(Number(bands[i]?.frequency ?? 0), gains)
                if (Math.abs(Number(bands[i]?.gain ?? 0) - want) > 0.15) { match = false; break }
            }
            if (match) return String(entry.name ?? "")
        }
        return ""
    }

    function commitSave(): void {
        const name = saveField.text.trim()
        if (name.length === 0) {
            root.saveError = Translation.tr("Give the preset a name first.")
            return
        }
        IrisAudio.savePreset(name)
        IrisAudio.listPresets()
        saveField.text = ""
        root.saving = false
    }

    // -- one preset: tap applies (chain reload), × deletes ------------------
    component PresetChip: Item {
        id: chip
        property string presetName: ""
        readonly property bool isCurrent: chip.presetName === root.current && chip.presetName.length > 0
        implicitWidth: chipRow.implicitWidth + Math.round(10 * root.d)
        implicitHeight: Math.round(30 * root.d)
        width: implicitWidth
        height: implicitHeight

        RowLayout {
            id: chipRow
            anchors.fill: parent
            spacing: 0
            IrisChip {
                label: chip.presetName
                selected: chip.isCurrent
                enabled: root.engineReady
                onClicked: {
                    IrisAudio.applyPreset(chip.presetName)
                    IrisAudio.listPresets()
                }
            }
            // Delete sits on the chip's shoulder, always available on a saved
            // chain; the confirm bar below is what gates the act.
            Rectangle {
                visible: root.engineReady
                Layout.alignment: Qt.AlignTop
                implicitWidth: Math.round(18 * root.d)
                implicitHeight: implicitWidth
                radius: width / 2
                color: delHover.hovered ? IrisStyle.danger : "transparent"
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: Math.round(11 * root.d)
                    color: delHover.hovered ? IrisStyle.onTint : IrisStyle.muted
                }
                HoverHandler { id: delHover }
                TapHandler { onTapped: confirmBar.open() }
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Delete %1").arg(chip.presetName)
            }
        }

        // Inline confirm: deleting a chain is the one destructive act here.
        Rectangle {
            id: confirmBar
            function open(): void { confirmBar.visible = true }
            visible: false
            anchors.fill: parent
            radius: height / 2
            color: IrisStyle.surfaceHighestOpaque
            border.width: 1
            border.color: IrisStyle.danger
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(10 * root.d)
                anchors.rightMargin: Math.round(4 * root.d)
                spacing: Math.round(4 * root.d)
                IrisText {
                    Layout.fillWidth: true
                    text: Translation.tr("Delete?")
                    color: IrisStyle.danger
                    font.pixelSize: IrisStyle.typeFootnote
                    elide: Text.ElideRight
                }
                IrisButton {
                    quiet: true
                    buttonRadius: height / 2
                    implicitHeight: Math.round(24 * root.d)
                    text: Translation.tr("Keep")
                    onClicked: confirmBar.visible = false
                }
                IrisButton {
                    danger: true
                    emphasized: true
                    buttonRadius: height / 2
                    implicitHeight: Math.round(24 * root.d)
                    text: Translation.tr("Delete")
                    onClicked: {
                        confirmBar.visible = false
                        IrisAudio.deletePreset(chip.presetName)
                        IrisAudio.listPresets()
                    }
                }
            }
        }
    }
}
