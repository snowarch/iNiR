import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.services

Item {
    id: root
    
    property string mode: "system" // "system" or "dock"
    readonly property string currentTheme: mode === "dock" ? IconThemeService.dockTheme : IconThemeService.currentTheme
    
    implicitHeight: themeButton.implicitHeight
    implicitWidth: 250
    Layout.fillWidth: true

    RippleButton {
        id: themeButton
        anchors.fill: parent
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
                text: root.currentTheme || (root.mode === "dock" ? Translation.tr("Same as system") : Translation.tr("Select theme..."))
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
                opacity: root.currentTheme ? 1 : 0.6
            }

            MaterialSymbol {
                text: popup.visible ? "expand_less" : "expand_more"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
        }

        onClicked: popup.visible ? popup.close() : popup.open()
    }

    Popup {
        id: popup
        y: -height - 4
        width: Math.min(300, themeButton.width)
        height: Math.min(280, themeList.contentHeight + searchField.height + 24 + (root.mode === "dock" ? 40 : 0))
        padding: 8

        onOpened: IconThemeService.ensureInitialized()
        
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
                placeholderText: Translation.tr("Search...")
                font.pixelSize: Appearance.font.pixelSize.small
                background: Rectangle {
                    color: Appearance.colors.colLayer1
                    radius: Appearance.rounding.small
                }
                color: Appearance.m3colors.m3onSurface
                placeholderTextColor: Appearance.colors.colSubtext
            }
            
            // "Same as system" option for dock mode
            RippleButton {
                visible: root.mode === "dock"
                Layout.fillWidth: true
                implicitHeight: 32
                
                colBackground: !root.currentTheme ? Appearance.colors.colPrimaryContainer : "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover

                contentItem: StyledText {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    text: Translation.tr("Same as system")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: !root.currentTheme ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                }

                onClicked: {
                    IconThemeService.setDockTheme("")
                    popup.close()
                }
            }

            ListView {
                id: themeList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: {
                    const themes = IconThemeService.availableThemes
                    const search = searchField.text.toLowerCase()
                    return search ? themes.filter(t => t.toLowerCase().includes(search)) : themes
                }

                delegate: RippleButton {
                    required property string modelData
                    width: themeList.width
                    implicitHeight: 32
                    
                    colBackground: modelData === root.currentTheme 
                        ? Appearance.colors.colPrimaryContainer 
                        : "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active

                    contentItem: StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                        color: modelData === root.currentTheme 
                            ? Appearance.m3colors.m3onPrimaryContainer 
                            : Appearance.m3colors.m3onSurface
                    }

                    onClicked: {
                        if (root.mode === "dock") {
                            IconThemeService.setDockTheme(modelData)
                        } else {
                            IconThemeService.setTheme(modelData)
                        }
                        popup.close()
                    }
                }
            }
        }
    }
}
