pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Visual pose picker for the mascot: a collapsed row showing the current
 * selection as a real thumbnail, expanding into a scrollable grid of pose
 * thumbnails. No dropdowns. Options come from the caller (built from
 * assets/images/mascot/manifest.json): [{ displayName, value, image }],
 * where image is a resolved file path ("" renders the auto/dice cell).
 *
 * Shared by both families (registered in this folder's qmldir): ii pages
 * use it directly inside SettingsGroup, waffle pages inside WSettingsCard.
 * Styling is Appearance-token based on purpose so one component serves
 * every global style. Usage:
 *
 *   MascotPoseGallery {
 *       label: Translation.tr("Pose for this event")
 *       options: somePoseOptions   // [{ displayName, value, image }]
 *       currentValue: Config.options?.mascot?.companion?.eventPoses?.music ?? ""
 *       onSelected: value => Config.setNestedValue("mascot.companion.eventPoses.music", value)
 *   }
 */
ColumnLayout {
    id: root

    property string label: ""
    property var options: []
    property string currentValue: ""
    property bool expanded: false
    signal selected(string value)

    // Chrome is parameterised so the same component can wear either family's
    // skin. Defaults are the ii/Material tokens; waffle call sites override
    // them with Looks-derived values so the gallery stops looking like a
    // Material widget dropped into a waffle card.
    property real surfaceRadius: Appearance.rounding.small
    property real cellRadius: Appearance.rounding.verysmall
    property color surfaceColor: Appearance.colors.colLayer2
    property color surfaceHoverColor: Appearance.colors.colLayer2Hover
    property color surfacePressedColor: Appearance.colors.colLayer2Active
    property color thumbBackdropColor: Appearance.colors.colLayer3
    property color selectedColor: Appearance.colors.colPrimaryContainer
    property color selectedBorderColor: Appearance.colors.colPrimary
    property color cellBorderColor: Appearance.colors.colOutlineVariant
    property color textColor: Appearance.colors.colOnLayer1
    property color subTextColor: Appearance.colors.colSubtext
    property color iconColor: Appearance.colors.colOnLayer2
    property color selectedTextColor: Appearance.colors.colOnPrimaryContainer

    readonly property var _current: {
        const found = options.find(o => o.value === root.currentValue)
        return found ?? (options.length ? options[0] : ({ displayName: "", value: "", image: "" }))
    }

    spacing: 4
    Layout.fillWidth: true

    // Collapsed header row: current thumbnail + name, tap to expand
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 56
        radius: root.surfaceRadius
        color: headerTap.pressed ? root.surfacePressedColor
             : headerHover.hovered ? root.surfaceHoverColor
             : root.surfaceColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: root.cellRadius
                color: root.thumbBackdropColor

                AnimatedImage {
                    anchors.fill: parent
                    anchors.margins: 3
                    visible: root._current.image?.length > 0
                    source: root._current.image ?? ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    playing: Appearance.animationsEnabled && visible
                    cache: true
                    smooth: true
                    mipmap: true
                    antialiasing: true
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !(root._current.image?.length > 0)
                    text: "casino"
                    iconSize: 24
                    color: root.iconColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: root.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.textColor
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root._current.displayName ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.subTextColor
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                text: root.expanded ? "expand_less" : "expand_more"
                iconSize: 22
                color: root.iconColor
            }
        }

        HoverHandler { id: headerHover }
        TapHandler {
            id: headerTap
            onTapped: root.expanded = !root.expanded
        }
    }

    // Expanded thumbnail grid
    Rectangle {
        visible: root.expanded
        Layout.fillWidth: true
        implicitHeight: 330
        radius: root.surfaceRadius
        color: root.surfaceColor

        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            cellWidth: Math.max(96, Math.floor(width / Math.max(1, Math.floor(width / 104))))
            cellHeight: 118
            model: root.options
            currentIndex: Math.max(0, root.options.findIndex(o => o.value === root.currentValue))

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight

                readonly property bool isSelected: cell.modelData.value === root.currentValue

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: root.cellRadius
                    color: cell.isSelected ? root.selectedColor
                         : cellHover.hovered ? root.surfaceHoverColor
                         : "transparent"
                    border.width: cell.isSelected ? 2 : 1
                    border.color: cell.isSelected ? root.selectedBorderColor
                                : root.cellBorderColor

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            AnimatedImage {
                                anchors.fill: parent
                                visible: cell.modelData.image?.length > 0
                                source: cell.modelData.image ?? ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                playing: Appearance.animationsEnabled && visible
                                smooth: true
                                mipmap: true
                                antialiasing: true
                                sourceSize.width: 256
                                sourceSize.height: 256
                            }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: !(cell.modelData.image?.length > 0)
                                text: "casino"
                                iconSize: 34
                                color: root.iconColor
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: cell.modelData.displayName ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: cell.isSelected ? root.selectedTextColor : root.subTextColor
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                        }
                    }

                    HoverHandler { id: cellHover }
                    TapHandler {
                        onTapped: {
                            root.selected(cell.modelData.value)
                            root.expanded = false
                        }
                    }
                }
            }
        }
    }
}
