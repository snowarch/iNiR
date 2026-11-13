import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.overlay

// The crosshair on a pad while the bench is open, its code beneath; pinned, only the crosshair stays, at the middle
// of the screen and at its own opacity.
StyledOverlayWidget {
    id: root
    showCenterButton: true
    showClickabilityButton: false
    hudPlate: false
    hudFades: false
    resizable: false

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: Math.round(220 * root.d)
        implicitHeight: Math.round(180 * root.d)

        // The pad stands in for the game: dark under a light crosshair, light under a dark one, in either mode.
        Rectangle {
            id: pad
            // The recessed fill is a faint tint, so the plate's light is read from its text: dark text, light plate.
            readonly property bool plateLight: OverlayLook.colOnLayer1.hslLightness < 0.5
            readonly property bool flipped: pad.plateLight === mark.crosshairColor.hslLightness > 0.5
            readonly property color ink: pad.flipped === pad.plateLight ? FamilyStyle.inkOnDark : FamilyStyle.inkOnLight
            anchors.fill: parent
            radius: root.contentRadius
            color: pad.flipped ? ColorUtils.mix(OverlayLook.colOnLayer1, OverlayLook.colRecessed, 0.82) : OverlayLook.colRecessed
            opacity: root.chrome
            visible: opacity > 0.01

            Rectangle {
                id: field
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Math.round(8 * root.d)
                height: Math.round(30 * root.d)
                radius: OverlayLook.roundingSmall
                color: ColorUtils.applyAlpha(pad.ink, codeInput.activeFocus ? 0.16 : 0.09)
                border.width: codeInput.activeFocus ? 1 : 0
                border.color: OverlayLook.colPrimary

                StyledTextInput {
                    id: codeInput
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(10 * root.d)
                    anchors.rightMargin: Math.round(10 * root.d)
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: pad.ink
                    selectionColor: OverlayLook.colToggle
                    selectedTextColor: OverlayLook.colOnToggle
                    font.family: OverlayLook.fontNumbers
                    font.pixelSize: OverlayLook.typeMeta
                    selectByMouse: true
                    Binding on text {
                        when: !codeInput.activeFocus
                        value: Config.options?.crosshair?.code ?? ""
                    }
                    onEditingFinished: {
                        const code = codeInput.text.trim()
                        if (code !== (Config.options?.crosshair?.code ?? ""))
                            Config.setNestedValue("crosshair.code", code)
                        codeInput.focus = false
                    }
                    Keys.onEscapePressed: event => {
                        codeInput.focus = false
                        event.accepted = true
                    }
                }
                StyledText {
                    anchors.fill: codeInput
                    verticalAlignment: Text.AlignVCenter
                    visible: codeInput.text.length === 0
                    text: Translation.tr("Crosshair code")
                    color: ColorUtils.applyAlpha(pad.ink, 0.5)
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeMeta
                }
            }
        }

        CrosshairContent {
            id: mark
            anchors.centerIn: parent
        }
    }
}
