import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Services.Notifications

/**
 * A group of notifications from the same app.
 * Similar to Android's notifications.
 *
 * Popup vs Sidebar behavior:
 * - Sidebar: Smooth height animations for expand/collapse (panel doesn't resize)
 * - Popup: Instant height changes to avoid Wayland window resize stair-stepping,
 *   with fast opacity/displacement transitions for polish
 */
MouseArea { // Notification group area
    id: root
    property var notificationGroup
    property var notifications: notificationGroup?.notifications ?? []
    property int notificationCount: notifications.length
    property bool multipleNotifications: notificationCount > 1
    property bool expanded: false
    property bool popup: false
    property real padding: 10
    property bool _expandAnimating: false
    implicitHeight: background.implicitHeight

    property real dragConfirmThreshold: 40 // Drag to discard notification
    property real dismissOvershoot: 20 // Account for gaps and bouncy animations
    property var qmlParent: root?.parent?.parent // There's something between this and the parent ListView
    property var parentDragIndex: qmlParent?.dragIndex
    property var parentDragDistance: qmlParent?.dragDistance
    property var dragIndexDiff: Math.abs(parentDragIndex - index)
    property real xOffset: dragIndexDiff == 0 ? parentDragDistance : 0

    // Animation tokens — use fast timing for dismiss in all modes
    readonly property QtObject _dismissAnim: Appearance.animation.elementMoveFast
    readonly property QtObject _contentAnim: Appearance.animation.elementMoveFast

    function destroyWithAnimation(left = false) {
        background.anchors.leftMargin = root.xOffset; // Break binding, capture current position
        background.implicitHeight = background.implicitHeight; // Freeze height during dismiss
        root.implicitHeight = root.implicitHeight; // Freeze delegate height in ListView
        root.qmlParent.resetDrag()
        destroyAnimation.left = left;
        destroyAnimation.running = true;
    }

    hoverEnabled: true
    onContainsMouseChanged: {
        if (!root.popup) return;
        if (root.containsMouse) root.notifications.forEach(notif => {
            Notifications.cancelTimeout(notif.notificationId);
        });
        // Don't restart timeout on mouse leave - let them stay visible
    }

    SequentialAnimation { // Drag finish animation
        id: destroyAnimation
        property bool left: true
        running: false

        NumberAnimation {
            target: background.anchors
            property: "leftMargin"
            to: (root.width + root.dismissOvershoot) * (destroyAnimation.left ? -1 : 1)
            duration: root._dismissAnim.duration
            easing.type: root._dismissAnim.type
            easing.bezierCurve: root._dismissAnim.bezierCurve
        }
        onFinished: () => {
            root.notifications.forEach((notif) => {
                Qt.callLater(() => {
                    Notifications.discardNotification(notif.notificationId);
                });
            });
        }
    }

    function toggleExpanded() {
        // Sidebar: animate height smoothly (panel doesn't resize, so no stair-stepping)
        // Popup: skip height animation (each frame would force async Wayland window resize)
        if (!root.popup) {
            root._expandAnimating = true;
            _expandAnimateEndTimer.restart();
        }
        root.expanded = !root.expanded;
    }

    Timer {
        id: _expandAnimateEndTimer
        interval: Appearance.animation.elementMoveFast.duration + 50
        onTriggered: root._expandAnimating = false
    }

    DragManager { // Drag manager
        id: dragManager
        anchors.fill: parent
        interactive: !expanded
        automaticallyReset: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.toggleExpanded();
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton && !dragging) {
                root.toggleExpanded();
            } else if (mouse.button === Qt.MiddleButton) {
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

    StyledRectangularShadow {
        target: background
        visible: popup && !Appearance.inirEverywhere
    }

    Rectangle { // Background of the notification
        id: background
        anchors.left: parent.left
        width: parent.width

        // For popup: glass blur for aurora/angel, solid for others
        // For sidebar: transparent to show parent's blur
        color: Appearance.angelEverywhere ? (popup ? "transparent" : Appearance.angel.colGlassCard)
            : Appearance.inirEverywhere ? (popup ? Appearance.inir.colLayer2 : Appearance.inir.colLayer1)
            : Appearance.auroraEverywhere ? "transparent"
            : (popup ? ColorUtils.applyAlpha(Appearance.colors.colLayer2, 1 - Appearance.backgroundTransparency)
                     : Appearance.colors.colLayer2)

        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
            : (Appearance.inirEverywhere || (Appearance.auroraEverywhere && popup)) ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : "transparent"
        anchors.leftMargin: root.xOffset

        Behavior on anchors.leftMargin {
            enabled: !dragManager.dragging
            NumberAnimation {
                duration: root._contentAnim.duration
                easing.type: root._contentAnim.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }

        clip: true

        // Rounded corner clipping for glass blur
        layer.enabled: root.popup && Appearance.auroraEverywhere && !Appearance.inirEverywhere
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        implicitHeight: root.expanded ?
            row.implicitHeight + padding * 2 :
            Math.min(80, row.implicitHeight + padding * 2)

        Behavior on implicitHeight {
            id: implicitHeightAnim
            // Only animate during user-initiated expand/collapse in sidebar mode.
            // Popup skips this to avoid Wayland window resize stair-stepping.
            enabled: root._expandAnimating && !root.popup && Appearance.animationsEnabled
            NumberAnimation {
                duration: root._contentAnim.duration
                easing.type: root._contentAnim.type
                easing.bezierCurve: root._contentAnim.bezierCurve
            }
        }

        // Glass blur layer — blurred wallpaper for aurora/angel popup
        Image {
            id: notifBlurredWallpaper
            anchors.fill: parent
            visible: root.popup && Appearance.auroraEverywhere && !Appearance.inirEverywhere
            source: Wallpapers.effectiveWallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                source: notifBlurredWallpaper
                anchors.fill: source
                saturation: Appearance.angelEverywhere
                    ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 100
                blur: Appearance.effectsEnabled
                    ? (Appearance.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                    : 0
            }
        }

        // Glass tint overlay
        Rectangle {
            anchors.fill: parent
            visible: root.popup && Appearance.auroraEverywhere && !Appearance.inirEverywhere
            color: Appearance.angelEverywhere
                ? ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
                : ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.aurora.popupTransparentize)
        }

        // Angel partial border for popup
        AngelPartialBorder {
            targetRadius: background.radius
        }

        RowLayout { // Left column for icon, right column for content
            id: row
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.padding
            spacing: 10

            NotificationAppIcon { // Icons
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: false
                image: root?.multipleNotifications ? "" : notificationGroup?.notifications[0]?.image ?? ""
                appIcon: root.notificationGroup?.appIcon
                summary: root.notificationGroup?.notifications[root.notificationCount - 1]?.summary
                // Use pre-calculated hasCritical from service
                urgency: root.notificationGroup?.hasCritical ? NotificationUrgency.Critical : NotificationUrgency.Normal
            }

            ColumnLayout { // Content
                Layout.fillWidth: true
                spacing: expanded ? (root.multipleNotifications ?
                    (notificationGroup?.notifications[root.notificationCount - 1].image != "") ? 35 :
                    5 : 0) : 0

                Behavior on spacing {
                    // Sidebar: smooth spacing transition; Popup: instant
                    enabled: !root.popup && Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                Item { // App name (or summary when there's only 1 notif) and time
                    id: topRow
                    Layout.fillWidth: true
                    property real fontSize: Appearance.font.pixelSize.smaller
                    property bool showAppName: root.multipleNotifications
                    implicitHeight: Math.max(topTextRow.implicitHeight, expandButton.implicitHeight)

                    RowLayout {
                        id: topTextRow
                        anchors.left: parent.left
                        anchors.right: expandButton.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        StyledText {
                            id: appName
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            text: (topRow.showAppName ?
                                notificationGroup?.appName :
                                notificationGroup?.notifications[0]?.summary) || ""
                            font.pixelSize: topRow.showAppName ?
                                topRow.fontSize :
                                Appearance.font.pixelSize.small
                            color: topRow.showAppName ?
                                Appearance.colors.colSubtext :
                                Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            id: timeText
                            Layout.rightMargin: 10
                            horizontalAlignment: Text.AlignLeft
                            text: NotificationUtils.getFriendlyNotifTimeString(notificationGroup?.time)
                            font.pixelSize: topRow.fontSize
                            color: Appearance.colors.colSubtext
                        }
                    }
                    NotificationGroupExpandButton {
                        id: expandButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        count: root.notificationCount
                        expanded: root.expanded
                        fontSize: topRow.fontSize
                        onClicked: { root.toggleExpanded() }
                        altAction: () => { root.toggleExpanded() }
                    }
                }

                StyledListView { // Notification body (expanded)
                    id: notificationsColumn
                    implicitHeight: contentHeight
                    Layout.fillWidth: true
                    spacing: expanded ? 5 : 3
                    interactive: false

                    // Disable built-in transitions — we provide custom ones below
                    // to use faster timing for popup and standard for sidebar
                    animateAppearance: false
                    popin: false

                    Behavior on spacing {
                        enabled: !root.popup && Appearance.animationsEnabled
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    // Custom removeDisplaced: smooth gap-filling when a notification is dismissed.
                    // Uses fast timing so remaining items slide up promptly after dismiss animation.
                    removeDisplaced: Transition {
                        NumberAnimation {
                            property: "y"
                            duration: root._contentAnim.duration
                            easing.type: root._contentAnim.type
                            easing.bezierCurve: root._contentAnim.bezierCurve
                        }
                        NumberAnimation {
                            property: "opacity"
                            to: 1
                            duration: root._contentAnim.duration
                            easing.type: root._contentAnim.type
                            easing.bezierCurve: root._contentAnim.bezierCurve
                        }
                    }

                    model: ScriptModel {
                        values: root.expanded ? root.notifications.slice().reverse() :
                            root.notifications.slice().reverse().slice(0, 2)
                    }
                    delegate: NotificationItem {
                        required property int index
                        required property var modelData
                        notificationObject: modelData
                        expanded: root.expanded
                        popup: root.popup
                        onlyNotification: (root.notificationCount === 1)
                        opacity: (!root.expanded && index == 1 && root.notificationCount > 2) ? 0.5 : 1
                        visible: root.expanded || (index < 2)
                        anchors.left: parent?.left
                        anchors.right: parent?.right
                    }
                }

            }
        }
    }
}
