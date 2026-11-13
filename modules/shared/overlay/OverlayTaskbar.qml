pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// The bench's strip: the time, every tool in its group (open ones tinted, pinned ones marked), the two captures with
// a live recording, and Arrange.
Item {
    id: root

    readonly property real d: OverlayLook.d
    readonly property real pad: Math.round(6 * root.d)
    readonly property real buttonSize: Math.round(36 * root.d)
    readonly property bool recording: RecorderStatus.isRecording

    implicitWidth: row.implicitWidth + root.pad * 2
    implicitHeight: root.buttonSize + root.pad * 2
    width: implicitWidth
    height: implicitHeight

    OverlayPlate {
        anchors.fill: parent
        radius: Math.min(height / 2, OverlayLook.plateRadius + 6)
        fillOpacity: Math.max(0.92, Config.options?.overlay?.backgroundOpacity ?? 0.9)
        screenX: root.x
        screenY: root.y
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(4 * root.d)

        // Time and battery
        Row {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: Math.round(10 * root.d)
            Layout.rightMargin: Math.round(6 * root.d)
            spacing: Math.round(10 * root.d)

            FamilyPart {
                id: familyClock
                anchors.verticalCenter: parent.verticalCenter
                visible: familyClock.url.length > 0
                part: "clock"
                props: ({ pixelSize: 18 * FamilyStyle.typeScale })
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: familyClock.url.length === 0
                text: DateTime.time
                color: OverlayLook.colOnLayer1
                font.family: OverlayLook.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: Math.round(18 * FamilyStyle.typeScale)
                font.weight: Font.DemiBold
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: Battery.available
                spacing: Math.round(2 * root.d)
                readonly property color ink: Battery.isLowAndNotCharging ? OverlayLook.colError : OverlayLook.colSubtext
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    fill: 1
                    text: Battery.isCharging ? "bolt" : "battery_android_full"
                    color: parent.ink
                    iconSize: Math.round(16 * root.d)
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Battery.percentage * 100) + "%"
                    color: parent.ink
                    font.family: OverlayLook.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: OverlayLook.typeMeta
                    font.weight: Font.DemiBold
                }
            }
        }

        Divider {}

        // Tools, a hairline between groups
        Repeater {
            model: OverlayContext.availableWidgets
            delegate: Row {
                id: toolCell
                required property var modelData
                required property int index
                readonly property string identifier: toolCell.modelData.identifier
                readonly property bool open: OverlayContext.openIds.includes(toolCell.identifier)
                readonly property bool pinned: toolCell.open && (Persistent.states.overlay[toolCell.identifier]?.pinned ?? false)
                readonly property bool live: toolCell.identifier === "recorder" && root.recording
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(4 * root.d)

                Divider {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: toolCell.index > 0 && OverlayContext.availableWidgets[toolCell.index - 1].group !== toolCell.modelData.group
                }
                OverlayButton {
                    id: toolButton
                    size: root.buttonSize
                    glyphSize: Math.round(20 * root.d)
                    glyph: toolCell.live ? "radio_button_checked" : toolCell.modelData.materialSymbol
                    tint: toolCell.live ? OverlayLook.colError : OverlayLook.colPrimary
                    toggled: toolCell.open
                    filledGlyph: toolCell.open || toolCell.live
                    tip: Translation.tr(toolCell.modelData.title)
                    onClicked: OverlayContext.toggle(toolCell.identifier)

                    // Pinned: a dot under the glyph, it stays after the bench closes.
                    Rectangle {
                        visible: toolCell.pinned
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Math.round(3 * root.d)
                        width: Math.round(4 * root.d)
                        height: width
                        radius: width / 2
                        color: OverlayLook.colOnToggle
                    }
                }
            }
        }

        Divider {}

        // Captures
        OverlayButton {
            Layout.alignment: Qt.AlignVCenter
            size: root.buttonSize
            glyphSize: Math.round(20 * root.d)
            glyph: "screenshot_region"
            tip: Translation.tr("Screenshot")
            onClicked: OverlayContext.screenshotRegion()
        }
        OverlayButton {
            Layout.alignment: Qt.AlignVCenter
            size: root.buttonSize
            glyphSize: Math.round(18 * root.d)
            strong: true
            tint: OverlayLook.colError
            glyph: root.recording ? "stop" : "radio_button_checked"
            label: root.recording ? OverlayContext.elapsed(RecorderStatus.elapsedSeconds) : Translation.tr("Record")
            tip: root.recording ? Translation.tr("Stop recording") : Translation.tr("Record a region")
            onClicked: root.recording ? OverlayContext.stopRecording() : OverlayContext.recordRegion()
        }

        Divider {}

        OverlayButton {
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: Math.round(2 * root.d)
            size: root.buttonSize
            glyphSize: Math.round(20 * root.d)
            glyph: "dashboard"
            tip: Translation.tr("Arrange")
            enabled: OverlayContext.openIds.length > 0
            onClicked: OverlayContext.arrange()
        }
    }

    component Divider: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: Math.round(root.buttonSize * 0.55)
        color: OverlayLook.colHairline
    }
}
