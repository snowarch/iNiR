pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root

    signal closed
    signal activateWindow(int windowId)

    required property var itemSnapshot
    property int selectedIndex: 0

    // Config getters for live updates
    function cfg() { return Config.options?.waffles?.altSwitcher ?? {} }
    function getPreset() { return cfg().preset ?? "thumbnails" }
    function getThumbnailWidth() { return cfg().thumbnailWidth ?? 280 }
    function getThumbnailHeight() { return cfg().thumbnailHeight ?? 180 }

    // Reactive properties that update when config changes
    property string preset: getPreset()
    property int thumbnailWidth: getThumbnailWidth()
    property int thumbnailHeight: getThumbnailHeight()

    property int columns: Math.min(5, Math.max(1, itemSnapshot?.length ?? 1))

    // Update properties when config changes
    Connections {
        target: Config
        function onOptionsChanged() {
            root.preset = root.getPreset()
            root.thumbnailWidth = root.getThumbnailWidth()
            root.thumbnailHeight = root.getThumbnailHeight()
        }
    }

    implicitWidth: contentLoader.item?.implicitWidth ?? 400
    implicitHeight: contentLoader.item?.implicitHeight ?? 300

    property real contentOpacity: 0
    property real contentScale: 0.95

    Component.onCompleted: openAnim.start()

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "contentOpacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "contentScale"; from: 0.95; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentOpacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "contentScale"; to: 0.95; duration: 150; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.closed() }
    }

    function close() { closeAnim.start() }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        opacity: root.contentOpacity
        scale: root.contentScale
        sourceComponent: {
            switch (root.preset) {
                case "compact": return compactPreset
                case "list": return listPreset
                case "cards": return cardsPreset
                case "none": return nonePreset
                default: return thumbnailsPreset
            }
        }
    }

    // === PRESET: Thumbnails ===
    Component {
        id: thumbnailsPreset
        Column {
            spacing: 16
            Grid {
                columns: root.columns
                spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: ScriptModel { values: root.itemSnapshot }
                    WaffleAltSwitcherThumbnail {
                        required property var modelData
                        required property int index
                        item: modelData
                        selected: root.selectedIndex === index
                        thumbnailWidth: root.thumbnailWidth
                        thumbnailHeight: root.thumbnailHeight
                        onClicked: { root.selectedIndex = index; root.activateWindow(modelData.id) }
                    }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: appNameText.implicitWidth + 32
                height: 36
                radius: Looks.radius.large
                color: Looks.colors.bg1Base
                WText {
                    id: appNameText
                    anchors.centerIn: parent
                    text: root.itemSnapshot?.[root.selectedIndex]?.appName ?? ""
                    font.pixelSize: Looks.font.pixelSize.large
                    color: Looks.colors.fg
                }
            }
        }
    }

    // === PRESET: Compact ===
    Component {
        id: compactPreset
        WPane {
            radius: Looks.radius.xLarge
            contentItem: Row {
                spacing: 4
                leftPadding: 8; rightPadding: 8; topPadding: 8; bottomPadding: 8
                Repeater {
                    model: ScriptModel { values: root.itemSnapshot }
                    WaffleAltSwitcherTile {
                        required property var modelData
                        required property int index
                        item: modelData
                        selected: root.selectedIndex === index
                        compact: true
                        onClicked: { root.selectedIndex = index; root.activateWindow(modelData.id) }
                    }
                }
            }
        }
    }

    // === PRESET: List ===
    Component {
        id: listPreset
        WPane {
            radius: Looks.radius.large

            contentItem: Column {
                spacing: 0

                RowLayout {
                    width: 400
                    height: 44

                    Item { width: 16 }
                    WText {
                        text: Translation.tr("Switch windows")
                        font.pixelSize: Looks.font.pixelSize.larger
                        font.weight: Looks.font.weight.strong
                        color: Looks.colors.fg
                    }
                    Item { Layout.fillWidth: true }
                    WText {
                        text: (root.itemSnapshot?.length ?? 0) + " " + Translation.tr("windows")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                    }
                    Item { width: 16 }
                }

                WPanelSeparator { width: 400 }

                Column {
                    width: 400
                    topPadding: 8; bottomPadding: 8; leftPadding: 8; rightPadding: 8
                    spacing: 4

                    Repeater {
                        model: ScriptModel { values: root.itemSnapshot }
                        WaffleAltSwitcherTile {
                            required property var modelData
                            required property int index
                            width: 384
                            item: modelData
                            selected: root.selectedIndex === index
                            compact: false
                            onClicked: { root.selectedIndex = index; root.activateWindow(modelData.id) }
                        }
                    }
                }
            }
        }
    }

    // === PRESET: None (no UI, just switch) ===
    Component {
        id: nonePreset
        Item {
            implicitWidth: 1
            implicitHeight: 1
            visible: false
        }
    }


    // === PRESET: Cards (Fluent-style with shadows and acrylic) ===
    Component {
        id: cardsPreset
        Item {
            implicitWidth: cardsRow.width
            implicitHeight: cardsRow.height + selectedLabel.height + 24

            Row {
                id: cardsRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    model: ScriptModel { values: root.itemSnapshot }

                    Item {
                        required property var modelData
                        required property int index
                        width: 180
                        height: 200

                        // Shadow behind card
                        WRectangularShadow {
                            target: cardPane
                        }

                        // Main card using WPane
                        Rectangle {
                            id: cardPane
                            anchors.fill: parent
                            radius: Looks.radius.large
                            color: root.selectedIndex === index ? Looks.colors.accent : Looks.colors.bgPanelFooter
                            border.width: root.selectedIndex === index ? 0 : 1
                            border.color: Looks.colors.bg2Border
                            scale: cardMouse.pressed ? 0.95 : (cardMouse.containsMouse ? 1.02 : 1.0)
                            
                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                animation: Looks.transition.color.createObject(this)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                // Icon area with gradient background
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Looks.radius.medium
                                    color: root.selectedIndex === index 
                                        ? ColorUtils.transparentize(Looks.colors.accentFg, 0.9)
                                        : Looks.colors.bg1Base

                                    WAppIcon {
                                        anchors.centerIn: parent
                                        implicitSize: 72
                                        iconName: AppSearch.guessIcon(modelData?.appId ?? modelData?.appName ?? "")
                                        tryCustomIcon: false
                                        monochrome: false
                                    }
                                }

                                // App name
                                WText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData?.appName ?? "Window"
                                    font.pixelSize: Looks.font.pixelSize.normal
                                    font.weight: Looks.font.weight.strong
                                    color: root.selectedIndex === index ? Looks.colors.accentFg : Looks.colors.fg
                                    elide: Text.ElideMiddle
                                }

                                // Workspace indicator
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: (modelData?.workspaceIdx ?? 0) > 0
                                    width: wsCardText.implicitWidth + 12
                                    height: 20
                                    radius: Looks.radius.small
                                    color: root.selectedIndex === index 
                                        ? ColorUtils.transparentize(Looks.colors.accentFg, 0.8)
                                        : Looks.colors.bg2

                                    WText {
                                        id: wsCardText
                                        anchors.centerIn: parent
                                        text: Translation.tr("WS") + " " + (modelData?.workspaceIdx ?? "")
                                        font.pixelSize: Looks.font.pixelSize.small
                                        color: root.selectedIndex === index ? Looks.colors.accentFg : Looks.colors.subfg
                                    }
                                }
                            }

                            // Selection indicator at bottom
                            Rectangle {
                                visible: root.selectedIndex === index
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 8
                                width: 32
                                height: 4
                                radius: 2
                                color: Looks.colors.accentFg
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.selectedIndex = index
                                root.activateWindow(modelData.id)
                            }
                        }
                    }
                }
            }

            // Window title label
            Rectangle {
                id: selectedLabel
                anchors.top: cardsRow.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(titleLabelText.implicitWidth + 40, 200)
                height: 44
                radius: Looks.radius.large
                color: Looks.colors.bgPanelFooter
                border.width: 1
                border.color: Looks.colors.bg2Border

                WRectangularShadow {
                    target: parent
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    WAppIcon {
                        implicitSize: 24
                        iconName: AppSearch.guessIcon(root.itemSnapshot?.[root.selectedIndex]?.appId ?? "")
                        tryCustomIcon: false
                        monochrome: false
                    }

                    WText {
                        id: titleLabelText
                        text: root.itemSnapshot?.[root.selectedIndex]?.title ?? ""
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.fg
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 350
                    }
                }
            }
        }
    }
}
