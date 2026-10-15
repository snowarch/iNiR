pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

FocusScope {
    id: root

    required property string query
    required property int resultCount
    property bool editing: false

    signal queryChangedByUser(string query)
    signal accepted()
    signal cleared()

    implicitWidth: 430
    implicitHeight: 42

    function focusInput(): void {
        root.editing = true
        lensField.forceActiveFocus()
        lensField.selectAll()
    }

    PanelSurface {
        anchors.fill: parent
        elevation: 2
        island: true
        outlined: true
        surfaceDialect: Appearance.surfaceDialectFor("")
        wallpaperBackdrop: false

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: 6
            spacing: 4

            MaterialSymbol {
                text: "filter_alt"
                iconSize: 17
                textRenderType: Text.QtRendering
                color: Appearance.colors.colPrimary
            }

            ToolbarTextField {
                id: lensField
                Layout.fillWidth: true
                implicitHeight: 34
                renderType: Text.QtRendering
                font.hintingPreference: Font.PreferNoHinting
                colBackground: "transparent"
                placeholderText: Translation.tr("Filter windows by app or title")
                text: root.query
                onTextEdited: root.queryChangedByUser(text)
                onAccepted: {
                    root.editing = false
                    root.accepted()
                }
                onActiveFocusChanged: if (!activeFocus) root.editing = false
            }

            StyledText {
                visible: root.query.length > 0
                text: String(root.resultCount)
                renderType: Text.QtRendering
                font.hintingPreference: Font.PreferNoHinting
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                Layout.rightMargin: 2
            }

            IconToolbarButton {
                visible: root.query.length > 0
                implicitWidth: 28
                implicitHeight: 28
                iconRenderType: Text.QtRendering
                text: "close"
                rippleEnabled: false
                stateTransitionsEnabled: false
                pressScaleEnabled: false
                onClicked: root.cleared()
            }
        }
    }
}
