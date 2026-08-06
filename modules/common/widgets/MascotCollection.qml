pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Searchable home for every shipped Kira asset. This is intentionally a
 * manual preview surface: portraits, chibis and editorial sheets stay out of
 * the automatic companion/chaos pools, while still having a useful home.
 */
ColumnLayout {
    id: root

    property string query: ""
    property string filter: "all"
    property string selectedPose: MascotCatalog.collectionPoses[0] ?? ""

    readonly property var filters: [
        { key: "all", label: Translation.tr("All") },
        { key: "fullbody", label: Translation.tr("Full body") },
        { key: "animated", label: Translation.tr("Animated") },
        { key: "portrait", label: Translation.tr("Portraits") },
        { key: "chibi", label: Translation.tr("Chibi") },
        { key: "street", label: Translation.tr("Street") },
        { key: "manual", label: Translation.tr("Manual") },
        { key: "editorial", label: Translation.tr("Editorial") }
    ]
    readonly property var filteredPoses: MascotCatalog.collectionPoses.filter(pose => {
        const category = MascotCatalog.collectionCategory(pose)
        const filterMatch = root.filter === "all"
            || (root.filter === "animated" && MascotCatalog.isAnimated(pose))
            || (root.filter === "street" && pose.startsWith("street-"))
            || (root.filter === "manual" && MascotCatalog.isManualOnly(pose))
            || category === root.filter
        return filterMatch && root.prettyName(pose).toLowerCase().includes(root.query.trim().toLowerCase())
    })

    function prettyName(pose) {
        return MascotCatalog.displayName(pose)
    }

    function roleText(pose) {
        if (MascotCatalog.isManualOnly(pose))
            return Translation.tr("Manual-only collection pose")
        switch (MascotCatalog.collectionRole(pose)) {
        case "identity": return Translation.tr("Canonical identity reference")
        case "expression-study": return Translation.tr("Expression and acting study")
        case "brand-key-art": return Translation.tr("iNiR brand key art")
        case "chaos-fail": return Translation.tr("Rare chaos-mode comedy fall")
        case "recording-director": return Translation.tr("Screenshot and recording director")
        case "fullbody": return Translation.tr("Full-body runtime pose")
        case "contextual": return Translation.tr("Contextual prop interaction")
        case "chibi": return Translation.tr("Comic chibi reaction")
        case "animated": return Translation.tr("Animated character loop")
        default: return Translation.tr("Portrait and manga cut-in")
        }
    }

    function selectRelative(offset) {
        const poses = root.filteredPoses
        if (poses.length === 0) return
        const current = poses.indexOf(root.selectedPose)
        root.selectedPose = poses[(Math.max(0, current) + offset + poses.length) % poses.length]
    }

    function selectRandom() {
        const poses = root.filteredPoses
        if (poses.length === 0) return
        if (poses.length === 1) {
            root.selectedPose = poses[0]
            return
        }
        let next = root.selectedPose
        while (next === root.selectedPose)
            next = poses[Math.floor(Math.random() * poses.length)]
        root.selectedPose = next
    }

    spacing: 8
    Layout.fillWidth: true

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 276
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        MascotImage {
            anchors.fill: parent
            anchors.margins: 12
            pose: root.selectedPose
            previewMode: true
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: previewLabels.implicitHeight + 18
            color: Appearance.colors.colLayer1
            opacity: 0.92

            ColumnLayout {
                id: previewLabels
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.prettyName(root.selectedPose)
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.roleText(root.selectedPose)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                { icon: "chevron_left", label: Translation.tr("Previous"), action: "previous" },
                { icon: "casino", label: Translation.tr("Surprise me"), action: "random" },
                { icon: "chevron_right", label: Translation.tr("Next"), action: "next" }
            ]
            delegate: Rectangle {
                id: navButton
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 38
                radius: Appearance.rounding.small
                color: navTap.pressed ? Appearance.colors.colLayer2Active
                    : navHover.hovered ? Appearance.colors.colLayer2Hover
                    : Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol {
                        text: navButton.modelData.icon
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        text: navButton.modelData.label
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                    }
                }
                HoverHandler { id: navHover }
                TapHandler {
                    id: navTap
                    onTapped: {
                        if (navButton.modelData.action === "previous") root.selectRelative(-1)
                        else if (navButton.modelData.action === "next") root.selectRelative(1)
                        else root.selectRandom()
                    }
                }
            }
        }
    }

    MaterialTextField {
        Layout.fillWidth: true
        implicitHeight: 44
        placeholderText: Translation.tr("Search all %1 mascot assets…").arg(MascotCatalog.collectionPoses.length)
        placeholderTextColor: Appearance.colors.colSubtext
        color: Appearance.colors.colOnLayer1
        enableSettingsSearch: false
        onTextChanged: root.query = text
    }

    Flow {
        Layout.fillWidth: true
        Layout.preferredHeight: childrenRect.height
        spacing: 5

        Repeater {
            model: root.filters
            delegate: Rectangle {
                id: filterChip
                required property var modelData
                implicitWidth: filterLabel.implicitWidth + 20
                implicitHeight: 32
                radius: height / 2
                color: root.filter === modelData.key
                    ? Appearance.colors.colPrimaryContainer
                    : filterHover.hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
                border.width: 1
                border.color: root.filter === modelData.key
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOutlineVariant

                StyledText {
                    id: filterLabel
                    anchors.centerIn: parent
                    text: filterChip.modelData.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.filter === filterChip.modelData.key
                        ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colOnLayer2
                }
                HoverHandler { id: filterHover }
                TapHandler {
                    onTapped: {
                        root.filter = filterChip.modelData.key
                        if (root.filteredPoses.indexOf(root.selectedPose) === -1)
                            root.selectedPose = root.filteredPoses[0] ?? ""
                    }
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: Translation.tr("%1 available").arg(root.filteredPoses.length)
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 382
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            cellWidth: Math.max(92, Math.floor(width / Math.max(1, Math.floor(width / 106))))
            cellHeight: 116
            model: root.filteredPoses

            delegate: Item {
                id: cell
                required property string modelData
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Appearance.rounding.verysmall
                    color: root.selectedPose === cell.modelData
                        ? Appearance.colors.colPrimaryContainer
                        : cellHover.hovered ? Appearance.colors.colLayer2Hover : "transparent"
                    border.width: root.selectedPose === cell.modelData ? 2 : 1
                    border.color: root.selectedPose === cell.modelData
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOutlineVariant

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 3

                        MascotImage {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            pose: cell.modelData
                            previewMode: true
                            playAnimation: false
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.prettyName(cell.modelData)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.selectedPose === cell.modelData
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colSubtext
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                        }
                    }
                    HoverHandler { id: cellHover }
                    TapHandler { onTapped: root.selectedPose = cell.modelData }
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: root.filteredPoses.length === 0
            text: Translation.tr("No Kira pose matches this search")
            color: Appearance.colors.colSubtext
        }
    }
}
