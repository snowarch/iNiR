import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.equalizer

// Profiles: a loudness target, a curve and a set of module states applied
// together. This is not a curve preset — a curve preset moves one thing, and
// a profile is meant to leave the chain coherent, so "Night" carries the
// limiter with it because a lower target on its own only lowers the average
// and leaves the peaks exactly where they were.
//
// Nothing here analyses the audio. These are presets, and the panel must not
// imply otherwise: the live engine state only decides WHICH profile is
// highlighted, never what a profile should be.
ColumnLayout {
    id: root
    spacing: Math.round(8 * root.d)

    readonly property real d: IrisStyle.density

    property bool engineReady: true

    // What the last bundle could not do. A profile naming a module that is
    // not installed gets that module SKIPPED, not installed — the rest still
    // applies, so without surfacing this a profile can look fully applied
    // while part of it did nothing.
    readonly property var skipped: IrisAudio.lastBundleSkipped ?? []

    // Which profile the ENGINE currently matches, derived from live values
    // rather than from IrisAudio.activeProfile: that name can survive a
    // mid-flight socket drop, and a highlight that outlives the engine is a
    // lie. Reading the live state also means it clears itself for free.
    readonly property string activeId: {
        if (!IrisAudio.available || !IrisAudio.ready) return ""
        const list = IrisEqSpec.profiles ?? []
        for (let i = 0; i < list.length; ++i) {
            if (root.matches(list[i])) return String(list[i].id)
        }
        return ""
    }

    readonly property var activeProfile: IrisEqSpec.profileById(root.activeId)

    function matches(profile): bool {
        if (!profile) return false
        const legacy = IrisEqSpec.profileLegacyGains(profile)
        if (!legacy) return false
        const bands = IrisAudio.bands ?? []
        if (bands.length === 0) return false

        const target = Number(IrisEqSpec.paramOf(IrisAudio.modules, "autogain", "target", NaN))
        if (!Number.isFinite(target) || Math.abs(target - Number(profile.target)) > 0.2) return false

        for (let i = 0; i < bands.length; ++i) {
            const want = IrisEqSpec.chainGainAt(Number(bands[i].frequency), legacy)
            if (Math.abs(Number(bands[i].gain) - want) > 0.25) return false
        }

        const wanted = profile.modules ?? {}
        for (const id in wanted) {
            // moduleActive, not entry.active: the bridge never sends `active`,
            // it sends `bypass`, so comparing against a field that does not
            // exist makes this false for every profile.
            if (IrisEqSpec.moduleActive(IrisAudio.modules, String(id)) !== (wanted[id] === true))
                return false
        }
        return true
    }

    // One bundle: the target, the profile's curve voiced at whatever band
    // count is live, and its module states. The bridge writes all of it in a
    // single flush, so the chain never passes through a state with the new
    // curve at the old loudness.
    function apply(profile): void {
        if (!root.engineReady || IrisAudio.rebuilding) return
        if (!profile) return
        const legacy = IrisEqSpec.profileLegacyGains(profile)
        const bands = IrisAudio.bands ?? []
        if (!legacy || bands.length === 0) return

        const gains = []
        for (let i = 0; i < bands.length; ++i)
            gains.push(IrisEqSpec.chainGainAt(Number(bands[i].frequency), legacy))

        const wanted = profile.modules ?? {}
        const modules = []
        for (const id in wanted)
            // A [id, active] PAIR, not an object: the bridge unpacks each entry
            // by position, so an object arrives with pair[0] undefined and the
            // reply reports a module named "undefined" as not installed.
            // Arrays are the contract; do not "improve" them.
            modules.push([String(id), wanted[id] === true])

        IrisAudio.applyBundle({
            target: Number(profile.target),
            bands: gains,
            modules: modules
        }, String(profile.label))
    }

    // Honest per reason: "isn't installed" and "didn't take" are different
    // failures and collapsing them into one sentence would hide which.
    function skippedText(): string {
        const missing = []
        const failed = []
        for (let i = 0; i < root.skipped.length; ++i) {
            const entry = root.skipped[i] ?? {}
            const id = String(entry.module ?? "")
            if (id.length === 0) continue
            const meta = IrisEqSpec.moduleMeta(id)
            const label = String(meta?.label ?? id)
            const reason = String(entry.reason ?? "")
            if (reason === "not_in_chain" || reason === "unknown_module") missing.push(label)
            else failed.push(label)
        }
        const parts = []
        if (missing.length > 0)
            parts.push(Translation.tr("%1 %2 not installed").arg(missing.join(" and ")).arg(missing.length === 1 ? Translation.tr("is") : Translation.tr("are")))
        if (failed.length > 0)
            parts.push(Translation.tr("%1 did not take").arg(failed.join(" and ")))
        if (parts.length === 0) return ""
        return parts.join("; ") + Translation.tr(". The rest of the profile applied.")
    }

    // Bypass the whole chain. EasyEffects' own global bypass: no parameter
    // writes and no preset reload, so every setting a profile applied is still
    // there when it is switched back on.
    readonly property bool globalBypassed: IrisAudio.globalBypass === "1"
    readonly property bool bypassUnknown: IrisAudio.globalBypass === ""

    function bypassLabel(): string {
        // Exactly two states, and that is all the engine can really be in for
        // this control: EasyEffects' IPC write path accepts "0" and "1" and
        // cannot produce anything else, so a value outside that pair is
        // presented as running instead of as a third state nobody can act on.
        return root.globalBypassed ? Translation.tr("CHAIN BYPASSED") : Translation.tr("CHAIN ON")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Item { Layout.fillWidth: true }
        IrisText {
            text: Translation.tr("PROFILE")
            role: IrisText.Eyebrow
        }
        RowLayout {
            spacing: Math.round(8 * root.d)
            IrisText {
                text: root.bypassLabel()
                role: IrisText.Eyebrow
                color: root.globalBypassed || !root.bypassUnknown
                    ? IrisStyle.textTertiary : IrisStyle.subtext
            }
            IrisSwitch {
                on: !root.globalBypassed
                enabled: root.engineReady && !root.bypassUnknown
                Accessible.name: Translation.tr("Bypass the whole chain")
                onToggled: IrisAudio.setGlobalBypass(!root.globalBypassed)
            }
        }
        Item { Layout.fillWidth: true }
    }

    Flow {
        Layout.fillWidth: true
        spacing: Math.round(6 * root.d)
        Repeater {
            model: IrisEqSpec.profiles
            IrisChip {
                required property var modelData
                // The LUFS number rides in the label: without it "Night" and
                // "Music" are indistinguishable until you hear them, and
                // hearing them is the thing the profile was meant to save.
                label: Translation.tr("%1 %2").arg(String(modelData.label)).arg(Number(modelData.target))
                selected: root.activeId === String(modelData.id)
                enabled: root.engineReady && !IrisAudio.rebuilding
                Accessible.name: Translation.tr("%1, %2 LUFS. %3").arg(String(modelData.label))
                    .arg(Number(modelData.target)).arg(String(modelData.detail))
                onClicked: root.apply(modelData)
            }
        }
    }

    IrisText {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(2 * root.d)
        visible: root.engineReady && !root.activeProfile
        text: Translation.tr("No profile — the chain is hand-tuned.")
        color: IrisStyle.textTertiary
        font.pixelSize: IrisStyle.typeFootnote
        wrapMode: Text.WordWrap
    }

    IrisText {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(2 * root.d)
        visible: root.engineReady && root.activeProfile && root.skipped.length === 0
        text: String(root.activeProfile?.detail ?? "")
        color: IrisStyle.subtext
        font.pixelSize: IrisStyle.typeFootnote
        wrapMode: Text.WordWrap
    }

    IrisText {
        Layout.fillWidth: true
        Layout.topMargin: Math.round(2 * root.d)
        visible: root.skipped.length > 0
        text: root.skippedText()
        color: IrisStyle.danger
        font.pixelSize: IrisStyle.typeFootnote
        wrapMode: Text.WordWrap
    }
}