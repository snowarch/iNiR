pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.waffle.looks

// InfoBar for inline informational/warning/error notices — Windows 11 InfoBar pattern
Rectangle {
    id: root

    enum Severity { Info, Warning, Error, Success }

    property int severity: WSettingsInfoBar.Severity.Info
    property string message: ""
    property bool closable: false

    signal closed()

    Layout.fillWidth: true
    implicitHeight: visible ? barRow.implicitHeight + 16 : 0
    visible: root.message !== ""
    radius: Looks.radius.large

    color: {
        switch (root.severity) {
            case WSettingsInfoBar.Severity.Warning: return Qt.rgba(Looks.colors.warning.r, Looks.colors.warning.g, Looks.colors.warning.b, 0.08)
            case WSettingsInfoBar.Severity.Error: return Qt.rgba(Looks.colors.danger.r, Looks.colors.danger.g, Looks.colors.danger.b, 0.08)
            case WSettingsInfoBar.Severity.Success: return Qt.rgba(Looks.colors.accent.r, Looks.colors.accent.g, Looks.colors.accent.b, 0.08)
            default: return Looks.colors.bg1Base
        }
    }

    border.width: 1
    border.color: {
        switch (root.severity) {
            case WSettingsInfoBar.Severity.Warning: return Qt.rgba(Looks.colors.warning.r, Looks.colors.warning.g, Looks.colors.warning.b, 0.2)
            case WSettingsInfoBar.Severity.Error: return Qt.rgba(Looks.colors.danger.r, Looks.colors.danger.g, Looks.colors.danger.b, 0.2)
            case WSettingsInfoBar.Severity.Success: return Qt.rgba(Looks.colors.accent.r, Looks.colors.accent.g, Looks.colors.accent.b, 0.2)
            default: return Looks.colors.bg1Border
        }
    }

    // Left accent stripe
    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            topMargin: 6
            bottomMargin: 6
        }
        width: 3
        radius: 1.5
        color: {
            switch (root.severity) {
                case WSettingsInfoBar.Severity.Warning: return Looks.colors.warning
                case WSettingsInfoBar.Severity.Error: return Looks.colors.danger
                case WSettingsInfoBar.Severity.Success: return Looks.colors.accent
                default: return Looks.colors.accent
            }
        }
    }

    RowLayout {
        id: barRow
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 14
            rightMargin: 12
        }
        spacing: 10

        FluentIcon {
            icon: {
                switch (root.severity) {
                    case WSettingsInfoBar.Severity.Warning: return "alert"
                    case WSettingsInfoBar.Severity.Error: return "alert"
                    case WSettingsInfoBar.Severity.Success: return "checkmark"
                    default: return "info"
                }
            }
            implicitSize: 16
            color: {
                switch (root.severity) {
                    case WSettingsInfoBar.Severity.Warning: return Looks.colors.warning
                    case WSettingsInfoBar.Severity.Error: return Looks.colors.danger
                    case WSettingsInfoBar.Severity.Success: return Looks.colors.accent
                    default: return Looks.colors.accent
                }
            }
        }

        WText {
            Layout.fillWidth: true
            text: root.message
            font.pixelSize: Looks.font.pixelSize.normal
            color: Looks.colors.fg
            wrapMode: Text.WordWrap
            lineHeight: 1.3
        }

        WBorderlessButton {
            visible: root.closable
            implicitWidth: 24
            implicitHeight: 24

            contentItem: FluentIcon {
                anchors.centerIn: parent
                icon: "dismiss"
                implicitSize: 12
                color: Looks.colors.subfg
            }

            onClicked: {
                root.visible = false
                root.closed()
            }
        }
    }
}
