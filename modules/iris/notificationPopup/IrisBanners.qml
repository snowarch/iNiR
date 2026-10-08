pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components

Item {
    id: root
    property var screenData: null
    readonly property string screenName: root.screenData?.name ?? ""
    readonly property bool fullscreenHere: CompositorService.isNiri && GameMode.hasFullscreenOnOutput(root.screenName) && !NiriService.inOverview
    // Customize owns the Island's surroundings while it is open: banners wait, and still land in Today.
    readonly property bool present: root.screenName === (GlobalStates.focusedScreen?.name ?? "") && !root.fullscreenHere
        && !GlobalStates.irisEdit
        && (root.popups.length > 0 || exitLinger.running)
    readonly property var hitRect: root.present && popupColumn.contentHeight > 0
        ? { x: popupColumn.x, y: popupColumn.y, width: popupColumn.width, height: popupColumn.height } : null
    readonly property var options: Config.options?.iris?.notifications ?? ({})
    readonly property var barOptions: Config.options?.iris?.bar ?? ({})
    readonly property string islandEdge: IrisFrame.islandEdge
    readonly property bool barTop: root.islandEdge !== "bottom"
    readonly property bool islandSide: root.islandEdge === "left" || root.islandEdge === "right"
    readonly property real sideGap: IrisFrame.safeClear(root.islandEdge) + Math.round(12 * root.d)
    readonly property var popups: (Notifications.popupList ?? []).slice(-3).reverse()
    readonly property real d: IrisStyle.density
    readonly property real edgeOffset: (Number(root.barOptions?.height ?? 42)
        + ((root.barOptions?.notch ?? false) ? 0 : Number(root.barOptions?.margin ?? 8) * 2) + 10) * root.d

    visible: root.present
    onPopupsChanged: if (root.popups.length === 0) exitLinger.restart()
    Timer { id: exitLinger; interval: IrisStyle.settleDuration * 2 + 80 }
    readonly property real popupWidth: Math.min(Math.max(260, root.width - 2 * IrisFrame.band - 16),
        Math.max(340, Number(root.options?.width ?? 380) * root.d) + 16)
    readonly property var island: GlobalStates.irisIslandGeometry?.[root.screenName] ?? null
    readonly property real bubbleSize: Math.round(44 * root.d)

    // Each banner is a body of the chassis field, so its material (solid, glass, compositor blur) and
    // its edge are the family's, and it grows out of the Island as one shape before letting go.
    property var bodies: ({})
    readonly property var fieldShapes: root.present ? Object.values(root.bodies) : []
    function publish(key: string, shape: var): void {
        const next = Object.assign({}, root.bodies)
        if (shape) next[key] = shape
        else delete next[key]
        root.bodies = next
    }
    // The Island's live bodies (its chassis and page, not its satellites), from the chassis field.
    property var islandShapes: []
    // Below whatever the Island takes up now, expanded included and while it moves, never over it.
    readonly property real islandClear: {
        if (root.islandSide) return 0
        const bodies = (root.islandShapes ?? []).filter(shape => shape.id !== "edge" && !shape.satellite)
        if (bodies.length === 0) return 0
        const gap = Math.round(10 * root.d)
        return root.barTop ? Math.max(...bodies.map(shape => shape.y + shape.height)) + gap
            : root.height - Math.min(...bodies.map(shape => shape.y)) + gap
    }

    property real now: Date.now()
    Timer { interval: 30000; repeat: true; running: root.visible; onTriggered: root.now = Date.now() }

    function activate(notification): void {
        const actions = notification?.actions ?? []
        const preferred = actions.find(action => action.identifier === "default")
        if (preferred) {
            Notifications.attemptInvokeAction(notification.notificationId, preferred.identifier)
            return
        }
        const key = String(notification?.appName ?? "").toLowerCase()
        if (key.length > 0 && CompositorService.isNiri) {
            const window = (NiriService.windows ?? []).find(w => String(w.app_id ?? "").toLowerCase().includes(key))
            if (window) NiriService.focusWindow(window.id)
        }
        Notifications.timeoutNotification(notification.notificationId)
    }

    ListView {
        id: popupColumn
        x: Math.round(root.islandEdge === "left" ? root.sideGap
            : root.islandEdge === "right" ? parent.width - width - root.sideGap : (parent.width - width) / 2)
        y: Math.round(root.islandSide ? IrisFrame.safeInset("top") + Math.round(12 * root.d)
            : root.barTop ? Math.max(root.edgeOffset + IrisFrame.band, root.islandClear)
            : parent.height - height - Math.max(root.edgeOffset + IrisFrame.band, root.islandClear))
        verticalLayoutDirection: root.barTop ? ListView.TopToBottom : ListView.BottomToTop
        width: Math.min(root.popupWidth - 16, parent.width - 16)
        height: Math.max(1, popupColumn.contentHeight)
        spacing: 8 * root.d
        interactive: false
        model: ScriptModel {
            objectProp: "notificationId"
            values: root.popups
        }
        delegate: bannerComponent
        remove: Transition {
            NumberAnimation {
                property: "leave"
                from: 0
                to: 1
                duration: IrisStyle.recedeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: IrisStyle.recedeCurve
            }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        }
    }

    Component {
        id: bannerComponent

        Item {
            id: banner
            required property var modelData
            readonly property var notification: banner.modelData
            readonly property var actions: (banner.notification?.actions ?? []).filter(action => action.identifier !== "default")
            readonly property bool critical: String(banner.notification?.urgency ?? "") === "critical"
            readonly property bool hovered: bannerHover.hovered
            width: popupColumn.width
            height: plate.height

            onHoveredChanged: if (banner.hovered) Notifications.cancelTimeout(banner.notification.notificationId)
            HoverHandler { id: bannerHover }

            // Frozen: a discarded notification is destroyed before its banner leaves, orphaning a live key.
            property string bodyKey: ""
            property real appear: 0
            Component.onCompleted: {
                banner.bodyKey = String(banner.notification?.notificationId ?? "")
                banner.appear = 1
            }
            Behavior on appear { NumberAnimation { duration: IrisStyle.emergeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve } }
            property real leave: 0
            readonly property bool swiped: Math.abs(banner.swipe) > 1
            readonly property real bloom: Math.min(banner.appear, banner.swiped ? 1 : 1 - banner.leave)
            readonly property bool meltsIntoIsland: root.island !== null && !root.islandSide
            // Measured a tick later: wrapped text re-measures inside the layout while the plate's height is read.
            readonly property real measuredHeight: content.implicitHeight + 24 * root.d
            property real fullHeight: banner.measuredHeight
            onMeasuredHeightChanged: fullSync.restart()
            Timer { id: fullSync; interval: 0; onTriggered: banner.fullHeight = banner.measuredHeight }

            property real swipe: 0
            Behavior on swipe {
                enabled: !swipeDrag.active
                NumberAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing }
            }
            // On the delegate, which never moves: inside the plate the handler would measure its
            // translation in coordinates that slide with the swipe. Nothing may take the grab mid-swipe,
            // and every end (release, cancel, a lost grab) settles the banner: gone or back home.
            function settleSwipe(): void {
                if (Math.abs(banner.swipe) > banner.width * 0.3) {
                    banner.swipe = banner.swipe > 0 ? banner.width : -banner.width
                    dismissLater.restart()
                } else {
                    banner.swipe = 0
                }
            }
            DragHandler {
                id: swipeDrag
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onTranslationChanged: if (active) banner.swipe = translation.x
                onActiveChanged: if (!active) banner.settleSwipe()
                onCanceled: banner.settleSwipe()
            }

            readonly property real fade: 1 - Math.min(1, Math.abs(banner.swipe) / (banner.width * 0.6))
            readonly property var body: {
                void (banner.y + popupColumn.y + popupColumn.contentY + plate.x + plate.y)
                if (banner.bloom <= 0.01 || banner.fade <= 0.01) return null
                const at = plate.mapToItem(root, 0, 0)
                // Swiped away it shrinks about its centre as it slides, instead of fading.
                const w = plate.width * banner.fade
                const h = plate.height * banner.fade
                return { x: at.x + (plate.width - w) / 2, y: at.y + (plate.height - h) / 2, width: w, height: h,
                    radius: Math.min(h / 2, plate.radius), paints: false, id: "banner:" + banner.bodyKey,
                    joins: banner.meltsIntoIsland ? "island" : "", fuse: IrisStyle.fuseDeep * (1 - banner.bloom) }
            }
            onBodyChanged: if (banner.bodyKey) root.publish(banner.bodyKey, banner.body)
            Component.onDestruction: if (banner.bodyKey) root.publish(banner.bodyKey, null)
            Rectangle {
                id: plate
                width: Math.round(root.bubbleSize + (banner.width - root.bubbleSize) * banner.bloom)
                height: Math.round(root.bubbleSize + (banner.fullHeight - root.bubbleSize) * banner.bloom)
                clip: true
                x: Math.round((banner.width - width) / 2 + banner.swipe)
                readonly property real islandLift: {
                    void (banner.y + popupColumn.y + popupColumn.contentY + popupColumn.height)
                    if (!banner.meltsIntoIsland) return root.barTop ? -18 * root.d : 18 * root.d
                    const at = banner.mapToItem(root, 0, 0)
                    return (root.island.y + root.island.height / 2) - (at.y + root.bubbleSize / 2)
                }
                y: Math.round(plate.islandLift * (1 - banner.bloom))
                opacity: Math.min(1, banner.bloom * 3) * banner.fade
                radius: Math.min(height / 2, root.bubbleSize / 2 + (Math.round(22 * root.d) - root.bubbleSize / 2) * banner.bloom)
                color: "transparent"
                border.width: banner.critical ? 1 : 0
                border.color: IrisStyle.tintBorder(IrisStyle.danger)

                Timer {
                    id: dismissLater
                    interval: IrisStyle.duration(180)
                    onTriggered: if (banner.notification) Notifications.timeoutNotification(banner.notification.notificationId)
                }
                TapHandler {
                    onTapped: root.activate(banner.notification)
                }

                RowLayout {
                    id: content
                    x: 14 * root.d
                    y: 12 * root.d
                    width: banner.width - 26 * root.d
                    spacing: 12 * root.d

                    IrisNotificationIcon {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2 * root.d
                        transform: Translate {
                            x: ((root.bubbleSize - 38 * root.d) / 2 - 14 * root.d) * (1 - banner.bloom)
                            y: ((root.bubbleSize - 38 * root.d) / 2 - 14 * root.d) * (1 - banner.bloom)
                        }
                        size: Math.round(38 * root.d)
                        appName: String(banner.notification?.appName ?? "")
                        appIcon: String(banner.notification?.appIcon ?? "")
                        image: String(banner.notification?.image ?? "")
                        summary: String(banner.notification?.summary ?? "")
                        critical: banner.critical
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        opacity: IrisStyle.contentAt(banner.bloom)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8 * root.d
                            IrisText {
                                Layout.fillWidth: true
                                text: String(banner.notification?.summary || banner.notification?.appName || "")
                                font.pixelSize: IrisStyle.typeLabel
                                font.weight: IrisStyle.weight(Font.DemiBold)
                                elide: Text.ElideRight
                            }
                            IrisText {
                                text: {
                                    void root.now
                                    const seconds = Math.max(0, Math.floor((root.now - Number(banner.notification?.time ?? root.now)) / 1000))
                                    return seconds < 60 ? Translation.tr("now")
                                        : seconds < 3600 ? Translation.tr("%1m").arg(Math.floor(seconds / 60))
                                        : Translation.tr("%1h").arg(Math.floor(seconds / 3600))
                                }
                                color: IrisStyle.muted
                                font.pixelSize: IrisStyle.typeMeta
                            }
                        }
                        IrisText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: String(banner.notification?.body ?? "").replace(/<[^>]*>/g, "")
                            color: IrisStyle.subtext
                            font.pixelSize: IrisStyle.typeLabel
                            wrapMode: Text.Wrap
                            maximumLineCount: banner.hovered ? 8 : 2
                            elide: Text.ElideRight
                        }
                        IrisText {
                            Layout.fillWidth: true
                            visible: text.length > 0 && text !== String(banner.notification?.summary ?? "")
                            text: String(banner.notification?.appName ?? "")
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeFootnote
                            elide: Text.ElideRight
                        }

                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: 8 * root.d
                            visible: banner.actions.length > 0
                            spacing: 6 * root.d
                            Repeater {
                                model: banner.actions
                                IrisButton {
                                    id: actionButton
                                    required property var modelData
                                    implicitHeight: Math.round(28 * root.d)
                                    implicitWidth: actionLabel.implicitWidth + 24 * root.d
                                    buttonRadius: height / 2
                                    buttonRadiusPressed: height / 2
                                    colBackground: IrisStyle.fill
                                    colBackgroundHover: IrisStyle.fillHover
                                    Accessible.name: String(actionButton.modelData.text ?? "")
                                    onClicked: Notifications.attemptInvokeAction(banner.notification.notificationId, actionButton.modelData.identifier)
                                    IrisText {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: String(actionButton.modelData.text ?? "")
                                        font.pixelSize: IrisStyle.typeMeta
                                        font.weight: IrisStyle.weight(Font.Medium)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    x: 5 * root.d
                    y: 5 * root.d
                    width: Math.round(22 * root.d)
                    height: width
                    radius: width / 2
                    color: closeArea.containsMouse ? IrisStyle.surfaceHighest : IrisStyle.surfaceHigh
                    border.width: 1
                    border.color: IrisStyle.hairlineStrong
                    opacity: banner.hovered ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: Math.round(13 * root.d)
                        color: IrisStyle.text
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: Translation.tr("Dismiss")
                        onClicked: Notifications.timeoutNotification(banner.notification.notificationId)
                    }
                }
            }
        }
    }

}
