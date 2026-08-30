pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common

PillSurface {
    id: root

    mTop: 14
    mLeft: 16
    mRight: 16
    mBottom: 14

    readonly property var entries: [
        { page: 0, icon: "mixer", label: Translation.tr("Quick"), desc: Translation.tr("Wallpaper and common tweaks") },
        { page: 4, icon: "palette", label: Translation.tr("Themes"), desc: Translation.tr("Colors, fonts and global styles") },
        { page: 3, icon: "waves", label: Translation.tr("Wallpaper"), desc: Translation.tr("Backdrop, effects and wallpaper behavior") },
        { page: 2, icon: "app-window", label: Translation.tr("Bar"), desc: Translation.tr("Pill modules, layout and behavior") },
        { page: 12, icon: "monitor", label: Translation.tr("Display & input"), desc: Translation.tr("Niri outputs, devices and layout") },
        { page: 18, icon: "sidebar-right", label: Translation.tr("Workspaces"), desc: Translation.tr("Workspace strip and navigation") },
        { page: 9, icon: "keyboard", label: Translation.tr("Shortcuts"), desc: Translation.tr("Keybindings reference") },
        { page: 1, icon: "cog", label: Translation.tr("System"), desc: Translation.tr("Audio, battery, language and lock") },
        { page: 21, icon: "sparkles", label: Translation.tr("Ricelin"), desc: Translation.tr("Pill and island appearance") }
    ]

    implicitHeight: header.height + 10 * s + divider.height + 8 * s + list.implicitHeight

    function openPage(page) {
        GlobalStates.openSettingsPage(page);
        root.requestClose();
    }

    readonly property point soulPoint: headerGlyph.mapToItem(root, headerGlyph.width / 2, -3 * s)
    ameForm: "soul"
    amePoint: soulPoint

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9 * root.s

            Text {
                id: headerGlyph
                anchors.verticalCenter: parent.verticalCenter
                visible: PillTheme.showGlyphs
                text: PillTheme.glyph("settings")
                color: PillTheme.cream
                font.family: PillTheme.fontJp
                font.pixelSize: 18 * root.s
                font.weight: Font.Medium
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("SETTINGS")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 11.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: PillTheme.hair
    }

    Column {
        id: list
        anchors.top: divider.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 2 * root.s

        Repeater {
            model: root.entries

            delegate: Rectangle {
                id: row
                required property var modelData
                width: list.width
                height: 48 * root.s
                radius: PillMotion.rSmall * root.s
                color: hover.hovered ? PillTheme.frameBg : "transparent"
                border.width: hover.hovered ? 1 : 0
                border.color: PillTheme.frameBorder

                HoverHandler { id: hover }

                GlyphIcon {
                    id: rowIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22 * root.s
                    height: 22 * root.s
                    name: row.modelData.icon
                    color: hover.hovered ? PillTheme.vermLit : PillTheme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: 12 * root.s
                    anchors.right: arrow.left
                    anchors.rightMargin: 10 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s

                    Text {
                        width: parent.width
                        text: row.modelData.label
                        color: PillTheme.cream
                        font.family: PillTheme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.desc
                        color: PillTheme.dim
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        elide: Text.ElideRight
                    }
                }

                GlyphIcon {
                    id: arrow
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16 * root.s
                    height: 16 * root.s
                    name: "chevron-right"
                    color: hover.hovered ? PillTheme.cream : PillTheme.faint
                    stroke: 1.8
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPage(row.modelData.page)
                }
            }
        }
    }
}
