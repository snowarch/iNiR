import QtQuick
import QtQuick.Effects

// Where a scrolled list meets what floats over it, its rows soften into a blur and fade into the air instead of
// ending on a cut (the scroll edge of Apple's Liquid Glass). Laid over the Flickable (anchors.fill: flick); the flick
// takes `mask` as its layer mask while `active`. The edge that has more rows past it fades over `reach`; at the head
// (`blurs`) a band shows the rows just under it blurred, sharp below and gone at the top.
Item {
    id: root

    required property Flickable flick
    property real reach: 28
    property bool blurs: true
    property real blurMax: 24
    readonly property bool atTop: root.flick.contentY > 1
    readonly property bool atBottom: root.flick.contentY + root.flick.height < root.flick.contentHeight - 1
    readonly property bool active: root.atTop || root.atBottom
    readonly property Item mask: fade
    readonly property real share: Math.min(0.5, root.reach / Math.max(1, root.height))

    // An eased ramp (0, a quarter, a half, all) so the fade has no visible start like a linear one.
    Item {
        id: fade
        anchors.fill: parent
        visible: false
        layer.enabled: root.active
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: root.atTop ? "transparent" : "white" }
                GradientStop { position: root.share * 0.35; color: root.atTop ? Qt.rgba(1, 1, 1, 0.2) : "white" } // iris-literal: mask alpha, not a colour
                GradientStop { position: root.share * 0.7; color: root.atTop ? Qt.rgba(1, 1, 1, 0.65) : "white" } // iris-literal: mask alpha, not a colour
                GradientStop { position: root.share; color: "white" }
                GradientStop { position: 1 - root.share; color: "white" }
                GradientStop { position: 1 - root.share * 0.7; color: root.atBottom ? Qt.rgba(1, 1, 1, 0.65) : "white" } // iris-literal: mask alpha, not a colour
                GradientStop { position: 1 - root.share * 0.35; color: root.atBottom ? Qt.rgba(1, 1, 1, 0.2) : "white" } // iris-literal: mask alpha, not a colour
                GradientStop { position: 1; color: root.atBottom ? "transparent" : "white" }
            }
        }
    }

    ShaderEffectSource {
        id: band
        visible: root.blurs && root.atTop
        width: root.width
        height: Math.min(root.height, Math.round(root.reach * 1.4))
        sourceItem: root.flick.contentItem
        sourceRect: Qt.rect(root.flick.contentX, root.flick.contentY, band.width, band.height)
        live: band.visible
        // Blurred at half size, as the field's glass is: the band is a soft shape, not text to read.
        textureSize: Qt.size(Math.max(1, Math.ceil(band.width / 2)), Math.max(1, Math.ceil(band.height / 2)))
        layer.enabled: band.visible
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: root.blurMax
            maskEnabled: true
            maskSource: bandMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
    // Gone at the very top (the rows have faded there too), fullest a third down, back to the sharp rows below.
    Item {
        id: bandMask
        width: band.width
        height: band.height
        visible: false
        layer.enabled: band.visible
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.85) } // iris-literal: mask alpha, not a colour
                GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.6) } // iris-literal: mask alpha, not a colour
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
}
