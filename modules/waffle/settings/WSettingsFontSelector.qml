pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

// Font family picker with search - Windows 11 style
WSettingsRow {
    id: root

    property string currentFont: ""
    property list<string> featuredFonts: [
        "Space Grotesk",
        "Roboto Flex",
        "Segoe UI Variable Display",
        "Segoe UI Variable Text",
        "Inter"
    ]

    signal selected(string fontFamily)

    control: Component {
        Item {
            id: controlRoot
            implicitWidth: 200
            implicitHeight: 32

            readonly property string currentFontRef: root.currentFont

            Rectangle {
                id: fontBtn
                anchors.fill: parent
                radius: Looks.settings.radiusMedium
                color: fontBtnArea.pressed
                    ? Looks.settings.tilePressed
                    : fontBtnArea.containsMouse
                        ? Looks.settings.tileHover
                        : Looks.colors.inputBg
                border.width: 1
                border.color: fontPopup.visible
                    ? Looks.colors.accent : Looks.settings.strokeStrong

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 6

                    WText {
                        Layout.fillWidth: true
                        text: controlRoot.currentFontRef || "Select font\u2026"
                        font.family: controlRoot.currentFontRef || Looks.font.family.ui
                        font.pixelSize: Looks.font.pixelSize.normal
                        elide: Text.ElideRight
                    }

                    FluentIcon {
                        icon: fontPopup.visible ? "chevron-up" : "chevron-down"
                        implicitSize: 12
                        color: Looks.colors.subfg
                    }
                }

                MouseArea {
                    id: fontBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (fontPopup.visible) fontPopup.close()
                        else fontPopup.open()
                    }
                }
            }

            Popup {
                id: fontPopup
                readonly property real popupHeight: Math.min(400, fontListView.contentHeight + fontSearchField.height + 24)
                x: fontBtn.width - width
                y: -popupHeight - 4
                width: 280
                height: popupHeight
                padding: 6

                enter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0; easing.type: Easing.OutCubic }
                    }
                }
                exit: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Looks.transition.enabled ? Looks.transition.duration.ultraFast : 0; easing.type: Easing.InQuad }
                        NumberAnimation { property: "scale"; from: 1.0; to: 0.97; duration: Looks.transition.enabled ? Looks.transition.duration.ultraFast : 0; easing.type: Easing.InQuad }
                    }
                }

                onOpened: {
                    fontSearchField.text = ""
                    fontSearchField.forceActiveFocus()
                }

                background: Item {
                    Rectangle {
                        id: popupBg
                        anchors.fill: parent
                        radius: Looks.settings.radiusLarge
                        color: Looks.colors.bgPanelFooter
                        border.width: 1
                        border.color: Looks.settings.strokeStrong
                    }

                    WRectangularShadow {
                        target: popupBg
                        visible: Looks.effectsEnabled
                    }
                }

                contentItem: ColumnLayout {
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Looks.radius.medium
                        color: Looks.colors.inputBg
                        border.width: fontSearchField.activeFocus ? 2 : 1
                        border.color: fontSearchField.activeFocus ? Looks.colors.accent : Looks.colors.bg1Border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            FluentIcon {
                                icon: "search"
                                implicitSize: 14
                                color: Looks.colors.subfg
                            }

                            WTextInput {
                                id: fontSearchField
                                Layout.fillWidth: true
                                font.pixelSize: Looks.font.pixelSize.normal
                                color: Looks.colors.fg
                                selectByMouse: true
                                clip: true
                            }

                            WText {
                                visible: !fontSearchField.text && !fontSearchField.activeFocus
                                text: Translation.tr("Search fonts\u2026")
                                color: Looks.colors.subfg
                                font.pixelSize: Looks.font.pixelSize.normal
                            }
                        }
                    }

                    ListView {
                        id: fontListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        model: {
                            const search = fontSearchField.text.toLowerCase()
                            const allFonts = Qt.fontFamilies()
                            const featured = root.featuredFonts.filter(f => allFonts.indexOf(f) !== -1)
                            let filtered

                            if (search) {
                                filtered = allFonts.filter(f => f.toLowerCase().includes(search))
                            } else {
                                // Put featured fonts at the top, then the rest
                                const rest = allFonts.filter(f => featured.indexOf(f) === -1)
                                filtered = featured.concat(rest)
                            }
                            return filtered
                        }

                        ScrollBar.vertical: WScrollBar {}

                        delegate: Rectangle {
                            id: fontDelegate
                            required property string modelData
                            required property int index
                            width: fontListView.width
                            height: Looks.dp(34)
                            radius: Looks.settings.radiusMedium
                            color: {
                                if (fontDelegate.modelData === controlRoot.currentFontRef)
                                    return Looks.colors.selection
                                if (fontDelegateArea.containsMouse)
                                    return Looks.settings.tileHover
                                return "transparent"
                            }

                            border.width: fontDelegate.modelData === controlRoot.currentFontRef ? 1 : 0
                            border.color: Looks.colors.accent

                            Behavior on color {
                                animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                FluentIcon {
                                    icon: "checkmark"
                                    implicitSize: 12
                                    color: Looks.colors.accent
                                    visible: fontDelegate.modelData === controlRoot.currentFontRef
                                }

                                Item {
                                    implicitWidth: 12
                                    visible: fontDelegate.modelData !== controlRoot.currentFontRef
                                }

                                WText {
                                    Layout.fillWidth: true
                                    text: fontDelegate.modelData
                                    font.family: fontDelegate.modelData
                                    font.pixelSize: Looks.font.pixelSize.normal
                                    font.weight: fontDelegate.modelData === controlRoot.currentFontRef ? Looks.font.weight.strong : Looks.font.weight.regular
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                // Show a star for featured fonts
                                FluentIcon {
                                    icon: "star-filled"
                                    implicitSize: 10
                                    color: Looks.colors.subfg
                                    visible: {
                                        const ff = root.featuredFonts
                                        for (let i = 0; i < ff.length; i++) {
                                            if (ff[i] === fontDelegate.modelData) return true
                                        }
                                        return false
                                    }
                                }
                            }

                            MouseArea {
                                id: fontDelegateArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selected(fontDelegate.modelData)
                                    fontPopup.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
