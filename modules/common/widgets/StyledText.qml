import qs.modules.common
import QtQuick

Text {
    id: root
    property bool animateChange: false
    property real animationDistanceX: 0
    property real animationDistanceY: 6

    property real _slideX: 0
    property real _slideY: 0
    // The slide and its animation are built for the texts that animate a change, on the first one that asks.
    property SequentialAnimation _textChange: null
    // A binding, not the property itself: its first evaluation signals, so a text built animating builds its change too.
    readonly property bool _changeAnimated: root.animateChange
    on_ChangeAnimatedChanged: if (root._changeAnimated) root._buildTextChange()
    transform: root._changeAnimated && root._textChange ? [root._textChange.slide] : []
    function _buildTextChange(): void {
        if (!root._textChange) {
            root._textChange = Qt.createComponent("StyledTextChange.qml").createObject(root, { text: root })
            // A Behavior takes its animation once: from then on it runs whenever it is enabled.
            textBehavior.animation = root._textChange
        }
    }

    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    property bool shouldUseNumberFont: /^\d+$/.test(root.text)
    property var defaultFont: shouldUseNumberFont ? Appearance.font.family.numbers : Appearance.font.family.main
    
    font {
        hintingPreference: Font.PreferDefaultHinting
        family: defaultFont
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        variableAxes: shouldUseNumberFont ? root._numberAxes : Appearance.font.variableAxes.main
        features: shouldUseNumberFont ? ({ "tnum": 1 }) : ({})
        // ZZZ poster crispness: a small global letter-spacing under the zzz style
        // (token-driven, absolute px). Numbers stay untracked so digit columns
        // don't drift. Other styles unaffected (0).
        letterSpacing: (Appearance?.zzzEverywhere && !root.shouldUseNumberFont)
            ? (Appearance?.zzz.tracking ?? 0)
            : (Appearance?.regaliaEverywhere && !root.shouldUseNumberFont) ? 0.12 : 0
    }
    // Figures round out by size; set from a handler, since a binding on the font's own size loops through the font.
    property var _numberAxes: ({})
    property string _numberStep: ""
    function _syncNumberAxes(): void {
        if (!root.shouldUseNumberFont) return
        const axes = Appearance.font.variableAxes.numbersAt(root.font.pixelSize)
        const step = axes.ROND + ":" + axes.opsz
        if (step === root._numberStep) return
        root._numberStep = step
        root._numberAxes = axes
    }
    onFontChanged: root._syncNumberAxes()
    onShouldUseNumberFontChanged: root._syncNumberAxes()
    Component.onCompleted: root._syncNumberAxes()
    color: Appearance?.colors.colOnLayer0 ?? "black"
    linkColor: Appearance?.colors.colPrimary

    Behavior on text {
        id: textBehavior
        enabled: root._changeAnimated && root._textChange !== null && Appearance.animationsEnabled
    }
}
