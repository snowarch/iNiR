pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 12

    property int configVersion: 0
    property string liftedKind: ""
    property string liftedId: ""

    readonly property var rightDefaultOrder: ["system", "sliders", "toggles", "notifications", "widgets"]
    readonly property var leftDefaultOrder: ["widgets", "ai", "translator", "anime", "animeSchedule", "wallhaven", "news", "ytmusic", "tools", "software"]

    readonly property var rightDescriptors: ({
        system: { icon: "computer", label: Translation.tr("System") },
        sliders: { icon: "tune", label: Translation.tr("Sliders") },
        toggles: { icon: "toggle_on", label: Translation.tr("Quick toggles") },
        notifications: { icon: "notifications", label: Translation.tr("Notifications") },
        widgets: { icon: "dashboard", label: Translation.tr("Widgets") }
    })

    readonly property var leftDescriptors: ({
        widgets: { icon: "widgets", label: Translation.tr("Widgets") },
        ai: { icon: "neurology", label: Translation.tr("Intelligence") },
        translator: { icon: "translate", label: Translation.tr("Translator") },
        anime: { icon: "bookmark_heart", label: Translation.tr("Anime") },
        animeSchedule: { icon: "calendar_month", label: Translation.tr("Schedule") },
        wallhaven: { icon: "collections", label: Translation.tr("Wallhaven") },
        news: { icon: "newspaper", label: Translation.tr("News") },
        ytmusic: { icon: "library_music", label: Translation.tr("YT Music") },
        tools: { icon: "build", label: Translation.tr("Tools") },
        software: { icon: "store", label: Translation.tr("Software") }
    })

    readonly property var rightOrder: {
        root.configVersion
        return root.sanitizeOrder(
            Config.options?.sidebar?.right?.sectionOrder ?? root.rightDefaultOrder,
            root.rightDefaultOrder)
    }

    readonly property var leftOrder: {
        root.configVersion
        return root.sanitizeOrder(
            Config.options?.sidebar?.left?.tabOrder ?? root.leftDefaultOrder,
            root.leftDefaultOrder)
    }

    readonly property real notificationsWeight: Math.max(0.35,
        Number(Config.options?.sidebar?.right?.sectionWeights?.notifications ?? 1))
    readonly property real widgetsWeight: Math.max(0.35,
        Number(Config.options?.sidebar?.right?.sectionWeights?.widgets ?? 1))
    readonly property real notificationsShare: notificationsWeight / Math.max(0.7,
        notificationsWeight + widgetsWeight)

    function sanitizeOrder(saved, defaults): var {
        const result = []
        const source = Array.isArray(saved) ? saved : defaults
        for (let i = 0; i < source.length; i++) {
            const id = source[i]
            if (defaults.includes(id) && !result.includes(id)) result.push(id)
        }
        for (let i = 0; i < defaults.length; i++) {
            if (!result.includes(defaults[i])) result.push(defaults[i])
        }
        return result
    }

    function toggleLift(kind: string, id: string): void {
        if (liftedKind === kind && liftedId === id) {
            cancelLift()
            return
        }
        liftedKind = kind
        liftedId = id
    }

    function cancelLift(): void {
        liftedKind = ""
        liftedId = ""
    }

    function place(kind: string, insertPosition: int): void {
        const order = kind === "right" ? [...rightOrder] : [...leftOrder]
        const from = order.indexOf(liftedId)
        if (liftedKind !== kind || from < 0) {
            cancelLift()
            return
        }
        const moved = order.splice(from, 1)[0]
        let target = insertPosition
        if (target > from) target--
        target = Math.max(0, Math.min(target, order.length))
        order.splice(target, 0, moved)
        Config.setNestedValue(kind === "right"
            ? "sidebar.right.sectionOrder" : "sidebar.left.tabOrder", order)
        cancelLift()
    }

    function saveBalance(share: real): void {
        const clamped = Math.max(0.2, Math.min(0.8, share))
        Config.setNestedValues({
            "sidebar.right.sectionWeights.notifications": clamped * 2,
            "sidebar.right.sectionWeights.widgets": (1 - clamped) * 2
        })
    }

    Connections {
        target: Config
        function onConfigChanged(): void { root.configVersion++ }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: arrangeHintRow.implicitHeight + 20
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        RowLayout {
            id: arrangeHintRow
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            MaterialSymbol {
                text: root.liftedKind.length > 0 ? "touch_app" : "drag_indicator"
                iconSize: 19
                color: Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                text: root.liftedKind.length > 0
                    ? Translation.tr("Choose a highlighted slot to place the lifted item.")
                    : Translation.tr("Tap an item to lift it, then tap a slot to place it.")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
            RippleButtonWithIcon {
                visible: root.liftedKind.length > 0
                materialIcon: "close"
                mainText: Translation.tr("Cancel")
                onClicked: root.cancelLift()
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                text: Translation.tr("Right sidebar sections")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Controls the live order of the normal right sidebar.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }

        RippleButtonWithIcon {
            materialIcon: "restart_alt"
            mainText: Translation.tr("Reset")
            onClicked: {
                Config.setNestedValue("sidebar.right.sectionOrder", root.rightDefaultOrder)
                root.cancelLift()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 44

        Flickable {
            anchors.fill: parent
            contentWidth: rightOrderRow.implicitWidth
            contentHeight: height
            clip: true
            interactive: contentWidth > width
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: rightOrderRow
                height: parent.height
                spacing: 6

                Repeater {
                    model: root.rightOrder
                    delegate: Row {
                        id: rightDelegate
                        required property string modelData
                        required property int index
                        height: rightOrderRow.height
                        spacing: 6
                        readonly property var descriptor: root.rightDescriptors[modelData]

                        ArrangeDropSlot {
                            anchors.verticalCenter: parent.verticalCenter
                            active: root.liftedKind === "right"
                                && !(root.liftedId === rightDelegate.modelData
                                    || (rightDelegate.index > 0
                                        && root.rightOrder[rightDelegate.index - 1] === root.liftedId))
                            onPlaced: root.place("right", rightDelegate.index)
                        }
                        ArrangeChip {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: rightDelegate.descriptor?.icon ?? "widgets"
                            label: rightDelegate.descriptor?.label ?? rightDelegate.modelData
                            lifted: root.liftedKind === "right" && root.liftedId === rightDelegate.modelData
                            dimmed: root.liftedKind.length > 0 && !lifted
                            onTapped: root.toggleLift("right", rightDelegate.modelData)
                        }
                    }
                }

                ArrangeDropSlot {
                    anchors.verticalCenter: parent.verticalCenter
                    active: root.liftedKind === "right"
                        && root.rightOrder[root.rightOrder.length - 1] !== root.liftedId
                    onPlaced: root.place("right", root.rightOrder.length)
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Section height balance")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: Translation.tr("Notifications %1% · Widgets %2%")
                    .arg(Math.round(root.notificationsShare * 100))
                    .arg(Math.round((1 - root.notificationsShare) * 100))
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        StyledSlider {
            Layout.fillWidth: true
            from: 0.2
            to: 0.8
            stepSize: 0.05
            value: root.notificationsShare
            scrollable: true
            tooltipContent: Math.round(value * 100) + "% / " + Math.round((1 - value) * 100) + "%"
            settingsSearchLabel: Translation.tr("Section height balance")
            settingsSearchDescription: Translation.tr("Share flexible space between notifications and widgets.")
            onMoved: root.saveBalance(value)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Appearance.colors.colOutlineVariant
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                text: Translation.tr("Left sidebar tabs")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Disabled tabs keep their saved position and return there when enabled.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }

        RippleButtonWithIcon {
            materialIcon: "restart_alt"
            mainText: Translation.tr("Reset")
            onClicked: {
                Config.setNestedValue("sidebar.left.tabOrder", root.leftDefaultOrder)
                root.cancelLift()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 44

        Flickable {
            anchors.fill: parent
            contentWidth: leftOrderRow.implicitWidth
            contentHeight: height
            clip: true
            interactive: contentWidth > width
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: leftOrderRow
                height: parent.height
                spacing: 6

                Repeater {
                    model: root.leftOrder
                    delegate: Row {
                        id: leftDelegate
                        required property string modelData
                        required property int index
                        height: leftOrderRow.height
                        spacing: 6
                        readonly property var descriptor: root.leftDescriptors[modelData]

                        ArrangeDropSlot {
                            anchors.verticalCenter: parent.verticalCenter
                            active: root.liftedKind === "left"
                                && !(root.liftedId === leftDelegate.modelData
                                    || (leftDelegate.index > 0
                                        && root.leftOrder[leftDelegate.index - 1] === root.liftedId))
                            onPlaced: root.place("left", leftDelegate.index)
                        }
                        ArrangeChip {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: leftDelegate.descriptor?.icon ?? "widgets"
                            label: leftDelegate.descriptor?.label ?? leftDelegate.modelData
                            lifted: root.liftedKind === "left" && root.liftedId === leftDelegate.modelData
                            dimmed: root.liftedKind.length > 0 && !lifted
                            onTapped: root.toggleLift("left", leftDelegate.modelData)
                        }
                    }
                }

                ArrangeDropSlot {
                    anchors.verticalCenter: parent.verticalCenter
                    active: root.liftedKind === "left"
                        && root.leftOrder[root.leftOrder.length - 1] !== root.liftedId
                    onPlaced: root.place("left", root.leftOrder.length)
                }
            }
        }
    }
}
