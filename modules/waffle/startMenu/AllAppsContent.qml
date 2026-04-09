pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

WPanelPageColumn {
    id: root
    signal back()

    property string filterText: ""

    // Group apps alphabetically: [{letter: "A", apps: [...]}, ...]
    readonly property var groupedApps: {
        const filter = filterText.toLowerCase().trim()
        const all = DesktopEntries.applications.values
            .filter(e => !e.noDisplay && (filter.length === 0 || (e.name || "").toLowerCase().includes(filter)))
            .sort((a, b) => (a.name || "").localeCompare(b.name || ""))

        const groups = []
        let currentLetter = ""
        let currentGroup = null
        for (const app of all) {
            const letter = (app.name || "?")[0].toUpperCase()
            if (letter !== currentLetter) {
                currentLetter = letter
                currentGroup = { letter: letter, apps: [] }
                groups.push(currentGroup)
            }
            currentGroup.apps.push(app)
        }
        return groups
    }

    // Flat filtered list for Enter-to-activate
    readonly property var flatApps: {
        const result = []
        for (const g of groupedApps) {
            for (const app of g.apps) result.push(app)
        }
        return result
    }

    // Current visible section letter based on scroll position
    readonly property string currentVisibleLetter: {
        const y = appsFlickable.contentY + 10
        const children = appsColumn.children
        let lastLetter = groupedApps.length > 0 ? groupedApps[0].letter : ""
        for (let i = 0; i < children.length; i++) {
            const child = children[i]
            if (child.objectName?.startsWith("section_") && child.y <= y) {
                lastLetter = child.objectName.substring(8)
            }
        }
        return lastLetter
    }

    function activateFirst() {
        if (flatApps.length > 0) {
            flatApps[0].execute()
            GlobalStates.searchOpen = false
        }
    }

    function scrollToLetter(letter: string) {
        const children = appsColumn.children
        for (let i = 0; i < children.length; i++) {
            const child = children[i]
            if (child.objectName === "section_" + letter) {
                scrollAnim.stop()
                scrollAnim.from = appsFlickable.contentY
                scrollAnim.to = Math.min(child.y, Math.max(0, appsFlickable.contentHeight - appsFlickable.height))
                scrollAnim.start()
                return
            }
        }
    }

    onFilterTextChanged: appsFlickable.contentY = 0

    WPanelSeparator {}

    BodyRectangle {
        Layout.fillWidth: true
        implicitHeight: 600
        implicitWidth: 768

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                WBorderlessButton {
                    implicitHeight: 28
                    implicitWidth: backRow.implicitWidth + 16
                    contentItem: RowLayout {
                        id: backRow
                        spacing: 4
                        FluentIcon { icon: "chevron-left"; implicitSize: 12 }
                        WText { text: Translation.tr("Back"); font.pixelSize: Looks.font.pixelSize.small }
                    }
                    onClicked: root.back()
                }
                Item { Layout.fillWidth: true }
                WText {
                    text: Translation.tr("All apps")
                    font.pixelSize: Looks.font.pixelSize.large
                    font.weight: Font.DemiBold
                }
            }

            // Search filter
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: height / 2
                color: Looks.colors.inputBg
                border.width: 1
                border.color: Looks.colors.bg2Border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    FluentIcon { icon: "search"; implicitSize: 14 }

                    WTextInput {
                        id: filterInput
                        Layout.fillWidth: true
                        focus: true
                        onTextChanged: root.filterText = text

                        Keys.onReturnPressed: root.activateFirst()
                        Keys.onEnterPressed: root.activateFirst()
                        Keys.onEscapePressed: root.back()

                        WText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Looks.colors.accentUnfocused
                            text: Translation.tr("Filter apps...")
                            visible: filterInput.text.length === 0
                            font.pixelSize: Looks.font.pixelSize.normal
                        }
                    }
                }
            }

            // Scrollable grid + letter index
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Flickable {
                    id: appsFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: appsColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: WScrollBar {}

                    NumberAnimation {
                        id: scrollAnim
                        target: appsFlickable
                        property: "contentY"
                        duration: Looks.transition.enabled ? 250 : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                    }

                    Column {
                        id: appsColumn
                        width: appsFlickable.width
                        spacing: 4

                        Repeater {
                            model: root.groupedApps

                            delegate: Column {
                                id: sectionDelegate
                                required property var modelData
                                required property int index
                                objectName: "section_" + modelData.letter
                                width: appsColumn.width
                                spacing: 2

                                // Section letter header
                                Item {
                                    width: parent.width
                                    height: 32
                                    WText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sectionDelegate.modelData.letter
                                        font.pixelSize: Looks.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        color: Looks.colors.accent
                                    }
                                }

                                // Grid of apps in this section
                                Grid {
                                    width: parent.width
                                    columns: 6
                                    rowSpacing: 4
                                    columnSpacing: 4

                                    Repeater {
                                        model: sectionDelegate.modelData.apps

                                        delegate: WBorderlessButton {
                                            id: appBtn
                                            required property var modelData
                                            required property int index
                                            implicitWidth: 88
                                            implicitHeight: 76

                                            onClicked: {
                                                appBtn.modelData.execute()
                                                GlobalStates.searchOpen = false
                                            }

                                            // Staggered entry animation per section
                                            opacity: 0
                                            scale: 0.85
                                            Component.onCompleted: {
                                                if (Looks.transition.enabled) {
                                                    btnEntryAnim.start()
                                                } else {
                                                    opacity = 1
                                                    scale = 1
                                                }
                                            }
                                            SequentialAnimation {
                                                id: btnEntryAnim
                                                PauseAnimation { duration: Looks.transition.staggerDelay(appBtn.index, 25) }
                                                ParallelAnimation {
                                                    NumberAnimation { target: appBtn; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutQuad }
                                                    NumberAnimation { target: appBtn; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 0.2 }
                                                }
                                            }

                                            contentItem: ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                Image {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    source: Quickshell.iconPath(appBtn.modelData.icon || appBtn.modelData.name, "application-x-executable")
                                                    sourceSize: Qt.size(32, 32)
                                                }
                                                WText {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.preferredWidth: 80
                                                    text: appBtn.modelData.name || ""
                                                    font.pixelSize: Looks.font.pixelSize.small
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.Wrap
                                                }
                                            }
                                            WToolTip { text: appBtn.modelData.name || "" }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    WText {
                        anchors.centerIn: parent
                        visible: root.groupedApps.length === 0
                        text: Translation.tr("No apps found")
                        color: Looks.colors.fg1
                    }
                }

                // Alphabetical letter jump strip
                Column {
                    id: letterStrip
                    Layout.fillHeight: true
                    Layout.preferredWidth: 24
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.groupedApps.length > 1
                    spacing: 0

                    Repeater {
                        model: root.groupedApps

                        delegate: Item {
                            id: letterItem
                            required property var modelData
                            required property int index
                            width: letterStrip.width
                            height: Math.min(24, Math.max(16, (letterStrip.height - 2) / Math.max(1, root.groupedApps.length)))

                            readonly property bool isActive: root.currentVisibleLetter === modelData.letter

                            Rectangle {
                                anchors.centerIn: parent
                                width: 20
                                height: parent.height - 2
                                radius: Looks.radius.small
                                color: letterMouse.containsMouse ? Looks.colors.bg1Hover : "transparent"

                                Behavior on color { ColorAnimation { duration: 70 } }
                            }

                            WText {
                                anchors.centerIn: parent
                                text: letterItem.modelData.letter
                                font.pixelSize: Looks.font.pixelSize.tiny
                                font.weight: letterItem.isActive ? Font.Bold : Font.Medium
                                color: letterItem.isActive ? Looks.colors.accent : Looks.colors.fg1
                                opacity: letterItem.isActive ? 1.0 : 0.6

                                Behavior on color { ColorAnimation { duration: 70 } }
                                Behavior on opacity { NumberAnimation { duration: 70 } }
                            }

                            MouseArea {
                                id: letterMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.scrollToLetter(letterItem.modelData.letter)
                            }
                        }
                    }

                }
            }
        }
    }
}
