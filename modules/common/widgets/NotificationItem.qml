import qs
import qs.modules.common
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Notifications

Item { // Notification item area
    id: root
    property var notificationObject
    property bool expanded: false
    property bool popup: false
    property bool onlyNotification: false
    property real fontSize: Appearance.font.pixelSize.small
    property real padding: onlyNotification ? 0 : 8
    property real summaryElideRatio: 0.85

    // Animation tokens — use fast timing for dismiss in all modes
    readonly property QtObject _contentAnim: Appearance.animation.elementMoveFast

    property real dragConfirmThreshold: 70 // Drag to discard notification
    property real dismissOvershoot: 58 // Account for gaps and bouncy animations (was notificationIcon.implicitWidth + 20)
    property var qmlParent: root?.parent?.parent // There's something between this and the parent ListView
    property var parentDragIndex: qmlParent?.dragIndex ?? -1
    property var parentDragDistance: qmlParent?.dragDistance ?? 0
    property var dragIndexDiff: Math.abs(parentDragIndex - index)
    property real xOffset: dragIndexDiff == 0 ? parentDragDistance : 0

    readonly property bool notificationCritical: {
        const value = root.notificationObject?.urgency
        if (value === undefined || value === null)
            return false
        return value === NotificationUrgency.Critical
            || String(value).toLowerCase() === "critical"
    }

    readonly property string notificationSummaryText: String(root.notificationObject?.summary ?? "")
    readonly property bool hasNotificationActions: (root.notificationObject?.actions?.length ?? 0) > 0
    readonly property string processedNotificationBodyText: {
        if (!root.notificationObject) return ""
        const body = String(root.notificationObject.body ?? "")
        const source = String(root.notificationObject.appName
            ?? root.notificationObject.summary ?? "")
        return String(NotificationUtils.processNotificationBody(body, source) ?? "")
            .replace(/\n/g, "<br/>")
    }

    implicitHeight: background.implicitHeight

    function destroyWithAnimation(left = false) {
        background.anchors.leftMargin = root.xOffset; // Break binding, capture current position
        background.implicitHeight = background.implicitHeight; // Freeze height so it doesn't resize during dismiss
        root.implicitHeight = root.implicitHeight; // Freeze delegate height in ListView
        root.qmlParent.resetDrag()
        destroyAnimation.left = left;
        destroyAnimation.running = true;
    }

    TextMetrics {
        id: summaryTextMetrics
        font.pixelSize: root.fontSize
        text: root.notificationSummaryText
    }

    SequentialAnimation { // Drag finish animation
        id: destroyAnimation
        property bool left: true
        running: false

        NumberAnimation {
            target: background.anchors
            property: "leftMargin"
            to: (root.width + root.dismissOvershoot) * (destroyAnimation.left ? -1 : 1)
            duration: Number(Appearance.animation?.elementMoveFast?.duration ?? 200)
            easing.type: Number(Appearance.animation?.elementMoveFast?.type ?? Easing.OutCubic)
            easing.bezierCurve: Appearance.animation?.elementMoveFast?.bezierCurve ?? [0.2, 0, 0, 1, 1, 1]
        }
        onFinished: () => {
            Notifications.discardNotification(notificationObject.notificationId);
        }
    }

    DragManager { // Drag manager
        id: dragManager
        anchors.fill: root
        anchors.leftMargin: root.expanded ? -root.dismissOvershoot : 0
        interactive: expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                root.destroyWithAnimation();
            }
        }

        onDraggingChanged: () => {
            if (dragging) {
                root.qmlParent.dragIndex = root.index ?? root.parent.children.indexOf(root);
            }
        }

        onDragDiffXChanged: () => {
            root.qmlParent.dragDistance = dragDiffX;
        }

        onDragReleased: (diffX, diffY) => {
            if (Math.abs(diffX) > root.dragConfirmThreshold)
                root.destroyWithAnimation(diffX < 0);
            else
                dragManager.resetDrag();
        }
    }

    // Note: App icon for expanded notifications with images is now handled by NotificationAppIcon
    // within the image itself (small corner icon) - no separate icon needed here to avoid duplication

    Rectangle { // Background of notification item
        id: background
        width: parent.width
        anchors.left: parent.left
        radius: Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
            : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
            : Appearance.rounding.small
        anchors.leftMargin: root.xOffset

        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging && Appearance.animationsEnabled
            NumberAnimation {
                duration: root._contentAnim.duration
                easing.type: root._contentAnim.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        color: (expanded && !onlyNotification) ?
            Appearance.regaliaEverywhere ? "transparent" :
            Appearance.zzzEverywhere ? (root.notificationCritical ? Appearance.zzz.secondary : Appearance.zzz.chrome) :
            root.notificationCritical ?
                ColorUtils.mix(Appearance.colors.colSecondaryContainer, Appearance.colors.colLayer2, 0.35) :
                (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colLayer3) :
            "transparent"
        border.width: (expanded && !onlyNotification && Appearance.zzzEverywhere) ? Appearance.zzz.borderThick
            : (expanded && !onlyNotification && (Appearance.angelEverywhere || Appearance.auroraEverywhere || Appearance.inirEverywhere)) ? 1 : 0
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
            : Appearance.angelEverywhere ? Appearance.angel.colBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutline, 0.8)
            : Appearance.colors.colLayer0Border

        RegaliaPlate {
            anchors.fill: parent
            visible: Appearance.regaliaEverywhere && root.expanded && !root.onlyNotification
            radius: background.radius
            fillColor: root.notificationCritical ? Appearance.regalia.signalPlate : Appearance.regalia.bg2
            elevated: true
        }

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        implicitHeight: expanded ? (contentColumn.implicitHeight + root.padding * 2) : summaryRow.implicitHeight
        Behavior on implicitHeight {
            // Sidebar: subtle fast transition; Popup: instant (window resize handled by parent)
            enabled: !root.popup && Appearance.animationsEnabled
            NumberAnimation {
                duration: root._contentAnim.duration / 2
                easing.type: root._contentAnim.type
                easing.bezierCurve: root._contentAnim.bezierCurve
            }
        }

        ColumnLayout { // Content column
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: expanded ? root.padding : 0
            spacing: 3

            Behavior on anchors.margins {
                // Sidebar: smooth margin transition; Popup: instant
                enabled: !root.popup && Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            RowLayout { // Summary row
                id: summaryRow
                visible: !root.onlyNotification || !root.expanded
                Layout.fillWidth: true
                implicitHeight: summaryText.implicitHeight
                StyledText {
                    id: summaryText
                    Layout.fillWidth: summaryTextMetrics.width >= contentColumn.width * root.summaryElideRatio
                    visible: !root.onlyNotification
                    font.pixelSize: root.fontSize
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.colors.colOnLayer3
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    elide: Text.ElideRight
                    text: root.notificationSummaryText
                }
                StyledText {
                    opacity: !root.expanded ? 1 : 0
                    visible: opacity > 0
                    Layout.fillWidth: true
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    font.pixelSize: root.fontSize
                    color: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap // Needed for proper eliding????
                    maximumLineCount: 1
                    textFormat: Text.StyledText
                    text: root.processedNotificationBodyText
                }
            }

            ColumnLayout { // Expanded content
                id: expandedContentColumn
                Layout.fillWidth: true
                opacity: root.expanded ? 1 : 0
                visible: opacity > 0

                StyledText { // Notification body (expanded)
                    id: notificationBodyText
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    Layout.fillWidth: true
                    font.pixelSize: root.fontSize
                    color: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.colors.colSubtext
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    textFormat: Text.RichText
                    text: root.notificationObject
                        ? `<style>img{max-width:100%;}</style>${root.processedNotificationBodyText}`
                        : ""

                    onLinkActivated: (link) => {
                        Qt.openUrlExternally(link)
                        GlobalStates.sidebarRightOpen = false
                    }

                    PointingHandLinkHover {}
                }

                Item {
                    Layout.fillWidth: true
                    implicitWidth: actionsFlickable.implicitWidth
                    implicitHeight: actionsFlickable.implicitHeight

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: actionsFlickable.width
                            height: actionsFlickable.height
                            radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                                : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                        }
                    }

                    ScrollEdgeFade {
                        target: actionsFlickable
                        vertical: false
                    }

                    StyledFlickable { // Notification actions
                        id: actionsFlickable
                        anchors.fill: parent
                        implicitHeight: actionRowLayout.implicitHeight
                        contentWidth: actionRowLayout.implicitWidth

                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Behavior on height {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Behavior on implicitHeight {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }

                        RowLayout {
                            id: actionRowLayout
                            Layout.alignment: Qt.AlignBottom
                            spacing: 4

                            NotificationActionButton {
                                Layout.fillWidth: true
                                buttonText: Translation.tr("Close")
                                urgency: root.notificationObject?.urgency ?? NotificationUrgency.Normal
                                implicitWidth: !root.hasNotificationActions ? (Math.max(0, actionsFlickable.width - actionRowLayout.spacing) / 2) :
                                    ((contentItem?.implicitWidth ?? 0) + (leftPadding ?? 0) + (rightPadding ?? 0))

                                onClicked: {
                                    root.destroyWithAnimation()
                                }

                                contentItem: MaterialSymbol {
                                    iconSize: Appearance.font.pixelSize.larger
                                    horizontalAlignment: Text.AlignHCenter
                                    color: root.notificationCritical
                                        ? Appearance.colors.colOnSecondaryContainer
                                        : Appearance.colors.colOnLayer3
                                    text: "close"
                                }
                            }

                            Repeater {
                                id: actionRepeater
                                model: notificationObject?.actions ?? []
                                NotificationActionButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    buttonText: String(modelData?.text ?? "")
                                    urgency: root.notificationObject?.urgency ?? NotificationUrgency.Normal
                                    onClicked: {
                                        Notifications.attemptInvokeAction(notificationObject.notificationId, modelData.identifier);
                                    }
                                }
                            }

                            NotificationActionButton {
                                Layout.fillWidth: true
                                urgency: root.notificationObject?.urgency ?? NotificationUrgency.Normal
                                implicitWidth: !root.hasNotificationActions ? (Math.max(0, actionsFlickable.width - actionRowLayout.spacing) / 2) :
                                    ((contentItem?.implicitWidth ?? 0) + (leftPadding ?? 0) + (rightPadding ?? 0))

                                onClicked: {
                                    Quickshell.execDetached(["wl-copy", notificationObject?.body ?? ""])
                                    copyIcon.text = "inventory"
                                    copyIconTimer.restart()
                                }

                                Timer {
                                    id: copyIconTimer
                                    interval: 1500
                                    repeat: false
                                    onTriggered: {
                                        copyIcon.text = "content_copy"
                                    }
                                }

                                contentItem: MaterialSymbol {
                                    id: copyIcon
                                    iconSize: Appearance.font.pixelSize.larger
                                    horizontalAlignment: Text.AlignHCenter
                                    color: root.notificationCritical
                                        ? Appearance.colors.colOnSecondaryContainer
                                        : Appearance.colors.colOnLayer3
                                    text: "content_copy"
                                }
                            }

                        }
                    }
                }
            }
        }
    }
}
