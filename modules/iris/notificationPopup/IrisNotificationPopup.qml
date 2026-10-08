pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.field as Field

PanelWindow {
    id: root
    readonly property var options: Config.options?.iris?.notifications ?? ({})
    readonly property var barOptions: Config.options?.iris?.bar ?? ({})
    readonly property bool barTop: String(root.barOptions?.position ?? "top") === "top"
    readonly property var popups: (Notifications.popupList ?? []).slice(-3).reverse()
    readonly property real d: IrisStyle.density
    readonly property real topOffset: (root.barTop
        ? (Number(root.barOptions?.height ?? 42) + ((root.barOptions?.notch ?? false) ? 0 : Number(root.barOptions?.margin ?? 8) * 2) + 10) * root.d
        : 10 * root.d) + IrisFrame.musicReach("top")

    visible: root.popups.length > 0 || exitLinger.running
    onPopupsChanged: if (root.popups.length === 0) exitLinger.restart()
    Timer { id: exitLinger; interval: IrisStyle.settleDuration * 2 + 80 }
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.visible
    }
    screen: outputHold.output
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:iris-notifications"
    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        left: IrisFrame.band
        right: IrisFrame.band
        top: IrisFrame.band
    }
    readonly property real popupWidth: Math.min(Math.max(260, (root.screen?.width ?? 1920) - 16),
        Math.max(340, Number(root.options?.width ?? 380) * root.d) + 16)
    implicitWidth: root.screen?.width ?? root.popupWidth
    implicitHeight: Math.min((root.screen?.height ?? 1080) * 0.8, root.topOffset + 3 * 250 * root.d)
    mask: Region { item: popupColumn }
    readonly property var island: GlobalStates.irisIslandGeometry?.[root.screen?.name ?? ""] ?? null
    readonly property real bubbleSize: Math.round(44 * root.d)

    property var blurBodies: ({})
    function publishBlur(key: string, shape: var): void {
        const next = Object.assign({}, root.blurBodies)
        if (shape) next[key] = shape
        else delete next[key]
        root.blurBodies = next
    }
    Field.IrisBlurRegion {
        window: root
        shapes: root.visible ? Object.values(root.blurBodies) : []
        windowWidth: root.width
        windowHeight: root.height
    }
    // One wallpaper source for the fallback window, borrowed by all its banners.
    Field.IrisField {
        anchors.fill: parent
        framed: false
        providesBackdrop: true
        compositorAllowed: true
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
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: root.topOffset
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

            property real appear: 0
            property string blurKey: ""
            Component.onCompleted: {
                banner.blurKey = String(banner.notification?.notificationId ?? "")
                root.publishBlur(banner.blurKey, banner.blurShape)
                banner.appear = 1
            }
            Component.onDestruction: root.publishBlur(banner.blurKey, null)
            readonly property var blurShape: {
                if (!root.visible || !IrisStyle.glassCompositor || plate.opacity < 0.999) return null
                return { x: popupColumn.x + banner.x + plate.x, y: popupColumn.y + banner.y + plate.y,
                    width: plate.width, height: plate.height, radius: plate.radius }
            }
            onBlurShapeChanged: if (banner.blurKey.length > 0) root.publishBlur(banner.blurKey, banner.blurShape)
            Behavior on appear { NumberAnimation { duration: IrisStyle.emergeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve } }
            property real leave: 0
            readonly property bool swiped: Math.abs(banner.swipe) > 1
            readonly property real bloom: Math.min(banner.appear, banner.swiped ? 1 : 1 - banner.leave)
            readonly property bool meltsIntoIsland: root.barTop && root.island !== null
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

            RectangularShadow {
                x: plate.x
                y: plate.y + 4 * root.d
                width: plate.width
                height: plate.height
                radius: plate.radius
                blur: 18 * root.d
                spread: -3 * root.d
                color: IrisStyle.shadow
                opacity: plate.opacity * IrisStyle.shadowAt(banner.bloom)
            }
            Field.IrisField {
                anchors.fill: parent
                z: -1
                framed: false
                compositorAllowed: true
                opacity: plate.opacity
                sceneOrigin: Qt.point(root.margins.left + popupColumn.x + banner.x,
                    root.margins.top + popupColumn.y + banner.y)
                sceneSize: Qt.size(root.screen?.width ?? 0, root.screen?.height ?? 0)
                shapes: plate.opacity > 0 ? [{ x: plate.x, y: plate.y, width: plate.width,
                    height: plate.height, radius: plate.radius, paints: true, fuse: 0 }] : []
            }
            ClippingRectangle {
                id: plate
                width: Math.round(root.bubbleSize + (banner.width - root.bubbleSize) * banner.bloom)
                height: Math.round(root.bubbleSize + (banner.fullHeight - root.bubbleSize) * banner.bloom)
                clip: true
                x: Math.round((banner.width - width) / 2 + banner.swipe)
                readonly property real islandLift: banner.meltsIntoIsland
                    ? (root.island.y + root.island.bubble / 2) - (popupColumn.y + banner.y + root.bubbleSize / 2) : -18 * root.d
                y: Math.round(banner.meltsIntoIsland ? plate.islandLift * (1 - banner.bloom) : (1 - banner.bloom) * -18 * root.d)
                opacity: Math.min(1, banner.bloom * 3)
                    * (1 - Math.min(1, Math.abs(banner.swipe) / (banner.width * 0.6)))
                radius: Math.min(height / 2, root.bubbleSize / 2 + (Math.round(22 * root.d) - root.bubbleSize / 2) * banner.bloom)
                color: IrisStyle.bodyClip
                border.width: banner.critical ? 1 : 0
                border.color: banner.critical ? IrisStyle.tintBorder(IrisStyle.danger)
                    : ColorUtils.applyAlpha(IrisStyle.border, IrisStyle.border.a * banner.bloom)

                Timer {
                    id: dismissLater
                    interval: IrisStyle.duration(180)
                    onTriggered: Notifications.timeoutNotification(banner.notification.notificationId)
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
