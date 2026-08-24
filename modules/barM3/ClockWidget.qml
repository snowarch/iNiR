import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

BarWidgetSwitcher {
    id: root
    property bool showDate: Config.options.bar.m3.verbose
    property var today: new Date()
    readonly property string dateTimeString: DateTime.time
    readonly property bool hasAmPm: dateTimeString.toLowerCase().includes("am") || dateTimeString.toLowerCase().includes("pm")
    readonly property string _timeFontFamily: Config.options?.bar?.m3?.clock?.timeFontFamily ?? ""
    readonly property int _timePixelSize: Config.options?.bar?.m3?.clock?.timePixelSize ?? 0
    readonly property string _dateFontFamily: Config.options?.bar?.m3?.clock?.dateFontFamily ?? ""
    readonly property int _datePixelSize: Config.options?.bar?.m3?.clock?.datePixelSize ?? 0

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.today = new Date()
    }

    colDefault: Component {
        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: root.hasAmPm ? 1 : 0

            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: -4

                Repeater {
                    model: root.dateTimeString.split(/[: ]/)
                    delegate: StyledText {
                        required property string modelData
                        width: implicitWidth
                        horizontalAlignment: Text.AlignHCenter
                        font.letterSpacing: -0.2
                        font.features: { "tnum": 1 }
                        font.family: root._timeFontFamily.length > 0
                            ? root._timeFontFamily
                            : (/^\d+$/.test(modelData) ? Appearance.font.family.numbers : Appearance.font.family.main)
                        font.pixelSize: {
                            if (modelData.match(/am|pm/i))
                                return Appearance.font.pixelSize.smaller;
                            else
                                return root._timePixelSize > 0
                                    ? root._timePixelSize : Appearance.font.pixelSize.large;
                        }
                        color: Appearance.colors.colOnLayer1
                        text: modelData.padStart(2, "0")
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 5
                font.family: root._dateFontFamily.length > 0
                    ? root._dateFontFamily : Appearance.font.family.main
                font.pixelSize: root._datePixelSize > 0
                    ? root._datePixelSize : Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer1
                text: DateTime.shortDate
            }
        }
    }

    colMaterial: Component {
        ColumnLayout {
            id: clockWidget
            spacing: 2
            Layout.alignment: Qt.AlignHCenter

            Column {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: -4

                Repeater {
                    model: DateTime.time.split(/[: ]/)
                    delegate: StyledText {
                        required property string modelData
                        width: implicitWidth
                        horizontalAlignment: Text.AlignHCenter
                        font.letterSpacing: -0.2
                        font.features: { "tnum": 1 }
                        font.family: root._timeFontFamily.length > 0
                            ? root._timeFontFamily
                            : (/^\d+$/.test(modelData) ? Appearance.font.family.numbers : Appearance.font.family.main)
                        font.pixelSize: modelData.match(/am|pm/i)
                            ? Appearance.font.pixelSize.smallest - 2
                            : (root._timePixelSize > 0
                                ? root._timePixelSize : Appearance.font.pixelSize.small)
                        color: Appearance.colors.colPrimary
                        text: modelData.padStart(2, "0")
                    }
                }
            }

            Rectangle {
                width: 25
                height: 25
                radius: Appearance.rounding.full
                color: M3Palette.primary
                Layout.alignment: Qt.AlignHCenter

                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 0
                    text: "calendar_clock"
                    iconSize: Appearance.font.pixelSize.normal
                    color: M3Palette.primaryForeground
                }
            }
        }
    }

    rowDefault: Component {
        RowLayout {
            spacing: 4
            StyledText {
                visible: root.showDate
                font.family: root._dateFontFamily.length > 0
                    ? root._dateFontFamily : Appearance.font.family.main
                font.pixelSize: root._datePixelSize > 0
                    ? root._datePixelSize : Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: DateTime.longDate ?? ""
            }
            StyledText {
                visible: root.showDate
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: "•"
            }
            StyledText {
                font.family: root._timeFontFamily.length > 0
                    ? root._timeFontFamily : Appearance.font.family.main
                font.pixelSize: root._timePixelSize > 0
                    ? root._timePixelSize : Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                text: DateTime.time ?? ""
                font.letterSpacing: -0.4
                font.features: { "tnum": 1 }
            }
        }
    }

    rowMaterial: Component {
        RowLayout {
            spacing: 4
            id: pill

            property var timeParts: DateTime.time.split(/[: ]/)
            property string hours: timeParts[0] ?? "00"
            property string minutes: timeParts[1] ?? "00"
            property string ampm: timeParts[2] ?? ""

            StyledText {
                visible: root.showDate
                font.family: root._dateFontFamily.length > 0
                    ? root._dateFontFamily : Appearance.font.family.main
                font.pixelSize: root._datePixelSize > 0
                    ? root._datePixelSize : Appearance.font.pixelSize.small
                color: M3Palette.pillInk("clockWidget")
                // iNiR's DateTime exposes `date` (long form) and `shortDate`;
                // upstream's `longDate` does not exist here.
                text: DateTime.date
                Layout.alignment: Qt.AlignVCenter
                leftPadding: 5
            }

            Rectangle {
                implicitWidth: timeText.implicitWidth + 16
                implicitHeight: 24
                radius: Appearance.rounding.full
                color: M3Palette.primary

                StyledText {
                    id: timeText
                    anchors.centerIn: parent
                    font.family: root._timeFontFamily.length > 0
                        ? root._timeFontFamily : Appearance.font.family.main
                    font.pixelSize: root._timePixelSize > 0
                        ? root._timePixelSize : Appearance.font.pixelSize.smallie
                    color: M3Palette.primaryForeground
                    font.weight: Font.Bold
                    text: pill.ampm !== "" ? pill.hours.padStart(2, "0") + ":" + pill.minutes.padStart(2, "0") : DateTime.time
                    font.features: { "tnum": 1 }
                    font.letterSpacing: -0.4
                }
            }

            Rectangle {
                visible: pill.ampm !== ""
                z: 1
                implicitWidth: ampmText.implicitWidth + 8
                implicitHeight: 24
                radius: Appearance.rounding.full
                color: M3Palette.tertiaryContainer
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: -10
                StyledText {
                    id: ampmText
                    anchors.centerIn: parent
                    font.family: root._timeFontFamily.length > 0
                        ? root._timeFontFamily : Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: M3Palette.tertiaryContainerForeground
                    text: pill.ampm
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        readonly property bool clickForDetails: Config.options?.bar?.m3?.tooltips?.clickToShow ?? false
        hoverEnabled: true
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && clickForDetails)
                clockPopup.active = !clockPopup.active
        }

        ClockWidgetPopup {
            id: clockPopup
            hoverTarget: mouseArea
            hoverActivates: !mouseArea.clickForDetails
            closeOnOutsideClick: mouseArea.clickForDetails
            onRequestClose: active = false
            today: root.today
        }
    }
}
