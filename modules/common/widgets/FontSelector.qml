import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common

Item {
    id: root
    property string selectedFont: ""
    property string label: ""
    property string icon: "font_download"
    
    implicitHeight: column.implicitHeight
    implicitWidth: column.implicitWidth
    Layout.fillWidth: true

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 4

        RowLayout {
            spacing: 4
            MaterialSymbol {
                text: root.icon
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: root.label
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        RippleButton {
            id: fontButton
            Layout.fillWidth: true
            implicitHeight: 40
            
            colBackground: Appearance.colors.colLayer1
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colRipple: Appearance.colors.colLayer1Active

            contentItem: RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: root.selectedFont || "Select font..."
                    font.family: root.selectedFont || Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }

                MaterialSymbol {
                    text: popup.visible ? "expand_less" : "expand_more"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
            }

            onClicked: {
                if (popup.visible) popup.close()
                else popup.open()
            }
        }
    }

    Popup {
        id: popup
        y: fontButton.y + fontButton.height + 4
        width: fontButton.width
        height: Math.min(300, fontList.contentHeight + searchField.height + 24)
        padding: 8
        
        background: Rectangle {
            color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                 : Appearance.colors.colLayer2Base
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                        : Appearance.colors.colLayer0Border
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search fonts..."
                font.pixelSize: Appearance.font.pixelSize.small
                background: Rectangle {
                    color: Appearance.colors.colLayer1
                    radius: Appearance.rounding.small
                }
                color: Appearance.m3colors.m3onSurface
                placeholderTextColor: Appearance.colors.colSubtext
            }

            ListView {
                id: fontList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: {
                    let fonts = Qt.fontFamilies()
                    let search = searchField.text.toLowerCase()
                    if (search) {
                        return fonts.filter(f => f.toLowerCase().includes(search))
                    }
                    return fonts
                }

                delegate: RippleButton {
                    required property string modelData
                    required property int index
                    width: fontList.width
                    implicitHeight: 36
                    
                    colBackground: modelData === root.selectedFont 
                        ? Appearance.colors.colPrimaryContainer 
                        : "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active

                    contentItem: StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        font.family: modelData
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                        color: modelData === root.selectedFont 
                            ? Appearance.m3colors.m3onPrimaryContainer 
                            : Appearance.m3colors.m3onSurface
                    }

                    onClicked: {
                        root.selectedFont = modelData
                        popup.close()
                    }
                }
            }
        }
    }
}
