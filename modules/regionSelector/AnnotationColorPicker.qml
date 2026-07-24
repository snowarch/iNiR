pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Custom-color swatch + in-window HSV picker popup with a saved-colors
// collection. Shared by the ii (Material) and waffle (Fluent) toolbars —
// all state/behavior comes from the injected `editor` (the ScreenshotEditor).
Rectangle {
    id: customSwatch
    required property var editor

    implicitWidth: 26
    implicitHeight: 26
    radius: Appearance.rounding.full
    border.width: editor.strokeColorIsCustom ? 3 : 1
    border.color: editor.strokeColorIsCustom
        ? Appearance.colors.colOnLayer1
        : Appearance.colors.colOutlineVariant
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type }
    }
    // Shows the last custom color once you've picked one; rainbow until then.
    color: editor.lastCustomColor !== "" ? editor.lastCustomColor : "transparent"
    gradient: editor.lastCustomColor === "" ? rainbowGradient : null
    Gradient {
        id: rainbowGradient
        GradientStop { position: 0.0; color: "#ff5252" }
        GradientStop { position: 0.33; color: "#4caf50" }
        GradientStop { position: 0.66; color: "#2196f3" }
        GradientStop { position: 1.0; color: "#e040fb" }
    }
    MaterialSymbol {
        anchors.centerIn: parent
        visible: customSwatch.editor.lastCustomColor === ""
        text: "colorize"
        iconSize: 14
        color: "#ffffff"
    }

    property real pickHue: 0
    property real pickSat: 0
    property real pickValue: 1
    property string hexText: "#000000"
    function syncFromStrokeColor() {
        pickHue = Math.max(0, editor.strokeColor.hsvHue);
        pickSat = editor.strokeColor.hsvSaturation;
        pickValue = editor.strokeColor.hsvValue;
        hexText = editor.strokeColor.toString();
    }
    function applyHsv() {
        editor.setStrokeColor(Qt.hsva(pickHue, pickSat, pickValue, 1));
        hexText = editor.strokeColor.toString();
        editor.setLastCustomColor(hexText);
    }

    property bool hovered: swatchMouseArea.containsMouse
    MouseArea {
        id: swatchMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { customSwatch.syncFromStrokeColor(); colorPickerPopup.open(); }
    }
    StyledToolTip { text: Translation.tr("Custom color") }

    Popup {
        id: colorPickerPopup
        y: -height - 10
        x: (customSwatch.width - width) / 2
        width: 232
        padding: 14
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: customSwatch.editor.suppressGlobalKeys = true
        onClosed: {
            customSwatch.editor.suppressGlobalKeys = false
            customSwatch.editor.focusKeySink()
        }

        background: GlassBackground {
            fallbackColor: Appearance.m3colors.m3surfaceContainer
            inirColor: Appearance.inir.colLayer2
            auroraTransparency: Appearance.aurora.overlayTransparentize
            screenWidth: customSwatch.editor.width
            screenHeight: customSwatch.editor.height
            radius: Appearance.rounding.normal
            border.width: (Appearance.angelEverywhere || Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0
            border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorder
                : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : "transparent"
        }

        contentItem: ColumnLayout {
            spacing: 12

            Item {
                id: svSquare
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                function updateFromPos(px, py) {
                    const cx = Math.max(0, Math.min(width, px));
                    const cy = Math.max(0, Math.min(height, py));
                    customSwatch.pickSat = cx / width;
                    customSwatch.pickValue = 1 - cy / height;
                    customSwatch.applyHsv();
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#ffffff" }
                        GradientStop { position: 1.0; color: Qt.hsva(customSwatch.pickHue, 1, 1, 1) }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 1.0; color: "#ff000000" }
                    }
                }
                Rectangle {
                    x: customSwatch.pickSat * svSquare.width - width / 2
                    y: (1 - customSwatch.pickValue) * svSquare.height - height / 2
                    width: 14
                    height: 14
                    radius: 7
                    color: "transparent"
                    border.width: 2
                    border.color: "#ffffff"
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: (m) => svSquare.updateFromPos(m.x, m.y)
                    onPositionChanged: (m) => { if (pressed) svSquare.updateFromPos(m.x, m.y) }
                }
            }

            Item {
                id: hueTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 18

                function updateFromPos(px) {
                    customSwatch.pickHue = Math.max(0, Math.min(1, px / width));
                    customSwatch.applyHsv();
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#ff0000" }
                        GradientStop { position: 0.166; color: "#ffff00" }
                        GradientStop { position: 0.333; color: "#00ff00" }
                        GradientStop { position: 0.5; color: "#00ffff" }
                        GradientStop { position: 0.666; color: "#0000ff" }
                        GradientStop { position: 0.833; color: "#ff00ff" }
                        GradientStop { position: 1.0; color: "#ff0000" }
                    }
                }
                Rectangle {
                    x: customSwatch.pickHue * (hueTrack.width - width)
                    y: -2
                    width: 6
                    height: hueTrack.height + 4
                    radius: 3
                    color: "#ffffff"
                    border.width: 1
                    border.color: "#55000000"
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: (m) => hueTrack.updateFromPos(m.x)
                    onPositionChanged: (m) => { if (pressed) hueTrack.updateFromPos(m.x) }
                }
            }

            ToolbarTextField {
                Layout.fillWidth: true
                implicitHeight: 44
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                font.family: Appearance.font.family.monospace
                horizontalAlignment: Text.AlignHCenter
                text: customSwatch.hexText
                onEditingFinished: {
                    customSwatch.editor.setStrokeColor(text);
                    customSwatch.syncFromStrokeColor();
                    customSwatch.editor.setLastCustomColor(customSwatch.hexText);
                }
            }

            StyledText {
                text: Translation.tr("My Collection")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: customSwatch.editor.palette
                    delegate: Rectangle {
                        id: baseSwatch
                        required property var modelData
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: Appearance.rounding.full
                        color: baseSwatch.modelData
                        border.width: customSwatch.editor.strokeColor == baseSwatch.modelData ? 3 : 1
                        border.color: customSwatch.editor.strokeColor == baseSwatch.modelData
                            ? Appearance.colors.colOnLayer1
                            : Appearance.colors.colOutlineVariant
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: customSwatch.editor.setStrokeColor(baseSwatch.modelData)
                        }
                    }
                }

                Repeater {
                    model: customSwatch.editor.savedCustomColors
                    delegate: Rectangle {
                        id: savedSwatch
                        required property var modelData
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: Appearance.rounding.full
                        color: savedSwatch.modelData
                        border.width: customSwatch.editor.strokeColor == savedSwatch.modelData ? 3 : 1
                        border.color: customSwatch.editor.strokeColor == savedSwatch.modelData
                            ? Appearance.colors.colOnLayer1
                            : Appearance.colors.colOutlineVariant
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                customSwatch.editor.setStrokeColor(savedSwatch.modelData);
                                customSwatch.syncFromStrokeColor();
                                customSwatch.editor.setLastCustomColor(savedSwatch.modelData);
                            }
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: Appearance.rounding.full
                    color: "transparent"
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "add"
                        iconSize: 14
                        color: Appearance.colors.colSubtext
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: customSwatch.editor.saveCustomColor(customSwatch.hexText)
                    }
                }
            }
        }
    }
}
